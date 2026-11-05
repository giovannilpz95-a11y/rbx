-- Sky events (src/shared/Sky, Config/Sky): the fixed schedule, the forecast, the rain's faster
-- growth and the weather Prize traits. Called from tests/run.luau.

local Config = require("../src/shared/Config/Sky")
local ExpressConfig = require("../src/shared/Config/Express")
local Prize = require("../src/shared/Config/Prize")
local PrizeRules = require("../src/shared/Prize")
local Profile = require("../src/shared/Profile")
local Sky = require("../src/shared/Sky")

local HOUR = 3600
local T0 = 1793491200 -- 2026-11-01 00:00 UTC, a Sunday

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("sky: the calendar maths", function()
		eq(Sky.weekday(T0), 0, "2026-11-01 is a Sunday")
		eq(Sky.weekday(T0 + 6 * 24 * HOUR), 6, "the 7th a Saturday")
		eq(Sky.hourOfDay(T0 + 17 * HOUR + 59), 17, "hour of day")
		ok(Sky.isPeak(T0 + 6 * 24 * HOUR + 18 * HOUR), "Saturday 18:00 is the peak")
		ok(not Sky.isPeak(T0 + 6 * 24 * HOUR + 22 * HOUR), "22:00 is not")
		ok(not Sky.isPeak(T0 + 18 * HOUR), "Sunday is not")
	end)

	test("sky: 1-2 events an hour, clear of the Town Express, varied", function()
		local counts = { 0, 0, 0 }
		local kinds = { Rain = 0, Starfall = 0 }
		local minutes = {}
		local firstHour = math.floor(T0 / HOUR)
		for h = firstHour, firstHour + 24 * 14 - 1 do
			local events = Sky.eventsInHour(h)
			counts[#events] = (counts[#events] or 0) + 1
			ok(#events >= 1 and #events <= 2, "one or two in hour " .. h)
			local prevEnd = h * HOUR
			for _, e in events do
				kinds[e.kind] += 1
				ok(e.startsAt >= prevEnd, "no overlap")
				ok(e.endsAt <= (h + 1) * HOUR, "ends inside its hour")
				-- The Express window is :00-:20 of even hours
				ok(e.startsAt % HOUR >= ExpressConfig.windowSeconds, "after the Express window")
				eq(e.endsAt - e.startsAt, Config.kinds[e.kind].seconds, "its length")
				minutes[(e.startsAt % HOUR) // 60] = true
				prevEnd = e.endsAt
			end
		end
		local hours = 24 * 14
		local share = counts[2] / hours
		ok(share > 0.3 and share < 0.6, "about 40% of hours have two (plus the peak): " .. share)
		ok(kinds.Rain > kinds.Starfall, "rain more often than stars")
		ok(kinds.Starfall > hours * 0.3, "but plenty of Starfalls")
		local distinct = 0
		for _ in minutes do
			distinct += 1
		end
		ok(distinct >= 15, "start minutes vary: " .. distinct)
		-- The same hour always gives the same events (every server agrees)
		local a, b = Sky.eventsInHour(firstHour + 5), Sky.eventsInHour(firstHour + 5)
		eq(#a, #b, "deterministic")
		eq(a[1].startsAt, b[1].startsAt, "deterministic start")
		-- Neighbouring hours don't drift by a fixed step
		local steps = {}
		for h = firstHour, firstHour + 10 do
			local d = (Sky.eventsInHour(h + 1)[1].startsAt % HOUR) - (Sky.eventsInHour(h)[1].startsAt % HOUR)
			steps[d] = true
		end
		local n = 0
		for _ in steps do
			n += 1
		end
		ok(n >= 4, "no fixed drift between hours")
	end)

	test("sky: the peak has two every hour", function()
		local saturday = math.floor((T0 + 6 * 24 * HOUR) / HOUR)
		for h = saturday + Config.peak.fromHour, saturday + Config.peak.toHour - 1 do
			eq(#Sky.eventsInHour(h), 2, "two at hour " .. (h - saturday))
		end
	end)

	test("sky: current, next and the forecast", function()
		local hour = math.floor(T0 / HOUR) + 3
		local first = Sky.eventsInHour(hour)[1]
		eq(Sky.current(first.startsAt - 1), nil, "clear just before")
		local now = Sky.current(first.startsAt + 5)
		ok(now ~= nil and now.startsAt == first.startsAt, "running just after")
		eq(Sky.current(first.endsAt), nil, "over at its end")
		local nextOne = Sky.nextEvent(first.startsAt - 60) :: any
		eq(nextOne.startsAt, first.startsAt, "next is the first one")
		ok(Sky.nextEvent(first.startsAt).startsAt > first.startsAt, "then the one after")
		local text = Sky.forecastText(first)
		ok(text:find("expected at :", 1, true) ~= nil, text)
		ok(text:find(Config.kinds[first.kind].displayName, 1, true) ~= nil, "names it")
	end)

	test("sky: the rain grows fields faster while it lasts", function()
		local rain = { kind = "Rain", startsAt = 1000, endsAt = 1180 }
		eq(Sky.growCut(rain, 5000, 1000), 27, "15% of 3 minutes")
		eq(Sky.growCut(rain, 1100, 1000), 15, "a crop ready in 100 s gains 15")
		eq(Sky.growCut(rain, 5000, 1120), 9, "joined with 60 s left: 9")
		eq(Sky.growCut({ kind = "Starfall", startsAt = 1000, endsAt = 1120 }, 5000, 1000), 0, "stars don't")
		ok(Sky.isGrowing({ crop = "Wheat", readyAt = 2000 }, 1000), "growing")
		ok(not Sky.isGrowing({ crop = "Wheat", readyAt = 900 }, 1000), "ready is not growing")
		ok(not Sky.isGrowing({}, 1000), "empty is not growing")
	end)

	test("sky: weather traits roll once per event and keep rarer ones", function()
		local data = Profile.migrate(nil) :: any
		data.tutorial.step = 0
		local rain = { kind = "Rain", startsAt = 1000, endsAt = 1180 }
		local field: any = { crop = "Wheat", readyAt = 5000 }
		ok(Sky.weatherRoll(data, field, rain, 0.05), "a 10% roll hits")
		eq(field.prize, "Dewkissed", "Dewkissed")
		eq(field.sky, 1000, "marked for this event")
		local again: any = { crop = "Wheat", readyAt = 5000, sky = 1000 }
		eq(Sky.weatherRoll(data, again, rain, 0), false, "only once per event")
		local miss: any = { crop = "Wheat", readyAt = 5000 }
		eq(Sky.weatherRoll(data, miss, rain, 0.1), false, "0.1 misses")
		eq(miss.prize, nil, "nothing")
		local sunny: any = { crop = "Wheat", readyAt = 5000, prize = "Sunkissed" }
		ok(Sky.weatherRoll(data, sunny, rain, 0), "upgrades Sunkissed")
		eq(sunny.prize, "Dewkissed", "x4 beats x3")
		local heir: any = { crop = "Wheat", readyAt = 5000, prize = "Heirloom" }
		eq(
			Sky.weatherRoll(data, heir, { kind = "Starfall", startsAt = 2000, endsAt = 2120 }, 0),
			false,
			"keeps Heirloom"
		)
		eq(heir.prize, "Heirloom", "still Heirloom")
		local star: any = { crop = "Wheat", readyAt = 5000 }
		ok(Sky.weatherRoll(data, star, { kind = "Starfall", startsAt = 2000, endsAt = 2120 }, 0.04), "5% Starlit")
		eq(star.prize, "Starlit", "Starlit")
		data.tutorial.step = 3
		local guide: any = { crop = "Wheat", readyAt = 5000 }
		eq(Sky.weatherRoll(data, guide, rain, 0), false, "none during the guide")
	end)

	test("sky: weather traits never come from an ordinary harvest roll", function()
		local data = Profile.migrate(nil) :: any
		data.tutorial.step = 0
		for i = 0, 999 do
			local tier = PrizeRules.roll(data, i / 1000)
			ok(tier == nil or not (Prize.tiers[tier] :: any).weather, "no weather trait at " .. i)
		end
		eq(PrizeRules.value("Corn", "Dewkissed"), 12, "x4 at the Prize Stand")
		eq(PrizeRules.value("Corn", "Starlit"), 18, "x6")
		ok(Prize.tiers.Starlit.value < Prize.tiers.Heirloom.value, "Heirloom stays the rarest prize")
	end)

	test("sky: the Rainbow", function()
		eq(Sky.chestCoins(10), 30, "10 + 2 a level")
		eq(Sky.thanksCoins(10), 15, "the owner's thanks: 5 + 1 a level")
		ok(Config.rainbow.reach > 7, "the server allows more than the client's open distance")
		-- A rainbow after the latest rain still fades before the second slot can start
		local lastRainEnd = Config.slots[1].to * 60 + Config.kinds.Rain.seconds
		ok(lastRainEnd + Config.rainbow.seconds < Config.slots[2].from * 60, "clear of the second slot")
	end)

	test("sky: the Golden Goose", function()
		eq(Sky.eggCoins(10), 75, "a Golden Egg: 25 + 5 a level")
		ok(Sky.eggCoins(1) > Sky.chestCoins(1), "worth more than a rainbow chest")
		ok(Config.goose.reach > 7, "the server allows more than the client's petting distance")
		ok(Config.goose.side ~= 0 or Config.goose.ahead ~= Config.rainbow.ahead, "it stands clear of a rainbow chest")
		ok(Config.goose.chance * 3600 / Config.goose.checkSeconds < 1, "rare: under one visit an hour")
	end)

	test("sky: stars", function()
		eq(Sky.starsPerShower("Starfall"), 12, "12 stars in a Starfall")
		eq(Sky.starCoins(10), 14, "4 + 1 a level")
		ok(Config.starReach > 7, "the server allows more than the client's catch distance")
	end)
end
