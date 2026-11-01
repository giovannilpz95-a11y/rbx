-- Rainbow patches: after every swap the plain tile on one changes colour, never into a match.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng, Matcher = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng, CropPop.Matcher

local LAYOUT = { "........", "........", "..r..r..", "........", "........", "..r..r..", "........", "........" }

local function rainbowLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, moves = 30 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

test("the layout marks rainbow patches", function()
	local board = Board.fromLayout(LAYOUT)
	truthy(board:get(3, 3).rainbow)
	falsy(board:get(1, 1).rainbow)
	truthy(board.hasRainbow)
	truthy(string.find(board:hash(), "~", 1, true))
	eq(Levels.validate(rainbowLevel()), nil)
end)

test("after a swap, tiles on patches change colour without making a match", function()
	local changed = 0
	for seed = 1, 6 do
		local pop = Engine.new(rainbowLevel(), seed)
		local rng = Rng.new(seed)
		for _ = 1, 10 do
			if pop.status ~= "Playing" then
				break
			end
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			for _, phase in phases do
				if phase.kind == "Recolor" then
					for _, c in phase.changes do
						changed += 1
						truthy(pop.board:get(c.x, c.y).rainbow)
					end
				end
			end
			eq(#Matcher.findGroups(pop.board, {}), 0, "no match left on the board")
		end
	end
	truthy(changed > 0)
end)

test("boosters don't recolour, and rainbow levels replay the same", function()
	local pop = Engine.new(rainbowLevel(), 4)
	local before = pop.board:get(3, 3).piece.color
	local _, phases = pop:useBooster("Trowel", 8, 8)
	for _, phase in phases do
		truthy(phase.kind ~= "Recolor")
	end
	local level = rainbowLevel()
	for seed = 1, 4 do
		local run = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while run.status == "Playing" and #swaps < 30 do
			local m = rng:pick(run:listPossibleMoves())
			run:trySwap(m[1], m[2], m[3], m[4])
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), run:hash())
	end
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(before ~= nil)
end)
