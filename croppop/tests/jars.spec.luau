-- Jam jars: three matches of the jar's colour next to it (once per wave) or
-- blasts fill it, then any match next to it or a blast cracks it open.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..J..J..", "........", "........", "........", "........", "........" }

local function jarLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Jars" } }, moves = 30 })
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

test("jam jars block a cell, take the level's colours in turn and need a Jars goal", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(3, 3).jar)
	eq(board:get(3, 3).bale, 1)
	eq(Levels.validate(jarLevel()), nil)
	truthy(Levels.validate(jarLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "jars without a goal")
	truthy(Levels.validate(jarLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without jars")
	local pop = Engine.new(jarLevel(), 1)
	local a, b = pop.board:get(3, 3), pop.board:get(6, 3)
	eq(a.jar, 3)
	eq(a.jarColor, pop.colors[1])
	eq(b.jarColor, pop.colors[2])
	eq(pop.goals:find("Jars").target, 2)
	falsy(pop.goals:find("HayBale"), "jars aren't hay bales")
	truthy(string.find(pop.board:hash(), "C3c", 1, true))
end)

test("an empty jar fills from its own colour once a wave, and a full one cracks at any match", function()
	local pop = Engine.new(jarLevel(), 2)
	local jar = pop.board:get(3, 3)
	local color = jar.jarColor
	local other = if pop.colors[1] == color then pop.colors[2] else pop.colors[1]
	local function row(c)
		local cells = { pop.board:get(2, 4), pop.board:get(3, 4), pop.board:get(4, 4) }
		for _, cell in cells do
			cell.piece = pop.board:newPiece(c)
		end
		return { cells = cells, color = c }
	end
	local wave = newWave()
	pop:_popGroups(wave, { row(other) })
	eq(jar.jar, 3, "another colour doesn't fill it")
	pop:_popGroups(wave, { row(color) })
	eq(jar.jar, 2)
	pop:_popGroups(wave, { row(color) })
	eq(jar.jar, 2, "once per wave")
	pop:_hit(newWave(), 3, 3)
	eq(jar.jar, 1, "a blast adds a scoop")
	local filling = newWave()
	pop:_popGroups(filling, { row(color) })
	eq(jar.jar, 0)
	eq(#effectsOf({ filling }, "JarFull"), 1)
	pop:_popGroups(filling, { row(other) })
	eq(jar.jar, 0, "the same wave can't fill and crack it")
	local goal = pop.goals:find("Jars")
	eq(goal.progress, 0)
	local crack = newWave()
	pop:_popGroups(crack, { row(other) })
	eq(goal.progress, 1, "any colour cracks a full jar")
	eq(jar.bale, 0)
	falsy(jar.jar)
	eq(#effectsOf({ crack }, "Jar"), 1)
end)

test("a blast cracks a full jar too", function()
	local pop = Engine.new(jarLevel(), 3)
	local jar = pop.board:get(6, 3)
	for _ = 1, 3 do
		pop:_hit(newWave(), 6, 3)
	end
	eq(jar.jar, 0)
	pop:_hit(newWave(), 6, 3)
	falsy(jar.jar)
	eq(pop.goals:find("Jars").progress, 1)
end)

test("jars crack in play, and jar levels replay the same", function()
	local level = jarLevel({ moves = 30 })
	local cracked = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			cracked += #effectsOf(phases, "Jar")
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(cracked > 0, "some jars cracked")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(jarLevel()), '"..J..J.."', 1, true))
end)

test("bees go for jam jars on a Jars level", function()
	local pop = Engine.new(jarLevel(), 4)
	for _ = 1, 10 do
		truthy(pop:_chooseBeeTarget().jar)
	end
end)
