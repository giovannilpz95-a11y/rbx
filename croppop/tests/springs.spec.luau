-- Goo springs: not cells, can't be broken, and goo spreads out of them.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", "...Gg...", "........", "........", "........", "........" }

local function springLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Goo" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

test("a goo spring is not a cell, and pieces fall past it", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board:get(4, 4), nil)
	eq(#board.springs, 1)
	eq(board:cellBelow(4, 3), board:get(4, 5))
	truthy(string.find(board:hash(), "G", 1, true))
	board:fillInitial(Rng.new(1), { 1, 2, 3, 4, 5 })
	truthy(board:get(4, 5).piece)
end)

test("levels check their goo springs", function()
	eq(Levels.validate(springLevel()), nil)
	truthy(Levels.validate(springLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "no goo goal")
	truthy(Levels.validate(springLevel({ fences = { { 4, 3, "d" } } })), "a fence can't touch a spring")
end)

test("goo oozes out of a spring even with no goo left on the board", function()
	local pop = Engine.new(springLevel(), 3)
	pop.board:get(5, 4).goo = false
	local phases = {}
	pop:_growGoo(phases)
	local grown
	for _, phase in phases do
		for _, g in phase.goo or {} do
			grown = g
		end
	end
	truthy(grown, "goo grew")
	local near = (grown.x == 4 and (grown.y == 3 or grown.y == 5)) or (grown.y == 4 and (grown.x == 3 or grown.x == 5))
	truthy(near, "next to the spring: " .. grown.x .. "," .. grown.y)
	truthy(pop.board:get(grown.x, grown.y).goo)
end)

test("blasts don't break a spring, and a spring level replays the same", function()
	local pop = Engine.new(springLevel(), 1)
	falsy(pop:useBooster("Trowel", 4, 4))
	eq(#pop.board.springs, 1)
	local level = springLevel({ moves = 30 })
	for seed = 1, 4 do
		local run = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while run.status == "Playing" and #swaps < 30 do
			local m = rng:pick(run:listPossibleMoves())
			run:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), run:hash())
	end
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
end)
