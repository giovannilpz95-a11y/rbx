-- Stew pots: each hit knocks a layer off; a swap that misses a pot makes
-- it puff steam (mist) onto a plain tile next to it.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board = CropPop.Levels, CropPop.Engine, CropPop.Board

local LAYOUT = { "........", "........", "..&..&..", "........", "........", "........", "........", "........" }

local function potLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Pots" } }, moves = 30 })
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

local function mistCount(board)
	local n = 0
	board:eachCell(function(cell)
		if cell.mist then
			n += 1
		end
	end)
	return n
end

test("stew pots block a cell with 2 layers and need a Pots goal", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(3, 3).pot)
	eq(board:get(3, 3).bale, 2)
	eq(Levels.validate(potLevel()), nil)
	truthy(Levels.validate(potLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "pots without a goal")
	truthy(Levels.validate(potLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without pots")
	local pop = Engine.new(potLevel(), 1)
	eq(pop.goals:find("Pots").target, 2)
	truthy(string.find(pop.board:hash(), "&2", 1, true))
end)

test("matches and blasts knock a layer off; the last takes the pot off the boil", function()
	local pop = Engine.new(potLevel(), 2)
	local cell = pop.board:get(3, 3)
	local color = pop.colors[1]
	local cells = { pop.board:get(2, 4), pop.board:get(3, 4), pop.board:get(4, 4) }
	for _, c in cells do
		c.piece = pop.board:newPiece(color)
	end
	pop:_popGroups(newWave(), { { cells = cells, color = color } })
	eq(cell.bale, 1, "a match next to it")
	local wave = newWave()
	pop:_hit(wave, 3, 3)
	falsy(cell.pot)
	eq(cell.bale, 0)
	eq(pop.goals:find("Pots").progress, 1)
	local done = false
	for _, e in wave.effects do
		done = done or (e.type == "Pot" and e.x == 3 and e.y == 3)
	end
	truthy(done, "a Pot effect")
end)

test("a pot missed by a swap puffs mist next to it; a hit pot doesn't", function()
	local pop = Engine.new(potLevel(), 3)
	pop:_hit(newWave(), 3, 3) -- hit the left pot this swap
	local phases = {}
	pop:_steamPots(phases)
	eq(mistCount(pop.board), 1, "only the missed pot steams")
	local steam
	for _, p in phases do
		for _, e in p.effects or {} do
			if e.type == "Steam" then
				steam = e
			end
		end
	end
	truthy(steam, "a Steam effect")
	eq(steam.fromX, 6)
	eq(math.abs(steam.x - 6) + math.abs(steam.y - 3), 1, "next to the pot")
	truthy(pop.board:get(steam.x, steam.y).mist)
	pop:_steamPots({})
	eq(mistCount(pop.board), 3, "both pots steam on the next missed swap")
end)

test("steam stops at a quarter of the board and adds to a Mist goal", function()
	local pop = Engine.new(potLevel({ goals = { { kind = "Pots" }, { kind = "Mist", count = 1 } } }), 4)
	eq(pop.goals:find("Mist").target, 1)
	for _ = 1, 40 do
		pop:_steamPots({})
	end
	-- Only the cells next to the two pots can steam: 8 of them, under the 16-cell cap.
	eq(mistCount(pop.board), 8)
	eq(pop.goals:find("Mist").target, 9)
end)

test("pot levels replay the same", function()
	local level = potLevel()
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
