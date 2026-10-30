--!strict
-- Gem prices for finishing timers early and for extra factory queue slots, from Township
-- Baseline Numbers §6 and §10 (Township baseline, pre-2025 premium scale: 1 unit = 1 Gem).
-- Each row is { under = seconds left, gems = price }; a timer longer than the last row pays
-- the last row's price.

local MIN = 60
local HOUR = 3600

local function rows(list: { { number } }): { { under: number, gems: number } }
	local out = {}
	for _, row in list do
		table.insert(out, table.freeze({ under = row[1], gems = row[2] }))
	end
	return table.freeze(out)
end

return table.freeze({
	-- Crops, factory jobs and animals
	production = rows({
		{ 5 * MIN, 1 },
		{ 13 * MIN, 2 },
		{ 28 * MIN, 3 },
		{ 35 * MIN, 4 },
		{ 50 * MIN, 5 },
		{ 1 * HOUR + 5 * MIN, 6 },
		{ 1 * HOUR + 20 * MIN, 7 },
		{ 1 * HOUR + 30 * MIN, 8 },
		{ 2 * HOUR, 9 },
		{ 2 * HOUR + 30 * MIN, 10 },
		{ 3 * HOUR, 11 },
		{ 3 * HOUR + 30 * MIN, 12 },
		{ 4 * HOUR, 13 },
		{ 4 * HOUR + 30 * MIN, 14 },
		{ 4 * HOUR + 45 * MIN, 15 },
		{ 5 * HOUR + 30 * MIN, 16 },
		{ 6 * HOUR + 15 * MIN, 17 },
		{ 7 * HOUR, 18 },
		{ 8 * HOUR, 19 },
	}),
	-- Factory and pen construction
	building = rows({
		{ 5 * MIN, 1 },
		{ 13 * MIN, 2 },
		{ 25 * MIN, 3 },
		{ 50 * MIN, 4 },
		{ 1 * HOUR + 20 * MIN, 5 },
		{ 2 * HOUR, 8 },
		{ 3 * HOUR, 11 },
		{ 4 * HOUR, 14 },
		{ 5 * HOUR + 30 * MIN, 17 },
		{ 8 * HOUR + 30 * MIN, 20 },
		{ 11 * HOUR + 30 * MIN, 23 },
		{ 14 * HOUR + 30 * MIN, 26 },
		{ 17 * HOUR + 30 * MIN, 29 },
		{ 21 * HOUR + 30 * MIN, 32 },
		{ 25 * HOUR + 30 * MIN, 35 },
	}),
	-- Waiting for a new Order Board card after a discard (30 min)
	orderWait = rows({
		{ 5 * MIN, 1 },
		{ 13 * MIN, 2 },
		{ 25 * MIN, 3 },
		{ 30 * MIN, 4 },
	}),
	-- Extra factory queue slots: the 1st extra slot costs 8 Gems, the 2nd 12, ... (+4 each).
	-- Township stops at 6 slots until a factory upgrade opens the 7th (Wiki Data - Factories
	-- & Goods §1.2), so a 3-slot factory pays 8/12/16 and a 2-slot one 8/12/16/20.
	queueSlotCosts = table.freeze({ 8, 12, 16, 20, 24 }),
	maxQueueSlots = 6,
})
