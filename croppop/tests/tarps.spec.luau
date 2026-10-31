-- Tarps: a row of covered cells that matches and blasts roll up from the right end.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "........", "..tttt..", "........", "........", ".tt.....", "........" }

local function tarpLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Tarps" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function rolls(phases)
	local out = {}
	for _, phase in phases do
		for _, b in phase.bales or {} do
			if b.tarp then
				table.insert(out, b)
			end
		end
	end
	return out
end

test("touching tarp cells in a row make one tarp that blocks like a bale", function()
	local board = Board.fromLayout(LAYOUT)
	eq(#board.tarps, 2)
	eq(#board.tarps[1].cells, 4)
	eq(board.tarps[1].cells[4], board:get(6, 4))
	eq(board:get(3, 4).bale, 1)
	eq(board:get(3, 4).tarp, board.tarps[1])
	truthy(string.find(board:hash(), "T", 1, true))
	local pop = Engine.new(tarpLevel(), 1)
	eq(pop.goals:find("Tarps").target, 6)
	eq(Levels.validate(tarpLevel()), nil)
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Tarps" } } })), "tarps goal without tarps")
	truthy(Levels.validate(tarpLevel({ goals = { { kind = "HayBale" } } })), "tarps aren't hay bales")
end)

test("a blast anywhere on a tarp rolls it up from the right end", function()
	local pop = Engine.new(tarpLevel(), 2)
	local ok, phases = pop:useBooster("Trowel", 3, 4)
	truthy(ok)
	local r = rolls(phases)
	eq(#r, 1)
	eq(r[1].x, 6)
	eq(r[1].y, 4)
	eq(pop.board:get(6, 4).bale, 0)
	eq(pop.board:get(3, 4).bale, 1, "the hit cell stays covered")
	eq(pop.board.tarps[1].left, 3)
	eq(pop.goals:find("Tarps").progress, 1)
	-- The next roll uncovers the next cell along.
	pop:useBooster("Trowel", 4, 4)
	falsy(pop.board:get(5, 4).tarp)
	truthy(pop.board:get(4, 4).tarp)
end)

test("a match rolls a tarp once per wave, and tarp levels replay the same", function()
	local level = tarpLevel()
	local rolled = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 40 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			for _, phase in phases do
				if phase.kind == "Pop" then
					local perTarp = {}
					local blast = false
					for _, e in phase.effects do
						blast = blast or e.type == "Spray" or e.type == "Bomb" or e.type == "Bee" or e.type == "Sun" or e.type == "Everything"
					end
					for _, b in phase.bales do
						if b.tarp then
							rolled += 1
							perTarp[b.y] = (perTarp[b.y] or 0) + 1
						end
					end
					if not blast then
						for _, n in perTarp do
							eq(n, 1, "one roll per tarp per wave from matches")
						end
					end
				end
			end
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(rolled > 0)
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
end)
