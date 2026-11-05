-- The County Fair (src/shared/Fair, Config/Fair): the weekend window, entries, the judges'
-- marks, ribbons, and paying out once after judging. Called from tests/run.luau.

local Config = require("../src/shared/Config/Fair")
local DecorRules = require("../src/shared/DecorRules")
local Fair = require("../src/shared/Fair")
local Profile = require("../src/shared/Profile")

local HOUR = 3600
local DAY = 86400
local FRI = 1793491200 + 5 * DAY -- 2026-11-06, a Friday, 00:00 UTC
local OPENS = FRI + 16 * HOUR

local function farm(level: number): any
	local data = Profile.migrate(nil) :: any
	data.level = level
	data.tutorial.step = 0
	return data
end

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("fair: the weekend window", function()
		Fair.setPreview(nil)
		local opens, closes, nextOpens = Fair.window(OPENS + 5)
		eq(opens, OPENS, "Friday 16:00 UTC")
		eq(closes, OPENS + 56 * HOUR, "to Monday 00:00 UTC")
		eq(nextOpens, OPENS + 7 * DAY, "every week")
		eq((Fair.window(OPENS - 1)), OPENS - 7 * DAY, "just before: last week's fair")
		ok(Fair.isOpen(OPENS + 50 * HOUR), "open on Sunday night")
		ok(not Fair.isOpen(OPENS + 56 * HOUR), "closed on Monday")
		ok(not Fair.isOpen(OPENS - 1), "closed on Friday morning")
		eq((Fair.window(OPENS + 6 * DAY)), OPENS, "Thursday belongs to the last fair (its results)")
	end)

	test("fair: marks and ribbons", function()
		local seen = {}
		for week = 0, 40 do
			for uid = 1, 20 do
				local w = OPENS + week * 7 * DAY
				local heir = Fair.produceMarks("Wheat", "Heirloom", w, uid)
				local sun = Fair.produceMarks("Wheat", "Sunkissed", w, uid)
				ok(heir >= 75, "an Heirloom always earns a Blue")
				ok(sun >= 50 and sun < 75, "a Sunkissed Wheat: Yellow or Red")
				seen[Fair.ribbon(sun).id] = true
				local plain = Fair.bakeMarks("Bread", nil, w, uid)
				local fancy = Fair.bakeMarks("Bagel", "Heirloom", w, uid)
				ok(plain < 62, "plain Bread: Green or Yellow")
				ok(fancy > plain, "a fancier bake with a prize on top scores more")
				ok(fancy <= 100, "out of 100")
			end
		end
		ok(seen.Yellow and seen.Red, "the judges' luck moves some entries up a ribbon")
		eq(Fair.ribbon(0).id, "Green", "everyone who enters gets a ribbon")
		eq(Fair.ribbon(75).id, "Blue", "75 is a Blue")
		eq(
			Fair.produceMarks("Wheat", "Heirloom", OPENS, 9),
			Fair.produceMarks("Wheat", "Heirloom", OPENS, 9),
			"same entry, same marks"
		)
	end)

	test("fair: entering", function()
		local data = farm(10)
		data.prizes = { { crop = "Corn", tier = "Starlit" }, { crop = "Wheat", tier = "Sunkissed" } }
		data.inventory.items.Bread = 2
		local now = OPENS + HOUR
		local okEnter, why = Fair.canEnter(farm(Config.minLevel - 1), now, "Produce", 1)
		eq(okEnter, false, "below its level")
		ok(why ~= nil, why or "a reason")
		eq(Fair.canEnter(data, now, "Nope", 1), false, "no such class")
		eq(Fair.canEnter(data, now, "Produce", 5), false, "no such prize")
		eq(Fair.canEnter(data, now, "Produce", "1"), false, "junk index")
		ok(Fair.canEnter(data, now, "Produce", 1), "a Prize Crop")
		Fair.enter(data, now, 42, "Produce", 1)
		eq(#data.prizes, 1, "the Prize Crop is taken")
		eq(data.fair.entries.Produce.item, "Corn", "entered")
		eq((Fair.canEnter(data, now, "Produce", 1)), false, "once a class")
		eq((Fair.canEnter(data, now, "Bake", "Wheat")), false, "not a bake")
		eq((Fair.canEnter(data, now, "Bake", "Cookies")), false, "not in the Barn")
		ok(Fair.canEnter(data, now, "Bake", "Bread", 1), "Bread topped with a Prize Crop")
		Fair.enter(data, now, 42, "Bake", "Bread", 1)
		eq(data.inventory.items.Bread, 1, "one Bread taken")
		eq(#data.prizes, 0, "the garnish is taken")
		eq(data.fair.entries.Bake.garnish, "Sunkissed", "with its garnish")
		eq((Fair.canEnter(data, OPENS + 57 * HOUR, "Bake", "Bread")), false, "closed after the weekend")
	end)

	test("fair: judging pays once, then a fresh week", function()
		local data = farm(10)
		data.prizes = { { crop = "Corn", tier = "Heirloom" } }
		local now = OPENS + HOUR
		Fair.sync(data, now)
		Fair.enter(data, now, 7, "Produce", 1)
		eq(#Fair.sync(data, now + HOUR), 0, "nothing before judging")
		local results = Fair.sync(data, OPENS + 56 * HOUR)
		eq(#results, 1, "judged on Monday")
		eq(results[1].ribbon, "Blue", "an Heirloom wins a Blue")
		eq(results[1].cup, Config.classes.Produce.cup, "and a cup")
		eq(data.trophies[Config.classes.Produce.cup], 1, "the cup is in storage")
		ok(DecorRules.isTrophy(Config.classes.Produce.cup), "it places free like a trophy")
		eq(data.fair.ribbons.Blue, 1, "counted")
		eq(#Fair.sync(data, OPENS + 60 * HOUR), 0, "paid once")
		ok(data.fair.entries.Produce ~= nil, "the entry stays for its results")
		Fair.sync(data, OPENS + 7 * DAY + HOUR)
		eq(data.fair.week, OPENS + 7 * DAY, "next week")
		eq(next(data.fair.entries), nil, "no entries yet")
		eq(data.fair.ribbons.Blue, 1, "ribbons kept")
	end)

	test("fair: results wait for a farm that was away all week", function()
		local data = farm(10)
		data.prizes = { { crop = "Wheat", tier = "Sunkissed" } }
		Fair.sync(data, OPENS + HOUR)
		Fair.enter(data, OPENS + HOUR, 3, "Produce", 1)
		local results = Fair.sync(data, OPENS + 9 * DAY)
		eq(#results, 1, "paid on the next visit")
		eq(data.fair.week, OPENS + 7 * DAY, "and this week's fair started fresh")
	end)

	test("fair: the Studio preview", function()
		Fair.setPreview(OPENS + 2 * DAY)
		local opens, closes = Fair.window(OPENS + 2 * DAY + 10)
		eq(opens, OPENS + 2 * DAY, "from the preview start")
		eq(closes, opens + Config.openSeconds, "open for the weekend's length")
		Fair.setPreview(nil)
	end)
end
