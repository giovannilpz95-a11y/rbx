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
	eq(#Levels.List, 100)
end)

test("levels run 1 to 100 in order, with unique names and the difficulty pattern", function()
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
