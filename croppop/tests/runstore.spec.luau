-- Server run tracking: seeds, unlock order, replay-checked wins.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local RunStore = require(game.ServerScriptService.CropPopServer.RunStore)
local Engine, Levels, Rng = CropPop.Engine, CropPop.Levels, CropPop.Rng

local function makeStore(unlockAll)
	local now = 0
	local seeds = Rng.new(11)
	local store = RunStore.new({
		clock = function()
			return now
		end,
		newSeed = function()
			return seeds:int(1, 2 ^ 31 - 1)
		end,
		unlockAll = unlockAll,
	})
	return store, function(dt)
		now += dt
	end
end

-- Plays the server's seed with random moves until it wins (retrying new runs).
local function winLevel(store, tick, userId, levelId)
	local picker = Rng.new(levelId * 31)
	for _ = 1, 200 do
		tick(2)
		local run = assert(store:start(userId, levelId))
		local pop = Engine.new(Levels.get(levelId), run.seed)
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
