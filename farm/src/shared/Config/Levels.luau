--!strict
-- XP curve and level-up rewards from Township Baseline Numbers §9 (Township baseline).
-- Level 1's reward is the starting wallet. `cap` is the live level cap: 12 at launch, raised
-- by about one a week (Launch/18 MVP & Roadmap §4). Rows and content past it are the content
-- bank, built ahead and switched on by raising `cap` on update day; `built` is the highest
-- level whose content exists.

export type LevelDef = {
	level: number,
	xpToNext: number, -- XP needed to go from this level to the next
	rewardCoins: number, -- granted on reaching this level
	rewardGems: number,
}

local CAP = 12 -- raise on update day (week 1: 13), never past BUILT
local BUILT = 53

local rows = {
	-- level, xpToNext, rewardCoins, rewardGems
	{ 1, 9, 500, 30 },
	{ 2, 17, 100, 1 },
	{ 3, 44, 150, 1 },
	{ 4, 130, 200, 1 },
	{ 5, 284, 250, 1 },
	{ 6, 292, 300, 1 },
	{ 7, 408, 300, 1 },
	{ 8, 556, 300, 0 },
	{ 9, 739, 300, 0 },
	{ 10, 963, 300, 0 },
	{ 11, 1234, 400, 0 },
	{ 12, 1555, 400, 0 },
	-- content bank (Update 1+)
	{ 13, 1935, 400, 0 },
	{ 14, 2377, 400, 0 },
	{ 15, 2889, 500, 0 },
	{ 16, 3478, 500, 0 },
	{ 17, 4149, 600, 0 },
	{ 18, 4912, 600, 0 },
	{ 19, 5771, 700, 0 },
	{ 20, 6736, 800, 0 },
	{ 21, 7813, 800, 0 },
	{ 22, 9011, 900, 0 },
	{ 23, 10338, 1000, 0 },
	{ 24, 11802, 1100, 0 },
	{ 25, 13413, 1200, 0 },
	{ 26, 15178, 1300, 0 },
	{ 27, 17108, 1400, 0 },
	{ 28, 19210, 1500, 0 },
	{ 29, 21495, 1600, 0 },
	{ 30, 23974, 1700, 0 },
	{ 31, 26654, 1800, 0 },
	{ 32, 29547, 2000, 0 },
	{ 33, 32663, 2200, 0 },
	{ 34, 36013, 2300, 0 },
	{ 35, 39606, 2500, 0 },
	{ 36, 43455, 2600, 0 },
	{ 37, 47571, 2800, 0 },
	{ 38, 51963, 3000, 0 },
	{ 39, 56645, 3200, 0 },
	{ 40, 61628, 3400, 0 },
	{ 41, 66924, 3600, 0 },
	{ 42, 72545, 3800, 0 },
	{ 43, 78503, 4000, 0 },
	{ 44, 84811, 4200, 0 },
	{ 45, 91481, 4500, 0 },
	{ 46, 98526, 4700, 0 },
	{ 47, 105961, 5000, 0 },
	{ 48, 113797, 5200, 0 },
	{ 49, 122047, 5500, 0 },
	{ 50, 130727, 5700, 0 },
	{ 51, 139848, 6000, 0 },
	{ 52, 149427, 6300, 0 },
	{ 53, 159476, 6600, 0 },
}

local list: { LevelDef } = {}
for _, row in rows do
	table.insert(
		list,
		table.freeze({
			level = row[1],
			xpToNext = row[2],
			rewardCoins = row[3],
			rewardGems = row[4],
		})
	)
end

-- Free units handed over on reaching a level, so a new crop or pen can start at once
-- (Township's unlock gifts, Wiki Data - Farming & Animals §1). Level 1's Cow Feed is
-- Balance.starterCowFeed.
local gifts: { [number]: { [string]: number } } = {
	[3] = { Corn = 4 },
	[4] = { Carrots = 4 },
	[5] = { ChickenFeed = 3 },
	[7] = { Sugarcane = 3 },
	[13] = { Strawberries = 3 },
	[15] = { Tomatoes = 3 },
	[22] = { Potatoes = 3 },
	[25] = { Cocoa = 3 },
	[29] = { RubberTrees = 3 },
	[31] = { Silk = 3 },
	[38] = { CorkOak = 3 },
	[43] = { Peppers = 3 },
	[50] = { Mint = 3 },
}
for _, gift in gifts do
	table.freeze(gift)
end

return table.freeze({
	cap = CAP,
	built = BUILT,
	gifts = table.freeze(gifts),
	list = table.freeze(list),
})
