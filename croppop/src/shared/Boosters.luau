--[[
	Crop Pop boosters (names from F12 Crop Pop Puzzle).

	Pre-level boosters are picked before a level and place a power-up on the
	starting board. In-level boosters are used during play and don't cost a
	move. Both are checked by the server replay.

	Gem prices follow the Township baseline (township.fandom.com Match-3 page,
	sold in 3s): new-scale T-cash / 25 for the 2025 rescale, / 3 per booster.
	Rocket's price is garbled on the wiki and Garden Gloves has no Township
	match, so those two are first-pass. The starting stock is first-pass too.
]]

local Boosters = {}

Boosters.PreLevel = { "SprayerStart", "BombStart", "SunflowerStart" }
Boosters.InLevel = { "Trowel", "Rake", "GardenGloves", "ShakeUp" }

Boosters.Info = table.freeze({
	SprayerStart = { name = "Sprayer Start", when = "pre", power = "Sprayer", gems = 15 }, -- first-pass, under Bomb Start
	BombStart = { name = "Bomb Start", when = "pre", power = "HayBomb", gems = 20 }, -- Dynamite: 3 for 1500
	SunflowerStart = { name = "Sunflower Start", when = "pre", power = "Sunflower", gems = 25 }, -- Rainbow Ball: 3 for 1900
	-- `args` is how many numbers follow the booster name in a replay action.
	Trowel = { name = "Trowel", when = "in", args = 2, gems = 25, help = "Break one tile" }, -- { "Trowel", x, y }; Jackhammer: 3 for 1900
	Rake = { name = "Rake", when = "in", args = 1, gems = 52, help = "Clear one row" }, -- { "Rake", y }; Drill: 3 for 3900
	GardenGloves = { name = "Garden Gloves", when = "in", args = 4, gems = 30, help = "Swap any two tiles" }, -- { "GardenGloves", x1, y1, x2, y2 }
	ShakeUp = { name = "Shake-Up", when = "in", args = 0, gems = 25, help = "Shuffle the board" }, -- { "ShakeUp" }; Fan: 3 for 1900
})

--[[
	Paid continues: +5 moves when a level runs out, for Gems that rise with
	each continue in the same run, the later ones adding a power-up (F12).
	Township's first continue was 10 T-cash on the old scale, so 10 Gems; the
	later steps are first-pass. Fixed prices, nothing random is sold.
]]
Boosters.Continue = table.freeze({
	MOVES = 5,
	MAX_PER_RUN = 10,
	Steps = table.freeze({
		{ gems = 10 },
		{ gems = 20, power = "Sprayer" },
		{ gems = 35, power = "HayBomb" },
		{ gems = 50, power = "HayBomb" }, -- and every continue after it
	}),
})

-- The price and power-up of the nth continue in a run.
function Boosters.continueStep(n: number)
	local steps = Boosters.Continue.Steps
	return steps[math.clamp(n, 1, #steps)]
end

Boosters.STARTING_STOCK = 2 -- of each, for a new player
Boosters.MAX_STOCK = 99

function Boosters.newStock(): { [string]: number }
	local stock = {}
	for kind in Boosters.Info do
		stock[kind] = Boosters.STARTING_STOCK
	end
	return stock
end

function Boosters.fromSave(raw: any): { [string]: number }
	local stock = Boosters.newStock()
	if type(raw) == "table" then
		for kind in Boosters.Info do
			local n = raw[kind]
			if type(n) == "number" and n == n then
				stock[kind] = math.clamp(math.floor(n), 0, Boosters.MAX_STOCK)
			end
		end
	end
	return stock
end

return Boosters
