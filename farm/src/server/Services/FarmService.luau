--!strict
-- Planting and harvesting fields (Design/02 Farming). Hands-on: the avatar must be in reach.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Balance = require(Shared.Config.Balance)
local Crops = require(Shared.Config.Crops)
local Net = require(Shared.Net)
local Prize = require(Shared.Config.Prize)
local SocialRules = require(Shared.Social)
local PrizeRules = require(Shared.Prize)
local SeedCartRules = require(Shared.SeedCart)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local Tutorial = require(Shared.Tutorial)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local NoticeService = require(script.Parent.NoticeService)
local PlotService = require(script.Parent.PlotService)
local QuestService = require(script.Parent.QuestService)
local TownService = require(script.Parent.TownService)
local Clock = require(script.Parent.Parent.Util.Clock)

local FarmService = {}

local rng = Random.new()

local enabledCrops: { [string]: boolean } = {}
for _, id in Balance.enabledCrops do
	enabledCrops[id] = true
end

-- Is `by` standing near one of `owner`'s fields?
local function nearField(owner: Player, fieldId: string, by: Player): boolean
	local pos = PlotService.fieldPosition(owner, fieldId)
	return pos ~= nil and NetService.isNear(by, pos, Balance.serverReachStuds)
end

function FarmService.plant(player: Player, fieldId: any, cropId: any): (boolean, string?)
	if not NetService.check.id(fieldId) or not NetService.check.id(cropId) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local field = data.fields[fieldId]
	local crop = Crops[cropId]
	if field == nil or crop == nil or not enabledCrops[cropId] then
		return false
	end
	if field.crop ~= nil then
		return false
	end
	if data.level < crop.unlockLevel then
		return false, string.format("%s unlocks at level %d", crop.displayName, crop.unlockLevel)
	end
	if not nearField(player, fieldId, player) then
		return false, "Walk closer to that field"
	end
	if not EconomyService.spend(player, "Coins", crop.seedCost, "seed_" .. cropId) then
		return false, "Not enough Coins"
	end
	local now = Clock.now()
	field.crop = cropId
	field.plantedAt = now
	-- A Welcome Boost (friend joined) grows crops planted now a little faster
	local seconds = SocialRules.growSeconds(crop.growSeconds, SocialRules.boostActive(data.social, now))
	field.readyAt = now + Clock.duration(Tutorial.seconds(data, cropId, seconds))
	-- Rolled now, so speed-ups can't buy it. An Heirloom Seed from the Seed Cart goes into
	-- the next field planted.
	local boost = SeedCartRules.useHeirloomSeed(data)
	field.prize = PrizeRules.roll(data, rng:NextNumber(), if boost > 1 then { Heirloom = boost } else nil)
	field.watered = nil -- a helper may water each crop once (Helping Hands)
	data.settings.lastSeed = cropId
	PlotService.refresh(player)
	return true
end

-- Harvest one of `owner`'s fields into the owner's Barn. `by` is standing at the field: the
-- owner, or a helper (Helping Hands), who must be near it.
function FarmService.reap(owner: Player, fieldId: string, by: Player): (boolean, string?)
	local player = owner -- the harvest is the owner's: their Barn, XP, drops and news
	local data = DataService.get(player) :: { [string]: any }
	local field = data.fields[fieldId]
	if field == nil or field.crop == nil then
		return false
	end
	-- 1 s of slack for the client's countdown reaching zero first
	if not Timer.isReady(field.readyAt, Clock.now() + 1) then
		return false
	end
	if not nearField(owner, fieldId, by) then
		return false, "Walk closer to that field"
	end
	local crop = Crops[field.crop]
	-- A Prize Crop goes to the Prize Basket; with the basket full it's an ordinary unit
	local prize = if field.prize and PrizeRules.hasRoom(data) then field.prize else nil
	local toBarn = if prize then crop.yield - 1 else crop.yield
	if toBarn > 0 and not InventoryService.add(player, { [crop.id] = toBarn }) then
		return false,
			if by == owner
				then "Your Barn is full. Sell something from the Barn first."
				else string.format("%s's Barn is full", owner.DisplayName)
	end
	if prize then
		table.insert(data.prizes, { crop = crop.id, tier = prize })
		NetService.popup(player, {
			kind = "Prize",
			crop = crop.id,
			tier = prize,
			name = string.format("%s %s", Prize.tiers[prize].displayName, crop.displayName),
		})
		NoticeService.post(
			string.format("%s %s on %s's farm", Prize.tiers[prize].displayName, crop.displayName, player.DisplayName),
			player.UserId
		)
		-- The Town Crier: an Heirloom find is news for the whole server
		if prize == "Heirloom" then
			for _, other in Players:GetPlayers() do
				if other ~= player then
					NetService.popup(other, {
						kind = "Crier",
						text = string.format(
							"An Heirloom %s was grown on %s's farm!",
							crop.displayName,
							player.DisplayName
						),
					})
				end
			end
		end
	elseif field.prize then
		NetService.popup(player, { kind = "PrizeLost", crop = crop.id, tier = field.prize })
	end
	field.crop = nil
	field.plantedAt = nil
	field.readyAt = nil
	field.prize = nil
	field.watered = nil
	EconomyService.add(player, "XP", crop.xp, "harvest_" .. crop.id)
	QuestService.progress(player, "harvest", crop.yield)
	TownService.onHarvest(player, crop.growSeconds)
	PlotService.refresh(player)
	return true
end

function FarmService.harvest(player: Player, fieldId: any): (boolean, string?)
	if not NetService.check.id(fieldId) then
		return false
	end
	return FarmService.reap(player, fieldId, player)
end

-- The Prize Stand: sell one Prize Crop from the basket for Coins (paperwork).
function FarmService.sellPrize(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if not NetService.check.int(index, 1, Prize.basketSlots) or data.prizes[index] == nil then
		return false
	end
	local entry = table.remove(data.prizes, index)
	EconomyService.add(player, "Coins", PrizeRules.value(entry.crop, entry.tier), "prize_" .. entry.tier)
	return true
end

-- Put a Prize Crop from the basket on the plot's Prize Shelf, or take one back down
function FarmService.shelvePrize(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if not NetService.check.int(index, 1, Prize.basketSlots) then
		return false
	end
	local ok, reason = PrizeRules.shelve(data, index)
	if ok then
		PlotService.refresh(player)
	end
	return ok, reason
end

function FarmService.unshelvePrize(player: Player, slot: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if not NetService.check.int(slot, 1, Prize.shelfSlots) then
		return false
	end
	local ok, reason = PrizeRules.unshelve(data, slot)
	if ok then
		PlotService.refresh(player)
	end
	return ok, reason
end

-- Gems finish a growing field now (paperwork: works from anywhere on your plot).
function FarmService.speedUp(player: Player, fieldId: any): (boolean, string?)
	if not NetService.check.id(fieldId) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local field = data.fields[fieldId]
	local now = Clock.now()
	if field == nil or field.crop == nil or Timer.isReady(field.readyAt, now) then
		return false
	end
	local gems = Speedup.production(field.readyAt - now)
	if not EconomyService.spend(player, "Gems", gems, "speedup_" .. field.crop) then
		return false, "Not enough Gems"
	end
	field.readyAt = now
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

-- Speed Up All: every growing field of one crop, for the summed price (paperwork)
function FarmService.speedUpAll(player: Player, cropId: any): (boolean, string?)
	if not NetService.check.id(cropId) or Crops[cropId] == nil then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local gems, count = Speedup.allFields(data.fields, cropId, now)
	if count == 0 then
		return false
	end
	if not EconomyService.spend(player, "Gems", gems, "speedup_all_" .. cropId) then
		return false, "Not enough Gems"
	end
	for _, field in data.fields do
		if field.crop == cropId and field.readyAt ~= nil and field.readyAt > now then
			field.readyAt = now
		end
	end
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function FarmService.init()
	NetService.on(Net.Farm_Plant, 20, 30, FarmService.plant)
	NetService.on(Net.Farm_Harvest, 20, 30, FarmService.harvest)
	NetService.on(Net.Farm_SpeedUp, 2, 3, FarmService.speedUp)
	NetService.on(Net.Farm_SpeedUpAll, 2, 3, FarmService.speedUpAll)
	NetService.on(Net.Prize_Sell, 3, 5, FarmService.sellPrize)
	NetService.on(Net.Prize_Shelve, 3, 5, FarmService.shelvePrize)
	NetService.on(Net.Prize_Unshelve, 3, 5, FarmService.unshelvePrize)
end

return FarmService
