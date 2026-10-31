--!strict
-- The Town Express (Design/14 Multiplayer Features C1; roadmap week 2): every 2 hours a giant
-- train pulls into the hub with cars of crates, and everyone on the server loads it from their
-- own Barns during a 20-minute window. Reward tiers at 25 / 50 / 75 / 100% pay every player
-- who loaded at least one crate. First-pass numbers from the design note; the crate sizes come
-- from Township's bulk-order quantities (the Airport Quantities table in Config/Blimp).
--
-- Decided defaults (14 C1 open question 3 left open): a fixed clock, every even UTC hour, so
-- players can plan around it.

local MIN = 60

return table.freeze({
	periodSeconds = 120 * MIN, -- arrivals on the hour, every 2 hours (UTC)
	windowSeconds = 20 * MIN, -- loading window from the arrival

	-- Crates to load for 100%: max(minCrates, cratesPerPlayer x players at arrival), capped
	minCrates = 8,
	cratesPerPlayer = 3,
	maxCrates = 30,
	cratesPerCar = 3, -- cars = crates / 3, rounded up

	-- Fewer than this many players at arrival: NPC neighbors load one crate every npcSeconds
	-- (so a solo player can still reach the 75% tier)
	npcBelowPlayers = 3,
	npcSeconds = 3 * MIN,

	-- Raw goods only (the Express is a shared sink for raw goods): crops and animal goods the
	-- server's median player has unlocked. A crate asks for the low half of the good's
	-- Cargo Blimp range at that level.
	goodKinds = table.freeze({ Crop = true, Animal = true }),

	tiers = table.freeze({ 0.25, 0.5, 0.75, 1 }),
	-- What each tier pays every contributor: Coins plus one prize stack drawn when the train
	-- arrives (the same for everyone, shown up front). Tier 1 pays Coins only.
	tierCoins = table.freeze({ 60, 120, 200, 320 }),
	tierPrizes = table.freeze({
		false,
		table.freeze({ kind = "material", qty = 1 }),
		table.freeze({ kind = "tool", qty = 1 }),
		table.freeze({ kind = "material", qty = 3 }),
	}),
	tools = table.freeze({ "Shovel", "Axe", "Saw" }),
	materials = table.freeze({ "Nails", "Hinges", "Paint", "Bricks", "Planks", "Panes" }),
	-- A loaded crate also pays its goods' XP at once
	crateXpMult = 1,
})
