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

test("a tool drop sparkles", function()
	expect.eq(names(FarmCues.popup({ kind = "Drop", item = "Shovel" })), "Unlock")
end)

test("missing blocks in a snapshot don't break it (newer farm builds add more)", function()
	expect.eq(names(FarmCues.diff({}, {})), "")
	expect.eq(names(FarmCues.diff({ fields = {} }, { factories = { Dairy = { built = true } } })), "")
end)
