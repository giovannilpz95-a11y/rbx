--!strict
-- Crop table from Design/02 Farming and Township Baseline Numbers §2 (Township baseline).
-- One unit per field harvested, as in Township (Wiki Data - Farming & Animals §1).
-- Only the crops listed in Balance.enabledCrops are playable in the greybox.

export type CropDef = {
	id: string, -- canonical name, also the Barn item key
	displayName: string,
	unlockLevel: number,
	growSeconds: number,
	seedCost: number, -- Coins per planting (Wheat is free)
	sellPrice: number, -- Coins per unit sold from the Barn
	xp: number, -- XP per field harvested
	yield: number, -- units per field harvested
	order: number, -- unlock order (UI sort)
	color: { number }, -- greybox RGB for the ripe crop
}

local MIN = 60
local HOUR = 3600

-- stylua: ignore
local Crops: { [string]: CropDef } = {
	Wheat = { id = "Wheat", displayName = "Wheat", unlockLevel = 1, growSeconds = 2 * MIN, seedCost = 0, sellPrice = 1, xp = 1, yield = 1, order = 1, color = { 230, 196, 92 } },
	Corn = { id = "Corn", displayName = "Corn", unlockLevel = 3, growSeconds = 5 * MIN, seedCost = 1, sellPrice = 3, xp = 1, yield = 1, order = 2, color = { 250, 222, 60 } },
	Carrots = { id = "Carrots", displayName = "Carrots", unlockLevel = 4, growSeconds = 10 * MIN, seedCost = 2, sellPrice = 5, xp = 2, yield = 1, order = 3, color = { 240, 130, 40 } },
	Sugarcane = { id = "Sugarcane", displayName = "Sugarcane", unlockLevel = 7, growSeconds = 20 * MIN, seedCost = 3, sellPrice = 7, xp = 3, yield = 1, order = 4, color = { 150, 200, 110 } },
	Cotton = { id = "Cotton", displayName = "Cotton", unlockLevel = 9, growSeconds = 30 * MIN, seedCost = 4, sellPrice = 9, xp = 4, yield = 1, order = 5, color = { 245, 245, 240 } },
	Strawberries = { id = "Strawberries", displayName = "Strawberries", unlockLevel = 13, growSeconds = 1 * HOUR, seedCost = 5, sellPrice = 11, xp = 6, yield = 1, order = 6, color = { 220, 40, 60 } },
	Tomatoes = { id = "Tomatoes", displayName = "Tomatoes", unlockLevel = 15, growSeconds = 2 * HOUR, seedCost = 6, sellPrice = 13, xp = 6, yield = 1, order = 7, color = { 230, 60, 40 } },
	Pumpkins = { id = "Pumpkins", displayName = "Pumpkins", unlockLevel = 18, growSeconds = 3 * HOUR, seedCost = 7, sellPrice = 15, xp = 7, yield = 1, order = 8, color = { 240, 140, 20 } },
	Potatoes = { id = "Potatoes", displayName = "Potatoes", unlockLevel = 22, growSeconds = 4 * HOUR, seedCost = 8, sellPrice = 17, xp = 8, yield = 1, order = 9, color = { 190, 150, 100 } },
	Cocoa = { id = "Cocoa", displayName = "Cocoa", unlockLevel = 25, growSeconds = 8 * HOUR, seedCost = 9, sellPrice = 19, xp = 19, yield = 1, order = 10, color = { 120, 70, 40 } },
}

return table.freeze(Crops)
