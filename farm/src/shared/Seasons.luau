--!strict
-- Which seasonal look is on (Config/Seasons): each season starts on the first Friday (UTC) of
-- its first month and lasts until the next one starts. Pure date maths, the same on every
-- server and client.

local Config = require("./Config/Seasons")

local Seasons = {}

local DAY = 86400

-- Days since 1970-01-01 for a UTC calendar date (Howard Hinnant's days_from_civil)
local function daysFromCivil(y: number, m: number, d: number): number
	if m <= 2 then
		y -= 1
	end
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- The UTC year of `now`
local function yearOf(now: number): number
	local days = now // DAY
	local y = 1970 + days // 366
	while daysFromCivil(y + 1, 1, 1) <= days do
		y += 1
	end
	return y
end

-- Unix seconds of the first Friday of `month` in `year` (UTC midnight)
function Seasons.firstFriday(year: number, month: number): number
	local first = daysFromCivil(year, month, 1)
	local weekday = (first + 4) % 7 -- 1970-01-01 was a Thursday; 0 = Sunday
	local offset = (5 - weekday) % 7
	return (first + offset) * DAY
end

-- When `id` starts in `year`
function Seasons.startsAt(id: string, year: number): number
	return Seasons.firstFriday(year, Config.seasons[id].firstMonth)
end

-- The season on at `now`
function Seasons.at(now: number): Config.Season
	local year = yearOf(now)
	local best: Config.Season? = nil
	local bestAt = -math.huge
	for _, y in { year - 1, year } do
		for _, id in Config.order do
			local at = Seasons.startsAt(id, y)
			if at <= now and at > bestAt then
				best, bestAt = Config.seasons[id], at
			end
		end
	end
	return best :: Config.Season
end

return Seasons
