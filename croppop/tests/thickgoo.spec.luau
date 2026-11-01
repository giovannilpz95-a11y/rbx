-- Thick goo: two clears, and goo spreading next to it spreads thick.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", "...ee...", "...gg...", "........", "........", "........" }

local function gooLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Goo" } }, moves = 60 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

test("thick goo counts twice for the goal", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(4, 4).thickGoo)
	truthy(board:get(4, 4).goo)
	falsy(board:get(4, 5).thickGoo)
	truthy(string.find(board:hash(), "gg", 1, true))
	eq(Engine.new(gooLevel(), 1).goals:find("Goo").target, 6)
	eq(Levels.validate(gooLevel()), nil)
end)

test("the first clear on thick goo leaves plain goo, the second clears it", function()
	local pop = Engine.new(gooLevel(), 2)
	local cell = pop.board:get(4, 4)
	local function clear()
		local wave = { removed = {}, frost = {}, goo = {}, mud = {}, queue = {} }
		pop:_removePiece(wave, cell, "power")
		cell.piece = pop.board:newPiece(1)
		return wave
	end
	local first = clear()
	truthy(cell.goo)
	falsy(cell.thickGoo)
	eq(first.goo[1].on, true, "still goo after the first clear")
	eq(pop.goals:find("Goo").progress, 1)
	local second = clear()
	falsy(cell.goo)
	eq(second.goo[1].on, false)
	eq(pop.goals:find("Goo").progress, 2)
end)

test("goo spreading next to thick goo spreads thick", function()
	local pop = Engine.new(gooLevel(), 3)
	-- Only thick goo left, so the spread lands next to it.
	pop.board:get(4, 5).goo = false
	pop.board:get(5, 5).goo = false
	local target = pop.goals:find("Goo").target
	local phases = {}
	pop:_growGoo(phases)
	local grown
	for _, phase in phases do
		for _, g in phase.goo or {} do
			grown = g
		end
	end
	truthy(grown and grown.thick)
	truthy(pop.board:get(grown.x, grown.y).thickGoo)
	eq(pop.goals:find("Goo").target, target + 2)
end)

test("a thick goo level replays the same, and the bot plays it", function()
	local level = gooLevel({ moves = 30 })
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
end)
