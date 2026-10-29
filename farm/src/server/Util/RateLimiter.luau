--!strict
-- Token bucket: `rate` tokens per second, holding at most `burst`.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: { rate: number, burst: number, tokens: number, last: number },
	RateLimiter
))

function RateLimiter.new(rate: number, burst: number): RateLimiter
	return setmetatable({ rate = rate, burst = burst, tokens = burst, last = os.clock() }, RateLimiter)
end

function RateLimiter.take(self: RateLimiter): boolean
	local now = os.clock()
	self.tokens = math.min(self.burst, self.tokens + (now - self.last) * self.rate)
	self.last = now
	if self.tokens < 1 then
		return false
	end
	self.tokens -= 1
	return true
end

return RateLimiter
