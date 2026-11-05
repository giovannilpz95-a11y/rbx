-- Weathervanes: 2-layer blockers with an arrow that turns a quarter after
-- every swap; only a match on the arrow's side knocks a layer off, while
-- blasts hit from anywhere.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..Z..Z..", "........", "........", "........", "........", "........" }

local function vaneLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Vanes" } }, moves = 30 })
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

test("weathervanes block a cell with 2 layers, point in turn and need a Vanes goal", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(3, 3).vane)
	eq(board:get(3, 3).bale, 2)
	eq(Levels.validate(vaneLevel()), nil)
	truthy(Levels.validate(vaneLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "vanes without a goal")
	truthy(Levels.validate(vaneLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without vanes")
	local pop = Engine.new(vaneLevel(), 1)
	eq(pop.board:get(3, 3).vane, 1, "the first points up")
	eq(pop.board:get(6, 3).vane, 2, "the next points right")
	eq(pop.goals:find("Vanes").target, 2)
	falsy(pop.goals:find("HayBale"), "vanes aren't hay bales")
	truthy(string.find(pop.board:hash(), "d2v1", 1, true))
end)

test("only a match on the arrow's side knocks a vane, once a wave; blasts hit from anywhere", function()
	local pop = Engine.new(vaneLevel(), 2)
	local vane = pop.board:get(3, 3) -- points up
	local function rowAt(y)
		local cells = { pop.board:get(2, y), pop.board:get(3, y), pop.board:get(4, y) }
		for _, cell in cells do
			cell.piece = pop.board:newPiece(pop.colors[1])
		end
		return { cells = cells, color = pop.colors[1] }
	end
	pop:_popGroups(newWave(), { rowAt(4) })
	eq(vane.bale, 2, "a match below doesn't touch an up vane")
	local wave = newWave()
	pop:_popGroups(wave, { rowAt(2) })
	eq(vane.bale, 1, "a match above knocks it")
	pop:_popGroups(wave, { rowAt(2) })
	eq(vane.bale, 1, "once per wave")
	local last = newWave()
	pop:_hit(last, 3, 3)
	eq(vane.bale, 0, "a blast hits it from anywhere")
	falsy(vane.vane)
	eq(pop.goals:find("Vanes").progress, 1)
	eq(#effectsOf({ last }, "Vane"), 1)
end)

test("vanes turn a quarter clockwise after every swap", function()
	local pop = Engine.new(vaneLevel(), 3)
	local a, b = pop.board:get(3, 3), pop.board:get(6, 3)
	local m = pop:listPossibleMoves()[1]
	local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
	if a.vane then
		eq(a.vane, 2)
	end
	if b.vane then
		eq(b.vane, 3)
	end
	eq(#effectsOf(phases, "Turn"), 1)
	for _ = 1, 3 do
		local n = pop:listPossibleMoves()[1]
		pop:trySwap(n[1], n[2], n[3], n[4])
	end
	if a.vane then
		eq(a.vane, 1, "back round after 4 swaps")
	end
end)

test("vanes come down in play, and vane levels replay the same", function()
	local level = vaneLevel({ moves = 30 })
	local down = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			down += #effectsOf(phases, "Vane")
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(down > 0, "some vanes came down")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(vaneLevel()), '"..Z..Z.."', 1, true))
end)

test("bees go for weathervanes on a Vanes level", function()
	local pop = Engine.new(vaneLevel(), 4)
	for _ = 1, 10 do
		truthy(pop:_chooseBeeTarget().vane)
	end
end)
