-- Berry bushes: every match next to one ripens it a stage; the third sends
-- 3 berries to the Berries goal and it grows again. Blasts don't ripen it.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board = CropPop.Levels, CropPop.Engine, CropPop.Board

local LAYOUT = { "........", "........", "..*..*..", "........", "........", "........", "........", "........" }

local function bushLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Berries", count = 6 } }, moves = 30 })
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

local function matchUnder(pop)
	local color = pop.colors[1]
	local cells = { pop.board:get(2, 4), pop.board:get(3, 4), pop.board:get(4, 4) }
	for _, c in cells do
		c.piece = pop.board:newPiece(color)
	end
	local wave = newWave()
	pop:_popGroups(wave, { { cells = cells, color = color } })
	return wave
end

test("berry bushes block a cell and need a Berries goal with a count", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board:get(3, 3).bush, 0)
	eq(board:get(3, 3).bale, 1)
	eq(Levels.validate(bushLevel()), nil)
	truthy(Levels.validate(bushLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "bushes without a goal")
	truthy(Levels.validate(bushLevel({ goals = { { kind = "Berries" } } })), "a goal without a count")
	truthy(Levels.validate(bushLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without bushes")
	local pop = Engine.new(bushLevel(), 1)
	eq(pop.goals:find("Berries").target, 6)
	truthy(string.find(pop.board:hash(), "B0", 1, true))
end)

test("three matches next to a bush send 3 berries, and it grows again", function()
	local pop = Engine.new(bushLevel(), 2)
	local cell = pop.board:get(3, 3)
	matchUnder(pop)
	eq(cell.bush, 1)
	matchUnder(pop)
	eq(cell.bush, 2)
	eq(pop.goals:find("Berries").progress, 0)
	local wave = matchUnder(pop)
	eq(cell.bush, 0, "it starts again")
	eq(cell.bale, 1, "and stays")
	eq(pop.goals:find("Berries").progress, 3)
	local picked = false
	for _, e in wave.effects do
		picked = picked or (e.type == "Berries" and e.x == 3 and e.y == 3 and e.count == 3)
	end
	truthy(picked, "a Berries effect")
end)

test("blasts don't ripen a bush", function()
	local pop = Engine.new(bushLevel(), 3)
	local cell = pop.board:get(3, 3)
	pop:_hit(newWave(), 3, 3)
	eq(cell.bush, 0)
	eq(cell.bale, 1)
	falsy(pop.goals:isComplete())
end)

test("bush levels replay the same", function()
	local level = bushLevel()
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
