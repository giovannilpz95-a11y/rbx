--!strict
-- What a level opens up, for the level-up window's "New!" row (UI Reference & Gaps G1).
-- Read from the configs, so a new crop, recipe or building shows up without listing it here.

local Animals = require("./Config/Animals")
local Balance = require("./Config/Balance")
local Crops = require("./Config/Crops")
local Daily = require("./Config/Daily")
local Decor = require("./Config/Decor")
local Factories = require("./Config/Factories")
local Recipes = require("./Config/Recipes")
local Tools = require("./Config/Tools")
local Town = require("./Config/Town")

export type Unlock = {
	kind: "Crop" | "Recipe" | "Factory" | "Pen" | "House" | "Community" | "Decor" | "Feature",
	id: string,
	name: string,
	item: string?, -- an item id with an icon (crops and goods)
	extra: boolean?, -- another copy of a House already unlocked
}

local Unlocks = {}

-- Kind -> sort weight: new places to make things first, then what they make, then the town
local WEIGHT = { Factory = 1, Pen = 2, Crop = 3, Recipe = 4, Community = 5, House = 6, Decor = 7, Feature = 8 }

function Unlocks.at(level: number): { Unlock }
	local out: { Unlock } = {}
	local factories = {}
	for _, id in Balance.enabledFactories do
		factories[id] = true
		local def = Factories[id]
		if def.unlockLevel == level then
			table.insert(out, { kind = "Factory", id = id, name = def.displayName })
		end
	end
	for _, id in Balance.enabledPens do
		local def = Animals.pens[id]
		if def.unlockLevel == level and not def.given then
			table.insert(out, { kind = "Pen", id = id, name = def.displayName })
		end
	end
	for _, id in Balance.enabledCrops do
		local def = Crops[id]
		if def.unlockLevel == level then
			table.insert(out, { kind = "Crop", id = id, name = def.displayName, item = id })
		end
	end
	for id, def in Recipes do
		if factories[def.factory] and def.unlockLevel == level then
			table.insert(out, { kind = "Recipe", id = id, name = def.displayName, item = id })
		end
	end
	for id, def in Town.community do
		if def.unlockLevel == level then
			table.insert(out, { kind = "Community", id = id, name = def.displayName })
		end
	end
	for id, def in Town.houses do
		for copy, at in def.copyLevels do
			if at == level then
				table.insert(out, { kind = "House", id = id, name = def.displayName, extra = copy > 1 })
				break
			end
		end
	end
	for id, def in Decor.items do
		if def.unlockLevel == level then
			table.insert(out, { kind = "Decor", id = id, name = def.displayName })
		end
	end
	if level == Daily.unlockLevel then
		table.insert(out, { kind = "Feature", id = "Daily", name = "Daily gifts" })
	end
	if level == Tools.fromLevel then
		table.insert(out, { kind = "Feature", id = "Tools", name = "Tool drops" })
	end
	if level == Town.materialsFromLevel then
		table.insert(out, { kind = "Feature", id = "Materials", name = "Building materials" })
	end
	table.sort(out, function(a, b)
		if WEIGHT[a.kind] ~= WEIGHT[b.kind] then
			return WEIGHT[a.kind] < WEIGHT[b.kind]
		end
		return a.name < b.name
	end)
	return out
end

return Unlocks
