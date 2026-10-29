--!strict
-- Population rules (Design/07 Town Building), pure so the server, the client and the Lune
-- tests share them. Saved under data.town:
--   houses = { { type, lot, readyAt? } }      -- readyAt nil or past = finished
--   community = { [id] = { readyAt? } }       -- present = built or building
-- Population and the Cap only count finished buildings. A House can't be started unless
-- the Cap has room for it on top of every House already finished or still building.

local Town = require("./Config/Town")

local TownRules = {}

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

-- Building-material drop chance for one field harvest: longer crops drop more, up to x3.
function TownRules.harvestDropChance(growSeconds: number): number
	return Town.harvestDropChance * math.min(1 + growSeconds / 3600 * 0.25, 3)
end

return TownRules
