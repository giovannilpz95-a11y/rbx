-- Pumpkins: dropped to the bottom of the board to collect them.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local engine, phase = Helpers.engine, Helpers.phase
local Levels, Engine, Matcher = CropPop.Levels, CropPop.Engine, CropPop.Matcher

local X8 = "x x x x x x x x"

local function rows(top)
	local out = table.clone(top)
	while #out < 8 do
		table.insert(out, X8)
	end
	return out
end

local function pumpkinsOn(board)
	local list = {}
	board:eachCell(function(cell)
		if cell.piece and cell.piece.pumpkin then
			table.insert(list, cell)
		end
	end)
	return list
end

test("a pumpkin never matches and can't be blasted", function()
	local pop = engine({ goals = { { kind = "Pumpkins", count = 5 } } }, rows({
		"1r 1 2 P x x x x",
		"x x 1 x x x x x",
	}))
	local pumpkinId = pop.board:get(4, 1).piece.id
	truthy(pop:trySwap(3, 2, 3, 1), "the sprayer row goes off")
	local found = false
	pop.board:eachCell(function(cell)
		found = found or (cell.piece ~= nil and cell.piece.id == pumpkinId)
	end)
	truthy(found, "the pumpkin survived the sprayer")
	eq(Matcher.colorAt(pop.board, pumpkinsOn(pop.board)[1].x, pumpkinsOn(pop.board)[1].y), 0)
end)

test("a pumpkin that reaches the bottom row is collected", function()
	local pop = engine({ goals = { { kind = "Pumpkins", count = 2 } } }, rows({
		X8,
		X8,
		X8,
		X8,
		X8,
		X8,
		"x x x x x x x P",
		X8,
	}))
	-- A gap opens under it, as if a match there just popped.
	pop.board:get(8, 8).piece = nil
	local phases = {}
	pop:_settle(phases)
	local collected
	for _, p in phases do
		if p.kind == "Pop" and p.effects[1] and p.effects[1].type == "Pumpkin" then
			collected = p
		end
	end
	truthy(collected, "a Pumpkin pop")
	eq(collected.removed[1].cause, "pumpkin")
	eq(collected.removed[1].x, 8)
	eq(collected.removed[1].y, 8)
	eq(pop.goals.list[1].progress, 1)
end)

test("refills drop new pumpkins until the goal has enough", function()
	local pop = engine({ goals = { { kind = "Pumpkins", count = 3 } } }, nil, 4)
	eq(#pumpkinsOn(pop.board), 0)
	local seen = 0
	for _ = 1, 60 do
		if pop.status ~= "Playing" then
			break
		end
		local moves = pop:listPossibleMoves()
		local m = moves[1]
		pop:trySwap(m[1], m[2], m[3], m[4])
		seen = math.max(seen, #pumpkinsOn(pop.board))
		truthy(#pumpkinsOn(pop.board) <= 1, "one at a time (the layout starts with none)")
	end
	truthy(pop.goals.list[1].progress > 0 or seen == 1, "pumpkins came down")
	truthy(pop.goals.list[1].progress <= 3)
end)

test("no more pumpkins drop once the goal is covered", function()
	local pop = engine({ goals = { { kind = "Pumpkins", count = 1 } } }, rows({ "x x x P x x x x" }))
	eq(pop:_pumpkinsWanted(), 0, "the one on the board covers the goal")
	pop.goals.list[1].progress = 1
	pop.board:get(4, 1).piece = pop.board:newPiece(4)
	eq(pop:_pumpkinsWanted(), 0, "goal done")
end)

test("power-ups, the bonus round and weeds never land on a pumpkin", function()
	local pop = engine({ goals = { { kind = "Pumpkins", count = 2 } } }, rows({
		"P P P P P P P P",
		"P P P P P P P P",
		"P P P P P P P P",
		"1 P P P P P P P",
	}))
	local placed = pop:_placePowerUps({ "HayBomb", "HayBomb" })
	eq(#placed, 2)
	for _, p in placed do
		falsy(pop.board:get(p.x, p.y).piece.pumpkin)
	end
end)

test("the Trowel won't take a pumpkin, and shuffles leave pumpkins put", function()
	local pop = engine({ goals = { { kind = "Pumpkins", count = 2 } } }, rows({ "x x x P x x x x" }))
	falsy(pop:useBooster("Trowel", 4, 1))
	local id = pop.board:get(4, 1).piece.id
	truthy(pop:useBooster("ShakeUp"))
	eq(pop.board:get(4, 1).piece.id, id)
end)

test("a pumpkin can be swapped like a tile", function()
	local pop = engine({ goals = { { kind = "Pumpkins", count = 2 } } }, rows({
		"x x P x x x x x",
		"1 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	truthy(pop:canSwap(3, 1, 3, 2))
	-- Pumpkin down, the 2 up: the 1 1 _ row doesn't match yet, so it's refused.
	falsy(pop:trySwap(3, 1, 3, 2))
	truthy(pop:trySwap(3, 3, 3, 2), "the match under it still works")
end)

test("pumpkins come from the layout, and the level checks them", function()
	local level = Helpers.level({
		layout = {
			"...p....",
			"........",
			"........",
			"........",
			"........",
			"........",
			"........",
			"........",
		},
		goals = { { kind = "Pumpkins", count = 3 } },
	})
	eq(Levels.validate(level), nil)
	local pop = Engine.new(level, 2)
	truthy(pop.board:get(4, 1).piece.pumpkin)
	eq(pop.goals.list[1].target, 3)
	eq(pop.pumpkinsAtOnce, 1)
	truthy(string.find(pop.board:hash(), "P", 1, true))

	local bottom = table.clone(level)
	bottom.layout = table.clone(level.layout)
	bottom.layout[1] = "........"
	bottom.layout[8] = "...p...."
	truthy(Levels.validate(bottom), "a pumpkin on a bottom cell")

	local few = table.clone(level)
	few.goals = { { kind = "Pumpkins", count = 0 } }
	truthy(Levels.validate(few), "count below the layout's pumpkins")

	local noGoal = table.clone(level)
	noGoal.goals = { { kind = "Collect", tile = "Tomato", count = 10 } }
	truthy(Levels.validate(noGoal), "pumpkins with no goal")
end)

test("pumpkin levels replay the same on the server", function()
	local level = Helpers.level({
		layout = {
			"..p..p..",
			"........",
			"...##...",
			"........",
			"........",
			"........",
			"........",
			"........",
		},
		goals = { { kind = "Pumpkins", count = 4 } },
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

test("the bot can win a pumpkin level", function()
	local level = Helpers.level({
		layout = {
			"..p..p..",
			"........",
			"........",
			"........",
			"........",
			"........",
			"........",
		},
		goals = { { kind = "Pumpkins", count = 3 } },
		moves = 30,
	})
	local report = CropPop.Bot.play(level, 10, 3)
	truthy(report.wins > 0, "won " .. report.wins .. " of 10")
end)
