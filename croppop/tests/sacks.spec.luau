-- Seed sacks: never break; a match next to one or a blast on it sows clover
-- on the nearest cells without any.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", ".z....z.", "........", "........", "........", "........" }

local function sackLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Clover" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function sowsOf(phases)
	local out = {}
	for _, phase in phases do
		for _, e in phase.effects or {} do
			if e.type == "Sow" then
				table.insert(out, e)
			end
		end
	end
	return out
end

test("seed sacks block a cell, and their cells need no clover", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(2, 4).sack)
	eq(board:get(2, 4).bale, 1)
	falsy(board:get(2, 4).piece)
	truthy(string.find(board:hash(), "Z", 1, true))
	eq(Engine.new(sackLevel(), 1).goals:find("Clover").target, 62)
	eq(Levels.validate(sackLevel()), nil)
	truthy(Levels.validate(sackLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "sacks without a clover goal")
end)

test("a blast on a sack sows the nearest cells and the sack stays", function()
	local pop = Engine.new(sackLevel(), 2)
	local wave = { bales = {}, effects = {}, clover = {} }
	pop:_damageBale(wave, pop.board:get(2, 4))
	truthy(pop.board:get(2, 4).sack)
	eq(pop.board:get(2, 4).bale, 1)
	local sow = sowsOf({ wave })
	eq(#sow, 1)
	eq(#sow[1].cells, 3)
	-- Nearest first, in NEIGHBORS order: right, left, below.
	truthy(pop.board:get(3, 4).clover)
	truthy(pop.board:get(1, 4).clover)
	truthy(pop.board:get(2, 5).clover)
	falsy(pop.board:get(2, 4).clover)
	eq(pop.goals:find("Clover").progress, 3)
	-- The next hit sows further out.
	pop:_damageBale(wave, pop.board:get(2, 4))
	truthy(pop.board:get(2, 3).clover)
	eq(pop.goals:find("Clover").progress, 6)
	-- A Trowel on a sack works the same way.
	local ok, phases = pop:useBooster("Trowel", 7, 4)
	truthy(ok)
	truthy(#sowsOf(phases) >= 1)
	truthy(pop.board:get(7, 4).sack)
end)

test("matches next to a sack sow clover, and sack levels replay the same", function()
	local level = sackLevel({ moves = 30 })
	local sown = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			sown += #sowsOf(phases)
			table.insert(swaps, m)
		end
		truthy(pop.board:get(2, 4).sack)
		falsy(pop.board:get(2, 4).clover)
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(sown > 0, "matches shook some sacks")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(sackLevel()), '".z....z."', 1, true))
end)
