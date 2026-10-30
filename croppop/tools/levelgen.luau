--[[
	Crop Pop level generator. Builds levels 6..175 from original shape and
	obstacle patterns, then tunes each level's moves with the test bot until
	its win rate is near the target for its place in the game.

	Run from the croppop/ folder (prints Luau text for each level):

		luaurun tools/levelgen.luau 6 175 > /tmp/levels.txt

	The output is pasted into src/shared/Levels/SetNN.luau. Levels are fixed
	once they ship, so this tool is for making new ones and retuning drafts;
	hand edits in the level editor win over regenerating.

	Same id, same level: every choice comes from an Rng seeded by the id.
]]

local load = loadmodule(readfile("tools/loadshared.luau"), "tools/loadshared.luau", setmetatable({}, { __index = _G }))()
local Bot = load("Bot")
local Engine = load("Engine")
local Matcher = load("Matcher")
local LevelText = load("LevelText")
local Levels = load("Levels")
local Rng = load("Rng")
local Tiles = load("Tiles")

local FIRST = tonumber(ARGS[1]) or 6
local LAST = tonumber(ARGS[2]) or 175
local GAMES = tonumber(ARGS[3]) or 48

-- Names for levels 6 onwards, in order.
local NAMES = {
	"Clover Patch", "Barn Dance", "Dewy Morning", "Fence Post", "Puddle Jump",
	"Haystack Hill", "Sprout Lane", "Muddy Boots", "Golden Rows", "Rooster Call",
	"Picnic Field", "Windmill Way", "Carrot Top", "Butter Churn", "Bramble Path",
	"Sheep Shearing", "Orchard Gate", "Rainy Day", "Tractor Tracks", "Honey Hollow",
	"Sunflower Bend", "Woolly Hills", "Corncrib Corner", "Egg Hunt", "Market Morning",
	"Mill Pond", "Scarecrow Watch", "Hay Loft", "Berry Bramble", "Cattle Crossing",
	"Frosty Furrows", "Harvest Moon", "Duck Pond", "Weathervane", "Goat Gully",
	"Tomato Terrace", "Milk Run", "Seed Bag", "Garden Gate", "Plough Line",
	"Cobble Yard", "Stable Row", "Lantern Lane", "Thistle Down", "Brook Bridge",
	"Meadow Maze", "Sugar Beet", "Old Oak", "Chicken Coop", "Root Cellar",
	"Willow Bank", "Hilltop Farm", "Dusty Road", "Cider Press", "Turnip Turn",
	"Bluebell Glade", "Pasture Loop", "Wheelbarrow", "Silo Shadow", "Henhouse Hustle",
	"Wild Oats", "Rolling Bales", "Cornflower Field", "Barnyard Bustle", "Cowbell Valley",
	"Sowing Season", "Clay Pots", "Sunset Shed", "Rusty Gate", "Fieldstone Wall",
	"Haywagon Ride", "Bumble Meadow", "Morning Milking", "Muddy Ditch", "Woolpack Lane",
	"Spud Rows", "Lavender Ridge", "Pea Pod", "Grain Store", "Foggy Fields",
	"Rain Barrel", "Tilled Earth", "Picket Fence", "Goose Green", "Saddle Hill",
	"Acorn Grove", "Market Stall", "Cabbage Corner", "Shearing Shed", "Harvest Feast",
	"Starry Paddock", "Lucky Horseshoe", "Fresh Furrows", "Apple Cart", "Golden Harvest",
	"Pumpkin Patch", "Hayride Hollow", "Gourd Garden", "Cranberry Bog", "Maple Lane",
	"Squash Rows", "Barley Maze", "Apple Bobbing", "Barn Owl", "Harvest Fair",
	"Leaf Pile", "Cider Mill", "Pumpkin Pie", "Bonfire Night", "Walnut Grove",
	"Haystack Maze", "Autumn Mist", "Turnip Lanterns", "Root Market", "Giant Gourd Show",
	"Hazel Hedge", "First Frost", "Harvest Supper", "Quilting Bee", "Moonlit Pumpkins",
	"Lucky Clover", "Green Pasture", "Mossy Stones", "Shamrock Hill", "Grand Harvest Ball",
	"Hedgerow", "Barn Swallow", "Fern Hollow", "Sheepfold", "Meadowsweet",
	"Gooseberry Lane", "Paddock Gate", "Summer Breeze", "Clover Honey", "Village Fete",
	"Nettle Bank", "Plum Orchard", "Dandelion Clock", "Rye Field", "Kitchen Garden",
	"Mill Wheel", "Lamb Meadow", "Buttercup Lane", "Cloverleaf Crossing", "Golden Meadows",
	"Old Stone Wall", "Frozen Pond", "Woodpile", "Snowy Barn", "Quarry Road",
	"Hot Cocoa", "Sleigh Path", "Winter Wheat", "Holly Bush", "Midwinter Market",
	"Pine Cone Lane", "Icicle Eaves", "Mitten Hill", "Rock Garden", "Hearth Bread",
	"Snowdrop Field", "Chimney Smoke", "Wool Socks", "Lantern Walk", "Winter Feast",
	"Cobblestone Bridge", "Robin's Perch", "Frosted Turnips", "Firelight Barn", "New Year Fields",
}

-- Township-like move counts: long enough to plan, short enough to stay tense.
local MIN_MOVES, MAX_MOVES = 15, 35
local MAX_COLLECT = 45
local FROST_INTRO = 21 -- first level with frost
local WEEDS_INTRO = 41 -- first level with weeds
local PUMPKIN_INTRO = 101 -- first level with pumpkins
local CLOVER_INTRO = 126 -- first level with clover
local STONE_INTRO = 151 -- first level with stone walls
local INTROS = { [FROST_INTRO] = true, [WEEDS_INTRO] = true, [PUMPKIN_INTRO] = true, [CLOVER_INTRO] = true, [STONE_INTRO] = true }

local REWARDS = {
	Normal = { coins = 25, xp = 5 },
	Tough = { coins = 50, xp = 10 },
	["Super Tough"] = { coins = 75, xp = 15 },
}

local function difficultyOf(id: number): string
	if id >= 20 and id % 10 == 0 then
		return "Super Tough"
	elseif id % 5 == 0 then
		return "Tough"
	end
	return "Normal"
end

-- Bot win rate to aim for. People do much better than the bot, so these
-- read low; what matters is the step between Normal, Tough and Super Tough.
local function targetOf(id: number, difficulty: string): number
	if difficulty == "Super Tough" then
		return if id <= 50 then 0.25 else 0.2
	elseif difficulty == "Tough" then
		return if id <= 25 then 0.45 elseif id <= 50 then 0.38 else 0.32
	end
	return if id <= 12 then 0.8 elseif id <= 25 then 0.7 elseif id <= 50 then 0.6 else 0.5
end

-- Grid helpers -----------------------------------------------------------------

local function newGrid(w, h, ch)
	local g = { w = w, h = h }
	for y = 1, h do
		g[y] = {}
		for x = 1, w do
			g[y][x] = ch
		end
	end
	return g
end

-- Sets a cell and its left-right mirror (and top-bottom mirror if asked).
local function setSym(g, x, y, ch, both)
	local mx = g.w - x + 1
	local my = g.h - y + 1
	g[y][x] = ch
	g[y][mx] = ch
	if both then
		g[my][x] = ch
		g[my][mx] = ch
	end
end

local function isCell(g, x, y)
	return x >= 1 and x <= g.w and y >= 1 and y <= g.h and g[y][x] ~= "#"
end

local function countCells(g, pred)
	local n = 0
	for y = 1, g.h do
		for x = 1, g.w do
			if pred(g[y][x]) then
				n += 1
			end
		end
	end
	return n
end

-- Every cell reachable from every other, and every column has a cell.
local function connected(g)
	local start
	for y = 1, g.h do
		for x = 1, g.w do
			if g[y][x] ~= "#" then
				start = start or { x, y }
			end
		end
	end
	for x = 1, g.w do
		local any = false
		for y = 1, g.h do
			any = any or g[y][x] ~= "#"
		end
		if not any then
			return false
		end
	end
	local seen, stack, count = {}, { start }, 0
	seen[start[2] * 100 + start[1]] = true
	while #stack > 0 do
		local p = table.remove(stack)
		count += 1
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, ny = p[1] + d[1], p[2] + d[2]
			if isCell(g, nx, ny) and not seen[ny * 100 + nx] then
				seen[ny * 100 + nx] = true
				table.insert(stack, { nx, ny })
			end
		end
	end
	return count == countCells(g, function(c)
		return c ~= "#"
	end)
end

-- Shapes: where the holes go ---------------------------------------------------

local SHAPES = {
	function() end, -- full board
	function(g, rng) -- cut corners
		local k = rng:int(1, 2)
		for y = 1, k do
			for x = 1, k - y + 1 do
				setSym(g, x, y, "#", true)
			end
		end
	end,
	function(g, rng) -- top corners only
		local k = rng:int(1, 3)
		for y = 1, k do
			for x = 1, k - y + 1 do
				setSym(g, x, y, "#")
			end
		end
	end,
	function(g) -- centre hole
		local cx, cy = math.ceil(g.w / 2), math.ceil(g.h / 2)
		setSym(g, cx, cy, "#", true)
		if g.w % 2 == 0 then
			setSym(g, cx, cy - 1, "#", true)
		end
	end,
	function(g, rng) -- side notches
		local y = rng:int(3, g.h - 2)
		setSym(g, 1, y, "#")
		if rng:int(1, 2) == 1 then
			setSym(g, 1, g.h - y + 1, "#")
		end
	end,
	function(g) -- diamond
		local r = math.max(g.w, g.h) // 2 + 1
		local cx, cy = (g.w + 1) / 2, (g.h + 1) / 2
		for y = 1, g.h do
			for x = 1, g.w do
				if math.abs(x - cx) + math.abs(y - cy) > r + 0.5 then
					g[y][x] = "#"
				end
			end
		end
	end,
	function(g, rng) -- pillars
		local x = rng:int(2, math.max(2, g.w // 2 - 1))
		local y = rng:int(3, g.h - 3)
		setSym(g, x, y, "#")
		setSym(g, x, y + 1, "#")
	end,
	function(g) -- hourglass
		local mid = math.ceil(g.h / 2)
		setSym(g, 1, mid, "#")
		if g.h % 2 == 0 then
			setSym(g, 1, mid + 1, "#")
		end
		setSym(g, 1, 1, "#")
		setSym(g, 1, g.h, "#")
	end,
	function(g) -- top teeth
		for x = 1, g.w // 2, 2 do
			setSym(g, x, 1, "#")
		end
	end,
	function(g) -- plus in the middle
		local cx, cy = math.ceil(g.w / 2), math.ceil(g.h / 2)
		setSym(g, cx, cy, "#")
		setSym(g, cx - 1, cy, "#")
		setSym(g, cx, cy - 1, "#")
		setSym(g, cx, cy + 1, "#")
	end,
	function(g) -- bottom corners
		setSym(g, 1, g.h, "#")
		setSym(g, 2, g.h, "#")
		setSym(g, 1, g.h - 1, "#")
	end,
}

-- Obstacle patterns: which cells get mud or bales ------------------------------

-- Each returns a list of {x, y} on the left half (mirrored when placed).
local PATTERNS = {
	rows = function(g, rng)
		local out, step = {}, rng:int(2, 3)
		for y = rng:int(2, 3), g.h, step do
			for x = 2, math.ceil(g.w / 2) do
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	frame = function(g, rng)
		local out, d = {}, rng:int(1, 2)
		for y = d, g.h - d + 1 do
			for x = d, math.ceil(g.w / 2) do
				if y == d or y == g.h - d + 1 or x == d then
					table.insert(out, { x, y })
				end
			end
		end
		return out
	end,
	bottom = function(g, rng)
		local out = {}
		for y = g.h - rng:int(1, 2), g.h do
			for x = 1, math.ceil(g.w / 2) do
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	centre = function(g, rng)
		local out, r = {}, rng:int(1, 2)
		local cy = math.ceil(g.h / 2)
		for y = cy - r, cy + r do
			for x = math.ceil(g.w / 2) - r, math.ceil(g.w / 2) do
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	checker = function(g, rng)
		local out, top = {}, rng:int(1, 3)
		for y = top, g.h do
			for x = 1, math.ceil(g.w / 2) do
				if (x + y) % 2 == 0 then
					table.insert(out, { x, y })
				end
			end
		end
		return out
	end,
	columns = function(g, rng)
		local out, x = {}, rng:int(1, math.ceil(g.w / 2) - 1)
		for y = rng:int(2, 3), g.h do
			table.insert(out, { x, y })
		end
		return out
	end,
	diagonal = function(g)
		local out = {}
		for y = 1, g.h do
			local x = (y % math.ceil(g.w / 2)) + 1
			table.insert(out, { x, y })
		end
		return out
	end,
	scatter = function(g, rng)
		local out = {}
		for _ = 1, rng:int(3, 6) do
			table.insert(out, { rng:int(1, math.ceil(g.w / 2)), rng:int(2, g.h) })
		end
		return out
	end,
}

local MUD_PATTERNS = { "rows", "frame", "bottom", "centre", "checker", "diagonal", "scatter" }
local BALE_PATTERNS = { "fence", "corners", "columns", "centre", "scatter", "pairs" }

local BALES = {
	fence = function(g, rng)
		-- A broken row: never the full width, so pieces can slide past.
		local y, out = rng:int(3, g.h - 1), {}
		for x = 1, math.ceil(g.w / 2) - 1 do
			if x ~= rng:int(1, 3) then
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	corners = function(g, rng)
		local out, k = {}, rng:int(1, 2)
		for y = g.h - k, g.h do
			for x = 1, k + 1 - (g.h - y) do
				table.insert(out, { x, y })
			end
		end
		return out
	end,
	columns = PATTERNS.columns,
	centre = function(g, rng)
		local cy = rng:int(3, g.h - 2)
		local cx = math.ceil(g.w / 2)
		return { { cx, cy }, { cx, cy + 1 }, { cx - 1, cy + 1 } }
	end,
	scatter = PATTERNS.scatter,
	pairs = function(g, rng)
		local out = {}
		for _ = 1, rng:int(2, 3) do
			local x, y = rng:int(1, math.ceil(g.w / 2) - 1), rng:int(3, g.h)
			table.insert(out, { x, y })
			table.insert(out, { x + 1, y })
		end
		return out
	end,
}

-- What a level is about, by id ---------------------------------------------------

local function mechanics(id)
	return {
		thickMud = id >= 13, -- "M"
		bales2 = id >= 9,
		bales3 = id >= 26,
		sixColors = id >= 30,
		frost = id >= FROST_INTRO, -- "f"
		thickFrost = id >= 33, -- "F"
		weeds = id >= WEEDS_INTRO, -- "w"
		pumpkins = id >= PUMPKIN_INTRO, -- "p"
		clover = id >= CLOVER_INTRO, -- "c"
		stones = id >= STONE_INTRO, -- "s"
		thickStones = id >= 160, -- "S"
	}
end

-- Rotates focus so neighbouring levels feel different.
local FOCUS = { "Collect", "Mud", "HayBale", "Mix", "Mud", "Collect", "HayBale", "Mix" }
local FOCUS_FROST = { "Collect", "Mud", "Frost", "HayBale", "Mix", "Mud", "Frost", "Collect", "HayBale", "Mix" }
local FOCUS_WEEDS = { "Collect", "Weeds", "Mud", "Frost", "HayBale", "Mix", "Mud", "Weeds", "Collect", "Frost", "HayBale", "Mix" }
local FOCUS_STONES = { "Stones", "Clover", "Collect", "Pumpkins", "Stones", "Weeds", "Mud", "Frost", "Stones", "HayBale", "Mix", "Clover" }
local FOCUS_CLOVER = { "Clover", "Pumpkins", "Collect", "Weeds", "Clover", "Mud", "Frost", "HayBale", "Clover", "Mix", "Pumpkins", "Collect" }
local FOCUS_PUMPKINS = { "Pumpkins", "Collect", "Weeds", "Mud", "Pumpkins", "Frost", "HayBale", "Mix", "Pumpkins", "Weeds", "Collect", "Mix" }

-- Names that promise an obstacle get it (when it's in the game by then).
local NAME_HINTS = {
	{ words = { "Mud", "Puddle", "Ditch" }, focus = "Mud" },
	{ words = { "Bale", "Hay" }, focus = "HayBale" },
	{ words = { "Frost", "Foggy" }, focus = "Frost", needs = "frost" },
	{ words = { "Thistle", "Bramble", "Wild Oats" }, focus = "Weeds", needs = "weeds" },
	{ words = { "Pumpkin", "Gourd", "Squash" }, focus = "Pumpkins", needs = "pumpkins" },
	{ words = { "Clover", "Shamrock", "Green" }, focus = "Clover", needs = "clover" },
	{ words = { "Stone", "Quarry", "Rock" }, focus = "Stones", needs = "stones" },
}

local function focusOf(id, name)
	local mech = mechanics(id)
	if id == FROST_INTRO then
		return "Frost"
	elseif id == WEEDS_INTRO then
		return "Weeds"
	elseif id == PUMPKIN_INTRO then
		return "Pumpkins"
	elseif id == CLOVER_INTRO then
		return "Clover"
	elseif id == STONE_INTRO then
		return "Stones"
	end
	for _, hint in NAME_HINTS do
		for _, word in hint.words do
			if string.find(name, word, 1, true) and (hint.needs == nil or mech[hint.needs]) then
				return hint.focus
			end
		end
	end
	if id <= 7 then
		return ({ "Collect", "Mud", "Collect" })[id - 5] or "Mud"
	end
	local list = if mech.stones then FOCUS_STONES elseif mech.clover then FOCUS_CLOVER elseif mech.pumpkins then FOCUS_PUMPKINS elseif mech.weeds then FOCUS_WEEDS elseif mech.frost then FOCUS_FROST else FOCUS
	return list[(id % #list) + 1]
end

local function placeMud(g, rng, id, mech)
	local name = rng:pick(MUD_PATTERNS)
	local thick = mech.thickMud and rng:int(1, 100) <= math.min(60, (id - 10) * 2)
	for _, p in PATTERNS[name](g, rng) do
		if isCell(g, p[1], p[2]) then
			setSym(g, p[1], p[2], if thick and (p[1] + p[2]) % 2 == 0 then "M" else "m")
		end
	end
end

local function placeBales(g, rng, id, mech)
	local name = rng:pick(BALE_PATTERNS)
	local top = if mech.bales3 then 3 elseif mech.bales2 then 2 else 1
	for _, p in BALES[name](g, rng) do
		if isCell(g, p[1], p[2]) and p[2] > 1 then
			local layers = rng:int(math.max(1, top - 1), top)
			setSym(g, p[1], p[2], tostring(layers))
		end
	end
end

-- No checker pattern: it freezes every other tile and leaves no swaps.
local FROST_PATTERNS = { "rows", "centre", "diagonal", "scatter", "columns" }

-- Frost goes on plain cells only (not mud or bales).
local function placeFrost(g, rng, id, mech)
	-- The first frost level keeps it small and in the middle.
	local name = if id == FROST_INTRO then "centre" else rng:pick(FROST_PATTERNS)
	local thick = mech.thickFrost and rng:int(1, 100) <= math.min(50, (id - 30) * 2)
	for _, p in PATTERNS[name](g, rng) do
		if isCell(g, p[1], p[2]) and g[p[2]][p[1]] == "." then
			setSym(g, p[1], p[2], if thick and (p[1] + p[2]) % 2 == 1 then "F" else "f")
		end
	end
end

-- A few weeds to start with, low on the board; they spread from there.
local function placeWeeds(g, rng)
	local placed = 0
	for _ = 1, 20 do
		if placed >= rng:int(1, 2) then
			break
		end
		local x, y = rng:int(1, math.ceil(g.w / 2) - 1), rng:int(math.ceil(g.h / 2), g.h)
		if isCell(g, x, y) and g[y][x] == "." then
			setSym(g, x, y, "w")
			placed += 1
		end
	end
end

-- Pumpkins start near the top, never in a column's bottom cell. Returns how
-- many the goal asks for (more drop in as these are collected).
local function placePumpkins(g, rng, id)
	local want = if id == PUMPKIN_INTRO then 2 else rng:int(1, 3)
	local placed = 0
	for _ = 1, 40 do
		if placed >= want then
			break
		end
		local x, y = rng:int(1, g.w), rng:int(1, 2)
		local below = false
		for yy = y + 1, g.h do
			below = below or isCell(g, x, yy)
		end
		if isCell(g, x, y) and g[y][x] == "." and below then
			g[y][x] = "p"
			placed += 1
		end
	end
	if placed == 0 then
		return 0
	end
	return placed + (if id == PUMPKIN_INTRO then 0 else rng:int(0, 1))
end

-- Stone walls use the bale shapes; the first stone level keeps them few and thin.
local function placeStones(g, rng, id, mech)
	local name = if id == STONE_INTRO then "centre" else rng:pick(BALE_PATTERNS)
	for _, p in BALES[name](g, rng) do
		if isCell(g, p[1], p[2]) and p[2] > 1 and g[p[2]][p[1]] == "." then
			local thick = mech.thickStones and rng:int(1, 3) == 1
			setSym(g, p[1], p[2], if thick then "S" else "s")
		end
	end
end

-- A small clover patch to grow from, low and in the middle (mirrored).
local function placeClover(g, rng, id)
	local size = if id == CLOVER_INTRO then 2 else rng:int(1, 3)
	local cx = math.ceil(g.w / 2)
	local y = rng:int(math.ceil(g.h / 2), g.h)
	for i = 0, size - 1 do
		local x = cx - i
		if isCell(g, x, y) and g[y][x] == "." then
			setSym(g, x, y, "c")
		end
	end
end

-- Keep a gap in every row so nothing is sealed off: bales, weeds and frozen
-- tiles all stop falling tiles.
local function keepRowsOpen(g)
	for y = 1, g.h do
		local open = false
		for x = 1, g.w do
			local c = g[y][x]
			open = open or c == "." or c == "m" or c == "M"
		end
		if not open then
			setSym(g, math.ceil(g.w / 2), y, ".")
		end
	end
end

local function layoutText(g)
	local rows = {}
	for y = 1, g.h do
		rows[y] = table.concat(g[y])
	end
	return rows
end

local function has(g, chars)
	return countCells(g, function(c)
		return string.find(chars, c, 1, true) ~= nil
	end)
end

local function draft(id, variant)
	local rng = Rng.new(id * 7919 + variant * 104729)
	local mech = mechanics(id)
	local difficulty = difficultyOf(id)
	local name = NAMES[id - 5] or ("Level " .. id)
	local focus = focusOf(id, name)
	local w = rng:int(7, if id < 15 then 8 else 9)
	local h = rng:int(7, if id < 15 then 8 else 9)
	local g
	repeat
		g = newGrid(w, h, ".")
		rng:pick(SHAPES)(g, rng)
	until connected(g) and countCells(g, function(c)
		return c ~= "#"
	end) >= 42

	local wantMud = focus == "Mud" or (focus == "Mix" and rng:int(1, 2) == 1)
	local wantBales = id >= 7 and (focus == "HayBale" or (focus == "Mix" and not wantMud) or (focus == "Mix" and id >= 40))
	if focus == "Clover" then
		-- Clover can't grow under bales from matches, so clover levels go without them.
		wantBales = false
		wantMud = id ~= CLOVER_INTRO and rng:int(1, 3) == 1
	end
	if wantMud then
		placeMud(g, rng, id, mech)
	end
	if wantBales then
		placeBales(g, rng, id, mech)
	end
	if focus == "Frost" or (focus == "Mix" and mech.frost and rng:int(1, 3) == 1) then
		placeFrost(g, rng, id, mech)
	end
	if focus == "Weeds" or (focus == "Mix" and mech.weeds and rng:int(1, 3) == 1) then
		placeWeeds(g, rng)
	end
	if focus == "Clover" then
		placeClover(g, rng, id)
	end
	if focus == "Stones" or (focus == "Mix" and mech.stones and rng:int(1, 3) == 1) then
		placeStones(g, rng, id, mech)
	end
	local pumpkins = 0
	if focus == "Pumpkins" or (focus == "Mix" and mech.pumpkins and rng:int(1, 3) == 1) then
		pumpkins = placePumpkins(g, rng, id)
	end
	keepRowsOpen(g)
	if not connected(g) then
		return nil
	end

	local colorCount = if mech.sixColors and difficulty ~= "Normal" and rng:int(1, 3) == 1 then 6 else 5
	local colors = table.clone(Tiles.Names)
	rng:shuffle(colors)
	colors = table.move(colors, 1, colorCount, 1, {})
	table.sort(colors, function(a, b)
		return Tiles.ByName[a] < Tiles.ByName[b]
	end)

	local goals = {}
	if has(g, "mM") > 0 then
		table.insert(goals, { kind = "Mud" })
	end
	if has(g, "123") > 0 then
		table.insert(goals, { kind = "HayBale" })
	end
	if has(g, "fF") > 0 then
		table.insert(goals, { kind = "Frost" })
	end
	if has(g, "w") > 0 then
		table.insert(goals, { kind = "Weeds" })
	end
	if pumpkins > 0 then
		table.insert(goals, { kind = "Pumpkins", count = pumpkins })
	end
	if has(g, "c") > 0 then
		table.insert(goals, { kind = "Clover" })
	end
	if has(g, "sS") > 0 then
		table.insert(goals, { kind = "Stones" })
	end
	if #goals > 3 then
		return nil -- the goal bar shows 3 at most
	end
	-- Frost and bales can leave too few swappable tiles: the board must deal playable.
	local probe = { layout = layoutText(g), colors = colors, goals = { { kind = "Collect", tile = colors[1], count = 1 } }, moves = 1 }
	for seed = 1, 10 do
		if not Matcher.hasPossibleMove(Engine.new(probe, seed).board) then
			return nil
		end
	end
	local collects = if #goals == 0 then rng:int(1, 2) elseif id >= 20 and #goals < 2 and rng:int(1, 2) == 1 then 1 else 0
	if focus == "Collect" and collects == 0 then
		collects = 1
	end
	if INTROS[id] then
		collects = 0 -- an intro level is about the new obstacle alone
	end
	local picks = table.clone(colors)
	rng:shuffle(picks)
	for i = 1, collects do
		local count = 10 + math.floor(id / 4) + rng:int(0, 6)
		if collects == 1 and #goals == 0 then
			count = math.floor(count * 1.6)
		end
		count = math.min(count, MAX_COLLECT)
		table.insert(goals, { kind = "Collect", tile = picks[i], count = count })
	end

	return {
		id = id,
		name = name,
		difficulty = difficulty,
		moves = 25,
		colors = colors,
		layout = layoutText(g),
		goals = goals,
		rewards = table.clone(REWARDS[difficulty]),
	}
end

-- Tuning --------------------------------------------------------------------------


local function rate(level, moves)
	local copy = table.clone(level)
	copy.moves = moves
	return Bot.play(copy, GAMES, level.id).winRate
end

-- Fewest moves that reach the target (binary search; the bot is noisy but
-- the trend is steady enough).
local function tune(level, target)
	local lo, hi = MIN_MOVES, MAX_MOVES
	if rate(level, hi) < target then
		return nil, "too hard"
	end
	if rate(level, lo) >= target then
		return lo, "too easy"
	end
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if rate(level, mid) >= target then
			hi = mid
		else
			lo = mid
		end
	end
	return hi
end

local function scaleCollects(level, factor)
	for _, goal in level.goals do
		if goal.kind == "Collect" then
			goal.count = math.clamp(math.floor(goal.count * factor + 0.5), 6, MAX_COLLECT)
		end
	end
end

-- The bot is much worse than a person at steering pumpkins down and at
-- spreading clover, so it gets a lower bar on those levels (their intro
-- levels use the usual one).
local GUIDED_TARGET_SCALE = 0.7

local function hasGoal(level, kind)
	for _, goal in level.goals do
		if goal.kind == kind then
			return true
		end
	end
	return false
end

local function build(id)
	local baseTarget = targetOf(id, difficultyOf(id))
	for variant = 0, 9 do
		local level = draft(id, variant)
		local target = baseTarget
		if level and not INTROS[id] and (hasGoal(level, "Pumpkins") or hasGoal(level, "Clover")) then
			target *= GUIDED_TARGET_SCALE
		end
		if level and Levels.validate(level) == nil then
			local moves, note = tune(level, target)
			if note == "too easy" and INTROS[id] then
				-- An intro level may be easy; it only teaches the new obstacle.
				moves, note = MIN_MOVES + 3, nil
			end
			if note == "too easy" then
				-- Ask for more: bigger collect goals, or an extra one.
				local hasCollect = false
				for _, goal in level.goals do
					hasCollect = hasCollect or goal.kind == "Collect"
				end
				if not hasCollect and #level.goals < 3 then
					table.insert(level.goals, { kind = "Collect", tile = level.colors[(id % #level.colors) + 1], count = 12 + id // 5 })
				else
					scaleCollects(level, 1.5)
				end
				moves, note = tune(level, target)
			end
			if moves and note == nil then
				level.moves = moves
				return level, rate(level, moves), variant, target
			end
		end
	end
	error("could not build level " .. id)
end

for id = FIRST, LAST do
	local started = clock()
	local level, winRate, variant, target = build(id)
	print(string.format("-- level %d: bot wins %d%% (target %d%%), variant %d, %.0fs", id, winRate * 100, target * 100, variant, clock() - started))
	print(LevelText.write(level))
end
