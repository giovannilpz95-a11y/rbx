-- Analytics helpers (src/shared/Analytics, Launch/19 Analytics & Metrics §4): custom-field
-- values stay in their small fixed sets, every EconomyService reason maps to a known SKU,
-- and the economy buffer sums per key. Called from tests/run.luau.

local Analytics = require("../src/shared/Analytics")
local Crops = require("../src/shared/Config/Crops")
local Products = require("../src/shared/Config/Products")
local Profile = require("../src/shared/Profile")

return function(test, eq, ok)
	test("analytics: level bands cover 1-30 in six bands", function()
		local seen = {}
		for level = 1, 30 do
			seen[Analytics.levelBand(level)] = true
		end
		local count = 0
		for _ in seen do
			count += 1
		end
		eq(count, 6, "bands")
		eq(Analytics.levelBand(4), "L01-04", "4")
		eq(Analytics.levelBand(5), "L05-09", "5")
		eq(Analytics.levelBand(12), "L10-14", "12")
		eq(Analytics.levelBand(99), "L25-30", "past the cap")
	end)

	test("analytics: cohort tag is tenure plus payer flag", function()
		local data = Profile.template()
		local day = 86400
		data.meta.createdAt = 1000
		eq(Analytics.cohort(data, 1000 + day), "new_nonpayer", "day 1")
		eq(Analytics.cohort(data, 1000 + 3 * day), "early_nonpayer", "day 3")
		eq(Analytics.cohort(data, 1000 + 10 * day), "core_nonpayer", "day 10")
		eq(Analytics.cohort(data, 1000 + 40 * day), "veteran_nonpayer", "day 40")
		data.purchases.receipts.r1 = 1
		eq(Analytics.cohort(data, 1000 + 3 * day), "early_payer", "bought once")
		data.purchases.receipts.r1 = nil
		data.purchases.passes.BigBarn = true
		eq(Analytics.cohort(data, 1000), "new_payer", "owns a pass")
		data.meta.createdAt = 0
		eq(Analytics.cohort(data, 5 * day), "new_payer", "unset createdAt counts as new")
	end)

	test("analytics: gap buckets", function()
		eq(Analytics.gapBucket(0), "<1h", "0")
		eq(Analytics.gapBucket(3600), "1-4h", "1h")
		eq(Analytics.gapBucket(5 * 3600), "4-12h", "5h")
		eq(Analytics.gapBucket(13 * 3600), "12-24h", "13h")
		eq(Analytics.gapBucket(2 * 86400), "1-3d", "2d")
		eq(Analytics.gapBucket(9 * 86400), "3d+", "9d")
	end)

	test("analytics: every economy reason maps to a known SKU", function()
		local crop = next(Crops) :: string
		local cases = {
			{ "seed_" .. crop, "Coins", "Seeds", "Gameplay" },
			{ "harvest_" .. crop, "XP", "Harvest", "Gameplay" },
			{ "order", "Coins", "OrderBoard", "Gameplay" },
			{ "speedup_order", "Gems", "SkipCooldown", "ContextualPurchase" },
			{ "speedup_" .. crop, "Gems", "SkipCrop", "ContextualPurchase" },
			{ "speedup_all_" .. crop, "Gems", "SkipCrop", "ContextualPurchase" },
			{ "speedup_Bakery", "Gems", "SkipFactory", "ContextualPurchase" },
			{ "speedup_CowBarn", "Gems", "SkipAnimal", "ContextualPurchase" },
			{ "speedup_town", "Gems", "SkipBuild", "ContextualPurchase" },
			{ "slot_Bakery", "Gems", "GemSlot", "ContextualPurchase" },
			{ "material_Bricks", "Gems", "BuyMissingItem", "ContextualPurchase" },
			{ "build_Bakery", "Coins", "BuildFactory", "Gameplay" },
			{ "build_ChickenCoop", "Coins", "BuildPen", "Gameplay" },
			{ "build_VillageWell", "Coins", "BuildCommunity", "Gameplay" },
			{ "build_Cottage", "Coins", "BuildHouse", "Gameplay" },
			{ "decor_Bench", "Coins", "BuildDecor", "Gameplay" },
			{ "decor_sell", "Coins", "DecorRefund", "Gameplay" },
			{ "expand_3", "Coins", "Expansion", "Gameplay" },
			{ "field_7", "XP", "FieldUnlock", "Gameplay" },
			{ "animal_ChickenCoop", "Coins", "BuyAnimal", "Gameplay" },
			{ "collect_Eggs", "XP", "Collect", "Gameplay" },
			{ "sell_Wheat", "Coins", "DirectSell", "Gameplay" },
			{ "prize_Heirloom", "Coins", "PrizeSale", "Gameplay" },
			{ "levelup", "Coins", "LevelUp", "Gameplay" },
			{ "levelup", "Gems", "LevelUpGems", "Gameplay" },
			{ "daily", "Gems", "DailyLogin", "TimedReward" },
			{ "tutorial", "Gems", "Tutorial", "Onboarding" },
			{ "croppop_12", "Coins", "CropPop", "Gameplay" },
			{ "CropPop:Continue1", "Gems", "CropPop", "ContextualPurchase" },
			{ "drop_harvest", "Tools", "HarvestDrop", "Gameplay" },
			{ "robux_Pouch", "Gems", "GemPack_Pouch", "IAP" },
			{ "robux_StarterPack", "Gems", "StarterPack", "IAP" },
			{ "robux_revert", "Gems", "IapRevert", "IAP" },
		}
		for _, case in cases do
			local sku, tx = Analytics.sku(case[1], case[2])
			eq(sku, case[3], case[1] .. " sku")
			eq(tx, case[4], case[1] .. " transaction type")
		end
		eq((Analytics.sku("something_new", "Coins")), "Other", "unknown reasons fall into Other")
	end)

	test("analytics: SKUs stay well under the 100 limit", function()
		-- Product SKUs are the only open-ended ones; everything else is a fixed list
		local count = 0
		for _ in Products.products do
			count += 1
		end
		ok(count + 40 < 100, "room for products")
		ok(Analytics.isSkip("SkipCrop") and not Analytics.isSkip("Seeds"), "skip SKUs")
	end)

	test("analytics: economy buffer sums per key and drains empty", function()
		local buffer = Analytics.newBuffer()
		Analytics.add(buffer, "Coins", "Source", "OrderBoard", "Gameplay", 10)
		Analytics.add(buffer, "Coins", "Sink", "Seeds", "Gameplay", 2)
		Analytics.add(buffer, "Coins", "Source", "OrderBoard", "Gameplay", 15)
		Analytics.add(buffer, "Tools", "Source", "HarvestDrop", "Gameplay", 1, "Shovels")
		Analytics.add(buffer, "Tools", "Source", "HarvestDrop", "Gameplay", 1, "Axes")
		local out = Analytics.drain(buffer)
		eq(#out, 4, "one entry per key")
		eq(out[1].sku, "OrderBoard", "oldest first")
		eq(out[1].amount, 25, "summed")
		eq(out[3].context, "Shovels", "context kept apart")
		eq(#Analytics.drain(buffer), 0, "drained")
	end)
end
