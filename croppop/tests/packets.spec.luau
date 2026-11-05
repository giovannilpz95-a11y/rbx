-- Seed packets: hold 4 seeds of one colour; a match of that colour next to
-- one (once per wave) or a blast takes a seed, and the last empties it.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..K..K..", "........", "........", "........", "........", "........" }

local function packetLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Packets" } }, moves = 30 })
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

local function effectsOf(phases, kind)
	local out = {}
	for _, phase in phases do
		for _, e in phase.effects or {} do
			if e.type == kind then
				table.insert(out, e)
			end
		end
	end
	return out
end

test("seed packets block a cell, take the level's colours in turn and need a Packets goal", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(3, 3).packet)
	eq(board:get(3, 3).bale, 1)
	eq(Levels.validate(packetLevel()), nil)
	truthy(Levels.validate(packetLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "packets without a goal")
	truthy(Levels.validate(packetLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without packets")
	local pop = Engine.new(packetLevel(), 1)
	local a, b = pop.board:get(3, 3), pop.board:get(6, 3)
	eq(a.packet, 4)
	eq(a.packetColor, pop.colors[1])
	eq(b.packetColor, pop.colors[2])
	eq(pop.goals:find("Packets").target, 2)
	falsy(pop.goals:find("HayBale"), "packets aren't hay bales")
	truthy(string.find(pop.board:hash(), "A4c", 1, true))
end)

test("only a match of the packet's colour takes a seed, once a wave; blasts take one too", function()
	local pop = Engine.new(packetLevel(), 2)
	local packet = pop.board:get(3, 3)
	local color = packet.packetColor
	local other = if pop.colors[1] == color then pop.colors[2] else pop.colors[1]
	local function row(c)
		local cells = { pop.board:get(2, 4), pop.board:get(3, 4), pop.board:get(4, 4) }
		for _, cell in cells do
			cell.piece = pop.board:newPiece(c)
		end
		return { cells = cells, color = c }
	end
	local wave = newWave()
	pop:_popGroups(wave, { row(other) })
	eq(packet.packet, 4, "another colour does nothing")
	pop:_popGroups(wave, { row(color) })
	eq(packet.packet, 3)
	pop:_popGroups(wave, { row(color) })
	eq(packet.packet, 3, "once per wave")
	pop:_hit(newWave(), 3, 3)
	eq(packet.packet, 2, "a blast takes a seed")
	local goal = pop.goals:find("Packets")
	local last = newWave()
	pop:_hit(last, 3, 3)
	pop:_hit(last, 3, 3)
	eq(goal.progress, 1)
	eq(packet.bale, 0)
	falsy(packet.packet)
	eq(#effectsOf({ last }, "Packet"), 1)
end)

test("packets empty in play, and packet levels replay the same", function()
	local level = packetLevel({ moves = 30 })
	local emptied = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			emptied += #effectsOf(phases, "Packet")
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(emptied > 0, "some packets emptied")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(packetLevel()), '"..K..K.."', 1, true))
end)

test("bees go for seed packets on a Packets level", function()
	local pop = Engine.new(packetLevel(), 4)
	for _ = 1, 10 do
		truthy(pop:_chooseBeeTarget().packet)
	end
end)
