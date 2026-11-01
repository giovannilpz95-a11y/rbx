--!strict
-- The Tonic Shed and its Farm Tonics (Features/F09; Township's Laboratory and its boosters,
-- baseline from the wiki's Laboratory and Gems pages, read 2026-10-30 and 2026-11-01). The
-- building, the tonic names, their looks and their text are ours.
--
-- Township: the Laboratory opens at level 18 (1,800 Coins, Population 560, 1 day, 79 XP).
-- Each booster runs for a fixed time (1 to 3 days); at most 3 run at once and never two of
-- the same; cancelling one throws its time away. Nine are switched on with three kinds of lab
-- gems (10 / 20 / 30 old-scale T-cash each when bought) and the rest only come from events.
-- We have one premium currency, so a tonic is switched on with Gems at the lab-gem cost
-- (1 old T-cash = 1 Gem, township-baseline-source), or for free with a tonic the farm earned.
--
-- Built now (the others need systems the farm doesn't have yet: a refreshing Trading Post,
-- co-op requests, hidden Quarry blocks, a per-farm train, a bigger Barn):
--   Gem tonics (Township's lab boosters): Bumper Crop, Happy Herd, Good Customer, Busy Bees
--   Oil, Fair Winds, Hot Smelter.
--   Earned-only tonics (Township's event boosters): Quick Sprout, Sky Bonus, Swift Sails,
--   Busy Board. They drop in Full Hold chests (and later from events and the Rally Shop).

local HOUR = 3600
local DAY = 24 * HOUR

-- What a tonic changes. Each stat is read where the game works it out (shared/Tonics):
--   fieldYield  x  crops a field gives at harvest
--   penYield    x  goods an animal gives at collection
--   orderCoins  x  Coins an Order Board order pays
--   factoryTime -  cut on factory goods' time, added to the Tinker's Guild's time upgrades
--   smeltTime   x  Smelter time
--   barPower    x  how far a Bar sent with a Sailboat moves the odds and amounts
--   growTime    x  crop growing time (crops planted while it runs)
--   blimpCoins  x  Coins from Cargo Blimp crates and rows
--   sailTime    x  Sailboat trip time (boats sent while it runs)
--   orderWait   x  wait for a new order after a delivery or a discard
export type Stat =
	"fieldYield"
	| "penYield"
	| "orderCoins"
	| "factoryTime"
	| "smeltTime"
	| "barPower"
	| "growTime"
	| "blimpCoins"
	| "sailTime"
	| "orderWait"

export type TonicDef = {
	id: string,
	displayName: string,
	effect: string, -- one line for the panel
	stat: Stat,
	value: number,
	seconds: number,
	gems: number?, -- the Gem price to switch it on; nil = earned only
	color: { number }, -- the jar on the shelf (RGB)
	order: number,
}

-- Gem prices: Township's lab-gem cost at 10 / 20 / 30 Gems a topaz / emerald / ruby
-- stylua: ignore
local tonics: { [string]: TonicDef } = {
	-- Super-Harvest: 5 topaz + 3 emerald, 2 days
	BumperCrop = { id = "BumperCrop", displayName = "Bumper Crop", effect = "Fields give twice the crops", stat = "fieldYield", value = 2, seconds = 2 * DAY, gems = 110, color = { 139, 211, 70 }, order = 1 },
	-- Advanced Farming: 7 topaz + 2 ruby, 2 days (pens and the Mushroom Shed)
	HappyHerd = { id = "HappyHerd", displayName = "Happy Herd", effect = "Animals give twice the goods", stat = "penYield", value = 2, seconds = 2 * DAY, gems = 130, color = { 255, 150, 180 }, order = 2 },
	-- Generous Customer: 6 topaz + 3 emerald + 2 ruby, 2 days
	GoodCustomer = { id = "GoodCustomer", displayName = "Good Customer", effect = "Order Board orders pay twice the Coins", stat = "orderCoins", value = 2, seconds = 2 * DAY, gems = 180, color = { 255, 201, 60 }, order = 3 },
	-- High-Speed Production: 8 topaz + 2 emerald + 2 ruby, 2 days, -30% on top of upgrades
	BusyBeesOil = { id = "BusyBeesOil", displayName = "Busy Bees Oil", effect = "Factories work 30% faster", stat = "factoryTime", value = 0.3, seconds = 2 * DAY, gems = 180, color = { 240, 160, 40 }, order = 4 },
	-- Efficient Smelting: 2 topaz + 4 emerald + 3 ruby, 2 days, -50%
	HotSmelter = { id = "HotSmelter", displayName = "Hot Smelter", effect = "Smelters work twice as fast", stat = "smeltTime", value = 0.5, seconds = 2 * DAY, gems = 190, color = { 230, 90, 60 }, order = 5 },
	-- Favorable Voyage: 7 topaz + 2 emerald, 2 days, ingots twice as effective
	FairWinds = { id = "FairWinds", displayName = "Fair Winds", effect = "A Bar sent with a Sailboat counts double", stat = "barPower", value = 2, seconds = 2 * DAY, gems = 110, color = { 90, 170, 230 }, order = 6 },
	-- Event boosters (Rich Fields, Profitable Flight, Smart Navigation, Record Demand), 1 day
	QuickSprout = { id = "QuickSprout", displayName = "Quick Sprout", effect = "Crops planted grow 40% faster", stat = "growTime", value = 0.6, seconds = 1 * DAY, color = { 120, 200, 120 }, order = 7 },
	SkyBonus = { id = "SkyBonus", displayName = "Sky Bonus", effect = "Cargo Blimp crates and rows pay twice the Coins", stat = "blimpCoins", value = 2, seconds = 1 * DAY, color = { 180, 140, 230 }, order = 8 },
	SwiftSails = { id = "SwiftSails", displayName = "Swift Sails", effect = "Sailboats sent sail twice as fast", stat = "sailTime", value = 0.5, seconds = 1 * DAY, color = { 60, 200, 200 }, order = 9 },
	BusyBoard = { id = "BusyBoard", displayName = "Busy Board", effect = "New orders come 80% sooner", stat = "orderWait", value = 0.2, seconds = 1 * DAY, color = { 230, 110, 150 }, order = 10 },
}

local list: { TonicDef } = {}
for _, def in tonics do
	table.freeze(def.color)
	table.freeze(def)
	table.insert(list, def)
end
table.sort(list, function(a, b)
	return a.order < b.order
end)

return table.freeze({
	unlockLevel = 18,
	buildCoins = 1800,
	population = 560,
	buildSeconds = 1 * DAY,
	buildXp = 79,
	maxActive = 3, -- at once, never two of the same
	tonics = table.freeze(tonics),
	list = table.freeze(list),
	-- A Full Hold chest has this chance of a tonic as well (Township's plane chest always holds
	-- one lab gem, about a tenth of a booster). Drawn when the load is made and shown up front.
	chestChance = 0.3,
	-- Weights for which tonic: earned-only ones come more often
	chestWeights = table.freeze({
		BumperCrop = 1,
		HappyHerd = 1,
		GoodCustomer = 1,
		BusyBeesOil = 1,
		HotSmelter = 1,
		FairWinds = 1,
		QuickSprout = 3,
		SkyBonus = 3,
		SwiftSails = 3,
		BusyBoard = 3,
	}),
})
