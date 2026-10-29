--!strict
-- One lookup for every Barn item, built from the crop and recipe configs.

local Crops = require("./Config/Crops")
local Recipes = require("./Config/Recipes")

export type ItemDef = {
	id: string,
	displayName: string,
	kind: "Crop" | "Product",
	unlockLevel: number,
	sellPrice: number,
	xpPerUnit: number, -- XP for producing one unit (order rewards use it)
	unitSeconds: number, -- production time for one unit, including inputs
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
	}
end

for id, recipe in Recipes do
	local inputSeconds = 0
	for input, qty in recipe.inputs do
		local crop = Crops[input]
		if crop then
			inputSeconds += qty * crop.growSeconds / crop.yield
		end
	end
	Items[id] = {
		id = id,
		displayName = recipe.displayName,
		kind = "Product",
		unlockLevel = recipe.unlockLevel,
		sellPrice = recipe.sellPrice,
		xpPerUnit = recipe.xp / recipe.outputQty,
		unitSeconds = recipe.seconds / recipe.outputQty + inputSeconds,
	}
end

for _, item in Items do
	table.freeze(item)
end

return table.freeze(Items)
