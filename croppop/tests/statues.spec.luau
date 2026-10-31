-- Buried statues: touching "b" cells make one statue; only blasts dig a cell up.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", ".bb.....", ".bb.....", "........", "........", "......b.", "......b.", "........" }

local function statueLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Statues" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

test("touching buried cells make one statue, and the goal counts statues", function()
	local board = Board.fromLayout(LAYOUT)
	eq(#board.statues, 2)
	eq(#board.statues[1].cells, 4)
	eq(board.statues[1].left, 4)
	eq(#board.statues[2].cells, 2)
	truthy(board:get(2, 2).buried)
	eq(board:get(3, 3).statue, board.statues[1])
	falsy(board:get(1, 1).buried)
	truthy(string.find(board:hash(), "^", 1, true))
	eq(Engine.new(statueLevel(), 1).goals:find("Statues").target, 2)
end)

test("levels check statues goals", function()
	eq(Levels.validate(statueLevel()), nil)
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Statues" } } })), "statues goal without statues")
end)

test("matches don't dig, blasts do, and the last cell finds the statue", function()
	-- A match on buried cells leaves them buried.
	local level = statueLevel({ moves = 60 })
	for seed = 1, 6 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		for _ = 1, 20 do
			if pop.status ~= "Playing" then
				break
			end
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			for _, phase in phases do
				for _, d in phase.statues or {} do
					-- Every dig comes in a wave with a blast (a power-up went off).
					local blast = false
					for _, r in phase.removed do
						blast = blast or r.cause == "power"
					end
					for _, e in phase.effects do
						blast = blast or e.type == "Spray" or e.type == "Bomb" or e.type == "Bee" or e.type == "Sun" or e.type == "Everything"
					end
					truthy(blast, "dug " .. d.x .. "," .. d.y .. " without a blast")
				end
			end
		end
	end
	-- The Trowel digs one cell at a time; the fourth finds the big statue.
	local pop = Engine.new(level, 3)
	local found = 0
	for i, at in { { 2, 2 }, { 3, 2 }, { 2, 3 }, { 3, 3 } } do
		local ok, phases = pop:useBooster("Trowel", at[1], at[2])
		truthy(ok)
		falsy(pop.board:get(at[1], at[2]).buried)
		for _, phase in phases do
			for _, e in phase.effects or {} do
				if e.type == "Statue" then
					found += 1
					eq(#e.cells, 4)
				end
			end
		end
		eq(found, if i == 4 then 1 else 0)
	end
	eq(pop.goals:find("Statues").progress, 1)
	eq(pop.board.statues[1].left, 0)
end)

test("a statue level replays the same, and the bot plays it", function()
	local level = statueLevel({ moves = 30 })
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
	truthy(string.find(CropPop.LevelText.write(statueLevel()), '".bb....."', 1, true))
end)
