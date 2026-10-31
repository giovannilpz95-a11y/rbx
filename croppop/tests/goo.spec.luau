-- Goo: covers tiles, clears when the tile on it goes, spreads after a swap that clears none.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", "...gg...", "...gg...", "........", "........", "........" }

local function gooLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Goo" } }, moves = 60 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function countGoo(board)
	local n = 0
	board:eachCell(function(cell)
		if cell.goo then
			n += 1
		end
	end)
	return n
end

test("the layout puts goo on cells and the goal counts it", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(4, 4).goo)
	falsy(board:get(1, 1).goo)
	eq(countGoo(board), 4)
	local pop = Engine.new(gooLevel(), 1)
	eq(pop.goals:find("Goo").target, 4)
	truthy(string.find(pop.board:hash(), "g", 1, true))
end)

test("levels check goo goals", function()
	eq(Levels.validate(gooLevel()), nil)
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Goo" } } })), "goo goal without goo")
end)

test("goo clears with its tile and spreads after a swap that clears none", function()
	local level = gooLevel()
	local cleared, spread = 0, 0
	for seed = 1, 6 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		for _ = 1, 25 do
			if pop.status ~= "Playing" then
				break
			end
			local before = countGoo(pop.board)
			local target = pop.goals:find("Goo").target
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			local offs, ons = 0, 0
			for _, phase in phases do
				for _, g in phase.goo or {} do
					if g.on then
						ons += 1
					else
						offs += 1
					end
				end
			end
			eq(countGoo(pop.board), before - offs + ons)
			truthy(ons <= 1, "one spread per swap at most")
			if ons == 1 then
				eq(offs, 0, "it spreads only when the swap cleared none")
				eq(pop.goals:find("Goo").target, target + 1, "a spread adds one to clear")
			end
			cleared += offs
			spread += ons
		end
	end
	truthy(cleared > 0)
	truthy(spread > 0)
end)

test("goo covering every tile loses the level, with no continue", function()
	local pop = Engine.new(gooLevel(), 2)
	-- Cover all but one tile next to the goo, then let it spread.
	pop.board:eachCell(function(cell)
		cell.goo = not (cell.x == 3 and cell.y == 4)
	end)
	local phases = {}
	pop:_growGoo(phases)
	truthy(pop.board:get(3, 4).goo)
	truthy(pop.flooded)
	pop:_updateStatus()
	eq(pop.status, "Lost")
	falsy(pop:continue(), "more moves won't help")
	eq(phases[#phases].effects[1].type, "Ooze")
end)

test("a goo level replays the same, and the bot plays it", function()
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
