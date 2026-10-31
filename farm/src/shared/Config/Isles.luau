--!strict
-- Harbor & Far Isles (Features/F02): the Harbor, its Sailboats and the Far Isles, on the
-- Township baseline for the port, ships and isles (Wiki Data - Side Systems §1 and §10; wiki
-- Ships and isle pages). The isle names, the Driftwood Crate, the Sea Chest's contents and the
-- look are ours; the goods are Township's own (township-items-continuity), so later recipes
-- always find the inputs they expect.
--
-- Township: the port is restored at level 29 (8,000 Coins, 2 days, 335 XP). The first ship is
-- free and up to 4 can be owned. Each isle grows one common good that always comes back x3 and
-- two rarer ones that come back by chance. Sending a ship costs a few Coins and can take one
-- ingot, which raises the odds of the rarer goods and adds a chance of a chest. A free chest
-- floats by once a day.

local HOUR = 3600

export type IsleDef = {
	id: string,
	displayName: string,
	theme: string, -- one line for the sea map
	order: number,
	unlockLevel: number,
	unlockCoins: number, -- 0 = opens with the Harbor
	unlockTools: number, -- Shovels, Axes and Saws, this many of each
	unlockSeconds: number,
	unlockXp: number,
	sendCoins: number,
	tripSeconds: number,
	goods: { string }, -- common, uncommon, rare
	-- Chance (0-1) of the uncommon good, the rare good and a Sea Chest, by the Bar sent along
	-- (index 1 = none, then Config.bars in order)
	odds: { { number } },
	color: { number }, -- RGB for the sea map and its art
}

export type GoodDef = {
	id: string,
	displayName: string,
	isle: string,
	tier: number, -- 1 common, 2 uncommon, 3 rare
	sellPrice: number,
	xp: number,
}

-- stylua: ignore
local isles: { IsleDef } = {
	{
		id = "BlossomCay", displayName = "Blossom Cay", theme = "An orchard isle of fruit trees", order = 1,
		unlockLevel = 29, unlockCoins = 0, unlockTools = 0, unlockSeconds = 0, unlockXp = 0,
		sendCoins = 70, tripSeconds = 4 * HOUR,
		goods = { "Peaches", "Watermelons", "Plums" },
		odds = { { 0.70, 0.33, 0 }, { 0.80, 0.53, 0.10 }, { 1, 0.74, 0.33 }, { 1, 0.88, 0.33 }, { 1, 1, 0.50 } },
		color = { 236, 150, 170 },
	},
	{
		id = "VineyardKey", displayName = "Vineyard Key", theme = "A hillside grove of vines and olive trees", order = 2,
		unlockLevel = 35, unlockCoins = 11000, unlockTools = 2, unlockSeconds = 36 * HOUR, unlockXp = 300,
		sendCoins = 100, tripSeconds = 7 * HOUR,
		goods = { "Grapes", "Olives", "KeyLimes" },
		odds = { { 0.65, 0.30, 0 }, { 0.78, 0.48, 0.20 }, { 0.95, 0.55, 0.27 }, { 1, 0.80, 0.40 }, { 1, 1, 0.60 } },
		color = { 140, 100, 180 },
	},
	{
		id = "CoconutAtoll", displayName = "Coconut Atoll", theme = "A ring of palm beaches", order = 3,
		unlockLevel = 41, unlockCoins = 15000, unlockTools = 4, unlockSeconds = 48 * HOUR, unlockXp = 500,
		sendCoins = 120, tripSeconds = 9 * HOUR,
		goods = { "Bananas", "Coconuts", "Pineapples" },
		odds = { { 0.60, 0.27, 0 }, { 0.75, 0.52, 0.20 }, { 0.92, 0.75, 0.30 }, { 1, 1, 0.48 }, { 1, 1, 0.65 } },
		color = { 90, 190, 120 },
	},
	{
		id = "ReefRock", displayName = "Reef Rock", theme = "A fishing village on the rocks", order = 4,
		unlockLevel = 52, unlockCoins = 45000, unlockTools = 6, unlockSeconds = 60 * HOUR, unlockXp = 1000,
		sendCoins = 140, tripSeconds = 8 * HOUR,
		goods = { "Fish", "Shrimp", "Lobsters" },
		odds = { { 0.55, 0.25, 0 }, { 0.70, 0.32, 0.15 }, { 0.80, 0.50, 0.25 }, { 1, 0.75, 0.37 }, { 1, 1, 0.58 } },
		color = { 70, 140, 200 },
	},
	{
		id = "CactusCove", displayName = "Cactus Cove", theme = "A sunny desert coast", order = 5,
		unlockLevel = 67, unlockCoins = 130000, unlockTools = 8, unlockSeconds = 72 * HOUR, unlockXp = 1300,
		sendCoins = 160, tripSeconds = 10 * HOUR,
		goods = { "Avocados", "Mangoes", "Aloe" },
		odds = { { 0.60, 0.30, 0 }, { 0.75, 0.43, 0.18 }, { 0.91, 0.56, 0.27 }, { 1, 0.81, 0.42 }, { 1, 1, 0.58 } },
		color = { 220, 170, 90 },
	},
}

-- Township's sell price and XP for each isle good
-- stylua: ignore
local goodStats: { [string]: { string | number } } = {
	Peaches = { "Peaches", 34, 8 }, Watermelons = { "Watermelons", 49, 11 }, Plums = { "Plums", 72, 17 },
	Grapes = { "Grapes", 48, 11 }, Olives = { "Olives", 69, 16 }, KeyLimes = { "Key Limes", 97, 23 },
	Bananas = { "Bananas", 58, 16 }, Coconuts = { "Coconuts", 84, 22 }, Pineapples = { "Pineapples", 117, 30 },
	Fish = { "Fish", 61, 17 }, Shrimp = { "Shrimp", 97, 24 }, Lobsters = { "Lobsters", 131, 33 },
	Avocados = { "Avocados", 73, 19 }, Mangoes = { "Mangoes", 114, 27 }, Aloe = { "Aloe", 153, 35 },
}

local byId: { [string]: IsleDef } = {}
local goods: { [string]: GoodDef } = {}
for _, isle in isles do
	byId[isle.id] = isle
	for tier, good in isle.goods do
		local stats = goodStats[good]
		goods[good] = table.freeze({
			id = good,
			displayName = stats[1] :: string,
			isle = isle.id,
			tier = tier,
			sellPrice = stats[2] :: number,
			xp = stats[3] :: number,
		})
	end
	table.freeze(isle.goods)
	for _, row in isle.odds do
		table.freeze(row)
	end
	table.freeze(isle.odds)
	table.freeze(isle.color)
	table.freeze(isle)
end

return table.freeze({
	-- The Harbor's repair (Township's port restoration)
	unlockLevel = 29,
	repairCoins = 8000,
	repairSeconds = 48 * HOUR,
	repairXp = 335,

	-- Sailboats: the first comes with the Harbor; the others are bought at a level and a
	-- Population, and arrive at once (Township's ships 1-4)
	boats = table.freeze({
		table.freeze({ level = 29, population = 0, coins = 0 }),
		table.freeze({ level = 29, population = 2050, coins = 5000 }),
		table.freeze({ level = 32, population = 2500, coins = 8000 }),
		table.freeze({ level = 38, population = 3500, coins = 25000 }),
	}),

	isles = table.freeze(isles), -- in unlock order
	byId = table.freeze(byId),
	goods = table.freeze(goods),

	commonQty = 3, -- the common good always comes back x3
	-- Bars that can ride along as ballast (the Ballast Bar), weakest first; their place in this
	-- list (+1) picks the row of each isle's odds
	bars = table.freeze({ "CopperBar", "SilverBar", "GoldBar", "PlatinumBar" }),
	-- How many of the uncommon and rare good come back when their roll hits, by Bar (none
	-- first). The wiki: 0-2 of each with no ingot, both pushed towards 3 by better ingots.
	-- (First-pass reading of its Frutus Isle table.)
	qty = table.freeze({
		table.freeze({ uncommon = table.freeze({ 1, 2 }), rare = table.freeze({ 1, 2 }) }),
		table.freeze({ uncommon = table.freeze({ 1, 2 }), rare = table.freeze({ 1, 2 }) }),
		table.freeze({ uncommon = table.freeze({ 2, 3 }), rare = table.freeze({ 1, 2 }) }),
		table.freeze({ uncommon = table.freeze({ 3, 3 }), rare = table.freeze({ 1, 2 }) }),
		table.freeze({ uncommon = table.freeze({ 3, 3 }), rare = table.freeze({ 3, 3 }) }),
	}),

	-- The Sea Chest a Ballast Bar can bring back: one prize drawn by weight when the boat
	-- leaves (Township's mystery chest: gems, premium cash, tools or a museum artifact).
	-- First-pass; our museum isn't built, so no artifacts yet.
	seaChest = table.freeze({
		table.freeze({ item = "Gems", qty = 3, weight = 3 }),
		table.freeze({ item = "Gems", qty = 6, weight = 1 }),
		table.freeze({ item = "Shovel", qty = 2, weight = 2 }),
		table.freeze({ item = "Axe", qty = 2, weight = 2 }),
		table.freeze({ item = "Saw", qty = 2, weight = 2 }),
		table.freeze({ item = "Pickaxe", qty = 5, weight = 2 }),
		table.freeze({ item = "CopperBar", qty = 1, weight = 2 }),
		table.freeze({ item = "SilverBar", qty = 1, weight = 1 }),
	}),

	-- The Driftwood Crate: once a UTC day a free crate washes up by the Harbor (Township's free
	-- sea chest every 24 hours). One prize drawn by weight when it's opened; "IsleGoods" is
	-- 2-3 of the common good of an isle the farm has open. First-pass.
	drift = table.freeze({
		table.freeze({ item = "IsleGoods", qty = 3, weight = 4 }),
		table.freeze({ item = "Coins", qty = 150, weight = 3 }),
		table.freeze({ item = "Shovel", qty = 1, weight = 1 }),
		table.freeze({ item = "Axe", qty = 1, weight = 1 }),
		table.freeze({ item = "Saw", qty = 1, weight = 1 }),
		table.freeze({ item = "Nails", qty = 2, weight = 1 }),
		table.freeze({ item = "Hinges", qty = 2, weight = 1 }),
		table.freeze({ item = "Paint", qty = 2, weight = 1 }),
		table.freeze({ item = "CopperBar", qty = 1, weight = 1 }),
		table.freeze({ item = "Gems", qty = 2, weight = 1 }),
	}),

	-- Gems to bring a boat home now, by time left (the wiki's ship skip ladder, read on the old
	-- premium scale: 1 T-cash = 1 Gem). Each row is { under seconds, gems }.
	skip = table.freeze({
		{ 5 * 60, 2 },
		{ 13 * 60, 4 },
		{ 28 * 60, 6 },
		{ 35 * 60, 8 },
		{ 51 * 60, 10 },
		{ 55 * 60, 12 },
		{ 65 * 60, 14 },
		{ 90 * 60, 16 },
		{ 2 * HOUR, 18 },
		{ 2.5 * HOUR, 20 },
		{ 3 * HOUR, 22 },
		{ 3.5 * HOUR, 24 },
		{ 4 * HOUR, 26 },
		{ 4.5 * HOUR, 28 },
		{ 5 * HOUR, 30 },
		{ 5.5 * HOUR, 32 },
		{ 6 * HOUR, 34 },
		{ 7 * HOUR, 36 },
		{ 8 * HOUR, 38 },
		{ 9 * HOUR, 40 },
	}),
	freeSkipSeconds = 30,
})
