-- Server run tracking: seeds, unlock order, replay-checked wins.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local RunStore = require(game.ServerScriptService.CropPopServer.RunStore)
local Engine, Levels, Rng = CropPop.Engine, CropPop.Levels, CropPop.Rng

local Hearts, Boosters = CropPop.Hearts, CropPop.Boosters

local function makeStore(unlockAll, config)
	local now = 0
	local seeds = Rng.new(11)
	local settings = {
		clock = function()
			return now
		end,
		newSeed = function()
			return seeds:int(1, 2 ^ 31 - 1)
		end,
		unlockAll = unlockAll,
		scoreTracks = false, -- so exact reward checks don't pick up track steps (see scoretracks.spec)
		cups = false, -- likewise the cup's personal-goal hearts (see cup.spec)
	}
	for k, v in config or {} do
		settings[k] = v
	end
	local store = RunStore.new(settings)
	return store, function(dt)
		now += dt
	end
end

-- Lose a run on purpose: finish it with no moves.
local function loseRun(store, tick, userId, levelId)
	tick(2)
	local run = assert(store:start(userId, levelId or 1))
	return assert(store:finish(userId, run.token, {}))
end

-- Plays the server's seed with random moves until it wins (retrying new runs).
local function winLevel(store, tick, userId, levelId)
	local picker = Rng.new(levelId * 31)
	for _ = 1, 200 do
		tick(Hearts.REFILL_SECONDS) -- keep hearts topped up between attempts
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

test("levels unlock in order", function()
	local store, tick = makeStore(false)
	tick(10)
	falsy(store:start(1, 2))
	truthy(store:start(1, 1))
	local result = winLevel(store, tick, 1, 1)
	truthy(result.won)
	truthy(result.firstWin)
	eq(result.rewards.coins, Levels.get(1).rewards.coins + result.rewards.bonusCoins)
	eq(store:getProgress(1).highestBeaten, 1)
	tick(2)
	truthy(store:start(1, 2))
end)

test("replaying a beaten level pays again but isn't a first win", function()
	local store, tick = makeStore(false)
	winLevel(store, tick, 7, 1)
	local again = winLevel(store, tick, 7, 1)
	falsy(again.firstWin)
end)

test("a run can only be finished once, with its own token", function()
	local store, tick = makeStore(true)
	tick(10)
	local run = assert(store:start(3, 1))
	falsy(store:finish(3, run.token + 1, {}))
	tick(2)
	run = assert(store:start(3, 1))
	local result = assert(store:finish(3, run.token, {}))
	falsy(result.won)
	falsy(store:finish(3, run.token, {}))
end)

test("fake wins are rejected", function()
	local store, tick = makeStore(true)
	tick(10)
	local run = assert(store:start(4, 1))
	local result, err = store:finish(4, run.token, { { 1, 1, 3, 1 } })
	falsy(result)
	truthy(err)
	tick(2)
	run = assert(store:start(4, 1))
	falsy(store:finish(4, run.token, "lots of moves"))
end)

test("starts are rate limited and bad levels refused", function()
	local store, tick = makeStore(true)
	tick(10)
	truthy(store:start(5, 1))
	falsy(store:start(5, 1))
	tick(2)
	falsy(store:start(5, 999))
	falsy(store:start(5, "1"))
end)

test("starting a level holds a heart, a win gives it back", function()
	local store, tick = makeStore(true)
	tick(10)
	local run = assert(store:start(8, 1))
	eq(run.progress.hearts.count, Hearts.MAX - 1)
	store:finish(8, run.token, {})
	eq(store:getProgress(8).hearts.count, Hearts.MAX - 1, "a loss keeps the heart spent")
	local won = winLevel(store, tick, 8, 1)
	eq(won.progress.hearts.count, Hearts.MAX, "a win gives it back")
end)

test("out of hearts means no start until the timer refills one", function()
	local store, tick = makeStore(true)
	tick(10)
	for _ = 1, Hearts.MAX do
		loseRun(store, tick, 9)
	end
	tick(2)
	local run, err = store:start(9, 1)
	falsy(run)
	eq(err, "no hearts")
	tick(Hearts.REFILL_SECONDS)
	truthy(store:start(9, 1))
end)

test("pre-level boosters are charged at the start and go on the board", function()
	local store, tick = makeStore(true)
	tick(10)
	local run = assert(store:start(10, 1, { "BombStart", "SprayerStart" }))
	eq(#run.startPowerUps, 2)
	eq(run.progress.boosters.BombStart, Boosters.STARTING_STOCK - 1)
	falsy(store:start(10, 1, { "BombStart", "BombStart" }), "no doubles")
	falsy(store:start(10, 1, { "Trowel" }), "in-level boosters aren't picked before a level")
	-- Use up the rest, then the start is refused.
	for _ = 1, Boosters.STARTING_STOCK - 1 do
		tick(2)
		assert(store:start(10, 1, { "BombStart" }))
	end
	tick(Hearts.REFILL_SECONDS)
	local none, err = store:start(10, 1, { "BombStart" })
	falsy(none)
	truthy(string.find(err, "Bomb Start"))
end)

test("in-level boosters are charged by what the replay used", function()
	local store, tick = makeStore(true)
	tick(10)
	local run = assert(store:start(11, 1))
	local result = assert(store:finish(11, run.token, { { "ShakeUp" }, { "Rake", 2 } }))
	eq(result.progress.boosters.ShakeUp, Boosters.STARTING_STOCK - 1)
	eq(result.progress.boosters.Rake, Boosters.STARTING_STOCK - 1)

	tick(2)
	run = assert(store:start(11, 1))
	local actions = {}
	for _ = 1, Boosters.STARTING_STOCK do
		table.insert(actions, { "ShakeUp" })
	end
	local cheat, err = store:finish(11, run.token, actions)
	falsy(cheat, "more Shake-Ups than owned")
	truthy(string.find(err, "Shake%-Up"))
end)

test("the shop charges Gems and refuses when they can't be spent", function()
	local spent = {}
	local wallet = 100
	local store, tick = makeStore(true, {
		spendGems = function(userId, amount, reason)
			if amount > wallet then
				return false
			end
			wallet -= amount
			table.insert(spent, reason)
			return true
		end,
	})
	tick(10)
	falsy(store:buyHearts(12, 1), "hearts are full")
	loseRun(store, tick, 12)
	falsy(store:buyHearts(12, 1), "the refill is only sold when it fits")
	for _ = 2, Hearts.MAX do
		loseRun(store, tick, 12)
	end
	local progress = assert(store:buyHearts(12, 1))
	eq(progress.hearts.count, Hearts.MAX)
	eq(wallet, 64)
	progress = assert(store:buyBooster(12, "Trowel"))
	eq(progress.boosters.Trowel, Boosters.STARTING_STOCK + 1)
	eq(wallet, 39)
	truthy(store:buyBooster(12, "SunflowerStart"))
	eq(wallet, 14)
	local none, err = store:buyBooster(12, "SunflowerStart")
	falsy(none)
	eq(err, "not enough Gems")
	eq(store:getProgress(12).boosters.SunflowerStart, Boosters.STARTING_STOCK + 1, "a failed buy adds nothing")
	eq(#spent, 3)
end)

test("nothing is for sale without a Gem hook", function()
	local store, tick = makeStore(true)
	tick(10)
	eq(store:getProgress(13).canBuy, false)
	falsy(store:buyBooster(13, "Trowel"))
end)

test("saves round-trip, and a late load replaces the fresh state", function()
	local store, tick = makeStore(true, { autoLoad = false })
	tick(10)
	falsy(store:start(14, 1), "can't play before the save loads")
	eq(store:exportSave(14), nil, "nothing to save before loading")
	store:markLoaded(14)
	loseRun(store, tick, 14)
	local saved = store:exportSave(14)
	eq(saved.v, 1)
	eq(saved.hearts.count, Hearts.MAX - 1)

	store:importSave(14, {
		v = 1,
		highestBeaten = 3,
		hearts = { count = 2, updatedAt = 0, unlimitedUntil = 0 },
		boosters = { Trowel = 7, Rake = "lots" },
	})
	local progress = store:getProgress(14)
	eq(progress.highestBeaten, 3)
	eq(progress.boosters.Trowel, 7)
	eq(progress.boosters.Rake, Boosters.STARTING_STOCK, "bad values fall back")
	truthy(progress.hearts.count >= 2)

	store:importSave(15, nil)
	eq(store:getProgress(15).hearts.count, Hearts.MAX, "nil is a new player")
end)

test("continues are sold only when out of moves, at rising prices, and checked at the end", function()
	local charged = {}
	local store, tick = makeStore(true, {
		spendGems = function(_, amount)
			table.insert(charged, amount)
			return true
		end,
		devActions = true,
	})
	tick(10)
	local run = assert(store:start(20, 5))
	local pop = Engine.new(Levels.get(5), run.seed, { startPowerUps = run.startPowerUps })
	local actions = {}
	local function act(action)
		assert(pop:apply(action))
		table.insert(actions, action)
	end

	falsy(store:buyContinue(20, run.token, actions), "not before running out")
	act({ "DevOneMove" })
	act(pop:listPossibleMoves()[1])
	if pop.status ~= "Lost" then
		return -- won on the last move by luck
	end
	falsy(store:buyContinue(20, run.token + 1, actions), "wrong run")
	assert(store:buyContinue(20, run.token, actions))
	eq(charged[1], 10)
	falsy(store:buyContinue(20, run.token, actions), "the paid one has to be used first")
	act({ "Continue" })
	act({ "DevOneMove" })
	act(pop:listPossibleMoves()[1])
	if pop.status ~= "Lost" then
		return
	end
	assert(store:buyContinue(20, run.token, actions))
	eq(charged[2], 20)
	act({ "Continue" })

	-- One more continue than was paid for is refused at the end.
	local cheat = table.clone(actions)
	pop:apply({ "DevOneMove" })
	table.insert(cheat, { "DevOneMove" })
	local m = pop:listPossibleMoves()[1]
	pop:apply(m)
	table.insert(cheat, m)
	if pop.status == "Lost" then
		table.insert(cheat, { "Continue" })
		local result, err = store:finish(20, run.token, cheat)
		falsy(result)
		truthy(string.find(err, "paid"))
	end
end)

test("an honest run with paid continues is accepted", function()
	local store, tick = makeStore(true, {
		spendGems = function()
			return true
		end,
		devActions = true,
	})
	tick(10)
	local run = assert(store:start(21, 4))
	local pop = Engine.new(Levels.get(4), run.seed, { startPowerUps = run.startPowerUps })
	local actions = {}
	local function act(action)
		assert(pop:apply(action))
		table.insert(actions, action)
	end
	act({ "DevOneMove" })
	act(pop:listPossibleMoves()[1])
	if pop.status == "Lost" then
		assert(store:buyContinue(21, run.token, actions))
		act({ "Continue" })
	end
	local result = assert(store:finish(21, run.token, actions))
	eq(result.won, pop.status == "Won")
end)

test("the Studio dev action is refused on live servers", function()
	local store, tick = makeStore(true)
	tick(10)
	local run = assert(store:start(22, 1))
	local result, err = store:finish(22, run.token, { { "DevOneMove" } })
	falsy(result)
	truthy(err)
end)

test("progress shows the farm's Gem balance when it has one", function()
	local store, tick = makeStore(true, {
		getGems = function()
			return 42
		end,
	})
	tick(10)
	eq(store:getProgress(30).gems, 42)
	local plain = makeStore(true)
	eq(plain:getProgress(30).gems, nil)
end)

test("the Studio hearts setter only works with dev actions on", function()
	local live = makeStore(true)
	falsy(live:devSetHearts(31, 0))
	local studio, tick = makeStore(true, { devActions = true })
	tick(10)
	eq(assert(studio:devSetHearts(31, 0)).hearts.count, 0)
	local _, err = studio:start(31, 1)
	eq(err, "no hearts")
end)

-- Hot Streak ---------------------------------------------------------------------

test("Hot Streak: a win starts it, the next level gets a free Sprayer", function()
	local store, tick = makeStore(true)
	tick(10)
	local won = winLevel(store, tick, 40, 1)
	eq(won.progress.streak, 1)
	tick(2)
	local run = assert(store:start(40, 2))
	eq(#run.hotStreak, 1)
	eq(run.hotStreak[1], "Sprayer")
	eq(run.startPowerUps[#run.startPowerUps], "Sprayer")
end)

test("Hot Streak grows to 3 free power-ups and stays there", function()
	local store, tick = makeStore(true)
	store:importSave(41, { v = 1, highestBeaten = 0, streak = 2 })
	tick(10)
	local run = assert(store:start(41, 1, { "BombStart" }))
	eq(#run.hotStreak, 2)
	eq(#run.startPowerUps, 3, "the pre-level booster plus two free ones")
	store:importSave(41, { v = 1, streak = 7 })
	tick(2)
	run = assert(store:start(41, 1))
	eq(#run.hotStreak, 3)
	eq(run.hotStreak[3], "Sunflower")
end)

test("a loss ends the Hot Streak and says how long it was", function()
	local store, tick = makeStore(true)
	store:importSave(42, { v = 1, streak = 4 })
	local lost = loseRun(store, tick, 42)
	eq(lost.lostStreak, 4)
	eq(lost.progress.streak, 0)
end)

test("leaving a level part-way ends the Hot Streak, and saves mid-level don't keep it", function()
	local store, tick = makeStore(true)
	store:importSave(43, { v = 1, streak = 3 })
	tick(10)
	assert(store:start(43, 1))
	eq(store:exportSave(43).streak, 0, "a drop mid-level would end it")
	tick(2)
	local again = assert(store:start(43, 1)) -- the first one was left
	eq(#again.hotStreak, 0)
	eq(again.progress.streak, 0)
end)

test("a win while on a streak adds to it and the save keeps it", function()
	local store, tick = makeStore(true)
	store:importSave(44, { v = 1, streak = 2 })
	tick(10)
	local before = store:getProgress(44).streak
	local run = assert(store:start(44, 1))
	-- Win through the replay with the streak's free power-ups on the board.
	local pop = Engine.new(Levels.get(1), run.seed, { startPowerUps = run.startPowerUps })
	local picker = Rng.new(5)
	local moves = {}
	while pop.status == "Playing" do
		local m = picker:pick(pop:listPossibleMoves())
		pop:trySwap(m[1], m[2], m[3], m[4])
		table.insert(moves, m)
	end
	local result = assert(store:finish(44, run.token, moves))
	if result.won then
		eq(result.progress.streak, before + 1)
		eq(store:exportSave(44).streak, before + 1)
	else
		eq(result.progress.streak, 0)
	end
	store:importSave(45, { v = 1, streak = "lots" })
	eq(store:getProgress(45).streak, 0, "bad values fall back")
end)

test("Trail Chests sit on every 10th level and grow a little each time", function()
	local TrailChest = CropPop.TrailChest
	eq(TrailChest.forLevel(9), nil)
	eq(TrailChest.forLevel(15), nil)
	local first, second, third = TrailChest.forLevel(10), TrailChest.forLevel(20), TrailChest.forLevel(30)
	eq(first.number, 1)
	eq(first.coins, 100)
	eq(first.boosters.SprayerStart, 1)
	eq(first.boosters.Trowel, 1)
	eq(second.boosters.BombStart, 1)
	eq(second.boosters.Rake, 2)
	truthy(second.coins > first.coins)
	eq(third.unlimitedMinutes, 30)
	eq(first.unlimitedMinutes, 15)
end)

test("the first win on a chest level pays the chest, a replay doesn't", function()
	local store, tick = makeStore(true)
	local result = winLevel(store, tick, 60, 10)
	truthy(result.firstWin)
	truthy(result.chest, "chest in the result")
	eq(result.rewards.chestCoins, 100)
	eq(result.rewards.coins, Levels.get(10).rewards.coins + result.rewards.bonusCoins + 100)
	local progress = store:getProgress(60)
	eq(progress.boosters.SprayerStart, Boosters.STARTING_STOCK + 1)
	eq(progress.boosters.Trowel, Boosters.STARTING_STOCK + 1)
	truthy(progress.hearts.unlimitedSeconds > 0 and progress.hearts.unlimitedSeconds <= 15 * 60)
	local again = winLevel(store, tick, 60, 10)
	eq(again.chest, nil)
	eq(again.rewards.chestCoins, nil)
end)

test("the Studio booster grant only works with dev actions on, and stops at the stock limit", function()
	local live = makeStore(true)
	falsy(live:devAddBoosters(32, 5))
	local studio = makeStore(true, { devActions = true })
	local progress = assert(studio:devAddBoosters(32, 5))
	eq(progress.boosters.Rake, Boosters.STARTING_STOCK + 5)
	eq(progress.boosters.BombStart, Boosters.STARTING_STOCK + 5)
	for _ = 1, 30 do
		progress = assert(studio:devAddBoosters(32, 5))
	end
	eq(progress.boosters.Rake, Boosters.MAX_STOCK)
end)
