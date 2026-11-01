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
	-- Township's Mexican Restaurant (level 43): placed by the player once it's built
	Cantina = { id = "Cantina", displayName = "Cantina", unlockLevel = 43, population = 3950, buildCost = 33000, buildSeconds = 44 * HOUR, xp = 1861, queueSlots = 2, trayCapacity = 6, order = 21, color = { 230, 120, 60 } },
	-- Township's third Feed Mill (level 44) and third Foundry (level 45): placed by the player
	FeedMill3 = { id = "FeedMill3", displayName = "Third Feed Mill", unlockLevel = 44, population = 4150, buildCost = 40000, buildSeconds = 44 * HOUR, xp = 1655, queueSlots = 3, trayCapacity = 6, order = 22, color = { 180, 140, 170 }, makes = "FeedMill" },
	Smelter3 = { id = "Smelter3", displayName = "Third Smelter", unlockLevel = 45, population = 4950, buildCost = 15000, buildSeconds = 36 * HOUR, xp = 623, queueSlots = 1, trayCapacity = 6, order = 23, color = { 140, 100, 120 }, makes = "Smelter", fixedSlots = true },
	-- Township's Stationery Factory (46) and Furniture Factory (47): placed by the player
	StationeryShop = { id = "StationeryShop", displayName = "Stationery Shop", unlockLevel = 46, population = 4130, buildCost = 40000, buildSeconds = 46 * HOUR, xp = 1655, queueSlots = 2, trayCapacity = 6, order = 24, color = { 120, 160, 230 } },
	FurnitureWorkshop = { id = "FurnitureWorkshop", displayName = "Furniture Workshop", unlockLevel = 47, population = 4760, buildCost = 48000, buildSeconds = 48 * HOUR, xp = 2892, queueSlots = 2, trayCapacity = 6, order = 25, color = { 180, 130, 90 } },
	-- Township's Shoe Factory (level 50): placed by the player
	Cobbler = { id = "Cobbler", displayName = "Cobbler", unlockLevel = 50, population = 5465, buildCost = 60000, buildSeconds = 52 * HOUR, xp = 2480, queueSlots = 2, trayCapacity = 6, order = 26, color = { 150, 100, 70 } },
	-- Township's Jewelry Store (level 53): cuts Quarry ore into jewellery; placed by the player
	Jeweler = { id = "Jeweler", displayName = "Jeweler", unlockLevel = 53, population = 5860, buildCost = 70000, buildSeconds = 56 * HOUR, xp = 2892, queueSlots = 1, trayCapacity = 6, order = 27, color = { 120, 200, 220 } },
	-- Township's Asian Restaurant (level 56): placed by the player
	SushiBar = { id = "SushiBar", displayName = "Sushi Bar", unlockLevel = 56, population = 7500, buildCost = 95000, buildSeconds = 60 * HOUR, xp = 3923, queueSlots = 2, trayCapacity = 6, order = 28, color = { 200, 60, 60 } },
	-- Township's Grill Factory (level 59): placed by the player
	GrillHouse = { id = "GrillHouse", displayName = "Grill House", unlockLevel = 59, population = 8700, buildCost = 115000, buildSeconds = 61 * HOUR, xp = 4748, queueSlots = 2, trayCapacity = 6, order = 29, color = { 90, 70, 60 } },
	-- Township's Perfume Factory (level 61): placed by the player
	Perfumery = { id = "Perfumery", displayName = "Perfumery", unlockLevel = 61, population = 9480, buildCost = 130000, buildSeconds = 62 * HOUR, xp = 5367, queueSlots = 2, trayCapacity = 6, order = 30, color = { 200, 150, 210 } },
	-- Township's Beverage Factory (level 65): placed by the player
	JuiceBar = { id = "JuiceBar", displayName = "Juice Bar", unlockLevel = 65, population = 10900, buildCost = 190000, buildSeconds = 63 * HOUR, xp = 7842, queueSlots = 2, trayCapacity = 6, order = 31, color = { 120, 200, 90 } },
	-- Township's Cake Factory (level 66): placed by the player
	CakeShop = { id = "CakeShop", displayName = "Cake Shop", unlockLevel = 66, population = 11000, buildCost = 200000, buildSeconds = 63 * HOUR, xp = 8255, queueSlots = 2, trayCapacity = 6, order = 32, color = { 245, 200, 215 } },
	-- Township's Hot Dog Factory (level 68) and French Restaurant (69): placed by the player
	HotDogStand = { id = "HotDogStand", displayName = "Hot Dog Stand", unlockLevel = 68, population = 11300, buildCost = 220000, buildSeconds = 64 * HOUR, xp = 9080, queueSlots = 2, trayCapacity = 6, order = 33, color = { 230, 80, 60 } },
	Bistro = { id = "Bistro", displayName = "Bistro", unlockLevel = 69, population = 12180, buildCost = 240000, buildSeconds = 65 * HOUR, xp = 9905, queueSlots = 2, trayCapacity = 6, order = 34, color = { 60, 80, 140 } },
	-- Township's Coffee Factory (level 72): placed by the player
	CoffeeHouse = { id = "CoffeeHouse", displayName = "Coffee House", unlockLevel = 72, population = 12600, buildCost = 270000, buildSeconds = 66 * HOUR, xp = 11142, queueSlots = 2, trayCapacity = 6, order = 35, color = { 120, 80, 50 } },
	-- Township's Down Feather Factory (level 74): placed by the player
	QuiltShop = { id = "QuiltShop", displayName = "Quilt Shop", unlockLevel = 74, population = 13100, buildCost = 290000, buildSeconds = 67 * HOUR, xp = 11967, queueSlots = 2, trayCapacity = 6, order = 36, color = { 200, 220, 240 } },
	-- Township's Doll Factory (level 76): placed by the player
	DollMaker = { id = "DollMaker", displayName = "Doll Maker", unlockLevel = 76, population = 13900, buildCost = 310000, buildSeconds = 67 * HOUR, xp = 12792, queueSlots = 2, trayCapacity = 6, order = 37, color = { 240, 180, 200 } },
	-- Township's Kitchenware Factory (level 78): placed by the player
	CookwareShop = { id = "CookwareShop", displayName = "Cookware Shop", unlockLevel = 78, population = 14500, buildCost = 340000, buildSeconds = 72 * HOUR, xp = 14030, queueSlots = 2, trayCapacity = 6, order = 38, color = { 200, 120, 80 } },
	-- Township's Music Factory (level 82): placed by the player
	MusicWorkshop = { id = "MusicWorkshop", displayName = "Music Workshop", unlockLevel = 82, population = 15700, buildCost = 390000, buildSeconds = 69 * HOUR, xp = 16092, queueSlots = 2, trayCapacity = 6, order = 39, color = { 150, 90, 60 } },
	-- Township's Tea Factory (level 84): placed by the player
	TeaHouse = { id = "TeaHouse", displayName = "Tea House", unlockLevel = 84, population = 16400, buildCost = 405000, buildSeconds = 72 * HOUR, xp = 16711, queueSlots = 2, trayCapacity = 6, order = 40, color = { 120, 170, 100 } },
	-- Township's Bouquet Factory (level 87): placed by the player
	FlowerShop = { id = "FlowerShop", displayName = "Flower Shop", unlockLevel = 87, population = 17200, buildCost = 420000, buildSeconds = 70 * HOUR, xp = 17330, queueSlots = 2, trayCapacity = 6, order = 41, color = { 240, 160, 190 } },
	-- Township's Italian Restaurant (level 92): placed by the player
	Trattoria = { id = "Trattoria", displayName = "Trattoria", unlockLevel = 92, population = 17845, buildCost = 450000, buildSeconds = 71 * HOUR, xp = 18567, queueSlots = 2, trayCapacity = 6, order = 42, color = { 200, 80, 60 } },
	-- Township's Festivities Factory (level 95): placed by the player
	PartyShop = { id = "PartyShop", displayName = "Party Shop", unlockLevel = 95, population = 18500, buildCost = 470000, buildSeconds = 72 * HOUR, xp = 19392, queueSlots = 2, trayCapacity = 6, order = 43, color = { 250, 200, 80 } },
	JamKitchen = { id = "JamKitchen", displayName = "Jam Kitchen", unlockLevel = 27, population = 1480, buildCost = 7100, buildSeconds = 26 * HOUR, xp = 297, queueSlots = 2, trayCapacity = 6, order = 13, color = { 200, 60, 90 }, land = 2 },
}

return table.freeze(Factories)
