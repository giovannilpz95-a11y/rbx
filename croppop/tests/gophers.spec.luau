-- Gopher burrows: one gopher hops between open burrows after every swap;
-- clearing the tile on its burrow catches it and fills the burrow in.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", ".I....I.", "........", "........", "........", "........", ".I....I.", "........" }

local function gopherLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Gophers" } }, moves = 40 })
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

local function gophers(pop)
	local out = {}
	for _, cell in pop.board.burrows do
		if cell.gopher then
			table.insert(out, cell)
		end
	end
	return out
end

test("burrows are plain cells, one gopher is out, and they need a Gophers goal", function()
	local board = Board.fromLayout(LAYOUT)
	eq(#board.burrows, 4)
	truthy(board:get(2, 2).burrow)
	eq(Levels.validate(gopherLevel()), nil)
	truthy(Levels.validate(gopherLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "burrows without a goal")
	truthy(Levels.validate(gopherLevel({ layout = { "........", ".I......", "........", "........", "........", "........", "........", "........" } })), "one burrow isn't enough")
	local pop = Engine.new(gopherLevel(), 1)
	eq(#gophers(pop), 1)
	eq(pop.goals:find("Gophers").target, 4)
	truthy(string.find(pop.board:hash(), "?", 1, true))
	eq(Engine.new(gopherLevel(), 1).board:hash(), pop.board:hash(), "the same seed, the same burrow")
end)

test("clearing the gopher's tile catches it and fills the burrow in; the next one comes up after the move", function()
	local pop = Engine.new(gopherLevel(), 3)
	local goal = pop.goals:find("Gophers")
	local cell = gophers(pop)[1]
	local wave = newWave()
	pop:_removePiece(wave, cell, "match")
	eq(goal.progress, 1)
	falsy(cell.gopher)
	falsy(cell.burrow, "the burrow is filled in")
	eq(#effectsOf({ wave }, "Gopher"), 1)
	eq(#gophers(pop), 0)
	-- A booster use (not a swap) still brings the next gopher up.
	local phases = {}
	pop:_afterAction(phases, false)
	eq(#gophers(pop), 1)
	truthy(gophers(pop)[1] ~= cell)
	eq(#effectsOf(phases, "Burrow"), 1)
end)

test("the gopher hops to another burrow after every swap, and gopher levels replay the same", function()
	local level = gopherLevel({ moves = 30 })
	local caught = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local before = gophers(pop)[1]
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			caught += #effectsOf(phases, "Gopher")
			local open = 0
			for _, c in pop.board.burrows do
				if c.burrow then
					open += 1
				end
			end
			if pop.status == "Playing" and open >= 2 then
				truthy(gophers(pop)[1] ~= before, "it hops every swap")
			end
			truthy(#gophers(pop) <= 1)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(caught > 0, "some gophers caught")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(gopherLevel()), '".I....I."', 1, true))
end)

test("bees go for the gopher on a Gophers level", function()
	local pop = Engine.new(gopherLevel(), 4)
	truthy(pop:_chooseBeeTarget().gopher)
end)
