-- Vines: hold a tile like a web, but a match next to one cuts it as well as
-- a blast; after a swap that cuts none, the vines creep onto another tile.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..Y..Y..", "........", "........", "........", "........", "........" }

local function vineLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Vines" } }, moves = 30 })
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

local function vineCount(pop)
	local n = 0
	pop.board:eachCell(function(cell)
		if cell.vine then
			n += 1
		end
	end)
	return n
end

test("vines hold a tile like a web and need a Vines goal", function()
	local board = Board.fromLayout(LAYOUT)
	local cell = board:get(3, 3)
	truthy(cell.vine)
	truthy(cell.web)
	falsy(Board.isMovable(cell), "the tile is held in place")
	eq(Levels.validate(vineLevel()), nil)
	truthy(Levels.validate(vineLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "vines without a goal")
	truthy(Levels.validate(vineLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without vines")
	local pop = Engine.new(vineLevel(), 1)
	eq(pop.goals:find("Vines").target, 2)
	falsy(pop.goals:find("Webs"), "vines aren't webs")
	truthy(string.find(pop.board:hash(), "'", 1, true))
end)

test("a match next to a vine cuts it once a wave, and so does a blast", function()
	local pop = Engine.new(vineLevel(), 2)
	local vine = pop.board:get(3, 3)
	local function rowAt(y)
		local cells = { pop.board:get(2, y), pop.board:get(3, y), pop.board:get(4, y) }
		for _, cell in cells do
			cell.piece = pop.board:newPiece(pop.colors[1])
		end
		return { cells = cells, color = pop.colors[1] }
	end
	local wave = newWave()
	pop:_popGroups(wave, { rowAt(4) })
	falsy(vine.vine)
	falsy(vine.web)
	truthy(vine.piece, "the tile stays")
	eq(pop.goals:find("Vines").progress, 1)
	eq(#wave.webs, 1)
	pop:_hit(newWave(), 6, 3)
	falsy(pop.board:get(6, 3).vine, "a blast cuts it")
	eq(pop.goals:find("Vines").progress, 2)
end)

test("vines creep after a swap that cuts none, and the goal grows with them", function()
	local level = vineLevel({ layout = { "Y.......", "........", "........", "........", "........", "........", "........", "........" } })
	local crept = false
	for seed = 1, 10 do
		local pop = Engine.new(level, seed)
		for _, m in pop:listPossibleMoves() do
			local x1, y1, x2, y2 = m[1], m[2], m[3], m[4]
			if x1 > 3 and x2 > 3 and y1 > 3 and y2 > 3 then
				local before = vineCount(pop)
				pop:trySwap(x1, y1, x2, y2)
				if pop.goals:find("Vines").progress == 0 then
					eq(vineCount(pop), before + 1)
					eq(pop.goals:find("Vines").target, 2)
					crept = true
				end
				break
			end
		end
		if crept then
			break
		end
	end
	truthy(crept, "a vine crept")
end)

test("vines stop creeping at a quarter of the board", function()
	local pop = Engine.new(vineLevel(), 3)
	for _ = 1, 40 do
		pop:_growVines({})
	end
	truthy(vineCount(pop) <= 16)
	eq(vineCount(pop), 16)
end)

test("vine levels play and replay the same", function()
	local level = vineLevel({ moves = 30 })
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(vineLevel()), '"..Y..Y.."', 1, true))
end)

test("bees go for vines on a Vines level", function()
	local pop = Engine.new(vineLevel(), 4)
	for _ = 1, 10 do
		truthy(pop:_chooseBeeTarget().vine)
	end
end)
