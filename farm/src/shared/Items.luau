--!strict
-- One lookup for every Barn item, built from the crop, animal, recipe and town configs.

local Animals = require("./Config/Animals")
local Barn = require("./Config/Barn")
local Crops = require("./Config/Crops")
local DuckPond = require("./Config/DuckPond")
local Isles = require("./Config/Isles")
local Recipes = require("./Config/Recipes")
local Town = require("./Config/Town")

export type ItemDef = {
	id: string,
	displayName: string,
	kind: "Crop" | "Animal" | "Product" | "Material" | "Isle",
	unlockLevel: number,
	sellPrice: number, -- 0 = can't be sold
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
	local crop, pen, recipe, good = Crops[id], penByProduct[id], Recipes[id], Isles.goods[id]
	if good then
		-- A boat's trip shared over the common good's 3, with rarer goods worth 2 and 3 shares
		seconds = Isles.byId[good.isle].tripSeconds / Isles.commonQty * good.tier
	elseif crop then
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

-- Duck Pond feathers (Config/DuckPond): a visit's wait plus its food, shared over the
-- feathers it leaves on average (Down from Bread, Colorful from Bagels)
local function featherSeconds(food: string, perVisit: number): number
	local def = DuckPond.foods[food]
	return (def.seconds + unitSeconds(def.item, 0)) / perVisit
end
local featherTimes = {
	[DuckPond.down] = featherSeconds("Bread", (DuckPond.foods.Bread.ducks[1] + DuckPond.foods.Bread.ducks[2]) / 2),
	[DuckPond.colorful] = featherSeconds(
		"Bagel",
		(DuckPond.foods.Bagel.drakes[1] + DuckPond.foods.Bagel.drakes[2]) / 2
	),
}
for id, feather in DuckPond.feathers do
	Items[id] = {
		id = id,
		displayName = feather.displayName,
		kind = "Animal",
		unlockLevel = DuckPond.unlockLevel,
		sellPrice = feather.sellPrice,
		xpPerUnit = feather.xp,
		unitSeconds = featherTimes[id],
		isFeed = false,
	}
	unitSecondsCache[id] = featherTimes[id]
end

-- Far Isle goods (Config/Isles): only Sailboats bring them back
for id, good in Isles.goods do
	Items[id] = {
		id = id,
		displayName = good.displayName,
		kind = "Isle",
		unlockLevel = Isles.byId[good.isle].unlockLevel,
		sellPrice = good.sellPrice,
		xpPerUnit = good.xp,
		unitSeconds = unitSeconds(id, 0),
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

-- Building and Barn materials take Barn space but can't be sold or ordered
local function addMaterials(materials: { [string]: { displayName: string } }, unlockLevel: number)
	for id, material in materials do
		Items[id] = {
			id = id,
			displayName = material.displayName,
			kind = "Material",
			unlockLevel = unlockLevel,
			sellPrice = 0,
			xpPerUnit = 0,
			unitSeconds = 0,
			isFeed = false,
		}
	end
end
addMaterials(Town.materials, Town.materialsFromLevel)
addMaterials(Barn.materials, Barn.materialsFromLevel)

for _, item in Items do
	table.freeze(item)
end

return table.freeze(Items)
