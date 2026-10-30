--!strict
-- "Buy what's missing" (UI Reference & Gaps G3, Township's convention C6): when a recipe, an
-- order, a Community Building or a Barn upgrade is short of items, the player can pay Gems
-- for just the missing ones and go ahead in one step. Pure, so the server's charge and the
-- client's button use the same price.
--
-- Prices (first-pass; no per-item list is published, Wiki Data - Orders & Economy):
-- building materials and Barn materials cost what buying one already costs (8 and 12 Gems,
-- Township baseline). Crops and goods cost what finishing their whole production would
-- (Speedup.production of the item's unit time, everything upstream included), at least 1.

local Barn = require("./Config/Barn")
local Items = require("./Items")
local Speedup = require("./Speedup")
local Town = require("./Config/Town")

export type Line = { item: string, qty: number }

local Missing = {}

-- Gems for one unit of `item`, or nil when it can't be bought (unknown items).
function Missing.unitPrice(item: string): number?
	if Town.materials[item] then
		return Town.materialGemPrice
	elseif Barn.materials[item] then
		return Barn.materialGemPrice
	end
	local def = Items[item]
	if def == nil then
		return nil
	end
	return math.max(1, Speedup.production(def.unitSeconds))
end

-- What `needs` is short of, given how many of each item there are (`count`), sorted by name.
function Missing.list(needs: { [string]: number }, count: (item: string) -> number): { Line }
	local out: { Line } = {}
	for item, qty in needs do
		local short = qty - count(item)
		if short > 0 then
			table.insert(out, { item = item, qty = short })
		end
	end
	table.sort(out, function(a, b)
		return a.item < b.item
	end)
	return out
end

-- Total Gems for a missing list, or nil when something in it can't be bought.
function Missing.price(lines: { Line }): number?
	local total = 0
	for _, line in lines do
		local unit = Missing.unitPrice(line.item)
		if unit == nil then
			return nil
		end
		total += unit * line.qty
	end
	return total
end

-- "1 Corn, 2 Eggs"
function Missing.describe(lines: { Line }): string
	local parts = {}
	for _, line in lines do
		local def = Items[line.item]
		table.insert(parts, string.format("%d %s", line.qty, if def then def.displayName else line.item))
	end
	return table.concat(parts, ", ")
end

return Missing
