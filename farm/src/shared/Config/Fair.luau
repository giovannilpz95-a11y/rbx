--!strict
-- The County Fair (Design/14 Multiplayer Features F1; roadmap week 10): a weekend contest in the
-- Town Square. Each farm enters once per class; NPC judges score each entry with a server-side
-- formula and a little luck, and award ribbons by merit (any number of farms can win a Blue,
-- as at a real county fair, so no cross-server ranking is needed). Ribbons and Blue Ribbon cups
-- (decorations) are the only rewards: Gems can't buy entries or quality.
--
-- Decided defaults (tell Giovanni, easy to change):
--   * Every week: entries Friday 16:00 UTC to Monday 00:00 UTC (20 §5's Friday content day),
--     judged at Monday 00:00; results wait in the Fair panel until you look.
--   * v1 has two classes: Prize Produce (enter a Prize Crop from your Prize Basket) and Best Bake
--     (a Bakery good, with a Prize Crop on top for extra marks). Biggest Pumpkin (cared for all
--     week, with help from friends) comes with v1.1.

local HOUR = 3600

export type Class = {
	id: string,
	displayName: string,
	order: number,
	cup: string, -- the decoration a Blue Ribbon wins (cups below)
}

return table.freeze({
	minLevel = 5,
	opensWeekday = 5, -- Friday (0 = Sunday), UTC
	opensHour = 16,
	openSeconds = 56 * HOUR, -- until Monday 00:00 UTC
	previewSeconds = 7 * 24 * HOUR, -- Studio: a preview fair runs this long from its start

	classes = table.freeze({
		Produce = table.freeze({ id = "Produce", displayName = "Prize Produce", order = 1, cup = "ProduceCup" }),
		Bake = table.freeze({ id = "Bake", displayName = "Best Bake", order = 2, cup = "BakersCup" }),
	}) :: { [string]: Class },
	order = table.freeze({ "Produce", "Bake" }),

	-- Prize Produce: the tier's marks, up to `cropMax` more for a crop unlocked later, and luck
	produceTier = table.freeze({ Sunkissed = 50, Dewkissed = 58, Starlit = 66, Heirloom = 82 }),
	cropMax = 10,
	cropLevelsPerMark = 3,
	-- Best Bake: base marks, one more per `bakeSecondsPerMark` of making time (up to `bakeMax`),
	-- and a Prize Crop on top adds its tier's garnish marks
	bakeBase = 40,
	bakeSecondsPerMark = 360,
	bakeMax = 25,
	bakeFactory = "Bakery",
	garnishTier = table.freeze({ Sunkissed = 8, Dewkissed = 11, Starlit = 14, Heirloom = 22 }),
	luckMax = 12, -- the judges' mood: 0-12 marks

	-- Ribbons by marks (out of 100); everyone who enters gets at least a Green
	ribbons = table.freeze({
		table.freeze({ id = "Blue", displayName = "Blue Ribbon", icon = "🥇", marks = 75 }),
		table.freeze({ id = "Red", displayName = "Red Ribbon", icon = "🥈", marks = 62 }),
		table.freeze({ id = "Yellow", displayName = "Yellow Ribbon", icon = "🥉", marks = 50 }),
		table.freeze({ id = "Green", displayName = "Green Ribbon", icon = "🎗️", marks = 0 }),
	}),

	-- Blue Ribbon cups: decorations placed free from storage, like Gold trophies
	cups = table.freeze({
		ProduceCup = table.freeze({
			id = "ProduceCup",
			displayName = "Prize Produce Cup",
			size = table.freeze({ 1, 1 }),
		}),
		BakersCup = table.freeze({ id = "BakersCup", displayName = "Baker's Blue Cup", size = table.freeze({ 1, 1 }) }),
	}),
})
