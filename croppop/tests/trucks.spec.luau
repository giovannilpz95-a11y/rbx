-- Hay trucks: each hit drops one of its 3 bales into the nearest emptied cell.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", ".C....C.", "........", "........", "........", "........" }

local function truckLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "HayBale" } }, moves = 40 })
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

test("hay trucks block like 3-layer bales, and the goal counts their bales", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board:get(2, 4).bale, 3)
	truthy(board:get(2, 4).truck)
	falsy(board:get(2, 4).piece)
	truthy(string.find(board:hash(), "N3", 1, true))
	eq(Engine.new(truckLevel(), 1).goals:find("HayBale").target, 6)
	eq(Levels.validate(truckLevel()), nil)
	truthy(Levels.validate(truckLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "trucks without a bale goal")
end)

test("a hit drops a bale into the nearest emptied cell; the last bale takes the truck", function()
	local pop = Engine.new(truckLevel(), 2)
	local truck = pop.board:get(2, 4)
	local goal = pop.goals:find("HayBale")
	-- An emptied cell next to it: the bale lands there as a 1-layer bale.
	local spot = pop.board:get(3, 4)
	spot.piece = nil
	local w = wave()
	pop:_damageBale(w, truck)
	eq(truck.bale, 2)
	truthy(truck.truck)
	eq(spot.bale, 1)
	falsy(spot.truck)
	truthy(w.balesTouched[spot])
	local drop = effectsOf({ w }, "Drop")
	eq(#drop, 1)
	eq(drop[1].x, 3)
	eq(goal.progress, 0)
	-- Breaking the dropped bale counts.
	pop:_damageBale(wave(), spot)
	eq(spot.bale, 0)
	eq(goal.progress, 1)
	-- Nowhere to drop it: it counts at once.
	spot.piece = pop.board:newPiece(1)
	pop:_damageBale(wave(), truck)
	eq(truck.bale, 1)
	eq(goal.progress, 2)
	pop:_damageBale(wave(), truck)
	eq(truck.bale, 0)
	falsy(truck.truck)
	eq(goal.progress, 3)
	-- A Trowel works on the other one.
	local ok = pop:useBooster("Trowel", 7, 4)
	truthy(ok)
	eq(pop.board:get(7, 4).bale, 2)
end)

test("matches knock bales off trucks, and truck levels replay the same", function()
	local level = truckLevel({ moves = 30 })
	local drops = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			drops += #effectsOf(phases, "Drop")
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(drops > 0, "some bales dropped off")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(truckLevel()), '".C....C."', 1, true))
end)
