--!strict
-- The Otter Pond (Township's Otter Pond, level 58; Township baseline from the wiki's Otter
-- Pond, Seaweed, Scallop and Pearls pages). The name, the look and the text are ours; the
-- catch is Township's own items (township-items-continuity), so the goods made from Seaweed,
-- Scallops and Pearls find the inputs they expect.
--
-- Township: the pond costs 24,000 Coins and takes 2 days 12 h (958 XP). It comes with one
-- otter; two more cost 16,000 and 30,000 Coins. Give an otter one Egg, Bacon or Fish and it
-- comes back with a catch: better food brings more and rarer goods, sooner. Township places
-- it on water; our farms have none, so it brings its own pond and is placed and moved like
-- any building.

local HOUR = 3600
local MIN = 60

export type FoodDef = {
	item: string, -- what the otter eats
	catch: { [string]: { number } }, -- good id -> { min, max } it brings back
	seconds: number, -- how long it's away
	order: number,
}

export type GoodDef = {
	id: string,
	displayName: string,
	sellPrice: number,
	xp: number,
	order: number,
}

-- stylua: ignore
local foods: { [string]: FoodDef } = {
	Eggs = { item = "Eggs", catch = { Seaweed = { 1, 2 }, Scallop = { 0, 1 } }, seconds = 4 * HOUR + 30 * MIN, order = 1 },
	Bacon = { item = "Bacon", catch = { Seaweed = { 2, 3 }, Scallop = { 1, 2 }, Pearls = { 0, 1 } }, seconds = 4 * HOUR, order = 2 },
	Fish = { item = "Fish", catch = { Seaweed = { 3, 3 }, Scallop = { 2, 2 }, Pearls = { 1, 2 } }, seconds = 3 * HOUR, order = 3 },
}

-- stylua: ignore
local goods: { [string]: GoodDef } = {
	Seaweed = { id = "Seaweed", displayName = "Seaweed", sellPrice = 45, xp = 18, order = 1 },
	Scallop = { id = "Scallop", displayName = "Scallop", sellPrice = 52, xp = 23, order = 2 },
	Pearls = { id = "Pearls", displayName = "Pearls", sellPrice = 60, xp = 27, order = 3 },
}

for _, food in foods do
	for _, range in food.catch do
		table.freeze(range)
	end
	table.freeze(food.catch)
	table.freeze(food)
end
for _, good in goods do
	table.freeze(good)
end

return table.freeze({
	unlockLevel = 58,
	buildCoins = 24000,
	buildSeconds = 60 * HOUR,
	buildXp = 958,
	otterCoins = table.freeze({ 0, 16000, 30000 }), -- the first otter comes with the pond
	foods = table.freeze(foods),
	goods = table.freeze(goods),
})
