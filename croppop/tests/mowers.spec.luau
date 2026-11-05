-- Lawn mowers: matches of a mower's colour anywhere charge it (once a wave),
-- and the third charge mows its row. Blasts don't touch it.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "U111111U", "........", "........", "........", "........", "........" }

local function mowLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "HayBale" } }, moves = 30 })
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

test("mowers block a cell, take the level's colours in turn, and aren't bales", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(1, 3).mower)
	eq(board:get(1, 3).bale, 1)
	eq(Levels.validate(mowLevel()), nil)
	local pop = Engine.new(mowLevel(), 1)
	local a, b = pop.board:get(1, 3), pop.board:get(8, 3)
	eq(a.mower, 0)
	eq(a.mowerColor, pop.colors[1])
	eq(b.mowerColor, pop.colors[2])
	eq(pop.goals:find("HayBale").target, 6, "mowers don't count as bales")
	truthy(string.find(pop.board:hash(), "M0c", 1, true))
end)

test("matches of its colour charge a mower once a wave; the third mows its row", function()
	local pop = Engine.new(mowLevel(), 2)
	local mower = pop.board:get(1, 3)
	local color = mower.mowerColor
	local other = pop.board:get(8, 3).mowerColor
	local function group(c)
		local cells = { pop.board:get(2, 7), pop.board:get(3, 7), pop.board:get(4, 7) }
		for _, cell in cells do
			cell.piece = pop.board:newPiece(c)
		end
		return { cells = cells, color = c }
	end
	local wave = newWave()
	pop:_popGroups(wave, { group(other) })
	eq(mower.mower, 0, "another colour doesn't charge it")
	pop:_popGroups(wave, { group(color) })
	eq(mower.mower, 1, "a match far away still charges it")
	pop:_popGroups(wave, { group(color) })
	eq(mower.mower, 1, "once per wave")
	pop:_hit(wave, 1, 3)
	eq(mower.mower, 1, "blasts don't charge it")
	truthy(mower.mower ~= nil and mower.bale == 1, "or break it")
	local w2 = newWave()
	pop:_popGroups(w2, { group(color) })
	local w3 = newWave()
	pop:_popGroups(w3, { group(color) })
	eq(mower.mower, 0, "it starts again after mowing")
	eq(#effectsOf({ w3 }, "Mow"), 1)
	local spray = w3.queue[#w3.queue]
	eq(spray.power, CropPop.Tiles.Power.SprayerRow)
	eq(spray.y, 3)
end)

test("mowers mow in play, and mower levels replay the same", function()
	local level = mowLevel({ moves = 30 })
	local mows = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			mows += #effectsOf(phases, "Mow")
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(mows > 0, "some rows were mowed")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(mowLevel()), '"U111111U"', 1, true))
end)

test("bees leave mowers alone", function()
	local pop = Engine.new(mowLevel(), 4)
	for _ = 1, 10 do
		falsy(pop:_chooseBeeTarget().mower)
	end
end)
