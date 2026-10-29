--!strict
-- One lookup for every Barn item, built from the crop, animal and recipe configs.

local Animals = require("./Config/Animals")
local Crops = require("./Config/Crops")
local Recipes = require("./Config/Recipes")

export type ItemDef = {
	id: string,
	displayName: string,
	kind: "Crop" | "Animal" | "Product",
	unlockLevel: number,
	sellPrice: number,
	xpPerUnit: number, -- XP for producing one unit (order rewards use it)
	unitSeconds: number, -- production time for one unit, including its inputs
	isFeed: boolean,
}

local Items: { [string]: ItemDef } = {}

for id, crop in Crops do
	Items[id] = {
		id = id,
		displayName = crop.displayName,
		kind = "Crop",
		unlockLevel = crop.unlockLevel,
		sellPrice = crop.sellPrice,
		xpPerUnit = crop.xp / crop.yield,
		unitSeconds = crop.growSeconds / crop.yield,
		isFeed = false,
	}
end

-- Production time of one unit including everything upstream (recipes can use animal
-- products and other recipes' output).
local unitSecondsCache: { [string]: number } = {}
local penByProduct: { [string]: Animals.PenDef } = {}
for _, pen in Animals.pens do
	penByProduct[pen.product] = pen
end

local function unitSeconds(id: string, depth: number): number
	if unitSecondsCache[id] then
		return unitSecondsCache[id]
	end
	assert(depth < 10, "recipe loop at " .. id)
	local seconds = 0
	local crop, pen, recipe = Crops[id], penByProduct[id], Recipes[id]
	if crop then
		seconds = crop.growSeconds / crop.yield
	elseif pen then
		seconds = pen.produceSeconds + unitSeconds(pen.feed, depth + 1) / Animals.feedPerBag
	elseif recipe then
		seconds = recipe.seconds
		for input, qty in recipe.inputs do
			seconds += qty * unitSeconds(input, depth + 1)
		end
		seconds /= recipe.outputQty
	end
	unitSecondsCache[id] = seconds
	return seconds
end

for _, pen in Animals.pens do
	Items[pen.product] = {
		id = pen.product,
		displayName = pen.productName,
		kind = "Animal",
		unlockLevel = pen.unlockLevel,
		sellPrice = pen.sellPrice,
		xpPerUnit = pen.productXP,
		unitSeconds = unitSeconds(pen.product, 0),
		isFeed = false,
	}
end

for id, recipe in Recipes do
	Items[id] = {
		id = id,
		displayName = recipe.displayName,
		kind = "Product",
		unlockLevel = recipe.unlockLevel,
		sellPrice = recipe.sellPrice,
		xpPerUnit = recipe.xp,
		unitSeconds = unitSeconds(id, 0),
		isFeed = recipe.isFeed == true,
	}
end

for _, item in Items do
	table.freeze(item)
end

return table.freeze(Items)
