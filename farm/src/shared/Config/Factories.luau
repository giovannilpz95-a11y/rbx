--!strict
-- Factory buildings from Design/04 Factories & Recipes and Township Baseline Numbers §4
-- (Township baseline): the five factories of the level-12 MVP.

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
}

local HOUR = 3600

-- stylua: ignore
local Factories: { [string]: FactoryDef } = {
	Bakery = { id = "Bakery", displayName = "Bakery", unlockLevel = 2, population = 55, buildCost = 125, buildSeconds = 3, xp = 10, queueSlots = 3, trayCapacity = 6, order = 1, color = { 230, 200, 150 } },
	FeedMill = { id = "FeedMill", displayName = "Feed Mill", unlockLevel = 3, population = 60, buildCost = 150, buildSeconds = 40, xp = 11, queueSlots = 3, trayCapacity = 6, order = 2, color = { 200, 170, 110 } },
	Dairy = { id = "Dairy", displayName = "Dairy", unlockLevel = 4, population = 65, buildCost = 175, buildSeconds = 1 * HOUR, xp = 12, queueSlots = 3, trayCapacity = 6, order = 3, color = { 225, 235, 245 } },
	SugarMill = { id = "SugarMill", displayName = "Sugar Mill", unlockLevel = 7, population = 75, buildCost = 250, buildSeconds = 2 * HOUR, xp = 15, queueSlots = 2, trayCapacity = 6, order = 4, color = { 215, 190, 200 } },
	TextileMill = { id = "TextileMill", displayName = "Textile Mill", unlockLevel = 9, population = 105, buildCost = 500, buildSeconds = 6 * HOUR, xp = 25, queueSlots = 2, trayCapacity = 6, order = 5, color = { 170, 190, 220 } },
}

return table.freeze(Factories)
