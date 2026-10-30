--!strict
-- The daily login calendar from Design/08 Social & Events (first-pass). Seven days that
-- repeat; a missed day pauses the calendar instead of resetting it. Opens at level 5
-- (06 Progression & Unlocks). Coins scale with the level band.
-- Until tools (Shovels, Axes, Saws) and decorations ship, their days give a Barn material
-- instead and day 7 is Gems only.

export type Reward = { coins: number?, gems: number?, item: string? }

return table.freeze({
	unlockLevel = 5,
	days = table.freeze({
		table.freeze({ coins = 100 }),
		table.freeze({ item = "Nails" }), -- Shovel in the design
		table.freeze({ coins = 200 }),
		table.freeze({ item = "Hinges" }), -- Axe in the design
		table.freeze({ gems = 5 }),
		table.freeze({ coins = 300, item = "Paint" }), -- Saw + 300 Coins in the design
		table.freeze({ gems = 15 }), -- + a random decoration in the design
	}) :: { Reward },
	-- Coin multiplier by level band: x1 at 1-10, x1.5 at 11-20, x2 at 21-30
	coinBands = table.freeze({ { minLevel = 1, mult = 1 }, { minLevel = 11, mult = 1.5 }, { minLevel = 21, mult = 2 } }),
})
