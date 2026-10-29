--!strict
-- Small deterministic RNG (Park–Miller) whose whole state is one saveable integer, so
-- regenerated orders are reproducible from the player's seed. Runs the same in Roblox and Lune.

local Rng = {}

local MOD = 2147483647
local MULT = 48271

function Rng.normalize(seed: number): number
	seed = math.floor(math.abs(seed)) % MOD
	if seed == 0 then
		seed = 1
	end
	return seed
end

-- Returns a float in [0, 1) and the next seed.
function Rng.next(seed: number): (number, number)
	local nextSeed = (Rng.normalize(seed) * MULT) % MOD
	return (nextSeed - 1) / (MOD - 1), nextSeed
end

-- Returns an integer in [min, max] and the next seed.
function Rng.int(seed: number, min: number, max: number): (number, number)
	local r, nextSeed = Rng.next(seed)
	return min + math.floor(r * (max - min + 1)), nextSeed
end

return Rng
