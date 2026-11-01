--!strict
-- The Duck Pond (Township's Duck Feeder, level 48; Township baseline from the wiki's Duck
-- Feeder, Down Feather and Colorful Feather pages). The name, the look and digging it out are
-- ours; the feathers are Township's own items (township-items-continuity), so the Shuttlecock
-- and the Feather Duster find the inputs they expect.
--
-- Township: the feeder costs 14,500 Coins and takes 1 day 21 h (603 XP). Feed it one Bakery
-- good and 1 to 4 ducks come; every duck leaves a Down Feather and every drake (green head)
-- a Colorful Feather as well. Better food brings more ducks, more drakes and a shorter wait.
-- Township places it on water; our farms have none, so it is a pond the player digs out where
-- they like (placed and moved like any building).

local HOUR = 3600
local MIN = 60

export type FoodDef = {
	item: string, -- the Bakery good it eats
	ducks: { number }, -- min, max ducks that come
	drakes: { number }, -- min, max of them that are drakes (never more than the ducks)
	seconds: number, -- how long they stay before the feathers can be collected
	order: number,
}

export type FeatherDef = {
	id: string,
	displayName: string,
	sellPrice: number,
	xp: number,
}

-- stylua: ignore
local foods: { [string]: FoodDef } = {
	Bread = { item = "Bread", ducks = { 1, 2 }, drakes = { 0, 0 }, seconds = 1 * HOUR + 30 * MIN, order = 1 },
	Bagel = { item = "Bagel", ducks = { 1, 3 }, drakes = { 0, 1 }, seconds = 1 * HOUR, order = 2 },
	BananaBread = { item = "BananaBread", ducks = { 2, 4 }, drakes = { 1, 2 }, seconds = 30 * MIN, order = 3 },
}

-- stylua: ignore
local feathers: { [string]: FeatherDef } = {
	DownFeather = { id = "DownFeather", displayName = "Down Feather", sellPrice = 12, xp = 5 },
	ColorfulFeather = { id = "ColorfulFeather", displayName = "Colorful Feather", sellPrice = 31, xp = 13 },
}

export type PondDef = {
	id: string,
	displayName: string,
	unlockLevel: number,
	digCoins: number,
	digSeconds: number,
	digXp: number,
	save: string, -- the save block that holds this pond
	order: number,
}

-- Township gives a second Duck Feeder at level 73 (140,000 Coins, 3 days 5 h, 5,780 XP; the
-- wiki's Buildings table). It works exactly like the first, with its own visits.
-- stylua: ignore
local ponds: { [string]: PondDef } = {
	DuckPond = { id = "DuckPond", displayName = "Duck Pond", unlockLevel = 48, digCoins = 14500, digSeconds = 45 * HOUR, digXp = 603, save = "duckPond", order = 1 },
	DuckPond2 = { id = "DuckPond2", displayName = "Willow Pond", unlockLevel = 73, digCoins = 140000, digSeconds = 77 * HOUR, digXp = 5780, save = "duckPond2", order = 2 },
}

for _, pond in ponds do
	table.freeze(pond)
end

for _, food in foods do
	table.freeze(food.ducks)
	table.freeze(food.drakes)
	table.freeze(food)
end
for _, feather in feathers do
	table.freeze(feather)
end

return table.freeze({
	unlockLevel = 48,
	digCoins = 14500,
	digSeconds = 45 * HOUR,
	digXp = 603,
	ponds = table.freeze(ponds),
	foods = table.freeze(foods),
	feathers = table.freeze(feathers),
	down = "DownFeather", -- one per duck
	colorful = "ColorfulFeather", -- one more per drake
})
