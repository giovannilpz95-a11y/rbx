--!strict
-- Population rules (Design/07 Town Building), pure so the server, the client and the Lune
-- tests share them. Saved under data.town:
--   houses = { { type, lot, readyAt? } }      -- readyAt nil or past = finished
--   community = { [id] = { readyAt? } }       -- present = built or building
-- and data.land = { { readyAt? } } -- land expansions, started in order
-- Population and the Cap only count finished buildings. A House can't be started unless
-- the Cap has room for it on top of every House already finished or still building.

local Land = require("./Config/Land")
local Lots = require("./Lots")
local Town = require("./Config/Town")

local TownRules = {}

export type FieldUnlock = Land.FieldUnlock

function TownRules.isDone(entry: { [string]: any }, now: number): boolean
	return entry.readyAt == nil or now >= entry.readyAt
end

function TownRules.population(data: { [string]: any }, now: number): number
	local total = 0
	for _, house in data.town.houses do
		local def = Town.houses[house.type]
		if def and TownRules.isDone(house, now) then
			total += def.population
		end
	end
	return total
end

-- Population still under construction
function TownRules.pending(data: { [string]: any }, now: number): number
	local total = 0
	for _, house in data.town.houses do
		local def = Town.houses[house.type]
		if def and not TownRules.isDone(house, now) then
			total += def.population
		end
	end
	return total
end

function TownRules.cap(data: { [string]: any }, now: number): number
	local total = Town.baseCap
	for id, entry in data.town.community do
		local def = Town.community[id]
		if def and TownRules.isDone(entry, now) then
			total += def.capBonus
		end
	end
	return total
end

function TownRules.copiesBuilt(data: { [string]: any }, houseId: string): number
	local count = 0
	for _, house in data.town.houses do
		if house.type == houseId then
			count += 1
		end
	end
	return count
end

function TownRules.copiesAllowed(houseId: string, level: number): number
	local count = 0
	for _, unlock in Town.houses[houseId].copyLevels do
		if unlock <= level then
			count += 1
		end
	end
	return count
end

-- Level at which the next copy unlocks, or nil when every copy is out.
function TownRules.nextCopyLevel(data: { [string]: any }, houseId: string): number?
	return Town.houses[houseId].copyLevels[TownRules.copiesBuilt(data, houseId) + 1]
end

-- Can this House be started now (ignoring Coins)? Returns false and a reason when not.
function TownRules.canBuildHouse(data: { [string]: any }, houseId: string, now: number): (boolean, string?)
	local def = Town.houses[houseId]
	if def == nil then
		return false, nil
	end
	local nextLevel = TownRules.nextCopyLevel(data, houseId)
	if nextLevel == nil then
		return false, string.format("Every %s is built", def.displayName)
	elseif nextLevel > data.level then
		return false, string.format("Your next %s unlocks at level %d", def.displayName, nextLevel)
	end
	local after = TownRules.population(data, now) + TownRules.pending(data, now) + def.population
	if after > TownRules.cap(data, now) then
		return false, "Need more room: build a Community Building"
	end
	return true, nil
end

-- First Main Street lot no House stands on, or nil when the street is full.
function TownRules.freeLot(data: { [string]: any }, lotCount: number): number?
	local used: { [number]: boolean } = {}
	for _, house in data.town.houses do
		used[house.lot] = true
	end
	for lot = 1, lotCount do
		if not used[lot] then
			return lot
		end
	end
	return nil
end

-- How many House lots are open: North Lane's wait for the North Fields to be cleared.
-- Lots needing land come after Main Street's, so the open ones are always a prefix.
function TownRules.houseLotCount(data: { [string]: any }, now: number): number
	for i, lot in Lots.houses do
		if lot.land > 0 and not TownRules.landDone(data, lot.land, now) then
			return i - 1
		end
	end
	return #Lots.houses
end

-- The lot a Community Building stands on: its `order`, not counting the Town Hall upgrades
-- before it, which build onto the Town Hall instead. Nil for a Town Hall upgrade.
function TownRules.communityLot(id: string): number?
	local def = Town.community[id]
	if def.townHallStorey then
		return nil
	end
	local lot = def.order
	for _, other in Town.community do
		if other.townHallStorey and other.order < def.order then
			lot -= 1
		end
	end
	return lot
end

-- The Town Hall's storeys (1 plus its finished upgrades), and whether an upgrade is going up.
function TownRules.townHall(data: { [string]: any }, now: number): (number, boolean)
	local storeys, upgrading = 1, false
	for id, entry in data.town.community do
		local def = Town.community[id]
		if def and def.townHallStorey then
			if TownRules.isDone(entry, now) then
				storeys = math.max(storeys, def.townHallStorey)
			else
				upgrading = true
			end
		end
	end
	return storeys, upgrading
end

-- Whether a Community Building's lot is open, and the land expansion it waits for if not.
-- A Town Hall upgrade needs no lot.
function TownRules.communityLotOpen(data: { [string]: any }, id: string, now: number): (boolean, number?)
	local index = TownRules.communityLot(id)
	if index == nil then
		return true, nil
	end
	local lot = Lots.community[index]
	if lot == nil then
		return false, nil
	end
	if lot.land > 0 and not TownRules.landDone(data, lot.land, now) then
		return false, lot.land
	end
	return true, nil
end

-- Land expansion

function TownRules.landDone(data: { [string]: any }, stage: number, now: number): boolean
	local entry = data.land[stage]
	return entry ~= nil and TownRules.isDone(entry, now)
end

-- The next expansion to start, or nil when all are started.
function TownRules.nextExpansion(data: { [string]: any }): Land.ExpansionDef?
	return Land.expansions[#data.land + 1]
end

function TownRules.canExpand(data: { [string]: any }, now: number): (boolean, string?)
	local def = TownRules.nextExpansion(data)
	if def == nil then
		return false, "No more land for now"
	end
	if def.stage > 1 and not TownRules.landDone(data, def.stage - 1, now) then
		return false, "Finish clearing the last expansion first"
	end
	local population = TownRules.population(data, now)
	if population < def.population then
		return false, string.format("Needs Population %d (you have %d)", def.population, population)
	end
	return true, nil
end

-- Fields 7+ the farm has earned (by Population) and has land for, but not placed yet.
function TownRules.fieldsToPlace(data: { [string]: any }, now: number): { FieldUnlock }
	local population = TownRules.population(data, now)
	local out = {}
	for _, unlock in Land.fields do
		if population < unlock.population then
			break
		end
		local hasLand = unlock.field <= Land.startAreaFields or TownRules.landDone(data, Land.extraFieldsStage, now)
		if data.fields["F" .. unlock.field] == nil and hasLand then
			table.insert(out, unlock)
		end
	end
	return out
end

-- Fields earned by Population but waiting for land.
function TownRules.fieldsWaiting(data: { [string]: any }, now: number): number
	local population = TownRules.population(data, now)
	local count = 0
	for _, unlock in Land.fields do
		if population >= unlock.population and data.fields["F" .. unlock.field] == nil then
			count += 1
		end
	end
	return count - #TownRules.fieldsToPlace(data, now)
end

return TownRules
