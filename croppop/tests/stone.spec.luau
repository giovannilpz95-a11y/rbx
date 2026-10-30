-- Stone walls: blockers that only blasts (and the Trowel) break.

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

test("a match next to a stone wall doesn't touch it", function()
	local pop = engine({ goals = { { kind = "Stones", count = 1 } } }, rows({
		"1 1 2 R1 x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	eq(#phase(phases, "Pop").bales, 0)
	eq(pop.board:get(4, 1).bale, 1)
	truthy(pop.board:get(4, 1).stone)
end)

test("a blast breaks a stone layer, and the last layer counts for the goal", function()
	local pop = engine({ goals = { { kind = "Stones", count = 1 } } }, rows({
		"1r 1 2 x R2 x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local hit = phase(phases, "Pop").bales[1]
	eq(hit.hp, 1)
	truthy(hit.stone)
	eq(pop.goals.list[1].progress, 0)
	truthy(pop.board:get(5, 1).stone)
	truthy(pop:useBooster("Trowel", 5, 1))
	falsy(pop.board:get(5, 1).stone)
	eq(pop.board:get(5, 1).bale, 0)
	eq(pop.goals.list[1].progress, 1)
	eq(pop.status, "Won")
end)

test("stone walls come from the layout and the goal counts them, not as bales", function()
	local level = Helpers.level({
		layout = {
			"........",
			"........",
			"..s..S..",
			"........",
			"...1....",
			"........",
			"........",
			"........",
		},
		goals = { { kind = "Stones" }, { kind = "HayBale" } },
	})
	eq(Levels.validate(level), nil)
	local pop = Engine.new(level, 1)
	eq(pop.goals.list[1].target, 2)
	eq(pop.goals.list[2].target, 1)
	eq(pop.board:get(6, 3).bale, 2)
	truthy(pop.board:get(6, 3).stone)
	eq(pop.board:get(3, 3).piece, nil)
	truthy(string.find(pop.board:hash(), "R2", 1, true))

	local none = table.clone(level)
	none.layout = table.clone(level.layout)
	none.layout[3] = "........"
	truthy(Levels.validate(none), "stones goal without stone")
end)

test("stone levels replay the same on the server", function()
	local level = Helpers.level({
		layout = {
			"........",
			"........",
			"..s..s..",
			"........",
			"...SS...",
			"........",
			"........",
			"........",
		},
		goals = { { kind = "Stones" } },
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
