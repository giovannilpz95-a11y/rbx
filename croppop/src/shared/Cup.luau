--[[
	The Harvest Cup: a leaderboard competition on Crop Pop wins (the Township
	Match-3 Reference note, section 7, Mayor's Cup).

	Three cups a week (UTC days): Mon-Tue, Wed-Thu and Fri-Sun. Winning a level
	during a cup enters you into a group of up to GROUP_SIZE players, and every
	win scores cups by difficulty: 1 Normal, 3 Tough, 5 Super Tough. When the
	cup ends, the top 10 of each group get prizes. Reaching PERSONAL_GOAL cups
	pays a small prize at once, whatever your place.

	Prizes follow Township's places: unlimited hearts, start boosters
	(Rainbow Ball / Rocket / Dynamite -> Sunflower / Sprayer / Bomb Start) and
	in-level boosters (Glove / Hydrant / Jackhammer -> Garden Gloves / Shake-Up /
	Trowel). Township's Load and Barn coupons are farm items Crop Pop doesn't
	have, so they're left out. You only place if you beat someone: a group of
	one pays the personal goal but no place prize.

	Township groups players by its own matchmaking and doesn't publish the
	group size or the personal-goal target, so GROUP_SIZE and PERSONAL_GOAL are
	first-pass.
]]

local Cup = {}

local DAY = 24 * 60 * 60

Cup.NAME = "Harvest Cup"
Cup.GLYPH = "🏆"
Cup.GROUP_SIZE = 30
Cup.PERSONAL_GOAL = 20
Cup.PersonalPrize = table.freeze({ unlimitedMinutes = 30 })

Cup.CupsFor = table.freeze({ Normal = 1, Tough = 3, ["Super Tough"] = 5 })

-- Runs of weekdays (0 = Monday).
local RUNS = { { 0, 1 }, { 2, 3 }, { 4, 5, 6 } }

export type Prize = {
	unlimitedMinutes: number?,
	boosters: { [string]: number }?,
}

local function places(): { Prize }
	local out = {
		{
			unlimitedMinutes = 180,
			boosters = { SunflowerStart = 3, SprayerStart = 3, BombStart = 3, GardenGloves = 1, ShakeUp = 1, Trowel = 1 },
		},
		{
			unlimitedMinutes = 120,
			boosters = { SunflowerStart = 2, SprayerStart = 2, BombStart = 2, GardenGloves = 1, Trowel = 1 },
		},
		{
			unlimitedMinutes = 60,
			boosters = { SunflowerStart = 2, SprayerStart = 2, BombStart = 2 },
		},
	}
	for _ = 4, 10 do
		table.insert(out, { boosters = { SunflowerStart = 1, SprayerStart = 1, BombStart = 1 } })
	end
	return out
end
Cup.Places = table.freeze(places())

-- 0 = Monday. Day 0 of the Unix clock was a Thursday.
local function weekday(day: number): number
	return (day + 3) % 7
end

-- The cup running at `now`: { key (its first day), startsAt, endsAt }.
function Cup.at(now: number)
	local today = now // DAY
	local wd = weekday(today)
	for _, run in RUNS do
		if wd >= run[1] and wd <= run[#run] then
			local startDay = today - (wd - run[1])
			return { key = startDay, startsAt = startDay * DAY, endsAt = (startDay + #run) * DAY }
		end
	end
	error("no cup for weekday " .. wd)
end

function Cup.cupsFor(difficulty: string?): number
	return Cup.CupsFor[difficulty or "Normal"] or 1
end

-- The prize for finishing `place` in a group of `players`, or nil.
function Cup.prizeFor(place: number?, players: number): Prize?
	-- You only place if someone finished below you.
	if not place or place < 1 or place >= players then
		return nil
	end
	return Cup.Places[place]
end

return table.freeze(Cup)
