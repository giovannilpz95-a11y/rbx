--!strict
-- Factory buildings from Design/04 Factories & Recipes and Township Baseline Numbers §4
-- (Township baseline). The greybox ships the Bakery only.

export type FactoryDef = {
	id: string,
	displayName: string,
	unlockLevel: number,
	buildCost: number, -- Coins
	buildSeconds: number,
	xp: number, -- XP for building it
	queueSlots: number, -- starting queue length (active + waiting)
	trayCapacity: number, -- finished goods the output tray holds
}

local Factories: { [string]: FactoryDef } = {
	Bakery = {
		id = "Bakery",
		displayName = "Bakery",
		unlockLevel = 2,
		buildCost = 125,
		buildSeconds = 3,
		xp = 10,
		queueSlots = 3,
		trayCapacity = 8,
	},
}

return table.freeze(Factories)
