-- Snowballs: tiles with a timer; left alone, one bursts and frosts the tiles
-- around it, then starts again. Clearing one counts for the goal.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..i..i..", "........", "........", "........", "........", "........" }

local function snowLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Snowballs" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function phasesOf(phases, kind)
	local out = {}
	for _, phase in phases do
		if phase.kind == kind then
			table.insert(out, phase)
		end
	end
	return out
end

test("snowballs start with a timer, and the goal counts them", function()
	local pop = Engine.new(snowLevel(), 1)
	local cell = pop.board:get(3, 3)
	eq(cell.piece.timer, 8)
	truthy(Board.isMovable(cell))
	truthy(string.find(pop.board:hash(), "i8", 1, true))
	eq(pop.goals:find("Snowballs").target, 2)
	eq(Levels.validate(snowLevel()), nil)
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Snowballs" } } })), "snowballs goal without snowballs")
end)

test("timers tick each swap; at 0 a snowball frosts its neighbours and starts again", function()
	local pop = Engine.new(snowLevel({ moves = 60 }), 3)
	-- Any swap ticks every timer down by one.
	local m = pop:listPossibleMoves()[1]
	local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
	local ticks = phasesOf(phases, "Tick")
	eq(#ticks, 1)
	for _, t in ticks[1].timers do
		eq(t.timer, 7)
	end
	-- One about to burst.
	local cell
	pop.board:eachCell(function(c)
		if not cell and c.piece and c.piece.timer then
			cell = c
		end
	end)
	cell.piece.timer = 1
	phases = {}
	pop:_tickSnowballs(phases)
	local burst
	for _, t in phasesOf(phases, "Tick")[1].timers do
		if t.burst then
			burst = t
		end
	end
	truthy(burst)
	eq(burst.timer, 8)
	eq(cell.piece.timer, 8)
	local frosted, froze = 0, false
	for _, phase in phasesOf(phases, "Pop") do
		for _, e in phase.effects do
			froze = froze or e.type == "Freeze"
		end
		for _, f in phase.frost do
			frosted += 1
			truthy(math.abs(f.x - burst.x) <= 1 and math.abs(f.y - burst.y) <= 1)
			eq(pop.board:get(f.x, f.y).frost, 1)
		end
	end
	truthy(froze)
	truthy(frosted > 0)
	eq(cell.frost, 0)
end)

test("clearing a snowball counts, and snowball levels replay the same", function()
	local pop = Engine.new(snowLevel(), 2)
	local ok = pop:useBooster("Trowel", 3, 3)
	truthy(ok)
	eq(pop.goals:find("Snowballs").progress, 1)
	local level = snowLevel({ moves = 30 })
	for seed = 1, 4 do
		local a = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while a.status == "Playing" and #swaps < 30 do
			local m = rng:pick(a:listPossibleMoves())
			a:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), a:hash())
	end
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	falsy(Engine.new(Helpers.level(), 1).board.startSnowballs[1])
end)
