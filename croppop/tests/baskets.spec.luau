-- Pumpkin baskets: matches next to them and blasts on them drop pumpkins into the cell below.

local eq, truthy = expect.eq, expect.truthy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "...d....", "........", "........", "........", "........", "........", "........", "........" }

local function basketLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Pumpkins", count = 3 } } })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

-- Plays random moves; returns the engine, its swaps and every phase.
local function play(level, seed, maxMoves)
	local pop = Engine.new(level, seed)
	local rng = Rng.new(seed)
	local swaps, phases = {}, {}
	while pop.status == "Playing" and #swaps < maxMoves do
		local m = rng:pick(pop:listPossibleMoves())
		local _, out = pop:trySwap(m[1], m[2], m[3], m[4])
		table.insert(swaps, m)
		for _, phase in out do
			table.insert(phases, phase)
		end
	end
	return pop, swaps, phases
end

test("a basket is not a cell, and pieces fall past it", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board:get(4, 1), nil)
	local basket = board:basket(4, 1)
	truthy(basket)
	eq(basket.waiting, 0)
	eq(#board.baskets, 1)
	eq(board:basket(3, 1), nil)
	-- Column 4 spawns into its first real cell.
	board:fillInitial(Rng.new(1), { 1, 2, 3, 4, 5 })
	truthy(board:get(4, 2).piece)
	truthy(string.find(board:hash(), "D0", 1, true))
end)

test("levels check their baskets", function()
	eq(Levels.validate(basketLevel()), nil)
	truthy(Levels.validate(basketLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "no pumpkins goal")
	local bottom = table.clone(LAYOUT)
	bottom[8] = "...d...."
	truthy(Levels.validate(basketLevel({ layout = bottom })), "nothing below it")
	truthy(Levels.validate(basketLevel({ portals = { { from = { 4, 1 }, to = { 4, 5 } } } })), "a portal can't start in a basket")
end)

test("a match next to the basket drops a pumpkin below it, and refills drop none", function()
	local level = basketLevel({ moves = 60 })
	local released, spawned = 0, 0
	for seed = 1, 6 do
		local _, _, phases = play(level, seed, 60)
		for _, phase in phases do
			if phase.kind == "Pop" then
				for _, e in phase.effects do
					if e.type == "Basket" then
						released += 1
						eq(e.fromX, 4)
						eq(e.toX, 4)
						eq(e.toY, 2)
					end
				end
				for _, c in phase.created do
					if c.piece.pumpkin then
						eq(c.x, 4)
						eq(c.y, 2)
					end
				end
			elseif phase.kind == "Drop" then
				for _, sp in phase.spawns do
					if sp.piece.pumpkin then
						spawned += 1
					end
				end
			end
		end
	end
	truthy(released > 0, "the basket released pumpkins")
	eq(spawned, 0, "refills drop no pumpkins on basket levels")
end)

test("baskets stop once the goal has enough pumpkins, and the level can be won", function()
	local level = basketLevel({ moves = 200, goals = { { kind = "Pumpkins", count = 2 } } })
	local wins = 0
	for seed = 1, 8 do
		local pop, _, phases = play(level, seed, 200)
		local released = 0
		for _, phase in phases do
			for _, e in phase.effects or {} do
				if e.type == "Basket" then
					released += 1
				end
			end
		end
		truthy(released <= 2, "no more than the goal needs")
		if pop.status == "Won" then
			wins += 1
		end
	end
	truthy(wins > 0)
end)

test("a blast on the basket shakes it too", function()
	local pop = Engine.new(basketLevel(), 4)
	local wave = {
		removed = {}, created = {}, transformed = {}, bales = {}, mud = {}, frost = {}, clover = {},
		effects = {}, queue = {}, spread = false, pendingCreates = {}, balesTouched = {}, basketsHit = {},
	}
	pop:_hit(wave, 4, 1)
	eq(pop.board:basket(4, 1).waiting, 1)
	pop:_hit(wave, 4, 1)
	eq(pop.board:basket(4, 1).waiting, 1, "once per wave")
end)

test("a basket level replays the same", function()
	local level = basketLevel({ moves = 40 })
	for seed = 1, 4 do
		local pop, swaps = play(level, seed, 40)
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
end)

test("the bot plays basket levels and level text keeps the basket", function()
	local report = CropPop.Bot.play(basketLevel({ moves = 30 }), 6, 1)
	eq(report.games, 6)
	local text = CropPop.LevelText.write(basketLevel())
	truthy(string.find(text, '"...d...."', 1, true), text)
end)
