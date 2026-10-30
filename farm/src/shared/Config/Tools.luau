--!strict
-- Expansion tools from Design/02 Farming (Township baseline; names are ours). They live in the
-- Tool Shed, not the Barn, so they never take Barn space. Land expansions start asking for
-- them later on (Shovels from expansion 20 on the Township baseline), so in the MVP players
-- build up a stock.

return table.freeze({
	tools = table.freeze({
		Shovel = table.freeze({ displayName = "Shovel", plural = "Shovels", order = 1, harvestChance = 0.03 }),
		Axe = table.freeze({ displayName = "Axe", plural = "Axes", order = 2, harvestChance = 0.02 }),
		Saw = table.freeze({ displayName = "Saw", plural = "Saws", order = 3, harvestChance = 0.015 }),
	}),
	fromLevel = 5, -- first-pass: with the other drops, after the first-session guide
	pityHarvests = 40, -- no tool in this many harvests in a row: the next one gives the scarcest
	orderDropChance = 0.05, -- per Order Board delivery, the scarcest tool (05 Orders & Economy)
})
