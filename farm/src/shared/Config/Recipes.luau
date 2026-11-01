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
	fromOreShed: boolean?, -- its inputs are Quarry ore, taken from the Ore Shed, not the Barn
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
	PotatoBread = { id = "PotatoBread", displayName = "Potato Bread", factory = "Bakery", unlockLevel = 26, inputs = { Wheat = 2, Eggs = 4, Potatoes = 2 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 158, xp = 68 }, -- content bank
	BananaBread = { id = "BananaBread", displayName = "Banana Bread", factory = "Bakery", unlockLevel = 41, inputs = { Wheat = 2, Eggs = 2, Butter = 1, Bananas = 3 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 294, xp = 126 }, -- content bank, Coconut Atoll
	-- Feed Mill
	CowFeed = { id = "CowFeed", displayName = "Cow Feed", factory = "FeedMill", unlockLevel = 3, inputs = { Wheat = 2, Corn = 1 }, outputQty = 3, seconds = 5 * MIN, sellPrice = 3, xp = 1, isFeed = true },
	ChickenFeed = { id = "ChickenFeed", displayName = "Chicken Feed", factory = "FeedMill", unlockLevel = 5, inputs = { Wheat = 2, Carrots = 1 }, outputQty = 3, seconds = 10 * MIN, sellPrice = 4, xp = 2, isFeed = true },
	BeeFeed = { id = "BeeFeed", displayName = "Bee Feed", factory = "FeedMill", unlockLevel = 35, inputs = { Wheat = 3, Sugarcane = 1 }, outputQty = 3, seconds = 30 * MIN, sellPrice = 7, xp = 3, isFeed = true },
	PigFeed = { id = "PigFeed", displayName = "Pig Feed", factory = "FeedMill", unlockLevel = 42, inputs = { Wheat = 2, Carrots = 2, Corn = 1 }, outputQty = 3, seconds = 40 * MIN, sellPrice = 10, xp = 4, isFeed = true },
	SheepFeed = { id = "SheepFeed", displayName = "Sheep Feed", factory = "FeedMill", unlockLevel = 10, inputs = { Corn = 2, Carrots = 2 }, outputQty = 3, seconds = 20 * MIN, sellPrice = 5, xp = 2, isFeed = true },
	-- Dairy
	PeachYogurt = { id = "PeachYogurt", displayName = "Peach Yogurt", factory = "Dairy", unlockLevel = 47, inputs = { Milk = 2, Peaches = 2 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 157, xp = 67 },
	Cream = { id = "Cream", displayName = "Cream", factory = "Dairy", unlockLevel = 4, inputs = { Milk = 1 }, outputQty = 1, seconds = 15 * MIN, sellPrice = 12, xp = 5 },
	Cheese = { id = "Cheese", displayName = "Cheese", factory = "Dairy", unlockLevel = 6, inputs = { Milk = 2 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 25, xp = 11 },
	Butter = { id = "Butter", displayName = "Butter", factory = "Dairy", unlockLevel = 11, inputs = { Milk = 3 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 39, xp = 17 },
	Yogurt = { id = "Yogurt", displayName = "Yogurt", factory = "Dairy", unlockLevel = 21, inputs = { Milk = 4 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 53, xp = 23 }, -- content bank
	-- Sugar Mill
	Sugar = { id = "Sugar", displayName = "Sugar", factory = "SugarMill", unlockLevel = 7, inputs = { Sugarcane = 1 }, outputQty = 1, seconds = 20 * MIN, sellPrice = 14, xp = 6 },
	CaneSyrup = { id = "CaneSyrup", displayName = "Cane Syrup", factory = "SugarMill", unlockLevel = 17, inputs = { Sugarcane = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 29, xp = 12 }, -- content bank
	Caramel = { id = "Caramel", displayName = "Caramel", factory = "SugarMill", unlockLevel = 24, inputs = { Sugarcane = 3 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 45, xp = 19 }, -- content bank
	HoneyCaramel = { id = "HoneyCaramel", displayName = "Honey Caramel", factory = "SugarMill", unlockLevel = 36, inputs = { Honeycomb = 1, Sugarcane = 1 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 68, xp = 29 }, -- content bank
	-- Textile Mill
	CottonFabric = { id = "CottonFabric", displayName = "Cotton Fabric", factory = "TextileMill", unlockLevel = 9, inputs = { Cotton = 2 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 37, xp = 16 },
	Yarn = { id = "Yarn", displayName = "Yarn", factory = "TextileMill", unlockLevel = 10, inputs = { Wool = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 61, xp = 26 },
	SilkFabric = { id = "SilkFabric", displayName = "Silk Fabric", factory = "TextileMill", unlockLevel = 31, inputs = { Silk = 2 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 140, xp = 60 }, -- content bank
	NylonThread = { id = "NylonThread", displayName = "Nylon Thread", factory = "TextileMill", unlockLevel = 36, inputs = { RubberTrees = 3 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 111, xp = 48 }, -- content bank
	-- Tailor (Township's Tailor Shop)
	Shirt = { id = "Shirt", displayName = "Shirt", factory = "Tailor", unlockLevel = 12, inputs = { CottonFabric = 1 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 45, xp = 19 },
	SunHat = { id = "SunHat", displayName = "Sun Hat", factory = "Tailor", unlockLevel = 31, inputs = { CottonFabric = 1, SilkFabric = 1 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 231, xp = 99 }, -- content bank
	PatchworkQuilt = { id = "PatchworkQuilt", displayName = "Patchwork Quilt", factory = "Tailor", unlockLevel = 20, inputs = { CottonFabric = 1, Yarn = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 125, xp = 54 }, -- content bank
	Dress = { id = "Dress", displayName = "Dress", factory = "Tailor", unlockLevel = 33, inputs = { Yarn = 1, SilkFabric = 1 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 268, xp = 115 }, -- content bank
	Suit = { id = "Suit", displayName = "Suit", factory = "Tailor", unlockLevel = 36, inputs = { Yarn = 1, CottonFabric = 1, SilkFabric = 1 }, outputQty = 1, seconds = 4 * HOUR, sellPrice = 330, xp = 141 }, -- content bank
	WoolScarf = { id = "WoolScarf", displayName = "Wool Scarf", factory = "Tailor", unlockLevel = 14, inputs = { Yarn = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 76, xp = 33 }, -- content bank
	-- Snack Factory (content bank)
	GlazedBacon = { id = "GlazedBacon", displayName = "Glazed Bacon", factory = "SnackFactory", unlockLevel = 43, inputs = { Bacon = 2, CaneSyrup = 1 }, outputQty = 1, seconds = 1 * HOUR + 20 * MIN, sellPrice = 115, xp = 49 },
	Canape = { id = "Canape", displayName = "Canapé", factory = "SnackFactory", unlockLevel = 42, inputs = { Olives = 2, Grapes = 2, Cheese = 1 }, outputQty = 1, seconds = 15 * MIN, sellPrice = 307, xp = 132 },
	Popcorn = { id = "Popcorn", displayName = "Popcorn", factory = "SnackFactory", unlockLevel = 14, inputs = { Corn = 2 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 12, xp = 5 },
	BerryGranola = { id = "BerryGranola", displayName = "Berry Granola", factory = "SnackFactory", unlockLevel = 19, inputs = { Wheat = 2, Strawberries = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 29, xp = 12 },
	PotatoChips = { id = "PotatoChips", displayName = "Potato Chips", factory = "SnackFactory", unlockLevel = 22, inputs = { Potatoes = 2 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 69, xp = 30 },
	CornChips = { id = "CornChips", displayName = "Corn Chips", factory = "SnackFactory", unlockLevel = 17, inputs = { Corn = 3 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 19, xp = 8 },
	-- Diner (content bank)
	BakedPotato = { id = "BakedPotato", displayName = "Baked Potato", factory = "Diner", unlockLevel = 46, inputs = { Potatoes = 2, Bacon = 1, Cheese = 1 }, outputQty = 1, seconds = 50 * MIN, sellPrice = 111, xp = 48 },
	StrawberryMilkshake = { id = "StrawberryMilkshake", displayName = "Strawberry Milkshake", factory = "Diner", unlockLevel = 16, inputs = { Milk = 2, Strawberries = 1 }, outputQty = 1, seconds = 15 * MIN, sellPrice = 30, xp = 13 },
	FarmBurger = { id = "FarmBurger", displayName = "Farm Burger", factory = "Diner", unlockLevel = 16, inputs = { Bread = 2, Cheese = 1, Tomatoes = 1 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 57, xp = 24 },
	BerrySandwich = { id = "BerrySandwich", displayName = "Berry Sandwich", factory = "Diner", unlockLevel = 19, inputs = { Bread = 1, Butter = 1, Strawberries = 2 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 80, xp = 34 },
	Fries = { id = "Fries", displayName = "Fries", factory = "Diner", unlockLevel = 28, inputs = { Potatoes = 2, Cream = 1, Tomatoes = 2 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 88, xp = 38 },
	-- Paper Mill (content bank)
	Paper = { id = "Paper", displayName = "Paper", factory = "PaperMill", unlockLevel = 18, inputs = { PineTrees = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 19, xp = 8 },
	Wallpaper = { id = "Wallpaper", displayName = "Wallpaper", factory = "PaperMill", unlockLevel = 30, inputs = { PineTrees = 2, Rubber = 1 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 147, xp = 63 },
	PaperTowel = { id = "PaperTowel", displayName = "Paper Towels", factory = "PaperMill", unlockLevel = 23, inputs = { PineTrees = 2 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 39, xp = 17 },
	-- Ice Cream Parlor (content bank)
	IceCreamCone = { id = "IceCreamCone", displayName = "Ice Cream Cone", factory = "IceCreamParlor", unlockLevel = 20, inputs = { Milk = 1, Cream = 1, Sugar = 1 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 39, xp = 17 },
	StrawberryIcePop = { id = "StrawberryIcePop", displayName = "Strawberry Ice Pop", factory = "IceCreamParlor", unlockLevel = 21, inputs = { Strawberries = 2, Sugar = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 45, xp = 19 },
	FrozenYogurt = { id = "FrozenYogurt", displayName = "Frozen Yogurt", factory = "IceCreamParlor", unlockLevel = 23, inputs = { Yogurt = 1, Cream = 1 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 87, xp = 37 },
	IceCreamBar = { id = "IceCreamBar", displayName = "Ice Cream Bar", factory = "IceCreamParlor", unlockLevel = 25, inputs = { CaneSyrup = 1, Cocoa = 1, PineTrees = 1 }, outputQty = 1, seconds = 4 * HOUR, sellPrice = 148, xp = 63 },
	-- Pastry Shop (content bank)
	CoconutMacaroon = { id = "CoconutMacaroon", displayName = "Coconut Macaroon", factory = "PastryShop", unlockLevel = 46, inputs = { Coconuts = 2, Eggs = 2, Sugar = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 253, xp = 108 },
	KeyLimePie = { id = "KeyLimePie", displayName = "Key Lime Pie", factory = "PastryShop", unlockLevel = 44, inputs = { Wheat = 3, KeyLimes = 2, Sugar = 1, Cream = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 285, xp = 122 },
	HoneyGingerbread = { id = "HoneyGingerbread", displayName = "Honey Gingerbread", factory = "PastryShop", unlockLevel = 37, inputs = { Wheat = 3, Honeycomb = 2, Eggs = 1 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 119, xp = 51 },
	Muffin = { id = "Muffin", displayName = "Muffin", factory = "PastryShop", unlockLevel = 24, inputs = { Wheat = 3, Sugar = 1, Eggs = 4 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 68, xp = 29 },
	Cupcake = { id = "Cupcake", displayName = "Cupcake", factory = "PastryShop", unlockLevel = 30, inputs = { Sugar = 1, Eggs = 5, Cream = 1 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 93, xp = 40 },
	Donut = { id = "Donut", displayName = "Donut", factory = "PastryShop", unlockLevel = 33, inputs = { Bagel = 1, Caramel = 1, Cocoa = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 149, xp = 64 },
	Cheesecake = { id = "Cheesecake", displayName = "Cheesecake", factory = "PastryShop", unlockLevel = 36, inputs = { Cookies = 1, Cheese = 1, CaneSyrup = 1, Strawberries = 2 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 160, xp = 69 },
	Brownie = { id = "Brownie", displayName = "Brownie", factory = "PastryShop", unlockLevel = 27, inputs = { Cocoa = 2, CaneSyrup = 1, Butter = 1 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 128, xp = 55 },
	-- Prep Kitchen (content bank)
	FrozenVegetables = { id = "FrozenVegetables", displayName = "Frozen Vegetables", factory = "PrepKitchen", unlockLevel = 34, inputs = { Tomatoes = 1, Corn = 1, Carrots = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 26, xp = 11 },
	Dumplings = { id = "Dumplings", displayName = "Dumplings", factory = "PrepKitchen", unlockLevel = 42, inputs = { Dough = 2, Bacon = 2 }, outputQty = 1, seconds = 3 * HOUR + 30 * MIN, sellPrice = 98, xp = 42 },
	-- Molding Works (content bank)
	InflatableBoat = { id = "InflatableBoat", displayName = "Inflatable Boat", factory = "MoldingWorks", unlockLevel = 38, inputs = { Rubber = 2, Glue = 1 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 236, xp = 101 },
	Ball = { id = "Ball", displayName = "Ball", factory = "MoldingWorks", unlockLevel = 37, inputs = { Plastic = 1, Glue = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 235, xp = 101 },
	Toys = { id = "Toys", displayName = "Toys", factory = "MoldingWorks", unlockLevel = 35, inputs = { Plastic = 1, Rubber = 1 }, outputQty = 1, seconds = 45 * MIN, sellPrice = 131, xp = 56 },
	PlasticBottle = { id = "PlasticBottle", displayName = "Plastic Bottle", factory = "MoldingWorks", unlockLevel = 34, inputs = { Plastic = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 91, xp = 39 },
	Dough = { id = "Dough", displayName = "Dough", factory = "PrepKitchen", unlockLevel = 31, inputs = { Wheat = 3 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 4, xp = 2 },
	-- Rubber Works (content bank)
	Glue = { id = "Glue", displayName = "Glue", factory = "RubberWorks", unlockLevel = 37, inputs = { RubberTrees = 3 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 111, xp = 48 },
	-- Candy Factory (content bank)
	JellyBeans = { id = "JellyBeans", displayName = "Jelly Beans", factory = "CandyFactory", unlockLevel = 39, inputs = { Strawberries = 3, CaneSyrup = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 79, xp = 34 },
	Toffee = { id = "Toffee", displayName = "Toffee", factory = "CandyFactory", unlockLevel = 40, inputs = { Caramel = 1, Butter = 1 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 112, xp = 48 },
	CandyCane = { id = "CandyCane", displayName = "Candy Cane", factory = "CandyFactory", unlockLevel = 42, inputs = { Caramel = 1, Cream = 1, Paper = 1 }, outputQty = 1, seconds = 4 * HOUR, sellPrice = 105, xp = 45 },
	-- Cantina (content bank)
	ChiliSauce = { id = "ChiliSauce", displayName = "Chili Sauce", factory = "Cantina", unlockLevel = 43, inputs = { Tomatoes = 3, Peppers = 3, Sugar = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 144, xp = 62 },
	Burrito = { id = "Burrito", displayName = "Burrito", factory = "Cantina", unlockLevel = 44, inputs = { Wheat = 2, Bacon = 2, Tomatoes = 1 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 97, xp = 42 },
	Chocolate = { id = "Chocolate", displayName = "Chocolate", factory = "CandyFactory", unlockLevel = 45, inputs = { Cocoa = 3, Cream = 1, Sugar = 1 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 108, xp = 46 },
	Nachos = { id = "Nachos", displayName = "Nachos", factory = "Cantina", unlockLevel = 46, inputs = { CornChips = 1, Cheese = 1, Peppers = 2 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 112, xp = 48 },
	-- Stationery Shop and Furniture Workshop (content bank)
	Eraser = { id = "Eraser", displayName = "Eraser", factory = "StationeryShop", unlockLevel = 46, inputs = { RubberTrees = 3 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 111, xp = 48 },
	StickyNotes = { id = "StickyNotes", displayName = "Sticky Notes", factory = "StationeryShop", unlockLevel = 47, inputs = { Paper = 3, Glue = 1 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 219, xp = 94 },
	Table = { id = "Table", displayName = "Table", factory = "FurnitureWorkshop", unlockLevel = 47, inputs = { PineTrees = 3 }, outputQty = 1, seconds = 4 * HOUR, sellPrice = 62, xp = 27 },
	Chair = { id = "Chair", displayName = "Chair", factory = "FurnitureWorkshop", unlockLevel = 47, inputs = { Plastic = 1 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 97, xp = 71 },
	Lollipop = { id = "Lollipop", displayName = "Lollipop", factory = "CandyFactory", unlockLevel = 48, inputs = { Strawberries = 2, CaneSyrup = 1, PineTrees = 2 }, outputQty = 1, seconds = 5 * HOUR, sellPrice = 117, xp = 50 },
	Couch = { id = "Couch", displayName = "Couch", factory = "FurnitureWorkshop", unlockLevel = 48, inputs = { PineTrees = 2, CottonFabric = 1 }, outputQty = 1, seconds = 6 * HOUR, sellPrice = 100, xp = 43 },
	Shuttlecock = { id = "Shuttlecock", displayName = "Shuttlecock", factory = "MoldingWorks", unlockLevel = 49, inputs = { DownFeather = 2, Plastic = 1 }, outputQty = 1, seconds = 40 * MIN, sellPrice = 117, xp = 50 },
	FeatherDuster = { id = "FeatherDuster", displayName = "Feather Duster", factory = "HomewaresShop", unlockLevel = 49, inputs = { Sugarcane = 1, ColorfulFeather = 3 }, outputQty = 1, seconds = 3 * HOUR + 30 * MIN, sellPrice = 136, xp = 58 },
	-- Cobbler (content bank)
	FlipFlops = { id = "FlipFlops", displayName = "Flip Flops", factory = "Cobbler", unlockLevel = 50, inputs = { Rubber = 1 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 44, xp = 19 },
	Sandals = { id = "Sandals", displayName = "Sandals", factory = "Cobbler", unlockLevel = 51, inputs = { CorkOak = 3, NylonThread = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 238, xp = 102 },
	-- Level 50-51 goods at older factories
	FeatherHat = { id = "FeatherHat", displayName = "Feather Hat", factory = "Tailor", unlockLevel = 50, inputs = { CottonFabric = 1, SilkFabric = 1, ColorfulFeather = 1 }, outputQty = 1, seconds = 2 * HOUR + 45 * MIN, sellPrice = 274, xp = 117 },
	MintChocIceCream = { id = "MintChocIceCream", displayName = "Mint Choc Ice Cream", factory = "IceCreamParlor", unlockLevel = 50, inputs = { Milk = 1, Mint = 2, Chocolate = 1 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 214, xp = 92 },
	PineappleSorbet = { id = "PineappleSorbet", displayName = "Pineapple Sorbet", factory = "IceCreamParlor", unlockLevel = 51, inputs = { CaneSyrup = 1, Pineapples = 2 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 343, xp = 147 },
	HoneyMarshmallow = { id = "HoneyMarshmallow", displayName = "Honey Marshmallow", factory = "CandyFactory", unlockLevel = 51, inputs = { HoneyCaramel = 1, Eggs = 2 }, outputQty = 1, seconds = 4 * HOUR + 30 * MIN, sellPrice = 211, xp = 90 },
	-- Level 52-53 goods
	Book = { id = "Book", displayName = "Book", factory = "PaperMill", unlockLevel = 52, inputs = { Paper = 4, CottonFabric = 1, Glue = 1 }, outputQty = 1, seconds = 3 * HOUR + 30 * MIN, sellPrice = 304, xp = 130 },
	HighlighterPen = { id = "HighlighterPen", displayName = "Highlighter Pen", factory = "StationeryShop", unlockLevel = 52, inputs = { NylonThread = 1, Cotton = 3, Plastic = 1 }, outputQty = 1, seconds = 3 * HOUR + 10 * MIN, sellPrice = 283, xp = 121 },
	FishBurger = { id = "FishBurger", displayName = "Fish Burger", factory = "Diner", unlockLevel = 53, inputs = { Bread = 2, Fish = 2, Peppers = 1 }, outputQty = 1, seconds = 45 * MIN, sellPrice = 184, xp = 79 },
	-- Level 54-55 goods
	Bed = { id = "Bed", displayName = "Bed", factory = "FurnitureWorkshop", unlockLevel = 54, inputs = { SilkFabric = 1, CottonFabric = 1, PineTrees = 2 }, outputQty = 1, seconds = 4 * HOUR + 30 * MIN, sellPrice = 292, xp = 125 },
	MintCandy = { id = "MintCandy", displayName = "Mint Candy", factory = "CandyFactory", unlockLevel = 54, inputs = { Mint = 2, CaneSyrup = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 114, xp = 49 },
	SeafoodPizza = { id = "SeafoodPizza", displayName = "Seafood Pizza", factory = "Bakery", unlockLevel = 55, inputs = { Wheat = 2, Fish = 1, Shrimp = 1, Cheese = 1 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 241, xp = 103 },
	Sneakers = { id = "Sneakers", displayName = "Sneakers", factory = "Cobbler", unlockLevel = 55, inputs = { Rubber = 1, CottonFabric = 1, Glue = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 234, xp = 100 },
	-- Jeweler (Township's Jewelry Store): Quarry ore from the Ore Shed, like the Smelter
	Pendant = { id = "Pendant", displayName = "Pendant", factory = "Jeweler", unlockLevel = 53, inputs = { SilverOre = 9 }, outputQty = 1, seconds = 30 * MIN, sellPrice = 345, xp = 148, fromOreShed = true },
	BulletinBoard = { id = "BulletinBoard", displayName = "Bulletin Board", factory = "StationeryShop", unlockLevel = 48, inputs = { CorkOak = 3, Paper = 1 }, outputQty = 1, seconds = 2 * HOUR + 50 * MIN, sellPrice = 124, xp = 53 },
	Taco = { id = "Taco", displayName = "Taco", factory = "Cantina", unlockLevel = 49, inputs = { Corn = 3, Cream = 1, Tomatoes = 2, Peppers = 2 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 109, xp = 47 },
	-- Homewares Shop (content bank)
	Plunger = { id = "Plunger", displayName = "Plunger", factory = "HomewaresShop", unlockLevel = 40, inputs = { PineTrees = 1, Rubber = 1 }, outputQty = 1, seconds = 3 * HOUR + 10 * MIN, sellPrice = 122, xp = 52 },
	Clothesline = { id = "Clothesline", displayName = "Clothesline", factory = "HomewaresShop", unlockLevel = 39, inputs = { Sugarcane = 5, NylonThread = 1 }, outputQty = 1, seconds = 2 * HOUR + 50 * MIN, sellPrice = 202, xp = 87 },
	SoapDispenser = { id = "SoapDispenser", displayName = "Soap Dispenser", factory = "HomewaresShop", unlockLevel = 38, inputs = { CorkOak = 1, PlasticBottle = 1 }, outputQty = 1, seconds = 2 * HOUR + 20 * MIN, sellPrice = 154, xp = 66 },
	ScrubBrush = { id = "ScrubBrush", displayName = "Scrub Brush", factory = "HomewaresShop", unlockLevel = 37, inputs = { Sugarcane = 3, NylonThread = 1 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 169, xp = 72 },
	Plastic = { id = "Plastic", displayName = "Plastic", factory = "RubberWorks", unlockLevel = 32, inputs = { RubberTrees = 2 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 73, xp = 31 },
	Rubber = { id = "Rubber", displayName = "Rubber", factory = "RubberWorks", unlockLevel = 29, inputs = { RubberTrees = 1 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 35, xp = 15 },
	-- Smelter (Township's Foundry: 5 ore -> 1 ingot, all at level 21). Bars go to the Barn.
	CopperBar = { id = "CopperBar", displayName = "Copper Bar", factory = "Smelter", unlockLevel = 21, inputs = { CopperOre = 5 }, outputQty = 1, seconds = 1 * HOUR, sellPrice = 96, xp = 41, fromOreShed = true },
	SilverBar = { id = "SilverBar", displayName = "Silver Bar", factory = "Smelter", unlockLevel = 21, inputs = { SilverOre = 5 }, outputQty = 1, seconds = 2 * HOUR, sellPrice = 144, xp = 62, fromOreShed = true },
	GoldBar = { id = "GoldBar", displayName = "Gold Bar", factory = "Smelter", unlockLevel = 21, inputs = { GoldOre = 5 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 204, xp = 87, fromOreShed = true },
	PlatinumBar = { id = "PlatinumBar", displayName = "Platinum Bar", factory = "Smelter", unlockLevel = 21, inputs = { PlatinumOre = 5 }, outputQty = 1, seconds = 4 * HOUR, sellPrice = 300, xp = 129, fromOreShed = true },
	-- Jam Kitchen (content bank)
	StrawberryJam = { id = "StrawberryJam", displayName = "Strawberry Jam", factory = "JamKitchen", unlockLevel = 27, inputs = { Strawberries = 3 }, outputQty = 1, seconds = 1 * HOUR + 30 * MIN, sellPrice = 41, xp = 18 },
	-- From the Far Isles (Config/Isles): Township's Jam Factory recipes for isle fruit
	PeachMarmalade = { id = "PeachMarmalade", displayName = "Peach Marmalade", factory = "JamKitchen", unlockLevel = 29, inputs = { Peaches = 3 }, outputQty = 1, seconds = 2 * HOUR + 30 * MIN, sellPrice = 133, xp = 57 },
	WatermelonJam = { id = "WatermelonJam", displayName = "Watermelon Jam", factory = "JamKitchen", unlockLevel = 30, inputs = { Watermelons = 3 }, outputQty = 1, seconds = 3 * HOUR, sellPrice = 196, xp = 84 },
	PlumJam = { id = "PlumJam", displayName = "Plum Jam", factory = "JamKitchen", unlockLevel = 32, inputs = { Plums = 3 }, outputQty = 1, seconds = 4 * HOUR, sellPrice = 299, xp = 128 },
	GrapeJelly = { id = "GrapeJelly", displayName = "Grape Jelly", factory = "JamKitchen", unlockLevel = 38, inputs = { Grapes = 3 }, outputQty = 1, seconds = 3 * HOUR + 30 * MIN, sellPrice = 196, xp = 84 },
}

return table.freeze(Recipes)
