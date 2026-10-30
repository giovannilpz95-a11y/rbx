-- Random play: board invariants, and client/server replays matching exactly.

local eq, truthy = expect.eq, expect.truthy
local Engine, Levels, Matcher, Replay, Rng = CropPop.Engine, CropPop.Levels, CropPop.Matcher, CropPop.Replay, CropPop.Rng

local RUNS = 1000

-- Bales, weeds and frozen tiles all stop tiles falling, so cells below them can sit empty.
local function hasBales(level)
	for _, row in level.layout do
		if string.find(row, "[123wfFsS]") then
			return true
		end
	end
	return false
end

-- Plays a level with random useful swaps (picked by a separate rng).
local function randomRun(level, seed, picker, check)
	local pop = Engine.new(level, seed)
	local moves = {}
	local guard = 0
	while pop.status == "Playing" and guard < 500 do
		guard += 1
		local options = pop:listPossibleMoves()
		if #options == 0 then
			break
		end
		local m = picker:pick(options)
		if picker:int(1, 2) == 1 then
			m = { m[3], m[4], m[1], m[2] } -- swipe either way
		end
		local ok = pop:trySwap(m[1], m[2], m[3], m[4])
		assert(ok, "listed move was refused")
		table.insert(moves, m)
		if check then
			check(pop)
		end
	end
	return pop, moves
end

test("random play keeps the board settled and playable", function()
	local picker = Rng.new(777)
	for i = 1, #Levels.List do
		local level = Levels.List[i]
		local bales = hasBales(level)
		randomRun(level, picker:nextU32(), picker, function(pop)
			eq(#Matcher.findGroups(pop.board, {}), 0, "board left with a match")
			if pop.status == "Playing" then
				truthy(Matcher.hasPossibleMove(pop.board), "no possible move after settling")
			end
			if not bales then
				eq(Helpers.emptySlots(pop.board), 0, "empty cells on a board without bales")
			end
		end)
	end
end)

test(RUNS .. " random runs replay to the exact same state", function()
	local picker = Rng.new(2026)
	local wins, total = 0, 0
	for i = 1, RUNS do
		local level = Levels.List[(i - 1) % #Levels.List + 1]
		local seed = picker:nextU32()
		local pop, moves = randomRun(level, seed, picker)
		local result = Replay.run(level, seed, moves)
		truthy(result.ok, "replay refused run " .. i .. ": " .. tostring(result.reason))
		eq(result.hash, pop:hash(), "replay hash for run " .. i)
		eq(result.won, pop.status == "Won", "replay result for run " .. i)
		if result.won then
			wins += 1
		end
		total += #moves
	end
	print(string.format("    %d/%d random runs won, %d moves replayed", wins, RUNS, total))
end)

test("the same seed always deals the same board, other seeds don't", function()
	local level = Levels.get(1)
	eq(Engine.new(level, 99):hash(), Engine.new(level, 99):hash())
	truthy(Engine.new(level, 99):hash() ~= Engine.new(level, 100):hash())
end)
