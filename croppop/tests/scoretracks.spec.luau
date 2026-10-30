-- Score tracks: weekly Bee Parade / Corn Harvest points, step rewards, x2 points and free starts.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local RunStore = require(game.ServerScriptService.CropPopServer.RunStore)
local Engine, Levels, Rng = CropPop.Engine, CropPop.Levels, CropPop.Rng
local Hearts, Boosters, ScoreTracks = CropPop.Hearts, CropPop.Boosters, CropPop.ScoreTracks

local DAY = 24 * 60 * 60
-- Day 0 of the Unix clock was a Thursday; day 4 is the next Monday.
local MONDAY = 4 * DAY
local FRIDAY = 8 * DAY

local function makeStore(start, config)
	local now = start
	local seeds = Rng.new(5)
	local settings = {
		clock = function()
			return now
		end,
		newSeed = function()
			return seeds:int(1, 2 ^ 31 - 1)
		end,
		unlockAll = true,
		cups = false, -- its personal goal pays hearts too (see cup.spec)
	}
	for k, v in config or {} do
		settings[k] = v
	end
	return RunStore.new(settings), function(dt)
		now += dt
	end
end

local function winLevel(store, tick, userId, levelId, boosters)
	local picker = Rng.new(levelId * 17)
	for _ = 1, 200 do
		tick(Hearts.REFILL_SECONDS)
		local run = assert(store:start(userId, levelId, boosters))
		local pop = Engine.new(Levels.get(levelId), run.seed, { startPowerUps = run.startPowerUps })
		local moves = {}
		while pop.status == "Playing" do
			local m = picker:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(moves, m)
		end
		local result = assert(store:finish(userId, run.token, moves))
		if result.won then
			return result, run
		end
	end
	error("could not win level " .. levelId)
end

test("Corn Harvest runs Monday to Thursday and Bee Parade Friday to Sunday", function()
	local mon = ScoreTracks.at(MONDAY + 3600)
	eq(mon.id, "CornHarvest")
	eq(mon.startsAt, MONDAY)
	eq(mon.endsAt, MONDAY + 4 * DAY)
	local thu = ScoreTracks.at(MONDAY + 4 * DAY - 1)
	eq(thu.id, "CornHarvest")
	eq(thu.key, mon.key)
	local fri = ScoreTracks.at(FRIDAY)
	eq(fri.id, "BeeParade")
	eq(fri.endsAt, FRIDAY + 3 * DAY)
	eq(ScoreTracks.at(FRIDAY + 3 * DAY - 1).key, fri.key)
	local nextMon = ScoreTracks.at(FRIDAY + 3 * DAY)
	eq(nextMon.id, "CornHarvest")
	truthy(nextMon.key ~= mon.key, "a new week's run")
end)

test("the tracks have Township's step counts and end on the big Gem prize", function()
	eq(#ScoreTracks.Tracks.BeeParade.steps, 20)
	eq(#ScoreTracks.Tracks.CornHarvest.steps, 25)
	for id, track in ScoreTracks.Tracks do
		eq(track.steps[#track.steps].reward.gems, 400, id)
		for i, s in track.steps do
			truthy(s.points >= 1, id .. " step " .. i)
			for kind in s.reward.boosters or {} do
				truthy(Boosters.Info[kind], kind)
			end
			if s.reward.freeStart then
				eq(Boosters.Info[s.reward.freeStart.kind].when, "pre")
			end
		end
	end
	eq(ScoreTracks.stepsReached("BeeParade", 0), 0)
	eq(ScoreTracks.stepsReached("BeeParade", 1), 1)
	eq(ScoreTracks.stepsReached("BeeParade", 3), 3)
	local totals = ScoreTracks.totals("CornHarvest")
	eq(ScoreTracks.stepsReached("CornHarvest", totals[25]), 25)
	eq(ScoreTracks.stepsReached("CornHarvest", totals[25] - 1), 24)
end)

test("points come from bees made or corn cleared, doubled under x2", function()
	local stats = { made = { Bumblebee = 3, HayBomb = 2 }, cleared = { [CropPop.Tiles.ByName.Corn] = 40, [1] = 99 } }
	eq(ScoreTracks.pointsFor("BeeParade", stats), 3)
	eq(ScoreTracks.pointsFor("CornHarvest", stats), 40)
	eq(ScoreTracks.pointsFor("CornHarvest", stats, true), 80)
	eq(ScoreTracks.pointsFor("BeeParade", {}), 0)
	eq(ScoreTracks.pointsFor("Nope", stats), 0)
end)

test("the engine counts power-ups made and tiles cleared", function()
	local level = Levels.get(12)
	local pop = Engine.new(level, 3)
	local rng = Rng.new(3)
	while pop.status == "Playing" do
		local m = rng:pick(pop:listPossibleMoves())
		pop:trySwap(m[1], m[2], m[3], m[4])
	end
	local made, cleared = 0, 0
	for _, n in pop.stats.made do
		made += n
	end
	for _, n in pop.stats.cleared do
		cleared += n
	end
	eq(made, pop.stats.powerUpsMade)
	truthy(cleared > 0)
	local state = pop:getState()
	state.stats.made.Bumblebee = 999
	truthy(pop.stats.made.Bumblebee ~= 999, "getState hands out a copy")
end)

test("a win adds track points and pays every step it reaches", function()
	local store, tick = makeStore(MONDAY)
	local result = winLevel(store, tick, 1, 12)
	local track = result.track
	eq(track.id, "CornHarvest")
	local corn = result.stats.cleared[CropPop.Tiles.ByName.Corn] or 0
	eq(track.gained, corn)
	eq(track.points, corn)
	eq(#track.steps, ScoreTracks.stepsReached("CornHarvest", corn))
	local progress = store:getProgress(1)
	eq(progress.track.points, corn)
	eq(progress.track.paid, #track.steps)
	truthy(progress.track.secondsLeft > 0 and progress.track.secondsLeft <= 4 * DAY)
	if #track.steps >= 1 then
		eq(progress.boosters.SprayerStart, Boosters.STARTING_STOCK + 1, "step 1 pays a Sprayer Start")
	end
	if #track.steps >= 2 then
		eq(result.rewards.trackCoins, 50)
	end
end)

test("step rewards: coins and Gems go to the farm, the rest to the save", function()
	local store, tick = makeStore(FRIDAY, { devActions = true })
	tick(10)
	-- Bee Parade steps 1-10: 1+1+1+2+1+3+1+4+2+5 = 21 points.
	local result = assert(store:devTrackPoints(2, 21))
	eq(#result.track.steps, 10)
	eq(result.rewards.coins, 100)
	eq(result.rewards.trackCoins, 100)
	eq(result.rewards.gems, 8)
	local p = result.progress
	eq(p.boosters.SprayerStart, Boosters.STARTING_STOCK + 1)
	truthy(p.hearts.unlimitedSeconds > 0 and p.hearts.unlimitedSeconds <= 30 * 60)
	eq(p.track.doubleSeconds, 45 * 60, "15 + 30 minutes of x2")
	eq(p.freeStarts.SprayerStart, 30 * 60)
	eq(p.freeStarts.SunflowerStart, 30 * 60)
	eq(p.freeStarts.BombStart, 30 * 60)
	-- Nothing more until the next step.
	local again = assert(store:devTrackPoints(2, 1))
	eq(#again.track.steps, 0)
	eq(again.rewards.gems, nil)
end)

test("free start boosters go on every level without using stock, and run out", function()
	local store, tick = makeStore(FRIDAY, { devActions = true })
	tick(10)
	assert(store:devTrackPoints(3, 3)) -- step 3: 30 min free Sprayer Start
	local run = assert(store:start(3, 1))
	eq(#run.freeStarts, 1)
	eq(run.freeStarts[1], "SprayerStart")
	eq(run.startPowerUps[1], "Sprayer")
	-- Picking it as well doesn't charge for it or add a second one.
	tick(2)
	local before = store:getProgress(3).boosters.SprayerStart
	local picked = assert(store:start(3, 1, { "SprayerStart" }))
	eq(store:getProgress(3).boosters.SprayerStart, before)
	local sprayers = 0
	for _, power in picked.startPowerUps do
		if power == "Sprayer" then
			sprayers += 1
		end
	end
	eq(sprayers, 1)
	tick(31 * 60)
	local later = assert(store:start(3, 1))
	eq(#later.freeStarts, 0)
	eq(store:getProgress(3).freeStarts.SprayerStart, nil)
end)

test("x2 points double a win's points while they last", function()
	local store, tick = makeStore(MONDAY, { devActions = true })
	tick(10)
	-- Corn Harvest steps 1-4 (1+3+5+15 = 24) include 15 min of x2.
	assert(store:devTrackPoints(4, 24))
	truthy(store:getProgress(4).track.doubleSeconds > 0)
	local result = winLevel(store, tick, 4, 12)
	if result.track.doubled then
		eq(result.track.gained, 2 * (result.stats.cleared[CropPop.Tiles.ByName.Corn] or 0))
	else
		eq(result.track.gained, result.stats.cleared[CropPop.Tiles.ByName.Corn] or 0)
	end
	tick(16 * 60)
	eq(store:getProgress(4).track.doubleSeconds, 0)
	local plain = winLevel(store, tick, 4, 12)
	falsy(plain.track.doubled)
end)

test("points start over when the next track begins", function()
	local store, tick = makeStore(MONDAY + 3 * DAY, { devActions = true })
	assert(store:devTrackPoints(5, 30))
	eq(store:getProgress(5).track.id, "CornHarvest")
	tick(DAY) -- Friday
	local p = store:getProgress(5)
	eq(p.track.id, "BeeParade")
	eq(p.track.points, 0)
	eq(p.track.paid, 0)
end)

test("track state saves and loads, and bad values are dropped", function()
	local store, tick = makeStore(FRIDAY, { devActions = true })
	tick(10)
	assert(store:devTrackPoints(6, 9))
	local block = store:exportSave(6)
	eq(block.track.points, 9)
	local other = makeStore(FRIDAY + 60)
	other:importSave(6, block)
	local p = other:getProgress(6)
	eq(p.track.points, 9)
	eq(p.track.paid, block.track.paid)
	truthy(p.freeStarts.SprayerStart ~= nil)
	other:importSave(7, { v = 1, track = { id = "Hacks", key = 1, points = 1e9, paid = 99 }, doubleUntil = "soon", freeStarts = { SprayerStart = 0 / 0, Nope = 5 } })
	local q = other:getProgress(7)
	eq(q.track.points, 0)
	eq(q.track.doubleSeconds, 0)
	eq(next(q.freeStarts), nil)
	other:importSave(8, { v = 1, track = { id = "BeeParade", key = ScoreTracks.at(FRIDAY).key, points = 3, paid = 999 } })
	eq(other:getProgress(8).track.paid, 20, "paid is capped at the step count")
end)

test("the dev grant only works in Studio, and tracks can be turned off", function()
	local live = makeStore(MONDAY)
	falsy(live:devTrackPoints(9, 10))
	local off, tick = makeStore(MONDAY, { scoreTracks = false })
	eq(off:getProgress(9).track, nil)
	eq(winLevel(off, tick, 9, 1).track, nil)
end)
