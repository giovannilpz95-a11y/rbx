-- Hedges: fences nothing breaks. No swap crosses one; matches and falling
-- tiles pass it.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng, Matcher = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng, CropPop.Matcher

local EDGES = { { 2, 2, "R" }, { 4, 4, "D" }, { 6, 6, "r" } }

local function hedgeLevel(fields)
	local level = Helpers.level({ fences = EDGES, goals = { { kind = "Fences" } }, moves = 60 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

test("hedges block swaps like fences but don't count as fences", function()
	local board = Board.fromLayout(hedgeLevel().layout, nil, EDGES)
	eq(board.fenceCount, 1)
	eq(board.edgeCount, 3)
	local hedge = board:fenceBetween(3, 2, 2, 2)
	truthy(hedge and hedge.hedge)
	eq(hedge.side, "r")
	eq(#board:fencesAround(3, 2), 0, "blasts and bees only see fences")
	falsy(board:breakFence(hedge))
	truthy(board:fenceBetween(2, 2, 3, 2))
	truthy(string.find(board:hash(), "h", 1, true))
	local pop = Engine.new(hedgeLevel(), 2)
	eq(pop.goals:find("Fences").target, 1)
	falsy(pop:canSwap(2, 2, 3, 2))
	falsy(pop:canSwap(4, 4, 4, 5))
	for _, m in Matcher.listPossibleMoves(pop.board) do
		falsy(pop.board:fenceBetween(m[1], m[2], m[3], m[4]), "listed move " .. table.concat(m, ","))
	end
	eq(Levels.validate(hedgeLevel()), nil)
	truthy(Levels.validate(hedgeLevel({ fences = { { 2, 2, "R" } } })), "a fences goal needs a fence, not just hedges")
	eq(Levels.validate(hedgeLevel({ fences = { { 2, 2, "R" } }, goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), nil)
	truthy(Levels.validate(hedgeLevel({ fences = { { 2, 2, "R" }, { 2, 2, "r" } } })), "an edge listed twice")
	truthy(Levels.validate(hedgeLevel({ fences = { { 2, 2, "x" } } })), "a bad side")
end)

test("blasts break fences but never hedges", function()
	local pop = Engine.new(hedgeLevel(), 5)
	local ok = pop:useBooster("Trowel", 3, 2)
	truthy(ok)
	truthy(pop.board:fenceBetween(2, 2, 3, 2))
	ok = pop:useBooster("Trowel", 4, 4)
	truthy(ok)
	truthy(pop.board:fenceBetween(4, 4, 4, 5))
	ok = pop:useBooster("Trowel", 7, 6)
	truthy(ok)
	falsy(pop.board:fenceBetween(6, 6, 7, 6))
	eq(pop.goals:find("Fences").progress, 1)
	eq(pop.board.edgeCount, 2)
end)

test("hedge levels replay the same, and the bot plays them", function()
	local level = hedgeLevel({ fences = { { 2, 2, "R" }, { 4, 4, "D" } }, goals = { { kind = "Collect", tile = "Tomato", count = 12 } }, moves = 30 })
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		eq(pop.board.edgeCount, 2, "nothing broke a hedge")
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(level), '{ 2, 2, "R" }', 1, true))
end)
