-- Fruit cages: hold a block of tiles like a web; matches next to a peg or
-- blasts on it pull the peg, and the last peg lifts the whole cage.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Matcher = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Matcher

local LAYOUT = { "........", "........", "..+=+...", "..===...", "..+=+...", "........", "........", "........" }

local function cageLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Cages" } }, moves = 30 })
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

test("a cage is one connected block with pegs, holds its tiles, and needs a Cages goal", function()
	local board = Board.fromLayout(LAYOUT)
	eq(#board.cages, 1)
	eq(board.cages[1].pegs, 4)
	eq(#board.cages[1].cells, 9)
	truthy(board:get(3, 3).peg)
	falsy(board:get(4, 3).peg)
	truthy(board:get(4, 4).web and board:get(4, 4).cage)
	eq(Levels.validate(cageLevel()), nil)
	truthy(Levels.validate(cageLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "a cage without a goal")
	truthy(Levels.validate(cageLevel({ layout = { "........", "........", "..===...", "........", "........", "........", "........", "........" } })), "a cage without pegs")
	local pop = Engine.new(cageLevel(), 1)
	eq(pop.goals:find("Cages").target, 1)
	falsy(pop.goals:find("Webs"), "cages aren't webs")
	falsy(Board.isMovable(pop.board:get(4, 4)), "a caged tile doesn't move")
	truthy(string.find(pop.board:hash(), "=+", 1, true))
end)

test("blasts on the cage do nothing except at a peg; matches next to a peg pull it", function()
	local pop = Engine.new(cageLevel(), 2)
	local cage = pop.board.cages[1]
	pop:_hit(newWave(), 4, 4)
	truthy(pop.board:get(4, 4).cage, "a blast in the middle leaves the cage")
	eq(cage.pegs, 4)
	pop:_hit(newWave(), 3, 3)
	falsy(pop.board:get(3, 3).peg)
	eq(cage.pegs, 3)
	-- A match in row 6 next to the bottom pegs at (3, 5) and (5, 5).
	local color = pop.colors[1]
	local cells = { pop.board:get(3, 6), pop.board:get(4, 6), pop.board:get(5, 6) }
	for _, c in cells do
		c.piece = pop.board:newPiece(color)
	end
	pop:_popGroups(newWave(), { { cells = cells, color = color } })
	eq(cage.pegs, 1)
	truthy(pop.board:get(4, 4).cage, "still caged with a peg left")
	local wave = newWave()
	pop:_hit(wave, 5, 3)
	eq(cage.pegs, 0)
	for y = 3, 5 do
		for x = 3, 5 do
			local cell = pop.board:get(x, y)
			falsy(cell.cage)
			falsy(cell.web)
		end
	end
	eq(pop.goals:find("Cages").progress, 1)
	local lifted = false
	for _, e in wave.effects do
		lifted = lifted or (e.type == "Cage" and #e.cells == 9)
	end
	truthy(lifted, "a Cage effect")
	truthy(Board.isMovable(pop.board:get(4, 4)), "the tiles are free")
end)

test("cage levels replay the same", function()
	local level = cageLevel()
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
