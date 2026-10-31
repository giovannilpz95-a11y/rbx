-- Harbor & Far Isles (src/shared/Harbor, Config/Isles): the repair, Sailboats, isle unlocks,
-- voyages rolled at departure, Ballast Bar odds, the Driftwood Crate and the isle goods in the
-- Order Board pool. Called from tests/run.luau.

local Config = require("../src/shared/Config/Isles")
local Harbor = require("../src/shared/Harbor")
local Items = require("../src/shared/Items")
local OrderGen = require("../src/shared/OrderGen")
local Profile = require("../src/shared/Profile")
local Recipes = require("../src/shared/Config/Recipes")
local Unlocks = require("../src/shared/Unlocks")

local HOUR = 3600

local function farm(level: number): { [string]: any }
	local data = Profile.template()
	data.level = level
	data.tutorial.step = 0
	return data
end

-- A farm with the Harbor repaired at time 0 + 48 h
local function harborFarm(level: number): ({ [string]: any }, number)
	local data = farm(level)
	Harbor.repair(data, 0, 777)
	return data, Config.repairSeconds
end

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("harbor: Township's port, ship and isle numbers", function()
		eq(Config.unlockLevel, 29, "port at 29")
		eq(Config.repairCoins, 8000, "8,000 Coins")
		eq(Config.repairSeconds, 48 * HOUR, "2 days")
		eq(Config.repairXp, 335, "335 XP")
		eq(#Config.boats, 4, "4 ships")
		eq(Config.boats[1].coins, 0, "first ship free")
		eq(Config.boats[4].coins, 25000, "fourth ship 25,000")
		eq(#Config.isles, 5, "5 isles")
		local first, second = Config.isles[1], Config.isles[2]
		eq(first.sendCoins, 70, "first isle send 70")
		eq(first.tripSeconds, 4 * HOUR, "first isle 4 h")
		eq(second.unlockLevel, 35, "second isle at 35")
		eq(second.unlockCoins, 11000, "second isle 11,000")
		eq(second.unlockTools, 2, "2 of each tool")
		eq(second.tripSeconds, 7 * HOUR, "second isle 7 h")
		for i, isle in Config.isles do
			eq(isle.order, i, isle.id .. " order")
			eq(#isle.goods, 3, isle.id .. " has 3 goods")
			eq(#isle.odds, #Config.bars + 1, isle.id .. " has a row of odds per Bar and none")
			for row, odds in isle.odds do
				for _, p in odds do
					ok(p >= 0 and p <= 1, isle.id .. " odds are chances")
				end
				if row > 1 then
					local prev = isle.odds[row - 1]
					ok(
						odds[1] >= prev[1] and odds[2] >= prev[2] and odds[3] >= prev[3],
						isle.id .. " better Bars never hurt"
					)
				end
			end
			eq(isle.odds[1][3], 0, isle.id .. " no chest without a Bar")
			eq(isle.odds[#isle.odds][2], 1, isle.id .. " Platinum always brings the rare good")
		end
		local total = 0
		for _, entry in Config.seaChest do
			total += entry.weight
		end
		ok(total > 0, "Sea Chest has prizes")
	end)

	test("harbor: isle goods are Barn items with Township's prices", function()
		eq(Items.Peaches.kind, "Isle", "Peaches are an isle good")
		eq(Items.Peaches.sellPrice, 34, "Peaches 34")
		eq(Items.Plums.xpPerUnit, 17, "Plums 17 XP")
		eq(Items.KeyLimes.displayName, "Key Limes", "Key Limes name")
		eq(Items.Grapes.unlockLevel, 35, "Grapes with Vineyard Key")
		ok(Items.Plums.unitSeconds > Items.Peaches.unitSeconds, "rarer goods take longer")
		for id, good in Config.goods do
			ok(Items[id] ~= nil, id .. " is an item")
			ok(Config.byId[good.isle] ~= nil, id .. " isle")
		end
		eq(Recipes.GrapeJelly.inputs.Grapes, 3, "Grape Jelly is 3 Grapes")
		eq(Recipes.GrapeJelly.unlockLevel, 38, "Grape Jelly at 38")
		eq(Recipes.PeachMarmalade.seconds, 2.5 * HOUR, "Peach Marmalade 2 h 30")
		eq(Recipes.WatermelonJam.sellPrice, 196, "Watermelon Jam 196")
		eq(Recipes.PlumJam.xp, 128, "Plum Jam 128 XP")
		eq(Recipes.BananaBread.inputs.Bananas, 3, "Banana Bread takes 3 Bananas")
	end)

	test("harbor: the repair brings the first boat and Blossom Cay", function()
		local data = farm(28)
		local can, why = Harbor.canRepair(data)
		ok(not can and why ~= nil, "not before 29")
		data.level = 29
		ok(Harbor.canRepair(data), "can repair at 29")
		Harbor.repair(data, 100, 5)
		ok(not Harbor.canRepair(data), "only once")
		eq(#data.harbor.boats, 1, "one boat")
		ok(not Harbor.isRepaired(data, 100), "repairing")
		ok(Harbor.isRepaired(data, 100 + Config.repairSeconds), "repaired after 2 days")
		eq(Harbor.isleState(data, "BlossomCay", 100), "Opening", "first isle opens with it")
		eq(Harbor.isleState(data, "BlossomCay", 100 + Config.repairSeconds), "Open", "then open")
		ok(Harbor.finishRepair(data, 200), "speed-up")
		ok(Harbor.isRepaired(data, 200), "repaired now")
		ok(Harbor.isleOpen(data, "BlossomCay", 200), "isle open now too")
		ok(not Harbor.finishRepair(data, 300), "nothing left to speed up")
	end)

	test("harbor: more Sailboats by level and Population", function()
		local data, t = harborFarm(29)
		local price, why = Harbor.canBuyBoat(data, t)
		eq(price, nil, "second boat needs Population 2,050")
		ok(why ~= nil and why:find("2050") ~= nil, why or "reason")
		-- Plenty of Population: 100 Farmhouses (25 each)
		for i = 1, 100 do
			table.insert(data.town.houses, { type = "Farmhouse", lot = 100 + i })
		end
		eq(Harbor.canBuyBoat(data, t), 5000, "second boat 5,000")
		Harbor.buyBoat(data)
		eq(#data.harbor.boats, 2, "two boats")
		local none3, why3 = Harbor.canBuyBoat(data, t)
		ok(none3 == nil and why3 ~= nil and why3:find("32") ~= nil, "third boat at level 32")
		data.level = 38
		eq(Harbor.canBuyBoat(data, t), 8000, "third boat 8,000")
		Harbor.buyBoat(data)
		Harbor.buyBoat(data)
		local none5, why5 = Harbor.canBuyBoat(data, t)
		ok(none5 == nil and why5 ~= nil, "four at most")
		local early = farm(29)
		local none, notYet = Harbor.canBuyBoat(early, 0)
		ok(none == nil and notYet ~= nil, "no boats before the repair")
	end)

	test("harbor: isles open in order, at their level", function()
		local data, t = harborFarm(34)
		local can, why = Harbor.canUnlockIsle(data, "VineyardKey", t)
		ok(not can and why ~= nil and why:find("35") ~= nil, "Vineyard Key at 35")
		data.level = 41
		ok(not Harbor.canUnlockIsle(data, "CoconutAtoll", t), "not before Vineyard Key")
		ok(Harbor.canUnlockIsle(data, "VineyardKey", t), "Vineyard Key can open")
		eq(Harbor.isleState(data, "VineyardKey", t), "Ready", "ready")
		Harbor.unlockIsle(data, "VineyardKey", t)
		eq(Harbor.isleState(data, "VineyardKey", t), "Opening", "opening")
		ok(not Harbor.canUnlockIsle(data, "VineyardKey", t), "only once")
		ok(not Harbor.canUnlockIsle(data, "CoconutAtoll", t), "still not while it opens")
		ok(Harbor.finishIsle(data, "VineyardKey", t + 10), "speed-up")
		ok(Harbor.isleOpen(data, "VineyardKey", t + 10), "open")
		ok(Harbor.canUnlockIsle(data, "CoconutAtoll", t + 10), "now Coconut Atoll")
		ok(not Harbor.canUnlockIsle(data, "Atlantis", t), "unknown isle")
	end)

	test("harbor: voyages always bring 3 of the common good, rarer ones by chance", function()
		local seed = 1
		local hits = { 0, 0, 0 }
		local N = 2000
		for _ = 1, N do
			local cargo, chest
			cargo, chest, seed = Harbor.roll("BlossomCay", nil, seed)
			eq(cargo[1].item, "Peaches", "common first")
			eq(cargo[1].qty, 3, "x3")
			for i = 2, #cargo do
				local tier = Config.goods[cargo[i].item].tier
				hits[tier] += 1
				ok(cargo[i].qty >= 1 and cargo[i].qty <= 2, "1-2 with no Bar")
			end
			eq(chest, nil, "no chest without a Bar")
		end
		ok(math.abs(hits[2] / N - 0.70) < 0.05, string.format("uncommon about 70%% (%.2f)", hits[2] / N))
		ok(math.abs(hits[3] / N - 0.33) < 0.05, string.format("rare about 33%% (%.2f)", hits[3] / N))

		local chests = 0
		for _ = 1, N do
			local cargo, chest
			cargo, chest, seed = Harbor.roll("BlossomCay", "PlatinumBar", seed)
			eq(#cargo, 3, "Platinum always brings all three")
			eq(cargo[2].qty, 3, "3 uncommon")
			eq(cargo[3].qty, 3, "3 rare")
			if chest then
				chests += 1
			end
		end
		ok(math.abs(chests / N - 0.5) < 0.05, string.format("chest about 50%% (%.2f)", chests / N))

		local a1, c1 = Harbor.roll("VineyardKey", "SilverBar", 4242)
		local a2, c2 = Harbor.roll("VineyardKey", "SilverBar", 4242)
		eq(#a1, #a2, "same seed, same cargo")
		eq(c1 and c1.item, c2 and c2.item, "same chest")
		local u, r, c = Harbor.odds("BlossomCay", "CopperBar")
		eq(u, 0.80, "Copper uncommon 80%")
		eq(r, 0.53, "Copper rare 53%")
		eq(c, 0.10, "Copper chest 10%")
	end)

	test("harbor: send, skip and unload; the cargo is fixed when the boat leaves", function()
		local data, t = harborFarm(29)
		eq(Harbor.canSend(data, 1, "VineyardKey", nil, t), nil, "Vineyard Key isn't open")
		eq(Harbor.canSend(data, 2, "BlossomCay", nil, t), nil, "no second boat")
		local cost, why = Harbor.canSend(data, 1, "BlossomCay", "Wheat", t)
		ok(cost == nil and why ~= nil, "only Bars as ballast")
		eq(Harbor.canSend(data, 1, "BlossomCay", nil, t), 70, "70 Coins")
		eq(Harbor.canSend(data, 1, "BlossomCay", "GoldBar", t), 70, "Bar or not")
		Harbor.send(data, 1, "BlossomCay", "GoldBar", t)
		local boat = data.harbor.boats[1]
		eq(boat.isle, "BlossomCay", "out to Blossom Cay")
		eq(boat.returnAt, t + 4 * HOUR, "back in 4 h")
		eq(boat.bar, "GoldBar", "Bar aboard")
		local cargo = Profile.deepCopy(boat.cargo)
		ok(Harbor.cargoUnits(boat) >= 3, "at least the 3 Peaches")
		local _, busy = Harbor.canSend(data, 1, "BlossomCay", nil, t)
		ok(busy ~= nil, "busy at sea")
		eq(Harbor.unload(data, 1, t + HOUR), nil, "not back yet")
		ok(Harbor.skipCost(boat, t) > 0, "skipping costs Gems")
		eq(Harbor.skipCost(boat, t + 4 * HOUR - 10), 0, "free in the last 30 s")
		ok(Harbor.skip(boat, t + HOUR), "skip")
		eq(boat.cargo[1].qty, cargo[1].qty, "skipping doesn't change the cargo")
		eq(#boat.cargo, #cargo, "same crates")
		local got, chest = Harbor.unload(data, 1, t + HOUR)
		ok(got ~= nil, "unloaded")
		eq(#(got :: any), #cargo, "the rolled cargo")
		eq(data.harbor.trips.BlossomCay, 1, "one trip counted")
		eq(data.harbor.chests, if chest then 1 else 0, "chest count")
		ok(Harbor.isIdle(data.harbor.boats[1]), "boat idle again")
		eq(Harbor.unload(data, 1, t + HOUR), nil, "nothing more to unload")
		-- the 4 h skip ladder price
		Harbor.send(data, 1, "BlossomCay", nil, t + HOUR)
		eq(Harbor.skipCost(data.harbor.boats[1], t + HOUR), 28, "a fresh 4 h trip costs 28 Gems")
	end)

	test("harbor: one Driftwood Crate a day", function()
		local early = farm(29)
		ok(not Harbor.canOpenDrift(early, 10, 0), "not before the repair")
		local data, t = harborFarm(29)
		ok(Harbor.canOpenDrift(data, 10, t), "today's crate")
		local prize = Harbor.openDrift(data, 10, t)
		ok(prize.qty >= 1, "a prize")
		ok(prize.item ~= "IsleGoods", "isle goods become a real good")
		local _, why = Harbor.canOpenDrift(data, 10, t)
		ok(why ~= nil, "once a day")
		ok(Harbor.canOpenDrift(data, 11, t), "tomorrow again")
		local seen = {}
		for day = 11, 200 do
			local p = Harbor.openDrift(data, day, t)
			seen[p.item] = true
		end
		ok(seen.Peaches, "Peaches wash up sometimes")
		ok(seen.Coins, "Coins wash up sometimes")
	end)

	test("harbor: isle goods and their jams reach the Order Board after a trip", function()
		local data, t = harborFarm(38)
		data.factories.JamKitchen.built = true
		local function has(pool: { string }, id: string): boolean
			return table.find(pool, id) ~= nil
		end
		local pool = OrderGen.makeablePool(data)
		ok(not has(pool, "Peaches"), "no Peaches before a trip")
		ok(not has(pool, "PeachMarmalade"), "no marmalade before a trip")
		Harbor.send(data, 1, "BlossomCay", nil, t)
		Harbor.unload(data, 1, t + 4 * HOUR)
		pool = OrderGen.makeablePool(data)
		ok(has(pool, "Peaches") and has(pool, "Plums"), "Blossom Cay goods after a trip")
		ok(has(pool, "PeachMarmalade") and has(pool, "PlumJam"), "and their jams")
		ok(not has(pool, "GrapeJelly"), "not Grape Jelly before Vineyard Key")
	end)

	test("harbor: the save block, the level-up list and old saves", function()
		local template = Profile.template()
		ok(template.harbor ~= nil, "harbor block")
		eq(#template.harbor.boats, 0, "no boats yet")
		eq(template.harbor.driftDay, -1, "no crate opened")
		local old = Profile.template()
		old.harbor = nil
		local loaded = Profile.migrate(old) :: any
		ok(loaded.harbor ~= nil and loaded.harbor.trips ~= nil, "old saves get it")
		local function feature(level: number, id: string): boolean
			for _, u in Unlocks.at(level) do
				if u.kind == "Feature" and u.id == id then
					return true
				end
			end
			return false
		end
		ok(feature(29, "Harbor"), "Harbor on the level-29 list")
		ok(feature(35, "VineyardKey"), "Vineyard Key on the level-35 list")
		ok(not feature(29, "BlossomCay"), "Blossom Cay comes with the Harbor")
	end)
end
