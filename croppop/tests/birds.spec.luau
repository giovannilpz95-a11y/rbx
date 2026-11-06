-- Songbirds: each wants one tile colour and hops to the next after every
-- swap; a match of its colour next to it feeds it, nothing else does.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board = CropPop.Levels, CropPop.Engine, CropPop.Board

local LAYOUT = { "........", "........", "..D..D..", "........", "........", "........", "........", "........" }

local function birdLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Birds" } }, moves = 30 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function newWave()
	return {
		removed = {}, created = {}, transformed = {}, bales = {}, mud = {}, clay = {}, frost = {},
		clover = {}, fences = {}, goo = {}, statues = {}, webs = {}, quilts = {}, effects = {},
		queue = {}, spread = false, pendingCreates = {}, balesTouched = {}, tarpsRolled = {}, basketsHit = {},
	}
end

local function rowAt(pop, y, x1, color)
	local cells = { pop.board:get(x1, y), pop.board:get(x1 + 1, y), pop.board:get(x1 + 2, y) }
	for _, cell in cells do
		cell.piece = pop.board:newPiece(color)
	end
	return { cells = cells, color = color }
end

test("songbirds block a cell, take the level's colours in turn, and need a Birds goal", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(3, 3).bird)
	eq(board:get(3, 3).bale, 1)
	eq(Levels.validate(birdLevel()), nil)
	truthy(Levels.validate(birdLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "birds without a goal")
	truthy(Levels.validate(birdLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without birds")
	local pop = Engine.new(birdLevel(), 1)
	eq(pop.board:get(3, 3).bird, pop.colors[1])
	eq(pop.board:get(6, 3).bird, pop.colors[2])
	eq(pop.goals:find("Birds").target, 2)
	truthy(string.find(pop.board:hash(), "F" .. pop.colors[1], 1, true))
end)

test("only a match of the bird's colour next to it feeds it; blasts don't", function()
	local pop = Engine.new(birdLevel(), 2)
	local want = pop.board:get(3, 3).bird
	local other = if pop.colors[1] == want then pop.colors[2] else pop.colors[1]
	pop:_hit(newWave(), 3, 3)
	truthy(pop.board:get(3, 3).bird, "a blast leaves it")
	pop:_popGroups(newWave(), { rowAt(pop, 4, 2, other) })
	truthy(pop.board:get(3, 3).bird, "another colour leaves it")
	local wave = newWave()
	pop:_popGroups(wave, { rowAt(pop, 4, 2, want) })
	falsy(pop.board:get(3, 3).bird)
	eq(pop.board:get(3, 3).bale, 0)
	eq(pop.goals:find("Birds").progress, 1)
	local fed = false
	for _, e in wave.effects do
		fed = fed or (e.type == "Bird" and e.x == 3 and e.y == 3)
	end
	truthy(fed, "a Bird effect")
end)

test("after every swap each bird hops on to the next colour, wrapping round", function()
	local pop = Engine.new(birdLevel(), 3)
	local cell = pop.board:get(3, 3)
	local n = #pop.colors
	local seen = { cell.bird }
	for i = 1, n do
		local phases = {}
		pop:_hopBirds(phases)
		table.insert(seen, cell.bird)
		local hop = false
		for _, p in phases do
			for _, e in p.effects or {} do
				hop = hop or e.type == "Hop"
			end
		end
		truthy(hop, "a Hop effect")
	end
	eq(seen[2], pop.colors[2])
	eq(seen[n + 1], pop.colors[1], "back to the first colour")
end)

test("bird levels replay the same", function()
	local level = birdLevel()
	local a, b = Engine.new(level, 7), Engine.new(level, 7)
	for _ = 1, 10 do
		local moves = a:listPossibleMoves()
		if #moves == 0 or a.status ~= "Playing" then
			break
		end
		local m = moves[1]
		a:trySwap(m[1], m[2], m[3], m[4])
		b:trySwap(m[1], m[2], m[3], m[4])
		eq(a.board:hash(), b.board:hash())
	end
end)
