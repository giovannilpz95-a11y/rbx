-- The Duck Pond (src/shared/DuckPond, Config/DuckPond): digging it out, feeding it, the ducks
-- drawn per visit, the feathers they leave, the Order Board pool and the model. Called from
-- tests/run.luau.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local ArtDuckPond = require("../src/shared/Art/DuckPond")
local Blimp = require("../src/shared/Config/Blimp")
local Config = require("../src/shared/Config/DuckPond")
local DuckPond = require("../src/shared/DuckPond")
local Items = require("../src/shared/Items")
local Kit = require("../src/shared/Art/Kit")
local Layout = require("../src/shared/Layout")
local OrderGen = require("../src/shared/OrderGen")
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
	test("duck pond: Township's Duck Feeder numbers", function()
		eq(Config.unlockLevel, 48, "at level 48")
		eq(Config.digCoins, 14500, "14,500 Coins")
		eq(Config.digSeconds, 45 * HOUR, "1 day 21 h")
		eq(Config.digXp, 603, "603 XP")
		eq(Config.foods.Bread.seconds, 90 * 60, "Bread 1 h 30")
		eq(Config.foods.BananaBread.seconds, 30 * 60, "Banana Bread 30 min")
		for id, food in Config.foods do
			ok(Recipes[food.item] ~= nil and Recipes[food.item].factory == "Bakery", id .. " is a Bakery good")
			ok(food.ducks[1] >= 1 and food.ducks[2] <= ArtDuckPond.DUCKS, id .. " brings 1 to 4 ducks")
			ok(food.drakes[2] <= food.ducks[2], id .. " never more drakes than ducks")
		end
		for id, feather in Config.feathers do
			local item = Items[id]
			ok(item ~= nil, id .. " is an item")
			eq(item.kind, "Animal", id .. " is an animal good")
			eq(item.sellPrice, feather.sellPrice, id .. " price")
			ok(Blimp.crates[id] ~= nil, id .. " can go on a blimp")
			ok(item.unitSeconds and item.unitSeconds > 0, id .. " has a production time")
		end
		eq(Recipes.Shuttlecock.inputs.DownFeather, 2, "Shuttlecock takes 2 Down Feathers")
		eq(Recipes.FeatherDuster.inputs.ColorfulFeather, 3, "Feather Duster takes 3 Colorful Feathers")
	end)

	test("duck pond: dig, feed, visit, collect", function()
		local data = farm(47)
		eq(data.duckPond.visits, 0, "a new save has the pond block")
		local okDig, why = DuckPond.canDig(data)
		ok(not okDig and why ~= nil, "not before 48")
		data.level = 48
		ok(DuckPond.canDig(data), "can dig at 48")
		DuckPond.dig(data, 100, 12345)
		eq(data.duckPond.readyAt, 100 + Config.digSeconds, "digging timer")
		ok(not DuckPond.canDig(data), "only dug once")
		ok(not DuckPond.isOpen(data, 101), "not open while digging")
		ok(not DuckPond.canFeed(data, "Bread", 101), "no feeding while digging")
		ok(DuckPond.finishDig(data, 200), "speed up")
		ok(DuckPond.isOpen(data, 200), "open once finished")
		ok(not DuckPond.canFeed(data, "Wheat", 200), "only the pond's foods")
		ok(not DuckPond.canFeed(data, 7, 200), "a bad argument is refused")
		ok(DuckPond.canFeed(data, "Bread", 200), "Bread goes in")
		local visit = DuckPond.feed(data, "Bread", 200)
		ok(visit.ducks >= 1 and visit.ducks <= 2, "Bread brings 1-2 ducks")
		eq(visit.drakes, 0, "Bread brings no drakes")
		eq(visit.readyAt, 200 + Config.foods.Bread.seconds, "visit timer")
		eq(data.duckPond.visits, 1, "visit counted")
		ok(not DuckPond.canFeed(data, "Bagel", 300), "one visit at a time")
		eq(DuckPond.collect(data, 300), nil, "nothing to collect while they're here")
		ok(DuckPond.skip(data, 300), "skip ends the visit")
		ok(DuckPond.isDone(data, 300), "done after skip")
		local got = DuckPond.collect(data, 300) :: { [string]: number }
		eq(got.DownFeather, visit.ducks, "a Down Feather per duck")
		eq(got.ColorfulFeather, nil, "no Colorful Feather without drakes")
		eq(data.duckPond.visit, nil, "empty again")
		ok(DuckPond.canFeed(data, "BananaBread", 300), "can feed again")
	end)

	test("duck pond: draws stay in range and better food brings more", function()
		local data = farm(48)
		DuckPond.dig(data, 0, 4242)
		local now = Config.digSeconds
		local totals = {}
		for id, food in Config.foods do
			local ducks = 0
			for _ = 1, 200 do
				local visit = DuckPond.feed(data, id, now)
				ok(visit.ducks >= food.ducks[1] and visit.ducks <= food.ducks[2], id .. " ducks in range")
				ok(visit.drakes >= food.drakes[1] or visit.drakes == visit.ducks, id .. " drakes at least the minimum")
				ok(visit.drakes <= math.min(food.drakes[2], visit.ducks), id .. " drakes within range")
				local f = DuckPond.feathers(visit)
				eq(f.DownFeather, visit.ducks, id .. " Down per duck")
				eq(f.ColorfulFeather or 0, visit.drakes, id .. " Colorful per drake")
				ducks += visit.ducks
				data.duckPond.visit = nil
			end
			totals[id] = ducks
		end
		ok(totals.Bread < totals.Bagel and totals.Bagel < totals.BananaBread, "better food, more ducks")
		local a = farm(48)
		local b = farm(48)
		DuckPond.dig(a, 0, 99)
		DuckPond.dig(b, 0, 99)
		local va = DuckPond.feed(a, "BananaBread", now)
		local vb = DuckPond.feed(b, "BananaBread", now)
		ok(va.ducks == vb.ducks and va.drakes == vb.drakes, "the same seed draws the same ducks")
		local d, k = DuckPond.average("Bagel")
		eq(d, 2, "Bagel averages 2 ducks")
		eq(k, 0.5, "Bagel averages half a drake")
	end)

	test("duck pond: the second pond (Township's Duck Feeder 2)", function()
		local second = Config.ponds.DuckPond2
		eq(second.unlockLevel, 73, "at level 73")
		eq(second.digCoins, 140000, "140,000 Coins")
		eq(second.digSeconds, 77 * HOUR, "3 days 5 h")
		eq(second.digXp, 5780, "5,780 XP")
		eq(Config.ponds.DuckPond.digCoins, Config.digCoins, "the first pond keeps its numbers")
		local data = farm(72)
		eq(data.duckPond2.visits, 0, "a new save has the second pond's block")
		ok(not Layout.exists(data, "pond", "DuckPond2"), "not on the farm before 73")
		local okDig, why = DuckPond.canDig(data, "DuckPond2")
		ok(not okDig and string.find(why or "", "73", 1, true) ~= nil, "locked until 73: " .. tostring(why))
		data.level = 73
		ok(Layout.exists(data, "pond", "DuckPond2"), "turns up at 73")
		ok(DuckPond.canDig(data, "DuckPond2"), "can dig at 73")
		DuckPond.dig(data, 0, 777, nil, "DuckPond2")
		eq(data.duckPond2.readyAt, second.digSeconds, "its own digging timer")
		eq(data.duckPond.readyAt, nil, "the first pond is untouched")
		ok(DuckPond.canDig(data), "the first can still be dug")
		DuckPond.dig(data, 0, 1, nil)
		DuckPond.finishDig(data, 10)
		DuckPond.finishDig(data, 10, "DuckPond2")
		DuckPond.feed(data, "Bread", 10)
		ok(DuckPond.canFeed(data, "Bagel", 10, "DuckPond2"), "both ponds can have ducks at once")
		local visit = DuckPond.feed(data, "Bagel", 10, nil, "DuckPond2")
		eq(data.duckPond2.visit, visit, "the visit lands on the second pond")
		eq(data.duckPond2.visits, 1, "its own visit count")
		eq(data.duckPond.visits, 1, "the first keeps its own count")
		ok(DuckPond.skip(data, 20, "DuckPond2"), "skip the second")
		ok(DuckPond.collect(data, 20, "DuckPond2") ~= nil, "collect from the second")
		eq(data.duckPond2.visit, nil, "second pond empty")
		ok(data.duckPond.visit ~= nil, "first pond's ducks still there")
		local Unlocks = require("../src/shared/Unlocks")
		local listed = false
		for _, unlock in Unlocks.at(73) do
			listed = listed or unlock.id == "DuckPond2"
		end
		ok(listed, "level 73's New! row names the second pond")
		local service = fs.readFile("src/server/Services/DuckPondService.luau")
		ok(string.find(service, "data.duckPond", 1, true) == nil, "the service reads ponds by id")
	end)

	test("duck pond: feathers join the Order Board pool once it's dug", function()
		local data = farm(49)
		for _, id in
			{ "Bakery", "SugarMill", "MoldingWorks", "HomewaresShop", "RubberWorks", "FeedMill", "DairyFactory" }
		do
			if data.factories[id] then
				data.factories[id].built = true
			else
				data.factories[id] = { built = true }
			end
		end
		data.pens.ChickenCoop = { built = true }
		local pool = OrderGen.makeablePool(data)
		ok(not has(pool, "DownFeather"), "no feathers before the pond")
		DuckPond.dig(data, 0, 5)
		pool = OrderGen.makeablePool(data)
		ok(has(pool, "DownFeather"), "Down Feathers once dug, with Bread makeable")
		ok(has(pool, "ColorfulFeather"), "Colorful Feathers with Bagels makeable")
	end)

	test("duck pond: the client gets the pond in its state", function()
		local net = fs.readFile("src/server/Services/NetService.luau")
		ok(
			string.find(net, "duckPond = data.duckPond", 1, true) ~= nil,
			"the snapshot carries duckPond (the panel reads it)"
		)
		local labels = fs.readFile("src/client/UI/WorldLabels.luau")
		ok(
			string.find(labels, "WaitForChild(id)", 1, true) == nil,
			"labels never wait on a building that isn't placed yet"
		)
	end)

	test("duck pond: the model, its states and its footprint", function()
		local _ = roblox
		local root = Instance.new("Model")
		local origin = CFrame.new(10, 0, 5) * Kit.yaw(90)
		local parts = ArtDuckPond.build(root, origin)
		local n = Kit.countParts(root)
		ok(n <= ArtDuckPond.PARTS_MAX, string.format("Duck Pond has %d parts, budget %d", n, ArtDuckPond.PARTS_MAX))
		eq(parts.body:GetAttribute("Interact"), "DuckPond", "the feeder opens the panel")
		ok(parts.body.CanQuery and parts.body.CanCollide, "a solid tap target")
		local fp = Layout.KINDS.pond
		eq(fp.w, ArtDuckPond.SIZE, "Layout footprint width")
		eq(fp.d, ArtDuckPond.SIZE, "Layout footprint depth")
		Kit.eachPart(root, function(p)
			local c = origin:PointToObjectSpace(p.CFrame.Position)
			ok(
				math.abs(c.X) <= ArtDuckPond.SIZE / 2 and math.abs(c.Z) <= ArtDuckPond.SIZE / 2,
				p.Name .. " inside the footprint"
			)
			local col = p.Color
			ok(not (col.R > 0.98 and col.G > 0.98 and col.B > 0.98), p.Name .. " not pure white")
			ok(p.CanTouch == false, p.Name .. " CanTouch off")
		end)
		local water = root:FindFirstChild("Water", true) :: BasePart
		local mud = root:FindFirstChild("Mud", true) :: BasePart
		ArtDuckPond.setState(root, "Overgrown")
		ok(water.Transparency == 1 and mud.Transparency < 1, "muddy while overgrown")
		ArtDuckPond.setState(root, "Open")
		ok(water.Transparency < 1 and mud.Transparency == 1, "water once dug")
		ArtDuckPond.setDucks(root, 3, 1, false)
		local function seen(i: number): boolean
			return ((root:FindFirstChild("Duck" .. i) :: Model):FindFirstChild("Body") :: BasePart).Transparency < 1
		end
		ok(seen(1) and seen(3) and not seen(4), "three ducks on the water")
		local feather = root:FindFirstChild("Feather", true) :: BasePart
		eq(feather.Transparency, 1, "no feather while they're here")
		ArtDuckPond.setDucks(root, 0, 1, true)
		ok(not seen(1), "the ducks swim off")
		ok(feather.Transparency < 1 and feather.CanQuery, "the feather waits to be tapped")
	end)
end
