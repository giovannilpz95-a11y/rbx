--!strict
-- Unit tests for the pure shared modules, plus a compile check of every Luau file.
-- Run from the farm/ folder:  lune run tests/run.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Animals = require("../src/shared/Config/Animals")
local Away = require("../src/shared/Away")
local Balance = require("../src/shared/Config/Balance")
local Barn = require("../src/shared/Config/Barn")
local BarnRules = require("../src/shared/BarnRules")
local Crops = require("../src/shared/Config/Crops")
local DailyRules = require("../src/shared/Daily")
local Decor = require("../src/shared/Config/Decor")
local DecorRules = require("../src/shared/DecorRules")
local Drops = require("../src/shared/Drops")
local Products = require("../src/shared/Config/Products")
local Shop = require("../src/shared/Shop")
local Prize = require("../src/shared/Config/Prize")
local PrizeRules = require("../src/shared/Prize")
local Factories = require("../src/shared/Config/Factories")
local Items = require("../src/shared/Items")
local Land = require("../src/shared/Config/Land")
local Levels = require("../src/shared/Config/Levels")
local Lots = require("../src/shared/Lots")
local OrderConfig = require("../src/shared/Config/Orders")
local OrderGen = require("../src/shared/OrderGen")
local Pen = require("../src/shared/Pen")
local Profile = require("../src/shared/Profile")
local Progression = require("../src/shared/Progression")
local Recipes = require("../src/shared/Config/Recipes")
local Records = require("../src/shared/Records")
local Missing = require("../src/shared/Missing")
local Rng = require("../src/shared/Rng")
local Settings = require("../src/shared/Settings")
local Social = require("../src/shared/Config/Social")
local SocialRules = require("../src/shared/Social")
local Speedup = require("../src/shared/Speedup")
local Timer = require("../src/shared/Timer")
local Town = require("../src/shared/Config/Town")
local TownRules = require("../src/shared/TownRules")
local Tutorial = require("../src/shared/Tutorial")
local Unlocks = require("../src/shared/Unlocks")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

local function eq(actual: any, expected: any, what: string?)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function ok(condition: any, what: string)
	if not condition then
		error(what, 2)
	end
end

---------------------------------------------------------------------------------------------
-- Config integrity (09 Roblox Architecture §9)
---------------------------------------------------------------------------------------------

test("every crop has positive timers and matching ids", function()
	for id, crop in Crops do
		eq(crop.id, id, "crop id")
		ok(crop.growSeconds > 0 and crop.yield > 0, id .. " needs time and yield")
		eq(crop.yield, 1, id .. " gives 1 unit a field, as in Township")
		ok(crop.unlockLevel >= 1 and crop.unlockLevel <= 30, id .. " unlock level in 1-30")
	end
end)

test("Township baseline crop rows for the greybox", function()
	eq(Crops.Wheat.growSeconds, 120, "Wheat time")
	eq(Crops.Wheat.seedCost, 0, "Wheat seed")
	eq(Crops.Corn.unlockLevel, 3, "Corn level")
	eq(Crops.Corn.growSeconds, 300, "Corn time")
	eq(Crops.Corn.sellPrice, 3, "Corn price")
end)

test("every recipe input and factory exists", function()
	for id, recipe in Recipes do
		eq(recipe.id, id, "recipe id")
		ok(Factories[recipe.factory] ~= nil, id .. " factory " .. recipe.factory)
		for input in recipe.inputs do
			ok(Items[input] ~= nil, id .. " input " .. input)
		end
	end
end)

test("enabled crops, factories and pens exist", function()
	for _, id in Balance.enabledCrops do
		ok(Crops[id] ~= nil, "crop " .. id)
	end
	for _, id in Balance.enabledFactories do
		ok(Factories[id] ~= nil, "factory " .. id)
	end
	for _, id in Balance.enabledPens do
		ok(Animals.pens[id] ~= nil, "pen " .. id)
	end
end)

test("every recipe of an enabled factory can be made in the MVP", function()
	local enabled = {}
	for _, id in Balance.enabledCrops do
		enabled[id] = true
	end
	for _, id in Balance.enabledPens do
		enabled[Animals.pens[id].product] = true
	end
	for id, recipe in Recipes do
		enabled[id] = table.find(Balance.enabledFactories, recipe.factory) ~= nil
	end
	for id, recipe in Recipes do
		if enabled[id] then
			for input in recipe.inputs do
				ok(enabled[input], id .. " needs " .. input .. ", which the MVP can't make")
			end
			ok(recipe.unlockLevel <= Levels.built, id .. " unlocks past the content bank")
			ok(recipe.unlockLevel >= Factories[recipe.factory].unlockLevel, id .. " unlocks before its factory")
		end
	end
end)

test("every pen's feed is a Feed Mill recipe and its product an item", function()
	for id, def in Animals.pens do
		eq(def.id, id, "pen id")
		local feed = Recipes[def.feed]
		ok(feed ~= nil and feed.isFeed and feed.factory == "FeedMill", id .. " feed " .. def.feed)
		ok(Items[def.product] ~= nil and Items[def.product].kind == "Animal", id .. " product")
		eq(#def.extraAnimalCosts, Animals.maxAnimals - def.startAnimals, id .. " animal costs")
	end
end)

test("Township baseline rows for animals, factories and recipes", function()
	eq(Animals.pens.CowBarn.produceSeconds, 20 * 60, "Milk time")
	eq(Animals.pens.ChickenCoop.unlockLevel, 5, "Chickens level")
	eq(Animals.pens.SheepFold.buildCost, 600, "Sheep Fold cost")
	eq(Factories.FeedMill.unlockLevel, 3, "Feed Mill level")
	eq(Factories.TextileMill.queueSlots, 2, "Textile Mill slots")
	eq(Recipes.CowFeed.outputQty, 3, "feed batch")
	eq(Recipes.Cheese.inputs.Milk, 2, "Cheese milk")
	eq(Recipes.Shirt.inputs.CottonFabric, 1, "Shirt fabric")
end)

test("item production time includes everything upstream", function()
	-- Cow Feed: (5 min + 2 Wheat * 120 s + 1 Corn * 300 s) / 3 bags = 280 s a bag
	eq(Items.CowFeed.unitSeconds, 280, "Cow Feed")
	-- Milk: 20 min + a third of a bag
	ok(math.abs(Items.Milk.unitSeconds - (1200 + 280 / 3)) < 1e-6, "Milk")
	ok(Items.Cheese.unitSeconds > 2 * Items.Milk.unitSeconds, "Cheese includes its Milk")
	ok(Items.CowFeed.isFeed and not Items.Milk.isFeed, "feed flag")
end)

test("no item id is both a crop and a recipe", function()
	for id in Recipes do
		ok(Crops[id] == nil, id .. " is both")
	end
end)

test("levels run 1..built in order, and the live cap is within them", function()
	eq(#Levels.list, Levels.built, "level rows")
	ok(Levels.cap >= 12 and Levels.cap <= Levels.built, "cap inside the built levels")
	for i, def in Levels.list do
		eq(def.level, i, "level order")
		ok(def.xpToNext > 0, "xp > 0")
	end
end)

---------------------------------------------------------------------------------------------
-- Progression
---------------------------------------------------------------------------------------------

test("level thresholds follow the Township curve", function()
	eq(Progression.levelFor(0), 1, "start")
	eq(Progression.levelFor(8), 1, "just under L2")
	eq(Progression.levelFor(9), 2, "L2 at 9 XP")
	eq(Progression.levelFor(26), 3, "L3 at 26 XP")
	eq(Progression.levelFor(4675), 11, "just under L12")
	eq(Progression.levelFor(4676), 12, "L12 at 4,676 XP")
	eq(Progression.levelFor(999999), 12, "capped")
	local info = Progression.info(30)
	eq(info.level, 3, "level at 30 XP")
	eq(info.xpIntoLevel, 4, "xp into level")
	eq(info.xpToNext, 44, "xp to next")
	ok(Progression.info(5000).atCap, "at cap")
end)

test("level-up gifts are the new crop or feed", function()
	for level, gift in Levels.gifts do
		for item, qty in gift do
			ok(Items[item] ~= nil and qty > 0, string.format("L%d %s", level, item))
			ok(Items[item].unlockLevel <= level, item .. " is open by then")
		end
	end
	eq(Levels.gifts[3].Corn, 4, "Corn at 3")
	eq(Balance.starterCowFeed, 9, "Cow Feed at 1")
end)

test("the content bank: XP past the live cap is banked until the cap is raised", function()
	eq(Levels.list[13].xpToNext, 1935, "L13 row")
	eq(Levels.list[15].rewardCoins, 500, "L15 coins")
	local toThirteen = 6231 -- Township total to reach 13
	eq(Progression.levelFor(toThirteen), Levels.cap, "held at the live cap")
	Progression.preview(Levels.built)
	eq(Progression.cap(), Levels.built, "preview opens the bank")
	eq(Progression.levelFor(toThirteen - 1), 12, "just under 13")
	eq(Progression.levelFor(toThirteen), 13, "13 once open")
	eq(Progression.levelFor(999999), Levels.built, "never past the built levels")
	Progression.preview(99)
	eq(Progression.cap(), Levels.built, "preview clamps")
	Progression.preview(nil)
	eq(Progression.cap(), Levels.cap, "preview off")
end)

test("the content bank stays locked at the live cap", function()
	ok(Crops.Strawberries.unlockLevel > Levels.cap, "Strawberries")
	ok(Recipes.WoolScarf.unlockLevel > Levels.cap, "Wool Scarf")
	ok(Town.community.ClockTower.unlockLevel > Levels.cap, "Clock Tower")
	ok(Town.houses.GardenVilla.copyLevels[1] > Levels.cap, "Garden Villa")
	ok(table.find(Balance.enabledCrops, "Strawberries") ~= nil, "Strawberries enabled")
	eq(Levels.built, 20, "levels 17 to 20 are banked")
	eq(Levels.list[20].xpToNext, 6736, "L20 row")
	eq(Recipes.IceCreamCone.factory, "IceCreamParlor", "Ice Cream Cone")
	eq(Recipes.PatchworkQuilt.inputs.Yarn, 1, "Patchwork Quilt")
	eq(Town.houses.CornerFlats.copyLevels[1], 20, "Corner Flats")
	eq(Levels.list[19].xpToNext, 5771, "L19 row")
	eq(Recipes.TomatoKetchup.inputs.Tomatoes, 2, "Tomato Ketchup")
	-- The second Feed Mill: its own building and queue, making the Feed Mill's recipes
	local second = Factories.FeedMill2
	eq(second.makes, "FeedMill", "second Feed Mill makes feed")
	eq(second.unlockLevel, 19, "second Feed Mill at 19")
	eq(second.population, 655, "second Feed Mill Population")
	ok(Factories[second.makes].makes == nil, "copies point at an original")
	for id, recipe in Recipes do
		ok(
			Factories[recipe.factory] ~= nil and Factories[recipe.factory].makes == nil,
			id .. " names an original factory"
		)
	end
	eq(Levels.list[18].xpToNext, 4912, "L18 row")
	ok(table.find(Balance.enabledCrops, "Pumpkins") ~= nil and Crops.Pumpkins.unlockLevel == 18, "Pumpkins at 18")
	eq(Recipes.RoastedPumpkinSeeds.inputs.Pumpkins, 2, "Roasted Pumpkin Seeds")
	eq(Levels.list[17].xpToNext, 4149, "L17 row")
	for _, id in { "CornChips", "CaneSyrup" } do
		eq(Recipes[id].unlockLevel, 17, id .. " at 17")
		ok(table.find(Balance.enabledFactories, Recipes[id].factory) ~= nil, id .. "'s factory is enabled")
	end
	eq(Town.houses.ThatchedLonghouse.copyLevels[1], 17, "Thatched Longhouse")
	for _, id in { "Bathhouse", "ArtStudio", "MusicHall", "StargazingTower", "RoseGarden" } do
		local def = Town.community[id]
		ok(def.unlockLevel > Levels.cap and def.unlockLevel <= Levels.built, id .. " in the bank")
		eq(Lots.community[TownRules.communityLot(id) :: number].land, Lots.northLaneLand, id .. " stands on North Lane")
	end
	for _, id in { "SnackFactory", "Diner", "FeedMill2", "IceCreamParlor" } do
		ok(Factories[id].unlockLevel > Levels.cap and Factories[id].unlockLevel <= Levels.built, id .. " in the bank")
		ok(table.find(Balance.enabledFactories, id) ~= nil, id .. " enabled")
		eq(Factories[id].land, 2, id .. " stands in the East Meadow")
	end
	eq(Recipes.FarmBurger.inputs.Tomatoes, 1, "Farm Burger uses the bank's Tomatoes")
end)

test("level rewards", function()
	local coins, gems = Progression.reward(2)
	eq(coins, 100, "L2 coins")
	eq(gems, 1, "L2 gems")
end)

---------------------------------------------------------------------------------------------
-- Timer
---------------------------------------------------------------------------------------------

test("format", function()
	eq(Timer.format(5), "5s")
	eq(Timer.format(125), "2m 05s")
	eq(Timer.format(3720), "1h 02m")
end)

test("queue chains jobs back to back while offline", function()
	local queue = {
		{ recipe = "Bread", seconds = 300 },
		{ recipe = "Bread", seconds = 300 },
		{ recipe = "Bread", seconds = 300 },
	}
	local output = {}
	Timer.advanceQueue(queue, output, 1000, 8)
	eq(queue[1].readyAt, 1300, "first job starts now")
	Timer.advanceQueue(queue, output, 1000 + 650, 8)
	eq(output.Bread, 2, "two finished")
	eq(#queue, 1, "one left")
	eq(queue[1].startedAt, 1600, "next starts when the previous finished, not now")
	eq(queue[1].readyAt, 1900, "and runs its full time")
end)

test("a full tray pauses the queue until goods are collected", function()
	local queue = { { recipe = "Bread", seconds = 10 }, { recipe = "Bread", seconds = 10 } }
	local output = { Bread = 7 }
	Timer.advanceQueue(queue, output, 0, 8)
	Timer.advanceQueue(queue, output, 100, 8)
	eq(output.Bread, 8, "tray filled")
	eq(#queue, 1, "one waiting")
	eq(queue[1].startedAt, nil, "paused, not started")
	output.Bread = 0 -- collected
	Timer.advanceQueue(queue, output, 200, 8)
	eq(queue[1].startedAt, 200, "restarts at collect time")
end)

test("a batch only starts when the tray has room for all of it", function()
	local queue = { { recipe = "CowFeed", seconds = 10, qty = 3 }, { recipe = "CowFeed", seconds = 10, qty = 3 } }
	local output = { Bread = 3 }
	Timer.advanceQueue(queue, output, 0, 8)
	Timer.advanceQueue(queue, output, 100, 8)
	eq(output.CowFeed, 3, "first batch of 3")
	eq(#queue, 1, "second waits: 6 + 3 > 8")
	eq(queue[1].startedAt, nil, "not started")
	output.Bread = nil
	Timer.advanceQueue(queue, output, 200, 8)
	eq(queue[1].startedAt, 200, "starts once there's room")
end)

---------------------------------------------------------------------------------------------
-- Pens
---------------------------------------------------------------------------------------------

local function newPen(n: number)
	local pen = { built = true, animals = {}, feedLeft = 0 }
	for _ = 1, n do
		table.insert(pen.animals, {})
	end
	return pen
end

test("one bag feeds three animals", function()
	local pen = newPen(4)
	local bags = 1
	local function takeBag(): boolean
		if bags > 0 then
			bags -= 1
			return true
		end
		return false
	end
	eq(Pen.feed(pen, 0, 1200, takeBag), 3, "three fed from one bag")
	eq(pen.feedLeft, 0, "bag used up")
	eq(Pen.counts(pen, 0).hungry, 1, "one still hungry")
	bags = 1
	eq(Pen.feed(pen, 0, 1200, takeBag), 1, "the fourth")
	eq(pen.feedLeft, 2, "two scoops left in the trough")
end)

test("animals hold their product until collected, within Barn space", function()
	local pen = newPen(3)
	Pen.feed(pen, 0, 100, function()
		return true
	end)
	local counts = Pen.counts(pen, 50)
	eq(counts.producing, 3, "producing")
	eq(counts.nextReadyAt, 100, "next ready")
	eq(Pen.counts(pen, 1000).ready, 3, "all ready, nothing lost offline")
	eq(Pen.collect(pen, 1000, 2), 2, "only what fits")
	local after = Pen.counts(pen, 1000)
	eq(after.ready, 1, "one waits")
	eq(after.hungry, 2, "collected ones are hungry")
end)

test("animals 4 to 6 cost Coins, then the pen is full", function()
	local def = Animals.pens.CowBarn
	local pen = newPen(3)
	eq(Pen.nextAnimalCost(def, pen), 30, "4th")
	table.insert(pen.animals, {})
	table.insert(pen.animals, {})
	eq(Pen.nextAnimalCost(def, pen), 50, "6th")
	table.insert(pen.animals, {})
	eq(Pen.nextAnimalCost(def, pen), nil, "full")
end)

test("construction blocks a pen until it's done", function()
	local pen = newPen(3)
	pen.constructionReadyAt = 100
	ok(not Pen.isOperational(pen, 50), "building")
	ok(Pen.isOperational(pen, 100), "done")
end)

---------------------------------------------------------------------------------------------
-- Gem speed-ups (Township baseline §10)
---------------------------------------------------------------------------------------------

test("speed-up prices follow the Township tables", function()
	eq(Speedup.production(0), 0, "done is free")
	eq(Speedup.production(1), 1, "a second left")
	eq(Speedup.production(4 * 60 + 59), 1, "under 5 min")
	eq(Speedup.production(5 * 60), 2, "5 min")
	eq(Speedup.production(2 * 3600 - 1), 9, "under 2 h")
	eq(Speedup.production(20 * 3600), 19, "past the table")
	eq(Speedup.building(40), 1, "Feed Mill build")
	eq(Speedup.building(3600), 5, "Dairy build (1 h)")
	eq(Speedup.building(6 * 3600), 20, "Textile Mill build (6 h)")
	eq(Speedup.orderWait(29 * 60), 4, "order wait")
end)

test("queue slots cost 8 Gems and up, to 7 slots", function()
	eq(Speedup.nextSlotCost(3, 3), 8, "first extra (Bakery)")
	eq(Speedup.nextSlotCost(3, 5), 16, "third extra")
	eq(Speedup.nextSlotCost(3, 6), nil, "max 6 until factory upgrades")
	eq(Speedup.nextSlotCost(2, 5), 20, "fourth extra (Sugar Mill)")
	eq(Speedup.nextSlotCost(2, 6), nil, "max")
end)

test("a pen's speed-up prices each producing animal", function()
	local pen = { animals = { { readyAt = 100 + 600 }, { readyAt = 100 + 3600 }, {}, { readyAt = 50 } } }
	-- 10 min -> 2, 1 h -> 6, hungry and ready ones are free
	eq(Speedup.pen(pen, 100), 8, "sum")
end)

---------------------------------------------------------------------------------------------
-- Town (07 Town Building)
---------------------------------------------------------------------------------------------

test("a new farm starts at Population 60 with Cap 75", function()
	local data = Profile.migrate(nil) :: any
	eq(TownRules.population(data, 0), 60, "starter Houses")
	eq(TownRules.cap(data, 0), 75, "base Cap")
	eq(#data.town.houses, 4, "four starter Houses")
end)

test("House copies unlock by level and need room under the Cap", function()
	local data = Profile.migrate(nil) :: any
	local first, reason = TownRules.canBuildHouse(data, "Cottage", 0)
	eq(first, false, "second Cottage is level 5")
	ok(reason ~= nil and reason:find("level 5") ~= nil, "says when")
	data.level = 4
	eq(TownRules.copiesAllowed("LeanTo", 4), 3, "three Lean-tos at level 4")
	for lot = 5, 7 do
		local can = TownRules.canBuildHouse(data, "LeanTo", 0)
		eq(can, true, "Lean-to " .. lot)
		table.insert(data.town.houses, { type = "LeanTo", lot = lot, readyAt = 100 })
	end
	eq(TownRules.population(data, 50), 60, "building ones don't count yet")
	eq(TownRules.pending(data, 50), 15, "pending")
	eq(TownRules.population(data, 100), 75, "done at readyAt")
	data.level = 5
	local can, why = TownRules.canBuildHouse(data, "Cottage", 100)
	eq(can, false, "75 + 10 > 75")
	ok(why and why:find("Community Building"), "asks for a Community Building")
	data.town.community.VillageWell = { readyAt = 200 }
	eq(TownRules.cap(data, 150), 75, "Cap waits for the Well")
	eq(TownRules.cap(data, 200), 85, "Well done")
	eq((TownRules.canBuildHouse(data, "Cottage", 200)), true, "room now")
end)

test("Houses take the first free lot", function()
	local data = Profile.migrate(nil) :: any
	eq(TownRules.freeLot(data, 32), 5, "after the starters")
	table.remove(data.town.houses, 2)
	eq(TownRules.freeLot(data, 32), 2, "a gap is reused")
	eq(TownRules.freeLot(data, 3), 2, "still fits")
	eq(TownRules.freeLot(data, 1), nil, "street full")
end)

test("North Lane opens more lots once the North Fields are cleared", function()
	eq(Lots.mainStreetHouses, 32, "Main Street House lots")
	eq(Lots.mainStreetCommunity, 11, "Main Street Community lots")
	eq(#Lots.houses, 48, "House lots with North Lane")
	eq(#Lots.community, 17, "Community lots with North Lane")
	local data = Profile.migrate(nil) :: any
	data.level = 16
	eq(TownRules.houseLotCount(data, 0), 32, "Main Street only")
	eq((TownRules.communityLotOpen(data, "Greenhouse", 0)), true, "Greenhouse is on Main Street")
	local open, land = TownRules.communityLotOpen(data, "Bathhouse", 0)
	eq(open, false, "Bathhouse waits")
	eq(land, Lots.northLaneLand, "for the North Fields")
	for stage = 1, Lots.northLaneLand do
		data.land[stage] = { readyAt = 100 }
	end
	eq(TownRules.houseLotCount(data, 50), 32, "still clearing")
	eq(TownRules.houseLotCount(data, 100), 48, "cleared")
	eq((TownRules.communityLotOpen(data, "ArtStudio", 100)), true, "Art Studio open")
	for lot = 5, 32 do
		table.insert(data.town.houses, { type = "LeanTo", lot = lot })
	end
	eq(TownRules.freeLot(data, TownRules.houseLotCount(data, 100)), 33, "first North Lane lot")
end)

test("the Town Hall upgrade builds onto the Town Hall, not a lot", function()
	local def = Town.community.TownHallUpgrade
	eq(def.unlockLevel, 20, "level 20")
	eq(def.capBonus, 95, "Cap +95")
	eq(TownRules.communityLot("TownHallUpgrade"), nil, "no lot")
	eq(TownRules.communityLot("RoseGarden"), 16, "earlier buildings keep their lots")
	local data = Profile.migrate(nil) :: any
	eq((TownRules.communityLotOpen(data, "TownHallUpgrade", 0)), true, "nothing to clear")
	local storeys, upgrading = TownRules.townHall(data, 0)
	eq(storeys, 1, "one storey to start")
	eq(upgrading, false, "not upgrading")
	local cap = TownRules.cap(data, 0)
	data.town.community.TownHallUpgrade = { readyAt = 100 }
	storeys, upgrading = TownRules.townHall(data, 50)
	eq(storeys, 1, "still one storey while it goes up")
	eq(upgrading, true, "upgrading")
	storeys, upgrading = TownRules.townHall(data, 100)
	eq(storeys, 2, "two storeys once done")
	eq(upgrading, false, "done")
	eq(TownRules.cap(data, 100), cap + 95, "raises the Cap")
end)

test("every lot sits on the plot, on its land, clear of the streets and the other lots", function()
	local boxes = {}
	local function add(list: { any }, size: number, what: string)
		for i, lot in list do
			local box = { lot.x - size / 2, lot.z - size / 2, lot.x + size / 2, lot.z + size / 2, what .. " " .. i }
			ok(box[1] >= -96 and box[3] <= 96 and box[2] >= -96 and box[4] <= 96, box[5] .. " on the plot")
			if lot.land > 0 then
				local rect = Land.rects[lot.land]
				ok(
					box[1] >= rect.minX and box[3] <= rect.maxX and box[2] >= rect.minZ and box[4] <= rect.maxZ,
					box[5] .. " inside its land"
				)
			end
			table.insert(boxes, box)
		end
	end
	add(Lots.houses, 8, "House lot")
	add(Lots.community, 12, "Community lot")
	local lane, link = Lots.northLane.z, Lots.northLane.linkX
	local streets = {
		{ -92, 71, 92, 79, "Main Street" },
		{ -4, 48, 4, 96, "gate road" },
		{ -46, lane - 4, 46, lane + 4, "North Lane" },
		{ link - 4, lane + 4, link + 4, -48, "North Lane link" },
	}
	local function overlaps(a, b)
		return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
	end
	for i, a in boxes do
		for _, street in streets do
			ok(not overlaps(a, street), a[5] .. " is clear of " .. street[5])
		end
		for j = i + 1, #boxes do
			ok(not overlaps(a, boxes[j]), a[5] .. " is clear of " .. boxes[j][5])
		end
	end
	for id, def in Town.community do
		local lot = TownRules.communityLot(id)
		ok(if def.townHallStorey then lot == nil else Lots.community[lot :: number] ~= nil, id .. " has a lot")
	end
end)

test("Township baseline town rows", function()
	eq(Town.houses.RowHouse.population, 20, "Row House")
	eq(Town.houses.Townhouse.coinCost, 105, "Townhouse cost")
	eq(Town.community.Bandstand.capBonus, 55, "Bandstand")
	eq(Town.community.FireHall.materials.Bricks, 2, "Fire Hall bricks")
	eq(Factories.Dairy.population, 65, "Dairy needs 65")
	eq(Factories.TextileMill.population, 105, "Textile Mill needs 105")
	local total = 0
	for _, def in Town.community do
		if def.unlockLevel <= 12 then
			total += def.capBonus
		end
		ok(def.unlockLevel <= Levels.built, def.id .. " past the content bank")
		for material in def.materials do
			ok(Town.materials[material] ~= nil and Items[material].kind == "Material", def.id .. " " .. material)
		end
	end
	eq(Town.baseCap + total, 385, "Cap with every MVP Community Building (Township's level-12 max Population)")
end)

test("materials can't be sold or ordered; longer crops drop more", function()
	eq(Items.Bricks.sellPrice, 0, "not sellable")
	local data = Profile.migrate(nil) :: any
	ok(table.find(OrderGen.makeablePool(data), "Bricks") == nil, "not on orders")
end)

test("Speed Up All prices every growing field of one crop", function()
	local fields = {
		F1 = { crop = "Corn", readyAt = 100 + 300 },
		F2 = { crop = "Corn", readyAt = 100 + 60 },
		F3 = { crop = "Corn", readyAt = 50 }, -- ready already
		F4 = { crop = "Wheat", readyAt = 100 + 120 },
		F5 = {},
	}
	local total, count = Speedup.allFields(fields, "Corn", 100)
	eq(count, 2, "only growing Corn")
	eq(total, Speedup.production(300) + Speedup.production(60), "summed")
	eq(select(2, Speedup.allFields(fields, "Carrot", 100)), 0, "none")
end)

test("Prize Crops: rare rolls, a 10-slot basket and Prize Stand prices", function()
	local data = Profile.migrate(nil) :: any
	eq(#data.prizes, 0, "empty basket")
	data.tutorial.step = 2
	eq(PrizeRules.roll(data, 0), nil, "none while the guide runs")
	data.tutorial.step = 0
	eq(PrizeRules.roll(data, 0.001), "Heirloom", "0.2% Heirloom")
	eq(PrizeRules.roll(data, 0.01), "Sunkissed", "then 2% Sunkissed")
	eq(PrizeRules.roll(data, 0.023), nil, "the rest are ordinary")
	eq(PrizeRules.value("Corn", "Sunkissed"), 9, "x3 the sell price")
	eq(PrizeRules.value("Corn", "Heirloom"), 45, "x15")
	for i = 1, Prize.basketSlots do
		ok(PrizeRules.hasRoom(data), "room for " .. i)
		table.insert(data.prizes, { crop = "Wheat", tier = "Sunkissed" })
	end
	eq(PrizeRules.hasRoom(data), false, "basket full at 10")
	eq(#data.prizeShelf, 0, "empty shelf")
	for i = 1, Prize.shelfSlots do
		ok((PrizeRules.shelve(data, 1)), "shelve " .. i)
	end
	local shelved, why = PrizeRules.shelve(data, 1)
	eq(shelved, false, "the shelf holds 3")
	ok(why ~= nil, "and says so")
	eq(#data.prizes, Prize.basketSlots - Prize.shelfSlots, "moved out of the basket")
	ok((PrizeRules.unshelve(data, 2)), "take one down")
	eq(#data.prizeShelf, 2, "two left on show")
	eq(PrizeRules.unshelve(data, 5), false, "no such slot")
	data.prizes = {
		{ crop = "Corn", tier = "Heirloom" },
		{ crop = "Wheat", tier = "Sunkissed" },
		{ crop = "Corn", tier = "Sunkissed" },
	}
	eq(PrizeRules.basketCount(data, "Corn"), 2, "two Corn count for orders")
	eq(PrizeRules.take(data, "Corn", 1), 1, "use one")
	eq(data.prizes[1].tier, "Heirloom", "the Sunkissed one went first")
	eq(PrizeRules.take(data, "Corn", 5), 1, "only what's there")
	eq(PrizeRules.basketCount(data, "Corn"), 0, "none left")
end)

test("the Shop: buy rules, receipt de-duplication and the Big Barn bonus", function()
	local data = Profile.migrate(nil) :: any
	eq((Shop.canBuy(data, "Pouch")), false, "no product id yet")
	eq(select(2, Shop.canBuy(data, "Pouch")), "Coming soon", "says so")
	eq((Shop.canBuy(data, "Nope")), false, "unknown key")
	for _, product in Products.products do
		eq(product.productId, 0, product.key .. " ships as a placeholder")
		ok(product.gems > 0, product.key .. " gives Gems")
	end
	ok(not Shop.processed(data, "r1"), "new receipt")
	Shop.record(data, "r1", 1)
	ok(Shop.processed(data, "r1"), "remembered")
	for i = 2, Products.keepReceipts + 5 do
		Shop.record(data, "r" .. i, i)
	end
	local kept = 0
	for _ in data.purchases.receipts do
		kept += 1
	end
	eq(kept, Products.keepReceipts, "trimmed to the newest")
	ok(not Shop.processed(data, "r1"), "oldest dropped")
	ok(Shop.processed(data, "r" .. (Products.keepReceipts + 5)), "newest kept")
	eq(Shop.barnCapacity(data), data.inventory.barnCapacity, "no pass")
	data.purchases.passes.BigBarn = true
	eq(Shop.barnCapacity(data), data.inventory.barnCapacity + 50, "+50 with Big Barn")
end)

test("harvests drop tools and materials on one roll, with a pity tool", function()
	local data = Profile.migrate(nil) :: any
	ok(math.abs(Drops.chance(0) - 0.105) < 1e-9, "3% + 2% + 1.5% tools, 2% + 2% materials")
	ok(math.abs(Drops.chance(8 * 3600) - 0.315) < 1e-9, "x3 cap")
	eq(Drops.harvest(data, 0, 0), nil, "nothing before level 5")
	eq(data.toolShed.dry, 0, "and no pity count")
	data.level = 5
	eq(Drops.harvest(data, 0, 0.01), "Shovel", "low rolls are Shovels")
	eq(Drops.harvest(data, 0, 0.06), "Saw", "then Axes, then Saws")
	eq(Drops.harvest(data, 0, 0.07), "Bricks", "then materials")
	eq(data.toolShed.dry, 1, "a material isn't a tool")
	eq(Drops.harvest(data, 0, 0.2), nil, "high rolls drop nothing")
	eq(Drops.harvest(data, 8 * 3600, 0.2), "Bricks", "long crops roll better")
	data.toolShed.items = { Shovel = 2, Axe = 1 }
	data.toolShed.dry = 39
	eq(Drops.harvest(data, 0, 0.99), nil, "harvest 40 can still miss")
	eq(Drops.harvest(data, 0, 0.99), "Saw", "harvest 41 gives the scarcest tool")
	eq(data.toolShed.dry, 0, "and resets the count")
	data.toolShed.items.Saw = 1
	eq(Drops.scarcestTool(data), "Axe", "ties go to the commoner tool")
end)

test("the first-session guide walks the opening loop", function()
	local data = Profile.migrate(nil) :: any
	eq(data.tutorial.step, 0, "off until welcomed (old farms never see it)")
	Profile.welcome(data, 100)
	Tutorial.start(data, 100)
	eq(Tutorial.current(data).id, "Harvest", "first step")
	eq(data.fields.F1.crop, "Wheat", "ripe Wheat waiting")
	eq(data.orders.board[1].order.wants.Wheat, 3, "an easy first order the ripe fields fill")
	eq(#Tutorial.advance(data, 100), 0, "nothing harvested yet")
	eq(Tutorial.seconds(data, "Wheat", 120), 30, "first Wheat is quick")
	for _, id in Tutorial.ripeFields do
		data.fields[id] = {}
	end
	data.fields.F4 = { crop = "Wheat", readyAt = 130 }
	eq(table.concat(Tutorial.advance(data, 101), ","), "Harvest,Plant", "harvested and replanted")
	eq(Tutorial.current(data).target, "OrderBoard", "points at the board")
	data.orders.delivered = 1
	data.level = 2
	data.factories.Bakery.built = true
	data.factories.Bakery.constructionReadyAt = 200
	eq(table.concat(Tutorial.advance(data, 150), ","), "Ship,Level2", "waits for the Bakery to finish")
	eq(table.concat(Tutorial.advance(data, 200), ","), "Bakery", "built")
	eq(Tutorial.seconds(data, "Bread", 300), 30, "first Bread is quick")
	eq(Tutorial.seconds(data, "Wheat", 120), 120, "Wheat back to normal")
	data.inventory.items.Bread = 1
	data.pens.CowBarn.animals[1].readyAt = 400
	eq(table.concat(Tutorial.advance(data, 200), ","), "Bread,Feed", "fed")
	data.inventory.items.Milk = 1
	eq(table.concat(Tutorial.advance(data, 400), ","), "Milk", "collected")
	data.level = 3
	data.factories.FeedMill.built = true
	data.factories.FeedMill.queue = { { recipe = "CowFeed", seconds = 300, qty = 3 } }
	eq(table.concat(Tutorial.advance(data, 400), ","), "Level3,FeedMill,CowFeed", "Feed Mill running")
	data.level = 4
	eq(table.concat(Tutorial.advance(data, 400), ","), "Level4", "the first House is next")
	table.insert(data.town.houses, { type = "LeanTo", lot = 5, readyAt = 460 })
	data.factories.Dairy.built = true
	data.factories.Dairy.constructionReadyAt = 4000
	eq(table.concat(Tutorial.advance(data, 400), ","), "House", "Dairy building")
	ok(Tutorial.freeFinish(data, "Dairy"), "the first Finish is free")
	ok(not Tutorial.freeFinish(data, "Bakery"), "only on the Dairy")
	data.factories.Dairy.constructionReadyAt = 400
	data.land[1] = { readyAt = 9000 }
	data.level = 5
	eq(table.concat(Tutorial.advance(data, 400), ","), "Dairy,Land,Level5", "level 5")
	ok(not Tutorial.freeFinish(data, "Dairy"), "free only while its step is on")
	eq(Tutorial.current(data).id, "WrapUp", "ends on a tap")
	eq(#Tutorial.advance(data, 500), 0, "the last step waits for Got it")
end)

test("the guide moves on when the player does the next step first", function()
	local data = Profile.migrate(nil) :: any
	Profile.welcome(data, 100)
	Tutorial.start(data, 100)
	-- Harvested two of the three ripe fields and replanted one; the third is still ripe
	data.fields.F1 = { crop = "Wheat", plantedAt = 110, readyAt = 140 }
	data.fields.F2 = {}
	eq(table.concat(Tutorial.advance(data, 110), ","), "Harvest,Plant", "went around the last ripe field")
	eq(Tutorial.current(data).id, "Ship", "on to the order")
	-- The replanted Wheat ripens before the order ships: the guide doesn't fall back
	data.orders.delivered = 1
	eq(table.concat(Tutorial.advance(data, 200), ","), "Ship", "shipped")
	eq(Tutorial.current(data).id, "Level2", "next")
	-- Nothing ahead done: it waits
	eq(#Tutorial.advance(data, 200), 0, "waits for level 2")
end)

test("decorations snap to the grid, stay on owned land and don't overlap", function()
	local data = Profile.migrate(nil) :: any
	local x, z = DecorRules.snap("OakTree", 0, 9, 1)
	eq(x, 8, "2x2 centres on a grid line")
	eq(z, 0, "z too")
	x, z = DecorRules.snap("GravelPath", 0, 9, 1)
	eq(x, 10, "1x1 centres mid-tile")
	local w, d = DecorRules.footprint("Bench", 1)
	eq(w * 10 + d, 12, "a turned bench is 1 x 2")
	local tree = { id = "OakTree", x = 8, z = 0, r = 0 }
	ok((DecorRules.canPlace(data, tree, 0)), "fits")
	table.insert(data.decor, tree)
	local bench = { id = "Bench", x = 12, z = 2, r = 0 }
	local fits, why = DecorRules.canPlace(data, bench, 0)
	eq(fits, false, "overlaps the tree")
	eq(why, "Something is already there", "says why")
	ok((DecorRules.canPlace(data, { id = "Bench", x = 16, z = 2, r = 0 }, 0)), "touching edges are fine")
	eq((DecorRules.canPlace(data, { id = "GravelPath", x = -50, z = 0, r = 0 }, 0)), false, "West Meadow not cleared")
	data.land[1] = { readyAt = 10 }
	ok((DecorRules.canPlace(data, { id = "GravelPath", x = -50, z = 0, r = 0 }, 10)), "cleared land is yours")
	ok((DecorRules.canPlace(data, { id = "OakTree", x = -48, z = 0, r = 0 }, 10)), "across the edge")
	eq(DecorRules.refund("StoneFountain"), 1000, "50% back")
	ok(DecorRules.isBig("OakTree") and not DecorRules.isBig("Bench"), "2 x 2 and up is big")
	data.decor = {}
	for i = 1, Decor.maxBig do
		data.decor[i] = { id = "OakTree", x = 0, z = 0, r = 0 }
	end
	eq((DecorRules.hasRoom(data, "Pond")), false, "big cap")
	ok((DecorRules.hasRoom(data, "GravelPath")), "small ones still fit")
	for i = Decor.maxBig + 1, Decor.maxPlaced do
		data.decor[i] = { id = "GravelPath", x = 0, z = 0, r = 0 }
	end
	eq((DecorRules.hasRoom(data, "GravelPath")), false, "overall cap")
end)

test("the daily calendar resets after a missed day", function()
	local data = Profile.migrate(nil) :: any
	local day1 = 20000 * 86400 + 3600
	eq((DailyRules.due(data, day1)), nil, "opens at level 5")
	data.level = 5
	local reward, day = DailyRules.due(data, day1)
	eq(day, 1, "day 1")
	eq(reward.coins, 100, "100 Coins")
	DailyRules.claim(data, day1, day)
	eq((DailyRules.due(data, day1 + 3600)), nil, "once per UTC day")
	reward, day = DailyRules.due(data, day1 + 86400)
	eq(day, 2, "the next day is day 2")
	eq(reward.item, "Nails", "Barn material until tools ship")
	DailyRules.claim(data, day1 + 86400, day)
	reward, day = DailyRules.due(data, day1 + 3 * 86400)
	eq(day, 1, "a missed day starts the round again")
	data.daily.day = 7
	data.daily.lastDay = DailyRules.utcDay(day1 + 5 * 86400)
	data.level = 12
	reward, day = DailyRules.due(data, day1 + 6 * 86400)
	eq(day, 1, "repeats after day 7")
	eq(reward.coins, 150, "x1.5 Coins from level 11")
end)

test("the away summary lists what finished", function()
	local data = Profile.migrate(nil) :: any
	eq(#Away.summary(data, 0, 10000), 0, "nothing for a new farm")
	data.fields.F1 = { crop = "Wheat", readyAt = 500 }
	data.factories.Bakery.built = true
	data.factories.Bakery.constructionReadyAt = 900
	data.factories.Bakery.output = { Bread = 2 }
	data.pens.CowBarn.animals[1].readyAt = 800
	local lines = Away.summary(data, 600, 5000)
	eq(#lines, 4, table.concat(lines, " | "))
	ok(table.find(lines, "1 field is ready to harvest") ~= nil, "fields")
	ok(table.find(lines, "Bakery finished building") ~= nil, "construction since last seen")
	eq(#Away.summary(data, 4900, 5000), 0, "a short break gets no summary")
end)

test("Barn upgrades follow the Township steps", function()
	eq(BarnRules.capacity(0), 50, "start")
	eq(BarnRules.capacity(1), 70, "1")
	eq(BarnRules.capacity(3), 110, "+20 to 3")
	eq(BarnRules.capacity(4), 135, "+25 from 4")
	eq(BarnRules.capacity(38), 985, "38")
	eq(BarnRules.capacity(39), 1035, "+50 from 39")
	eq(BarnRules.capacity(58), 1985, "58")
	eq(BarnRules.capacity(59), 2060, "+75 from 59")
	local cost = BarnRules.upgradeCost(4)
	eq(cost.Nails, 4, "n of each")
	eq(cost.Hinges, 4, "Hinges")
	eq(cost.Paint, 4, "Paint")
	eq(Items.Paint.sellPrice, 0, "Barn materials can't be sold")
	eq(Profile.migrate(nil).inventory.upgrades, 0, "saved")
end)

test("Population brings fields; later ones need the West Meadow", function()
	local data = Profile.migrate(nil) :: any
	eq(#TownRules.fieldsToPlace(data, 0), 0, "none at Population 60")
	-- Population 100: fields 7-11 earned (65, 70, 75, 85, 95)
	table.insert(data.town.houses, { type = "Duplex", lot = 5 })
	table.insert(data.town.houses, { type = "LeanTo", lot = 6 })
	table.insert(data.town.houses, { type = "LeanTo", lot = 7 })
	eq(TownRules.population(data, 0), 100, "Population")
	local place = TownRules.fieldsToPlace(data, 0)
	eq(#place, 4, "7-10 fit in the start area")
	eq(place[1].field, 7, "first")
	eq(place[1].xp, 2, "XP on placing")
	eq(TownRules.fieldsWaiting(data, 0), 1, "field 11 waits for land")
	for _, unlock in place do
		data.fields["F" .. unlock.field] = {}
	end
	data.land[1] = { readyAt = 50 }
	eq(#TownRules.fieldsToPlace(data, 10), 0, "still clearing")
	eq(TownRules.fieldsToPlace(data, 50)[1].field, 11, "placed once cleared")
end)

test("land expansions go in order and need Population", function()
	local data = Profile.migrate(nil) :: any
	eq((TownRules.canExpand(data, 0)), true, "first needs 60")
	eq(TownRules.nextExpansion(data).coinCost, 25, "Township baseline cost")
	data.land[1] = { readyAt = 100 }
	local can, why = TownRules.canExpand(data, 50)
	eq(can, false, "first still clearing")
	ok(why and why:find("Finish"), "says why")
	can, why = TownRules.canExpand(data, 100)
	eq(can, false, "second needs 75")
	ok(why and why:find("75"), "says the need")
end)

test("visiting and helping follow the owner's settings, and blocks always win", function()
	eq(SocialRules.canVisit("Open", false, false), true, "open farm")
	eq(SocialRules.canVisit("Friends", false, false), false, "friends-only, stranger")
	eq(SocialRules.canVisit("Friends", true, false), true, "friends-only, friend")
	eq(SocialRules.canVisit("Closed", true, false), false, "closed")
	eq(SocialRules.canVisit("Open", true, true), false, "blocked")
	eq(SocialRules.canHelp("Friends", false, false), false, "helpers: friends, stranger")
	eq(SocialRules.canHelp("Friends", true, false), true, "helpers: friends, friend")
	eq(SocialRules.canHelp("Anyone", false, false), true, "helpers: anyone")
	eq(SocialRules.canHelp("Nobody", true, false), false, "helpers: nobody")
	eq(SocialRules.canHelp("Anyone", true, true), false, "blocked helper")
	local social = Profile.template().social
	eq(social.privacy, "Open", "default privacy")
	eq(social.helpers, "Friends", "default helpers")
end)

test("one daily help budget: 40 actions, 15 on one farm, fresh each UTC day", function()
	local social = Profile.template().social
	local day = 20000
	for _ = 1, Social.helpPerOwnerPerDay do
		ok(SocialRules.spendHelp(social, 111, day), "help on farm 111")
	end
	ok(not SocialRules.spendHelp(social, 111, day), "farm 111 is capped")
	local spent = Social.helpPerOwnerPerDay
	local owner = 200
	while spent < Social.helpPerDay do
		if SocialRules.spendHelp(social, owner, day) then
			spent += 1
		else
			owner += 1
		end
	end
	ok(not SocialRules.spendHelp(social, 999, day), "daily budget spent")
	local total, onOwner = SocialRules.helpLeft(social, 111, day + 1)
	eq(total, Social.helpPerDay, "new day")
	eq(onOwner, Social.helpPerOwnerPerDay, "new day, same farm")
end)

test("watering, helper Coins and Good Neighbors", function()
	eq(SocialRules.wateredReadyAt(1000, 0), 900, "10% off the time left")
	eq(SocialRules.wateredReadyAt(1000, 1000), 1000, "a ready field stays ready")
	eq(SocialRules.helperCoins(1, 2), 1, "at least 1 Coin")
	eq(SocialRules.helperCoins(20, 2), 4, "10% of the field's sell value")
	eq(SocialRules.neighborBonus(0), 0, "alone")
	eq(SocialRules.neighborBonus(1), 0.05, "one friend")
	eq(SocialRules.neighborBonus(5), 0.10, "capped")
	eq(SocialRules.bonusCoins(100, 0.05), 5, "+5%")
	eq(SocialRules.bonusCoins(10, 0.05), 1, "at least 1")
	eq(SocialRules.bonusCoins(100, 0), 0, "no bonus")
end)

test("the Welcome Boost: 15 minutes, once per friend a day, crops 10% faster", function()
	local social = Profile.template().social
	local now = 20000 * 86400 + 100
	eq(SocialRules.boostActive(social, now), false, "off at first")
	ok(SocialRules.grantBoost(social, 42, now), "first join today")
	eq(SocialRules.boostActive(social, now + Social.welcomeSeconds - 1), true, "on")
	eq(SocialRules.boostActive(social, now + Social.welcomeSeconds), false, "over")
	ok(not SocialRules.grantBoost(social, 42, now + 60), "same friend, same day")
	ok(SocialRules.grantBoost(social, 43, now + 60), "another friend")
	eq(social.boostUntil, now + 2 * Social.welcomeSeconds, "a second friend extends it")
	ok(SocialRules.grantBoost(social, 42, now + 86400), "next day")
	eq(SocialRules.growSeconds(120, false), 120, "no boost")
	eq(SocialRules.growSeconds(120, true), 108, "boosted")
	eq(SocialRules.growSeconds(1, true), 1, "never below 1 s")
end)

test("an old save gains the starter town", function()
	local data = Profile.migrate({ version = 1 }) :: any
	eq(TownRules.population(data, 0), 60, "starter Houses")
end)

---------------------------------------------------------------------------------------------
-- Rng and OrderGen
---------------------------------------------------------------------------------------------

test("rng is deterministic and in range", function()
	local a1, s1 = Rng.next(12345)
	local a2, s2 = Rng.next(12345)
	eq(a1, a2, "same value")
	eq(s1, s2, "same seed")
	local seed = 7
	for _ = 1, 1000 do
		local n
		n, seed = Rng.int(seed, 2, 5)
		ok(n >= 2 and n <= 5 and n % 1 == 0, "int in range")
	end
end)

test("order slots by level", function()
	eq(OrderGen.slotsFor(1), 3)
	eq(OrderGen.slotsFor(3), 4)
	eq(OrderGen.slotsFor(12), 7)
	eq(OrderGen.slotsFor(30), OrderConfig.maxSlots)
end)

test("reward formula", function()
	-- 4 Wheat: value 4, XP 4 * 1 = 4; Coins = round(4 * 1.31 * 1.00) = 5, XP = round(4 * 1.5) = 6
	local coins, xp = OrderGen.rewards({ Wheat = 4 }, 1)
	eq(coins, 5, "coins")
	eq(xp, 6, "xp")
end)

test("generated orders are valid, unlocked and reproducible", function()
	local pool = { "Wheat", "Corn", "Bread" }
	for level = 1, 12 do
		local seed = level * 101
		local existing = {}
		for _ = 1, 7 do
			local order, nextSeed =
				OrderGen.generate({ level = level, seed = seed, pool = pool, existing = existing, now = 0 })
			local again = OrderGen.generate({ level = level, seed = seed, pool = pool, existing = existing, now = 0 })
			assert(order and again, "an order")
			eq(order.id, again.id, "reproducible")
			local lines = 0
			for item, qty in order.wants do
				lines += 1
				ok(Items[item].unlockLevel <= level, item .. " unlocked at level " .. level)
				ok(qty >= 1 and qty % 1 == 0, "whole quantity")
			end
			ok(lines >= 1 and lines <= 4, "line count")
			ok(order.rewardCoins >= 1 and order.rewardXP >= 1, "pays something")
			table.insert(existing, order)
			seed = nextSeed
		end
	end
end)

test("the first card on an empty board is crops-only", function()
	for seed = 1, 50 do
		local order =
			OrderGen.generate({ level = 5, seed = seed, pool = { "Wheat", "Corn", "Bread" }, existing = {}, now = 0 })
		ok(order and OrderGen.isCropsOnly(order), "crops-only guarantee")
	end
end)

test("the order pool only holds what the farm can make, and never feed", function()
	local data = Profile.migrate(nil) :: any
	local function has(pool: { string }, id: string): boolean
		return table.find(pool, id) ~= nil
	end
	local pool = OrderGen.makeablePool(data)
	ok(has(pool, "Wheat") and has(pool, "Cotton"), "crops")
	ok(not has(pool, "Milk"), "no Milk without Cow Feed")
	data.inventory.items.CowFeed = 1
	ok(has(OrderGen.makeablePool(data), "Milk"), "Milk once there's feed")
	data.inventory.items.CowFeed = nil
	data.factories.FeedMill.built = true
	data.factories.Dairy.built = true
	pool = OrderGen.makeablePool(data)
	ok(has(pool, "Milk") and has(pool, "Cheese"), "Milk and Cheese with a Feed Mill and Dairy")
	ok(not has(pool, "CowFeed"), "feed is never ordered")
	ok(not has(pool, "Cookies"), "no Cookies without a Bakery and Chickens")
	data.factories.Bakery.built = true
	ok(not has(OrderGen.makeablePool(data), "Cookies"), "still no Eggs")
	data.pens.ChickenCoop.built = true
	ok(has(OrderGen.makeablePool(data), "Cookies"), "Cookies once Chickens are in")
end)

---------------------------------------------------------------------------------------------
-- Profile
---------------------------------------------------------------------------------------------

test("new profile uses the Township starting wallet", function()
	local data = Profile.migrate(nil) :: any
	eq(data.version, Profile.VERSION, "version")
	eq(data.currencies.Coins, 500, "coins")
	eq(data.currencies.Gems, 30, "gems")
	eq(data.inventory.barnCapacity, 50, "barn")
	local fields = 0
	for _ in data.fields do
		fields += 1
	end
	eq(fields, 6, "six fields")
	eq(data.factories.Bakery.slots, 3, "bakery slots")
	eq(data.factories.SugarMill.slots, 2, "sugar mill slots")
	ok(data.pens.CowBarn.built, "Cow Barn given")
	eq(#data.pens.CowBarn.animals, 3, "three Cows")
	ok(not data.pens.ChickenCoop.built, "Chicken Coop not built")
end)

test("a new farm gets its starter feed once", function()
	local data = Profile.migrate(nil) :: any
	ok(Profile.welcome(data, 1000), "welcomed")
	eq(data.inventory.items.CowFeed, Balance.starterCowFeed, "starter feed")
	eq(data.meta.createdAt, 1000, "created")
	data.inventory.items.CowFeed = nil -- fed it all
	ok(not Profile.welcome(data, 2000), "only once")
	local again = Profile.migrate(data) :: any
	eq(again.inventory.items.CowFeed, nil, "a reload doesn't refill it")
end)

test("an old save gains the new factories and the Cow Barn", function()
	local old = { version = 1, factories = { Bakery = { built = true, slots = 3, queue = {}, output = {} } } }
	local data = Profile.migrate(old) :: any
	ok(data.factories.Bakery.built, "kept the Bakery")
	ok(data.factories.FeedMill ~= nil and not data.factories.FeedMill.built, "Feed Mill to build")
	eq(#data.pens.CowBarn.animals, 3, "Cows")
end)

test("reconcile fills missing keys and keeps extra ones", function()
	local old = { version = 1, currencies = { Coins = 7 }, futureThing = { keep = true } }
	local data = Profile.migrate(old) :: any
	eq(data.currencies.Coins, 7, "kept coins")
	eq(data.currencies.Gems, 30, "filled gems")
	ok(data.futureThing.keep, "kept unknown key")
	ok(data.fields.F1 ~= nil, "filled fields")
end)

test("a profile from a newer build is refused", function()
	local data, reason = Profile.migrate({ version = Profile.VERSION + 1 })
	eq(data, nil, "no data")
	eq(reason, "newer", "reason")
end)

test("records: counters, read stats, claiming tiers in order", function()
	local data = Profile.template()
	assert(Records.ready(data, "Harvest", 0) == nil, "nothing ready on a new farm")
	Records.add(data, "harvest", 499)
	assert(Records.ready(data, "Harvest", 0) == nil, "one short")
	Records.add(data, "harvest", 1)
	assert(Records.ready(data, "Harvest", 0) == 1, "Bronze ready")
	local tier, def = Records.claim(data, "Harvest", 0)
	assert(tier == 1 and type(def) == "table" and def.gems[1] == 1, "Bronze claimed")
	assert(Records.claim(data, "Harvest", 0) == nil, "Silver not reached yet")
	assert(Records.claim(data, "Nope", 0) == nil and Records.claim(data, 5, 0) == nil, "junk ids refused")
	data.orders.delivered = 2000
	assert(Records.claim(data, "Orders", 0) == 1 and Records.claim(data, "Orders", 0) == 2, "one tier per claim")
	assert(Records.claim(data, "Orders", 0) == 3 and Records.claim(data, "Orders", 0) == nil, "Gold is the last")
	local views = Records.view(data, 0)
	assert(Records.stars(views) == 4, "four stars")
	assert(Records.title(Records.stars(views)) == "Farmhand", "title from stars")
	assert(Records.value(data, "houses", 0) >= 1, "starter houses count")
end)

test("settings: defaults in new profiles, checked values, the Gem confirm", function()
	local profile = Profile.template()
	eq(profile.settings.lastSeed, "Wheat", "lastSeed kept")
	eq(profile.settings.music, 10, "music default")
	eq(profile.settings.gemConfirm, "Always", "confirm default")
	-- An old save without the new keys gets them, and keeps its lastSeed
	local old = Profile.template()
	old.settings = { lastSeed = "Corn" }
	local migrated = Profile.migrate(old) :: any
	eq(migrated.settings.lastSeed, "Corn", "old lastSeed")
	eq(migrated.settings.textSize, "Normal", "text size filled in")
	ok(Settings.valid("music", 0) and Settings.valid("music", 10), "volume ends")
	ok(not Settings.valid("music", 11) and not Settings.valid("music", 2.5), "volume range and steps")
	ok(not Settings.valid("lastSeed", "Corn"), "lastSeed isn't a player option")
	ok(not Settings.valid("textSize", "Huge") and Settings.valid("textSize", "Large"), "choices")
	ok(Settings.valid("reduceMotion", true) and not Settings.valid("reduceMotion", "yes"), "toggle")
	ok(not Settings.valid({}, 1) and not Settings.valid(nil, nil), "junk keys")
	ok(Settings.confirmGems(nil, 1), "asks by default")
	ok(not Settings.confirmGems({ gemConfirm = "Over 10" }, 10), "10 Gems is one tap with Over 10")
	ok(Settings.confirmGems({ gemConfirm = "Over 10" }, 11), "11 Gems asks with Over 10")
	ok(not Settings.confirmGems({ gemConfirm = "Never" }, 500), "never asks")
	eq(Settings.get({ music = "loud" }, "music"), 10, "a bad saved value reads as the default")
end)

test("each level's unlocks come from the configs", function()
	local function has(level: number, kind: string, id: string): boolean
		for _, unlock in Unlocks.at(level) do
			if unlock.kind == kind and unlock.id == id then
				return true
			end
		end
		return false
	end
	ok(has(2, "Factory", "Bakery") and has(2, "Recipe", "Bread"), "level 2: Bakery and Bread")
	ok(has(3, "Crop", "Corn") and has(3, "Factory", "FeedMill"), "level 3: Corn and the Feed Mill")
	ok(has(5, "Pen", "ChickenCoop") and has(5, "Feature", "Daily"), "level 5: Chickens and daily gifts")
	ok(not has(1, "Pen", "CowBarn"), "the Cow Barn comes with the farm")
	ok(has(5, "Community", "VillageWell"), "Community Buildings")
	ok(has(4, "House", "LeanTo"), "Houses")
	ok(#Unlocks.at(99) == 0, "nothing past the content")
	local list = Unlocks.at(5)
	for i = 2, #list do
		ok(list[i - 1].kind ~= "Feature" or list[i].kind == "Feature", "features last")
	end
end)

test("buying what's missing: only the short items, priced from the item's production", function()
	local stock = { Wheat = 5, Eggs = 1 }
	local lines = Missing.list({ Wheat = 2, Eggs = 3, Sugar = 1 }, function(item)
		return stock[item] or 0
	end)
	eq(#lines, 2, "Wheat is covered")
	eq(lines[1].item, "Eggs", "sorted by name")
	eq(lines[1].qty, 2, "2 Eggs short")
	eq(Missing.describe(lines), "2 Eggs, 1 Sugar")
	eq(Missing.unitPrice("Bricks"), Town.materialGemPrice, "building material")
	eq(Missing.unitPrice("Nails"), Barn.materialGemPrice, "Barn material")
	eq(Missing.unitPrice("Wheat"), math.max(1, Speedup.production(Items.Wheat.unitSeconds)), "crop")
	ok(Missing.unitPrice("Bagel") :: number >= Missing.unitPrice("Bread") :: number, "longer chains cost more")
	ok(Missing.unitPrice("Nope") == nil, "unknown items can't be bought")
	eq(Missing.price({}), 0, "nothing missing is free")
	eq(Missing.price({ { item = "Bricks", qty = 2 } }), 2 * Town.materialGemPrice, "per unit")
	eq(Missing.price({ { item = "Nope", qty = 1 } }), nil, "a list with an unknown item")
	for id, item in Items do
		if item.kind ~= "Material" then
			ok((Missing.unitPrice(id) :: number) >= 1, id .. " costs at least 1 Gem")
		end
	end
end)

---------------------------------------------------------------------------------------------
-- UI theme (uitheme/, Design/25 UI Style Guide): the pure parts, loaded with Lune's Color3
---------------------------------------------------------------------------------------------

local roblox = require("@lune/roblox")

local function loadTheme(name: string): any
	local path = "../uitheme/src/" .. name .. ".luau"
	return luau.load(fs.readFile(path), { debugName = path, environment = { Color3 = roblox.Color3 } })()
end

local Format = loadTheme("Format")
local Palette = loadTheme("Palette")

test("theme numbers abbreviate like 11 UI & UX", function()
	eq(Format.short(0), "0", "zero")
	eq(Format.short(9999), "9999", "below 10K")
	eq(Format.short(12400), "12.4K", "12.4K")
	eq(Format.short(12499), "12.4K", "rounds down")
	eq(Format.short(50000), "50K", "drops .0")
	eq(Format.short(3200000), "3.2M", "millions")
end)

test("theme brand colours match the 3D palette hex values", function()
	eq(Palette.coins:ToHex():upper(), "FFC93C", "Coins")
	eq(Palette.gems:ToHex():upper(), "29C7AC", "Gems")
	eq(Palette.xp:ToHex():upper(), "8BD346", "XP")
	eq(Palette.cream:ToHex():upper(), "FFF6E5", "cream")
	eq(Palette.cocoa:ToHex():upper(), "4A3426", "cocoa")
end)

test("theme buttons get their own lip, other colours a darker shade", function()
	for name, colors in Palette.button do
		eq(Palette.lipFor(colors.face), colors.lip, name .. " lip")
		ok(Palette.luminance(colors.lip) < Palette.luminance(colors.face), name .. " lip is darker")
	end
	local odd = roblox.Color3.fromRGB(100, 200, 50)
	ok(Palette.luminance(Palette.lipFor(odd)) < Palette.luminance(odd), "fallback lip is darker")
end)

test("theme text on coloured buttons stays readable", function()
	-- White text with an outline on every coloured face; cocoa text on the light neutral face
	for _, name in { "primary", "secondary", "premium", "attention", "danger" } do
		ok(Palette.luminance(Palette.button[name].face) < 0.8, name .. " face is dark enough for white text")
	end
	ok(Palette.luminance(Palette.button.neutral.face) > 0.8, "neutral face takes dark text")
end)

---------------------------------------------------------------------------------------------
-- Art models (tests/art.luau)
---------------------------------------------------------------------------------------------

require("./art")(test, eq, ok)

---------------------------------------------------------------------------------------------
-- Analytics helpers (tests/analytics.luau)
---------------------------------------------------------------------------------------------

require("./analytics")(test, eq, ok)

---------------------------------------------------------------------------------------------
-- Data safety (tests/datasafety.luau)
---------------------------------------------------------------------------------------------

require("./datasafety")(test, eq, ok)

---------------------------------------------------------------------------------------------
-- Daily Quests (tests/quests.luau)
---------------------------------------------------------------------------------------------

require("./quests")(test, eq, ok)
require("./seedcart")(test, eq, ok)

---------------------------------------------------------------------------------------------
-- Every Luau file compiles
---------------------------------------------------------------------------------------------

local function eachLuau(dir: string, fn: (string) -> ())
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			eachLuau(path, fn)
		elseif name:match("%.luau$") then
			fn(path)
		end
	end
end

for _, root in { "src", "tools", "../uitheme/src" } do
	eachLuau(root, function(path)
		test("compiles: " .. path, function()
			luau.compile(fs.readFile(path))
		end)
	end)
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
