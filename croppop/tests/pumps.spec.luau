-- Flood water and hand pumps: each hit on a pump drains the 2 nearest
-- flooded cells, and the pumps go once the water is gone.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "...H....", "........", "..WWWW..", "..WWWW..", "........", "....H...", "........" }

local function floodLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Floods" } }, moves = 30 })
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

local function flooded(board)
	local n = 0
	board:eachCell(function(cell)
		if cell.flood then
			n += 1
		end
	end)
	return n
end

test("flood water lies under tiles, pumps block a cell, and both need a Floods goal", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board.floodsLeft, 8)
	truthy(board:get(3, 4).flood)
	truthy(board:get(4, 2).pump)
	eq(board:get(4, 2).bale, 1)
	eq(Levels.validate(floodLevel()), nil)
	truthy(Levels.validate(floodLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "water without a goal")
	truthy(Levels.validate(floodLevel({ layout = { "........", "........", "........", "..WWWW..", "..WWWW..", "........", "........", "........" } })), "water without a pump")
	truthy(Levels.validate(floodLevel({ layout = { "........", "...H....", "........", "........", "........", "........", "........", "........" } })), "a pump without water")
	local pop = Engine.new(floodLevel(), 1)
	eq(pop.goals:find("Floods").target, 8)
	falsy(pop.goals:find("HayBale"), "pumps aren't hay bales")
	truthy(string.find(pop.board:hash(), "=", 1, true))
	truthy(pop.board:get(3, 4).piece, "flooded cells hold tiles")
end)

test("each hit on a pump drains the 2 nearest flooded cells, and the pumps go with the water", function()
	local pop = Engine.new(floodLevel(), 2)
	local goal = pop.goals:find("Floods")
	local wave = newWave()
	-- Matches don't touch the water.
	pop:_removePiece(wave, pop.board:get(3, 4), "match")
	truthy(pop.board:get(3, 4).flood)
	pop:_hit(wave, 4, 2)
	eq(goal.progress, 2)
	eq(flooded(pop.board), 6)
	eq(#effectsOf({ wave }, "Pump")[1].cells, 2)
	falsy(pop.board:get(4, 4).flood, "the cell nearest the pump drains first")
	truthy(pop.board:get(4, 2).pump, "a pump stays while there's water")
	for _ = 1, 3 do
		pop:_hit(wave, 5, 7)
	end
	eq(goal.progress, 8)
	eq(flooded(pop.board), 0)
	falsy(pop.board:get(4, 2).pump)
	falsy(pop.board:get(5, 7).pump)
	eq(pop.board:get(4, 2).bale, 0)
	eq(#effectsOf({ wave }, "PumpGone"), 2)
end)

test("pumps drain in play, and flood levels replay the same", function()
	local level = floodLevel({ moves = 30 })
	local pumped = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			pumped += #effectsOf(phases, "Pump")
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(pumped > 0, "some pumps were hit")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(floodLevel()), '"..WWWW.."', 1, true))
end)

test("bees go for pumps on a Floods level", function()
	local pop = Engine.new(floodLevel(), 4)
	for _ = 1, 10 do
		truthy(pop:_chooseBeeTarget().pump)
	end
end)
