--!strict
-- Sky events (Design/14 Multiplayer Features H1; 13 Roblox Success Mechanics §3.2 "weather that
-- matters"; roadmap weeks 2-5): server-wide moments everyone sees at the same instant. v1 has
-- the Rain Shower and Starfall; the Rainbow and rare visitors come in v1.1. Township has no
-- weather, so every number here is first-pass from the design notes.
--
-- Decided defaults (tell Giovanni, easy to change):
--   * A fixed schedule on the UTC clock, the same on every server, so the Notice Board can
--     forecast it ("Rain Shower expected at :31") and the Town Bell Hour can chain it later.
--   * One event every hour between :25 and :38, and a second between :46 and :52 on 40% of
--     hours (every hour on Saturday 17:00-22:00 UTC, the weekly peak in 20 Live Ops §5). Both
--     stay clear of the Town Express window (:00-:20 on even hours).
--   * Effects are bonus-only and only for players on the server (nobody offline loses out).

local MIN = 60

export type Kind = {
	displayName: string,
	seconds: number,
	weight: number,
	trait: string, -- the Prize Crop trait fields growing during it can turn
	growBoost: number?, -- growing fields grow this much faster while it lasts
	stars: boolean?, -- stars fall for each player to catch
}

return table.freeze({
	kinds = table.freeze({
		Rain = table.freeze({
			displayName = "Rain Shower",
			seconds = 3 * MIN,
			weight = 3,
			trait = "Dewkissed",
			growBoost = 0.15,
		} :: Kind),
		Starfall = table.freeze({
			displayName = "Starfall",
			seconds = 2 * MIN,
			weight = 2,
			trait = "Starlit",
			stars = true,
		} :: Kind),
	}),
	order = table.freeze({ "Rain", "Starfall" }), -- the order weights are walked in

	-- Minutes past the hour an event can start in, and the chance the slot has one
	slots = table.freeze({
		table.freeze({ from = 25, to = 38, chance = 1 }),
		table.freeze({ from = 46, to = 52, chance = 0.4 }),
	}),
	-- The weekly peak (UTC; weekday 0 = Sunday): every slot has an event
	peak = table.freeze({ weekday = 6, fromHour = 17, toHour = 22 }),

	forecastSeconds = 10 * MIN, -- the Notice Board forecasts the next event this long ahead

	-- Starfall: each player's own stars (nobody can take anyone else's), checked by the server
	starEvery = 10, -- seconds between stars for each player: 12 in a 2-minute Starfall
	starFall = 1.5, -- seconds a star takes to land (it can be caught once it has)
	starRadius = table.freeze({ 10, 28 }), -- studs from the avatar a star lands
	starReach = 12, -- flat studs the avatar must be within to catch one (the client catches at 7)
	starLinger = 20, -- seconds a star waits after the Starfall ends
	starCoins = 4, -- Coins a star gives: starCoins + starCoinsPerLevel x level
	starCoinsPerLevel = 1,
	starXp = 1,
	luckyChance = 0.1, -- per Starfall per player: one star is a Lucky Star with an Heirloom Seed
	-- Catching every star of a whole Starfall adds one reward drawn from the train's reward
	-- table (building materials and tools, Config/Train)

	-- The Rainbow (14 H1 v1.1): after some Rain Showers a rainbow ends on one farm on the
	-- server, picked at random, with a chest at its foot near the farm's gate. Everyone who
	-- walks up to it within its time opens one chest (the owner too), and the owner gets a
	-- thank-you in Coins for each neighbor who came.
	rainbow = table.freeze({
		chance = 0.5, -- per Rain Shower, as it ends
		seconds = 3 * MIN,
		reach = 14, -- flat studs from the chest (the client opens it at 7)
		ahead = 14, -- studs up the spine path from where visitors arrive at the gate
		coins = 10, -- a chest: coins + coinsPerLevel x level, XP, and maybe a material or tool
		coinsPerLevel = 2,
		xp = 5,
		rewardChance = 0.5, -- one reward from the train's table
		thanksCoins = 5, -- to the owner for each neighbor: thanksCoins + thanksPerLevel x level
		thanksPerLevel = 1,
		thanksMax = 5, -- neighbors a rainbow thanks the owner for
	}),

	-- The Golden Goose (14 H2, a rare visitor): now and then it lands on one farm on the
	-- server, picked at random, beside the path up from the gate. Everyone who walks up to it
	-- (the owner too) gets a Golden Egg once, which sells on the spot for Coins, and the owner
	-- gets a thank-you for each neighbor. Only one visitor at a time, and never during a sky
	-- event or a rainbow.
	goose = table.freeze({
		checkSeconds = 20 * MIN, -- how often the server rolls for a visit
		chance = 0.2, -- per roll: about one visit every 1.7 hours on a busy server
		seconds = 5 * MIN,
		reach = 14,
		ahead = 22, -- studs up the spine path from the gate
		side = 7, -- studs to the right of it (clear of a rainbow's chest)
		eggCoins = 25, -- a Golden Egg: eggCoins + eggCoinsPerLevel x level, and XP
		eggCoinsPerLevel = 5,
		xp = 10,
		thanksMax = 8, -- neighbors the owner is thanked for (Coins as the Rainbow's thanks)
	}),
})
