--!strict
-- Factory buildings from Design/04 Factories & Recipes and Township Baseline Numbers §4
-- (Township baseline): the six factories of the level-12 MVP (the Tailor in the West
-- Meadow), then the content bank's (Config/Levels.built), which stand in the East Meadow. The Feed Mill gets a second copy
-- (level 19) and the Smelter two at once (level 21), as in Township; a copy has its own id and
-- queue and makes the same recipes.

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
	makes: string?, -- a second copy: the factory whose recipes it makes
	fixedSlots: boolean?, -- no extra queue slots for Gems (Township's Foundry: one at a time)
}

local HOUR = 3600

-- stylua: ignore
local Factories: { [string]: FactoryDef } = {
	Bakery = { id = "Bakery", displayName = "Bakery", unlockLevel = 2, population = 55, buildCost = 125, buildSeconds = 3, xp = 10, queueSlots = 3, trayCapacity = 6, order = 1, color = { 230, 200, 150 } },
	FeedMill = { id = "FeedMill", displayName = "Feed Mill", unlockLevel = 3, population = 60, buildCost = 150, buildSeconds = 40, xp = 11, queueSlots = 3, trayCapacity = 6, order = 2, color = { 200, 170, 110 } },
	Dairy = { id = "Dairy", displayName = "Dairy", unlockLevel = 4, population = 65, buildCost = 175, buildSeconds = 1 * HOUR, xp = 12, queueSlots = 3, trayCapacity = 6, order = 3, color = { 225, 235, 245 } },
	SugarMill = { id = "SugarMill", displayName = "Sugar Mill", unlockLevel = 7, population = 75, buildCost = 250, buildSeconds = 2 * HOUR, xp = 15, queueSlots = 2, trayCapacity = 6, order = 4, color = { 215, 190, 200 } },
	TextileMill = { id = "TextileMill", displayName = "Textile Mill", unlockLevel = 9, population = 105, buildCost = 500, buildSeconds = 6 * HOUR, xp = 25, queueSlots = 2, trayCapacity = 6, order = 5, color = { 170, 190, 220 } },
	Tailor = { id = "Tailor", displayName = "Tailor", unlockLevel = 12, population = 195, buildCost = 800, buildSeconds = 10 * HOUR, xp = 38, queueSlots = 2, trayCapacity = 6, order = 6, color = { 200, 170, 210 }, land = 1 },
	-- content bank (level 13+)
	SnackFactory = { id = "SnackFactory", displayName = "Snack Factory", unlockLevel = 14, population = 300, buildCost = 1300, buildSeconds = 12 * HOUR, xp = 58, queueSlots = 2, trayCapacity = 6, order = 7, color = { 240, 200, 90 }, land = 2 },
	Diner = { id = "Diner", displayName = "Diner", unlockLevel = 16, population = 425, buildCost = 2100, buildSeconds = 16 * HOUR, xp = 91, queueSlots = 2, trayCapacity = 6, order = 8, color = { 150, 215, 200 }, land = 2 },
	PaperMill = { id = "PaperMill", displayName = "Paper Mill", unlockLevel = 18, population = 570, buildCost = 2800, buildSeconds = 16 * HOUR, xp = 120, queueSlots = 2, trayCapacity = 6, order = 9, color = { 225, 215, 190 }, land = 2 },
	FeedMill2 = { id = "FeedMill2", displayName = "Second Feed Mill", unlockLevel = 19, population = 655, buildCost = 2800, buildSeconds = 16 * HOUR, xp = 120, queueSlots = 3, trayCapacity = 6, order = 10, color = { 200, 150, 110 }, land = 2, makes = "FeedMill" },
	IceCreamParlor = { id = "IceCreamParlor", displayName = "Ice Cream Parlor", unlockLevel = 20, population = 735, buildCost = 3600, buildSeconds = 24 * HOUR, xp = 174, queueSlots = 2, trayCapacity = 6, order = 11, color = { 245, 190, 210 }, land = 2 },
	PastryShop = { id = "PastryShop", displayName = "Pastry Shop", unlockLevel = 24, population = 1100, buildCost = 5300, buildSeconds = 28 * HOUR, xp = 252, queueSlots = 2, trayCapacity = 6, order = 12, color = { 240, 215, 170 }, land = 2 },
	-- Township's Foundries #1 and #2 (level 21): smelt Quarry ore into Bars, one at a time
	Smelter = { id = "Smelter", displayName = "Smelter", unlockLevel = 21, population = 730, buildCost = 2000, buildSeconds = 36 * HOUR, xp = 87, queueSlots = 1, trayCapacity = 6, order = 14, color = { 170, 120, 95 }, land = 2, fixedSlots = true },
	Smelter2 = { id = "Smelter2", displayName = "Second Smelter", unlockLevel = 21, population = 920, buildCost = 8000, buildSeconds = 36 * HOUR, xp = 335, queueSlots = 1, trayCapacity = 6, order = 15, color = { 150, 110, 100 }, land = 2, makes = "Smelter", fixedSlots = true },
	RubberWorks = { id = "RubberWorks", displayName = "Rubber Works", unlockLevel = 29, population = 1670, buildCost = 9000, buildSeconds = 32 * HOUR, xp = 376, queueSlots = 2, trayCapacity = 6, order = 16, color = { 90, 95, 105 }, land = 2 },
	PrepKitchen = { id = "PrepKitchen", displayName = "Prep Kitchen", unlockLevel = 31, population = 1980, buildCost = 12000, buildSeconds = 34 * HOUR, xp = 500, queueSlots = 2, trayCapacity = 6, order = 17, color = { 235, 225, 200 }, land = 2 },
	-- Township's Plastics Factory (level 34): no usual spot, the player places it once it's built
	MoldingWorks = { id = "MoldingWorks", displayName = "Molding Works", unlockLevel = 34, population = 2375, buildCost = 15000, buildSeconds = 36 * HOUR, xp = 623, queueSlots = 2, trayCapacity = 6, order = 18, color = { 110, 170, 210 } },
	-- Township's Household Goods Factory (level 37): placed by the player once it's built
	HomewaresShop = { id = "HomewaresShop", displayName = "Homewares Shop", unlockLevel = 37, population = 3130, buildCost = 18000, buildSeconds = 38 * HOUR, xp = 747, queueSlots = 2, trayCapacity = 6, order = 19, color = { 240, 200, 120 } },
	-- Township's Candy Factory (level 39): placed by the player once it's built
	CandyFactory = { id = "CandyFactory", displayName = "Candy Factory", unlockLevel = 39, population = 3190, buildCost = 20000, buildSeconds = 40 * HOUR, xp = 830, queueSlots = 2, trayCapacity = 6, order = 20, color = { 245, 150, 190 } },
	JamKitchen = { id = "JamKitchen", displayName = "Jam Kitchen", unlockLevel = 27, population = 1480, buildCost = 7100, buildSeconds = 26 * HOUR, xp = 297, queueSlots = 2, trayCapacity = 6, order = 13, color = { 200, 60, 90 }, land = 2 },
}

return table.freeze(Factories)
