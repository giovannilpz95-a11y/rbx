--[[
	Crop Pop boosters (names from F12 Crop Pop Puzzle).

	Pre-level boosters are picked before a level and place a power-up on the
	starting board. In-level boosters are used during play and don't cost a
	move. Both are checked by the server replay.

	Gem prices and the starting stock are first-pass: Township's booster prices
	aren't public.
]]

local Boosters = {}

Boosters.PreLevel = { "SprayerStart", "BombStart", "SunflowerStart" }
Boosters.InLevel = { "Trowel", "Rake", "GardenGloves", "ShakeUp" }

Boosters.Info = table.freeze({
	SprayerStart = { name = "Sprayer Start", when = "pre", power = "Sprayer", gems = 30 },
	BombStart = { name = "Bomb Start", when = "pre", power = "HayBomb", gems = 40 },
	SunflowerStart = { name = "Sunflower Start", when = "pre", power = "Sunflower", gems = 50 },
	-- `args` is how many numbers follow the booster name in a replay action.
	Trowel = { name = "Trowel", when = "in", args = 2, gems = 25, help = "Break one tile" }, -- { "Trowel", x, y }
	Rake = { name = "Rake", when = "in", args = 1, gems = 35, help = "Clear one row" }, -- { "Rake", y }
	GardenGloves = { name = "Garden Gloves", when = "in", args = 4, gems = 30, help = "Swap any two tiles" }, -- { "GardenGloves", x1, y1, x2, y2 }
	ShakeUp = { name = "Shake-Up", when = "in", args = 0, gems = 20, help = "Shuffle the board" }, -- { "ShakeUp" }
})

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
