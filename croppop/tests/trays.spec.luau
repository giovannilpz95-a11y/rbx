-- Seed trays: touching R cells make one tray under the tiles; clearing the
-- tile on each cell sprouts it, and a tray with every cell sprouted is done.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", ".RR.....", ".RR.....", "........", "........", ".....R..", ".....R..", "........" }

local function trayLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Trays" } }, moves = 30 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function newWave()
	return { removed = {}, effects = {}, goo = {}, mud = {}, clay = {}, frost = {}, queue = {} }
end

local function effectsOf(wave, kind)
	local out = {}
	for _, e in wave.effects do
		if e.type == kind then
			table.insert(out, e)
		end
	end
	return out
end

test("touching tray cells make one tray, and trays need a Trays goal", function()
	local board = Board.fromLayout(LAYOUT)
	eq(#board.trays, 2)
	eq(#board.trays[1].cells, 4)
	eq(board.trays[1].left, 4)
	eq(#board.trays[2].cells, 2)
	eq(board:get(2, 2).tray, board:get(3, 3).tray)
	truthy(board:get(2, 2).tray ~= board:get(6, 6).tray)
	falsy(board:get(1, 1).tray)
	eq(Levels.validate(trayLevel()), nil)
	truthy(Levels.validate(trayLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "trays without a goal")
	truthy(Levels.validate(trayLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without trays")
	local pop = Engine.new(trayLevel(), 1)
	eq(pop.goals:find("Trays").target, 2)
	truthy(string.find(pop.board:hash(), ";", 1, true))
	falsy(string.find(pop.board:hash(), ":", 1, true))
end)

test("clearing a tile on a tray cell sprouts it, once, and the last cell finishes the tray", function()
	local pop = Engine.new(trayLevel(), 2)
	local goal = pop.goals:find("Trays")
	local tray = pop.board:get(6, 6).tray
	local wave = newWave()
	pop:_removePiece(wave, pop.board:get(6, 6), "match")
	truthy(pop.board:get(6, 6).sprouted)
	eq(tray.left, 1)
	eq(#effectsOf(wave, "Sprout"), 1)
	eq(goal.progress, 0)
	truthy(string.find(pop.board:hash(), ":", 1, true))
	-- Clearing a sprouted cell again does nothing more.
	pop.board:get(6, 6).piece = pop.board:newPiece(1)
	pop:_removePiece(wave, pop.board:get(6, 6), "blast")
	eq(tray.left, 1)
	eq(#effectsOf(wave, "Sprout"), 1)
	pop:_removePiece(wave, pop.board:get(6, 7), "blast")
	eq(tray.left, 0)
	eq(goal.progress, 1)
	local done = effectsOf(wave, "Tray")
	eq(#done, 1)
	eq(#done[1].cells, 2)
end)

test("trays sprout in play, and tray levels replay the same", function()
	local level = trayLevel({ moves = 30 })
	local sprouts = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			for _, phase in phases do
				for _, e in phase.effects or {} do
					if e.type == "Sprout" then
						sprouts += 1
					end
				end
			end
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(sprouts > 0, "some tray cells sprouted")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(trayLevel()), '".RR....."', 1, true))
end)

test("bees go for unsprouted tray cells on a Trays level", function()
	local pop = Engine.new(trayLevel(), 4)
	for _ = 1, 10 do
		local cell = pop:_chooseBeeTarget()
		truthy(cell.tray and not cell.sprouted)
	end
end)
