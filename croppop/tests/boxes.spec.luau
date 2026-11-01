-- Produce boxes: each hit takes a box off a stack, and what's left hops into
-- the nearest cell the wave just emptied.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", ".v....V.", "........", "........", "........", "........" }

local function boxLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Boxes" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function wave()
	return { bales = {}, effects = {}, pendingCreates = {}, balesTouched = {} }
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

test("box stacks block like bales, and the goal counts every box", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board:get(2, 4).bale, 3)
	eq(board:get(7, 4).bale, 2)
	truthy(board:get(2, 4).stack)
	falsy(board:get(2, 4).piece)
	truthy(string.find(board:hash(), "V3", 1, true))
	local pop = Engine.new(boxLevel({ goals = { { kind = "Boxes" }, { kind = "HayBale" } } }), 1)
	eq(pop.goals:find("Boxes").target, 5)
	eq(pop.goals:find("HayBale").target, 0)
	eq(Levels.validate(boxLevel()), nil)
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Boxes" } } })), "boxes goal without stacks")
end)

test("a hit takes a box, and the rest hop into the nearest emptied cell", function()
	local pop = Engine.new(boxLevel(), 2)
	local from = pop.board:get(2, 4)
	-- Nothing emptied nearby: it stays put.
	local w = wave()
	pop:_damageBale(w, from)
	eq(from.bale, 2)
	truthy(from.stack)
	eq(#effectsOf({ w }, "Box"), 1)
	eq(#effectsOf({ w }, "Hop"), 0)
	eq(pop.goals:find("Boxes").progress, 1)
	-- Two cells emptied, one 1 step away and one 2 away: it takes the near one.
	local near, far = pop.board:get(3, 4), pop.board:get(2, 6)
	near.piece, far.piece = nil, nil
	w = wave()
	pop:_damageBale(w, from)
	eq(from.bale, 0)
	falsy(from.stack)
	eq(near.bale, 1)
	truthy(near.stack)
	truthy(w.balesTouched[near])
	local hop = effectsOf({ w }, "Hop")
	eq(#hop, 1)
	eq(hop[1].x, 3)
	eq(hop[1].fromX, 2)
	-- A cell where a power-up is about to appear is off limits.
	local other = pop.board:get(7, 4)
	local saved, open = pop.board:get(6, 4), pop.board:get(7, 6)
	saved.piece, open.piece = nil, nil
	w = wave()
	table.insert(w.pendingCreates, { cell = saved, power = 1, color = 1 })
	pop:_damageBale(w, other)
	eq(saved.bale, 0, "kept clear for the power-up")
	eq(open.bale, 1)
	truthy(open.stack)
	falsy(other.stack)
	-- The last box on a stack goes with no hop.
	pop:_damageBale(wave(), near)
	pop:_damageBale(wave(), open)
	falsy(near.stack)
	falsy(open.stack)
	eq(near.bale, 0)
	eq(pop.goals:find("Boxes").progress, 5)
	eq(pop.goals:find("Boxes").target, 5)
end)

test("matches knock boxes off, and box levels replay the same", function()
	local level = boxLevel({ moves = 30 })
	local hopped = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			hopped += #effectsOf(phases, "Hop")
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(hopped > 0, "some stacks hopped")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(boxLevel()), '".v....V."', 1, true))
end)
