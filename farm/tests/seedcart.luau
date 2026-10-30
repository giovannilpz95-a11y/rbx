-- The Seed Cart (src/shared/SeedCart, Config/SeedCart): restock windows, the stock, buying,
-- the Heirloom Seed and prepaid decorations, and the cart model. Called from tests/run.luau.

local roblox = require("@lune/roblox")

local Analytics = require("../src/shared/Analytics")
local Config = require("../src/shared/Config/SeedCart")
local Crops = require("../src/shared/Config/Crops")
local Decor = require("../src/shared/Config/Decor")
local PrizeRules = require("../src/shared/Prize")
local Profile = require("../src/shared/Profile")
local SeedCart = require("../src/shared/SeedCart")

local T = 1_800_000_000 -- a restock boundary (a multiple of 1800)

local function farm(level: number): { [string]: any }
	local data = Profile.template()
	data.level = level
	data.tutorial.step = 0
	return data
end

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("seed cart: restocks every 30 minutes on the UTC clock", function()
		eq(T % Config.restockSeconds, 0, "T is a boundary")
		eq(SeedCart.restockAt(T), T + 1800, "next at :30")
		eq(SeedCart.restockAt(T + 1799), T + 1800, "same window")
		eq(SeedCart.period(T + 1800), SeedCart.period(T) + 1, "new window")
	end)

	test("seed cart: four slots, the same for a level within a window, only unlocked goods", function()
		local heirlooms = 0
		for period = 1, 400 do
			local level = 3 + period % 10
			local stock = SeedCart.stock(period, level)
			eq(#stock, 4, "four slots")
			eq(stock[1].kind, "Crate", "slot 1")
			eq(stock[2].kind, "Crate", "slot 2")
			ok(stock[1].id ~= stock[2].id, "two different crops")
			eq(stock[3].kind, "Decor", "slot 3")
			for _, slot in stock do
				if slot.kind == "Crate" then
					ok(Crops[slot.id].unlockLevel <= level, slot.id .. " unlocked")
					eq(slot.qty, Config.crateQty, "crate size")
					ok(slot.price >= Crops[slot.id].sellPrice * slot.qty, "a crate costs more than it sells for")
				elseif slot.kind == "Decor" then
					local def = Decor.items[slot.id]
					ok(def.unlockLevel <= level, slot.id .. " unlocked")
					ok(slot.price < def.coinCost, "decoration discounted")
				else
					heirlooms += 1
					eq(slot.price, Config.heirloomPrice, "Heirloom price")
				end
			end
			eq(SeedCart.stock(period, level)[4].kind, stock[4].kind, "deterministic")
		end
		ok(heirlooms > 60 and heirlooms < 140, "Heirloom Seed about a quarter of restocks: " .. heirlooms)
	end)

	test("seed cart: shut until its update and level 3, then one of each slot per restock", function()
		local data = farm(2)
		SeedCart.forceOn(false)
		eq(Config.enabled, false, "held for roadmap week 3")
		eq((SeedCart.canBuy(farm(5), 1, T)), false, "not shipped yet")
		SeedCart.forceOn(true)
		local open, reason = SeedCart.canBuy(data, 1, T)
		eq(open, false, "level 2")
		ok(reason and reason:find("level 3") ~= nil, "says when")
		data.level = 5
		local can, _, slot = SeedCart.canBuy(data, 1, T)
		eq(can, true, "open")
		ok(slot ~= nil and slot.kind == "Crate", "slot 1 is a crate")
		SeedCart.markBought(data, 1)
		local again, why = SeedCart.canBuy(data, 1, T + 60)
		eq(again, false, "sold out")
		ok(why and why:find("Sold out") ~= nil, "says so")
		eq((SeedCart.canBuy(data, 2, T + 60)), true, "other slots still there")
		eq((SeedCart.canBuy(data, 5, T)), false, "no fifth slot")
		eq((SeedCart.canBuy(data, 1, T + 1800)), true, "restocked")
		SeedCart.forceOn(false)
	end)

	test("seed cart: an Heirloom Seed goes into the next field and boosts its Heirloom roll", function()
		local data = farm(5)
		eq(SeedCart.useHeirloomSeed(data), 1, "none")
		data.heirloomSeeds = 1
		data.tutorial.step = 2
		eq(SeedCart.useHeirloomSeed(data), 1, "kept during the guide")
		data.tutorial.step = 0
		eq(SeedCart.useHeirloomSeed(data), Config.heirloomBoost, "used")
		eq(data.heirloomSeeds, 0, "spent")
		ok(PrizeRules.roll(data, 0.015) ~= "Heirloom", "plain roll misses")
		eq(PrizeRules.roll(data, 0.015, { Heirloom = Config.heirloomBoost }), "Heirloom", "boosted roll hits")
	end)

	test("seed cart: a prepaid decoration is placed once for free", function()
		local data = farm(5)
		eq(SeedCart.useCoupon(data, "Bench"), false, "none")
		data.decorCoupons.Bench = 2
		eq(SeedCart.useCoupon(data, "Bench"), true, "first")
		eq(SeedCart.useCoupon(data, "Bench"), true, "second")
		eq(data.decorCoupons.Bench, nil, "cleared")
		eq(SeedCart.useCoupon(data, "Bench"), false, "all used")
	end)

	test("seed cart: purchases have their own analytics SKU", function()
		eq((Analytics.sku("cart_Corn", "Coins")), "SeedCart", "SKU")
	end)

	test("art: the Seed Cart stays within its budget", function()
		Instance = roblox.Instance
		local ArtSeedCart = require("../src/shared/Art/SeedCart")
		local Kit = require("../src/shared/Art/Kit")
		local m = Instance.new("Model")
		local cart = ArtSeedCart.build(m, roblox.CFrame.new())
		local n = Kit.countParts(m)
		ok(n <= ArtSeedCart.PARTS_MAX, string.format("Seed Cart %d parts, budget %d", n, ArtSeedCart.PARTS_MAX))
		ok(cart.body:IsDescendantOf(m) and cart.sign:IsDescendantOf(m), "body and sign")
	end)
end
