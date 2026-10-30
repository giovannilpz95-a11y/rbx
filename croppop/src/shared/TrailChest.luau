--[[
	Trail Chests (F12 Crop Pop Puzzle): beating every 10th level for the first
	time opens one. Contents are fixed per chest, never random, and paid to
	the save by the server when the win checks out:

		TrailChest.forLevel(20) -> { number = 2, coins = 120, boosters = { BombStart = 1, Rake = 2 },
		                            unlimitedMinutes = 15 }

	Numbers are first-pass (Township has no direct equivalent); the economy
	thread can retune them here.
]]

local TrailChest = {}

TrailChest.EVERY = 10 -- levels per chest
local BASE_COINS = 100
local COINS_PER_CHEST = 20
local Boosters = require(script.Parent.Boosters)

local PRE = Boosters.PreLevel
local IN = Boosters.InLevel

export type Chest = {
	number: number,
	coins: number,
	boosters: { [string]: number },
	unlimitedMinutes: number,
}

-- The chest on this level, or nil if it has none.
function TrailChest.forLevel(levelId: number): Chest?
	if levelId < TrailChest.EVERY or levelId % TrailChest.EVERY ~= 0 then
		return nil
	end
	local n = levelId // TrailChest.EVERY
	local boosters = {}
	boosters[PRE[(n - 1) % #PRE + 1]] = 1
	local inLevel = IN[(n - 1) % #IN + 1]
	boosters[inLevel] = if n % 2 == 0 then 2 else 1
	return {
		number = n,
		coins = BASE_COINS + COINS_PER_CHEST * (n - 1),
		boosters = boosters,
		-- Every 3rd chest gives a longer Unlimited Hearts bonus.
		unlimitedMinutes = if n % 3 == 0 then 30 else 15,
	}
end

return TrailChest
