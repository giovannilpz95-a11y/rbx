--!strict
-- Factory buildings from Design/04 Factories & Recipes and Township Baseline Numbers §4
-- (Township baseline): the five factories of the level-12 MVP, then the content bank's
-- (Config/Levels.built), which stand in the East Meadow.

export type FactoryDef = {
	id: string,
	displayName: string,
	unlockLevel: number,
	population: number, -- Population needed to build it (07 Town Building)
	buildCost: number, -- Coins
	buildSeconds: number,
	xp: number, -- XP for building it
	queueSlots: number, -- starting queue length (active + waiting)
	trayCapacity: number, -- finished goods the output tray holds
	order: number, -- unlock order (UI sort)
	color: { number }, -- greybox RGB
	land: number?, -- the land expansion its spot is on, which must be cleared first
}

local HOUR = 3600

-- stylua: ignore
local Factories: { [string]: FactoryDef } = {
	Bakery = { id = "Bakery", displayName = "Bakery", unlockLevel = 2, population = 55, buildCost = 125, buildSeconds = 3, xp = 10, queueSlots = 3, trayCapacity = 6, order = 1, color = { 230, 200, 150 } },
	FeedMill = { id = "FeedMill", displayName = "Feed Mill", unlockLevel = 3, population = 60, buildCost = 150, buildSeconds = 40, xp = 11, queueSlots = 3, trayCapacity = 6, order = 2, color = { 200, 170, 110 } },
	Dairy = { id = "Dairy", displayName = "Dairy", unlockLevel = 4, population = 65, buildCost = 175, buildSeconds = 1 * HOUR, xp = 12, queueSlots = 3, trayCapacity = 6, order = 3, color = { 225, 235, 245 } },
	SugarMill = { id = "SugarMill", displayName = "Sugar Mill", unlockLevel = 7, population = 75, buildCost = 250, buildSeconds = 2 * HOUR, xp = 15, queueSlots = 2, trayCapacity = 6, order = 4, color = { 215, 190, 200 } },
	TextileMill = { id = "TextileMill", displayName = "Textile Mill", unlockLevel = 9, population = 105, buildCost = 500, buildSeconds = 6 * HOUR, xp = 25, queueSlots = 2, trayCapacity = 6, order = 5, color = { 170, 190, 220 } },
	-- content bank (level 13+)
	SnackFactory = { id = "SnackFactory", displayName = "Snack Factory", unlockLevel = 14, population = 300, buildCost = 1300, buildSeconds = 12 * HOUR, xp = 58, queueSlots = 2, trayCapacity = 6, order = 6, color = { 240, 200, 90 }, land = 2 },
	Diner = { id = "Diner", displayName = "Diner", unlockLevel = 16, population = 425, buildCost = 2100, buildSeconds = 16 * HOUR, xp = 91, queueSlots = 2, trayCapacity = 6, order = 7, color = { 150, 215, 200 }, land = 2 },
}

return table.freeze(Factories)
