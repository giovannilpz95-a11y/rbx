--!strict
-- Daily Quests from Design/08 Social & Events (first-pass): three a day from 00:00 UTC, a
-- bonus chest for finishing all three, one free reroll a day. Only quests for systems the
-- farm has unlocked are offered. The Market, visiting and Help Crate quests in the design
-- wait for those systems to call QuestService.progress.

export type QuestDef = {
	kind: string,
	text: string, -- "%d" is the target
	target: number,
	coins: number,
	xp: number,
}

return table.freeze({
	perDay = 3,
	-- Opens with the first-session guide's wrap-up (11 UI & UX step 10), not before
	afterTutorial = true,
	-- Targets are halved below this level so a new farm can finish them
	smallTargetsBelow = 5,
	pool = table.freeze({
		table.freeze({ kind = "harvest", text = "Harvest %d crops", target = 30, coins = 80, xp = 20 }),
		table.freeze({ kind = "animal", text = "Collect %d animal goods", target = 10, coins = 80, xp = 20 }),
		table.freeze({ kind = "factory", text = "Make %d factory goods", target = 5, coins = 100, xp = 25 }),
		table.freeze({ kind = "order", text = "Deliver %d orders", target = 3, coins = 120, xp = 30 }),
	}) :: { QuestDef },
	-- Bonus chest for all three: Gems, or (from the tool level) sometimes a tool
	chest = table.freeze({ minGems = 3, maxGems = 10, toolChance = 0.3 }),
})
