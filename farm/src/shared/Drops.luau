--!strict
-- What a field harvest drops (Design/02 Farming): one roll on a combined table of expansion
-- tools, building materials and Barn materials, so a field gives at most one item. Longer
-- crops roll better (x(1 + grow hours * 0.25), at most x3). If 40 harvests in a row bring no
-- tool, the next one gives whichever tool the farm has fewest of. Pure, so Lune can test it.

local Barn = require("./Config/Barn")
local Tools = require("./Config/Tools")
local Town = require("./Config/Town")

export type Drop = { id: string, weight: number, tool: boolean }

local Drops = {}

local pool: { Drop } = {}
local function add(group: { [string]: any }, chanceOf: (any) -> number, tool: boolean)
	local ids = {}
	for id in group do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return group[a].order < group[b].order
	end)
	for _, id in ids do
		table.insert(pool, table.freeze({ id = id, weight = chanceOf(group[id]), tool = tool }))
	end
end
add(Tools.tools, function(def)
	return def.harvestChance
end, true)
add(Town.materials, function()
	return Town.harvestDropChance / 3
end, false)
add(Barn.materials, function()
	return Barn.harvestDropChance / 3
end, false)
Drops.pool = table.freeze(pool)

function Drops.multiplier(growSeconds: number): number
	return math.min(1 + growSeconds / 3600 * 0.25, 3)
end

-- Chance that one harvest drops anything
function Drops.chance(growSeconds: number): number
	local total = 0
	for _, drop in pool do
		total += drop.weight
	end
	return total * Drops.multiplier(growSeconds)
end

function Drops.isTool(id: string): boolean
	return Tools.tools[id] ~= nil
end

-- The tool the farm has fewest of (ties go to the commonest: Shovel, Axe, Saw)
function Drops.scarcestTool(data: { [string]: any }): string
	local best, bestQty = nil, math.huge
	for _, drop in pool do
		if drop.tool then
			local qty = data.toolShed.items[drop.id] or 0
			if qty < bestQty then
				best, bestQty = drop.id, qty
			end
		end
	end
	return best :: string
end

-- One field harvest. `roll` is uniform in [0, 1). Returns the item dropped, if any, and
-- updates the pity count (data.toolShed.dry); the caller adds the item.
function Drops.harvest(data: { [string]: any }, growSeconds: number, roll: number): string?
	if data.level < Tools.fromLevel then
		return nil
	end
	local shed = data.toolShed
	if shed.dry >= Tools.pityHarvests then
		shed.dry = 0
		return Drops.scarcestTool(data)
	end
	local scaled = roll / Drops.multiplier(growSeconds)
	local id: string?, tool = nil, false
	for _, drop in pool do
		scaled -= drop.weight
		if scaled < 0 then
			id, tool = drop.id, drop.tool
			break
		end
	end
	shed.dry = if tool then 0 else shed.dry + 1
	return id
end

return Drops
