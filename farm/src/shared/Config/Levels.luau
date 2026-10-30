--!strict
-- XP curve and level-up rewards from Township Baseline Numbers §9 (Township baseline).
-- The MVP caps at level 12 (Launch/18 MVP & Roadmap). Level 1's reward is the starting wallet.

export type LevelDef = {
	level: number,
	xpToNext: number, -- XP needed to go from this level to the next
	rewardCoins: number, -- granted on reaching this level
	rewardGems: number,
}

local CAP = 12

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
}
for _, gift in gifts do
	table.freeze(gift)
end

return table.freeze({
	cap = CAP,
	gifts = table.freeze(gifts),
	list = table.freeze(list),
})
