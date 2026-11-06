-- Apple trees: matches next to one do nothing; each blast on it shakes one
-- apple off, and the last leaves it bare and gone.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board = CropPop.Levels, CropPop.Engine, CropPop.Board

local LAYOUT = { "........", "........", "..$..$..", "........", "........", "........", "........", "........" }

local function treeLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Apples" } }, moves = 30 })
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

test("apple trees block a cell with 2 apples and need an Apples goal", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board:get(3, 3).tree, 2)
	eq(board:get(3, 3).bale, 1)
	eq(Levels.validate(treeLevel()), nil)
	truthy(Levels.validate(treeLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "trees without a goal")
	truthy(Levels.validate(treeLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without trees")
	local pop = Engine.new(treeLevel(), 1)
	eq(pop.goals:find("Apples").target, 4, "two apples a tree")
	truthy(string.find(pop.board:hash(), "$2", 1, true))
end)

test("matches next to a tree do nothing; each blast shakes an apple off", function()
	local pop = Engine.new(treeLevel(), 2)
	local cell = pop.board:get(3, 3)
	local color = pop.colors[1]
	local cells = { pop.board:get(2, 4), pop.board:get(3, 4), pop.board:get(4, 4) }
	for _, c in cells do
		c.piece = pop.board:newPiece(color)
	end
	pop:_popGroups(newWave(), { { cells = cells, color = color } })
	eq(cell.tree, 2, "a match leaves it")
	pop:_hit(newWave(), 3, 3)
	eq(cell.tree, 1)
	eq(pop.goals:find("Apples").progress, 1)
	local wave = newWave()
	pop:_hit(wave, 3, 3)
	falsy(cell.tree)
	eq(cell.bale, 0)
	eq(pop.goals:find("Apples").progress, 2)
	local bare = false
	for _, e in wave.effects do
		bare = bare or (e.type == "Tree" and e.x == 3 and e.y == 3)
	end
	truthy(bare, "a Tree effect")
end)

test("tree levels replay the same", function()
	local level = treeLevel()
	local a, b = Engine.new(level, 7), Engine.new(level, 7)
	for _ = 1, 10 do
		local moves = a:listPossibleMoves()
		if #moves == 0 or a.status ~= "Playing" then
			break
		end
		local m = moves[1]
		a:trySwap(m[1], m[2], m[3], m[4])
		b:trySwap(m[1], m[2], m[3], m[4])
		eq(a.board:hash(), b.board:hash())
	end
end)
