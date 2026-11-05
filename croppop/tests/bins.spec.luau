-- Compost bins: count down from 9; a match next to one feeds it all its
-- tiles, a blast takes 1, and at 0 it bursts, blasting the cells around it.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..B..B..", "........", "........", "........", "........", "........" }

local function binLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Bins" } }, moves = 30 })
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

test("compost bins block a cell, count down from 9 and need a Bins goal", function()
	local board = Board.fromLayout(LAYOUT)
	local bin = board:get(3, 3)
	eq(bin.bin, 9)
	eq(bin.bale, 1)
	eq(Levels.validate(binLevel()), nil)
	truthy(Levels.validate(binLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "bins without a goal")
	truthy(Levels.validate(binLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without bins")
	local pop = Engine.new(binLevel(), 1)
	eq(pop.goals:find("Bins").target, 2)
	falsy(pop.goals:find("HayBale"), "bins aren't hay bales")
	truthy(string.find(pop.board:hash(), "Q9", 1, true))
end)

test("a match next to a bin feeds it every tile, a blast takes one, and at 0 it bursts", function()
	local pop = Engine.new(binLevel(), 2)
	local bin = pop.board:get(3, 3)
	local wave = newWave()
	-- A match of 4 along the row under the bin.
	local cells = { pop.board:get(2, 4), pop.board:get(3, 4), pop.board:get(4, 4), pop.board:get(5, 4) }
	pop:_popGroups(wave, { { cells = cells, color = cells[1].piece.color } })
	eq(bin.bin, 5, "a match of 4 takes 4")
	pop:_hit(wave, 3, 3)
	eq(bin.bin, 4, "a blast takes 1")
	local goal = pop.goals:find("Bins")
	pop:_feedBin(wave, bin, 10)
	eq(goal.progress, 1)
	eq(bin.bale, 0)
	falsy(bin.bin)
	eq(#effectsOf({ wave }, "Compost"), 1)
	local bomb = wave.queue[#wave.queue]
	eq(bomb.power, CropPop.Tiles.Power.HayBomb)
	eq(bomb.radius, 1)
	-- A burst bin takes nothing more.
	pop:_hit(wave, 3, 3)
	eq(goal.progress, 1)
end)

test("bins burst in play, and bin levels replay the same", function()
	local level = binLevel({ moves = 30 })
	local bursts = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			bursts += #effectsOf(phases, "Compost")
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(bursts > 0, "some bins burst")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(binLevel()), '"..B..B.."', 1, true))
end)

test("bees go for compost bins on a Bins level", function()
	local pop = Engine.new(binLevel(), 4)
	for _ = 1, 10 do
		truthy(pop:_chooseBeeTarget().bin)
	end
end)
