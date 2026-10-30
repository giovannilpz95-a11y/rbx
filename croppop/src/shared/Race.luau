--[[
	The Tractor Race: a 4-player race on Crop Pop wins (the Township Match-3
	Reference note, section 7, Farmers' Race).

	It runs Friday to Sunday (UTC). Your first win of the weekend puts you in
	a race with up to 3 other players; the first to WINS level wins finish in
	order. The race is over once FINISHERS players have finished, or when the
	weekend ends. Finishing pays your place's prize at once, and your next win
	starts a new race. Any win counts, not only new levels, so players at the
	end of the Trail can race too.

	Township lists only the winner's prize (1 h lives, one each of its three
	start boosters and three in-level boosters). 2nd and 3rd are first-pass,
	stepping down. As in the Harvest Cup, you only place if someone else is in
	the race.

	A racer's board score packs wins and finishing time into one number, so
	the shared OrderedDataStore sorts finishers by who finished first:
		score = wins * SCALE + (if finished then SCALE - 1 - seconds into the weekend else 0)
]]

local Race = {}

local DAY = 24 * 60 * 60

Race.NAME = "Tractor Race"
Race.GLYPH = "🚜"
Race.SIZE = 4
Race.WINS = 15
Race.FINISHERS = 3
Race.SCALE = 1000000 -- above the seconds in a weekend

Race.Places = table.freeze({
	table.freeze({
		unlimitedMinutes = 60,
		boosters = table.freeze({ SunflowerStart = 1, SprayerStart = 1, BombStart = 1, GardenGloves = 1, ShakeUp = 1, Trowel = 1 }),
	}),
	table.freeze({
		unlimitedMinutes = 30,
		boosters = table.freeze({ SunflowerStart = 1, SprayerStart = 1, BombStart = 1 }),
	}),
	table.freeze({
		boosters = table.freeze({ SprayerStart = 1, BombStart = 1 }),
	}),
})

-- 0 = Monday. Day 0 of the Unix clock was a Thursday.
local function weekday(day: number): number
	return (day + 3) % 7
end

-- The race weekend running at `now`: { key (Friday's day), startsAt, endsAt }, or nil on weekdays.
function Race.at(now: number)
	local today = now // DAY
	local wd = weekday(today)
	if wd < 4 then
		return nil
	end
	local friday = today - (wd - 4)
	return { key = friday, startsAt = friday * DAY, endsAt = (friday + 3) * DAY }
end

-- Seconds until the next race weekend starts (0 during one).
function Race.secondsToNext(now: number): number
	local today = now // DAY
	local wd = weekday(today)
	if wd >= 4 then
		return 0
	end
	return (today + (4 - wd)) * DAY - now
end

function Race.score(wins: number, finishedAt: number?, weekendStart: number): number
	wins = math.clamp(math.floor(wins), 0, Race.WINS)
	local bonus = if finishedAt then Race.SCALE - 1 - math.clamp(finishedAt - weekendStart, 0, Race.SCALE - 1) else 0
	return wins * Race.SCALE + bonus
end

function Race.winsOf(score: number): number
	return score // Race.SCALE
end

function Race.finished(score: number): boolean
	return Race.winsOf(score) >= Race.WINS
end

-- The prize for finishing `place` in a race of `racers`, or nil.
function Race.prizeFor(place: number?, racers: number): any?
	if not place or place < 1 or racers < 2 then
		return nil
	end
	return Race.Places[place]
end

return table.freeze(Race)
