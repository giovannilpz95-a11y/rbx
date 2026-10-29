-- Frost and weeds: the third and fourth obstacles.

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

test("a frosted tile can't be swapped", function()
	local pop = engine(nil, rows({
		"1 1 2f x x x x x",
		"x x 1 x x x x x",
	}))
	falsy(pop:canSwap(3, 1, 3, 2))
	falsy(pop:trySwap(3, 2, 3, 1))
end)

test("a match through a frosted tile breaks the frost and leaves the tile", function()
	local pop = engine({ goals = { { kind = "Frost", count = 2 } } }, rows({
		"1f 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	local frostedId = pop.board:get(1, 1).piece.id
	truthy(pop:trySwap(3, 2, 3, 1))
	local cell = pop.board:get(1, 1)
	eq(cell.frost, 0)
	eq(pop.goals.list[1].progress, 1)
	-- The tile is free now, so it may have fallen, but it wasn't popped.
	local found = false
	pop.board:eachCell(function(c)
		found = found or (c.piece ~= nil and c.piece.id == frostedId)
	end)
	truthy(found, "frosted tile survived")
end)

test("two layers of frost take two hits, and the tile stays put meanwhile", function()
	local pop = engine({ goals = { { kind = "Frost", count = 2 } } }, rows({
		"x x x x x x x x",
		"1F 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 3, 3, 2)
	local first = phase(phases, "Pop")
	eq(#first.frost, 1)
	eq(first.frost[1].layers, 1)
	eq(pop.board:get(1, 2).frost, 1)
	truthy(pop.board:get(1, 2).piece, "the frozen tile doesn't fall or pop")
	eq(pop:hash() ~= "", true)
	truthy(string.find(pop.board:hash(), "f1", 1, true))
end)

test("power-up blasts break frost too", function()
	local pop = engine({ goals = { { kind = "Frost", count = 1 } } }, rows({
		"1r 1 2 x 3f x x x",
		"x x 1 x x x x x",
	}))
	truthy(pop:trySwap(3, 2, 3, 1))
	eq(pop.board:get(5, 1).frost, 0)
	eq(pop.status, "Won")
end)

test("a power-up made in a match with a frosted tile lands on a free tile", function()
	local pop = engine(nil, rows({
		"1f 1 2 1 x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local created = phase(phases, "Pop").created
	eq(#created, 1)
	eq(created[1].piece.power, "SprayerRow")
	truthy(created[1].x ~= 1, "not on the frosted cell")
end)

test("a match next to a weed pulls it", function()
	local pop = engine({ goals = { { kind = "Weeds", count = 1 } } }, rows({
		"1 1 2 W x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local first = phase(phases, "Pop")
	eq(#first.bales, 1)
	truthy(first.bales[1].weed)
	falsy(pop.board:get(4, 1).weed)
	eq(pop.status, "Won")
end)

test("a swap that pulls no weed lets one spread onto a neighbouring tile", function()
	local pop = engine({ goals = { { kind = "Weeds", count = 1 } } }, rows({
		"1 1 2 x x x x x",
		"x x 1 x x x x x",
		"x x x x x x x x",
		"x x x x x x x x",
		"x x x x x x x x",
		"x x x x x x x W",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local grow
	for _, p in phases do
		if p.kind == "Pop" and p.effects[1] and p.effects[1].type == "Grow" then
			grow = p
		end
	end
	truthy(grow, "a Grow phase")
	eq(grow.removed[1].cause, "weed")
	local weeds = 0
	pop.board:eachCell(function(cell)
		if cell.weed then
			weeds += 1
		end
	end)
	eq(weeds, 2)
	eq(pop.goals.list[1].target, 2)
	truthy(string.find(pop.board:hash(), "W", 1, true))
end)

test("boosters don't make weeds spread", function()
	local pop = engine({ goals = { { kind = "Weeds", count = 1 } } }, rows({
		"x x x x x x x x",
		"x x x x x x x x",
		"x x x x x x x x",
		"x x x x x x x W",
	}))
	truthy(pop:useBooster("Trowel", 1, 1))
	local weeds = 0
	pop.board:eachCell(function(cell)
		if cell.weed then
			weeds += 1
		end
	end)
	eq(weeds, 1)
end)

test("frost and weeds come from the layout and its goals count them", function()
	local level = Helpers.level({
		layout = {
			"f......w",
			"F.......",
			"........",
			"........",
			"........",
			"........",
			"........",
			"w......f",
		},
		goals = { { kind = "Frost" }, { kind = "Weeds" } },
	})
	eq(Levels.validate(level), nil)
	local pop = Engine.new(level, 3)
	eq(pop.goals.list[1].target, 4)
	eq(pop.goals.list[2].target, 2)
	eq(pop.board:get(1, 1).frost, 1)
	eq(pop.board:get(1, 2).frost, 2)
	truthy(pop.board:get(8, 1).weed)
	truthy(pop.board:get(1, 1).piece, "frosted cells get a tile")
	eq(pop.board:get(8, 1).piece, nil)

	local broken = table.clone(level)
	broken.layout = table.clone(level.layout)
	broken.layout[1] = "f......."
	broken.layout[8] = ".......f"
	truthy(Levels.validate(broken), "weeds goal without weeds")
end)

test("frost and weed levels replay the same on the server", function()
	local level = Helpers.level({
		layout = {
			"........",
			"..ff....",
			"........",
			"...w....",
			"........",
			"..F..F..",
			"........",
			"w......w",
		},
		goals = { { kind = "Frost" }, { kind = "Weeds" } },
	})
	for seed = 1, 5 do
		local live = Engine.new(level, seed)
		local actions = {}
		local rng = CropPop.Rng.new(seed)
		while live.status == "Playing" and #actions < 25 do
			local moves = live:listPossibleMoves()
			local m = rng:pick(moves)
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
