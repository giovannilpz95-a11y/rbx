-- Daily Quests (src/shared/Quests, Config/Quests): the day's list, progress, claiming, the
-- free swap and the bonus chest. Called from tests/run.luau.

local Analytics = require("../src/shared/Analytics")
local Config = require("../src/shared/Config/Quests")
local Profile = require("../src/shared/Profile")
local Quests = require("../src/shared/Quests")
local Tools = require("../src/shared/Config/Tools")

local DAY = 20_000

-- A farm past the guide with a built pen (with animals) and a built factory
local function farm(level: number?): { [string]: any }
	local data = Profile.template()
	data.level = level or 8
	data.tutorial.step = 0
	data.meta.createdAt = 1_700_000_000
	for _, pen in data.pens do
		pen.built = true
		if #pen.animals == 0 then
			table.insert(pen.animals, {})
		end
	end
	for _, factory in data.factories do
		factory.built = true
	end
	return data
end

local function finishAll(data: { [string]: any })
	for _, quest in data.quests.list do
		Quests.add(data, quest.kind, quest.target)
	end
end

return function(test, eq, ok)
	test("quests: a new day picks three different quests the farm can do", function()
		local data = farm()
		ok(Quests.refresh(data, DAY), "refreshed")
		eq(#data.quests.list, Config.perDay, "count")
		local seen = {}
		for _, quest in data.quests.list do
			ok(not seen[quest.kind], "distinct " .. quest.kind)
			seen[quest.kind] = true
			ok(Quests.def(quest.kind) ~= nil, "known kind")
			eq(quest.progress, 0, "fresh")
		end
		ok(not Quests.refresh(data, DAY), "same day: no change")
		ok(Quests.refresh(data, DAY + 1), "next day: new list")
	end)

	test("quests: none while the first-session guide runs", function()
		local data = farm()
		data.tutorial.step = 3
		ok(not Quests.refresh(data, DAY), "no list")
		eq(#data.quests.list, 0, "empty")
		data.tutorial.step = 0
		ok(Quests.refresh(data, DAY), "opens after the guide")
	end)

	test("quests: no animal or factory quests before there's a pen or factory", function()
		local data = farm()
		for _, pen in data.pens do
			pen.animals = {}
		end
		for _, factory in data.factories do
			factory.built = false
		end
		local kinds = Quests.eligible(data)
		for _, kind in kinds do
			ok(kind ~= "animal" and kind ~= "factory", kind)
		end
		Quests.refresh(data, DAY)
		eq(#data.quests.list, #kinds, "only what fits")
	end)

	test("quests: smaller targets on young farms", function()
		local young, grown = farm(Config.smallTargetsBelow - 1), farm(Config.smallTargetsBelow)
		Quests.refresh(young, DAY)
		Quests.refresh(grown, DAY)
		for _, quest in young.quests.list do
			eq(quest.target, math.max(1, math.ceil((Quests.def(quest.kind) :: any).target / 2)), quest.kind)
		end
		for _, quest in grown.quests.list do
			eq(quest.target, (Quests.def(quest.kind) :: any).target, quest.kind)
		end
	end)

	test("quests: progress caps at the target and reports the finish once", function()
		local data = farm()
		Quests.refresh(data, DAY)
		local quest = data.quests.list[1]
		eq(#Quests.add(data, quest.kind, quest.target - 1), 0, "not yet")
		local done = Quests.add(data, quest.kind, 5)
		eq(#done, 1, "finished now")
		eq(done[1], 1, "index")
		eq(quest.progress, quest.target, "capped")
		eq(#Quests.add(data, quest.kind, 1), 0, "only once")
		eq(#Quests.add(data, "nothing", 3), 0, "other kinds ignored")
	end)

	test("quests: claim only when finished, and only once", function()
		local data = farm()
		Quests.refresh(data, DAY)
		local quest = data.quests.list[2]
		local def, reason = Quests.claim(data, 2)
		eq(def, nil, "unfinished")
		ok(reason ~= nil, "says why")
		Quests.add(data, quest.kind, quest.target)
		def = Quests.claim(data, 2)
		ok(def ~= nil and def.kind == quest.kind, "reward")
		ok(quest.claimed, "marked")
		eq(Quests.claim(data, 2), nil, "twice")
		eq(Quests.claim(data, 9), nil, "no such quest")
	end)

	test("quests: one free swap a day, never on a finished quest", function()
		local data = farm()
		Quests.refresh(data, DAY)
		local before = {}
		for _, quest in data.quests.list do
			before[quest.kind] = true
		end
		local eligible = #Quests.eligible(data)
		local swapped, reason = Quests.reroll(data, 1)
		if eligible > Config.perDay then
			ok(swapped, "swapped")
			ok(not before[data.quests.list[1].kind], "a new kind")
		else
			ok(not swapped and reason ~= nil, "nothing to swap in")
			return
		end
		local again, why = Quests.reroll(data, 2)
		ok(not again and why ~= nil, "one a day")
		Quests.refresh(data, DAY + 1)
		local quest = data.quests.list[1]
		Quests.add(data, quest.kind, quest.target)
		ok(not Quests.reroll(data, 1), "finished quests stay")
	end)

	test("quests: the bonus chest opens once, after all three are claimed", function()
		local data = farm()
		Quests.refresh(data, DAY)
		ok(not Quests.chestReady(data), "nothing done")
		finishAll(data)
		Quests.claim(data, 1)
		Quests.claim(data, 2)
		ok(not Quests.chestReady(data), "two of three")
		Quests.claim(data, 3)
		ok(Quests.chestReady(data), "all claimed")
		local gems, tool = Quests.openChest(data, "Axe")
		ok(tool == "Axe" or (gems >= Config.chest.minGems and gems <= Config.chest.maxGems), "gems or a tool")
		ok(not Quests.chestReady(data), "once")
		ok(Quests.refresh(data, DAY + 1) and not data.quests.chest, "resets next day")
	end)

	test("quests: the chest gives tools only from the tool level", function()
		local tools = 0
		for i = 1, 200 do
			local data = farm(Tools.fromLevel - 1)
			data.meta.createdAt = i
			Quests.refresh(data, DAY)
			finishAll(data)
			for index in data.quests.list do
				Quests.claim(data, index)
			end
			local _, tool = Quests.openChest(data, "Axe")
			ok(tool == nil, "no tool below the level")
			data = farm(Tools.fromLevel)
			data.meta.createdAt = i
			Quests.refresh(data, DAY)
			finishAll(data)
			for index in data.quests.list do
				Quests.claim(data, index)
			end
			if select(2, Quests.openChest(data, "Axe")) then
				tools += 1
			end
		end
		ok(tools > 20 and tools < 120, "about 30% tools: " .. tools)
	end)

	test("quests: text and analytics SKUs", function()
		eq(Quests.text({ kind = "harvest", target = 30, progress = 0, claimed = false }), "Harvest 30 crops", "text")
		eq(Analytics.sku("quest_harvest", "Coins"), "DailyQuest", "claim")
		eq(Analytics.sku("questchest", "Gems"), "QuestChest", "chest")
	end)
end
