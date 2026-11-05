-- Muddy pumpkins: a match next to one washes it; only then is it collected
-- from the bottom of its column. Blasts don't wash it.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board = CropPop.Levels, CropPop.Engine, CropPop.Board

local LAYOUT = { "........", "...o....", "........", "........", "........", "........", "........", "......o." }

local function muddyLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Pumpkins", count = 2 } }, moves = 30 })
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

local function rowAt(pop, y, x1)
	local cells = { pop.board:get(x1, y), pop.board:get(x1 + 1, y), pop.board:get(x1 + 2, y) }
	for _, cell in cells do
		cell.piece = pop.board:newPiece(pop.colors[1])
	end
	return { cells = cells, color = pop.colors[1] }
end

test("muddy pumpkins start as pumpkins, may sit on the bottom, and need a Pumpkins goal", function()
	eq(Levels.validate(muddyLevel()), nil)
	truthy(Levels.validate(muddyLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "no Pumpkins goal")
	truthy(Levels.validate(muddyLevel({ goals = { { kind = "Pumpkins", count = 1 } } })), "count below the muddy pumpkins")
	local pop = Engine.new(muddyLevel(), 1)
	local top, bottom = pop.board:get(4, 2).piece, pop.board:get(7, 8).piece
	truthy(top.pumpkin and top.muddy)
	truthy(bottom.pumpkin and bottom.muddy)
	truthy(Board.isMovable(pop.board:get(4, 2)), "it still swaps")
	truthy(string.find(pop.board:hash(), "Pm", 1, true))
	eq(pop.goals:find("Pumpkins").progress, 0)
end)

test("a muddy pumpkin on the bottom stays until a match next to it washes it", function()
	local pop = Engine.new(muddyLevel(), 2)
	local phases = {}
	pop:_settle(phases)
	truthy(pop.board:get(7, 8).piece.muddy, "settling doesn't collect it")
	eq(pop.goals:find("Pumpkins").progress, 0)
	local wave = newWave()
	pop:_popGroups(wave, { rowAt(pop, 7, 6) })
	local washed = false
	for _, e in wave.effects do
		washed = washed or (e.type == "Wash" and e.x == 7 and e.y == 8)
	end
	truthy(washed, "a Wash effect")
	falsy(pop.board:get(7, 8).piece.muddy)
	pop:_settle({})
	eq(pop.goals:find("Pumpkins").progress, 1)
end)

test("blasts don't wash a muddy pumpkin", function()
	local pop = Engine.new(muddyLevel(), 3)
	local wave = newWave()
	pop:_hit(wave, 4, 3)
	pop:_hit(wave, 4, 2)
	truthy(pop.board:get(4, 2).piece.muddy)
end)

test("a washed pumpkin hashes like a plain one", function()
	local pop = Engine.new(muddyLevel(), 4)
	pop.board:get(4, 2).piece.muddy = nil
	pop.board:get(7, 8).piece.muddy = nil
	falsy(string.find(pop.board:hash(), "Pm", 1, true))
end)
