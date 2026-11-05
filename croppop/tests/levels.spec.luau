-- The test levels are well-formed and deal playable boards.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Engine, Levels, Matcher = CropPop.Engine, CropPop.Levels, CropPop.Matcher

test("every level validates", function()
	local seen = {}
	for _, level in Levels.List do
		eq(Levels.validate(level), nil, level.name)
		truthy(not seen[level.id], "duplicate id " .. level.id)
		seen[level.id] = true
	end
	eq(#Levels.List, 1025)
end)

test("levels run 1 to 1025 in order, with unique names and the difficulty pattern", function()
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

test("buried statues first show up on level 326, with a Statues goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "b", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 326)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Statues")
end)

test("goo springs first show up on level 351, with a Goo goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "G", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 351)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Goo")
end)

test("tarps first show up on level 376, with a Tarps goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "t", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 376)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Tarps")
end)

test("thick goo first shows up on level 401, with a Goo goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "e", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 401)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Goo")
end)

test("rainbow patches first show up on level 426", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "r", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 426)
end)

test("webs first show up on level 451, with a Webs goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "n", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 451)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Webs")
end)

test("quilts first show up on level 476, with a Quilts goal alone and tins enough", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "q", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 476)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Quilts")
	local quilts, tins = 0, 0
	for _, row in first.layout do
		quilts += select(2, string.gsub(row, "q", ""))
		tins += select(2, string.gsub(row, "k", ""))
	end
	truthy(tins >= quilts)
end)

test("seed sacks first show up on level 501, with a Clover goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "z", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 501)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Clover")
end)

test("snowballs first show up on level 526, with a Snowballs goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "i", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 526)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Snowballs")
end)

test("clay first shows up on level 551, with a Clay goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "[aA]") then
				first = level
			end
		end
	end
	eq(first and first.id, 551)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Clay")
end)

test("mailboxes first show up on level 576, with a Letters goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "[lL]") then
				first = level
			end
		end
	end
	eq(first and first.id, 576)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Letters")
end)

test("scarecrows first show up on level 601, with a Collect goal", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "y", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 601)
	eq(first.goals[1].kind, "Collect")
end)

test("mud buckets first show up on level 626, with a Mud goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "u", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 626)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Mud")
	for _, row in first.layout do
		falsy(string.find(row, "[mM]"), "the first bucket level's mud all comes from its buckets")
	end
end)

test("produce box stacks first show up on level 651, with a Boxes goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "[vV]") then
				first = level
			end
		end
	end
	eq(first and first.id, 651)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Boxes")
end)

test("hedges first show up on level 676, which only asks to collect tiles", function()
	local first
	for _, level in Levels.List do
		for _, f in level.fences or {} do
			if not first and (f[3] == "R" or f[3] == "D") then
				first = level
			end
		end
	end
	eq(first and first.id, 676)
	for _, goal in first.goals do
		eq(goal.kind, "Collect")
	end
end)

test("beehives first show up on level 701, with a Honey goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "j", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 701)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Honey")
	truthy(first.goals[1].count >= 1)
end)

test("hay trucks first show up on level 726, with a HayBale goal alone and no other bales", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "C", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 726)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "HayBale")
	for _, row in first.layout do
		falsy(string.find(row, "[123]"), "the first truck level's bales all come off its trucks")
	end
end)

test("snails first show up on level 751, with a Goo goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "O", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 751)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Goo")
end)

test("tulip buds first show up on level 776, with a Blooms goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "T", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 776)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Blooms")
end)

test("lost lambs first show up on level 801, with a Lambs goal alone and a pen", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "E", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 801)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Lambs")
	local pens = 0
	for _, row in first.layout do
		pens += select(2, string.gsub(row, "P", ""))
	end
	truthy(pens >= 1)
end)

test("fireflies first show up on level 826, with a Fireflies goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "N", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 826)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Fireflies")
	truthy(first.goals[1].count >= 1)
end)

test("seed trays first show up on level 851, with a Trays goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "R", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 851)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Trays")
end)

test("compost bins first show up on level 876, with a Bins goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "B", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 876)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Bins")
end)

test("flood water and pumps first show up on level 901, with a Floods goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "W", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 901)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Floods")
	local pumps = 0
	for _, row in first.layout do
		pumps += select(2, string.gsub(row, "H", ""))
	end
	truthy(pumps >= 1)
end)

test("seed packets first show up on level 926, with a Packets goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "K", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 926)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Packets")
end)

test("lawn mowers first show up on level 951, in a row of hay bales", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "U", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 951)
	eq(first.goals[1].kind, "HayBale")
end)

test("gopher burrows first show up on level 976, with a Gophers goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "I", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 976)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Gophers")
end)

test("jam jars first show up on level 1001, with a Jars goal alone", function()
	local first
	for _, level in Levels.List do
		for _, row in level.layout do
			if not first and string.find(row, "J", 1, true) then
				first = level
			end
		end
	end
	eq(first and first.id, 1001)
	eq(#first.goals, 1)
	eq(first.goals[1].kind, "Jars")
end)
