-- Fences: edges no swap crosses; only blasts break them.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng, Matcher = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng, CropPop.Matcher

local FENCES = { { 2, 2, "r" }, { 4, 4, "d" } }

local function fenceLevel(fields)
	local level = Helpers.level({ fences = FENCES, goals = { { kind = "Fences" } }, moves = 80 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

test("the board knows its fences from either side", function()
	local board = Board.fromLayout(fenceLevel().layout, nil, FENCES)
	eq(board.fenceCount, 2)
	truthy(board:fenceBetween(2, 2, 3, 2))
	truthy(board:fenceBetween(3, 2, 2, 2))
	truthy(board:fenceBetween(4, 5, 4, 4))
	falsy(board:fenceBetween(2, 2, 2, 3))
	eq(#board:fencesAround(3, 2), 1)
	eq(#board:fencesAround(5, 5), 0)
	truthy(board:breakFence(board:fenceBetween(2, 2, 3, 2)))
	eq(board.fenceCount, 1)
	falsy(board:fenceBetween(2, 2, 3, 2))
end)

test("no swap or listed move crosses a fence", function()
	local pop = Engine.new(fenceLevel(), 3)
	falsy(pop:canSwap(2, 2, 3, 2))
	falsy(pop:trySwap(2, 2, 3, 2))
	for _, m in Matcher.listPossibleMoves(pop.board) do
		falsy(pop.board:fenceBetween(m[1], m[2], m[3], m[4]), "listed move " .. table.concat(m, ","))
	end
	truthy(pop:canSwap(2, 2, 2, 3))
end)

test("blasts break fences and fill the goal; matches don't", function()
	local pop = Engine.new(fenceLevel(), 5)
	eq(pop.goals:find("Fences").target, 2)
	local ok, phases = pop:useBooster("Trowel", 3, 2)
	truthy(ok)
	local broke = 0
	for _, phase in phases do
		for _, f in phase.fences or {} do
			broke += 1
			eq(f.x, 2)
			eq(f.side, "r")
		end
	end
	eq(broke, 1)
	eq(pop.goals:find("Fences").progress, 1)
	falsy(pop.board:fenceBetween(2, 2, 3, 2))
	-- Random play: only power-up waves break fences.
	local level = fenceLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 999 } } })
	local game = Engine.new(level, 7)
	local rng = Rng.new(7)
	for _ = 1, 40 do
		if game.status ~= "Playing" then
			break
		end
		local m = rng:pick(game:listPossibleMoves())
		local _, out = game:trySwap(m[1], m[2], m[3], m[4])
		for _, phase in out do
			if phase.kind == "Pop" and #(phase.fences or {}) > 0 then
				truthy(#phase.effects > 0, "a fence broke only in a wave with a blast")
			end
		end
	end
end)

test("levels check their fences", function()
	eq(Levels.validate(fenceLevel()), nil)
	truthy(Levels.validate(fenceLevel({ fences = { { 8, 1, "r" } } })), "off the board")
	truthy(Levels.validate(fenceLevel({ fences = { { 1, 1, "x" } } })), "bad side")
	truthy(Levels.validate(fenceLevel({ fences = { { 1, 1, "r" }, { 1, 1, "r" } } })), "twice")
	truthy(Levels.validate(fenceLevel({ fences = "lots" })), "not a list")
	local holed = Helpers.level().layout
	holed = table.clone(holed)
	holed[1] = "#......."
	truthy(Levels.validate(fenceLevel({ layout = holed, fences = { { 1, 1, "r" } } })), "next to a hole")
	local bare = fenceLevel()
	bare.fences = nil
	truthy(Levels.validate(bare), "fences goal without fences")
end)

test("a fence level replays the same and its text keeps the fences", function()
	local level = fenceLevel({ moves = 40 })
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 40 do
			local m = rng:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	local text = CropPop.LevelText.write(level)
	truthy(string.find(text, '{ 2, 2, "r" },', 1, true), text)
	falsy(string.find(CropPop.LevelText.write(Helpers.level()), "fences", 1, true))
end)
