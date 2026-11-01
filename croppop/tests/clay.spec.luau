-- Clay: glazed clay under a tile only cracks under a blast; then any clear
-- there (a match too) breaks it up.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..aa....", "..aA....", "........", "........", "........", "........" }

local function clayLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Clay" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function wave()
	return { removed = {}, mud = {}, clay = {}, goo = {}, frost = {}, queue = {} }
end

test("clay sits under tiles, and the goal counts clay cells", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board:get(3, 3).clay, 2)
	eq(board:get(4, 4).clay, 1)
	truthy(string.find(board:hash(), "a2", 1, true))
	local pop = Engine.new(clayLevel(), 1)
	truthy(pop.board:get(3, 3).piece)
	eq(pop.goals:find("Clay").target, 4)
	eq(Levels.validate(clayLevel()), nil)
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Clay" } } })), "clay goal without clay")
end)

test("a match leaves glazed clay alone; a blast cracks it; the next clear breaks it", function()
	local pop = Engine.new(clayLevel(), 2)
	local cell = pop.board:get(3, 3)
	local w = wave()
	pop:_removePiece(w, cell, "match")
	eq(cell.clay, 2, "a match can't crack the glaze")
	eq(#w.clay, 0)
	cell.piece = pop.board:newPiece(1)
	pop:_removePiece(w, cell, "power")
	eq(cell.clay, 1)
	eq(w.clay[1].layers, 1)
	eq(pop.goals:find("Clay").progress, 0)
	cell.piece = pop.board:newPiece(1)
	pop:_removePiece(w, cell, "match")
	eq(cell.clay, nil)
	eq(pop.goals:find("Clay").progress, 1)
	-- Cracked clay breaks to a match straight away.
	local cracked = pop.board:get(4, 4)
	pop:_removePiece(w, cracked, "match")
	eq(cracked.clay, nil)
	eq(pop.goals:find("Clay").progress, 2)
	-- The Trowel cracks glazed clay.
	local ok = pop:useBooster("Trowel", 4, 3)
	truthy(ok)
	truthy(pop.board:get(4, 3).clay ~= 2, "the Trowel cracked it (a cascade may have broken it up)")
end)

test("clay levels replay the same, and the bot plays them", function()
	local level = clayLevel({ moves = 30 })
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	falsy(Board.fromLayout(Helpers.level().layout):get(1, 1).clay)
	truthy(string.find(CropPop.LevelText.write(clayLevel()), '"..aA...."', 1, true))
end)
