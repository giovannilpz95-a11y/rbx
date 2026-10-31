--!strict
-- Airship Freight (Features/F04): the Blimp Mast and its Cargo Blimp, on the Township baseline
-- for the airport and airplane (Wiki Data - Side Systems §4; wiki Airport and Airport
-- Quantities pages). Names, the blimp and the chest contents are ours.
--
-- Township: the airport is restored at level 17 for 1,500 Coins (24h, 66 XP). A plane lands
-- with 3 rows of 2-3 crates and has 15 hours to be loaded and sent; time running out sends it
-- away with no row rewards. The next one comes 5 hours after it leaves, and only lands once
-- the player is in the game. Each crate pays Coins and XP when filled, each full row pays
-- Coins and leaderboard points (rows are worth more the further down they are: 382 Coins for
-- row 1, 1,146 for rows 1 and 2 in the wiki's example), and a full load adds a chest. One
-- crate per row can be flagged for help. Skipping the wait costs up to 232 T-cash on the new
-- scale (about 9 Gems) and is free in the last 30 seconds.

local HOUR = 3600

export type Range = { number } -- { low, high } items per crate

-- Items per crate from the wiki's Airport Quantities table (Township's goods matched to ours).
-- Only goods listed here go on a blimp: Bars, Dough, feed and building materials never do.
-- stylua: ignore
local crates: { [string]: Range } = {
	-- Crops
	Wheat = { 18, 99 }, Corn = { 47, 81 }, Carrots = { 19, 40 }, Sugarcane = { 11, 27 },
	Cotton = { 8, 20 }, Strawberries = { 5, 14 }, Tomatoes = { 6, 15 }, PineTrees = { 6, 11 },
	Potatoes = { 3, 15 }, Cocoa = { 2, 6 }, RubberTrees = { 1, 6 }, CorkOak = { 2, 3 }, Peppers = { 6, 9 }, Silk = { 1, 5 },
	-- Animal goods
	Milk = { 8, 20 }, Eggs = { 9, 15 }, Wool = { 2, 10 }, Honeycomb = { 1, 7 }, Bacon = { 2, 4 },
	-- Bakery
	Bread = { 5, 14 }, Cookies = { 4, 9 }, Bagel = { 2, 6 }, GardenPizza = { 1, 3 }, PotatoBread = { 2, 4 },
	-- Dairy
	Cream = { 4, 11 }, Cheese = { 3, 10 }, Butter = { 2, 6 }, Yogurt = { 1, 4 },
	-- Sugar Mill
	Sugar = { 5, 10 }, CaneSyrup = { 3, 7 }, Caramel = { 2, 4 }, HoneyCaramel = { 1, 2 },
	-- Textile Mill
	CottonFabric = { 4, 10 }, Yarn = { 1, 5 }, SilkFabric = { 2, 4 }, Shirt = { 2, 5 },
	WoolScarf = { 1, 4 }, PatchworkQuilt = { 1, 3 }, SunHat = { 1, 2 }, Dress = { 1, 2 }, Suit = { 1, 2 },
	NylonThread = { 1, 3 },
	-- Snack Factory
	Popcorn = { 3, 9 }, CornChips = { 2, 5 }, BerryGranola = { 2, 7 }, PotatoChips = { 1, 3 },
	-- Diner
	FarmBurger = { 4, 8 }, StrawberryMilkshake = { 4, 11 }, BerrySandwich = { 2, 5 }, Fries = { 2, 5 },
	-- Ice Cream Parlor
	IceCreamCone = { 3, 10 }, StrawberryIcePop = { 1, 4 }, FrozenYogurt = { 1, 2 }, IceCreamBar = { 1, 2 },
	-- Paper Mill
	Paper = { 1, 4 }, PaperTowel = { 1, 4 }, Wallpaper = { 1, 2 },
	-- Pastry Shop
	Muffin = { 2, 7 }, Brownie = { 2, 5 }, Cupcake = { 2, 3 }, Donut = { 2, 3 }, Cheesecake = { 1, 2 },
	HoneyGingerbread = { 1, 4 },
	-- Prep Kitchen, Molding Works
	FrozenVegetables = { 2, 3 }, PlasticBottle = { 2, 3 }, Toys = { 1, 3 }, Ball = { 1, 2 }, InflatableBoat = { 1, 2 },
	-- Jam Kitchen, Rubber Works
	StrawberryJam = { 1, 3 }, Rubber = { 2, 4 }, Plastic = { 2, 3 }, Glue = { 1, 3 },
	-- Homewares Shop
	ScrubBrush = { 1, 2 }, SoapDispenser = { 1, 2 }, Clothesline = { 1, 2 }, Plunger = { 1, 2 },
	-- Cantina, Snack Factory
	ChiliSauce = { 1, 3 }, GlazedBacon = { 1, 2 },
	-- Candy Factory
	JellyBeans = { 1, 3 }, Toffee = { 1, 3 }, CandyCane = { 1, 2 }, Dumplings = { 1, 2 },
}

return table.freeze({
	-- The mast's repair (Township's airport restoration)
	unlockLevel = 17,
	repairCoins = 1500,
	repairSeconds = 24 * HOUR,
	repairXp = 66,
	land = 1, -- the mast stands in the West Meadow (land expansion 1)

	loadSeconds = 15 * HOUR, -- docked: fill and send before this runs out
	gapSeconds = 5 * HOUR, -- from leaving to the next arrival
	skipGemsMax = 9, -- Gems to call the next blimp at once with the whole gap to go
	freeSkipSeconds = 30,

	rows = 3,
	minCrates = 2, -- per row
	maxCrates = 3,

	crates = table.freeze(crates),
	-- Crates ask for the low end of the range at `qtyFromLevel`, and their top grows to the
	-- whole range by `qtyFullLevel` ("less for lower levels, more as you gain levels"). At
	-- the start the top is `qtyStartShare` of the way from low to high. (First-pass.)
	qtyFromLevel = 17,
	qtyFullLevel = 60,
	qtyStartShare = 0.35,
	-- Factory goods are picked this many times as often as crops and animal goods, so loads
	-- lean towards mixed goods (F04: keep the train about raw goods, the blimp about goods).
	productWeight = 2,

	-- Rewards (first-pass; the wiki gives only the row example above). A crate pays its goods'
	-- sale value times crateCoinMult in Coins, and their XP times crateXpMult. A full row pays
	-- its crates' sale value times rowCoinMult[row] in Coins, plus the Sky Miles of its crates
	-- (1 per milesPerValue Coins of goods, 1 to milesMax each; Township's 1-3 points a crate).
	crateCoinMult = 1.2,
	crateXpMult = 1,
	rowCoinMult = table.freeze({ 0.5, 1, 1.5 }),
	milesPerValue = 150,
	milesMax = 3,

	-- The Full Hold chest for loading every crate: fixed when the load is made and shown up
	-- front, so there's no paid randomness. One Bar, one tool stack and one material stack,
	-- each drawn by weight (Township's chest: a gem and two prizes such as ingots, building
	-- materials and mining tools).
	chest = table.freeze({
		bars = table.freeze({
			table.freeze({ item = "CopperBar", qty = 1, weight = 4 }),
			table.freeze({ item = "SilverBar", qty = 1, weight = 3 }),
			table.freeze({ item = "GoldBar", qty = 1, weight = 2 }),
			table.freeze({ item = "PlatinumBar", qty = 1, weight = 1 }),
		}),
		tools = table.freeze({
			table.freeze({ item = "Shovel", qty = 1, weight = 1 }),
			table.freeze({ item = "Axe", qty = 1, weight = 1 }),
			table.freeze({ item = "Saw", qty = 1, weight = 1 }),
			table.freeze({ item = "Pickaxe", qty = 3, weight = 1 }),
		}),
		materials = table.freeze({
			table.freeze({ item = "Nails", qty = 2, weight = 1 }),
			table.freeze({ item = "Hinges", qty = 2, weight = 1 }),
			table.freeze({ item = "Paint", qty = 2, weight = 1 }),
			table.freeze({ item = "Bricks", qty = 2, weight = 1 }),
			table.freeze({ item = "Planks", qty = 2, weight = 1 }),
			table.freeze({ item = "Panes", qty = 2, weight = 1 }),
		}),
	}),
})
