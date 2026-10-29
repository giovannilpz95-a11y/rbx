-- Gravity, refills, holes, hay bales and shuffles.

local eq, truthy = expect.eq, expect.truthy
local Board, Rng, Matcher = CropPop.Board, CropPop.Rng, CropPop.Matcher

local function filled(layout, color)
	local board = Board.fromLayout(layout)
	board:eachCell(function(cell)
		if cell.bale == 0 then
			cell.piece = board:newPiece(color or 1)
		end
	end)
	return board
end

test("pieces fall through holes and new ones spawn at the top", function()
	local board = filled({ ".", "#", ".", "." })
	local topId = board:get(1, 1).piece.id
	board:get(1, 4).piece = nil
	local moves, spawns = board:applyGravity(Rng.new(1), { 2 })
	eq(#spawns, 1)
	eq(spawns[1].toY, 1)
	eq(spawns[1].fromY, 0)
	eq(board:get(1, 3).piece.id, topId)
	local fromTop
	for _, m in moves do
		if m.id == topId then
			fromTop = m
		end
	end
	eq(fromTop.fromY, 1)
	eq(fromTop.toY, 3)
	eq(Helpers.emptySlots(board), 0)
end)

test("a cell under a hay bale is filled from the side", function()
	local board = filled({ ".1.", "...", "..." })
	board:get(2, 2).piece = nil
	board:get(2, 3).piece = nil
	board:applyGravity(Rng.new(1), { 2 })
	eq(Helpers.emptySlots(board), 0)
	eq(board:get(2, 1).bale, 1)
end)

test("cells sealed under bales stay empty", function()
	local board = filled({ "111", "..." })
	for x = 1, 3 do
		board:get(x, 2).piece = nil
	end
	local moves, spawns = board:applyGravity(Rng.new(1), { 2 })
	eq(#moves + #spawns, 0)
	eq(Helpers.emptySlots(board), 3)
end)

test("several spawns in one column stack above the board", function()
	local board = filled({ "..", "..", ".." })
	for y = 1, 3 do
		board:get(1, y).piece = nil
	end
	local _, spawns = board:applyGravity(Rng.new(5), { 1, 2, 3 })
	eq(#spawns, 3)
	local starts = {}
	for _, s in spawns do
		starts[s.fromY] = s.toY
	end
	-- Spawned in order: first lands lowest.
	eq(starts[0], 3)
	eq(starts[-1], 2)
	eq(starts[-2], 1)
end)

test("a fresh board has no matches and at least one move", function()
	for seed = 1, 200 do
		local board = Board.fromLayout({ "......", "......", "......", "......", "......", "......" })
		board:fillInitial(Rng.new(seed), { 1, 2, 3, 4 })
		eq(#Matcher.findGroups(board, {}), 0, "seed " .. seed)
		truthy(Matcher.hasPossibleMove(board), "seed " .. seed)
	end
end)

test("shuffle leaves a playable board with the same pieces", function()
	local board = Board.fromLayout({ "....", "....", "...." })
	board:fillInitial(Rng.new(3), { 1, 2, 3 })
	local before = {}
	board:eachCell(function(cell)
		before[cell.piece.id] = true
	end)
	local moves = board:shuffle(Rng.new(9), { 1, 2, 3 })
	eq(#moves, 12)
	board:eachCell(function(cell)
		truthy(before[cell.piece.id])
	end)
	eq(#Matcher.findGroups(board, {}), 0)
	truthy(Matcher.hasPossibleMove(board))
end)

test("rng is deterministic and stays in range", function()
	local a, b = Rng.new(1234), Rng.new(1234)
	for _ = 1, 1000 do
		local n = a:int(1, 6)
		eq(n, b:int(1, 6))
		truthy(n >= 1 and n <= 6)
	end
	truthy(Rng.new(1):nextU32() ~= Rng.new(2):nextU32())
	truthy(Rng.new(0).state ~= 0)
end)
