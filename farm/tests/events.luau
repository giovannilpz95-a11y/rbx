-- Limited-time events (src/shared/Events, Config/Events): the schedule, joining and ending an
-- event, the Fair Stand's crates, the prize track and the Event Shop. Called from tests/run.luau.

local Config = require("../src/shared/Config/Events")
local Decor = require("../src/shared/Config/Decor")
local DecorRules = require("../src/shared/DecorRules")
local Events = require("../src/shared/Events")
local Items = require("../src/shared/Items")
local Profile = require("../src/shared/Profile")

local DAY = 86400
local START = 1800000000

local function farm(level: number): any
	local data = Profile.migrate(nil) :: any
	data.level = level
	data.tutorial.step = 0
	return data
end

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	local def = Config.events.HarvestFair

	test("events: the Harvest Fair's config", function()
		eq(#def.milestones, 15, "15 prizes (08)")
		eq(def.milestones[15].tokens, 1500, "1,500 tokens to finish (20 §4.4)")
		local last = 0
		for i, m in def.milestones do
			ok(m.tokens > last, "prize " .. i .. " needs more than the one before")
			last = m.tokens
			ok(Events.describe(m.reward) ~= "", "prize " .. i .. " describes itself")
		end
		for i = 12, 15 do
			local reward = def.milestones[i].reward :: any
			ok(reward.keepsake ~= nil and reward.coins == nil and reward.gems == nil, "prize " .. i .. " is looks only")
		end
		for _, m in def.milestones do
			local reward = m.reward :: any
			for item in reward.items or {} do
				ok(Items[item] ~= nil or item == "Shovel" or item == "Axe" or item == "Saw", item .. " is a real item")
			end
			if reward.keepsake then
				ok(Config.keepsakes[reward.keepsake] ~= nil, reward.keepsake .. " is a keepsake")
			end
		end
		for _, item in def.shop do
			ok(Config.keepsakes[item.id] ~= nil, item.id .. " in the shop is a keepsake")
			ok(item.price > 0 and item.stock > 0, item.id .. " price and stock")
		end
		eq(def.startsAt, 0, "not scheduled until the launch date is set")
		eq(def.tokenToCoins, 2, "1 token = 2 Coins at the end (20 §4.3)")
	end)

	test("events: keepsakes place like trophies, never sold", function()
		for id, k in Config.keepsakes do
			ok(Decor.items[id] == nil, id .. " is not in the Decorations shop")
			local placed = DecorRules.def(id)
			ok(placed ~= nil and placed.trophy == true and placed.coinCost == 0, id .. " places free from storage")
			ok(DecorRules.isTrophy(id), id .. " goes back to storage when taken up")
			eq(placed.size[1], k.size[1], id .. " size")
		end
	end)

	test("events: nothing runs unscheduled; the Studio preview runs the first event", function()
		Events.setPreview(nil)
		eq((Events.active(START)), nil, "no event when nothing is scheduled")
		Events.setPreview(START)
		local running, startsAt, endsAt = Events.active(START + 10)
		eq(running and running.id, "HarvestFair", "the preview")
		eq(startsAt, START, "from its start")
		eq(endsAt, START + def.previewSeconds, "for its length")
		eq((Events.active(START - 1)), nil, "not before")
		eq((Events.active(endsAt)), nil, "not after")
		Events.setPreview(nil)
	end)

	test("events: joining, earning, claiming and the end", function()
		Events.setPreview(START)
		local low = farm(def.minLevel - 1)
		eq((Events.sync(low, START + 5, 1)), nil, "below its level: not in it")
		eq(low.event.id, "", "still blank")
		local data = farm(10)
		eq((Events.sync(data, START + 5, 42)), "started", "joined")
		eq(data.event.id, "HarvestFair", "in it")
		eq(Events.current(data, START + 5), def, "current")
		eq((Events.sync(data, START + 6, 42)), nil, "joins once")

		eq(Events.add(data, def, 120), 2, "120 tokens reach two prizes")
		eq(data.event.tokens, 120, "to spend")
		eq(data.event.earned, 120, "earned")
		local coins = data.currencies.Coins
		local rewards = Events.claimAll(data, def)
		eq(#rewards, 2, "two to claim")
		eq(data.event.claimed, 2, "marked claimed")
		eq(#Events.claimAll(data, def), 0, "nothing more")
		for _, r in rewards do
			Events.give(data, r)
		end
		eq(data.toolShed.items.Shovel, 1, "a Shovel to the Tool Shed")
		eq(data.currencies.Coins, coins, "Coins are the service's to pay")

		-- Spending never sets the track back
		Events.add(data, def, 200)
		local index = 1
		local item = Events.canBuy(data, def, index)
		ok(item ~= nil, "can buy the first shop piece")
		Events.buy(data, def, index)
		eq(data.event.tokens, 320 - def.shop[index].price, "tokens spent")
		eq(data.event.earned, 320, "earned kept")
		eq(data.trophies[def.shop[index].id], 1, "the keepsake is in storage")
		for _ = 2, def.shop[index].stock do
			Events.buy(data, def, index)
		end
		local none, why = Events.canBuy(data, def, index)
		eq(none, nil, "sold out")
		ok(why ~= nil, why or "a reason")
		eq((Events.canBuy(data, def, 99)), nil, "no such slot")
		eq((Events.canBuy(data, def, "1")), nil, "junk index")

		-- Unclaimed prizes and leftover tokens at the end
		local leftover = data.event.tokens
		local _, ended = Events.sync(data, START + def.previewSeconds + 1, 42)
		ok(ended ~= nil, "ended")
		local e = ended :: any
		eq(e.tokens, leftover, "leftovers counted")
		eq(e.coins, leftover * def.tokenToCoins, "turned into Coins")
		eq(#e.rewards, Events.reached(def, 320) - 2, "reached but unclaimed prizes are handed over")
		eq(data.event.id, "", "the block is cleared")
		Events.setPreview(nil)
	end)

	test("events: a new run of the same event starts fresh", function()
		Events.setPreview(START)
		local data = farm(10)
		Events.sync(data, START + 5, 7)
		Events.add(data, def, 60)
		Events.setPreview(START + 400 * DAY)
		local started, ended = Events.sync(data, START + 400 * DAY + 5, 7)
		ok(ended ~= nil and (ended :: any).tokens == 60, "last year's tokens paid out")
		eq(started, "started", "this year's joined")
		eq(data.event.earned, 0, "from zero")
		Events.setPreview(nil)
	end)

	test("events: Fair Stand crates", function()
		Events.setPreview(START)
		local data = farm(10)
		Events.sync(data, START, 42)
		ok(Events.refreshCrates(data, def, START), "crates filled")
		local seen = {}
		for i = 1, def.fairStand.slots do
			local crate = Events.crate(data, def, i) :: any
			ok(crate ~= nil and crate.item ~= nil, "slot " .. i .. " has a crate")
			ok(Items[crate.item] ~= nil, crate.item .. " is an item")
			ok(crate.qty >= def.fairStand.minQty and crate.qty <= 40, crate.item .. " x" .. crate.qty)
			eq(crate.tokens, def.fairStand.tokens, "pays its tokens")
			ok(not seen[crate.item], "three different goods")
			seen[crate.item] = true
		end
		eq(Events.refreshCrates(data, def, START + 1), false, "full slots stay")
		Events.emptySlot(data, def, 2, START + 10)
		local waiting, why = Events.crate(data, def, 2)
		eq(waiting, nil, "slot 2 waits")
		ok(why ~= nil, why or "a reason")
		eq(Events.refreshCrates(data, def, START + 10 + def.fairStand.refillSeconds - 1), false, "not yet")
		ok(Events.refreshCrates(data, def, START + 10 + def.fairStand.refillSeconds), "a new crate after the wait")
		ok(Events.crate(data, def, 2) ~= nil, "slot 2 has one again")
		eq((Events.crate(data, def, 0)), nil, "no slot 0")
		eq((Events.crate(data, def, 1.5)), nil, "junk slot")
		Events.setPreview(nil)
	end)

	test("events: token pacing finishes for active players, not in a day", function()
		-- 20 §4.4: ~200 a day active (two 25-minute sessions), ~120 casual
		local perSession = function(minutes: number): number
			return (def.fairStand.slots + math.floor(minutes * 60 / def.fairStand.refillSeconds) * def.fairStand.slots)
				* def.fairStand.tokens
		end
		local active = 2 * perSession(25) + def.bonus.questChest
		local casual = perSession(12) + def.bonus.questChest
		ok(active >= 150 and active <= 260, "active ~200 a day: " .. active)
		ok(1500 / active >= 5 and 1500 / active <= 10, "finishes in 5-10 days")
		ok(Events.reached(def, casual * 10) >= 8, "casual players reach most prizes in 10 days")
		eq(Events.timeLeft(6 * DAY + 4 * 3600 + 5), "6d 4h", "days left")
		eq(Events.timeLeft(90), "1m 30s", "minutes left")
	end)
end
