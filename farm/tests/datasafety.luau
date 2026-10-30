-- Data safety (Design/09 Roblox Architecture §12): a played farm survives the trip through
-- JSON (what a DataStore keeps) unchanged, every past save version loads into today's
-- layout, and SaveCheck catches the values a DataStore can't hold. Called from tests/run.luau.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Profile = require("../src/shared/Profile")
local SaveCheck = require("../src/shared/SaveCheck")
local Shop = require("../src/shared/Shop")

local function deepEqual(a: any, b: any, path: string): (boolean, string?)
	if type(a) ~= "table" or type(b) ~= "table" then
		if a == b then
			return true
		end
		return false, string.format("%s: %s vs %s", path, tostring(a), tostring(b))
	end
	for k, v in a do
		local ok, why = deepEqual(v, b[k], path .. "." .. tostring(k))
		if not ok then
			return false, why
		end
	end
	for k in b do
		if a[k] == nil then
			return false, path .. "." .. tostring(k) .. ": only after the round trip"
		end
	end
	return true
end

-- A farm a few days in, touching every save block
local function playedFarm(): { [string]: any }
	local data = Profile.migrate(nil) :: any
	Profile.welcome(data, 1761700000)
	data.meta.sessionCount = 9
	data.meta.lastSeenAt = 1762000000
	data.currencies = { Coins = 5321, Gems = 88, XP = 2400 }
	data.level = 9
	data.inventory.items = { Wheat = 20, Corn = 6, Bread = 4, Eggs = 3, Nails = 1, Planks = 2 }
	data.inventory.upgrades = 2
	data.fields.F1 = { crop = "Wheat", plantedAt = 1762000000, readyAt = 1762000120, prize = "Sunkissed" }
	data.fields.F2 = { crop = "Carrots", plantedAt = 1762000000, readyAt = 1762000600 }
	data.fields.F7 = {}
	data.factories.Bakery.built = true
	data.factories.Bakery.queue = {
		{ recipe = "Bread", seconds = 300, startedAt = 1762000000, readyAt = 1762000300 },
		{ recipe = "Cookies", seconds = 1200 },
	}
	data.factories.Bakery.output = { Bread = 2 }
	data.decor = { { id = "Bench", x = 12, z = -8, r = 1 }, { id = "OakTree", x = -20, z = 30, r = 0 } }
	data.prizes = { { crop = "Corn", tier = "Sunkissed" }, { crop = "Wheat", tier = "Heirloom" } }
	data.prizeShelf = { { crop = "Carrots", tier = "Sunkissed" } }
	Shop.record(data, "receipt-1", 1761800000)
	data.purchases.bought.StarterPack = true
	data.purchases.passes.BigBarn = true
	data.toolShed = { items = { Shovel = 2, Axe = 1 }, dry = 13 }
	data.land = { {}, { readyAt = 1762003600 } }
	data.daily = { day = 4, lastDay = 20391 }
	data.social.help = { day = 20391, used = 3, owners = { ["123456"] = 2 } }
	data.social.boostPairs = { "987654" }
	data.orders.board = {
		{ order = { wants = { Bread = 2, Eggs = 1 }, rewardCoins = 64, rewardXP = 20 } },
		{ refreshAt = 1762000900 },
	}
	-- Crop Pop's block, in the shape RunStore.exportSave writes
	data.puzzle = {
		v = 1,
		highestBeaten = 23,
		streak = 2,
		hearts = { count = 4, refillAt = 1762000500 },
		boosters = { Trowel = 2, Sprinkler = 0 },
		gifts = { day = 20391, sentTo = { 111, 222 }, claimed = 1 },
	}
	return data
end

return function(test, eq, ok)
	test("data safety: a played farm can be stored", function()
		local good, problem = SaveCheck.check(playedFarm())
		ok(good, tostring(problem))
	end)

	test("data safety: a played farm comes back from JSON unchanged", function()
		local data = playedFarm()
		local back = serde.decode("json", serde.encode("json", data))
		local same, why = deepEqual(data, back, "profile")
		ok(same, tostring(why))
		-- and loading it again changes nothing
		local reloaded = Profile.migrate(back) :: any
		same, why = deepEqual(data, reloaded, "reloaded")
		ok(same, tostring(why))
	end)

	test("data safety: the v1 greybox save loads into today's layout", function()
		local old = serde.decode("json", fs.readFile("tests/fixtures/profile-v1-greybox.json"))
		local data = Profile.migrate(old) :: any
		ok(data ~= nil, "loads")
		eq(data.version, Profile.VERSION, "version")
		-- Everything it had is kept
		eq(data.currencies.Coins, 412, "Coins kept")
		eq(data.inventory.items.Bread, 2, "Barn kept")
		eq(data.fields.F1.crop, "Wheat", "growing field kept")
		eq(#data.factories.Bakery.queue, 1, "factory queue kept")
		eq(data.orders.delivered, 4, "orders kept")
		-- Every block the template has now exists
		local function covers(target: any, template: any, path: string)
			for key, default in template do
				ok(target[key] ~= nil, path .. "." .. key .. " filled in")
				if type(default) == "table" and type(target[key]) == "table" then
					covers(target[key], default, path .. "." .. key)
				end
			end
		end
		covers(data, Profile.template(), "profile")
		local good, problem = SaveCheck.check(data)
		ok(good, tostring(problem))
	end)

	test("data safety: SaveCheck names what a DataStore can't hold", function()
		local function bad(value: any, expect: string)
			local good, problem = SaveCheck.check(value)
			ok(not good, expect .. " should fail")
			ok(problem and problem:find(expect, 1, true) ~= nil, string.format("%q in %s", expect, tostring(problem)))
		end
		bad({ currencies = { Coins = 0 / 0 } }, "currencies.Coins: number is NaN")
		bad({ x = math.huge }, "x: number is NaN or infinite")
		bad({ list = { 1, 2, nil, 4 } }, "list: array with holes")
		bad({ mixed = { 1, 2, name = "x" } }, "mixed: array with holes or mixed")
		bad({ owners = { [123456] = 2 } }, "owners: array with holes")
		bad({ owners = { [true] = 2 } }, "owners: key true is not a string")
		bad({ f = function() end }, "f: can't store a function")
		local loop = {}
		loop.self = loop
		bad(loop, "self: the table contains itself")
		local big = { s = string.rep("x", SaveCheck.maxBytes) }
		bad(big, "over the")
		-- Fine: empty tables, arrays, a table used in two places
		local shared = { 1 }
		ok((SaveCheck.check({ a = {}, b = { 1, 2, 3 }, c = shared, d = shared })), "storable shapes pass")
	end)
end
