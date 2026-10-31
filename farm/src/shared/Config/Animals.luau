--!strict
-- Animal pens from Design/03 Animals and Township Baseline Numbers §3 (Township baseline):
-- the three pens of the level-12 MVP, then the content bank's extra Cow Barns (levels 15 and 22)
-- and second Chicken Coop (level 24), which stand in the West Meadow. Each pen comes with 3 animals; animals 4-6 are bought.
-- One bag of feed feeds 3 animals (one product each). A copy has its own id, animals and
-- price, and shares its original's animals, feed, product and look (`copyOf`).

export type PenDef = {
	id: string,
	displayName: string, -- the pen
	animalName: string, -- one animal, for buttons ("Buy a Cow")
	animalPlural: string,
	unlockLevel: number,
	given: boolean, -- placed for free at level 1 (the Cow Barn)
	buildCost: number, -- Coins
	buildSeconds: number,
	xp: number, -- XP for building it
	feed: string, -- Feed Mill recipe id
	product: string, -- Barn item id
	productName: string,
	produceSeconds: number,
	sellPrice: number, -- Coins per product
	productXP: number, -- XP per product collected
	startAnimals: number,
	extraAnimalCosts: { number }, -- Coins for animals 4, 5, 6
	order: number,
	color: { number }, -- greybox RGB for the animals
	productColor: { number },
	copyOf: string?, -- a second or third pen of a kind: the pen whose animals and look it shares
	land: number?, -- the land expansion its spot is on, which must be cleared first
}

local MIN = 60
local HOUR = 3600

-- One bag of feed feeds this many animals.
local FEED_PER_BAG = 3

-- stylua: ignore
local Pens: { [string]: PenDef } = {
	CowBarn = { id = "CowBarn", displayName = "Cow Barn", animalName = "Cow", animalPlural = "Cows", unlockLevel = 1, given = true, buildCost = 0, buildSeconds = 0, xp = 0, feed = "CowFeed", product = "Milk", productName = "Milk", produceSeconds = 20 * MIN, sellPrice = 7, productXP = 3, startAnimals = 3, extraAnimalCosts = { 30, 40, 50 }, order = 1, color = { 245, 245, 245 }, productColor = { 250, 250, 255 } },
	ChickenCoop = { id = "ChickenCoop", displayName = "Chicken Coop", animalName = "Chicken", animalPlural = "Chickens", unlockLevel = 5, given = false, buildCost = 200, buildSeconds = 1 * HOUR, xp = 13, feed = "ChickenFeed", product = "Eggs", productName = "Eggs", produceSeconds = 1 * HOUR, sellPrice = 10, productXP = 4, startAnimals = 3, extraAnimalCosts = { 90, 120, 150 }, order = 2, color = { 250, 240, 220 }, productColor = { 240, 220, 170 } },
	SheepFold = { id = "SheepFold", displayName = "Sheep Fold", animalName = "Sheep", animalPlural = "Sheep", unlockLevel = 10, given = false, buildCost = 600, buildSeconds = 4 * HOUR, xp = 29, feed = "SheepFeed", product = "Wool", productName = "Wool", produceSeconds = 4 * HOUR, sellPrice = 15, productXP = 6, startAnimals = 3, extraAnimalCosts = { 180, 240, 300 }, order = 3, color = { 225, 225, 215 }, productColor = { 235, 235, 230 } },
	-- content bank (level 13+)
	CowBarn2 = { id = "CowBarn2", displayName = "Second Cow Barn", animalName = "Cow", animalPlural = "Cows", unlockLevel = 15, given = false, buildCost = 1000, buildSeconds = 14 * HOUR, xp = 46, feed = "CowFeed", product = "Milk", productName = "Milk", produceSeconds = 20 * MIN, sellPrice = 7, productXP = 3, startAnimals = 3, extraAnimalCosts = { 180, 200, 220 }, order = 4, color = { 245, 245, 245 }, productColor = { 250, 250, 255 }, copyOf = "CowBarn", land = 1 },
	CowBarn3 = { id = "CowBarn3", displayName = "Third Cow Barn", animalName = "Cow", animalPlural = "Cows", unlockLevel = 22, given = false, buildCost = 5000, buildSeconds = 26 * HOUR, xp = 211, feed = "CowFeed", product = "Milk", productName = "Milk", produceSeconds = 20 * MIN, sellPrice = 7, productXP = 3, startAnimals = 3, extraAnimalCosts = { 750, 800, 850 }, order = 5, color = { 245, 245, 245 }, productColor = { 250, 250, 255 }, copyOf = "CowBarn", land = 1 },
	ChickenCoop2 = { id = "ChickenCoop2", displayName = "Second Chicken Coop", animalName = "Chicken", animalPlural = "Chickens", unlockLevel = 24, given = false, buildCost = 3000, buildSeconds = 28 * HOUR, xp = 128, feed = "ChickenFeed", product = "Eggs", productName = "Eggs", produceSeconds = 1 * HOUR, sellPrice = 10, productXP = 4, startAnimals = 3, extraAnimalCosts = { 540, 600, 660 }, order = 6, color = { 250, 240, 220 }, productColor = { 240, 220, 170 }, copyOf = "ChickenCoop", land = 1 },
	SheepFold2 = { id = "SheepFold2", displayName = "Second Sheep Fold", animalName = "Sheep", animalPlural = "Sheep", unlockLevel = 31, given = false, buildCost = 8000, buildSeconds = 34 * HOUR, xp = 335, feed = "SheepFeed", product = "Wool", productName = "Wool", produceSeconds = 4 * HOUR, sellPrice = 15, productXP = 6, startAnimals = 3, extraAnimalCosts = { 1080, 1200, 1320 }, order = 7, color = { 225, 225, 215 }, productColor = { 235, 235, 230 }, copyOf = "SheepFold", land = 2 },
}

for _, pen in Pens do
	table.freeze(pen.extraAnimalCosts)
	table.freeze(pen.color)
	table.freeze(pen.productColor)
	table.freeze(pen)
end

return table.freeze({
	pens = table.freeze(Pens),
	feedPerBag = FEED_PER_BAG,
	maxAnimals = 6,
})
