--!strict
-- Order Board tuning from Design/05 Orders & Economy.
-- Refresh after discard (30 min) is Township baseline; the rest is first-pass.

local MIN = 60

return table.freeze({
	maxSlots = 9, -- Township baseline cap

	-- Slots by player level (first-pass curve shared with 06 Progression & Unlocks)
	slotsByLevel = table.freeze({
		{ level = 1, slots = 3 },
		{ level = 3, slots = 4 },
		{ level = 5, slots = 5 },
		{ level = 8, slots = 6 },
		{ level = 12, slots = 7 },
		{ level = 16, slots = 8 },
		{ level = 20, slots = 9 },
	}),

	-- Line count and target production time per level band (first-pass)
	bands = table.freeze({
		{ minLevel = 1, minLines = 1, maxLines = 2, minSeconds = 2 * MIN, maxSeconds = 6 * MIN },
		{ minLevel = 5, minLines = 1, maxLines = 3, minSeconds = 5 * MIN, maxSeconds = 20 * MIN },
		{ minLevel = 12, minLines = 2, maxLines = 3, minSeconds = 10 * MIN, maxSeconds = 45 * MIN },
		{ minLevel = 20, minLines = 2, maxLines = 4, minSeconds = 20 * MIN, maxSeconds = 90 * MIN },
	}),

	maxCropQty = 20,
	maxProductQty = 3,
	newItemWeightBonus = 0.5, -- items unlocked in the last 2 levels get +50% weight
	newItemLevels = 2,

	-- Rewards: Coins = round(ItemValue * CoinMult(level) * LineBonus), XP = round(OrderXP * 1.5)
	coinMultBase = 1.30,
	coinMultPerLevel = 0.01,
	lineBonus = table.freeze({ 1.00, 1.05, 1.10, 1.15 }),
	xpMult = 1.5,

	discardRefreshSeconds = 30 * MIN, -- Township baseline
	truckReturnSeconds = 30, -- filled card refills after the truck comes back
})
