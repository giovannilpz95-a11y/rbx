-- The Tonic Shed (src/shared/Tonics, Config/Tonics, Features/F09): building it, switching
-- tonics on and off, the modifier pipeline the other systems read, Fair Winds and Swift Sails
-- at the Harbor, tonics in Full Hold chests, and the model. Called from tests/run.luau.

local roblox = require("@lune/roblox")

local Analytics = require("../src/shared/Analytics")
local ArtTonicShed = require("../src/shared/Art/TonicShed")
local Blimp = require("../src/shared/Blimp")
local Config = require("../src/shared/Config/Tonics")
local Harbor = require("../src/shared/Harbor")
local Isles = require("../src/shared/Config/Isles")
local Items = require("../src/shared/Items")
local Kit = require("../src/shared/Art/Kit")
local Layout = require("../src/shared/Layout")
local Profile = require("../src/shared/Profile")
local Tonics = require("../src/shared/Tonics")
local Unlocks = require("../src/shared/Unlocks")

local HOUR = 3600
local DAY = 24 * HOUR

local function farm(level: number): { [string]: any }
	local data = Profile.template()
	data.level = level
	data.tutorial.step = 0
	return data
end

local function openShed(level: number?): ({ [string]: any }, number)
	local data = farm(level or 18)
	Tonics.build(data, 0)
	return data, Config.buildSeconds
end

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("tonics: Township's Laboratory numbers", function()
		eq(Config.unlockLevel, 18, "at level 18")
		eq(Config.buildCoins, 1800, "1,800 Coins")
		eq(Config.population, 560, "Population 560")
		eq(Config.buildSeconds, DAY, "1 day")
		eq(Config.buildXp, 79, "79 XP")
		eq(Config.maxActive, 3, "3 at once")
		-- Lab-gem costs at 10 / 20 / 30 Gems a topaz / emerald / ruby
		eq(Config.tonics.BumperCrop.gems, 5 * 10 + 3 * 20, "Super-Harvest")
		eq(Config.tonics.HappyHerd.gems, 7 * 10 + 2 * 30, "Advanced Farming")
		eq(Config.tonics.GoodCustomer.gems, 6 * 10 + 3 * 20 + 2 * 30, "Generous Customer")
		eq(Config.tonics.BusyBeesOil.gems, 8 * 10 + 2 * 20 + 2 * 30, "High-Speed Production")
		eq(Config.tonics.HotSmelter.gems, 2 * 10 + 4 * 20 + 3 * 30, "Efficient Smelting")
		eq(Config.tonics.FairWinds.gems, 7 * 10 + 2 * 20, "Favorable Voyage")
		for _, def in Config.list do
			ok(Items[def.id] == nil, def.id .. " isn't also a Barn item")
			ok(def.seconds == (if def.gems then 2 * DAY else DAY), def.id .. " runs 2 days (Gem) or 1 day (earned)")
			ok(Config.chestWeights[def.id] ~= nil, def.id .. " can drop from a chest")
		end
		eq(#Config.list, 10, "ten tonics")
		ok(ArtTonicShed.JARS == Config.maxActive, "a jar per running tonic")
	end)

	test("tonics: the save block, the lot and the level-up notice", function()
		local old = Profile.template()
		old.tonics = nil
		local data = Profile.migrate(old) :: any
		ok(data.tonics ~= nil and #data.tonics.active == 0, "old saves get an empty shed")
		ok(not Layout.exists(farm(17), "tonics", "TonicShed"), "no lot before 18")
		ok(Layout.exists(farm(18), "tonics", "TonicShed"), "the lot from 18")
		local found = false
		for _, u in Unlocks.at(18) do
			found = found or u.id == "TonicShed"
		end
		ok(found, "level 18 announces the Tonic Shed")
	end)

	test("tonics: building the shed", function()
		local data = farm(17)
		local can, why = Tonics.canBuild(data, 1000)
		ok(not can and why ~= nil, "not before 18")
		data.level = 18
		can, why = Tonics.canBuild(data, 100)
		ok(not can and why ~= nil, "needs Population 560")
		ok(Tonics.canBuild(data, 560), "can build")
		Tonics.build(data, 100)
		eq(data.tonics.readyAt, 100 + DAY, "a day")
		ok(not Tonics.canBuild(data, 1000), "only once")
		ok(not Tonics.isOpen(data, 200), "still building")
		local how, reason = Tonics.canActivate(data, "BumperCrop", 200)
		ok(how == nil and reason ~= nil, "no tonics while building")
		ok(Tonics.finishBuild(data, 200), "Gems finish it")
		ok(Tonics.isOpen(data, 200), "open")
		ok(not Tonics.finishBuild(data, 300), "nothing to finish")
		Tonics.build(farm(18), 0, 0.01)
	end)

	test("tonics: switching on, the cap of three, no doubles, stopping", function()
		local data, t = openShed()
		eq(Tonics.canActivate(data, "Nope", t), nil, "unknown ids refused")
		eq(Tonics.canActivate(data, 42, t), nil, "junk refused")
		eq(Tonics.canActivate(data, "BumperCrop", t), "gems", "Gem tonics cost Gems")
		local how, why = Tonics.canActivate(data, "QuickSprout", t)
		ok(how == nil and why ~= nil, "earned-only tonics can't be bought")
		Tonics.give(data, "QuickSprout", 2)
		eq(Tonics.owned(data, "QuickSprout"), 2, "two earned")
		eq(Tonics.canActivate(data, "QuickSprout", t), "owned", "an earned one is free")
		local entry = Tonics.activate(data, "QuickSprout", "owned", t)
		eq(entry.endsAt, t + DAY, "runs a day")
		eq(Tonics.owned(data, "QuickSprout"), 1, "one used")
		how, why = Tonics.canActivate(data, "QuickSprout", t)
		ok(how == nil and why ~= nil, "never two of the same")
		Tonics.activate(data, "BumperCrop", "gems", t)
		Tonics.activate(data, "GoodCustomer", "gems", t)
		eq(Tonics.activeCount(data, t), 3, "three running")
		how, why = Tonics.canActivate(data, "HappyHerd", t)
		ok(how == nil and why ~= nil, "at most three")
		ok(not Tonics.cancel(data, "HappyHerd", t), "can't stop one that isn't running")
		ok(Tonics.cancel(data, "GoodCustomer", t + HOUR), "stop one")
		eq(Tonics.activeCount(data, t + HOUR), 2, "two left")
		eq(Tonics.canActivate(data, "GoodCustomer", t + HOUR), "gems", "and it can start again (time lost)")
		-- Running out
		eq(Tonics.activeCount(data, t + DAY), 1, "Quick Sprout ran out after a day")
		local ended = Tonics.prune(data, t + DAY)
		eq(#ended, 1, "pruned")
		eq(ended[1], "QuickSprout", "the one that ended")
		eq(Tonics.prune(data, t + 2 * DAY)[1], "BumperCrop", "Bumper Crop after two")
		eq(#data.tonics.active, 0, "none left")
		-- The earned store
		Tonics.give(data, "Nope", 3)
		eq(data.tonics.owned.Nope, nil, "only real tonics are stored")
		Tonics.activate(data, "QuickSprout", "owned", t + 3 * DAY)
		eq(data.tonics.owned.QuickSprout, nil, "the last one used clears the entry")
		-- Studio time scale
		local fast = openShed()
		eq(Tonics.activate(fast, "HappyHerd", "gems", 0, 0.01).endsAt, math.floor(2 * DAY * 0.01 + 0.5), "scaled")
	end)

	test("tonics: the modifier pipeline", function()
		local data, t = openShed(30)
		eq(Tonics.value(data, "fieldYield", t), 1, "nothing running: x1")
		eq(Tonics.value(data, "factoryTime", t), 0, "nothing running: no cut")
		eq(Tonics.value({}, "fieldYield", t), 1, "a snapshot without the block")
		for _, def in Config.list do
			local d = openShed(30)
			Tonics.activate(d, def.id, "gems", t)
			eq(Tonics.value(d, def.stat, t), def.value, def.id .. " sets " .. def.stat)
			eq(Tonics.value(d, def.stat, t + def.seconds), if def.stat == "factoryTime" then 0 else 1, "and stops")
		end
		eq(Config.tonics.BumperCrop.value, 2, "double crops")
		eq(Config.tonics.HappyHerd.value, 2, "double animal goods")
		eq(Config.tonics.GoodCustomer.value, 2, "double order Coins")
		eq(Config.tonics.QuickSprout.value, 0.6, "40% faster crops")
		eq(Config.tonics.BusyBoard.value, 0.2, "orders 80% sooner")
		-- Factories: Busy Bees Oil's 30% adds to the Guild's cut; Smelters use Hot Smelter
		eq(Tonics.factoryMult(data, "Bakery", 0.8, t), 0.8, "Guild only")
		Tonics.activate(data, "BusyBeesOil", "gems", t)
		ok(math.abs(Tonics.factoryMult(data, "Bakery", 0.8, t) - 0.5) < 1e-9, "-20% and -30% = -50%")
		eq(Tonics.factoryMult(data, "Smelter", 1, t), 1, "Busy Bees Oil skips Smelters")
		ok(Tonics.isSmelter("Smelter2") and Tonics.isSmelter("Smelter3"), "copies are Smelters")
		ok(not Tonics.isSmelter("Bakery"), "a Bakery isn't")
		eq(Tonics.factoryMult(data, "Bakery", 0.2, t), 0.1, "never under 10%")
		Tonics.activate(data, "HotSmelter", "gems", t)
		eq(Tonics.factoryMult(data, "Smelter2", 0.9, t), 0.45, "Hot Smelter halves")
	end)

	test("tonics: Fair Winds and Swift Sails at the Harbor", function()
		local data = farm(29)
		Harbor.repair(data, 0, 777)
		local t = Isles.repairSeconds
		Tonics.build(data, 0)
		local u1, r1, c1 = Harbor.odds("BlossomCay", "CopperBar")
		local u2, r2, c2 = Harbor.odds("BlossomCay", "CopperBar", nil, 2)
		local base = Isles.byId.BlossomCay.odds[1]
		ok(math.abs((u2 - base[1]) - 2 * (u1 - base[1])) < 1e-9, "the Bar's push on the uncommon good doubles")
		ok(math.abs((r2 - base[2]) - 2 * (r1 - base[2])) < 1e-9, "and on the rare good")
		ok(math.abs(c2 - 2 * c1) < 1e-9, "and on the Sea Chest")
		local u5 = Harbor.odds("BlossomCay", "PlatinumBar", nil, 2)
		ok(u5 <= 1, "capped at 100%")
		eq(Harbor.odds("BlossomCay", nil, nil, 2), Harbor.odds("BlossomCay", nil), "no Bar, no change")
		eq(Harbor.qtyRow("CopperBar", 2), 3, "Copper counts like Gold for amounts")
		eq(Harbor.qtyRow("GoldBar", 2), #Isles.qty, "capped at the best row")
		eq(Harbor.qtyRow(nil, 2), 1, "no Bar")
		-- Sending with Fair Winds rolls with the boosted odds (same seed as the boosted roll)
		local seed = data.harbor.seed
		Tonics.activate(data, "FairWinds", "gems", t)
		Harbor.send(data, 1, "BlossomCay", "CopperBar", t)
		local cargo = Harbor.roll("BlossomCay", "CopperBar", seed, Harbor.isleLevels(data, "BlossomCay"), 2)
		eq(#data.harbor.boats[1].cargo, #cargo, "the boosted roll")
		eq(data.harbor.boats[1].returnAt, t + Harbor.tripSeconds(data, "BlossomCay"), "normal speed")
		-- Swift Sails halves the trip of a boat sent while it runs
		local fast = farm(29)
		Harbor.repair(fast, 0, 777)
		Tonics.build(fast, 0)
		Tonics.activate(fast, "SwiftSails", "gems", t)
		Harbor.send(fast, 1, "BlossomCay", nil, t)
		eq(fast.harbor.boats[1].returnAt, t + Harbor.tripSeconds(fast, "BlossomCay") / 2, "half the trip")
	end)

	test("tonics: Full Hold chests sometimes hold one", function()
		eq(Tonics.chestDraw(Config.chestChance, 0), nil, "a miss")
		eq(Tonics.chestDraw(0, 0), Config.list[1].id, "a hit picks by weight")
		eq(Tonics.chestDraw(0, 0.9999), Config.list[#Config.list].id, "the last one")
		local seen, hits = {}, 0
		for i = 1, 2000 do
			local id = Tonics.chestDraw((i % 100) / 100, (i * 7 % 1000) / 1000)
			if id then
				hits += 1
				seen[id] = true
			end
		end
		ok(math.abs(hits / 2000 - Config.chestChance) < 0.02, "about the chance")
		for _, def in Config.list do
			ok(seen[def.id], def.id .. " drops")
		end
		-- Loads: some chests have a fourth prize that's a tonic
		local found = 0
		for seed = 1, 60 do
			local data = farm(30)
			Blimp.repair(data, 0, seed * 7919)
			for _, prize in data.blimp.load.chest do
				if Tonics.isTonic(prize.item) then
					found += 1
				end
			end
		end
		ok(found > 5 and found < 40, "tonics in some Full Hold chests: " .. found)
	end)

	test("tonics: Gem tonics are their own analytics SKU", function()
		local sku, tx = Analytics.sku("tonic_BumperCrop", "Gems")
		eq(sku, "Tonic", "sku")
		eq(tx, "ContextualPurchase", "a Gem purchase")
		eq((Analytics.sku("tonic_build", "Coins")), "Tonic", "building it")
		eq((Analytics.sku("order_tonic", "Coins")), "OrderBoard", "Good Customer's Coins are order Coins")
	end)

	test("tonics: the model, its states and its footprint", function()
		local _ = roblox
		local root = Instance.new("Model")
		local origin = CFrame.new(8, 0, -4) * Kit.yaw(90)
		local parts = ArtTonicShed.build(root, origin)
		local n = Kit.countParts(root)
		ok(n <= ArtTonicShed.PARTS_MAX, string.format("Tonic Shed has %d parts, budget %d", n, ArtTonicShed.PARTS_MAX))
		eq(parts.body:GetAttribute("Interact"), "TonicShed", "the bench opens the panel")
		eq(parts.board:GetAttribute("Interact"), "TonicShed", "so does the board")
		ok(parts.body.CanQuery and parts.body.CanCollide, "a solid tap target")
		local fp = Layout.KINDS.tonics
		eq(fp.w, ArtTonicShed.SIZE, "Layout footprint width")
		eq(fp.d, ArtTonicShed.SIZE, "Layout footprint depth")
		eq(Layout.DISPLAY.tonics, "Tonic Shed", "move label")
		Kit.eachPart(root, function(p)
			local c = origin:PointToObjectSpace(p.CFrame.Position)
			ok(
				math.abs(c.X) <= ArtTonicShed.SIZE / 2 and math.abs(c.Z) <= ArtTonicShed.SIZE / 2,
				p.Name .. " inside the footprint"
			)
			local col = p.Color
			ok(not (col.R > 0.98 and col.G > 0.98 and col.B > 0.98), p.Name .. " not pure white")
			ok(p.CanTouch == false, p.Name .. " CanTouch off")
		end)
		local walls = root:FindFirstChild("Walls", true) :: BasePart
		local sign = root:FindFirstChild("LotSign", true) :: BasePart
		local jar1 = root:FindFirstChild("Jar1", true) :: BasePart
		local jar3 = root:FindFirstChild("Jar3", true) :: BasePart
		ArtTonicShed.setState(root, "Lot")
		ok(walls.Transparency == 1 and not walls.CanCollide and sign.Transparency < 1, "an empty lot first")
		eq(jar1.Transparency, 1, "no jars on the lot")
		ArtTonicShed.setState(root, "Open")
		ok(walls.Transparency < 1 and walls.CanCollide and sign.Transparency == 1, "the shed once built")
		eq(jar1.Transparency, 1, "no jars with nothing running")
		local green = Color3.fromRGB(139, 211, 70)
		ArtTonicShed.setJars(root, { green })
		ok(jar1.Transparency < 1 and jar1.Color == green, "one jar, in the tonic's colour")
		eq(jar3.Transparency, 1, "the others empty")
	end)
end
