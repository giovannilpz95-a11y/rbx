-- Harvest Cup: groups, cups per win, the personal goal, final places and prizes.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local RunStore = require(game.ServerScriptService.CropPopServer.RunStore)
local CupBoard = require(game.ServerScriptService.CropPopServer.CupBoard)
local Engine, Levels, Rng = CropPop.Engine, CropPop.Levels, CropPop.Rng
local Hearts, Boosters, Cup = CropPop.Hearts, CropPop.Boosters, CropPop.Cup

local DAY = 24 * 60 * 60
-- Day 0 of the Unix clock was a Thursday; day 4 is the next Monday.
local MONDAY = 4 * DAY

local function makeStore(start, config)
	local now = start
	local seeds = Rng.new(9)
	local settings = {
		clock = function()
			return now
		end,
		newSeed = function()
			return seeds:int(1, 2 ^ 31 - 1)
		end,
		unlockAll = true,
		scoreTracks = false,
		races = false,
	}
	for k, v in config or {} do
		settings[k] = v
	end
	return RunStore.new(settings), function(dt)
		now += dt
	end
end

local function winLevel(store, tick, userId, levelId)
	local picker = Rng.new(levelId * 13 + userId)
	for _ = 1, 200 do
		tick(60)
		store:devSetHearts(userId, Hearts.MAX)
		local run = assert(store:start(userId, levelId))
		local pop = Engine.new(Levels.get(levelId), run.seed, { startPowerUps = run.startPowerUps })
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
	error("could not win level " .. levelId)
end

test("cups run Mon-Tue, Wed-Thu and Fri-Sun", function()
	local mon = Cup.at(MONDAY + 10)
	eq(mon.startsAt, MONDAY)
	eq(mon.endsAt, MONDAY + 2 * DAY)
	eq(Cup.at(MONDAY + 2 * DAY - 1).key, mon.key)
	local wed = Cup.at(MONDAY + 2 * DAY)
	eq(wed.endsAt, MONDAY + 4 * DAY)
	local fri = Cup.at(MONDAY + 4 * DAY)
	eq(fri.endsAt, MONDAY + 7 * DAY)
	eq(Cup.at(MONDAY + 7 * DAY - 1).key, fri.key)
	eq(Cup.at(MONDAY + 7 * DAY).key, mon.key + 7)
end)

test("cups by difficulty, and places pay only when you beat someone", function()
	eq(Cup.cupsFor("Normal"), 1)
	eq(Cup.cupsFor("Tough"), 3)
	eq(Cup.cupsFor("Super Tough"), 5)
	eq(Cup.prizeFor(1, 1), nil, "alone in the group")
	eq(Cup.prizeFor(1, 2).unlimitedMinutes, 180)
	eq(Cup.prizeFor(2, 2), nil, "last of two")
	eq(Cup.prizeFor(3, 30).unlimitedMinutes, 60)
	eq(Cup.prizeFor(10, 30).boosters.BombStart, 1)
	eq(Cup.prizeFor(11, 30), nil)
	eq(Cup.prizeFor(0, 30), nil, "not in the standings")
	eq(#Cup.Places, 10)
	for _, prize in Cup.Places do
		for kind in prize.boosters do
			truthy(Boosters.Info[kind], kind)
		end
	end
end)

test("the memory board fills groups in entry order and ranks by cups", function()
	local board = CupBoard.memory()
	for i = 1, Cup.GROUP_SIZE do
		local ok, group = board.join(5)
		truthy(ok)
		eq(group, 0, "entrant " .. i)
	end
	eq(select(2, board.join(5)), 1, "the next one starts group 1")
	eq(select(2, board.join(6)), 0, "each cup counts on its own")
	board.setScore(5, 0, 11, 4)
	board.setScore(5, 0, 12, 9)
	board.setScore(5, 0, 13, 1)
	local ok, list, players = board.top(5, 0, 2)
	truthy(ok)
	eq(players, 3)
	eq(#list, 2)
	eq(list[1].userId, 12)
	eq(list[2].cups, 4)
end)

test("a win enters the cup and scores by difficulty", function()
	local store, tick = makeStore(MONDAY, { devActions = true })
	falsy(store:getProgress(1).cup.entered)
	local first = winLevel(store, tick, 1, 1)
	eq(first.cup.gained, 1)
	eq(first.cup.cups, 1)
	local tough = winLevel(store, tick, 1, 5)
	eq(tough.cup.gained, 3)
	eq(tough.cup.cups, 4)
	store:refreshCup(1, true)
	local cup = store:getProgress(1).cup
	truthy(cup.entered)
	eq(cup.cups, 4)
	eq(cup.standings.place, 1)
	eq(cup.standings.rows[1].cups, 4)
	truthy(cup.secondsLeft > 0 and cup.secondsLeft <= 2 * DAY)
end)

test("the personal goal pays unlimited hearts once", function()
	local store, tick = makeStore(MONDAY, { devActions = true })
	tick(10)
	assert(store:devCup(2, "add"))
	local p = assert(store:devCup(2, "add"))
	eq(p.cup.cups, 20)
	truthy(p.cup.goalPaid)
	truthy(p.hearts.unlimitedSeconds > 0 and p.hearts.unlimitedSeconds <= 30 * 60)
	local before = p.hearts.unlimitedSeconds
	p = assert(store:devCup(2, "add"))
	eq(p.hearts.unlimitedSeconds, before, "not paid again")
end)

test("when the cup ends, the final place is read and the prize claimed once", function()
	local board = CupBoard.memory()
	local store, tick = makeStore(MONDAY, { cupBoard = board, devActions = true })
	tick(10)
	assert(store:devCup(3, "add")) -- 10 cups
	winLevel(store, tick, 4, 1) -- 1 cup, same group
	falsy(store:claimCup(3), "nothing to claim yet")
	tick(2 * DAY) -- Wednesday: a new cup
	local p = store:getProgress(3)
	eq(p.cup.cups, 0)
	falsy(p.cup.entered)
	eq(p.cup.ended.cups, 10)
	eq(p.cup.ended.place, nil, "not read yet")
	store:refreshCup(3)
	p = store:getProgress(3)
	eq(p.cup.ended.place, 1)
	eq(p.cup.ended.players, 2)
	eq(p.cup.ended.prize.unlimitedMinutes, 180)
	local before = p.boosters.SunflowerStart
	local claimed = assert(store:claimCup(3))
	eq(claimed.place, 1)
	eq(claimed.progress.boosters.SunflowerStart, before + 3)
	eq(claimed.progress.cup.ended, nil)
	falsy(store:claimCup(3), "only once")
	-- Second of two: no prize, but the claim still clears it.
	store:refreshCup(4)
	eq(store:getProgress(4).cup.ended.place, 2)
	local last = assert(store:claimCup(4))
	eq(last.prize, nil)
end)

test("cup state saves and loads, and bad values are dropped", function()
	local store, tick = makeStore(MONDAY, { devActions = true })
	tick(10)
	assert(store:devCup(5, "add"))
	local block = store:exportSave(5)
	eq(block.cup.cups, 10)
	local other = makeStore(MONDAY + 60)
	other:importSave(5, block)
	eq(other:getProgress(5).cup.cups, 10)
	truthy(other:getProgress(5).cup.entered)
	other:importSave(6, { v = 1, cup = { key = "x", group = 0, cups = 99 }, pendingCup = { key = 1, group = 0 / 0 } })
	local p = other:getProgress(6)
	eq(p.cup.cups, 0)
	eq(p.cup.ended, nil)
	other:importSave(7, { v = 1, pendingCup = { key = 1, group = 2, cups = 5, place = 1, players = 9 } })
	eq(other:getProgress(7).cup.ended.prize.unlimitedMinutes, 180)
end)

test("the cup can be turned off, and the Studio helper only works in Studio", function()
	local off, tick = makeStore(MONDAY, { cups = false })
	eq(off:getProgress(8).cup, nil)
	eq(winLevel(off, tick, 8, 1).cup, nil)
	local live = makeStore(MONDAY)
	falsy(live:devCup(8, "add"))
end)
