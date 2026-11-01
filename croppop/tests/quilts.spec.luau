-- Quilts and sewing tins: an opened tin sends a patch to a quilt; the last
-- patch finishes the quilt and frees its cells. Nothing breaks a quilt.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

-- One 2x2 quilt in the middle, one 2x1 quilt at the bottom, six tins.
local LAYOUT = { "........", ".k....k.", "........", "...qq...", "...qq...", ".k....k.", "........", "k..qq..k" }

local function quiltLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Quilts" } }, moves = 40 })
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

test("touching quilt cells make one quilt, and the goal counts quilts", function()
	local board = Board.fromLayout(LAYOUT)
	eq(#board.quilts, 2)
	eq(#board.quilts[1].cells, 4)
	eq(board.quilts[1].left, 4)
	eq(board.quilts[2].left, 2)
	eq(board:get(4, 5).quilt, board.quilts[1])
	truthy(board:get(2, 2).tin)
	eq(board:get(2, 2).bale, 1)
	truthy(string.find(board:hash(), "Q", 1, true))
	truthy(string.find(board:hash(), "K", 1, true))
	local pop = Engine.new(quiltLevel(), 1)
	eq(pop.goals:find("Quilts").target, 2)
	-- Tins and quilts aren't hay bales.
	eq(Engine.new(quiltLevel({ goals = { { kind = "Quilts" }, { kind = "Collect", tile = "Tomato", count = 5 } } }), 1).goals:find("HayBale"), nil)
end)

test("levels check quilts goals and that there are enough tins", function()
	eq(Levels.validate(quiltLevel()), nil)
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Quilts" } } })), "quilts goal without quilts")
	local short = table.clone(LAYOUT)
	short[2] = "........"
	short[8] = "...qq..."
	truthy(Levels.validate(quiltLevel({ layout = short })), "2 tins for 6 quilt cells")
end)

test("blasts don't break a quilt; each opened tin patches the emptiest quilt", function()
	local pop = Engine.new(quiltLevel(), 2)
	-- A Trowel can't be used on a quilt.
	falsy((pop:useBooster("Trowel", 4, 4)))
	local function open(x, y)
		local wave = { bales = {}, effects = {}, quilts = {} }
		pop:_damageBale(wave, pop.board:get(x, y))
		return { wave }
	end
	-- Nothing breaks a quilt cell.
	eq(#open(4, 4)[1].bales, 0)
	eq(pop.board:get(4, 4).bale, 1)
	-- The first tin patches the small quilt (fewest missing), the second
	-- finishes it, and it lifts off.
	local phases = open(2, 2)
	falsy(pop.board:get(2, 2).tin)
	eq(pop.board:get(2, 2).bale, 0)
	local patch = effectsOf(phases, "Patch")
	eq(#patch, 1)
	eq(patch[1].fromX, 2)
	eq(patch[1].y, 8)
	truthy(pop.board:get(4, 8).patched)
	eq(#effectsOf(phases, "Quilt"), 0)
	phases = open(7, 2)
	local done = effectsOf(phases, "Quilt")
	eq(#done, 1)
	eq(#done[1].cells, 2)
	eq(pop.board:get(5, 8).quilt, nil)
	eq(pop.board:get(5, 8).bale, 0)
	eq(pop.goals:find("Quilts").progress, 1)
	-- The big quilt is next: four tins finish it.
	for _, at in { { 2, 6 }, { 7, 6 }, { 1, 8 } } do
		eq(#effectsOf(open(at[1], at[2]), "Quilt"), 0)
	end
	eq(pop.board.quilts[1].left, 1)
	eq(#effectsOf(open(8, 8), "Quilt"), 1)
	eq(pop.board.quilts[1].left, 0)
	eq(pop.board:get(4, 4).bale, 0)
	eq(pop.goals:find("Quilts").progress, 2)
	truthy(pop.goals:isComplete())
end)

test("a Trowel on a tin opens it", function()
	local pop = Engine.new(quiltLevel(), 3)
	local ok, phases = pop:useBooster("Trowel", 2, 2)
	truthy(ok)
	falsy(pop.board:get(2, 2).tin)
	truthy(#effectsOf(phases, "Patch") >= 1)
end)

test("a match next to a tin opens it, and quilt levels replay the same", function()
	local level = quiltLevel({ moves = 30 })
	local opened = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			opened += #effectsOf(phases, "Patch")
			table.insert(swaps, m)
		end
		-- Quilt cells never broke except by finishing.
		for _, quilt in pop.board.quilts do
			for _, cell in quilt.cells do
				eq(cell.bale, if quilt.left > 0 then 1 else 0)
			end
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(opened > 0, "matches opened some tins")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(quiltLevel()), '"...qq..."', 1, true))
end)
