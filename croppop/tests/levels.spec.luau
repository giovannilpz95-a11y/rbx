-- The test levels are well-formed and deal playable boards.

local eq, truthy = expect.eq, expect.truthy
local Engine, Levels, Matcher = CropPop.Engine, CropPop.Levels, CropPop.Matcher

test("every level validates", function()
	local seen = {}
	for _, level in Levels.List do
		eq(Levels.validate(level), nil, level.name)
		truthy(not seen[level.id], "duplicate id " .. level.id)
		seen[level.id] = true
	end
	eq(#Levels.List, 325)
end)

test("levels run 1 to 325 in order, with unique names and the difficulty pattern", function()
	local names = {}
	for i, level in Levels.List do
		eq(level.id, i)
		truthy(not names[level.name], "duplicate name " .. level.name)
		names[level.name] = true
		local expected = if i >= 20 and i % 10 == 0 then "Super Tough" elseif i % 5 == 0 then "Tough" else "Normal"
		eq(level.difficulty, expected, "level " .. i)
	end
end)

test("validate catches broken levels", function()
	local broken = table.clone(Levels.get(1))
	broken.layout = { "...", "..", "..." }
	truthy(Levels.validate(broken))
	broken = table.clone(Levels.get(1))
	broken.goals = { { kind = "Mud" } }
	truthy(Levels.validate(broken), "mud goal without mud")
	broken = table.clone(Levels.get(1))
	broken.colors = { "Tomato", "Pumpkin", "Egg" }
	truthy(Levels.validate(broken), "unknown tile")
end)

test("every level deals a settled, playable board", function()
	for _, level in Levels.List do
		for seed = 1, if level.id <= 5 then 50 else 10 do
			local pop = Engine.new(level, seed)
			eq(#Matcher.findGroups(pop.board, {}), 0, level.name)
			truthy(Matcher.hasPossibleMove(pop.board), level.name)
			eq(pop.status, "Playing")
		end
	end
end)

test("goal targets come from the layout", function()
	local five = Engine.new(Levels.get(5), 1)
	local kinds = {}
	for _, goal in five.goals.list do
		kinds[goal.kind] = goal.target
	end
	eq(kinds.HayBale, 4)
	eq(kinds.Mud, 16)
	eq(kinds.Collect, 15)
end)

test("frost first shows up on level 21, weeds on 41, pumpkins on 101, clover on 126 and stone on 151, each alone with its goal", function()
	local function first(chars)
		for _, level in Levels.List do
			for _, row in level.layout do
				if string.find(row, "[" .. chars .. "]") then
					return level
				end
			end
		end
		return nil
	end
	local frost, weeds = first("fF"), first("w")
	eq(frost and frost.id, 21)
	eq(weeds and weeds.id, 41)
	eq(#frost.goals, 1)
	eq(frost.goals[1].kind, "Frost")
	eq(#weeds.goals, 1)
	eq(weeds.goals[1].kind, "Weeds")
	local pumpkins = first("p")
	eq(pumpkins and pumpkins.id, 101)
	eq(#pumpkins.goals, 1)
	eq(pumpkins.goals[1].kind, "Pumpkins")
	local clover = first("c")
	eq(clover and clover.id, 126)
	eq(#clover.goals, 1)
	eq(clover.goals[1].kind, "Clover")
	local stone = first("sS")
	eq(stone and stone.id, 151)
	eq(#stone.goals, 1)
	eq(stone.goals[1].kind, "Stones")
end)

test("portals first show up on level 176, and every portal level checks out", function()
	local firstPortal
	for _, level in Levels.List do
		if level.portals then
			firstPortal = firstPortal or level
			eq(Levels.checkPortals(level), nil, level.name)
		end
	end
	eq(firstPortal and firstPortal.id, 176)
	eq(#firstPortal.portals, 2, "one crossing pair")
end)

test("pumpkin baskets first show up on level 201, alone with a Pumpkins goal", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "d", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 201)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Pumpkins")
	eq(first.portals, nil)
end)

test("fences first show up on level 226, alone with their goal", function()
	local first
	for _, level in Levels.List do
		if level.fences then
			first = first or level
			eq(Levels.checkFences(level), nil, level.name)
		end
	end
	eq(first and first.id, 226)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Fences")
end)

test("goo first shows up on level 251, alone with its goal", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "g", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 251)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Goo")
end)

test("hen houses first show up on level 276, asking for eggs", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "h", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 276)
	eq(#first.goals, 1)
	eq(first.goals[1].tile, "Egg")
end)

test("surprise crates first show up on level 301", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "x", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 301)
end)
