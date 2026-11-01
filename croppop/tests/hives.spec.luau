-- Beehives: never break; each hit sends a honey jar to the Honey goal.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", ".j....j.", "........", "........", "........", "........" }

local function hiveLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Honey", count = 6 } }, moves = 40 })
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

test("beehives block a cell, and the Honey goal needs a count and a hive", function()
	local board = Board.fromLayout(LAYOUT)
	local cell = board:get(2, 4)
	eq(cell.bale, 1)
	truthy(cell.hive)
	falsy(cell.piece)
	truthy(string.find(board:hash(), "J", 1, true))
	local pop = Engine.new(hiveLevel({ goals = { { kind = "Honey", count = 6 }, { kind = "HayBale" } } }), 1)
	eq(pop.goals:find("Honey").target, 6)
	eq(pop.goals:find("HayBale").target, 0)
	eq(Levels.validate(hiveLevel()), nil)
	truthy(Levels.validate(hiveLevel({ goals = { { kind = "Honey" } } })), "honey goal without a count")
	truthy(Levels.validate(hiveLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "hives without a honey goal")
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Honey", count = 3 } } })), "honey goal without hives")
end)

test("every hit sends a jar, and the hive stays", function()
	local pop = Engine.new(hiveLevel(), 2)
	for i = 1, 3 do
		local wave = { bales = {}, effects = {} }
		pop:_damageBale(wave, pop.board:get(2, 4))
		eq(#effectsOf({ wave }, "Honey"), 1)
		eq(wave.bales[1].hp, 1)
		truthy(wave.bales[1].hive)
		eq(pop.goals:find("Honey").progress, i)
	end
	truthy(pop.board:get(2, 4).hive)
	eq(pop.board:get(2, 4).bale, 1)
	local ok, phases = pop:useBooster("Trowel", 7, 4)
	truthy(ok)
	truthy(#effectsOf(phases, "Honey") >= 1)
	truthy(pop.board:get(7, 4).hive)
	truthy(pop.goals:find("Honey").progress >= 4)
end)

test("matches next to hives send honey, and hive levels replay the same", function()
	local level = hiveLevel({ goals = { { kind = "Honey", count = 40 } }, moves = 30 })
	local jars = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			jars += #effectsOf(phases, "Honey")
			table.insert(swaps, m)
		end
		truthy(pop.board:get(2, 4).hive)
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(jars > 0, "matches hit some hives")
	eq(CropPop.Bot.play(hiveLevel(), 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(hiveLevel()), 'kind = "Honey", count = 6', 1, true))
end)
