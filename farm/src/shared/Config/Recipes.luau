--!strict
-- Recipes from Design/04 Factories & Recipes and Township Baseline Numbers §5 (Township baseline):
-- the 13 recipes that unlock by level 12, plus the content bank's (Config/Levels.built). Feed comes out 3 bags per batch; its sell price and
-- XP are per bag.

export type RecipeDef = {
	id: string, -- also the output item key
	displayName: string,
	factory: string,
	unlockLevel: number,
	inputs: { [string]: number },
	outputQty: number,
	seconds: number,
	sellPrice: number, -- per unit
	xp: number, -- XP per unit collected
	isFeed: boolean?, -- animal feed never shows up on order cards
}

local MIN = 60
local HOUR = 3600

-- stylua: ignore
local Recipes: { [string]: RecipeDef } = {
	-- Bakery
	Bread = { id = "Bread", displayName = "Bread", factory = "Bakery", unlockLevel = 2, inputs = { Wheat = 2 }, outputQty = 1, seconds = 5 * MIN, sellPrice = 5, xp = 2 },
	Cookies = { id = "Cookies", displayName = "Cookies", factory = "Bakery", unlockLevel = 5, inputs = { Wheat = 2, Eggs = 2 }, outputQty = 1, seconds = 15 * MIN, sellPrice = 44, xp = 19 },
	Bagel = { id = "Bagel", displayName = "Bagel", factory = "Bakery", unlockLevel = 8, inputs = { Wheat = 2, Eggs = 3, Sugar = 1 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 55, xp = 24 },
	-- Feed Mill
	CowFeed = { id = "CowFeed", displayName = "Cow Feed", factory = "FeedMill", unlockLevel = 3, inputs = { Wheat = 2, Corn = 1 }, outputQty = 3, seconds = 5 * MIN, sellPrice = 3, xp = 1, isFeed = true },
	ChickenFeed = { id = "ChickenFeed", displayName = "Chicken Feed", factory = "FeedMill", unlockLevel = 5, inputs = { Wheat = 2, Carrots = 1 }, outputQty = 3, seconds = 10 * MIN, sellPrice = 4, xp = 2, isFeed = true },
	SheepFeed = { id = "SheepFeed", displayName = "Sheep Feed", factory = "FeedMill", unlockLevel = 10, inputs = { Corn = 2, Carrots = 2 }, outputQty = 3, seconds = 20 * MIN, sellPrice = 5, xp = 2, isFeed = true },
	-- Dairy
	Cream = { id = "Cream", displayName = "Cream", factory = "Dairy", unlockLevel = 4, inputs = { Milk = 1 }, outputQty = 1, seconds = 15 * MIN, sellPrice = 12, xp = 5 },
	Cheese = { id = "Cheese", displayName = "Cheese", factory = "Dairy", unlockLevel = 6, inputs = { Milk = 2 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 25, xp = 11 },
	Butter = { id = "Butter", displayName = "Butter", factory = "Dairy", unlockLevel = 11, inputs = { Milk = 3 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 39, xp = 17 },
	-- Sugar Mill
	Sugar = { id = "Sugar", displayName = "Sugar", factory = "SugarMill", unlockLevel = 7, inputs = { Sugarcane = 1 }, outputQty = 1, seconds = 20 * MIN, sellPrice = 14, xp = 6 },
	CaneSyrup = { id = "CaneSyrup", displayName = "Cane Syrup", factory = "SugarMill", unlockLevel = 17, inputs = { Sugarcane = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 29, xp = 12 }, -- content bank
	-- Textile Mill
	CottonFabric = { id = "CottonFabric", displayName = "Cotton Fabric", factory = "TextileMill", unlockLevel = 9, inputs = { Cotton = 2 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 37, xp = 16 },
	Yarn = { id = "Yarn", displayName = "Yarn", factory = "TextileMill", unlockLevel = 10, inputs = { Wool = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 61, xp = 26 },
	Shirt = { id = "Shirt", displayName = "Shirt", factory = "TextileMill", unlockLevel = 12, inputs = { CottonFabric = 1 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 45, xp = 19 },
	WoolScarf = { id = "WoolScarf", displayName = "Wool Scarf", factory = "TextileMill", unlockLevel = 14, inputs = { Yarn = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 76, xp = 33 }, -- content bank
	-- Snack Factory (content bank)
	Popcorn = { id = "Popcorn", displayName = "Popcorn", factory = "SnackFactory", unlockLevel = 14, inputs = { Corn = 2 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 12, xp = 5 },
	CornChips = { id = "CornChips", displayName = "Corn Chips", factory = "SnackFactory", unlockLevel = 17, inputs = { Corn = 3 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 19, xp = 8 },
	-- Diner (content bank)
	StrawberryMilkshake = { id = "StrawberryMilkshake", displayName = "Strawberry Milkshake", factory = "Diner", unlockLevel = 16, inputs = { Milk = 2, Strawberries = 1 }, outputQty = 1, seconds = 15 * MIN, sellPrice = 30, xp = 13 },
	FarmBurger = { id = "FarmBurger", displayName = "Farm Burger", factory = "Diner", unlockLevel = 16, inputs = { Bread = 2, Cheese = 1, Tomatoes = 1 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 57, xp = 24 },
}

return table.freeze(Recipes)
