--!strict
-- Recipes from Design/04 Factories & Recipes and Township Baseline Numbers §5 (Township baseline).
-- Only recipes whose inputs exist in the greybox are listed: Cookies and Bagel need Eggs
-- and Sugar, which arrive with Chickens and the Sugar Mill.

export type RecipeDef = {
	id: string, -- also the output item key
	displayName: string,
	factory: string,
	unlockLevel: number,
	inputs: { [string]: number },
	outputQty: number,
	seconds: number,
	sellPrice: number,
	xp: number, -- XP per unit collected
}

local MIN = 60

local Recipes: { [string]: RecipeDef } = {
	Bread = {
		id = "Bread",
		displayName = "Bread",
		factory = "Bakery",
		unlockLevel = 2,
		inputs = { Wheat = 2 },
		outputQty = 1,
		seconds = 5 * MIN,
		sellPrice = 5,
		xp = 2,
	},
}

return table.freeze(Recipes)
