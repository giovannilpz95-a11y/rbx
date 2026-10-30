--!strict
-- Daily login rules (Config/Daily), pure for the server and the Lune tests. Saved as
-- data.daily = { day = n (days claimed in this 7-day round), lastDay = UTC day number }.

local Daily = require("./Config/Daily")

local DailyRules = {}

function DailyRules.utcDay(now: number): number
	return now // 86400
end

-- The reward due today and its day of the calendar (1-7), or nil when none is due.
function DailyRules.due(data: { [string]: any }, now: number): (Daily.Reward?, number)
	if data.level < Daily.unlockLevel or DailyRules.utcDay(now) <= data.daily.lastDay then
		return nil, 0
	end
	-- A missed UTC day starts the round again from day 1 (Township; Wiki Data - Progression,
	-- Town & Social C10)
	local missed = data.daily.lastDay >= 0 and DailyRules.utcDay(now) > data.daily.lastDay + 1
	local day = if missed then 1 else data.daily.day % #Daily.days + 1
	return DailyRules.rewardFor(day, data.level), day
end

-- Day `day`'s reward at `level` (Coins scale with the level band).
function DailyRules.rewardFor(day: number, level: number): Daily.Reward
	local reward = Daily.days[day]
	local mult = 1
	for _, band in Daily.coinBands do
		if level >= band.minLevel then
			mult = band.mult
		end
	end
	return {
		coins = if reward.coins then math.floor(reward.coins * mult) else nil,
		gems = reward.gems,
		item = reward.item,
	}
end

-- Mark today's reward taken.
function DailyRules.claim(data: { [string]: any }, now: number, day: number)
	data.daily.day = day
	data.daily.lastDay = DailyRules.utcDay(now)
end

return DailyRules
