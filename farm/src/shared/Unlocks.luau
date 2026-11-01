--!strict
-- What a level opens up, for the level-up window's "New!" row (UI Reference & Gaps G1).
-- Read from the configs, so a new crop, recipe or building shows up without listing it here.

local Animals = require("./Config/Animals")
local Balance = require("./Config/Balance")
local Crops = require("./Config/Crops")
local Daily = require("./Config/Daily")
local Decor = require("./Config/Decor")
local DuckPondConfig = require("./Config/DuckPond")
local Factories = require("./Config/Factories")
local Isles = require("./Config/Isles")
local Recipes = require("./Config/Recipes")
local ToolTrader = require("./Config/ToolTrader")
local TonicsConfig = require("./Config/Tonics")
local Tools = require("./Config/Tools")
local Town = require("./Config/Town")
local TrainConfig = require("./Config/Train")

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
	if level == Isles.unlockLevel then
		table.insert(out, { kind = "Feature", id = "Harbor", name = "Harbor" })
	end
	for id, pond in DuckPondConfig.ponds do
		if pond.unlockLevel == level then
			table.insert(out, { kind = "Feature", id = id, name = pond.displayName })
		end
	end
	for i, train in TrainConfig.trains do
		if train.level == level then
			table.insert(
				out,
				if i == 1
					then { kind = "Feature", id = "TrainStation", name = "Train Station" }
					else { kind = "Feature", id = "Train" .. i, name = "Train " .. i }
			)
		end
	end
	if level == TrainConfig.helpFromLevel then
		table.insert(out, { kind = "Feature", id = "TrainHelp", name = "Help with trains" })
	end
	if level == TonicsConfig.unlockLevel then
		table.insert(out, { kind = "Feature", id = "TonicShed", name = "Tonic Shed" })
	end
	if level == ToolTrader.unlockLevel then
		table.insert(out, { kind = "Feature", id = "ToolTrader", name = "Tool Trader" })
	end
	for _, isle in Isles.isles do
		if isle.unlockLevel == level and isle.unlockCoins > 0 then
			table.insert(out, { kind = "Feature", id = isle.id, name = isle.displayName })
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
