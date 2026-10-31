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
local Blimp = require("../src/shared/Blimp")
local BlimpConfig = require("../src/shared/Config/Blimp")
local Express = require("../src/shared/Express")
local ExpressConfig = require("../src/shared/Config/Express")
local Market = require("../src/shared/Market")
local Layout = require("../src/shared/Layout")
local MarketConfig = require("../src/shared/Config/Market")
local BarnRules = require("../src/shared/BarnRules")
local Crops = require("../src/shared/Config/Crops")
local DailyRules = require("../src/shared/Daily")
local Decor = require("../src/shared/Config/Decor")
local DecorRules = require("../src/shared/DecorRules")
local Badges = require("../src/shared/Badges")
local BadgesConfig = require("../src/shared/Config/Badges")
local RecordsConfig = require("../src/shared/Config/Records")
local Trophies = require("../src/shared/Config/Trophies")
local Drops = require("../src/shared/Drops")
local Products = require("../src/shared/Config/Products")
local Shop = require("../src/shared/Shop")
local Prize = require("../src/shared/Config/Prize")
local PrizeRules = require("../src/shared/Prize")
local Factories = require("../src/shared/Config/Factories")
local Items = require("../src/shared/Items")
local IslesConfig = require("../src/shared/Config/Isles")
local Land = require("../src/shared/Config/Land")
local Levels = require("../src/shared/Config/Levels")
local Lots = require("../src/shared/Lots")
local OrderConfig = require("../src/shared/Config/Orders")
local OrderGen = require("../src/shared/OrderGen")
local Pen = require("../src/shared/Pen")
local Profile = require("../src/shared/Profile")
local Progression = require("../src/shared/Progression")
local Quarry = require("../src/shared/Quarry")
local QuarryConfig = require("../src/shared/Config/Quarry")
local Guild = require("../src/shared/Guild")
local GuildConfig = require("../src/shared/Config/Guild")
local Recipes = require("../src/shared/Config/Recipes")
local Records = require("../src/shared/Records")
local Missing = require("../src/shared/Missing")
local Rng = require("../src/shared/Rng")
local Settings = require("../src/shared/Settings")
local Social = require("../src/shared/Config/Social")
local SocialRules = require("../src/shared/Social")
local Speedup = require("../src/shared/Speedup")
local Tools = require("../src/shared/Config/Tools")
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
		ok(crop.unlockLevel >= 1 and crop.unlockLevel <= 60, id .. " unlock level in 1-60")
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
			-- Bars smelt Quarry ore, which lives in the Ore Shed rather than the Barn
			local exists = if recipe.fromOreShed then QuarryConfig.ores[input] ~= nil else Items[input] ~= nil
			ok(exists, id .. " input " .. input)
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
	for id in QuarryConfig.ores do
		enabled[id] = QuarryConfig.unlockLevel <= Levels.built -- dug in the Quarry
	end
	for id, good in IslesConfig.goods do
		enabled[id] = IslesConfig.byId[good.isle].unlockLevel <= Levels.built -- brought by Sailboats
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
	-- More Cow Barns in the content bank: their own price, the Cow Barn's cows
	eq(Animals.pens.CowBarn2.unlockLevel, 15, "second Cow Barn at 15")
	eq(Animals.pens.CowBarn2.buildCost, 1000, "second Cow Barn cost")
	eq(Animals.pens.CowBarn3.unlockLevel, 22, "third Cow Barn at 22")
	eq(Animals.pens.CowBarn3.extraAnimalCosts[1], 750, "third Cow Barn's 4th Cow")
	eq(Animals.pens.ChickenCoop2.unlockLevel, 24, "second Chicken Coop at 24")
	eq(Animals.pens.ChickenCoop2.buildCost, 3000, "second Chicken Coop cost")
	eq(Animals.pens.ChickenCoop2.extraAnimalCosts[3], 660, "second Chicken Coop's 6th Chicken")
	for id, def in Animals.pens do
		if def.copyOf then
			local original = Animals.pens[def.copyOf]
			ok(original ~= nil and original.copyOf == nil, id .. " copies an original pen")
			eq(def.feed, original.feed, id .. " eats the same feed")
			eq(def.product, original.product, id .. " makes the same product")
			ok(def.unlockLevel > Levels.cap and def.unlockLevel <= Levels.built, id .. " in the bank")
			-- Copies with a fixed spot stand on expansion land; from level 34 the player places them
			ok(def.land ~= nil or def.unlockLevel >= 34, id .. " waits for its land")
		end
	end
	eq(Factories.FeedMill.unlockLevel, 3, "Feed Mill level")
	eq(Factories.TextileMill.queueSlots, 2, "Textile Mill slots")
	eq(Recipes.CowFeed.outputQty, 3, "feed batch")
	eq(Recipes.Cheese.inputs.Milk, 2, "Cheese milk")
	eq(Recipes.Shirt.inputs.CottonFabric, 1, "Shirt fabric")
	-- Township keeps clothing in its own Tailor Shop (level 12), apart from the Textile Mill
	eq(Factories.Tailor.unlockLevel, 12, "Tailor level")
	eq(Factories.Tailor.population, 195, "Tailor needs 195")
	eq(Factories.Tailor.buildCost, 800, "Tailor cost")
	eq(Factories.Tailor.buildSeconds, 10 * 3600, "Tailor build (10 h)")
	eq(Factories.Tailor.xp, 38, "Tailor XP")
	for _, id in { "Shirt", "WoolScarf", "PatchworkQuilt" } do
		eq(Recipes[id].factory, "Tailor", id .. " made by the Tailor")
	end
	ok(table.find(Balance.enabledFactories, "Tailor") ~= nil, "Tailor enabled")
	eq(Guild.maxLevel("Tailor"), 53, "the Tailor has its own Guild table")
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
	eq(Levels.built, 45, "levels 17 to 45 are banked")
	eq(Recipes.Canape.inputs.Olives, 2, "Canapé from the isles' Olives and Grapes, and Cheese")
	eq(Recipes.KeyLimePie.inputs.KeyLimes, 2, "Key Lime Pie from the isles' Key Limes")
	eq(Levels.list[44].xpToNext, 84811, "L44 row")
	eq(Levels.list[45].xpToNext, 91481, "L45 row")
	eq(Factories.FeedMill3.makes, "FeedMill", "third Feed Mill makes feed")
	eq(Factories.FeedMill3.buildCost, 40000, "third Feed Mill cost")
	eq(Guild.maxLevel("FeedMill3"), Guild.maxLevel("FeedMill"), "the third Feed Mill uses the Feed Mill's table")
	eq(Factories.Smelter3.makes, "Smelter", "third Smelter makes Bars")
	ok(
		Factories.Smelter3.population == 4950 and Factories.Smelter3.buildCost == 15000,
		"third Smelter (Township's Foundry 3)"
	)
	eq(Recipes.Burrito.inputs.Bacon, 2, "Burrito from Wheat, Bacon and a Tomato")
	eq(Recipes.Chocolate.inputs.Cocoa, 3, "Chocolate from Cocoa, Cream and Sugar")
	eq(Town.houses.AtticTower.population, 140, "Attic Tower")
	eq(Town.community.Glasshouse.capBonus, 215, "Glasshouse")
	eq(Town.community.SplashPark.capBonus, 220, "Splash Park")
	eq(Levels.list[43].xpToNext, 78503, "L43 row")
	ok(table.find(Balance.enabledCrops, "Peppers") ~= nil and Crops.Peppers.growSeconds == 5 * 3600, "Peppers, 5 h")
	eq(Levels.gifts[43].Peppers, 3, "Peppers to start with")
	eq(Factories.Cantina.buildCost, 33000, "Cantina (Township's Mexican Restaurant)")
	eq(Guild.maxLevel("Cantina"), 52, "the Cantina has its own Guild table")
	eq(Recipes.ChiliSauce.inputs.Peppers, 3, "Chili Sauce from Tomatoes, Peppers and Sugar")
	eq(Recipes.GlazedBacon.inputs.Bacon, 2, "Glazed Bacon from Bacon and Cane Syrup")
	eq(Town.community.GroceryStore.capBonus, 210, "Grocery Store")
	eq(Levels.list[42].xpToNext, 72545, "L42 row")
	eq(Animals.pens.PigPen.buildCost, 12000, "Pig Pen (Township's Pig Farm)")
	eq(Animals.pens.PigPen.produceSeconds, 7 * 3600, "Bacon takes 7 h")
	eq(Animals.pens.PigPen.extraAnimalCosts[3], 3150, "Pigs 4 to 6")
	eq(Recipes.PigFeed.outputQty, 3, "Pig Feed comes in threes")
	eq(Recipes.CandyCane.inputs.Paper, 1, "Candy Cane from Caramel, Cream and Paper")
	eq(Recipes.Dumplings.inputs.Bacon, 2, "Dumplings from Dough and Bacon")
	eq(Town.houses.SkylineFlats.population, 120, "Skyline Flats")
	eq(Town.community.LifeboatStation.capBonus, 205, "Lifeboat Station")
	eq(Levels.list[41].xpToNext, 66924, "L41 row")
	eq(Town.community.ComicShop.capBonus, 200, "Comic Shop")
	eq(Levels.list[40].xpToNext, 61628, "L40 row")
	eq(Recipes.Toffee.inputs.Caramel, 1, "Toffee from Caramel and Butter")
	eq(Recipes.Plunger.inputs.Rubber, 1, "Plunger from a Pine Tree and Rubber")
	eq(Town.community.SkydivingSchool.capBonus, 195, "Skydiving School")
	eq(Levels.list[39].xpToNext, 56645, "L39 row")
	eq(Factories.CandyFactory.buildCost, 20000, "Candy Factory")
	eq(Factories.CandyFactory.population, 3190, "Candy Factory Population")
	eq(Guild.maxLevel("CandyFactory"), 53, "the Candy Factory has its own Guild table")
	eq(Recipes.JellyBeans.inputs.CaneSyrup, 1, "Jelly Beans from Strawberries and Cane Syrup")
	eq(Recipes.Clothesline.inputs.Sugarcane, 5, "Clothesline from Sugarcane and Nylon Thread")
	eq(Animals.pens.ChickenCoop3.buildCost, 15000, "third Chicken Coop")
	eq(Animals.pens.ChickenCoop3.extraAnimalCosts[3], 2550, "third Chicken Coop's 6th Chicken")
	ok(table.find(Balance.enabledPens, "ChickenCoop3") ~= nil, "third Chicken Coop enabled")
	eq(Town.houses.SkyGardenTower.population, 110, "Sky Garden Tower")
	eq(Town.community.WeatherStation.capBonus, 190, "Weather Station")
	eq(Levels.list[38].xpToNext, 51963, "L38 row")
	ok(table.find(Balance.enabledCrops, "CorkOak") ~= nil and Crops.CorkOak.growSeconds == 10 * 3600, "Cork Oak, 10 h")
	eq(Levels.gifts[38].CorkOak, 3, "Cork Oak to start with")
	eq(Recipes.InflatableBoat.inputs.Glue, 1, "Inflatable Boat from Rubber and Glue")
	eq(Recipes.SoapDispenser.inputs.CorkOak, 1, "Soap Dispenser from Cork Oak and a Plastic Bottle")
	eq(Town.community.PetParlor.capBonus, 185, "Pet Parlor")
	eq(Levels.list[37].xpToNext, 47571, "L37 row")
	eq(Factories.HomewaresShop.buildCost, 18000, "Homewares Shop (Township's Household Goods Factory)")
	eq(Factories.HomewaresShop.population, 3130, "Homewares Shop Population")
	eq(Guild.maxLevel("HomewaresShop"), 53, "the Homewares Shop has its own Guild table")
	eq(Recipes.ScrubBrush.inputs.NylonThread, 1, "Scrub Brush from Sugarcane and Nylon Thread")
	eq(Recipes.Glue.inputs.RubberTrees, 3, "Glue from 3 Rubber Trees")
	eq(Recipes.Ball.inputs.Glue, 1, "Ball from Plastic and Glue")
	eq(Recipes.HoneyGingerbread.inputs.Honeycomb, 2, "Honey Gingerbread from Wheat, Honeycomb and Eggs")
	eq(Town.houses.GardenCoop.population, 100, "Garden Co-op")
	eq(Town.community.SportsArena.capBonus, 180, "Sports Arena")
	eq(Levels.list[36].xpToNext, 43455, "L36 row")
	eq(Recipes.Cheesecake.inputs.Strawberries, 2, "Cheesecake (Township's inputs)")
	eq(Recipes.HoneyCaramel.inputs.Honeycomb, 1, "Honey Caramel from Honeycomb")
	eq(Recipes.Suit.inputs.SilkFabric, 1, "Suit from Yarn, Cotton Fabric and Silk Fabric")
	eq(Recipes.NylonThread.inputs.RubberTrees, 3, "Nylon Thread from 3 Rubber Trees")
	eq(Town.community.LoopCoaster.capBonus, 175, "Loop Coaster")
	eq(Levels.list[35].xpToNext, 39606, "L35 row")
	eq(Animals.pens.BeeYard.buildCost, 9000, "Bee Yard (Township's Apiary)")
	eq(Animals.pens.BeeYard.extraAnimalCosts[3], 1500, "Bee Hives 4 to 6")
	eq(Recipes.BeeFeed.outputQty, 3, "Bee Feed comes in threes")
	eq(Recipes.Toys.inputs.Rubber, 1, "Toys from Plastic and Rubber")
	eq(Town.community.SkyWheel.capBonus, 170, "Sky Wheel")
	eq(Levels.list[34].xpToNext, 36013, "L34 row")
	eq(Factories.MoldingWorks.buildCost, 15000, "Molding Works (Township's Plastics Factory)")
	eq(Factories.MoldingWorks.population, 2375, "Molding Works Population")
	eq(Recipes.PlasticBottle.inputs.Plastic, 1, "Plastic Bottle from Plastic")
	eq(Recipes.FrozenVegetables.inputs.Tomatoes, 1, "Frozen Vegetables from Tomatoes, Corn and Carrots")
	eq(Town.houses.CourtyardFlats.population, 90, "Courtyard Flats")
	eq(Town.community.SignalTower.capBonus, 165, "Signal Tower")
	eq(Guild.maxLevel("MoldingWorks"), 53, "the Molding Works has its own Guild table")
	eq(Levels.list[33].xpToNext, 32663, "L33 row")
	eq(Recipes.Dress.inputs.SilkFabric, 1, "Dress from Yarn and Silk Fabric")
	eq(Recipes.Donut.inputs.Cocoa, 1, "Donut from Bagel, Caramel and Cocoa")
	eq(Town.community.BroadcastStudio.capBonus, 160, "Broadcast Studio")
	eq(Levels.list[32].xpToNext, 29547, "L32 row")
	eq(Recipes.Plastic.inputs.RubberTrees, 2, "Plastic from 2 Rubber Trees")
	eq(Town.houses.Condos.copyLevels[1], 32, "Terrace Condos")
	eq(Town.community.GrandHotel.capBonus, 155, "Grand Hotel")
	eq(Levels.list[31].xpToNext, 26654, "L31 row")
	ok(table.find(Balance.enabledCrops, "Silk") ~= nil and Crops.Silk.growSeconds == 15 * 3600, "Silk at 31")
	eq(Recipes.SunHat.inputs.SilkFabric, 1, "Sun Hat (Township's inputs)")
	eq(Recipes.Dough.factory, "PrepKitchen", "Dough at the Prep Kitchen")
	eq(Factories.PrepKitchen.buildCost, 12000, "Prep Kitchen")
	eq(Animals.pens.SheepFold2.copyOf, "SheepFold", "second Sheep Fold")
	eq(Animals.pens.SheepFold2.buildCost, 8000, "second Sheep Fold cost")
	eq(Town.houses.IvyApartments.copyLevels[1], 31, "Ivy Apartments")
	eq(Town.community.OfficeBlock.capBonus, 150, "Office Block")
	eq(Levels.list[30].xpToNext, 23974, "L30 row")
	eq(Recipes.Wallpaper.inputs.Rubber, 1, "Wallpaper uses Rubber (Township's inputs)")
	eq(Recipes.Cupcake.inputs.Eggs, 5, "Cupcake")
	eq(Town.community.OpenAirCinema.capBonus, 145, "Open-Air Cinema")
	eq(Levels.list[29].xpToNext, 21495, "L29 row")
	ok(
		table.find(Balance.enabledCrops, "RubberTrees") ~= nil and Crops.RubberTrees.growSeconds == 12 * 3600,
		"Rubber Trees at 29"
	)
	eq(Levels.gifts[29].RubberTrees, 3, "Rubber Trees to start with")
	eq(Factories.RubberWorks.population, 1670, "Rubber Works Population")
	eq(Recipes.Rubber.inputs.RubberTrees, 1, "Rubber from a Rubber Tree")
	eq(Town.houses.BrickTownhouse.copyLevels[1], 29, "Brick Townhouse")
	eq(Town.community.CabStand.capBonus, 140, "Cab Stand")
	eq(Levels.list[28].xpToNext, 19210, "L28 row")
	eq(Recipes.Fries.factory, "Diner", "Fries at the Diner")
	eq(Recipes.Fries.inputs.Cream, 1, "Fries (Township's inputs)")
	eq(Town.houses.CanalHouse.copyLevels[1], 28, "Canal House")
	eq(
		Lots.community[TownRules.communityLot("FillingStation") :: number].land,
		Lots.westMeadowLand,
		"Filling Station in the West Meadow"
	)
	eq(Levels.list[27].xpToNext, 17108, "L27 row")
	eq(Recipes.StrawberryJam.factory, "JamKitchen", "Strawberry Jam at the Jam Kitchen")
	eq(Recipes.StrawberryJam.inputs.Strawberries, 3, "Strawberry Jam")
	eq(Recipes.Brownie.inputs.Cocoa, 2, "Brownie (Township's inputs)")
	eq(Factories.JamKitchen.population, 1480, "Jam Kitchen Population")
	eq(
		Lots.community[TownRules.communityLot("BusDepot") :: number].land,
		Lots.farCornersLand,
		"Bus Depot in the Far Corners"
	)
	eq(Levels.list[26].xpToNext, 15178, "L26 row")
	eq(Recipes.PotatoBread.inputs.Potatoes, 2, "Potato Bread (Township's inputs)")
	eq(Town.houses.HearthHouse.copyLevels[1], 24, "Hearth House")
	eq(Town.houses.TwinGables.copyLevels[1], 26, "Twin Gables")
	eq(
		Lots.community[TownRules.communityLot("BigTop") :: number].land,
		Lots.farCornersLand,
		"Big Top in the Far Corners"
	)
	eq(Levels.list[25].xpToNext, 13413, "L25 row")
	ok(table.find(Balance.enabledCrops, "Cocoa") ~= nil and Crops.Cocoa.unlockLevel == 25, "Cocoa at 25")
	eq(Levels.gifts[25].Cocoa, 3, "Cocoa to start with")
	eq(Recipes.IceCreamBar.inputs.CaneSyrup, 1, "Ice Cream Bar (Township's inputs)")
	eq(Recipes.IceCreamBar.inputs.PineTrees, 1, "Ice Cream Bar uses a Pine Tree")
	eq(
		Lots.community[TownRules.communityLot("SculpturePark") :: number].land,
		Lots.farCornersLand,
		"Sculpture Park in the Far Corners"
	)
	eq(Levels.list[24].xpToNext, 11802, "L24 row")
	eq(Recipes.Muffin.factory, "PastryShop", "Muffin at the Pastry Shop")
	eq(Recipes.Muffin.inputs.Eggs, 4, "Muffin (Township's inputs)")
	eq(Recipes.Caramel.inputs.Sugarcane, 3, "Caramel")
	eq(Factories.PastryShop.population, 1100, "Pastry Shop Population")
	eq(
		Lots.community[TownRules.communityLot("Amphitheatre") :: number].land,
		Lots.farCornersLand,
		"Amphitheatre in the Far Corners"
	)
	eq(Levels.list[23].xpToNext, 10338, "L23 row")
	eq(Recipes.PaperTowel.inputs.PineTrees, 2, "Paper Towels")
	eq(Recipes.FrozenYogurt.inputs.Yogurt, 1, "Frozen Yogurt")
	eq(
		Lots.community[TownRules.communityLot("BotanicalArch") :: number].land,
		Lots.farCornersLand,
		"Botanical Arch in the Far Corners"
	)
	eq(Levels.list[22].xpToNext, 9011, "L22 row")
	ok(table.find(Balance.enabledCrops, "Potatoes") ~= nil and Crops.Potatoes.unlockLevel == 22, "Potatoes at 22")
	eq(Levels.gifts[22].Potatoes, 3, "Potatoes to start with")
	eq(Recipes.PotatoChips.inputs.Potatoes, 2, "Potato Chips")
	eq(Recipes.GardenPizza.inputs.Cheese, 1, "Garden Pizza (Township's Pizza inputs)")
	eq(Town.houses.LakesideManor.copyLevels[1], 22, "Lakeside Manor")
	eq(
		Lots.community[TownRules.communityLot("PuppetTheatre") :: number].land,
		Lots.farCornersLand,
		"Puppet Theatre in the Far Corners"
	)
	eq(Levels.list[21].xpToNext, 7813, "L21 row")
	eq(Recipes.Yogurt.inputs.Milk, 4, "Yogurt (Township's inputs)")
	eq(Recipes.StrawberryIcePop.factory, "IceCreamParlor", "Strawberry Ice Pop")
	eq(Levels.list[20].xpToNext, 6736, "L20 row")
	eq(Recipes.IceCreamCone.factory, "IceCreamParlor", "Ice Cream Cone")
	eq(Recipes.PatchworkQuilt.inputs.Yarn, 1, "Patchwork Quilt")
	eq(Town.houses.CornerFlats.copyLevels[1], 20, "Corner Flats")
	eq(Levels.list[19].xpToNext, 5771, "L19 row")
	eq(Recipes.BerryGranola.inputs.Strawberries, 2, "Berry Granola (Township's Granola inputs)")
	eq(Recipes.BerrySandwich.inputs.Butter, 1, "Berry Sandwich (Township's Sandwich inputs)")
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
	ok(table.find(Balance.enabledCrops, "PineTrees") ~= nil and Crops.PineTrees.unlockLevel == 18, "Pine Trees at 18")
	eq(Recipes.Paper.inputs.PineTrees, 1, "Paper from Pine Trees")
	eq(Recipes.Paper.factory, "PaperMill", "Paper Mill makes Paper")
	for _, crop in Crops do
		eq(crop.yield, 1, crop.id .. " gives 1 per field, as in Township")
	end
	eq(Levels.list[17].xpToNext, 4149, "L17 row")
	for _, id in { "CornChips", "CaneSyrup" } do
		eq(Recipes[id].unlockLevel, 17, id .. " at 17")
		ok(table.find(Balance.enabledFactories, Recipes[id].factory) ~= nil, id .. "'s factory is enabled")
	end
	eq(Town.houses.ThatchedLonghouse.copyLevels[1], 17, "Thatched Longhouse")
	for _, id in { "Bathhouse", "ArtStudio", "MusicHall", "StargazingTower", "RoseGarden", "SeedExchange" } do
		local def = Town.community[id]
		ok(def.unlockLevel > Levels.cap and def.unlockLevel <= Levels.built, id .. " in the bank")
		eq(Lots.community[TownRules.communityLot(id) :: number].land, Lots.northLaneLand, id .. " stands on North Lane")
	end
	for _, id in
		{
			"SnackFactory",
			"Diner",
			"PaperMill",
			"FeedMill2",
			"IceCreamParlor",
			"PastryShop",
			"JamKitchen",
			"RubberWorks",
		}
	do
		ok(Factories[id].unlockLevel > Levels.cap and Factories[id].unlockLevel <= Levels.built, id .. " in the bank")
		ok(table.find(Balance.enabledFactories, id) ~= nil, id .. " enabled")
		eq(Factories[id].land, 2, id .. " stands in the East Meadow")
	end
	eq(Recipes.FarmBurger.inputs.Tomatoes, 1, "Farm Burger uses the bank's Tomatoes")
end)

test("the Quarry: Township's numbers, a fixed shaft and Pickaxe digging", function()
	eq(QuarryConfig.unlockLevel, 21, "opens at 21")
	eq(QuarryConfig.restoreCost, 3000, "3,000 Coins to reopen")
	eq(QuarryConfig.restoreSeconds, 30 * 3600, "1 d 6 h")
	eq(QuarryConfig.ores.CopperOre.sellPrice, 8, "Copper Ore sells for 8")
	local data = Profile.migrate(nil) :: any
	eq(data.quarry.readyAt, nil, "closed on a new farm")
	eq(next(data.oreShed), nil, "empty Ore Shed")
	local ok1, why = Quarry.canDig(data, 1, 1, 0)
	eq(ok1, false, "can't dig before it reopens")
	ok(why ~= nil, "says why")
	Quarry.restore(data, 100 + QuarryConfig.restoreSeconds, 12345)
	eq(Quarry.pickaxes(data), QuarryConfig.restoreGift, "opening Pickaxes")
	eq(Quarry.isRestored(data, 100 + QuarryConfig.restoreSeconds - 1), false, "still reopening")
	local now = 100 + QuarryConfig.restoreSeconds
	eq(Quarry.isRestored(data, now), true, "open")
	-- The same seed always gives the same shaft
	local seed = data.quarry.seed
	for row = 1, 40 do
		for col = 1, QuarryConfig.width do
			local a, b = Quarry.cell(seed, row, col), Quarry.cell(seed, row, col)
			eq(a.block, b.block, "fixed block")
			eq(a.find, b.find, "fixed find")
		end
	end
	-- Bedrock never sits beside Bedrock, and every row has room to dig
	for row = 1, 300 do
		local free = 0
		for col = 1, QuarryConfig.width do
			if Quarry.cell(seed, row, col).block == "Bedrock" then
				ok(Quarry.cell(seed, row, col + 1).block ~= "Bedrock", "no Bedrock pair across")
				ok(Quarry.cell(seed, row + 1, col).block ~= "Bedrock", "no Bedrock pair down")
				eq(Quarry.cell(seed, row, col).find, nil, "Bedrock holds nothing")
			else
				free += 1
			end
		end
		ok(free > 0, "row " .. row .. " can be dug")
	end
	-- Deeper ores only below their depth
	local seen: { [string]: number } = {}
	for row = 1, 400 do
		for col = 1, QuarryConfig.width do
			local find = Quarry.cell(seed, row, col).find
			if find and QuarryConfig.ores[find] then
				ok(row >= QuarryConfig.ores[find].fromDepth, find .. " not above its depth")
				seen[find] = (seen[find] or 0) + 1
			end
		end
	end
	for _, id in Quarry.ORE_IDS do
		ok((seen[id] or 0) > 0, id .. " turns up somewhere in 400 m")
	end
	ok(seen.CopperOre > seen.PlatinumOre, "copper is commoner than platinum")
	-- Digging: only next to an open spot, Stone takes two swings, a Pickaxe a swing
	eq((Quarry.canDig(data, 2, 1, now)), false, "row 2 is out of reach from the surface")
	local col = 1
	while Quarry.cell(seed, 1, col).block == "Bedrock" do
		col += 1
	end
	local cell = Quarry.cell(seed, 1, col)
	local before = Quarry.pickaxes(data)
	local result = Quarry.dig(data, 1, col)
	if cell.block == "Stone" then
		eq(result.cleared, false, "Stone stands after one swing")
		eq(Quarry.isOpen(data.quarry, 1, col), false, "not open yet")
		result = Quarry.dig(data, 1, col)
	end
	eq(result.cleared, true, "dug out")
	eq(Quarry.isOpen(data.quarry, 1, col), true, "open")
	eq(Quarry.depth(data.quarry), 1, "1 m down")
	local swings = if cell.block == "Stone" then 2 else 1
	local gift = if result.pickaxes then result.pickaxes else 0
	eq(Quarry.pickaxes(data), before - swings + gift, "a Pickaxe per swing")
	eq((Quarry.canDig(data, 1, col, now)), false, "already open")
	ok(Quarry.inReach(data.quarry, 2, col), "the cell below is in reach")
	-- Ore lands in the Ore Shed, never the Barn
	local oreRow, oreCol
	for row = 1, 60 do
		for c = 1, QuarryConfig.width do
			if Quarry.cell(seed, row, c).find == "CopperOre" and not oreRow then
				oreRow, oreCol = row, c
			end
		end
	end
	local copy = Profile.deepCopy(data)
	copy.quarry.rows[tostring(oreRow - 1)] = 0xFFF -- open the row above it
	local items = Profile.deepCopy(copy.inventory.items)
	local swing = Quarry.dig(copy, oreRow, oreCol)
	if not swing.cleared then
		swing = Quarry.dig(copy, oreRow, oreCol)
	end
	eq(swing.find, "CopperOre", "found Copper Ore")
	eq(copy.oreShed.CopperOre, 1, "in the Ore Shed")
	eq(swing.xp, QuarryConfig.ores.CopperOre.xp, "ore XP")
	eq(copy.inventory.items.CopperOre, items.CopperOre, "not in the Barn")
	-- Out of Pickaxes
	data.toolShed.items.Pickaxe = 0
	local _, noPick = Quarry.canDig(data, 2, col, now)
	ok(noPick ~= nil, "needs a Pickaxe")
	-- The day's free Pickaxes, once a day
	eq(Quarry.claimFree(data, 7, now), QuarryConfig.dailyFree, "free Pickaxes")
	eq(Quarry.claimFree(data, 7, now), 0, "once a day")
	eq(Quarry.claimFree(data, 8, now), QuarryConfig.dailyFree, "next day")
end)

test("the Smelters: Township's Foundry numbers, Bars from Ore Shed ore", function()
	local s1, s2 = Factories.Smelter, Factories.Smelter2
	eq(s1.unlockLevel, 21, "Smelter level")
	eq(s1.population, 730, "Smelter Population")
	eq(s1.buildCost, 2000, "Smelter Coins")
	eq(s1.buildSeconds, 36 * 3600, "Smelter build time")
	eq(s1.xp, 87, "Smelter XP")
	eq(s2.population, 920, "second Smelter Population")
	eq(s2.buildCost, 8000, "second Smelter Coins")
	eq(s2.xp, 335, "second Smelter XP")
	eq(s2.makes, "Smelter", "second Smelter makes Bars")
	ok(s1.queueSlots == 1 and s1.fixedSlots and s2.queueSlots == 1 and s2.fixedSlots, "one Bar at a time")
	local bars = {
		CopperBar = { "CopperOre", 1, 96, 41 },
		SilverBar = { "SilverOre", 2, 144, 62 },
		GoldBar = { "GoldOre", 3, 204, 87 },
		PlatinumBar = { "PlatinumOre", 4, 300, 129 },
	}
	for id, want in bars do
		local r = Recipes[id]
		eq(r.factory, "Smelter", id .. " factory")
		eq(r.inputs[want[1]], 5, id .. " takes 5 ore")
		eq(r.seconds, want[2] * 3600, id .. " time")
		eq(r.sellPrice, want[3], id .. " price")
		eq(r.xp, want[4], id .. " XP")
		ok(r.fromOreShed, id .. " smelts Ore Shed ore")
		ok(Items[id] ~= nil and Items[id].kind == "Product", id .. " goes to the Barn")
	end
	local data = Profile.migrate(nil) :: any
	data.oreShed.CopperOre = 7
	ok(not Quarry.takeOre(data, { CopperOre = 8 }), "not enough ore takes nothing")
	eq(data.oreShed.CopperOre, 7, "ore untouched")
	ok(Quarry.takeOre(data, { CopperOre = 5 }), "5 ore for a Bar")
	eq(data.oreShed.CopperOre, 2, "2 ore left")
	ok(Quarry.takeOre(data, { CopperOre = 2 }), "the rest")
	eq(data.oreShed.CopperOre, nil, "empty ore cleared")
	eq(table.find(OrderGen.makeablePool(data), "CopperBar"), nil, "Bars never show up on orders")
end)

test("the Tinker's Guild: Township's Academy numbers and upgrades", function()
	eq(GuildConfig.unlockLevel, 22, "Guild level")
	eq(GuildConfig.population, 810, "Guild Population")
	eq(GuildConfig.buildBars.CopperBar, 6, "6 Copper Bars")
	eq(GuildConfig.buildBars.SilverBar, 2, "2 Silver Bars")
	eq(GuildConfig.buildSeconds, 41 * 3600, "1 d 17 h")
	eq(GuildConfig.buildXp, 269, "Guild XP")
	-- Every upgradable factory has a cost table; the wiki's totals for the Bakery
	for id in Factories do
		local upgradable = Guild.tableId(id) ~= nil
		ok(upgradable == not id:find("^Smelter"), id .. " upgradable unless a Smelter")
	end
	local totals = { 0, 0, 0, 0 }
	for _, row in GuildConfig.costs.Bakery do
		for i = 1, 4 do
			totals[i] += row[i]
		end
	end
	eq(table.concat(totals, ","), "516,296,197,81", "Bakery's Bars to the top")
	eq(Guild.maxLevel("Bakery"), 53, "factories top out at 53")
	eq(Guild.maxLevel("FeedMill2"), 13, "the second Feed Mill uses the Feed Mill's table")
	local first = Guild.nextCost("Bakery", 1) :: any
	ok(first.SilverBar == 1 and first.GoldBar == 1 and first.CopperBar == nil, "Bakery 1 -> 2: 1 Silver + 1 Gold")

	local data = Profile.migrate(nil) :: any
	data.level = 30
	local ok1, why = Guild.canUpgrade(data, "Bakery", "time", 100)
	ok(ok1 == nil and why == "Build the Tinker's Guild first", "no Guild, no upgrades")
	data.guild.readyAt = 50
	data.factories.Bakery.built = true
	ok(Guild.canUpgrade(data, "Bakery", "coins", 100) == nil, "level 2 is a time upgrade")
	ok(Guild.canUpgrade(data, "Bakery", "time", 100) ~= nil, "time at level 2")
	-- Take the Bakery to the top, always picking the first offer
	for _ = 1, 52 do
		local pick = Guild.choices("Bakery", Guild.levels(data, "Bakery"))[1]
		ok(pick ~= nil and Guild.canUpgrade(data, "Bakery", pick, 100) ~= nil, "an upgrade on offer")
		Guild.upgrade(data, "Bakery", pick)
	end
	local top = Guild.levels(data, "Bakery")
	eq(Guild.level(top), 53, "Bakery at 53")
	eq(top.time, 10, "-50% time")
	eq(top.shelves, 2, "+2 shelves")
	ok(top.coins == 20 and top.xp == 20, "+100% Coins and XP")
	eq(#Guild.choices("Bakery", top), 0, "nothing left")
	eq(Guild.timeMult(data, "Bakery"), 0.5, "half the time")
	eq(Guild.trayCapacity(data, "Bakery"), 8, "8 shelves")
	local coins, xp = Guild.orderBonus(data, { Bread = 2, Wheat = 2 }, 100, 40)
	local breadShare = Items.Bread.sellPrice * 2 / (Items.Bread.sellPrice * 2 + Items.Wheat.sellPrice * 2)
	eq(coins, math.floor(100 * breadShare + 0.5), "Coins +100% on the Bread's share")
	ok(xp > 0 and xp < 40, "XP on the Bread's share only")
	-- The Feed Mill: shelves at 5 and 10, time at the rest, no Coins or XP
	data.factories.FeedMill.built = true
	for _ = 1, 12 do
		Guild.upgrade(data, "FeedMill", Guild.choices("FeedMill", Guild.levels(data, "FeedMill"))[1])
	end
	local mill = Guild.levels(data, "FeedMill")
	ok(mill.time == 10 and mill.shelves == 2 and mill.coins == 0, "Feed Mill: -50% and 8 shelves")
	eq(Guild.level(Guild.levels(data, "FeedMill2")), 1, "copies upgrade on their own")
	local canBuild = Guild.canBuild(Profile.migrate(nil) :: any, 100)
	ok(not canBuild, "a new farm can't build the Guild")
end)

test("Airship Freight: Township's airport numbers and crate list", function()
	eq(BlimpConfig.unlockLevel, 17, "mast at level 17")
	eq(BlimpConfig.repairCoins, 1500, "1,500 Coins")
	eq(BlimpConfig.repairSeconds, 24 * 3600, "24 h")
	eq(BlimpConfig.repairXp, 66, "66 XP")
	eq(BlimpConfig.loadSeconds, 15 * 3600, "15 h to load")
	eq(BlimpConfig.gapSeconds, 5 * 3600, "5 h to the next")
	-- Every crate good is a real, sellable, non-feed item; every sellable crop, animal good
	-- and factory good is on the list except the Bars and Dough
	local skip = { CopperBar = true, SilverBar = true, GoldBar = true, PlatinumBar = true, Dough = true }
	for id, range in BlimpConfig.crates do
		local def = Items[id]
		ok(def ~= nil and def.sellPrice > 0 and not def.isFeed, id .. " is a sellable good")
		ok(range[1] >= 1 and range[2] >= range[1], id .. " range")
	end
	for id, def in Items do
		if def.sellPrice > 0 and not def.isFeed and def.kind ~= "Material" and def.kind ~= "Isle" and not skip[id] then
			ok(BlimpConfig.crates[id] ~= nil, id .. " can go on a blimp")
		end
	end
	for _, group in BlimpConfig.chest do
		for _, entry in group do
			ok(
				Items[entry.item] ~= nil or Tools.tools[entry.item] ~= nil or entry.item == QuarryConfig.pickaxe,
				entry.item .. " exists"
			)
		end
	end
	local low, high = Blimp.qtyRange("Wheat", 17)
	ok(low == 18 and high < 99, "Wheat starts low")
	low, high = Blimp.qtyRange("Wheat", 60)
	ok(low == 18 and high == 99, "the whole Wheat range by 60")
end)

test("Airship Freight: repair, dock, load, send, expire", function()
	local data = Profile.migrate(nil) :: any
	data.level = 16
	local can, why = Blimp.canRepair(data, 0)
	ok(not can and why ~= nil, "not before level 17")
	data.level = 25
	for _, id in { "Bakery", "Dairy", "SugarMill", "FeedMill" } do
		data.factories[id].built = true
	end
	data.pens.CowBarn.built = true
	ok(not Blimp.canRepair(data, 0), "not before the West Meadow is cleared")
	data.land = { { readyAt = 0 } }
	ok(Blimp.canRepair(data, 0), "can repair at 25")
	local H = 3600
	Blimp.repair(data, 1000, 12345)
	ok(not Blimp.canRepair(data, 0), "only once")
	local load = data.blimp.load
	eq(#load.rows, 3, "3 rows")
	local seen = {}
	for _, row in load.rows do
		ok(#row >= 2 and #row <= 3, "2-3 crates a row")
		for _, crate in row do
			ok(BlimpConfig.crates[crate.item] ~= nil and crate.qty >= 1, "a crate good")
			ok(not seen[crate.item], crate.item .. " once per load")
			seen[crate.item] = true
		end
	end
	eq(#load.chest, 3, "chest: a Bar, a tool, a material")
	-- Same seed, same load
	local again = Profile.migrate(nil) :: any
	again.level, again.factories, again.pens = data.level, data.factories, data.pens
	Blimp.repair(again, 1000, 12345)
	eq(again.blimp.load.rows[2][1].item, load.rows[2][1].item, "loads are fixed by the seed")

	eq(Blimp.tick(data, 1000 + 23 * H), nil, "nothing during the repair")
	eq(Blimp.tick(data, 1000 + 24 * H), "docked", "docks when the repair ends")
	eq(data.blimp.leavesAt, 1000 + 39 * H, "15 h window")
	ok(Blimp.canFill(data, 4, 1, 1000 + 24 * H) == nil, "no row 4")
	ok(Blimp.canFill(data, 1, 1.5, 1000 + 24 * H) == nil, "whole numbers only")
	-- Flags: one per row, toggled
	ok(Blimp.flag(data, 1, 1, 1000 + 24 * H), "flag")
	ok(Blimp.flag(data, 1, 2, 1000 + 24 * H), "move the flag")
	ok(not load.rows[1][1].flagged and load.rows[1][2].flagged, "one flag a row")
	Blimp.flag(data, 1, 2, 1000 + 24 * H)
	ok(not load.rows[1][2].flagged, "flag off")
	ok(Blimp.flag(data, 2, 1, 1000 + 24 * H), "flag a row 2 crate")
	Blimp.fill(load.rows[2][1], 99)
	ok(not load.rows[2][1].flagged, "loading takes the flag down")
	ok(not Blimp.flag(data, 2, 1, 1000 + 24 * H), "a loaded crate can't be flagged")
	load.rows[2][1].filledBy = nil
	-- Fill row 1 only and send: row 1 pays, no chest
	local now = 1000 + 25 * H
	for slot in load.rows[1] do
		local crate = Blimp.canFill(data, 1, slot, now) :: any
		ok(crate ~= nil, "row 1 crate open")
		local coins, xp, miles = Blimp.crateRewards(crate)
		ok(coins > 0 and xp > 0 and miles >= 1 and miles <= 3, "crate pays")
		Blimp.fill(crate, 42)
	end
	local _, why2 = Blimp.canFill(data, 1, 1, now)
	eq(why2, "That crate is already loaded", "no double loading")
	local rowCoins, rowMiles = Blimp.rowRewards(load.rows[1], 1)
	local payout = Blimp.send(data, now) :: any
	eq(payout.coins, rowCoins, "row 1 bonus")
	eq(payout.miles, rowMiles, "row 1 miles")
	eq(payout.chest, nil, "no chest for a part load")
	eq(data.blimp.skyMiles, rowMiles, "Sky Miles kept")
	eq(data.blimp.arrivesAt, now + 5 * H, "next in 5 h")
	ok(data.blimp.load ~= load, "Next Flight drawn")
	-- Skipping the wait costs Gems scaled by time left, free in the last 30 s
	eq(Blimp.skipCost(data, now), 9, "9 Gems with 5 h to go")
	eq(Blimp.skipCost(data, now + 5 * H - 20), 0, "free at the end")
	-- Offline past the arrival: docks only on the next tick, with a full window
	eq(Blimp.tick(data, now + 9 * H), "docked", "docks when the player is back")
	eq(data.blimp.leavesAt, now + 24 * H, "window starts on arrival")
	-- Fill everything and send: every row and the chest
	local full = data.blimp.load
	for _, row in full.rows do
		for _, crate in row do
			Blimp.fill(crate, 42)
		end
	end
	local all = Blimp.send(data, now + 10 * H) :: any
	eq(#all.rows, 3, "every row pays")
	eq(all.chest, full.chest, "Full Hold chest")
	eq(data.blimp.fullHolds, 1, "one full hold")
	-- Running out of time: leaves with nothing, next one 5 h after it left
	Blimp.tick(data, now + 15 * H + 1)
	local leaves = data.blimp.leavesAt
	eq(Blimp.tick(data, leaves), "expired", "leaves when time runs out")
	eq(data.blimp.arrivesAt, leaves + 5 * H, "gap from when it left")
	eq(data.blimp.flights, 3, "three flights")
	-- The Studio time scale shortens every timer
	local quick = Profile.migrate(nil) :: any
	quick.level = 17
	Blimp.repair(quick, 0, 7, 0.05)
	eq(quick.blimp.readyAt, math.floor(24 * H * 0.05 + 0.5), "scaled repair")
	Blimp.tick(quick, quick.blimp.readyAt, 0.05)
	eq(quick.blimp.leavesAt, quick.blimp.readyAt + math.floor(15 * H * 0.05 + 0.5), "scaled window")
	-- Finishing the repair early brings the first blimp in too
	local fresh = Profile.migrate(nil) :: any
	fresh.level = 17
	Blimp.repair(fresh, 0, 7)
	ok(Blimp.finishRepair(fresh, 100), "finish early")
	eq(Blimp.tick(fresh, 100), "docked", "first blimp docks")
	ok(#fresh.blimp.load.rows[1] >= 2, "a load from crops alone")
end)

test("moving buildings: keys, turned footprints, owned land and bad input", function()
	eq(Layout.key("factory", "Bakery"), "factory:Bakery", "key")
	local kind, id = Layout.parse("house:12")
	ok(kind == "house" and id == "12", "parse a house key")
	ok(Layout.parse("barn:1") == nil and Layout.parse(5) == nil and Layout.parse("factory:") == nil, "bad keys")
	local w, d, ox, oz = Layout.footprint("factory", 0)
	ok(w == 18 and d == 10 and ox == -3 and oz == 0, "a factory's table sticks out west")
	w, d, ox, oz = Layout.footprint("factory", 90)
	ok(w == 10 and d == 18 and ox == 0 and oz == 3, "turned a quarter: the table side follows Kit.yaw")
	w, d, ox, oz = Layout.footprint("factory", 180)
	ok(w == 18 and ox == 3, "half a turn")
	eq(Layout.snap(3.1), 4, "2-stud grid")

	local data = Profile.migrate(nil) :: any
	data.level = 20
	ok(data.layout ~= nil, "new saves have a layout")
	ok(Layout.canMove(data, "factory:Bakery", 0, 0, 0, 0), "a factory moves inside the start area")
	ok(Layout.canMove(data, "factory:Bakery", 10, 70, 90, 0), "Main Street is the farm's land")
	ok(not Layout.canMove(data, "factory:Bakery", -70, 0, 0, 0), "not onto the West Meadow before it's cleared")
	ok(not Layout.canMove(data, "factory:Bakery", 140, 0, 0, 0), "not off the plot")
	ok(not Layout.canMove(data, "factory:Bakery", 1, 0, 0, 0), "on the grid only")
	ok(not Layout.canMove(data, "factory:Bakery", 0, 0, 45, 0), "quarter turns only")
	ok(not Layout.canMove(data, "factory:Bakery", 0 / 0, 0, 0, 0), "NaN")
	ok(not Layout.canMove(data, "factory:Bakery", math.huge, 0, 0, 0), "infinity")
	ok(not Layout.canMove(data, "field:F99", 0, 0, 0, 0), "a field the farm doesn't have")
	ok(Layout.canMove(data, "field:F1", -40, 40, 0, 0), "a starting field")
	ok(not Layout.canMove(data, "house:999", 0, 0, 0, 0), "a house that isn't there")
	local lot = data.town.houses[1].lot
	ok(Layout.canMove(data, "house:" .. lot, 20, 20, 180, 0), "a starter house")
	-- Reasons for everything the ghost can't do, so the server's refusal always says why
	local okGrid, why = Layout.canMove(data, "factory:Bakery", 27, 2, 0, 0)
	ok(not okGrid and why ~= nil, "off the grid says why")
	local okKey, whyKey = Layout.canMove(data, "barn:1", 0, 0, 0, 0)
	ok(not okKey and whyKey ~= nil, "an unmovable building says why")
	-- A moved building survives a save round trip (DataStore JSON, then load + reconcile)
	local saved = Profile.deepCopy(data)
	saved.layout["factory:Bakery"] = { x = 10, z = 70, r = 90 }
	local serde = require("@lune/serde")
	local loaded = Profile.migrate(serde.decode("json", serde.encode("json", saved))) :: any
	local spot = Layout.spot(loaded, "factory:Bakery")
	ok(spot ~= nil and spot.x == 10 and spot.z == 70 and spot.r == 90, "the moved Bakery is still moved after a reload")
	ok(Layout.spot(loaded, "factory:FeedMill") == nil, "unmoved buildings stay unmoved")
	-- Clear the West Meadow: it becomes the farm's land
	data.land[1] = {}
	ok(Layout.canMove(data, "factory:Bakery", -70, 0, 0, 0), "the cleared West Meadow")
	ok(not Layout.canMove(data, "factory:Bakery", -120, 0, 0, 0), "but not the West Woods yet")
end)

test("Market stall: slots by level, price band, tax, buy caps, the passing trader and featuring", function()
	eq(Market.slotCount(12), 0, "no stall before level 13")
	eq(Market.slotCount(13), 4, "4 slots at level 13")
	eq(Market.slotCount(22), 7, "+1 at 16, 19 and 22")
	eq(Market.slotCount(40), 9, "9 at most")
	ok(Market.tradeable("Wheat") and Market.tradeable("Milk") and Market.tradeable("Bread"), "goods trade")
	ok(
		not Market.tradeable("Nails") and not Market.tradeable("Shovel") and not Market.tradeable(5),
		"materials and tools don't"
	)
	for id, def in Items do
		if Market.tradeable(id) then
			ok(def.sellPrice > 0 and def.kind ~= "Material", id .. " has a Barn price and isn't a material")
		end
	end
	local low, high, default = Market.priceRange("Wheat", 10)
	local base = Items.Wheat.sellPrice * 10
	eq(low, math.ceil(base * 0.5), "floor 50%")
	eq(high, math.floor(base * 2), "ceiling 200%")
	ok(default >= low and default <= high and math.abs(default - base * 1.2) <= 1, "default 120%")

	local seller = Profile.migrate(nil) :: any
	local buyer = Profile.migrate(nil) :: any
	seller.level, buyer.level = 13, 13
	buyer.currencies.Coins = 10000
	ok(not Market.canList(seller, 1, "Wheat", 10, default, 5), "can't list more than you have")
	ok(not Market.canList(seller, 1, "Wheat", 11, default, 20), "10 a slot at most")
	ok(not Market.canList(seller, 1, "Wheat", 10, high + 1, 20), "price above the band")
	ok(not Market.canList(seller, 1, "Wheat", 10, low - 1, 20), "price below the band")
	ok(not Market.canList(seller, 5, "Wheat", 10, default, 20), "slot 5 isn't open at 13")
	ok(not Market.canList(seller, 1, "Nails", 1, 1, 20), "materials can't be listed")
	ok(Market.canList(seller, 1, "Wheat", 10, default, 20), "a fair listing")
	Market.list(seller, 1, "Wheat", 10, default, 1000)
	ok(not Market.canList(seller, 1, "Milk", 1, Market.priceRange("Milk", 1), 5), "one listing a slot")

	ok(Market.canBuy(seller, seller, "1", 1, 1001) == nil, "not from your own stall")
	local young = Profile.migrate(nil) :: any
	young.level, young.currencies.Coins, young.meta.createdAt = 13, 10000, 900
	Market.list(seller, 2, "Wheat", 10, high, 1000)
	ok(Market.canBuy(young, seller, "1", 2, 1001) == nil, "a day-old farm can't pay 200%")
	ok(Market.canBuy(young, seller, "1", 1, 1001) ~= nil, "but can pay 120%")
	local listing, proceeds, tax = Market.buy(buyer, seller, "1", 1, 1001)
	eq(listing.qty, 10, "bought the listing")
	eq(proceeds + tax, default, "proceeds and tax add up to the price")
	eq(tax, math.floor(default * 0.1 + 0.5), "10% tax")
	ok(Market.listing(seller, 1) == nil, "the slot is free again")
	eq(Market.buysThisHour(buyer, "1", 1002), 1, "buy counted")
	buyer.market.buys["1"].n = MarketConfig.buysPerSellerPerHour
	ok(Market.canBuy(buyer, seller, "1", 2, 1003) == nil, "20 an hour from one seller")
	ok(Market.canBuy(buyer, seller, "1", 2, 1001 + 3600) ~= nil, "a new hour")

	-- The passing trader: after 2 hours, at the Barn price or the listing's if lower
	eq(Market.botPrice(Market.listing(seller, 2) :: any), base, "trader pays the Barn price for a 200% listing")
	Market.list(seller, 3, "Wheat", 10, low, 1000)
	eq(#Market.botTick(seller, 1000 + 7199), 0, "not before 2 hours")
	local sold = Market.botTick(seller, 1000 + 7200)
	eq(#sold, 2, "both old listings go")
	eq(#seller.market.listings, 0, "stall empty")
	for _, sale in sold do
		ok(sale.price <= base, "never above the Barn price")
	end
	eq(#Market.botTick(seller, 0, 0.01), 0, "nothing left")
	Market.list(seller, 1, "Wheat", 1, Market.priceRange("Wheat", 1), 0)
	eq(#Market.botTick(seller, 72, 0.01), 1, "the Studio time scale shortens the wait")

	-- Featuring: once every 5 minutes, cleared when the listing goes
	Market.list(seller, 1, "Wheat", 1, Market.priceRange("Wheat", 1), 0)
	Market.list(seller, 2, "Milk", 1, Market.priceRange("Milk", 1), 0)
	ok(not Market.feature(seller, 3, 0), "an empty slot can't be featured")
	ok(Market.feature(seller, 1, 100), "feature slot 1")
	ok(not Market.feature(seller, 2, 200), "cooldown")
	ok(Market.feature(seller, 2, 100 + MarketConfig.featureCooldown), "after 5 minutes")
	Market.remove(seller, 2)
	eq(seller.market.featured, 0, "taking the listing down clears the feature")
end)

test("Market board and stall colors: newest featured first, capped, colors from the list", function()
	local function farm(level: number): any
		local data = Profile.migrate(nil) :: any
		data.level = level
		return data
	end
	local a, b, c = farm(13), farm(13), farm(13)
	eq(a.market.color, MarketConfig.defaultColor, "stalls start in the default color")
	ok(Market.setColor(a, "Teal"), "pick a listed color")
	eq(a.market.color, "Teal", "color saved")
	ok(not Market.setColor(a, "Teal"), "same color is no change")
	ok(not Market.setColor(a, "Gold"), "only listed colors")
	ok(not Market.setColor(farm(12), "Plum"), "no stall, no color")

	eq(Market.featuredListing(a), nil, "nothing featured yet")
	Market.list(a, 1, "Wheat", 5, select(3, Market.priceRange("Wheat", 5)), 0)
	Market.list(b, 2, "Corn", 3, select(3, Market.priceRange("Corn", 3)), 0)
	Market.list(c, 1, "Milk", 2, select(3, Market.priceRange("Milk", 2)), 0)
	ok(Market.feature(a, 1, 100) and Market.feature(b, 2, 300), "two farms feature")
	eq(Market.featuredListing(b).item, "Corn", "featured listing found")
	local entries = Market.boardEntries({
		{ userId = 1, name = "A", data = a },
		{ userId = 2, name = "B", data = b },
		{ userId = 3, name = "C", data = c },
	})
	eq(#entries, 2, "only featured listings show")
	eq(entries[1].name, "B", "newest featured first")
	eq(entries[2].item, "Wheat", "then the older one")
	Market.remove(b, 2)
	eq(#Market.boardEntries({ { userId = 2, name = "B", data = b } }), 0, "taken down leaves the board")
	local many = {}
	for i = 1, MarketConfig.boardLines + 3 do
		local f = farm(13)
		Market.list(f, 1, "Wheat", 1, select(3, Market.priceRange("Wheat", 1)), 0)
		Market.feature(f, 1, i)
		table.insert(many, { userId = i, name = tostring(i), data = f })
	end
	eq(#Market.boardEntries(many), MarketConfig.boardLines, "the board has room for a few")
end)

test("Town Express: the 2-hour clock, crates scaled to players, NPC help and reward tiers", function()
	local H = 3600
	local at, open = Express.window(4 * H + 5 * 60)
	ok(at == 4 * H and open, "inside the 20-minute window after an even hour")
	at, open = Express.window(4 * H + 25 * 60)
	ok(at == 4 * H and not open, "closed after 20 minutes")
	eq(Express.nextArrival(5 * H), 6 * H, "every 2 hours")
	eq(Express.crateCount(1), 8, "at least 8 crates")
	eq(Express.crateCount(5), 15, "3 a player")
	eq(Express.crateCount(12), 30, "a full server, capped at 30")
	local pool = Express.pool(10, Balance.enabledCrops)
	for _, id in pool do
		ok(Items[id].kind == "Crop" or Items[id].kind == "Animal", id .. " is a raw good")
		ok(Items[id].unlockLevel <= 10, id .. " unlocked by level 10")
	end
	ok(table.find(pool, "Strawberries") == nil and table.find(pool, "Wheat") ~= nil, "pool by level")
	-- A solo server: 8 crates, NPC help, tiers paid to contributors only
	local train = Express.generate(2 * H, { 10 }, pool, 99)
	eq(#train.crates, 8, "8 crates solo")
	eq(train.cars, 3, "3 cars")
	ok(train.npc, "NPC neighbors help a solo player")
	eq(train.prizes[1].item, nil, "tier 1 pays Coins only")
	ok(train.prizes[3].item ~= nil and table.find(ExpressConfig.tools, train.prizes[3].item) ~= nil, "tier 3: a tool")
	for _, crate in train.crates do
		local low, high = Express.qtyRange(crate.item, 10)
		ok(crate.qty >= low and crate.qty <= high, crate.item .. " qty in range")
	end
	local now = 2 * H + 60
	local crate = Express.canLoad(train, 1, now) :: any
	ok(crate ~= nil, "crate 1 open")
	ok(Express.canLoad(train, 1, 2 * H + 21 * 60) == nil, "closed after the window")
	ok(Express.canLoad(train, 0.5, now) == nil, "whole numbers only")
	Express.load(train, crate, 42)
	ok(Express.crateXp(crate) >= 1, "a crate pays XP")
	local _, why = Express.canLoad(train, 1, now)
	eq(why, "That crate is already loaded", "once")
	eq(#Express.collect(train, 42), 0, "1 of 8 reaches no tier")
	Express.load(train, train.crates[2], 42)
	local owed = Express.collect(train, 42)
	ok(#owed == 1 and owed[1] == 1, "2 of 8: tier 1")
	eq(#Express.collect(train, 42), 0, "paid once")
	eq(#Express.collect(train, 7), 0, "no crate, no chest")
	-- NPCs load one crate every 3 minutes
	local index = Express.npcTick(train, 2 * H + 2 * 60, 5)
	eq(index, nil, "not before 3 minutes")
	index = Express.npcTick(train, 2 * H + 3 * 60, 5)
	ok(index ~= nil and train.crates[index :: number].by == 0, "an NPC loaded a crate")
	-- A late helper is paid every tier reached so far
	Express.load(train, train.crates[(index :: number) == 3 and 4 or 3], 7)
	local late = Express.collect(train, 7)
	eq(#late, 2, "4 of 8 = 50%: tiers 1 and 2 for the late helper")
	eq(#Express.collect(train, 42), 1, "and tier 2 for the first helper")
	-- A full server: no NPCs
	local big = Express.generate(4 * H, { 5, 9, 12, 20 }, Express.pool(12, Balance.enabledCrops), 3)
	eq(#big.crates, 12, "3 crates for each of 4 players")
	ok(not big.npc, "no NPC help with 4 players")
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
	eq(#Lots.houses, 66, "House lots with North Lane, the Far Corners and the last gap")
	eq(#Lots.community, 29, "Community lots with North Lane, the Far Corners and the West Meadow")
	for i = 24, 29 do
		eq(Lots.community[i].land, Lots.westMeadowLand, "Community lot " .. i .. " in the West Meadow")
		ok(Lots.community[i].z - 6 > 12, "Community lot " .. i .. " clear of the West Meadow's pen row")
	end
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
				-- Every corner on land cleared by then: its own expansion's rectangles, an earlier
				-- one's (expansions go in order) or the start area. A lot may straddle a border.
				local function cleared(x: number, z: number): boolean
					if math.abs(x) <= Land.startArea and math.abs(z) <= Land.startArea then
						return true
					end
					for _, rect in Land.rects do -- an expansion can clear more than one rectangle
						if
							rect.stage <= lot.land
							and x >= rect.minX
							and x <= rect.maxX
							and z >= rect.minZ
							and z <= rect.maxZ
						then
							return true
						end
					end
					return false
				end
				local inside = cleared(box[1], box[2])
					and cleared(box[3], box[2])
					and cleared(box[1], box[4])
					and cleared(box[3], box[4])
				ok(inside, box[5] .. " inside its land")
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
		{ -Lots.northLane.halfWidth, lane - 4, Lots.northLane.halfWidth, lane + 4, "North Lane" },
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
	-- From level 34 the lots have run out: new Community Buildings go up wherever the player
	-- places them (the free-placement sandbox, shared/Layout)
	for id, def in Town.community do
		local lot = TownRules.communityLot(id)
		if def.townHallStorey then
			eq(lot, nil, id .. " is a Town Hall storey")
		elseif def.unlockLevel < 34 then
			ok(Lots.community[lot :: number] ~= nil, id .. " has a lot")
		else
			ok(lot ~= nil and Lots.community[lot :: number] == nil, id .. " is placed by the player")
		end
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

test("land rectangles tile the 288-stud plot without overlapping, every expansion clears some", function()
	local half = 144
	for stage = 1, #Land.expansions do
		local any = false
		for _, rect in Land.rects do
			any = any or rect.stage == stage
		end
		ok(any, "expansion " .. stage .. " clears land")
	end
	local area = 0
	for i, a in Land.rects do
		ok(a.minX >= -half and a.maxX <= half and a.minZ >= -half and a.maxZ <= half, "rect " .. i .. " on the plot")
		local s = Land.startArea
		ok(not (a.minX < s and a.maxX > -s and a.minZ < s and a.maxZ > -s), "rect " .. i .. " off the start area")
		ok(not (a.minX < 96 and a.maxX > -96 and a.minZ < 96 and a.maxZ > 48), "rect " .. i .. " off Main Street")
		for j, b in Land.rects do
			if j > i then
				local overlap = a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
				ok(not overlap, string.format("rects %d and %d don't overlap", i, j))
			end
		end
		area += (a.maxX - a.minX) * (a.maxZ - a.minZ)
	end
	-- Everything but the start area and Main Street is expansion land
	eq(area, 288 * 288 - 96 * 96 - 192 * 48, "the whole plot is covered")
	-- Township's table: Population and Coins rise with each expansion
	for stage = 2, #Land.expansions do
		local a, b = Land.expansions[stage - 1], Land.expansions[stage]
		ok(b.population > a.population and b.coinCost > a.coinCost, "expansion " .. stage .. " costs more")
	end
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

test("records: the public card others see has stars and the card's six numbers", function()
	local data = Profile.template()
	Records.add(data, "harvest", 640)
	data.orders.delivered = 120
	Records.claim(data, "Orders", 0)
	local card = Records.publicCard(data, 0)
	eq(card.stars, 1, "one star")
	eq(card.stats.Harvest, 640, "harvest")
	eq(card.stats.Orders, 120, "orders")
	eq(card.stats.Coins, nil, "only the card's stats")
	eq(card.townHall, 1, "a new town's hall has one storey")
	eq(card.upgrading, false, "nothing going up")
	local n = 0
	for _ in card.stats do
		n += 1
	end
	eq(n, 6, "six numbers")
end)

test("trophies: Gold Town Record trophies place like decorations, free and never sold", function()
	local def = DecorRules.def("TrophyOrders")
	ok(def ~= nil and def.trophy == true, "trophy def")
	eq(def.coinCost, 0, "free")
	eq(DecorRules.refund("TrophyOrders"), 0, "no refund")
	ok(DecorRules.isTrophy("TrophyHelping") and not DecorRules.isTrophy("Bench"), "isTrophy")
	eq(DecorRules.def("Nope"), nil, "junk id")
	local w, d = DecorRules.footprint("TrophyHarvest", 1)
	eq(w * d, 1, "1 x 1")
	local data = Profile.template()
	ok(type(data.trophies) == "table", "trophies in the save")
	local fine = DecorRules.canPlace(data, { id = "TrophyGoods", x = 2, z = 2, r = 0 }, 0)
	ok(fine, "a trophy fits on the start area")
	for _, trophy in Trophies.byRecord do
		ok(RecordsConfig ~= nil and Records.def(trophy.record) ~= nil, trophy.id .. " matches a record")
	end
end)

test("badges: medals map to badge ids, and a save's earned badges are listed", function()
	eq(Badges.forMedal("Orders", 3), nil, "no ids set yet")
	eq(Badges.forMedal("Nope", 1), nil, "junk record")
	for id in RecordsConfig.list do
		ok(BadgesConfig.records[RecordsConfig.list[id].id] ~= nil, "a badge slot per record")
	end
	local data = Profile.template()
	data.records.claimed.Orders = 3
	eq(#Badges.earned(data), 0, "nothing earned while ids are 0")
end)

test("records: the Studio fill reaches each counted record's next medal", function()
	local data = Profile.template()
	local ready = Records.debugFill(data, 0)
	eq(Records.ready(data, "Harvest", 0), 1, "Bronze harvest ready")
	eq(Records.ready(data, "Orders", 0), 1, "Bronze orders ready")
	eq(Records.ready(data, "Population", 0), nil, "buildings aren't faked")
	ok(ready >= 7, "the seven counted records")
	Records.claim(data, "Harvest", 0)
	Records.debugFill(data, 0)
	eq(Records.ready(data, "Harvest", 0), 2, "then Silver")
	for _ = 1, 3 do
		Records.claim(data, "Harvest", 0)
		Records.debugFill(data, 0)
	end
	eq(Records.claimed(data, "Harvest"), 3, "Gold claimed, nothing past it")
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
require("./harbor")(test, eq, ok)

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
