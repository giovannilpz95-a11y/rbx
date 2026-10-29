--!strict
-- Planting and harvesting fields (Design/02 Farming). Hands-on: the avatar must be in reach.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Balance = require(Shared.Config.Balance)
local Crops = require(Shared.Config.Crops)
local Net = require(Shared.Net)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local Tutorial = require(Shared.Tutorial)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TownService = require(script.Parent.TownService)
local Clock = require(script.Parent.Parent.Util.Clock)

local FarmService = {}

local enabledCrops: { [string]: boolean } = {}
for _, id in Balance.enabledCrops do
	enabledCrops[id] = true
end

local function nearField(player: Player, fieldId: string): boolean
	local pos = PlotService.fieldPosition(player, fieldId)
	return pos ~= nil and NetService.isNear(player, pos, Balance.serverReachStuds)
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
	if not nearField(player, fieldId) then
		return false, "Walk closer to that field"
	end
	if not EconomyService.spend(player, "Coins", crop.seedCost, "seed_" .. cropId) then
		return false, "Not enough Coins"
	end
	local now = Clock.now()
	field.crop = cropId
	field.plantedAt = now
	field.readyAt = now + Clock.duration(Tutorial.seconds(data, cropId, crop.growSeconds))
	data.settings.lastSeed = cropId
	PlotService.refresh(player)
	return true
end

function FarmService.harvest(player: Player, fieldId: any): (boolean, string?)
	if not NetService.check.id(fieldId) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local field = data.fields[fieldId]
	if field == nil or field.crop == nil then
		return false
	end
	-- 1 s of slack for the client's countdown reaching zero first
	if not Timer.isReady(field.readyAt, Clock.now() + 1) then
		return false
	end
	if not nearField(player, fieldId) then
		return false, "Walk closer to that field"
	end
	local crop = Crops[field.crop]
	if not InventoryService.add(player, { [crop.id] = crop.yield }) then
		return false, "Your Barn is full. Sell something from the Barn first."
	end
	field.crop = nil
	field.plantedAt = nil
	field.readyAt = nil
	EconomyService.add(player, "XP", crop.xp, "harvest_" .. crop.id)
	TownService.onHarvest(player, crop.growSeconds)
	PlotService.refresh(player)
	return true
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

function FarmService.init()
	NetService.on(Net.Farm_Plant, 20, 30, FarmService.plant)
	NetService.on(Net.Farm_Harvest, 20, 30, FarmService.harvest)
	NetService.on(Net.Farm_SpeedUp, 2, 3, FarmService.speedUp)
end

return FarmService
