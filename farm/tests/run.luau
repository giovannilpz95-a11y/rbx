--!strict
-- Unit tests for the pure shared modules, plus a compile check of every Luau file.
-- Run from the farm/ folder:  lune run tests/run.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Animals = require("../src/shared/Config/Animals")
local Away = require("../src/shared/Away")
local Balance = require("../src/shared/Config/Balance")
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
local Levels = require("../src/shared/Config/Levels")
local OrderConfig = require("../src/shared/Config/Orders")
local OrderGen = require("../src/shared/OrderGen")
local Pen = require("../src/shared/Pen")
local Profile = require("../src/shared/Profile")
local Progression = require("../src/shared/Progression")
local Recipes = require("../src/shared/Config/Recipes")
local Rng = require("../src/shared/Rng")
local Social = require("../src/shared/Config/Social")
local SocialRules = require("../src/shared/Social")
local Speedup = require("../src/shared/Speedup")
local Timer = require("../src/shared/Timer")
local Town = require("../src/shared/Config/Town")
local TownRules = require("../src/shared/TownRules")
local Tutorial = require("../src/shared/Tutorial")

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
			ok(recipe.unlockLevel <= 12, id .. " unlocks past the MVP cap")
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
	-- Cow Feed: (5 min + 2 Wheat * 60 s + 1 Corn * 150 s) / 3 bags = 190 s a bag
	eq(Items.CowFeed.unitSeconds, 190, "Cow Feed")
	-- Milk: 20 min + a third of a bag
	ok(math.abs(Items.Milk.unitSeconds - (1200 + 190 / 3)) < 1e-6, "Milk")
	ok(Items.Cheese.unitSeconds > 2 * Items.Milk.unitSeconds, "Cheese includes its Milk")
	ok(Items.CowFeed.isFeed and not Items.Milk.isFeed, "feed flag")
end)

test("no item id is both a crop and a recipe", function()
	for id in Recipes do
		ok(Crops[id] == nil, id .. " is both")
	end
end)

test("levels run 1..cap in order", function()
	eq(#Levels.list, Levels.cap, "level rows")
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
	eq(Speedup.nextSlotCost(3, 6), 20, "fourth extra")
	eq(Speedup.nextSlotCost(3, 7), nil, "max")
	eq(Speedup.nextSlotCost(2, 6), 24, "fifth extra (Sugar Mill)")
end)

test("a pen's speed-up prices each producing animal", function()
	local pen = { animals = { { readyAt = 100 + 600 }, { readyAt = 100 + 3600 }, {}, { readyAt = 50 } } }
	-- 10 min -> 2, 1 h -> 6, hungry and ready ones are free
	eq(Speedup.pen(pen, 100), 8, "sum")
end)

---------------------------------------------------------------------------------------------
-- Town (07 Town Building)
---------------------------------------------------------------------------------------------

test("a new farm starts at Population 60 with Cap 80", function()
	local data = Profile.migrate(nil) :: any
	eq(TownRules.population(data, 0), 60, "starter Houses")
	eq(TownRules.cap(data, 0), 80, "base Cap")
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
	eq(can, false, "75 + 10 > 80")
	ok(why and why:find("Community Building"), "asks for a Community Building")
	data.town.community.VillageWell = { readyAt = 200 }
	eq(TownRules.cap(data, 150), 80, "Cap waits for the Well")
	eq(TownRules.cap(data, 200), 90, "Well done")
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

test("Township baseline town rows", function()
	eq(Town.houses.RowHouse.population, 20, "Row House")
	eq(Town.houses.Townhouse.coinCost, 105, "Townhouse cost")
	eq(Town.community.Bandstand.capBonus, 55, "Bandstand")
	eq(Town.community.FireHall.materials.Bricks, 2, "Fire Hall bricks")
	eq(Factories.Dairy.population, 65, "Dairy needs 65")
	eq(Factories.TextileMill.population, 105, "Textile Mill needs 105")
	local total = 0
	for _, def in Town.community do
		total += def.capBonus
		ok(def.unlockLevel <= 12, def.id .. " past the MVP")
		for material in def.materials do
			ok(Town.materials[material] ~= nil and Items[material].kind == "Material", def.id .. " " .. material)
		end
	end
	eq(Town.baseCap + total, 390, "Cap with every MVP Community Building")
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
	eq(data.orders.board[1].order.wants.Wheat, 4, "an easy first order")
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
	eq(DecorRules.refund("StoneFountain"), 500, "25% back")
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

test("the daily calendar pauses instead of resetting", function()
	local data = Profile.migrate(nil) :: any
	local day1 = 20000 * 86400 + 3600
	eq((DailyRules.due(data, day1)), nil, "opens at level 5")
	data.level = 5
	local reward, day = DailyRules.due(data, day1)
	eq(day, 1, "day 1")
	eq(reward.coins, 100, "100 Coins")
	DailyRules.claim(data, day1, day)
	eq((DailyRules.due(data, day1 + 3600)), nil, "once per UTC day")
	reward, day = DailyRules.due(data, day1 + 5 * 86400)
	eq(day, 2, "a missed day pauses the calendar")
	eq(reward.item, "Nails", "Barn material until tools ship")
	data.daily.day = 7
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
	-- 4 Wheat: value 4, XP 4 * 0.5 = 2; Coins = round(4 * 1.31 * 1.00) = 5, XP = round(2 * 1.5) = 3
	local coins, xp = OrderGen.rewards({ Wheat = 4 }, 1)
	eq(coins, 5, "coins")
	eq(xp, 3, "xp")
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
