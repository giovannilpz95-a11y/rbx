--!strict
-- The town (Design/07 Town Building): Houses raise Population, Community Buildings raise the
-- Cap, and building materials (Bricks, Planks, Panes) pay for Community Buildings. Population
-- also brings free fields, and land expansion opens room for them (02 Farming).
-- Everything here is paperwork, done from the Town panel; new buildings take the next free
-- lot on Main Street (no free placement in the greybox).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Barn = require(Shared.Config.Barn)
local Drops = require(Shared.Drops)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Speedup = require(Shared.Speedup)
local Tools = require(Shared.Config.Tools)
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

-- Order deliveries roll building and Barn materials (one roll for both, each group split evenly)
local function pickMaterial(): string
	local materials = {}
	local total = 0
	for _, drop in Drops.pool do
		if not drop.tool then
			table.insert(materials, drop)
			total += drop.weight
		end
	end
	local roll = rng:NextNumber() * total
	for _, drop in materials do
		roll -= drop.weight
		if roll < 0 then
			return drop.id
		end
	end
	return materials[#materials].id
end

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
	elseif kind == "Land" and NetService.check.int(key, 1, 99) then
		entry = data.land[key]
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

-- One building material (8 Gems) or Barn material (12 Gems).
function TownService.buyMaterial(player: Player, itemId: any): (boolean, string?)
	if not NetService.check.id(itemId) then
		return false
	end
	local price = if Town.materials[itemId]
		then Town.materialGemPrice
		elseif Barn.materials[itemId] then Barn.materialGemPrice
		else nil
	if price == nil then
		return false
	end
	if InventoryService.space(player) < 1 then
		return false, "Your Barn is full. Sell something from the Barn first."
	end
	if not EconomyService.spend(player, "Gems", price, "material_" .. itemId) then
		return false, "Not enough Gems"
	end
	InventoryService.add(player, { [itemId] = 1 })
	return true
end

function TownService.expand(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = TownRules.canExpand(data, now)
	if not ok then
		return false, reason
	end
	local def = TownRules.nextExpansion(data) :: any
	if not EconomyService.spend(player, "Coins", def.coinCost, "expand_" .. def.stage) then
		return false, string.format("Clearing the %s costs %d Coins", def.displayName, def.coinCost)
	end
	table.insert(data.land, { readyAt = now + Clock.duration(def.buildSeconds) })
	EconomyService.add(player, "XP", def.xp, "expand_" .. def.stage)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

-- Place every field the farm has earned and has land for (free; XP on placing).
function TownService.placeFields(player: Player): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local placed = TownRules.fieldsToPlace(data, Clock.now())
	for _, unlock in placed do
		data.fields["F" .. unlock.field] = {}
		EconomyService.add(player, "XP", unlock.xp, "field_" .. unlock.field)
		NetService.popup(player, { kind = "Field", field = unlock.field, xp = unlock.xp })
	end
	if #placed > 0 then
		DataService.markDirty(player, true)
		PlotService.refresh(player)
		return true
	end
	return false
end

-- Tools go to the Tool Shed; materials go to the Barn (silently lost when it's full)
local function give(player: Player, data: { [string]: any }, id: string)
	if Drops.isTool(id) then
		data.toolShed.items[id] = (data.toolShed.items[id] or 0) + 1
		NetService.popup(player, { kind = "Drop", item = id, name = Tools.tools[id].displayName, tool = true })
	elseif InventoryService.add(player, { [id] = 1 }) then
		NetService.popup(player, { kind = "Drop", item = id, name = Items[id].displayName })
	end
end

TownService.give = give -- Helping Hands pays helpers a tool now and then

-- One roll per field harvested for a tool or a material (from level 5), with the pity count.
-- Both hooks run inside a remote handler, which saves and pushes state afterwards.
function TownService.onHarvest(player: Player, growSeconds: number)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local id = Drops.harvest(data, growSeconds, rng:NextNumber())
	if id then
		give(player, data, id)
	end
end

-- Deliveries: a chance at a material, and a smaller one at the scarcest tool
function TownService.onOrderDelivered(player: Player)
	local data = DataService.get(player)
	if data == nil or data.level < Town.materialsFromLevel then
		return
	end
	if rng:NextNumber() < Town.orderDropChance then
		give(player, data, pickMaterial())
	end
	if data.level >= Tools.fromLevel and rng:NextNumber() < Tools.orderDropChance then
		give(player, data, Drops.scarcestTool(data))
	end
end

function TownService.init()
	NetService.on(Net.Town_BuildHouse, 2, 3, TownService.buildHouse)
	NetService.on(Net.Town_BuildCommunity, 1, 2, TownService.buildCommunity)
	NetService.on(Net.Town_SpeedUp, 2, 3, TownService.speedUp)
	NetService.on(Net.Town_BuyMaterial, 2, 3, TownService.buyMaterial)
	NetService.on(Net.Town_Expand, 1, 2, TownService.expand)

	-- Houses and expansions finish on their own; new fields follow
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				if TownService.placeFields(player) then
					NetService.pushState(player)
				end
			end
		end
	end)
end

return TownService
