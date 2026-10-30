--[[
	Score tracks: a weekly pair of point tracks that run alongside the levels
	(the Township Match-3 Reference note, section 8). One is always on:

		Bee Parade    Fri-Sun (UTC)  Bumblebees made in won levels   20 steps
		Corn Harvest  Mon-Thu (UTC)  Corn tiles cleared in won levels 25 steps

	Reaching a step pays its reward at once. Points start over when the next
	track begins. A "x2 points" reward doubles the points of wins while it lasts.

	Step rewards follow Township's Treasure Tree and Green Machine tracks in
	order and kind: T-cash becomes Gems (new scale / 25), timed boosters become
	free start boosters for that long, lives become unlimited hearts. Building
	materials have no Crop Pop match yet, so they pay Coins (50 each, first-pass).
	Township's point totals assume far more play than ours, so the step costs
	keep Township's shape but are scaled to what the test bot makes per win
	(about 3 bees and 35 corn): about 60 wins finish Bee Parade and 80 finish
	Corn Harvest. Retune here.

		ScoreTracks.at(now) -> { id, key, startsAt, endsAt }
		ScoreTracks.pointsFor(id, stats, doubled) -> number
		ScoreTracks.stepsReached(id, points) -> number
]]

local ScoreTracks = {}

local DAY = 24 * 60 * 60
local Tiles = require(script.Parent.Tiles)

export type Reward = {
	coins: number?,
	gems: number?,
	boosters: { [string]: number }?,
	unlimitedMinutes: number?, -- unlimited hearts
	doubleMinutes: number?, -- x2 track points
	freeStart: { kind: string, minutes: number }?, -- a pre-level booster on every level, free
}

export type Step = { points: number, reward: Reward }

local function step(points: number, reward: Reward): Step
	return table.freeze({ points = points, reward = table.freeze(reward) })
end

local MATERIAL_COINS = 50

ScoreTracks.Tracks = table.freeze({
	BeeParade = table.freeze({
		id = "BeeParade",
		name = "Bee Parade",
		glyph = "🐝",
		unit = "Bumblebees made",
		days = { 4, 5, 6 }, -- Fri, Sat, Sun (0 = Monday)
		-- Treasure Tree: 5, 10, 20, 100, 30, 200, 50, 300, 100, 400, 150, 200, 800,
		-- 200, 800, 5000, 300, 4000, 500, 8000 points, divided by about 85.
		steps = table.freeze({
			step(1, { boosters = { SprayerStart = 1 } }),
			step(1, { coins = MATERIAL_COINS }),
			step(1, { freeStart = { kind = "SprayerStart", minutes = 30 } }),
			step(2, { doubleMinutes = 15 }),
			step(1, { unlimitedMinutes = 30 }),
			step(3, { coins = MATERIAL_COINS }),
			step(1, { freeStart = { kind = "SunflowerStart", minutes = 30 } }),
			step(4, { doubleMinutes = 30 }),
			step(2, { freeStart = { kind = "BombStart", minutes = 30 } }),
			step(5, { gems = 8 }),
			step(2, { boosters = { ShakeUp = 1, Trowel = 1 } }),
			step(3, { doubleMinutes = 30 }),
			step(9, { coins = 3 * MATERIAL_COINS }),
			step(3, { freeStart = { kind = "BombStart", minutes = 30 } }),
			step(9, { boosters = { ShakeUp = 1, GardenGloves = 1 } }),
			step(55, { doubleMinutes = 30 }),
			step(4, { unlimitedMinutes = 120 }),
			step(45, { coins = 5 * MATERIAL_COINS }),
			step(6, { unlimitedMinutes = 90, boosters = { SprayerStart = 1, BombStart = 1, SunflowerStart = 1 } }),
			step(90, { gems = 400 }),
		}),
		points = function(stats)
			return stats.made and stats.made.Bumblebee or 0
		end,
	}),
	CornHarvest = table.freeze({
		id = "CornHarvest",
		name = "Corn Harvest",
		glyph = "🌽",
		unit = "Corn cleared",
		days = { 0, 1, 2, 3 }, -- Mon to Thu
		-- Green Machine: 40, 100, 200, 600, 200, 500, 1200, 800, 800, 1600, 800, 2400,
		-- 600, 2400, 1200, 4700, 2000, 4000, 9500, 2400, 4000, 39500, 2400, 23700,
		-- 39500 points, divided by 40. Gems at steps 10, 22 and 25 and materials at
		-- 2, 7, 16 and 19 as on the wiki; the rest follow the same rhythm.
		steps = table.freeze({
			step(1, { boosters = { SprayerStart = 1 } }),
			step(3, { coins = MATERIAL_COINS }),
			step(5, { freeStart = { kind = "SprayerStart", minutes = 30 } }),
			step(15, { doubleMinutes = 15 }),
			step(5, { unlimitedMinutes = 30 }),
			step(13, { boosters = { Trowel = 1 } }),
			step(30, { coins = 2 * MATERIAL_COINS }),
			step(20, { doubleMinutes = 30 }),
			step(20, { freeStart = { kind = "BombStart", minutes = 30 } }),
			step(40, { gems = 8 }),
			step(20, { boosters = { Rake = 1, ShakeUp = 1 } }),
			step(60, { doubleMinutes = 30 }),
			step(15, { unlimitedMinutes = 60 }),
			step(60, { freeStart = { kind = "SunflowerStart", minutes = 30 } }),
			step(30, { boosters = { GardenGloves = 1, Trowel = 1 } }),
			step(118, { coins = 3 * MATERIAL_COINS }),
			step(50, { doubleMinutes = 30 }),
			step(100, { unlimitedMinutes = 120 }),
			step(238, { coins = 5 * MATERIAL_COINS }),
			step(60, { freeStart = { kind = "BombStart", minutes = 60 } }),
			step(100, { doubleMinutes = 60 }),
			step(988, { gems = 56 }),
			step(60, { unlimitedMinutes = 90, boosters = { SprayerStart = 1, BombStart = 1, SunflowerStart = 1 } }),
			step(593, { boosters = { Rake = 2, Trowel = 2 } }),
			step(988, { gems = 400 }),
		}),
		points = function(stats)
			return stats.cleared and stats.cleared[Tiles.ByName.Corn] or 0
		end,
	}),
})

-- 0 = Monday. Day 0 of the Unix clock was a Thursday.
local function weekday(day: number): number
	return (day + 3) % 7
end

-- The track running at `now` (wall-clock seconds). `key` (its first day)
-- tells one week's run from the next.
function ScoreTracks.at(now: number)
	local today = now // DAY
	local wd = weekday(today)
	local track = if wd >= 4 then ScoreTracks.Tracks.BeeParade else ScoreTracks.Tracks.CornHarvest
	local first = track.days[1]
	local startDay = today - (wd - first)
	local endDay = startDay + #track.days
	return { id = track.id, key = startDay, startsAt = startDay * DAY, endsAt = endDay * DAY }
end

-- Points a won level earns on this track.
function ScoreTracks.pointsFor(id: string, stats: any, doubled: boolean?): number
	local track = ScoreTracks.Tracks[id]
	if not track or type(stats) ~= "table" then
		return 0
	end
	local points = math.max(0, math.floor(track.points(stats)))
	return if doubled then points * 2 else points
end

-- The points needed to reach each step, added up.
function ScoreTracks.totals(id: string): { number }
	local out, sum = {}, 0
	for _, s in ScoreTracks.Tracks[id].steps do
		sum += s.points
		table.insert(out, sum)
	end
	return out
end

-- How many steps `points` reaches.
function ScoreTracks.stepsReached(id: string, points: number): number
	local n = 0
	for i, total in ScoreTracks.totals(id) do
		if points >= total then
			n = i
		end
	end
	return n
end

return table.freeze(ScoreTracks)
