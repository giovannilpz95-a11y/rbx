-- Tool chests: locked until a blast opens them; then each match next to one
-- (once per wave) or blast on it takes one of its 3 tools.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..X..X..", "........", "........", "........", "........", "........" }

local function chestLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Tools" } }, moves = 30 })
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

test("tool chests block a cell locked, hold 3 tools each and need a Tools goal", function()
	local board = Board.fromLayout(LAYOUT)
	eq(board:get(3, 3).chest, 3)
	falsy(board:get(3, 3).chestOpen)
	eq(board:get(3, 3).bale, 1)
	eq(Levels.validate(chestLevel()), nil)
	truthy(Levels.validate(chestLevel({ goals = { { kind = "Collect", tile = "Tomato", count = 5 } } })), "chests without a goal")
	truthy(Levels.validate(chestLevel({ layout = { "........", "........", "........", "........", "........", "........", "........", "........" } })), "a goal without chests")
	local pop = Engine.new(chestLevel(), 1)
	eq(pop.goals:find("Tools").target, 6)
	falsy(pop.goals:find("HayBale"), "chests aren't hay bales")
	truthy(string.find(pop.board:hash(), "S3", 1, true))
end)

test("matches don't touch a locked chest; a blast opens it, then matches take tools once a wave", function()
	local pop = Engine.new(chestLevel(), 2)
	local chest = pop.board:get(3, 3)
	local function row(c)
		local cells = { pop.board:get(2, 4), pop.board:get(3, 4), pop.board:get(4, 4) }
		for _, cell in cells do
			cell.piece = pop.board:newPiece(c)
		end
		return { cells = cells, color = c }
	end
	pop:_popGroups(newWave(), { row(pop.colors[1]) })
	falsy(chest.chestOpen, "a match doesn't open it")
	eq(chest.chest, 3)
	local opening = newWave()
	pop:_hit(opening, 3, 3)
	truthy(chest.chestOpen)
	eq(chest.chest, 3, "opening takes no tool")
	eq(#effectsOf({ opening }, "ChestOpen"), 1)
	local goal = pop.goals:find("Tools")
	local wave = newWave()
	pop:_popGroups(wave, { row(pop.colors[1]) })
	eq(chest.chest, 2)
	eq(goal.progress, 1)
	pop:_popGroups(wave, { row(pop.colors[2]) })
	eq(chest.chest, 2, "once per wave")
	pop:_hit(newWave(), 3, 3)
	eq(chest.chest, 1, "a blast takes a tool")
	local last = newWave()
	pop:_popGroups(last, { row(pop.colors[3]) })
	eq(goal.progress, 3)
	falsy(chest.chest)
	eq(chest.bale, 0)
	eq(#effectsOf({ last }, "Tool"), 1)
end)

test("chests empty in play, and chest levels replay the same", function()
	local level = chestLevel({ moves = 30 })
	local tools = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
			tools += #effectsOf(phases, "Tool")
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(tools > 0, "some tools taken")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(chestLevel()), '"..X..X.."', 1, true))
end)

test("bees go for tool chests on a Tools level", function()
	local pop = Engine.new(chestLevel(), 4)
	for _ = 1, 10 do
		truthy(pop:_chooseBeeTarget().chest)
	end
end)
