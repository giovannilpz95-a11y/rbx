-- Fireflies: clearing the tile on a lit spot catches one; the lights move every 2 swaps.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", ".N....N.", "........", "...NN...", "........", "........", ".N....N.", "........" }

local function flyLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Fireflies", count = 8 } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function litCells(pop)
	local out = {}
	for _, cell in pop.board.spots do
		if cell.lit then
			table.insert(out, cell)
		end
	end
	return out
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

test("firefly spots are plain cells, a third of them lit, and need a fireflies goal with a count", function()
	local board = Board.fromLayout(LAYOUT)
	eq(#board.spots, 6)
	truthy(board:get(2, 2).spot)
	truthy(board:get(2, 2).piece == nil, "an empty board until it's filled")
	eq(Levels.validate(flyLevel()), nil)
	truthy(Levels.validate(flyLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "spots without a fireflies goal")
	truthy(Levels.validate(flyLevel({ goals = { { kind = "Fireflies" } } })), "a fireflies goal without a count")
	truthy(Levels.validate(flyLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a fireflies goal without spots")
	local pop = Engine.new(flyLevel(), 1)
	eq(#litCells(pop), 2)
	eq(pop.goals:find("Fireflies").target, 8)
	truthy(string.find(pop.board:hash(), "$", 1, true))
	-- The same seed lights the same spots.
	local again = Engine.new(flyLevel(), 1)
	eq(again.board:hash(), pop.board:hash())
end)

test("clearing a tile on a lit spot catches a firefly and darkens the spot", function()
	local pop = Engine.new(flyLevel(), 3)
	local goal = pop.goals:find("Fireflies")
	local lit = litCells(pop)[1]
	local wave = { removed = {}, effects = {}, goo = {}, mud = {}, clay = {}, frost = {}, queue = {} }
	pop:_removePiece(wave, lit, "match")
	eq(goal.progress, 1)
	falsy(lit.lit)
	eq(#effectsOf({ wave }, "Catch"), 1)
	-- A dark spot catches nothing.
	lit.piece = pop.board:newPiece(1)
	pop:_removePiece(wave, lit, "match")
	eq(goal.progress, 1)
	-- The Trowel catches one too.
	local other = litCells(pop)[1]
	truthy(pop:useBooster("Trowel", other.x, other.y))
	eq(goal.progress, 2)
end)

test("the lights move to other spots every 2 swaps, and firefly levels replay the same", function()
	local level = flyLevel({ moves = 30 })
	local moved, catches = 0, 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local before = {}
			for _, cell in litCells(pop) do
				before[cell] = true
			end
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			catches += #effectsOf(phases, "Catch")
			local lights = effectsOf(phases, "Lights")
			if #lights > 0 then
				moved += 1
				eq(#swaps % 2, 0, "the lights move on every second swap")
				for _, cell in litCells(pop) do
					falsy(before[cell], "they move to spots that weren't lit")
				end
				eq(#litCells(pop), 2)
			end
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(moved > 0, "the lights moved")
	truthy(catches > 0, "some fireflies caught")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(flyLevel()), '".N....N."', 1, true))
end)
