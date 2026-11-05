-- The Wandering Peddler (src/shared/Peddler, Config/Sky peddler): each player's own three
-- offers, buying once a visit, prepaid decorations and seeds. Called from tests/run.luau.

local Config = require("../src/shared/Config/Sky")
local Decor = require("../src/shared/Config/Decor")
local Peddler = require("../src/shared/Peddler")
local Profile = require("../src/shared/Profile")

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("peddler: three offers, an early decoration, a deal and seeds", function()
		local slots = Peddler.stock(1000, 42, 10)
		eq(#slots, 3, "three offers")
		local early, deal, seeds = slots[1], slots[2], slots[3]
		ok(early.early == true, "the first is early")
		local def = Decor.items[early.id :: string]
		ok(def.unlockLevel > 10 and def.unlockLevel <= 10 + Config.peddler.earlyLevels, "1-4 levels ahead")
		eq(early.price, math.ceil(def.coinCost * Config.peddler.earlyMult), "at a premium")
		local dealDef = Decor.items[deal.id :: string]
		ok(dealDef.unlockLevel <= 10, "the deal is at your level")
		eq(deal.price, math.max(1, math.floor(dealDef.coinCost * 0.7)), "30% off")
		eq(seeds.kind, "Seeds", "then the seeds")
		eq(seeds.price, Config.peddler.seeds * Config.peddler.seedPrice, "seed price")
	end)

	test("peddler: the stock is each player's own and fixed for a visit", function()
		local a, b = Peddler.stock(1000, 42, 10), Peddler.stock(1000, 42, 10)
		eq(a[1].id, b[1].id, "the same player sees the same stock")
		local differs = false
		for user = 1, 30 do
			local other = Peddler.stock(1000, user, 10)
			if other[1].id ~= a[1].id or other[2].id ~= a[2].id then
				differs = true
			end
		end
		ok(differs, "other players get other offers")
		for level = 1, 140 do
			for _, slot in Peddler.stock(77, 5, level) do
				ok(slot.price > 0, "a price at level " .. level)
				ok(slot.kind == "Seeds" or Decor.items[slot.id :: string] ~= nil, "a real item")
				ok(slot.kind == "Seeds" or not (Decor.items[slot.id :: string] :: any).trophy, "never a trophy")
			end
		end
	end)

	test("peddler: buying once a visit, coupons and seeds", function()
		local data = Profile.migrate(nil) :: any
		data.level = 10
		eq(data.peddler.visit, 0, "saved block")
		local okBuy, _, slot = Peddler.canBuy(data, 1000, 42, 1)
		ok(okBuy and slot ~= nil, "can buy")
		Peddler.give(data, slot :: any)
		Peddler.markBought(data, 1)
		eq(data.decorCoupons[(slot :: any).id], 1, "a prepaid decoration")
		local again, why = Peddler.canBuy(data, 1000, 42, 1)
		eq(again, false, "once a visit")
		ok(why ~= nil, why or "a reason")
		local _, _, seeds = Peddler.canBuy(data, 1000, 42, 3)
		Peddler.give(data, seeds :: any)
		eq(data.heirloomSeeds, Config.peddler.seeds, "Heirloom Seeds")
		ok((Peddler.canBuy(data, 2000, 42, 1)), "a new visit, new purchases")
		eq(Peddler.canBuy(data, 2000, 42, 9), false, "no such slot")
		eq(Peddler.canBuy(data, 2000, 42, "1"), false, "junk index")
	end)
end
