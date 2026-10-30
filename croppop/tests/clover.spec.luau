-- Clover: spreads from matches and blasts that start on it; the goal covers the board.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local engine, phase = Helpers.engine, Helpers.phase
local Levels, Engine = CropPop.Levels, CropPop.Engine

local X8 = "x x x x x x x x"

local function rows(top)
	local out = table.clone(top)
	while #out < 8 do
		table.insert(out, X8)
	end
	return out
end

local function cloverCount(board)
	local n = 0
	board:eachCell(function(cell)
		if cell.clover then
			n += 1
		end
	end)
	return n
end

test("a match with one tile on clover plants clover on the whole match", function()
	local pop = engine({ goals = { { kind = "Clover", count = 64 } } }, rows({
		"1+ 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local first = phase(phases, "Pop")
	eq(#first.clover, 2, "the two new cells")
	truthy(pop.board:get(2, 1).clover)
	truthy(pop.board:get(3, 1).clover)
	falsy(pop.board:get(4, 1).clover)
	eq(pop.goals.list[1].progress, 2)
end)

test("a match with no clover in it plants nothing", function()
	local pop = engine({ goals = { { kind = "Clover", count = 64 } } }, rows({
		"1 1 2 x+ x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	eq(#phase(phases, "Pop").clover, 0)
end)

test("a power-up going off on clover plants it everywhere it hits", function()
	local pop = engine({ goals = { { kind = "Clover", count = 64 } } }, rows({
		"1r+ 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	truthy(pop:trySwap(3, 2, 3, 1))
	for x = 1, 8 do
		truthy(pop.board:get(x, 1).clover, "row cell " .. x)
	end
end)

test("a power-up off clover doesn't spread it", function()
	local pop = engine({ goals = { { kind = "Clover", count = 64 } } }, rows({
		"x+ x x x x x x x",
		"1r 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	truthy(pop:trySwap(3, 3, 3, 2))
	eq(cloverCount(pop.board), 1)
end)

test("a combo with either power-up on clover spreads it", function()
	local pop = engine({ goals = { { kind = "Clover", count = 64 } } }, rows({
		"x x x x x x x x",
		"x 1r+ 2c x x x x x",
	}))
	truthy(pop:trySwap(2, 2, 3, 2))
	truthy(cloverCount(pop.board) >= 8 + 7, "a row and a column")
end)

test("clover comes from the layout and the goal is every bare cell", function()
	local level = Helpers.level({
		layout = {
			"#......#",
			"........",
			"........",
			"...cc...",
			"........",
			"........",
			"........",
			"#......#",
		},
		goals = { { kind = "Clover" } },
	})
	eq(Levels.validate(level), nil)
	local pop = Engine.new(level, 1)
	eq(pop.goals.list[1].target, 60 - 2)
	truthy(pop.board:get(4, 4).clover)
	truthy(string.find(pop.board:hash(), "+", 1, true))

	local none = table.clone(level)
	none.layout = table.clone(level.layout)
	none.layout[4] = "........"
	truthy(Levels.validate(none), "clover goal without clover")
end)

test("covering every cell wins", function()
	local pop = engine({ goals = { { kind = "Clover", count = 2 } } }, rows({
		"1+ 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	pop:trySwap(3, 2, 3, 1)
	eq(pop.status, "Won")
end)

test("clover levels replay the same on the server", function()
	local level = Helpers.level({
		layout = {
			"........",
			"........",
			"........",
			"...cc...",
			"...cc...",
			"........",
			"........",
			"........",
		},
		goals = { { kind = "Clover" } },
	})
	for seed = 1, 5 do
		local live = Engine.new(level, seed)
		local actions = {}
		local rng = CropPop.Rng.new(seed)
		while live.status == "Playing" and #actions < 30 do
			local m = rng:pick(live:listPossibleMoves())
			live:trySwap(m[1], m[2], m[3], m[4])
			table.insert(actions, m)
		end
		local again = Engine.new(level, seed)
		for _, m in actions do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), live:hash())
	end
end)
