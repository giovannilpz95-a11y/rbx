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
	local day = data.daily.day % #Daily.days + 1
	local reward = Daily.days[day]
	local mult = 1
	for _, band in Daily.coinBands do
		if data.level >= band.minLevel then
			mult = band.mult
		end
	end
	return {
		coins = if reward.coins then math.floor(reward.coins * mult) else nil,
		gems = reward.gems,
		item = reward.item,
	},
		day
end

-- Mark today's reward taken.
function DailyRules.claim(data: { [string]: any }, now: number, day: number)
	data.daily.day = day
	data.daily.lastDay = DailyRules.utcDay(now)
end

return DailyRules
