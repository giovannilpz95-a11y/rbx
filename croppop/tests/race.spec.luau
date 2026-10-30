-- Tractor Race: 4-player races to 15 wins on race weekends.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local RunStore = require(game.ServerScriptService.CropPopServer.RunStore)
local CupBoard = require(game.ServerScriptService.CropPopServer.CupBoard)
local Engine, Levels, Rng = CropPop.Engine, CropPop.Levels, CropPop.Rng
local Hearts, Race = CropPop.Hearts, CropPop.Race

local DAY = 24 * 60 * 60
-- Day 0 of the Unix clock was a Thursday; day 1 a Friday.
local FRIDAY = 1 * DAY
local MONDAY = 4 * DAY

local function makeStore(start, config)
	local now = start
	local seeds = Rng.new(21)
	local settings = {
		clock = function()
			return now
		end,
		newSeed = function()
			return seeds:int(1, 2 ^ 31 - 1)
		end,
		unlockAll = true,
		scoreTracks = false,
		cups = false,
		devActions = true,
	}
	for k, v in config or {} do
		settings[k] = v
	end
	return RunStore.new(settings), function(dt)
		now += dt
	end
end

local function winLevel(store, tick, userId)
	local picker = Rng.new(userId * 7)
	for _ = 1, 200 do
		tick(60)
		store:devSetHearts(userId, Hearts.MAX)
		local run = assert(store:start(userId, 1))
		local pop = Engine.new(Levels.get(1), run.seed, { startPowerUps = run.startPowerUps })
		local moves = {}
		while pop.status == "Playing" do
			local m = picker:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(moves, m)
		end
		local result = assert(store:finish(userId, run.token, moves))
		if result.won then
			return result
		end
	end
	error("could not win")
end

test("races run Friday to Sunday", function()
	local fri = Race.at(FRIDAY + 5)
	eq(fri.key, 1)
	eq(fri.endsAt, FRIDAY + 3 * DAY)
	eq(Race.at(MONDAY - 1).key, 1)
	eq(Race.at(MONDAY), nil)
	eq(Race.at(0), nil, "Thursday")
	eq(Race.secondsToNext(0), DAY)
	eq(Race.secondsToNext(FRIDAY), 0)
	eq(Race.secondsToNext(MONDAY + 10), 4 * DAY - 10)
end)

test("scores sort finishers by who finished first", function()
	local start = FRIDAY
	local early = Race.score(15, start + 100, start)
	local late = Race.score(15, start + 5000, start)
	local racing = Race.score(14, nil, start)
	truthy(early > late and late > racing)
	eq(Race.winsOf(early), 15)
	truthy(Race.finished(late))
	falsy(Race.finished(racing))
	eq(Race.winsOf(Race.score(99, nil, start)), 15, "capped")
	eq(Race.prizeFor(1, 1), nil, "nobody else in the race")
	eq(Race.prizeFor(1, 4).unlimitedMinutes, 60)
	eq(Race.prizeFor(3, 2).boosters.BombStart, 1)
	eq(Race.prizeFor(4, 4), nil)
end)

test("no race on weekdays", function()
	local store, tick = makeStore(MONDAY)
	local p = store:getProgress(1).race
	falsy(p.running)
	eq(p.secondsToNext, 4 * DAY)
	eq(winLevel(store, tick, 1).race, nil)
end)

test("a win enters a race of 4 and counts towards 15", function()
	local board = CupBoard.memory(Race.SIZE)
	local store, tick = makeStore(FRIDAY, { raceBoard = board })
	local result = winLevel(store, tick, 1)
	eq(result.race.wins, 1)
	eq(result.race.target, 15)
	falsy(result.race.finished)
	for userId = 2, 5 do
		winLevel(store, tick, userId)
	end
	store:refreshRace(1, true)
	local p = store:getProgress(1).race
	truthy(p.running and p.entered)
	eq(#p.standings, 4, "players 1-4 share a race")
	store:refreshRace(5, true)
	eq(#store:getProgress(5).race.standings, 1, "the 5th starts the next one")
end)

test("finishing pays the place's prize, and the next win starts a new race", function()
	local store, tick = makeStore(FRIDAY)
	tick(10)
	winLevel(store, tick, 2) -- a rival in the same race
	for _ = 1, 2 do
		assert(store:devRace(1)) -- 10 wins
	end
	local before = store:getProgress(1).boosters.Trowel
	local done = assert(store:devRace(1)).race
	truthy(done.finished)
	eq(done.wins, 15)
	eq(done.place, 1)
	eq(done.racers, 2)
	eq(done.prize.unlimitedMinutes, 60)
	local p = store:getProgress(1)
	eq(p.boosters.Trowel, before + 1)
	truthy(p.race.finished)
	eq(p.race.place, 1)
	local next = winLevel(store, tick, 1)
	eq(next.race.wins, 1, "a new race")
	falsy(store:getProgress(1).race.finished)
end)

test("alone in a race, finishing pays nothing", function()
	local store = makeStore(FRIDAY)
	local last
	for _ = 1, 3 do
		last = assert(store:devRace(7)).race
	end
	truthy(last.finished)
	eq(last.place, 1)
	eq(last.prize, nil)
end)

test("a race is over for the rest once 3 have finished", function()
	local store, tick = makeStore(FRIDAY)
	tick(10)
	winLevel(store, tick, 9) -- the slow one
	for userId = 10, 12 do
		for _ = 1, 3 do
			assert(store:devRace(userId))
		end
	end
	store:refreshRace(9, true)
	local p = store:getProgress(9).race
	truthy(p.over)
	falsy(p.finished)
	eq(winLevel(store, tick, 9).race.wins, 1, "the next win starts a new race")
end)

test("race state saves, loads and starts over on a new weekend", function()
	local store, tick = makeStore(FRIDAY)
	assert(store:devRace(3))
	local block = store:exportSave(3)
	eq(block.race.wins, 5)
	local other = makeStore(FRIDAY + 60)
	other:importSave(3, block)
	eq(other:getProgress(3).race.wins, 5)
	other:importSave(4, { v = 1, race = { key = 1, group = "x", wins = 9 } })
	eq(other:getProgress(4).race.wins, 0)
	tick(7 * DAY)
	eq(store:getProgress(3).race.wins, 0, "next weekend")
end)

test("races can be turned off, Studio can race every day, and the dev grant needs Studio", function()
	local off = makeStore(FRIDAY, { races = false })
	eq(off:getProgress(1).race, nil)
	local studio = makeStore(MONDAY, { raceEveryDay = true })
	truthy(studio:getProgress(1).race.running)
	local live = makeStore(FRIDAY, { devActions = false })
	falsy(live:devRace(1))
end)
