-- Tulip buds: three hits on swaps in a row make one bloom; a missed swap closes it.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", ".T....T.", "........", "........", "........", "........" }

local function budLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Blooms" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function wave()
	return { bales = {}, effects = {}, pendingCreates = {}, balesTouched = {} }
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

test("tulip buds block a cell, aren't bales, and need a blooms goal", function()
	local board = Board.fromLayout(LAYOUT)
	local cell = board:get(2, 4)
	eq(cell.bale, 1)
	eq(cell.bud, 0)
	falsy(cell.piece)
	truthy(string.find(board:hash(), "E0", 1, true))
	eq(Levels.validate(budLevel()), nil)
	truthy(Levels.validate(budLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "buds without a blooms goal")
	truthy(Levels.validate(budLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a blooms goal without buds")
	eq(Engine.new(budLevel(), 1).goals:find("Blooms").target, 2)
	local mixed = Engine.new(budLevel({ layout = { "........", "..1.....", "........", ".T....T.", "........", "........", "........", "........" }, goals = { { kind = "HayBale" }, { kind = "Blooms" } } }), 1)
	eq(mixed.goals:find("HayBale").target, 1, "buds don't count as bales")
end)

test("three hits make a bud bloom; a swap that misses it closes it up", function()
	local pop = Engine.new(budLevel(), 2)
	local bud = pop.board:get(2, 4)
	local goal = pop.goals:find("Blooms")
	pop:_damageBale(wave(), bud)
	eq(bud.bud, 1)
	eq(bud.bale, 1)
	-- A swap went by and the bud was hit during it: it keeps its charge.
	local phases = {}
	pop:_wiltBuds(phases)
	eq(bud.bud, 1)
	eq(#phases, 0)
	-- The next swap misses it: it closes.
	pop:_wiltBuds(phases)
	eq(bud.bud, 0)
	eq(#effectsOf(phases, "Wilt"), 1)
	-- Three hits in a row: it blooms.
	for _ = 1, 3 do
		pop:_damageBale(wave(), bud)
	end
	falsy(bud.bud)
	eq(bud.bale, 0)
	eq(goal.progress, 1)
	-- An uncharged bud doesn't wilt (nothing to lose).
	phases = {}
	pop:_wiltBuds(phases)
	eq(#phases, 0)
	-- The Trowel charges a bud too.
	truthy(pop:useBooster("Trowel", 7, 4))
	eq(pop.board:get(7, 4).bud, 1)
end)

test("matches charge buds, and bud levels replay the same", function()
	local level = budLevel({ moves = 30 })
	local blooms, wilts = 0, 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			blooms += #effectsOf(phases, "Bloom")
			wilts += #effectsOf(phases, "Wilt")
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(wilts > 0, "some buds closed up")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(budLevel()), '".T....T."', 1, true))
end)
