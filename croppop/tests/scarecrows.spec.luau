-- Scarecrows: never break; every third hit clears the most common colour.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", "...y....", "........", "........", "........", "........" }

local function crowLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
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

test("a scarecrow blocks a cell, never breaks, and isn't a bale", function()
	local board = Board.fromLayout(LAYOUT)
	local cell = board:get(4, 4)
	eq(cell.bale, 1)
	eq(cell.scarecrow, 0)
	truthy(string.find(board:hash(), "Y0", 1, true))
	eq(Levels.validate(crowLevel()), nil)
	local pop = Engine.new(crowLevel({ goals = { { kind = "HayBale" } } }), 1)
	eq(pop.goals:find("HayBale").target, 0)
end)

test("every third hit clears the most common colour, and it charges again", function()
	local pop = Engine.new(crowLevel(), 2)
	for i = 1, 2 do
		local ok, phases = pop:useBooster("Trowel", 4, 4)
		truthy(ok)
		eq(#effectsOf(phases, "Scarecrow"), 0)
		eq(pop.board:get(4, 4).scarecrow, i)
	end
	local ok, phases = pop:useBooster("Trowel", 4, 4)
	truthy(ok)
	eq(#effectsOf(phases, "Scarecrow"), 1)
	local sun = effectsOf(phases, "Sun")
	eq(#sun, 1)
	truthy(sun[1].color)
	-- It starts charging again (a cascade next to it may already have added one).
	local reset = false
	for _, b in phases[1].bales do
		reset = reset or (b.x == 4 and b.y == 4 and b.scarecrow == 0)
	end
	truthy(reset)
	truthy(pop.board:get(4, 4).scarecrow < 3)
	eq(pop.board:get(4, 4).bale, 1)
	-- Lots of tiles went in that one wave.
	local removed = 0
	for _, phase in phases do
		if phase.kind == "Pop" then
			removed += #phase.removed
		end
	end
	truthy(removed >= 6, "removed " .. removed)
end)

test("scarecrow levels replay the same, and the bot plays them", function()
	local level = crowLevel({ moves = 30 })
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		truthy(pop.board:get(4, 4).scarecrow ~= nil)
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(crowLevel()), '"...y...."', 1, true))
end)
