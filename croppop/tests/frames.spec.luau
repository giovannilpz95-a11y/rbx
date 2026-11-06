-- Cold frames: each hit opens one a stage and the last frees it; a swap
-- that misses a part-open frame closes it one stage again.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board = CropPop.Levels, CropPop.Engine, CropPop.Board

local LAYOUT = { "........", "........", "..^..^..", "........", "........", "........", "........", "........" }

local function frameLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Frames" } }, moves = 30 })
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

local function rowAt(pop, y, x1)
	local color = pop.colors[1]
	local cells = { pop.board:get(x1, y), pop.board:get(x1 + 1, y), pop.board:get(x1 + 2, y) }
	for _, cell in cells do
		cell.piece = pop.board:newPiece(color)
	end
	return { cells = cells, color = color }
end

local function hasEffect(phases, kind)
	for _, p in phases do
		for _, e in p.effects or {} do
			if e.type == kind then
				return true
			end
		end
	end
	return false
end

test("cold frames block a cell with 3 stages and need a Frames goal", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(3, 3).frame)
	eq(board:get(3, 3).bale, 3)
	eq(Levels.validate(frameLevel()), nil)
	truthy(Levels.validate(frameLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "frames without a goal")
	truthy(Levels.validate(frameLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without frames")
	local pop = Engine.new(frameLevel(), 1)
	eq(pop.goals:find("Frames").target, 2)
	truthy(string.find(pop.board:hash(), "^3", 1, true))
end)

test("matches and blasts open a frame a stage each; the last frees it", function()
	local pop = Engine.new(frameLevel(), 2)
	local cell = pop.board:get(3, 3)
	pop:_popGroups(newWave(), { rowAt(pop, 4, 2) })
	eq(cell.bale, 2, "a match next to it")
	pop:_hit(newWave(), 3, 3)
	eq(cell.bale, 1, "a blast on it")
	local wave = newWave()
	pop:_hit(wave, 3, 3)
	falsy(cell.frame)
	eq(cell.bale, 0)
	eq(pop.goals:find("Frames").progress, 1)
	local freed = false
	for _, e in wave.effects do
		freed = freed or (e.type == "Frame" and e.x == 3 and e.y == 3)
	end
	truthy(freed, "a Frame effect")
end)

test("a swap that misses a part-open frame closes it one stage; a closed frame stays put", function()
	local pop = Engine.new(frameLevel(), 3)
	local a, b = pop.board:get(3, 3), pop.board:get(6, 3)
	pop:_hit(newWave(), 3, 3)
	pop:_hit(newWave(), 3, 3)
	eq(a.bale, 1)
	local phases = {}
	pop:_shutFrames(phases) -- the hits count for this swap
	eq(a.bale, 1)
	falsy(hasEffect(phases, "Shut"))
	phases = {}
	pop:_shutFrames(phases) -- the next swap misses it
	eq(a.bale, 2)
	eq(b.bale, 3, "a closed frame doesn't grow")
	truthy(hasEffect(phases, "Shut"))
	pop:_shutFrames({})
	pop:_shutFrames({})
	eq(a.bale, 3, "never more than closed")
end)

test("frame levels replay the same", function()
	local level = frameLevel()
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
