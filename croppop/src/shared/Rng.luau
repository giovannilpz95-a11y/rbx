--[[
	Deterministic random numbers for Crop Pop (xorshift32).

	The client and the server must produce the same refills from the same seed,
	so the engine never uses math.random or Random.new. Only bit32 maths here,
	which behaves the same in every Luau runtime.
]]

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

function Rng.new(seed: number): Rng
	local state = math.floor(seed) % 4294967296
	if state == 0 then
		state = 0x9E3779B9
	end
	local self = setmetatable({ state = state }, Rng)
	-- Warm up so nearby seeds don't start with similar numbers.
	for _ = 1, 8 do
		self:nextU32()
	end
	return self
end

function Rng.nextU32(self: Rng): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

-- Integer in [lo, hi].
function Rng.int(self: Rng, lo: number, hi: number): number
	return lo + self:nextU32() % (hi - lo + 1)
end

function Rng.pick<T>(self: Rng, list: { T }): T
	return list[self:int(1, #list)]
end

function Rng.shuffle<T>(self: Rng, list: { T })
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

return Rng
