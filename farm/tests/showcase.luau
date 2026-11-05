-- The Plot Showcase (src/shared/Showcase, Config/Showcase): the hourly window, the checks on a
-- rating, weighted sunflowers and the winner. Called from tests/run.luau.

local Config = require("../src/shared/Config/Showcase")
local ExpressConfig = require("../src/shared/Config/Express")
local Profile = require("../src/shared/Profile")
local Showcase = require("../src/shared/Showcase")
local SkyConfig = require("../src/shared/Config/Sky")

local HOUR = 3600
local T = 1793491200

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("showcase: every hour at :40 for five minutes, clear of the Express and sky slots", function()
		Showcase.setPreview(nil)
		local startsAt, endsAt = Showcase.window(T + 5)
		eq(startsAt, T + 40 * 60, ":40")
		eq(endsAt - startsAt, Config.seconds, "five minutes")
		ok(Showcase.isOn(T + 41 * 60), "on at :41")
		ok(not Showcase.isOn(T + 46 * 60), "off at :46")
		ok(Showcase.canRate(T + 45 * 60 + 10), "a card still open just after counts")
		ok(not Showcase.canRate(T + 47 * 60), "but not later")
		ok(Config.minute * 60 >= ExpressConfig.windowSeconds, "after the Town Express window")
		ok(
			Config.minute > SkyConfig.slots[1].to and Config.minute + Config.seconds / 60 <= SkyConfig.slots[2].from,
			"between the sky slots' starts"
		)
		Showcase.setPreview(T + 5)
		eq((Showcase.window(T + 10)), T + 5, "the Studio preview")
		Showcase.setPreview(nil)
	end)

	test("showcase: who may rate", function()
		eq(Showcase.check(10, 1, 2, true, 25, false, 3), nil, "fine")
		eq(Showcase.check(10, 1, 2, true, 25, false, 4), "junk", "1-3 only")
		eq(Showcase.check(10, 1, 2, true, 25, false, 1.5), "junk", "whole sunflowers")
		ok(Showcase.check(10, 2, 2, true, 25, false, 3) ~= nil, "never your own farm")
		ok(Showcase.check(Config.minLevel - 1, 1, 2, true, 25, false, 3) ~= nil, "level 5+")
		ok(Showcase.check(10, 1, 2, false, 25, false, 3) ~= nil, "only farms on show")
		ok(Showcase.check(10, 1, 2, true, 25, true, 3) ~= nil, "once a farm")
		ok(Showcase.check(10, 1, 2, true, 5, false, 3) ~= nil, "after a while on it")
	end)

	test("showcase: sunflowers and the winner", function()
		eq(
			Showcase.total({ { voter = 1, stars = 3, weight = 1 }, { voter = 2, stars = 2, weight = 0.5 } }),
			4,
			"friends count half"
		)
		local winner, total = Showcase.winner({
			[10] = { { voter = 1, stars = 3, weight = 1 } }, -- one vote: can't win
			[20] = { { voter = 1, stars = 2, weight = 1 }, { voter = 2, stars = 2, weight = 1 } },
			[30] = { { voter = 1, stars = 3, weight = 0.5 }, { voter = 2, stars = 2, weight = 1 } },
		})
		eq(winner, 20, "the most sunflowers with enough votes")
		eq(total, 4, "its sunflowers")
		eq((Showcase.winner({})), nil, "nobody")
		local tie = Showcase.winner({
			[7] = { { voter = 1, stars = 2, weight = 1 }, { voter = 2, stars = 2, weight = 1 } },
			[5] = { { voter = 1, stars = 2, weight = 1 }, { voter = 2, stars = 2, weight = 1 } },
		})
		eq(tie, 5, "ties go the same way on every run")
	end)

	test("showcase: opt-in by default off", function()
		local data = Profile.migrate(nil) :: any
		eq(data.showcase.optIn, false, "nobody is on show unasked")
		eq(data.showcase.ribbonUntil, 0, "no ribbon")
	end)
end
