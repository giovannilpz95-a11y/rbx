--!strict
-- Unit tests for the pure shared modules, plus a compile check of every Luau file.
-- Run from the farm/ folder:  lune run tests/run.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Balance = require("../src/shared/Config/Balance")
local Crops = require("../src/shared/Config/Crops")
local Factories = require("../src/shared/Config/Factories")
local Items = require("../src/shared/Items")
local Levels = require("../src/shared/Config/Levels")
local OrderConfig = require("../src/shared/Config/Orders")
local OrderGen = require("../src/shared/OrderGen")
local Profile = require("../src/shared/Profile")
local Progression = require("../src/shared/Progression")
local Recipes = require("../src/shared/Config/Recipes")
local Rng = require("../src/shared/Rng")
local Timer = require("../src/shared/Timer")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

local function eq(actual: any, expected: any, what: string?)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function ok(condition: any, what: string)
	if not condition then
		error(what, 2)
	end
end

---------------------------------------------------------------------------------------------
-- Config integrity (09 Roblox Architecture §9)
---------------------------------------------------------------------------------------------

test("every crop has positive timers and matching ids", function()
	for id, crop in Crops do
		eq(crop.id, id, "crop id")
		ok(crop.growSeconds > 0 and crop.yield > 0, id .. " needs time and yield")
		ok(crop.unlockLevel >= 1 and crop.unlockLevel <= 30, id .. " unlock level in 1-30")
	end
end)

test("Township baseline crop rows for the greybox", function()
	eq(Crops.Wheat.growSeconds, 120, "Wheat time")
	eq(Crops.Wheat.seedCost, 0, "Wheat seed")
	eq(Crops.Corn.unlockLevel, 3, "Corn level")
	eq(Crops.Corn.growSeconds, 300, "Corn time")
	eq(Crops.Corn.sellPrice, 3, "Corn price")
end)

test("every recipe input and factory exists", function()
	for id, recipe in Recipes do
		eq(recipe.id, id, "recipe id")
		ok(Factories[recipe.factory] ~= nil, id .. " factory " .. recipe.factory)
		for input in recipe.inputs do
			ok(Items[input] ~= nil, id .. " input " .. input)
		end
	end
end)

test("enabled crops and factories exist", function()
	for _, id in Balance.enabledCrops do
		ok(Crops[id] ~= nil, "crop " .. id)
	end
	for _, id in Balance.enabledFactories do
		ok(Factories[id] ~= nil, "factory " .. id)
	end
end)

test("no item id is both a crop and a recipe", function()
	for id in Recipes do
		ok(Crops[id] == nil, id .. " is both")
	end
end)

test("levels run 1..cap in order", function()
	eq(#Levels.list, Levels.cap, "level rows")
	for i, def in Levels.list do
		eq(def.level, i, "level order")
		ok(def.xpToNext > 0, "xp > 0")
	end
end)

---------------------------------------------------------------------------------------------
-- Progression
---------------------------------------------------------------------------------------------

test("level thresholds follow the Township curve", function()
	eq(Progression.levelFor(0), 1, "start")
	eq(Progression.levelFor(8), 1, "just under L2")
	eq(Progression.levelFor(9), 2, "L2 at 9 XP")
	eq(Progression.levelFor(26), 3, "L3 at 26 XP")
	eq(Progression.levelFor(4675), 11, "just under L12")
	eq(Progression.levelFor(4676), 12, "L12 at 4,676 XP")
	eq(Progression.levelFor(999999), 12, "capped")
	local info = Progression.info(30)
	eq(info.level, 3, "level at 30 XP")
	eq(info.xpIntoLevel, 4, "xp into level")
	eq(info.xpToNext, 44, "xp to next")
	ok(Progression.info(5000).atCap, "at cap")
end)

test("level rewards", function()
	local coins, gems = Progression.reward(2)
	eq(coins, 100, "L2 coins")
	eq(gems, 1, "L2 gems")
end)

---------------------------------------------------------------------------------------------
-- Timer
---------------------------------------------------------------------------------------------

test("format", function()
	eq(Timer.format(5), "5s")
	eq(Timer.format(125), "2m 05s")
	eq(Timer.format(3720), "1h 02m")
end)

test("queue chains jobs back to back while offline", function()
	local queue = {
		{ recipe = "Bread", seconds = 300 },
		{ recipe = "Bread", seconds = 300 },
		{ recipe = "Bread", seconds = 300 },
	}
	local output = {}
	Timer.advanceQueue(queue, output, 1000, 8)
	eq(queue[1].readyAt, 1300, "first job starts now")
	Timer.advanceQueue(queue, output, 1000 + 650, 8)
	eq(output.Bread, 2, "two finished")
	eq(#queue, 1, "one left")
	eq(queue[1].startedAt, 1600, "next starts when the previous finished, not now")
	eq(queue[1].readyAt, 1900, "and runs its full time")
end)

test("a full tray pauses the queue until goods are collected", function()
	local queue = { { recipe = "Bread", seconds = 10 }, { recipe = "Bread", seconds = 10 } }
	local output = { Bread = 7 }
	Timer.advanceQueue(queue, output, 0, 8)
	Timer.advanceQueue(queue, output, 100, 8)
	eq(output.Bread, 8, "tray filled")
	eq(#queue, 1, "one waiting")
	eq(queue[1].startedAt, nil, "paused, not started")
	output.Bread = 0 -- collected
	Timer.advanceQueue(queue, output, 200, 8)
	eq(queue[1].startedAt, 200, "restarts at collect time")
end)

---------------------------------------------------------------------------------------------
-- Rng and OrderGen
---------------------------------------------------------------------------------------------

test("rng is deterministic and in range", function()
	local a1, s1 = Rng.next(12345)
	local a2, s2 = Rng.next(12345)
	eq(a1, a2, "same value")
	eq(s1, s2, "same seed")
	local seed = 7
	for _ = 1, 1000 do
		local n
		n, seed = Rng.int(seed, 2, 5)
		ok(n >= 2 and n <= 5 and n % 1 == 0, "int in range")
	end
end)

test("order slots by level", function()
	eq(OrderGen.slotsFor(1), 3)
	eq(OrderGen.slotsFor(3), 4)
	eq(OrderGen.slotsFor(12), 7)
	eq(OrderGen.slotsFor(30), OrderConfig.maxSlots)
end)

test("reward formula", function()
	-- 4 Wheat: value 4, XP 4 * 0.5 = 2; Coins = round(4 * 1.31 * 1.00) = 5, XP = round(2 * 1.5) = 3
	local coins, xp = OrderGen.rewards({ Wheat = 4 }, 1)
	eq(coins, 5, "coins")
	eq(xp, 3, "xp")
end)

test("generated orders are valid, unlocked and reproducible", function()
	local pool = { "Wheat", "Corn", "Bread" }
	for level = 1, 12 do
		local seed = level * 101
		local existing = {}
		for _ = 1, 7 do
			local order, nextSeed =
				OrderGen.generate({ level = level, seed = seed, pool = pool, existing = existing, now = 0 })
			local again = OrderGen.generate({ level = level, seed = seed, pool = pool, existing = existing, now = 0 })
			assert(order and again, "an order")
			eq(order.id, again.id, "reproducible")
			local lines = 0
			for item, qty in order.wants do
				lines += 1
				ok(Items[item].unlockLevel <= level, item .. " unlocked at level " .. level)
				ok(qty >= 1 and qty % 1 == 0, "whole quantity")
			end
			ok(lines >= 1 and lines <= 4, "line count")
			ok(order.rewardCoins >= 1 and order.rewardXP >= 1, "pays something")
			table.insert(existing, order)
			seed = nextSeed
		end
	end
end)

test("the first card on an empty board is crops-only", function()
	for seed = 1, 50 do
		local order =
			OrderGen.generate({ level = 5, seed = seed, pool = { "Wheat", "Corn", "Bread" }, existing = {}, now = 0 })
		ok(order and OrderGen.isCropsOnly(order), "crops-only guarantee")
	end
end)

---------------------------------------------------------------------------------------------
-- Profile
---------------------------------------------------------------------------------------------

test("new profile uses the Township starting wallet", function()
	local data = Profile.migrate(nil) :: any
	eq(data.version, Profile.VERSION, "version")
	eq(data.currencies.Coins, 500, "coins")
	eq(data.currencies.Gems, 30, "gems")
	eq(data.inventory.barnCapacity, 50, "barn")
	local fields = 0
	for _ in data.fields do
		fields += 1
	end
	eq(fields, 6, "six fields")
	eq(data.factories.Bakery.slots, 3, "bakery slots")
end)

test("reconcile fills missing keys and keeps extra ones", function()
	local old = { version = 1, currencies = { Coins = 7 }, futureThing = { keep = true } }
	local data = Profile.migrate(old) :: any
	eq(data.currencies.Coins, 7, "kept coins")
	eq(data.currencies.Gems, 30, "filled gems")
	ok(data.futureThing.keep, "kept unknown key")
	ok(data.fields.F1 ~= nil, "filled fields")
end)

test("a profile from a newer build is refused", function()
	local data, reason = Profile.migrate({ version = Profile.VERSION + 1 })
	eq(data, nil, "no data")
	eq(reason, "newer", "reason")
end)

---------------------------------------------------------------------------------------------
-- Every Luau file compiles
---------------------------------------------------------------------------------------------

local function eachLuau(dir: string, fn: (string) -> ())
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			eachLuau(path, fn)
		elseif name:match("%.luau$") then
			fn(path)
		end
	end
end

eachLuau("src", function(path)
	test("compiles: " .. path, function()
		luau.compile(fs.readFile(path))
	end)
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
