-- Lost lambs: matches next to one walk it towards a pen, trampling what's in the way.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", ".E....E.", "........", "........", "........", "........", ".P....P.", "........" }

local function lambLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Lambs" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function wave()
	return { bales = {}, effects = {}, pendingCreates = {}, balesTouched = {}, removed = {}, goo = {}, mud = {}, clay = {}, frost = {}, webs = {}, queue = {}, fences = {} }
end

local function effectsOf(phases, kind)
	local out = {}
	for _, phase in phases do
		for _, e in phase.effects or {} do
			if e.type == kind then
				table.insert(out, e)
			end
		end
	end
	return out
end

test("lambs block a cell, pens are plain cells, and both need a lambs goal", function()
	local board = Board.fromLayout(LAYOUT)
	local lamb, pen = board:get(2, 2), board:get(2, 7)
	eq(lamb.bale, 1)
	truthy(lamb.lamb)
	falsy(lamb.piece)
	truthy(pen.pen)
	eq(pen.bale, 0)
	eq(#board.pens, 2)
	truthy(string.find(board:hash(), "I", 1, true))
	truthy(string.find(board:hash(), "&", 1, true))
	eq(Levels.validate(lambLevel()), nil)
	truthy(Levels.validate(lambLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "lambs without a lambs goal")
	truthy(Levels.validate(lambLevel({ layout = { "........", ".E....E.", "........", "........", "........", "........", "........", "........" } })), "lambs without a pen")
	eq(Engine.new(lambLevel(), 1).goals:find("Lambs").target, 2)
end)

test("a lamb walks towards its pen, trampling what's there, and goes home on it", function()
	local pop = Engine.new(lambLevel(), 2)
	local goal = pop.goals:find("Lambs")
	local lamb = pop.board:get(2, 2)
	-- A 2-layer bale in the way gets trampled flat, then the lamb steps in.
	local below = pop.board:get(2, 3)
	below.piece, below.bale = nil, 2
	local w = wave()
	pop:_walkLamb(w, lamb)
	falsy(lamb.lamb)
	eq(lamb.bale, 0)
	truthy(below.lamb)
	eq(below.bale, 1)
	eq(#effectsOf({ w }, "Walk"), 1)
	-- The tile in the next cell gets trampled.
	local next = pop.board:get(2, 4)
	truthy(next.piece)
	pop:_walkLamb(wave(), below)
	truthy(next.lamb)
	falsy(next.piece)
	pop:_walkLamb(wave(), next)
	pop:_walkLamb(wave(), pop.board:get(2, 5))
	local last = pop.board:get(2, 6)
	truthy(last.lamb)
	-- Onto the pen: home.
	local hw = wave()
	pop:_walkLamb(hw, last)
	falsy(last.lamb)
	falsy(pop.board:get(2, 7).lamb)
	eq(pop.board:get(2, 7).bale, 0)
	eq(goal.progress, 1)
	eq(#effectsOf({ hw }, "Home"), 1)
	-- Blasts, bees and the Trowel leave lambs alone.
	local other = pop.board:get(7, 2)
	pop:_damageBale(wave(), other)
	truthy(other.lamb)
	falsy(pop:useBooster("Trowel", 7, 2))
end)

test("a hedge sends a lamb the other way; a fence breaks", function()
	-- Pen down and to the right: the longer way (down) first.
	local layout = { "E.......", "........", "........", "........", "........", "...P....", "........", "........" }
	local pop = Engine.new(lambLevel({ layout = layout, fences = { { 1, 1, "D" } } }), 1)
	local lamb = pop.board:get(1, 1)
	pop:_walkLamb(wave(), lamb)
	truthy(pop.board:get(2, 1).lamb, "the hedge below sends it right")
	local fenced = Engine.new(lambLevel({ layout = layout, fences = { { 1, 1, "d" } } }), 1)
	local w = wave()
	fenced:_walkLamb(w, fenced.board:get(1, 1))
	truthy(fenced.board:get(1, 2).lamb, "it goes through a fence")
	eq(#w.fences, 1)
	-- Boxed in by hedges both ways: it stays.
	local boxed = Engine.new(lambLevel({ layout = layout, fences = { { 1, 1, "D" }, { 1, 1, "R" } } }), 1)
	boxed:_walkLamb(wave(), boxed.board:get(1, 1))
	truthy(boxed.board:get(1, 1).lamb)
end)

test("matches walk lambs home, and lamb levels replay the same", function()
	local level = lambLevel({ moves = 30 })
	local walks = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			walks += #effectsOf(phases, "Walk")
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(walks > 0, "some lambs walked")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(lambLevel()), '".E....E."', 1, true))
end)
