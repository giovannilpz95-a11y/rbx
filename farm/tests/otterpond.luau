-- The Otter Pond (src/shared/OtterPond, Config/OtterPond): building it, buying otters, sending
-- them fishing, the catch drawn per trip, the Order Board pool and the model. Called from
-- tests/run.luau.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local ArtOtterPond = require("../src/shared/Art/OtterPond")
local Blimp = require("../src/shared/Config/Blimp")
local Config = require("../src/shared/Config/OtterPond")
local Items = require("../src/shared/Items")
local Kit = require("../src/shared/Art/Kit")
local Layout = require("../src/shared/Layout")
local OrderGen = require("../src/shared/OrderGen")
local OtterPond = require("../src/shared/OtterPond")
local Profile = require("../src/shared/Profile")
local Recipes = require("../src/shared/Config/Recipes")

local HOUR = 3600

local function farm(level: number): { [string]: any }
	local data = Profile.template()
	data.level = level
	data.tutorial.step = 0
	return data
end

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("otter pond: Township's Otter Pond numbers", function()
		eq(Config.unlockLevel, 58, "at level 58")
		eq(Config.buildCoins, 24000, "24,000 Coins")
		eq(Config.buildSeconds, 60 * HOUR, "2 days 12 h")
		eq(#Config.otterCoins, ArtOtterPond.OTTERS, "three otters")
		eq(Config.otterCoins[1], 0, "the first otter comes with the pond")
		for id, food in Config.foods do
			ok(Items[food.item] ~= nil, id .. " is an item")
			ok(food.seconds > 0, id .. " has a trip time")
			for good, range in food.catch do
				ok(Config.goods[good] ~= nil, id .. " brings a pond good: " .. good)
				ok(range[1] >= 0 and range[1] <= range[2], id .. " " .. good .. " range")
			end
		end
		ok(Config.foods.Fish.seconds < Config.foods.Eggs.seconds, "Fish is the quickest trip")
		for id, good in Config.goods do
			local item = Items[id]
			ok(item ~= nil, id .. " is an item")
			eq(item.kind, "Animal", id .. " is an animal good")
			eq(item.sellPrice, good.sellPrice, id .. " price")
			ok(Blimp.crates[id] ~= nil, id .. " can go on a blimp")
			ok(item.unitSeconds and item.unitSeconds > 0, id .. " has a production time")
		end
		eq(Recipes.SeafoodMix.inputs.Scallop, 1, "Seafood Mix takes a Scallop")
		eq(Recipes.SeaweedShrimpSalad.inputs.Seaweed, 1, "the salad takes Seaweed")
	end)

	test("otter pond: build, buy, feed, fish, collect", function()
		local data = farm(57)
		eq(data.otterPond.otters, 1, "a new save has the pond block")
		local okBuild, why = OtterPond.canBuild(data)
		ok(not okBuild and why ~= nil, "not before 58")
		data.level = 58
		ok(OtterPond.canBuild(data), "can build at 58")
		OtterPond.build(data, 100, 12345)
		eq(data.otterPond.readyAt, 100 + Config.buildSeconds, "building timer")
		ok(not OtterPond.canBuild(data), "only built once")
		ok(not OtterPond.isOpen(data, 101), "not open while building")
		ok(not OtterPond.canFeed(data, 1, "Eggs", 101), "no feeding while building")
		ok(not OtterPond.canBuyOtter(data, 101), "no otters while building")
		ok(OtterPond.finishBuild(data, 200), "speed up")
		ok(OtterPond.isOpen(data, 200), "open once finished")
		ok(not OtterPond.canFeed(data, 1, "Wheat", 200), "only the pond's foods")
		ok(not OtterPond.canFeed(data, 2, "Eggs", 200), "only otters that live here")
		ok(not OtterPond.canFeed(data, "1", "Eggs", 200), "a bad argument is refused")
		ok(not OtterPond.canFeed(data, 1.5, "Eggs", 200), "a fractional otter is refused")
		ok(OtterPond.canFeed(data, 1, "Bacon", 200), "Bacon goes in")
		local trip = OtterPond.feed(data, 1, "Bacon", 200)
		eq(trip.readyAt, 200 + Config.foods.Bacon.seconds, "trip timer")
		local s = trip.catch.Seaweed or 0
		ok(s >= 2 and s <= 3, "Bacon brings 2-3 Seaweed")
		eq(data.otterPond.trips, 1, "trip counted")
		ok(not OtterPond.canFeed(data, 1, "Fish", 300), "one trip per otter")
		eq(OtterPond.collect(data, 1, 300), nil, "nothing while it's fishing")
		eq(OtterPond.firstDone(data, 300), nil, "nobody back yet")

		eq(OtterPond.nextOtterCoins(data), Config.otterCoins[2], "the second otter's price")
		ok(OtterPond.canBuyOtter(data, 300), "can buy a second")
		OtterPond.buyOtter(data)
		OtterPond.buyOtter(data)
		eq(data.otterPond.otters, 3, "three otters")
		eq(OtterPond.nextOtterCoins(data), nil, "no fourth")
		ok(not OtterPond.canBuyOtter(data, 300), "can't buy a fourth")
		OtterPond.buyOtter(data)
		eq(data.otterPond.otters, 3, "still three")
		ok(OtterPond.canFeed(data, 3, "Fish", 300), "the third otter can fish while the first is out")
		OtterPond.feed(data, 3, "Fish", 300)

		ok(OtterPond.skip(data, 1, 400), "skip brings it home")
		ok(OtterPond.isDone(data, 1, 400), "done after skip")
		eq(OtterPond.firstDone(data, 400), 1, "the first otter is back")
		local got = OtterPond.collect(data, 1, 400) :: { [string]: number }
		eq(got.Seaweed, trip.catch.Seaweed, "the catch drawn at feeding")
		eq(OtterPond.trip(data, 1), nil, "home again")
		ok(OtterPond.canFeed(data, 1, "Eggs", 400), "can go out again")
		ok(not OtterPond.skip(data, 2, 400), "nothing to skip for an otter at home")
	end)

	test("otter pond: draws stay in range and better food brings more", function()
		local data = farm(58)
		OtterPond.build(data, 0, 4242)
		data.otterPond.otters = 1
		local now = Config.buildSeconds
		local totals = {}
		for id, food in Config.foods do
			local count = 0
			for _ = 1, 200 do
				local trip = OtterPond.feed(data, 1, id, now)
				for good, range in food.catch do
					local q = trip.catch[good] or 0
					ok(q >= range[1] and q <= range[2], id .. " " .. good .. " in range")
					count += q
				end
				for good in trip.catch do
					ok(food.catch[good] ~= nil, id .. " brings only its goods")
				end
				data.otterPond.away = {}
			end
			totals[id] = count
		end
		ok(totals.Eggs < totals.Bacon and totals.Bacon < totals.Fish, "better food, bigger catch")
		local a = farm(58)
		local b = farm(58)
		OtterPond.build(a, 0, 99)
		OtterPond.build(b, 0, 99)
		local ta = OtterPond.feed(a, 1, "Fish", now)
		local tb = OtterPond.feed(b, 1, "Fish", now)
		ok(ta.catch.Pearls == tb.catch.Pearls and ta.catch.Scallop == tb.catch.Scallop, "the same seed, the same catch")
		eq(OtterPond.average("Bacon", "Seaweed"), 2.5, "Bacon averages 2.5 Seaweed")
		eq(OtterPond.average("Eggs", "Pearls"), 0, "Eggs never bring Pearls")
	end)

	test("otter pond: its goods join the Order Board pool once it's built", function()
		local data = farm(59)
		for _, id in { "FeedMill", "DairyFactory", "PrepKitchen", "SushiBar" } do
			if data.factories[id] then
				data.factories[id].built = true
			else
				data.factories[id] = { built = true }
			end
		end
		data.pens.ChickenCoop = { built = true }
		data.pens.PigPen = { built = true }
		local pool = OrderGen.makeablePool(data)
		ok(not has(pool, "Seaweed"), "no Seaweed before the pond")
		OtterPond.build(data, 0, 5)
		pool = OrderGen.makeablePool(data)
		ok(has(pool, "Seaweed"), "Seaweed once built, with Eggs makeable")
		ok(has(pool, "Pearls"), "Pearls with Bacon makeable")
	end)

	test("otter pond: wired into the server and client", function()
		local net = fs.readFile("src/server/Services/NetService.luau")
		ok(string.find(net, "otterPond = data.otterPond", 1, true) ~= nil, "the snapshot carries otterPond")
		local main = fs.readFile("src/server/Main.server.luau")
		ok(string.find(main, "OtterPondService.init()", 1, true) ~= nil, "the service starts")
		local client = fs.readFile("src/client/Main.client.luau")
		ok(string.find(client, "OtterPondUi.init()", 1, true) ~= nil, "the panel registers")
		local reach = fs.readFile("src/client/Controllers/ReachController.luau")
		ok(string.find(reach, '"OtterCatch"', 1, true) ~= nil, "the catch on the bank can be tapped")
	end)

	test("otter pond: the model, its states and its footprint", function()
		local _ = roblox
		local root = Instance.new("Model")
		local origin = CFrame.new(10, 0, 5) * Kit.yaw(90)
		local parts = ArtOtterPond.build(root, origin)
		local n = Kit.countParts(root)
		ok(n <= ArtOtterPond.PARTS_MAX, string.format("Otter Pond has %d parts, budget %d", n, ArtOtterPond.PARTS_MAX))
		eq(parts.body:GetAttribute("Interact"), "OtterPond", "the dock opens the panel")
		ok(parts.body.CanQuery and parts.body.CanCollide, "a solid tap target")
		local fp = Layout.KINDS.otters
		eq(fp.w, ArtOtterPond.WIDTH, "Layout footprint width")
		eq(fp.d, ArtOtterPond.DEPTH, "Layout footprint depth")
		local function inside()
			Kit.eachPart(root, function(p)
				local c = origin:PointToObjectSpace(p.CFrame.Position)
				ok(
					math.abs(c.X) <= ArtOtterPond.WIDTH / 2 and math.abs(c.Z) <= ArtOtterPond.DEPTH / 2,
					p.Name .. " inside the footprint"
				)
			end)
		end
		inside()
		Kit.eachPart(root, function(p)
			local col = p.Color
			ok(not (col.R > 0.98 and col.G > 0.98 and col.B > 0.98), p.Name .. " not pure white")
			ok(p.CanTouch == false, p.Name .. " CanTouch off")
		end)
		local water = root:FindFirstChild("Water", true) :: BasePart
		ArtOtterPond.setState(root, "Dry")
		eq(water.Transparency, 1, "no water before it's built")
		ArtOtterPond.setState(root, "Open")
		ok(water.Transparency < 1, "water once built")
		local function seen(i: number): boolean
			return ((root:FindFirstChild("Otter" .. i) :: Model):FindFirstChild("Body") :: BasePart).Transparency < 1
		end
		local function catch(i: number): BasePart
			local found
			Kit.eachPart(root, function(p)
				if p:GetAttribute("Interact") == "OtterCatch" and p:GetAttribute("Otter") == i then
					found = p
				end
			end)
			return found
		end
		ArtOtterPond.setOtters(root, { "home", "none", "none" })
		ok(seen(1) and not seen(2) and not seen(3), "one otter at first")
		eq(catch(1).Transparency, 1, "no catch while it's home")
		ArtOtterPond.setOtters(root, { "back", "away", "home" })
		ok(seen(1) and seen(2) and seen(3), "three otters")
		ok(catch(1).Transparency < 1 and catch(1).CanQuery, "the catch waits to be tapped")
		ok(not catch(2).CanQuery, "nothing to tap while it's out")
		inside()
		ArtOtterPond.setState(root, "Dry")
		ok(not seen(1), "no otters in a dry pond")
	end)
end
