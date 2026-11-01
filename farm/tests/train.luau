-- The Train Station (src/shared/Train, Config/Train): the trains and their levels, new cars,
-- loading, sending, the trip, the rewards and the model. Called from tests/run.luau.

local ArtMerge = require("../src/shared/Art/Merge")
local ArtRail = require("../src/shared/Art/Rail")
local Config = require("../src/shared/Config/Train")
local Items = require("../src/shared/Items")
local Kit = require("../src/shared/Art/Kit")
local Layout = require("../src/shared/Layout")
local Profile = require("../src/shared/Profile")
local QuarryConfig = require("../src/shared/Config/Quarry")
local Speedup = require("../src/shared/Speedup")
local Tools = require("../src/shared/Config/Tools")
local Train = require("../src/shared/Train")
local Unlocks = require("../src/shared/Unlocks")

local MIN = 60
local HOUR = 3600

local function farm(level: number): { [string]: any }
	local data = Profile.template()
	data.level = level
	data.tutorial.step = 0
	data.trains.seed = 12345
	return data
end

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("train: Township's train numbers", function()
		eq(Config.unlockLevel, 5, "first train at level 5")
		eq(#Config.trains, 3, "three trains")
		eq(Config.trains[2].level, 14, "train 2 at 14")
		eq(Config.trains[2].coins, 1000, "for 1,000 Coins")
		eq(Config.trains[3].level, 25, "train 3 at 25")
		eq(Config.trains[3].coins, 14000, "for 14,000 Coins")
		eq(Train.carsAt(5), 3, "3 cars at 5")
		eq(Train.carsAt(11), 4, "4 cars at 11")
		eq(Train.carsAt(15), 5, "5 cars at 15")
		eq(Train.travelSeconds(5), 4 * HOUR + 15 * MIN, "4 h 15 at first")
		eq(Train.travelSeconds(60), 5 * HOUR, "5 h at most")
		eq(Train.travelSeconds(138), 5 * HOUR, "never longer")
		eq(Speedup.train(4 * MIN), 1, "1 Gem under 5 min")
		eq(Speedup.train(20 * MIN), 3, "3 Gems under 25 min")
		eq(Speedup.train(4 * HOUR + 30 * MIN), 9, "9 Gems at most")
		local low, high = Train.baseRange("Wheat")
		eq(low, 3, "Wheat from 3")
		eq(high, 37, "to 37 a car")
	end)

	test("train: every good and reward it names is real", function()
		for id, range in Config.qty do
			ok(Items[id] ~= nil, id .. " is an item")
			ok(range[1] >= 1 and range[2] >= range[1], id .. " has a range")
		end
		for _, r in Config.rewards do
			local real = Items[r.item] ~= nil or Tools.tools[r.item] ~= nil or r.item == QuarryConfig.pickaxe
			ok(real, r.item .. " is a reward")
			ok(r.weight > 0 and r.qty > 0, r.item .. " has a weight and count")
		end
		local building = 0
		local total = 0
		for _, r in Train.rewardPool(5) do
			total += r.weight
			if r.item == "Bricks" or r.item == "Planks" or r.item == "Panes" then
				building += r.weight
			end
		end
		ok(building / total > 0.5, "building materials come most often")
		for _, r in Train.rewardPool(5) do
			ok(r.item ~= QuarryConfig.pickaxe, "no Pickaxes before the Quarry")
		end
	end)

	test("train: the first train turns up at level 5 with its cars", function()
		local data = farm(4)
		ok(not Train.ensure(data), "nothing at level 4")
		ok(not Layout.exists(data, "station", "Station"), "no station yet")
		data.level = 5
		ok(Layout.exists(data, "station", "Station"), "the station stands at 5")
		ok(Train.ensure(data), "the first train arrives")
		ok(not Train.ensure(data), "only once")
		local line = Train.lines(data)[1]
		eq(#line.cars, 3, "three cars")
		local pool = Train.pool(data)
		local seen = {}
		for _, car in line.cars do
			ok(table.find(pool, car.item) ~= nil, car.item .. " is makeable")
			ok(not seen[car.item], car.item .. " asked for once")
			seen[car.item] = true
			local low, high = Train.qtyRange(car.item, 5)
			ok(car.qty >= low and car.qty <= high, car.item .. " in its range")
			ok(not car.loaded, "not loaded yet")
			ok(car.reward.item ~= nil and car.reward.qty > 0, "shows its reward")
		end
		ok(line.bonus.item ~= nil, "shows the full-train bonus")
		ok(line.returnAt == nil, "at the platform")
		local found = false
		for _, u in Unlocks.at(5) do
			found = found or (u.kind == "Feature" and u.id == "TrainStation")
		end
		ok(found, "level 5 lists the Train Station")
	end)

	test("train: load, send, come back and unload", function()
		local data = farm(15)
		Train.ensure(data)
		local line = Train.lines(data)[1]
		eq(#line.cars, 5, "five cars at 15")
		local now = 1000
		-- Junk requests find nothing
		for _, bad in { nil, "1", 1.5, 0 / 0, math.huge, -1, 0, 9 } do
			eq(Train.canLoad(data, bad, 1, now), nil, "junk train " .. tostring(bad))
			eq(Train.canLoad(data, 1, bad, now), nil, "junk car " .. tostring(bad))
		end
		local car = Train.canLoad(data, 1, 1, now) :: Train.Car
		ok(car ~= nil, "car 1 can be loaded")
		ok(Train.carXp(car) >= 1, "loading pays XP")
		Train.load(car)
		local again, reason = Train.canLoad(data, 1, 1, now)
		eq(again, nil, "not twice")
		eq(reason, "That car is already loaded", "says why")
		Train.load(line.cars[2])
		local sent = Train.canSend(data, 1)
		ok(sent == line, "it can go")
		Train.send(data, line, now)
		eq(line.returnAt, now + Train.travelSeconds(15), "back after the trip")
		eq(data.trains.trips, 1, "one trip")
		ok(Train.isAway(line, now + 10), "away")
		eq(select(2, Train.canSend(data, 1)), "That train is already out", "can't go twice")
		eq(select(2, Train.canLoad(data, 1, 3, now + 10)), "That train is away", "no loading while away")
		eq(Train.unload(data, 1, now + 10), nil, "nothing to unload yet")
		-- Two loaded cars of five: two rewards, no bonus
		local expected = {}
		for i = 1, 2 do
			local r = line.cars[i].reward
			expected[r.item] = (expected[r.item] or 0) + r.qty
		end
		ok(Train.speedUp(line, now + 10), "Gems bring it back")
		ok(Train.isBack(line, now + 10), "back")
		local rewards = Train.unload(data, 1, now + 10) :: { [string]: number }
		for item, qty in expected do
			eq(rewards[item], qty, "brought " .. item)
		end
		local fresh = Train.lines(data)[1]
		ok(fresh ~= line, "new cars")
		ok(fresh.returnAt == nil and Train.loadedCount(fresh) == 0, "waiting to be loaded")
		eq(Train.unload(data, 1, now + 20), nil, "only once")
	end)

	test("train: a full train brings its bonus too", function()
		local data = farm(20)
		Train.ensure(data)
		local line = Train.lines(data)[1]
		for _, car in line.cars do
			Train.load(car)
		end
		ok(Train.isFull(line), "every car loaded")
		local total = 0
		for _, qty in Train.rewards(line) do
			total += qty
		end
		local want = line.bonus.qty
		for _, car in line.cars do
			want += car.reward.qty
		end
		eq(total, want, "every car's reward and the bonus")
		-- An empty train brings nothing
		local empty =
			{ cars = { { item = "Wheat", qty = 3, reward = { item = "Bricks", qty = 1 } } }, bonus = line.bonus }
		eq(next(Train.rewards(empty)), nil, "nothing for empty cars")
	end)

	test("train: buying the second and third trains", function()
		local data = farm(13)
		Train.ensure(data)
		local index, def = Train.nextTrain(data)
		eq(index, 2, "train 2 next")
		eq(def and def.coins, 1000, "for 1,000 Coins")
		local can, reason = Train.canBuy(data)
		ok(not can, "not at 13")
		eq(reason, "Train 2 can be bought at level 14", "says when")
		data.level = 14
		ok(Train.canBuy(data), "at 14")
		Train.buy(data)
		eq(#Train.lines(data), 2, "two trains")
		ok(not Train.canBuy(data), "train 3 waits for 25")
		data.level = 25
		Train.buy(data)
		eq(#Train.lines(data), 3, "three trains")
		eq(Train.nextTrain(data), nil, "no fourth")
		ok(not Train.canBuy(data), "nothing more to buy")
	end)

	test("train: raw goods are asked for most", function()
		local data = farm(30)
		data.factories.Bakery = { built = true, slots = 3, queue = {}, output = {} }
		local raw, made = 0, 0
		local seed = 777
		for _ = 1, 200 do
			local line
			line, seed = Train.newLine(data, seed)
			for _, car in line.cars do
				local kind = Items[car.item].kind
				if kind == "Crop" or kind == "Animal" then
					raw += 1
				else
					made += 1
				end
			end
		end
		ok(raw > made, string.format("raw %d, made %d", raw, made))
	end)

	test("train: the farm's station and a full train fit their footprint and budget", function()
		local m = Instance.new("Model")
		local static = Instance.new("Model")
		static.Parent = m
		local _, platform = ArtRail.farmStation(static, CFrame.new())
		local engine, cars = ArtRail.farmTrain(m, CFrame.new(), 3, Train.carsAt(15))
		for _, car in cars do
			ArtRail.setCarCrates(car, ArtRail.CAR_CRATES)
		end
		local hw, hd = ArtRail.FARM_SIZE.X / 2 + 0.5, ArtRail.FARM_SIZE.Z / 2 + 0.5
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				local c = p.CFrame.Position
				ok(math.abs(c.X) <= hw and math.abs(c.Z) <= hd, p.Name .. " inside the footprint")
			end
		end
		local w = Layout.KINDS.station
		eq(w.w, ArtRail.FARM_SIZE.X, "layout width matches the art")
		eq(w.d, ArtRail.FARM_SIZE.Z, "layout depth matches the art")
		local merged = ArtMerge.count(static, platform)
		ok(merged <= 20, "station merges to " .. merged .. " parts")
		ok(engine:FindFirstChild("Chassis") ~= nil, "the engine has a chassis to merge around")
		ok(Kit.countParts(m) > 0, "it builds")
	end)
end
