-- Hen houses: nothing falls past one, and it drops tiles (every other one an Egg) into the empty cell below it.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng, Tiles = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng, CropPop.Tiles

local EGG = Tiles.ByName.Egg
local LAYOUT = { "........", "........", "........", "...h....", "........", "........", "........", "........" }

local function henLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Collect", tile = "Egg", count = 20 } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

test("a hen house blocks its column and feeds the cell below", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board:get(4, 4), nil)
	eq(#board.hens, 1)
	eq(board:cellBelow(4, 3), nil, "nothing falls past it")
	eq(board:cellAbove(4, 5), nil, "the cell below is fed by the hen house")
	truthy(board:isExit(board:get(4, 3)), "the cell above it is the bottom of its column")
	truthy(string.find(board:hash(), "H", 1, true))
end)

test("emptying the cell below the hen house fills it with an Egg, falling from the hen", function()
	local board = Board.fromLayout(LAYOUT)
	local rng = Rng.new(2)
	local colors = { 1, 2, 3, 4, 5 }
	board:fillInitial(rng, colors)
	for y = 5, 8 do
		board:get(4, y).piece = nil
	end
	local above = board:get(4, 3).piece
	local _, spawns = board:applyGravity(rng, colors)
	eq(board:get(4, 3).piece, above, "the column above stays put")
	local eggs = 0
	for _, sp in spawns do
		if sp.toX == 4 and sp.toY >= 5 then
			eggs += 1
			truthy(sp.fromY >= 4, "it comes out of the hen house")
		end
	end
	eq(eggs, 4, "one new tile per empty cell under it")
	local laidEggs = 0
	for y = 5, 8 do
		if board:get(4, y).piece.color == EGG then
			laidEggs += 1
		end
	end
	truthy(laidEggs >= 2, "every other one is an Egg")
end)

test("levels check their hen houses", function()
	eq(Levels.validate(henLevel()), nil)
	truthy(Levels.validate(henLevel({ colors = { "Tomato", "Carrot", "Corn", "Milk", "Wool" }, goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "no Egg colour")
	local bottom = table.clone(LAYOUT)
	bottom[8] = "...h...."
	truthy(Levels.validate(henLevel({ layout = bottom })), "nothing below it")
	truthy(Levels.validate(henLevel({ fences = { { 4, 4, "d" } } })), "a fence can't touch a hen house")
end)

test("a hen house level plays, refills fully and replays the same", function()
	local level = henLevel()
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 40 do
			local m = rng:pick(pop:listPossibleMoves())
			pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		pop.board:eachCell(function(cell)
			truthy(cell.piece ~= nil, "no gaps at " .. cell.x .. "," .. cell.y)
		end)
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	falsy(Engine.new(level, 1):canSwap(4, 3, 4, 4), "a hen house can't be swapped")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
end)
