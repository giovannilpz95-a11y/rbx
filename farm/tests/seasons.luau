-- Seasonal looks (src/shared/Seasons, Config/Seasons): each starts on the first Friday (UTC) of
-- its window. Called from tests/run.luau.

local Config = require("../src/shared/Config/Seasons")
local Seasons = require("../src/shared/Seasons")

local DAY = 86400
local NOV1_2026 = 1793491200 -- a Sunday

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("seasons: first Fridays", function()
		eq(Seasons.firstFriday(2026, 11), NOV1_2026 + 5 * DAY, "6 Nov 2026")
		eq(Seasons.firstFriday(2026, 12), NOV1_2026 + 33 * DAY, "4 Dec 2026")
		eq(Seasons.firstFriday(1970, 1), 1 * DAY, "2 Jan 1970")
		for _, y in { 2026, 2027, 2028 } do
			for m = 1, 12 do
				local at = Seasons.firstFriday(y, m)
				eq((at // DAY + 4) % 7, 5, string.format("%d-%d is a Friday", y, m))
			end
		end
	end)

	test("seasons: the calendar", function()
		eq(Seasons.at(NOV1_2026 + 4 * DAY).id, "HarvestMoon", "November is the Harvest Moon")
		eq(Seasons.at(NOV1_2026 + 33 * DAY - 1).id, "HarvestMoon", "until the first Friday of December")
		eq(Seasons.at(NOV1_2026 + 33 * DAY).id, "FrostyFields", "then Frosty Fields")
		local jan = Seasons.firstFriday(2027, 1)
		eq(Seasons.at(jan).id, "FrostyFields", "through the new year")
		local march = Seasons.firstFriday(2027, 3)
		eq(Seasons.at(march - 1).id, "FrostyFields", "the day before spring")
		eq(Seasons.at(march).id, "SpringBloom", "Spring Bloom")
		eq(Seasons.at(Seasons.firstFriday(2027, 7)).id, "SummerSun", "summer")
		eq(Seasons.at(Seasons.firstFriday(2027, 9) + 10).id, "HarvestMoon", "and back to autumn")
	end)

	test("seasons: every look is gentle", function()
		for id, s in Config.seasons do
			ok(math.abs(s.saturation) <= 0.1, id .. " grade stays light")
			if s.particles then
				ok(s.particles.reducedRate < s.particles.rate, id .. " fewer particles with Reduce motion")
				ok(s.particles.rate <= 20, id .. " never a blizzard")
			end
		end
		eq(#Config.order, 4, "four seasons")
	end)
end
