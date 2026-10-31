local FarmCues = load("FarmCues")

local function state(over)
	local s = {
		currencies = { Coins = 500, Gems = 30, XP = 0 },
		inventory = { Wheat = 4 },
		fields = { F1 = {}, F2 = {}, F3 = { crop = "Wheat", plantedAt = 0, readyAt = 120 } },
		factories = {
			Bakery = { built = true, queue = {}, output = {}, outputCount = 0 },
		},
		serverNow = 100,
	}
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

local function names(cues)
	local out = {}
	for _, c in cues do
		table.insert(out, c.sound)
	end
	return table.concat(out, ",")
end

test("the first snapshot is quiet", function()
	expect.eq(names(FarmCues.diff(nil, state())), "")
end)

test("no change, no sound", function()
	expect.eq(names(FarmCues.diff(state(), state())), "")
end)

test("planting two beds plays two rising plant sounds", function()
	local after = state({ fields = { F1 = { crop = "Wheat" }, F2 = { crop = "Wheat" }, F3 = { crop = "Wheat" } } })
	local cues = FarmCues.diff(state(), after)
	expect.eq(names(cues), "Plant,Plant")
	expect.eq(cues[1].pitch, 0)
	expect.eq(cues[2].pitch, 1)
	expect.truthy(cues[2].delay > 0)
end)

test("harvesting plays a harvest chain, capped at 6", function()
	local before = { fields = {}, inventory = {}, currencies = { Coins = 0 } }
	local after = { fields = {}, inventory = { Wheat = 10 }, currencies = { Coins = 0 } }
	for i = 1, 10 do
		before.fields["F" .. i] = { crop = "Wheat" }
		after.fields["F" .. i] = {}
	end
	local cues = FarmCues.diff(before, after)
	expect.eq(#cues, 6)
	expect.eq(cues[6].pitch, 10)
end)

test("selling from the Barn: items down and Coins up", function()
	local after = state({ inventory = { Wheat = 2 }, currencies = { Coins = 506, Gems = 30, XP = 0 } })
	expect.eq(names(FarmCues.diff(state(), after)), "Sell")
end)

test("Coins and Gems from nowhere else", function()
	local after = state({ currencies = { Coins = 600, Gems = 31, XP = 0 } })
	expect.eq(names(FarmCues.diff(state(), after)), "Coin,Gem")
end)

test("a reward popup keeps its Coins quiet", function()
	local after = state({ inventory = { Wheat = 0 }, currencies = { Coins = 600, Gems = 31, XP = 10 } })
	expect.eq(names(FarmCues.diff(state(), after, { rewardShown = true })), "")
end)

test("factory: build, queue and collect", function()
	local before = state({ factories = { Bakery = { built = false, queue = {}, output = {}, outputCount = 0 } } })
	local built = state({ factories = { Bakery = { built = true, constructionReadyAt = 200, queue = {}, output = {}, outputCount = 0 } } })
	expect.eq(names(FarmCues.diff(before, built)), "BuildStart")

	local queued = state({
		inventory = { Wheat = 1 },
		factories = { Bakery = { built = true, queue = { { recipe = "Bread", seconds = 300 } }, output = {}, outputCount = 0 } },
	})
	expect.eq(names(FarmCues.diff(state(), queued)), "FactoryStart", "spending ingredients isn't a sale")

	local full = state({ factories = { Bakery = { built = true, queue = {}, output = { Bread = 2 }, outputCount = 2 } } })
	local collected = state({ inventory = { Wheat = 4, Bread = 2 } })
	expect.eq(names(FarmCues.diff(full, collected)), "FactoryCollect")
end)

test("timers: a finished job and a finished building", function()
	local s = state({
		factories = {
			Bakery = {
				built = true,
				constructionReadyAt = 150,
				queue = { { recipe = "Bread", seconds = 300, startedAt = 0, readyAt = 300 }, { recipe = "Bread", seconds = 300 } },
				output = {},
				outputCount = 0,
			},
		},
	})
	expect.eq(names(FarmCues.timed(s, 100, 149)), "")
	expect.eq(names(FarmCues.timed(s, 149, 151)), "BuildDone")
	expect.eq(names(FarmCues.timed(s, 299, 301)), "Ready")
	expect.eq(names(FarmCues.timed(s, 599, 601)), "Ready", "the second job follows the first")
	expect.eq(names(FarmCues.timed(s, 601, 900)), "")
	expect.eq(names(FarmCues.timed(nil, 0, 1)), "")
end)

test("ripe crops stay quiet", function()
	expect.eq(names(FarmCues.timed(state(), 100, 200)), "")
end)

test("popups: level up and orders", function()
	expect.eq(names(FarmCues.popup({ kind = "LevelUp", level = 3 })), "LevelUp")
	expect.eq(names(FarmCues.popup({ kind = "Order", coins = 40 })), "OrderComplete,Coin")
	expect.eq(names(FarmCues.popup({ kind = "Other" })), "")
	expect.eq(names(FarmCues.popup(nil)), "")
end)

test("pens: build, new animal, feed and collect", function()
	local function pens(built, animals)
		return state({ pens = { CowBarn = { built = built, animals = animals, feedLeft = 0 } } })
	end
	expect.eq(names(FarmCues.diff(pens(false, {}), pens(true, {}))), "BuildStart")
	expect.eq(names(FarmCues.diff(pens(true, { {} }), pens(true, { {}, {} }))), "Unlock")
	expect.eq(names(FarmCues.diff(pens(true, { {}, {} }), pens(true, { { readyAt = 500 }, { readyAt = 500 } }))), "Feed")
	expect.eq(names(FarmCues.diff(pens(true, { { readyAt = 50 }, { readyAt = 50 } }), pens(true, { {}, {} }))), "FactoryCollect,FactoryCollect")
end)

test("town: a new house or community building starts a build; finishing chimes", function()
	local before = state({ town = { houses = { { type = "Cottage", lot = 1 } }, community = {} } })
	local house = state({ town = { houses = { { type = "Cottage", lot = 1 }, { type = "Cottage", lot = 2, readyAt = 400 } }, community = {} } })
	expect.eq(names(FarmCues.diff(before, house)), "BuildStart")
	local hall = state({ town = { houses = { { type = "Cottage", lot = 1 } }, community = { Hall = { readyAt = 700 } } } })
	expect.eq(names(FarmCues.diff(before, hall)), "BuildStart")
	expect.eq(names(FarmCues.timed(house, 399, 401)), "BuildDone")
	expect.eq(names(FarmCues.timed(hall, 699, 701)), "BuildDone")
	local pen = state({ pens = { CowBarn = { built = true, constructionReadyAt = 250, animals = {} } } })
	expect.eq(names(FarmCues.timed(pen, 249, 251)), "BuildDone")
end)

test("a tool drop, a new field and a Barn upgrade sparkle", function()
	expect.eq(names(FarmCues.popup({ kind = "Drop", item = "Shovel" })), "Unlock")
	expect.eq(names(FarmCues.popup({ kind = "Field", field = "F7", xp = 5 })), "Unlock")
	expect.eq(names(FarmCues.popup({ kind = "BarnUpgrade", capacity = 75 })), "Unlock")
end)

test("the tutorial chimes on each new step, not when it ends", function()
	expect.eq(names(FarmCues.diff(state({ tutorial = { step = 0 } }), state({ tutorial = { step = 1 } }))), "Notify")
	expect.eq(names(FarmCues.diff(state({ tutorial = { step = 1 } }), state({ tutorial = { step = 1 } }))), "")
	expect.eq(names(FarmCues.diff(state({ tutorial = { step = 4 } }), state({ tutorial = { step = 0 } }))), "")
end)

test("land that finishes clearing opens with a sparkle", function()
	local s = state({ land = { {}, { readyAt = 500 } } })
	expect.eq(names(FarmCues.timed(s, 499, 501)), "Unlock")
	expect.eq(names(FarmCues.timed(s, 501, 600)), "")
end)

test("missing blocks in a snapshot don't break it (newer farm builds add more)", function()
	expect.eq(names(FarmCues.diff({}, {})), "")
	expect.eq(names(FarmCues.diff({ fields = {} }, { factories = { Dairy = { built = true } } })), "")
end)

test("decorations: placing, turning, moving and selling", function()
	local bench = { id = "Bench", x = 10, z = 4, r = 0 }
	local before = state({ decor = { bench } })
	-- Placing costs Coins, so only the place sound plays.
	local placed = state({
		decor = { bench, { id = "Lamp", x = 2, z = 2, r = 0 } },
		currencies = { Coins = 450, Gems = 30, XP = 2 },
	})
	expect.eq(names(FarmCues.diff(before, placed)), "DecorPlace")
	-- Turning re-snaps the spot, which is still a turn.
	local turned = state({ decor = { { id = "Bench", x = 11, z = 3, r = 1 } } })
	expect.eq(names(FarmCues.diff(before, turned)), "DecorRotate")
	local moved = state({ decor = { { id = "Bench", x = 20, z = 4, r = 0 } } })
	expect.eq(names(FarmCues.diff(before, moved)), "DecorPlace")
	-- Selling gives Coins back: the sell sound, not a plain coin.
	local sold = state({ decor = {}, currencies = { Coins = 520, Gems = 30, XP = 0 } })
	expect.eq(names(FarmCues.diff(before, sold)), "Sell")
	expect.eq(names(FarmCues.diff(state(), state({ decor = {} }))), "")
end)

test("tool drops, prize crops and the Town Crier", function()
	expect.eq(names(FarmCues.popup({ kind = "Drop", item = "Shovel", name = "Shovel", tool = true })), "ToolDrop")
	expect.eq(names(FarmCues.popup({ kind = "Drop", item = "Wheat", name = "Wheat" })), "Unlock")
	expect.eq(names(FarmCues.popup({ kind = "Prize", crop = "Wheat", tier = "Sunkissed", name = "Sunkissed Wheat" })), "PrizeFind")
	expect.eq(names(FarmCues.popup({ kind = "Prize", crop = "Wheat", tier = "Heirloom", name = "Heirloom Wheat" })), "PrizeHeirloom")
	expect.eq(names(FarmCues.popup({ kind = "PrizeLost", crop = "Wheat", tier = "Sunkissed" })), "PrizeLost")
	expect.eq(names(FarmCues.popup({ kind = "Crier", text = "An Heirloom Wheat was grown!" })), "CrierBell")
end)

test("selling a prize crop at the Prize Stand", function()
	local before = state({ prizes = { { crop = "Wheat", tier = "Sunkissed" } } })
	local after = state({ prizes = {}, currencies = { Coins = 530, Gems = 30, XP = 0 } })
	expect.eq(names(FarmCues.diff(before, after)), "Sell")
	-- A new prize in the basket on its own is quiet (its popup plays the sound).
	expect.eq(names(FarmCues.diff(state({ prizes = {} }), before)), "")
end)

test("putting a prize crop on the Prize Shelf and taking it back", function()
	local prize = { crop = "Wheat", tier = "Sunkissed" }
	local inBasket = state({ prizes = { prize }, prizeShelf = {} })
	local onShelf = state({ prizes = {}, prizeShelf = { prize } })
	expect.eq(names(FarmCues.diff(inBasket, onShelf)), "DecorPlace")
	expect.eq(names(FarmCues.diff(onShelf, inBasket)), "DecorRotate")
end)

test("shop purchases", function()
	expect.eq(names(FarmCues.popup({ kind = "Purchase", key = "Gems100", name = "Pile of Gems", gems = 100 })), "Purchase,Gem")
	expect.eq(names(FarmCues.popup({ kind = "Purchase", key = "VIP", name = "Farm Pass" })), "Purchase")
end)

local function has(cues, sound)
	for _, c in cues do
		if c.sound == sound then
			return c
		end
	end
	return nil
end

test("moving a building sets it down with a thunk", function()
	local before = state({ layout = {} })
	local after = state({ layout = { ["factory:Bakery"] = { x = 10, z = 4, r = 0 } } })
	expect.eq(names(FarmCues.diff(before, after)), "DecorPlace")
	local turned = state({ layout = { ["factory:Bakery"] = { x = 10, z = 4, r = 90 } } })
	expect.eq(names(FarmCues.diff(after, turned)), "DecorPlace")
	expect.eq(names(FarmCues.diff(turned, turned)), "")
end)

test("a Tinker's Guild upgrade plays the unlock sound", function()
	local before = state({ buildingLevels = { Bakery = { time = 1 } } })
	local after = state({ buildingLevels = { Bakery = { time = 1, shelves = 1 } } })
	expect.eq(names(FarmCues.diff(before, after)), "Unlock")
	expect.eq(names(FarmCues.diff(state({ buildingLevels = {} }), state({ buildingLevels = {} }))), "")
end)

test("the Quarry: digging a cell, a Stone block taking a hit, and ore turning up", function()
	local before = state({ quarry = { rows = { ["1"] = 1 }, hits = {} }, oreShed = {} })
	local dug = state({ quarry = { rows = { ["1"] = 3 }, hits = {} }, oreShed = { Copper = 1 } })
	local cues = FarmCues.diff(before, dug)
	expect.eq(names(cues), "Dig,Gem")
	expect.eq(cues[1].pitch, nil)
	expect.eq(cues[2].pitch, -5, "a lower shimmer than Gems")
	local hit = state({ quarry = { rows = { ["1"] = 1 }, hits = { ["2:3"] = 1 } }, oreShed = {} })
	cues = FarmCues.diff(before, hit)
	expect.eq(names(cues), "Dig")
	expect.eq(cues[1].pitch, 3, "the clink of a Stone block that stays")
end)

test("Airship Freight: the horn on docking and leaving, a collect for each crate loaded", function()
	local away = state({ blimp = { arrivesAt = 500 } })
	local load = { rows = { { { item = "Wheat", qty = 5 }, { item = "Bread", qty = 2 } } }, chest = {} }
	local docked = state({ blimp = { leavesAt = 900, load = load } })
	expect.eq(names(FarmCues.diff(away, docked)), "AirshipHorn")
	local filledLoad = { rows = { { { item = "Wheat", qty = 5, filledBy = 1 }, { item = "Bread", qty = 2 } } }, chest = {} }
	local filled = state({ blimp = { leavesAt = 900, load = filledLoad }, inventory = { Wheat = 0 } })
	expect.eq(names(FarmCues.diff(docked, filled)), "FactoryCollect")
	local left = FarmCues.diff(filled, state({ blimp = { arrivesAt = 2000 } }))
	expect.eq(names(left), "AirshipHorn")
	expect.eq(left[1].pitch, -2)
end)

test("the Market stall: listing, a sale, and taking goods back", function()
	local empty = state({ market = { listings = {} } })
	local listed = state({ market = { listings = { { slot = 1, item = "Wheat", qty = 2, price = 10 } } }, inventory = { Wheat = 2 } })
	expect.eq(names(FarmCues.diff(empty, listed)), "DecorPlace")
	local sold = state({ market = { listings = {} }, inventory = { Wheat = 2 }, currencies = { Coins = 510, Gems = 30, XP = 0 } })
	expect.eq(names(FarmCues.diff(listed, sold)), "Sell")
	local back = state({ market = { listings = {} }, inventory = { Wheat = 4 } })
	expect.eq(names(FarmCues.diff(listed, back)), "DecorRotate")
end)

test("the Quarry reopening and the mast's repair finish like builds", function()
	local s = state({ factories = {}, quarry = { readyAt = 150 }, blimp = { readyAt = 400 } })
	expect.eq(names(FarmCues.timed(s, 100, 160)), "BuildDone")
	expect.eq(names(FarmCues.timed(s, 390, 410)), "BuildDone")
	expect.eq(names(FarmCues.timed(s, 160, 390)), "")
end)

test("newer popups: quests, records, the daily gift and news", function()
	expect.eq(names(FarmCues.popup({ kind = "Quest", text = "Harvest 10 Wheat" })), "Notify")
	expect.eq(names(FarmCues.popup({ kind = "QuestClaim", coins = 50, xp = 10 })), "OrderComplete,Coin")
	expect.eq(names(FarmCues.popup({ kind = "QuestChest", gems = 3 })), "Unlock,Gem")
	expect.eq(names(FarmCues.popup({ kind = "RecordClaim", gems = 5 })), "PrizeHeirloom,Gem")
	expect.eq(names(FarmCues.popup({ kind = "Daily", day = 2 })), "Unlock")
	expect.eq(names(FarmCues.popup({ kind = "WelcomeBoost", name = "Pat" })), "Unlock")
	expect.eq(names(FarmCues.popup({ kind = "Away", lines = {} })), "Notify")
	expect.eq(names(FarmCues.popup({ kind = "HelpedYou", name = "Pat" })), "Notify")
	expect.eq(names(FarmCues.popup({ kind = "Visitor", name = "Pat" })), "Notify")
	expect.eq(names(FarmCues.popup({ kind = "Helped", owner = "Pat" })), "Xp")
	expect.eq(names(FarmCues.popup({ kind = "Place", key = "factory:Bakery" })), "UiOpen")
end)

test("news popups leave the next snapshot's Coins their own sound", function()
	for _, kind in { "Crier", "Quest", "Away", "HelpedYou", "Visitor", "Place" } do
		expect.falsy(FarmCues.isReward({ kind = kind }), kind)
	end
	for _, kind in { "Order", "LevelUp", "QuestClaim", "QuestChest", "RecordClaim", "Daily", "Purchase", "Helped" } do
		expect.truthy(FarmCues.isReward({ kind = kind }), kind)
	end
	expect.falsy(FarmCues.isReward(nil))
end)

test("every popup kind the farm server sends has a sound", function()
	-- Reads the farm server's popup kinds, so a new kind without a sound fails here.
	local kinds = {}
	local function scan(path)
		for _, e in listdir(path) do
			local child = path .. "/" .. e.name
			if e.dir then
				scan(child)
			elseif string.sub(e.name, -5) == ".luau" then
				for kind in string.gmatch(readfile(child), 'kind = "(%w+)"') do
					kinds[kind] = true
				end
			end
		end
	end
	scan(ROOT .. "/../farm/src/server")
	local count = 0
	for kind in kinds do
		count += 1
		local payload = { kind = kind, tool = "Shovel" }
		expect.truthy(#FarmCues.popup(payload) > 0, kind .. " has no sound")
	end
	expect.truthy(count >= 15, "found the popup kinds")
end)
