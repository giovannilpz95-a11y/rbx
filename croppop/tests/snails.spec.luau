-- Garden snails: matches shove them along; they bite what's in the way and leave goo.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "g......g", "........", "........", "..O..O..", "........", "........", "........", "g......g" }

local function snailLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Goo" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function wave()
	return { bales = {}, effects = {}, pendingCreates = {}, balesTouched = {}, removed = {}, goo = {}, mud = {}, clay = {}, frost = {}, webs = {}, queue = {} }
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

test("snails block a cell, aren't bales, and need a goo goal", function()
	local board = Board.fromLayout(LAYOUT)
	local cell = board:get(3, 4)
	eq(cell.bale, 1)
	truthy(cell.snail)
	falsy(cell.piece)
	truthy(string.find(board:hash(), "O0", 1, true))
	eq(Levels.validate(snailLevel()), nil)
	truthy(Levels.validate(snailLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "snails without a goo goal")
	local pop = Engine.new(snailLevel(), 1)
	eq(pop.goals:find("Goo").target, 4)
	local bales = Engine.new(snailLevel({ layout = { "........", "..1.....", "........", "..O..O..", "........", "........", "........", "g......g" }, goals = { { kind = "HayBale" }, { kind = "Goo" } } }), 1)
	eq(bales.goals:find("HayBale").target, 1, "snails don't count as bales")
end)

test("a shove bites the tile in the way, and the snail crawls in leaving goo", function()
	local pop = Engine.new(snailLevel(), 2)
	local snail, to = pop.board:get(3, 4), pop.board:get(4, 4)
	local goal = pop.goals:find("Goo")
	local w = wave()
	pop:_shoveSnail(w, snail, 1, 0)
	falsy(snail.snail)
	eq(snail.bale, 0)
	truthy(snail.goo, "a goo trail where it was")
	truthy(to.snail)
	eq(to.bale, 1)
	falsy(to.piece)
	eq(#w.removed, 1)
	eq(goal.target, 5)
	eq(#effectsOf({ w }, "Crawl"), 1)
	-- Blasts and the Trowel don't move it.
	pop:_damageBale(wave(), to)
	truthy(to.snail)
	falsy(pop:useBooster("Trowel", 4, 4))
	-- Off the board edge: it stays.
	local edge = Engine.new(snailLevel({ layout = { "O.......", "........", "........", "........", "........", "........", "........", "g......g" } }), 1)
	local corner = edge.board:get(1, 1)
	edge:_shoveSnail(wave(), corner, -1, 0)
	truthy(corner.snail)
	-- A 2-layer bale in the way takes a bite, and the snail stays put.
	local baled = Engine.new(snailLevel({ layout = { "........", "........", "........", "..O2....", "........", "........", "........", "g......g" } }), 1)
	local s2, bale = baled.board:get(3, 4), baled.board:get(4, 4)
	baled:_shoveSnail(wave(), s2, 1, 0)
	truthy(s2.snail)
	eq(bale.bale, 1)
	baled:_shoveSnail(wave(), s2, 1, 0)
	falsy(s2.snail)
	truthy(bale.snail, "the last bite clears it, so the snail crawls in")
	-- Into another snail or across a fence: no.
	local fenced = Engine.new(snailLevel({ fences = { { 3, 4, "R" } } }), 1)
	local s3 = fenced.board:get(3, 4)
	fenced:_shoveSnail(wave(), s3, 1, 0)
	truthy(s3.snail)
	truthy(fenced.board:get(4, 4).piece)
end)

test("matches shove snails, and snail levels replay the same", function()
	local level = snailLevel({ moves = 30 })
	local crawls = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			crawls += #effectsOf(phases, "Crawl")
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
		local snails = 0
		pop.board:eachCell(function(cell)
			if cell.snail then
				snails += 1
			end
		end)
		eq(snails, 2, "snails never vanish")
	end
	truthy(crawls > 0, "some snails crawled")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(snailLevel()), '"..O..O.."', 1, true))
end)
