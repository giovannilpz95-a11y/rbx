-- Server replay check: honest runs pass, tampered runs fail.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Engine, Levels, Replay, Rng = CropPop.Engine, CropPop.Levels, CropPop.Replay, CropPop.Rng

-- Finds a seed and move list that wins level 1 with random play.
local function findWinningRun()
	local level = Levels.get(1)
	local picker = Rng.new(5)
	for _ = 1, 300 do
		local seed = picker:nextU32()
		local pop = Engine.new(level, seed)
		local moves = {}
		while pop.status == "Playing" do
			local m = picker:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(moves, m)
		end
		if pop.status == "Won" then
			return level, seed, moves
		end
	end
	error("no winning run found")
end

local level, seed, moves = findWinningRun()

test("an honest winning run is accepted", function()
	local result = Replay.run(level, seed, moves)
	truthy(result.ok)
	truthy(result.won)
	eq(result.movesUsed, #moves)
end)

test("the same moves with another seed don't win", function()
	local result = Replay.run(level, seed + 1, moves)
	falsy(result.ok and result.won)
end)

test("a run cut short doesn't win", function()
	local short = table.clone(moves)
	table.remove(short)
	local result = Replay.run(level, seed, short)
	truthy(result.ok)
	falsy(result.won)
end)

test("moves after the level ended are refused", function()
	local extra = table.clone(moves)
	table.insert(extra, moves[1])
	local result = Replay.run(level, seed, extra)
	falsy(result.ok)
end)

test("an illegal swap is refused", function()
	local bad = table.clone(moves)
	bad[1] = { 1, 1, 3, 1 }
	local result = Replay.run(level, seed, bad)
	falsy(result.ok)
	falsy(result.won)
end)

test("sanitize rejects malformed input", function()
	falsy((Replay.sanitize("nope")))
	falsy((Replay.sanitize({ { 1, 1, 2 } })))
	falsy((Replay.sanitize({ { 1, 1, 2, 1.5 } })))
	falsy((Replay.sanitize({ { 1, 1, 2, 99 } })))
	falsy((Replay.sanitize({ { "1", 1, 2, 1 } })))
	local tooMany = {}
	for i = 1, Replay.MAX_MOVES + 1 do
		tooMany[i] = { 1, 1, 2, 1 }
	end
	falsy((Replay.sanitize(tooMany)))
	local clean = Replay.sanitize({ { 1, 1, 2, 1, "extra" } })
	eq(#clean[1], 4)
end)
