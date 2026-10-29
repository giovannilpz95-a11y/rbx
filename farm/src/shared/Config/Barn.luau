--!strict
-- Barn upgrades and Barn materials from Design/02 Farming (Township baseline; names are ours).
-- Upgrade n costs n of each Barn material and no Coins; the materials are the only gate.

export type Step = { upTo: number, add: number }

return table.freeze({
	materials = table.freeze({
		Nails = table.freeze({ displayName = "Nails", order = 1 }),
		Hinges = table.freeze({ displayName = "Hinges", order = 2 }),
		Paint = table.freeze({ displayName = "Paint", order = 3 }),
	}),
	materialGemPrice = 12, -- Township baseline
	materialsFromLevel = 5, -- Township baseline
	harvestDropChance = 0.02, -- first-pass, rolled together with building materials (02 Farming)
	-- Space each upgrade adds: upgrades 1-3 +20, up to 38 +25 (985), up to 58 +50, then +75
	steps = table.freeze({
		table.freeze({ upTo = 3, add = 20 }),
		table.freeze({ upTo = 38, add = 25 }),
		table.freeze({ upTo = 58, add = 50 }),
		table.freeze({ upTo = math.huge, add = 75 }),
	}) :: { Step },
})
