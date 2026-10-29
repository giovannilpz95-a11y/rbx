--!strict
-- The town (Design/07 Town Building): Houses raise Population, Community Buildings raise the
-- Cap, and building materials (Bricks, Planks, Panes) pay for Community Buildings.
-- Everything here is paperwork, done from the Town panel; new buildings take the next free
-- lot on Main Street (no free placement in the greybox).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Speedup = require(Shared.Speedup)
local Town = require(Shared.Config.Town)
local TownRules = require(Shared.TownRules)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local Clock = require(script.Parent.Parent.Util.Clock)

local TownService = {}

local rng = Random.new()
local materialIds: { string } = {}
for id in Town.materials do
	table.insert(materialIds, id)
end
table.sort(materialIds)

function TownService.buildHouse(player: Player, houseId: any): (boolean, string?)
	if not NetService.check.id(houseId) or Town.houses[houseId] == nil then
		return false
	end
	local def = Town.houses[houseId]
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = TownRules.canBuildHouse(data, houseId, now)
	if not ok then
		return false, reason
	end
	local lot = TownRules.freeLot(data, #PlotService.LAYOUT.houseLots)
	if lot == nil then
		return false, "Main Street is full"
	end
	if not EconomyService.spend(player, "Coins", def.coinCost, "build_" .. houseId) then
		return false, string.format("A %s costs %d Coins", def.displayName, def.coinCost)
	end
	table.insert(data.town.houses, { type = houseId, lot = lot, readyAt = now + Clock.duration(def.buildSeconds) })
	EconomyService.add(player, "XP", def.xp, "build_" .. houseId)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function TownService.buildCommunity(player: Player, buildingId: any): (boolean, string?)
	if not NetService.check.id(buildingId) or Town.community[buildingId] == nil then
		return false
	end
	local def = Town.community[buildingId]
	local data = DataService.get(player) :: { [string]: any }
	if data.town.community[buildingId] ~= nil then
		return false
	end
	if data.level < def.unlockLevel then
		return false, string.format("The %s unlocks at level %d", def.displayName, def.unlockLevel)
	end
	if not InventoryService.has(player, def.materials) then
		return false, "Not enough building materials"
	end
	if not EconomyService.spend(player, "Coins", def.coinCost, "build_" .. buildingId) then
		return false, string.format("The %s costs %d Coins", def.displayName, def.coinCost)
	end
	InventoryService.remove(player, def.materials)
	data.town.community[buildingId] = { readyAt = Clock.now() + Clock.duration(def.buildSeconds) }
	EconomyService.add(player, "XP", def.xp, "build_" .. buildingId)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

-- Gems finish a House (by lot) or a Community Building (by id) under construction.
function TownService.speedUp(player: Player, kind: any, key: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local entry
	if kind == "House" and NetService.check.int(key, 1, 999) then
		for _, house in data.town.houses do
			if house.lot == key then
				entry = house
			end
		end
	elseif kind == "Community" and NetService.check.id(key) then
		entry = data.town.community[key]
	end
	local now = Clock.now()
	if entry == nil or TownRules.isDone(entry, now) then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(entry.readyAt - now), "speedup_town") then
		return false, "Not enough Gems"
	end
	entry.readyAt = now
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function TownService.buyMaterial(player: Player, itemId: any): (boolean, string?)
	if not NetService.check.id(itemId) or Town.materials[itemId] == nil then
		return false
	end
	if InventoryService.space(player) < 1 then
		return false, "Your Barn is full. Sell something from the Barn first."
	end
	if not EconomyService.spend(player, "Gems", Town.materialGemPrice, "material_" .. itemId) then
		return false, "Not enough Gems"
	end
	InventoryService.add(player, { [itemId] = 1 })
	return true
end

-- A chance at one building material (from level 5). Silent when the Barn is full.
local function rollMaterial(player: Player, chance: number)
	local data = DataService.get(player)
	if data == nil or data.level < Town.materialsFromLevel or rng:NextNumber() >= chance then
		return
	end
	local id = materialIds[rng:NextInteger(1, #materialIds)]
	if InventoryService.add(player, { [id] = 1 }) then
		NetService.popup(player, { kind = "Drop", item = id, name = Items[id].displayName })
	end
end

function TownService.onHarvest(player: Player, growSeconds: number)
	rollMaterial(player, TownRules.harvestDropChance(growSeconds))
end

function TownService.onOrderDelivered(player: Player)
	rollMaterial(player, Town.orderDropChance)
end

function TownService.init()
	NetService.on(Net.Town_BuildHouse, 2, 3, TownService.buildHouse)
	NetService.on(Net.Town_BuildCommunity, 1, 2, TownService.buildCommunity)
	NetService.on(Net.Town_SpeedUp, 2, 3, TownService.speedUp)
	NetService.on(Net.Town_BuyMaterial, 2, 3, TownService.buyMaterial)
end

return TownService
