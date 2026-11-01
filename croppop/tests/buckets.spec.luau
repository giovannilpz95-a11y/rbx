-- Mud buckets: one hit tips a bucket over and spills mud on the 3x3 around
-- it; the Mud goal counts each bucket and each spilt layer.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", ".u....u.", "........", "........", "........", "........" }

local function bucketLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Mud" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function wave()
	return { bales = {}, effects = {}, mud = {} }
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

test("mud buckets block a cell, and each counts for the Mud goal", function()
	local board = Board.fromLayout(LAYOUT)
	local cell = board:get(2, 4)
	eq(cell.bale, 1)
	truthy(cell.bucket)
	falsy(cell.piece)
	truthy(string.find(board:hash(), "U", 1, true))
	local pop = Engine.new(bucketLevel({ goals = { { kind = "Mud" }, { kind = "HayBale" } } }), 1)
	eq(pop.goals:find("Mud").target, 2)
	eq(pop.goals:find("HayBale").target, 0)
	eq(Levels.validate(bucketLevel()), nil)
	truthy(Levels.validate(bucketLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "buckets without a mud goal")
end)

test("a hit tips a bucket, spilling mud on the 3x3 around it", function()
	local pop = Engine.new(bucketLevel(), 2)
	-- Some mud already there, and clay, get no more.
	pop.board:get(1, 3).mud = 2
	pop.board:get(3, 5).clay = 2
	local w = wave()
	pop:_damageBale(w, pop.board:get(2, 4))
	local cell = pop.board:get(2, 4)
	eq(cell.bale, 0)
	falsy(cell.bucket)
	local spill = effectsOf({ w }, "Spill")
	eq(#spill, 1)
	eq(#spill[1].cells, 7, "9 cells less the muddy one and the clay one")
	eq(#w.mud, 7)
	eq(cell.mud, 1)
	eq(pop.board:get(3, 3).mud, 1)
	eq(pop.board:get(1, 3).mud, 2)
	eq(pop.board:get(3, 5).mud, 0)
	eq(pop.board:get(4, 4).mud, 0)
	local goal = pop.goals:find("Mud")
	eq(goal.progress, 1)
	eq(goal.target, 2 + 7)
	-- A Trowel tips the other one.
	local ok, phases = pop:useBooster("Trowel", 7, 4)
	truthy(ok)
	eq(#effectsOf(phases, "Spill"), 1)
	falsy(pop.board:get(7, 4).bucket)
	truthy(pop.goals:find("Mud").progress >= 2)
end)

test("matches tip buckets, and bucket levels replay the same", function()
	local level = bucketLevel({ moves = 30 })
	local tipped = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			tipped += #effectsOf(phases, "Spill")
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(tipped > 0, "matches tipped some buckets")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(bucketLevel()), '".u....u."', 1, true))
end)
