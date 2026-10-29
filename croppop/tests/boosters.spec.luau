-- In-level and pre-level boosters in the engine and the replay.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local engine, phase, removedAt = Helpers.engine, Helpers.phase, Helpers.removedAt
local Engine, Levels, Replay, Rng = CropPop.Engine, CropPop.Levels, CropPop.Replay, CropPop.Rng

local X8 = "x x x x x x x x"
local function rows(top)
	local out = table.clone(top)
	while #out < 8 do
		table.insert(out, X8)
	end
	return out
end

test("Trowel breaks one tile without using a move", function()
	local pop = engine(nil, rows({}))
	local ok, phases = pop:useBooster("Trowel", 4, 4)
	truthy(ok)
	local set, count = removedAt(phase(phases, "Pop"))
	eq(count, 1)
	truthy(set["4,4"])
	eq(pop.movesLeft, 30)
	eq(pop.boostersUsed.Trowel, 1)
end)

test("Trowel on a power-up sets it off", function()
	local pop = engine(nil, rows({ X8, "1r x x x x x x x" }))
	local _, phases = pop:useBooster("Trowel", 1, 2)
	local set = removedAt(phase(phases, "Pop"))
	truthy(set["8,2"], "the sprayer cleared its row")
end)

test("Trowel knocks one layer off a hay bale", function()
	local pop = engine({
		layout = { "........", "........", "........", "........", "........", "........", "........", "...2...." },
		goals = { { kind = "HayBale" } },
	}, rows({ X8, X8, X8, X8, X8, X8, X8, "x x x B2 x x x x" }))
	pop:useBooster("Trowel", 4, 8)
	eq(pop.board:get(4, 8).bale, 1)
	falsy(pop:useBooster("Trowel", 0, 0))
end)

test("Rake clears a row", function()
	local pop = engine(nil, rows({}))
	local ok, phases = pop:useBooster("Rake", 5)
	truthy(ok)
	local set, count = removedAt(phase(phases, "Pop"))
	eq(count, 8)
	truthy(set["1,5"] and set["8,5"])
	falsy(pop:useBooster("Rake", 9))
end)

test("Garden Gloves swap two tiles even without a match", function()
	local pop = engine(nil, rows({}))
	local a, b = pop.board:get(1, 1).piece.id, pop.board:get(2, 1).piece.id
	local ok, phases = pop:useBooster("GardenGloves", 1, 1, 2, 1)
	truthy(ok)
	eq(phases[1].kind, "Swap")
	eq(pop.board:get(1, 1).piece.id, b)
	eq(pop.board:get(2, 1).piece.id, a)
	eq(pop.movesLeft, 30)
	falsy(pop:useBooster("GardenGloves", 1, 1, 3, 1), "only neighbours")
end)

test("Garden Gloves still pop a match they make", function()
	local pop = engine(nil, rows({
		"1 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:useBooster("GardenGloves", 3, 2, 3, 1)
	eq(#phase(phases, "Pop").removed, 3)
end)

test("Shake-Up shuffles and leaves a playable board", function()
	local pop = engine(nil, nil, 7)
	local ok, phases = pop:useBooster("ShakeUp")
	truthy(ok)
	eq(phases[1].kind, "Shuffle")
	truthy(#pop:listPossibleMoves() > 0)
end)

test("boosters can't be used after the level ends or by unknown names", function()
	local pop = engine({ moves = 1 }, rows({
		"1 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	falsy(pop:useBooster("Hoe", 1, 1))
	falsy(pop:useBooster("SprayerStart"), "pre-level boosters aren't used in play")
	pop:trySwap(3, 2, 3, 1)
	eq(pop.status, "Lost")
	falsy(pop:useBooster("Trowel", 1, 1))
end)

test("a Trowel can win a level", function()
	local pop = engine({
		layout = { "........", "........", "........", "...1....", "........", "........", "........", "........" },
		goals = { { kind = "HayBale" } },
	}, rows({ X8, X8, X8, "x x x B1 x x x x" }))
	pop:useBooster("Trowel", 4, 4)
	eq(pop.status, "Won")
end)

test("Sprayer Start places a sprayer of either direction", function()
	local seen = {}
	for seed = 1, 30 do
		local pop = Engine.new(Levels.get(1), seed, { startPowerUps = { "Sprayer" } })
		pop.board:eachCell(function(cell)
			if cell.piece and cell.piece.power then
				seen[cell.piece.power] = true
			end
		end)
	end
	truthy(seen.SprayerRow and seen.SprayerColumn)
end)

test("replays with boosters match the live game and report what was used", function()
	local picker = Rng.new(99)
	for i = 1, 200 do
		local level = Levels.List[(i - 1) % #Levels.List + 1]
		local seed = picker:nextU32()
		local options = { startPowerUps = { "Sprayer", "HayBomb" } }
		local pop = Engine.new(level, seed, options)
		local actions = {}
		while pop.status == "Playing" and #actions < 60 do
			local roll = picker:int(1, 10)
			local action
			if roll == 1 then
				action = { "Trowel", picker:int(1, pop.board.width), picker:int(1, pop.board.height) }
			elseif roll == 2 then
				action = { "Rake", picker:int(1, pop.board.height) }
			elseif roll == 3 then
				action = { "ShakeUp" }
			elseif roll == 4 then
				local m = picker:pick(pop:listPossibleMoves())
				action = { "GardenGloves", m[1], m[2], m[3], m[4] }
			else
				action = picker:pick(pop:listPossibleMoves())
			end
			if pop:apply(action) then
				table.insert(actions, action)
			end
		end
		local clean = assert(Replay.sanitize(actions))
		local result = Replay.run(level, seed, clean, options)
		truthy(result.ok, tostring(result.reason))
		eq(result.hash, pop:hash(), "run " .. i)
		for kind, n in pop.boostersUsed do
			eq(result.boostersUsed[kind], n)
		end
	end
end)

test("sanitize checks booster actions", function()
	truthy(Replay.sanitize({ { "Trowel", 1, 2 }, { "Rake", 3 }, { "ShakeUp" }, { "GardenGloves", 1, 1, 2, 1 } }))
	falsy((Replay.sanitize({ { "Trowel", 1 } })))
	falsy((Replay.sanitize({ { "Rake", 0 } })))
	falsy((Replay.sanitize({ { "Hoe", 1, 1 } })))
	falsy((Replay.sanitize({ { "BombStart" } })))
	local clean = Replay.sanitize({ { "Rake", 3, 4, 5 } })
	eq(#clean[1], 2, "extra values are dropped")
end)

-- Paid continues ---------------------------------------------------------------

local Boosters = CropPop.Boosters

local function runOut(pop)
	while pop.status == "Playing" do
		local m = pop:listPossibleMoves()[1]
		pop.movesLeft = 1
		pop:trySwap(m[1], m[2], m[3], m[4])
	end
end

test("a continue adds 5 moves, only once the level is lost", function()
	local pop = Engine.new(Levels.get(5), 3)
	falsy(pop:continue(), "not while playing")
	runOut(pop)
	if pop.status == "Won" then
		return -- this seed won by luck; the replay test below covers continues too
	end
	local ok, phases = pop:continue()
	truthy(ok)
	eq(#phases, 0, "the first continue adds no power-up")
	eq(pop.status, "Playing")
	eq(pop.movesLeft, 5)
	falsy(pop:continue(), "not twice in a row")
end)

test("later continues add a power-up and the prices rise", function()
	eq(Boosters.continueStep(1).gems, 10)
	truthy(Boosters.continueStep(2).gems > Boosters.continueStep(1).gems)
	eq(Boosters.continueStep(99).gems, Boosters.continueStep(#Boosters.Continue.Steps).gems)
	local pop = Engine.new(Levels.get(5), 11)
	for n = 1, 3 do
		runOut(pop)
		if pop.status == "Won" then
			return
		end
		local _, phases = pop:continue()
		local step = Boosters.continueStep(n)
		if step.power then
			eq(phases[1].kind, "Pop")
			eq(#phases[1].transformed, 1)
		end
	end
	eq(pop.continues, 3)
end)

test("replays accept continues only when the level is lost, and count them", function()
	local level = Levels.get(5)
	local pop = Engine.new(level, 21)
	local actions = { { "DevOneMove" } }
	pop:apply(actions[1])
	local m = pop:listPossibleMoves()[1]
	pop:apply(m)
	table.insert(actions, m)
	if pop.status ~= "Lost" then
		return
	end
	table.insert(actions, { "Continue" })
	falsy(Replay.sanitize(actions), "the dev action needs allowDev")
	local clean = assert(Replay.sanitize(actions, true))
	local result = Replay.run(level, 21, clean)
	truthy(result.ok, tostring(result.reason))
	eq(result.continues, 1)
	eq(result.status, "Playing")

	local early = Replay.run(level, 21, { { "Continue" } })
	falsy(early.ok, "a continue while playing is refused")
end)

test("Hot Streak gives 1, then 2, then 3 free power-ups", function()
	eq(#Boosters.hotStreakPowers(0), 0)
	eq(Boosters.hotStreakPowers(1)[1], "Sprayer")
	eq(#Boosters.hotStreakPowers(2), 2)
	eq(#Boosters.hotStreakPowers(3), 3)
	eq(#Boosters.hotStreakPowers(50), 3)
	local powers = Boosters.hotStreakPowers(3)
	table.insert(powers, "x")
	eq(#Boosters.hotStreakPowers(3), 3, "callers get a copy")
end)
