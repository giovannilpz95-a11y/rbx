-- Mist: hides a cell's tile; a match on the cell or next to it lifts it,
-- blasts don't.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..Q..Q..", "........", "........", "........", "........", "........" }

local function mistLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Mist" } }, moves = 30 })
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

test("mist sits on a plain cell, its tile still moves, and it needs a Mist goal", function()
	local board = Board.fromLayout(LAYOUT)
	local cell = board:get(3, 3)
	truthy(cell.mist)
	eq(cell.bale, 0)
	eq(Levels.validate(mistLevel()), nil)
	truthy(Levels.validate(mistLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "mist without a goal")
	truthy(Levels.validate(mistLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without mist")
	local pop = Engine.new(mistLevel(), 1)
	truthy(Board.isMovable(pop.board:get(3, 3)), "the hidden tile still swaps")
	eq(pop.goals:find("Mist").target, 2)
	truthy(string.find(pop.board:hash(), "@", 1, true))
end)

test("a match on the cell or next to it lifts mist; blasts don't", function()
	local pop = Engine.new(mistLevel(), 2)
	local function rowAt(y)
		local cells = { pop.board:get(2, y), pop.board:get(3, y), pop.board:get(4, y) }
		for _, cell in cells do
			cell.piece = pop.board:newPiece(pop.colors[1])
		end
		return { cells = cells, color = pop.colors[1] }
	end
	pop:_hit(newWave(), 3, 3)
	truthy(pop.board:get(3, 3).mist, "a blast leaves it")
	local wave = newWave()
	pop:_popGroups(wave, { rowAt(4) })
	falsy(pop.board:get(3, 3).mist, "a match next to it lifts it")
	eq(pop.goals:find("Mist").progress, 1)
	local cells = { pop.board:get(5, 3), pop.board:get(6, 3), pop.board:get(7, 3) }
	for _, cell in cells do
		cell.piece = pop.board:newPiece(pop.colors[2])
	end
	pop:_popGroups(newWave(), { { cells = cells, color = pop.colors[2] } })
	falsy(pop.board:get(6, 3).mist, "a match on it lifts it")
	eq(pop.goals:find("Mist").progress, 2)
end)

test("mist levels play and replay the same", function()
	local level = mistLevel({ moves = 30 })
	local won = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		won += if pop.status == "Won" then 1 else 0
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(won > 0, "random play lifts all the mist sometimes")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(mistLevel()), '"..Q..Q.."', 1, true))
end)
