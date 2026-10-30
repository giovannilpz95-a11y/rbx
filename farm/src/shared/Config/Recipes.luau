--!strict
-- Recipes from Design/04 Factories & Recipes and Township Baseline Numbers §5 (Township baseline):
-- the 13 recipes that unlock by level 12, plus the content bank's (Config/Levels.built). Feed comes out 3 bags per batch; its sell price and
-- XP are per bag.

export type RecipeDef = {
	id: string, -- also the output item key
	displayName: string,
	factory: string, -- also made by its copies (Factories `makes`)
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
	GardenPizza = { id = "GardenPizza", displayName = "Garden Pizza", factory = "Bakery", unlockLevel = 22, inputs = { Wheat = 2, Tomatoes = 2, Cheese = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 68, xp = 29 }, -- content bank
	-- Feed Mill
	CowFeed = { id = "CowFeed", displayName = "Cow Feed", factory = "FeedMill", unlockLevel = 3, inputs = { Wheat = 2, Corn = 1 }, outputQty = 3, seconds = 5 * MIN, sellPrice = 3, xp = 1, isFeed = true },
	ChickenFeed = { id = "ChickenFeed", displayName = "Chicken Feed", factory = "FeedMill", unlockLevel = 5, inputs = { Wheat = 2, Carrots = 1 }, outputQty = 3, seconds = 10 * MIN, sellPrice = 4, xp = 2, isFeed = true },
	SheepFeed = { id = "SheepFeed", displayName = "Sheep Feed", factory = "FeedMill", unlockLevel = 10, inputs = { Corn = 2, Carrots = 2 }, outputQty = 3, seconds = 20 * MIN, sellPrice = 5, xp = 2, isFeed = true },
	-- Dairy
	Cream = { id = "Cream", displayName = "Cream", factory = "Dairy", unlockLevel = 4, inputs = { Milk = 1 }, outputQty = 1, seconds = 15 * MIN, sellPrice = 12, xp = 5 },
	Cheese = { id = "Cheese", displayName = "Cheese", factory = "Dairy", unlockLevel = 6, inputs = { Milk = 2 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 25, xp = 11 },
	Butter = { id = "Butter", displayName = "Butter", factory = "Dairy", unlockLevel = 11, inputs = { Milk = 3 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 39, xp = 17 },
	Yogurt = { id = "Yogurt", displayName = "Yogurt", factory = "Dairy", unlockLevel = 21, inputs = { Milk = 4 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 53, xp = 23 }, -- content bank
	-- Sugar Mill
	Sugar = { id = "Sugar", displayName = "Sugar", factory = "SugarMill", unlockLevel = 7, inputs = { Sugarcane = 1 }, outputQty = 1, seconds = 20 * MIN, sellPrice = 14, xp = 6 },
	CaneSyrup = { id = "CaneSyrup", displayName = "Cane Syrup", factory = "SugarMill", unlockLevel = 17, inputs = { Sugarcane = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 29, xp = 12 }, -- content bank
	-- Textile Mill
	CottonFabric = { id = "CottonFabric", displayName = "Cotton Fabric", factory = "TextileMill", unlockLevel = 9, inputs = { Cotton = 2 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 37, xp = 16 },
	Yarn = { id = "Yarn", displayName = "Yarn", factory = "TextileMill", unlockLevel = 10, inputs = { Wool = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 61, xp = 26 },
	Shirt = { id = "Shirt", displayName = "Shirt", factory = "TextileMill", unlockLevel = 12, inputs = { CottonFabric = 1 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 45, xp = 19 },
	PatchworkQuilt = { id = "PatchworkQuilt", displayName = "Patchwork Quilt", factory = "TextileMill", unlockLevel = 20, inputs = { CottonFabric = 1, Yarn = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 125, xp = 54 }, -- content bank
	WoolScarf = { id = "WoolScarf", displayName = "Wool Scarf", factory = "TextileMill", unlockLevel = 14, inputs = { Yarn = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 76, xp = 33 }, -- content bank
	-- Snack Factory (content bank)
	Popcorn = { id = "Popcorn", displayName = "Popcorn", factory = "SnackFactory", unlockLevel = 14, inputs = { Corn = 2 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 12, xp = 5 },
	BerryGranola = { id = "BerryGranola", displayName = "Berry Granola", factory = "SnackFactory", unlockLevel = 19, inputs = { Wheat = 2, Strawberries = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 29, xp = 12 },
	PotatoChips = { id = "PotatoChips", displayName = "Potato Chips", factory = "SnackFactory", unlockLevel = 22, inputs = { Potatoes = 2 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 69, xp = 30 },
	CornChips = { id = "CornChips", displayName = "Corn Chips", factory = "SnackFactory", unlockLevel = 17, inputs = { Corn = 3 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 19, xp = 8 },
	-- Diner (content bank)
	StrawberryMilkshake = { id = "StrawberryMilkshake", displayName = "Strawberry Milkshake", factory = "Diner", unlockLevel = 16, inputs = { Milk = 2, Strawberries = 1 }, outputQty = 1, seconds = 15 * MIN, sellPrice = 30, xp = 13 },
	FarmBurger = { id = "FarmBurger", displayName = "Farm Burger", factory = "Diner", unlockLevel = 16, inputs = { Bread = 2, Cheese = 1, Tomatoes = 1 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 57, xp = 24 },
	BerrySandwich = { id = "BerrySandwich", displayName = "Berry Sandwich", factory = "Diner", unlockLevel = 19, inputs = { Bread = 1, Butter = 1, Strawberries = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 80, xp = 34 },
	-- Paper Mill (content bank)
	Paper = { id = "Paper", displayName = "Paper", factory = "PaperMill", unlockLevel = 18, inputs = { PineTrees = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 19, xp = 8 },
	PaperTowel = { id = "PaperTowel", displayName = "Paper Towels", factory = "PaperMill", unlockLevel = 23, inputs = { PineTrees = 2 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 39, xp = 17 },
	-- Ice Cream Parlor (content bank)
	IceCreamCone = { id = "IceCreamCone", displayName = "Ice Cream Cone", factory = "IceCreamParlor", unlockLevel = 20, inputs = { Milk = 1, Cream = 1, Sugar = 1 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 39, xp = 17 },
	StrawberryIcePop = { id = "StrawberryIcePop", displayName = "Strawberry Ice Pop", factory = "IceCreamParlor", unlockLevel = 21, inputs = { Strawberries = 2, Sugar = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 45, xp = 19 },
	FrozenYogurt = { id = "FrozenYogurt", displayName = "Frozen Yogurt", factory = "IceCreamParlor", unlockLevel = 23, inputs = { Yogurt = 1, Cream = 1 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 87, xp = 37 },
}

return table.freeze(Recipes)
