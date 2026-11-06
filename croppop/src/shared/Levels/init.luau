--[[
	Crop Pop levels: the shared API. The level data lives in the Set modules
	next to this one, 25 levels each, in play order.

	Layout characters:
	  .  plain cell          #  hole (not part of the board)
	  m  mud, 1 layer        M  mud, 2 layers
	  a  glazed clay under the tile: only a blast cracks it, then any clear
	     there breaks it up (the Clay goal)   A  cracked clay (any clear)
	  f  frost, 1 layer      F  frost, 2 layers (the tile is frozen in place)
	  w  weed (spreads when a swap pulls none)
	  p  pumpkin (drop it to the bottom of its column; not on a column's bottom cell)
	  o  muddy pumpkin: a pumpkin that a match next to it must wash before it
	     can be collected (blasts don't); it may start on the bottom cell
	  c  clover (matches on it spread it; a Clover goal covers the board)
	  I  gopher burrow: a plain cell; one gopher at a time sits in an open
	     burrow and hops to another after every swap; clearing the tile on
	     its burrow catches it and fills that burrow in (the Gophers goal)
	  U  lawn mower: blocks a cell and never breaks; it has a tile colour
	     (the level's colours in turn, in reading order), every wave with a
	     match of that colour charges it, and the third charge mows its row
	  Q  mist on a plain cell: hides its tile (which still swaps and
	     matches); a match on the cell or next to it lifts it, blasts
	     don't (the Mist goal)
	  Y  vine over the tile: holds it in place and out of matches like a
	     web, but a match next to it cuts it as well as a blast; after a
	     swap that cuts none, the vines creep onto another tile next to
	     them (the Vines goal)
	  D  songbird: blocks like a bale and wants one tile colour (the level's
	     colours in turn, in reading order), hopping on to the next colour
	     after every swap; a match of its colour next to it feeds it, other
	     matches and blasts don't (the Birds goal)
	  Z  weathervane: blocks like a 2-layer bale, with an arrow pointing up,
	     right, down or left (in turn, in reading order) that turns a
	     quarter clockwise after every swap; only a match on the side it
	     points at knocks a layer off, blasts from anywhere (the Vanes goal)
	  X  tool chest: blocks like a bale and starts locked; only a blast
	     unlocks it, then each match next to it or blast on it takes one of
	     its 3 tools (the Tools goal), and the last one frees the cell
	  J  jam jar: blocks like a bale and has a tile colour (the level's
	     colours in turn, in reading order); 3 matches of that colour next
	     to it (or blasts) fill it, then any match next to it or a blast
	     cracks it open (the Jars goal)
	  K  seed packet: blocks like a bale and holds 4 seeds of one tile colour
	     (the level's colours in turn, in reading order); a match of that
	     colour next to it, or a blast, takes a seed (the Packets goal)
	  W  flood water under a tile: only a hand pump drains it (the Floods goal)
	  H  hand pump: blocks a cell and never breaks; every hit drains the 2
	     nearest flooded cells, and pumps go once all the water has
	  B  compost bin: blocks like a 1-layer bale and counts down from 9; a
	     match next to it takes all its tiles off, a blast takes 1, and at 0
	     it bursts, blasting the cells around it (the Bins goal)
	  R  seed tray cell: touching R cells make one tray, under the tiles;
	     clearing the tile on a tray cell sprouts it, and a tray with every
	     cell sprouted is done (the Trays goal)
	  N  firefly spot: a plain cell; a third of the spots are lit at a time
	     and the lights move every 2 swaps. Clearing the tile on a lit spot
	     catches a firefly (the Fireflies goal, which needs a count)
	  E  lost lamb: blocks a cell and never breaks; a match next to it walks
	     it a cell towards the nearest pen, trampling what's there, and one
	     that reaches a pen is home (the Lambs goal)
	  P  lamb pen: a plain cell where lambs go home. Lambs need a pen and a
	     Lambs goal
	  T  tulip bud: blocks like a 1-layer bale; every hit charges it and the
	     third makes it bloom (the Blooms goal), but a swap that doesn't hit
	     a charged bud closes it back up to no charge
	  = +  fruit cage over a tile ("+" also holds one of its pegs): each
	     connected group is one cage, holding its tiles like a web; a match
	     next to a peg or a blast on it pulls the peg, and the last peg out
	     lifts the cage (the Cages goal). Every cage needs a peg.
	  *  berry bush: blocks a cell and never breaks; every 3rd match next
	     to it ripens it and sends 3 berries to the Berries goal (which
	     needs a count); blasts don't ripen it
	  $  apple tree: blocks a cell with 2 apples on it; only blasts shake
	     them off, one a blast (the Apples goal), and a bare tree goes
	  &  stew pot: blocks like a 2-layer bale; every hit knocks a layer off
	     (the Pots goal), but after a swap that doesn't hit it, it puffs
	     mist onto a plain tile next to it
	  ^  cold frame: blocks like a 3-layer bale; every hit opens it a stage
	     and the last frees its seedling (the Frames goal), but a swap that
	     doesn't hit a part-open frame closes it one stage again
	  O  garden snail: blocks a cell and never breaks; a match next to it
	     shoves it a cell away, biting what's there and crawling in if that
	     empties the cell, leaving goo behind. Needs a Goo goal
	  C  hay truck: blocks like a 3-layer bale; each hit drops one of its 3
	     hay bales into the nearest cell the move emptied. Needs a HayBale
	     goal, which counts the truck's bales
	  j  beehive: blocks a cell and never breaks; each hit (a match next to
	     it or a blast) sends a honey jar to the Honey goal, which needs a
	     count and at least one hive
	  v  stack of 3 produce boxes   V  stack of 2: blocks like a bale with
	     that many layers; each hit takes a box (the Boxes goal), and the
	     rest hop into the nearest cell the wave just emptied
	  u  mud bucket: blocks like a 1-layer bale; a hit tips it over, spilling
	     a layer of mud around it (the 3x3 cells with no mud, clay or bale).
	     Needs a Mud goal, which counts each bucket as one more
	  y  scarecrow: blocks a cell and never breaks; every third hit (a match
	     next to it or a blast) clears the most common tile colour
	  l  mailbox with a letter     L  empty mailbox: either blocks like a
	     2-layer bale; the first hit opens it, the next takes it away (and
	     the letter, for the Letters goal)
	  i  snowball: a tile with a timer; it bursts after 8 swaps, frosting the
	     tiles around it, then starts again. Clearing it counts for the
	     Snowballs goal
	  z  seed sack: blocks a cell and never breaks; a match next to it or a
	     blast on it sows clover on the nearest cells without any. Needs a
	     Clover goal.
	  s  stone wall, 1 layer   S  stone wall, 2 layers (only blasts break stone)
	  g  goo over the tile (a match or blast on it clears it; after a swap that
	     clears none, it spreads to a neighbouring tile; covering the board loses)
	  b  buried statue under the tile: touching b cells make one statue; only
	     blasts (power-ups, boosters) dig a cell up, and the Statues goal wants
	     every statue dug up
	  t  tarp: touching t cells in a row make one tarp, blocking like 1-layer
	     bales; matches next to it and blasts on it roll it up from its right
	     end (the Tarps goal)
	  e  thick goo over the tile: two clears (the first leaves plain goo), and
	     goo spreading next to it spreads thick
	  n  web over the tile: the tile can't move or match; only a blast clears
	     the web (the Webs goal)
	  r  rainbow patch under the tile: after every swap the plain tile on it
	     changes to the next colour that doesn't make a match
	  q  quilt: touching q cells make one quilt, blocking like bales that
	     nothing breaks; it needs one patch per cell, and when the last patch
	     lands it lifts off (the Quilts goal)
	  k  sewing tin: blocks like a 1-layer bale; a match next to it or a blast
	     opens it and sends a patch to a quilt (a level needs at least one tin
	     per quilt cell)
	  x  surprise crate: blocks like a 1-layer bale; a match next to it or a blast
	     opens it, and it leaves a power-up (or now and then a hay bale)
	  h  hen house: not a cell, and nothing falls past it; it drops a new tile
	     into the cell below whenever that cell is empty, every other one an
	     Egg (needs Egg in the colours)
	  G  goo spring: not a cell (pieces fall past it) and nothing breaks it;
	     goo spreads out of it like from goo. Needs a Goo goal (and some goo).
	  d  pumpkin basket: not a cell (pieces fall past it); a match next to it or
	     a blast on it drops a pumpkin into the cell below. Needs a Pumpkins goal,
	     and then pumpkins come only from baskets, not from refills.
	  1 2 3  hay bale with that many layers

	Fences sit outside the layout too, as `fences = { { x, y, "r" | "d" } }`: a
	fence on the edge right of (x, y) ("r") or below it ("d"). Nothing swaps
	across a fence; only blasts break it (the Fences goal). "R" or "D" makes it
	a hedge instead: the same, but nothing breaks it (and it isn't a goal).

	Portals sit outside the layout, as `portals = { { from = { x, y }, to = { x, y } } }`:
	pieces falling out of `from` land in `to` instead of the cell below.

	Difficulty: every 5th level is Tough, and every 10th from level 20 is
	Super Tough. Levels 6 onwards come from tools/levelgen.luau, with moves
	tuned by the test bot; the level editor (Studio) is for hand changes.
	Rewards are first-pass placeholders until the economy thread sets them.
]]

local Tiles = require(script.Parent.Tiles)

local Levels = {}

Levels.SETS = { "Set01", "Set02", "Set03", "Set04", "Set05", "Set06", "Set07", "Set08", "Set09", "Set10", "Set11", "Set12", "Set13", "Set14", "Set15", "Set16", "Set17", "Set18", "Set19", "Set20", "Set21", "Set22", "Set23", "Set24", "Set25", "Set26", "Set27", "Set28", "Set29", "Set30", "Set31", "Set32", "Set33", "Set34", "Set35", "Set36", "Set37", "Set38", "Set39", "Set40", "Set41", "Set42", "Set43", "Set44", "Set45", "Set46", "Set47", "Set48", "Set49", "Set50", "Set51", "Set52" }

Levels.List = {}
for _, setName in Levels.SETS do
	for _, level in require(script[setName]) do
		table.insert(Levels.List, level)
	end
end

Levels.PER_SET = 25

-- The set module a level id belongs in ("Set01" for 1..25, and so on).
function Levels.setFor(id: number): string
	return string.format("Set%02d", math.ceil(id / Levels.PER_SET))
end

Levels.ById = {}
for _, level in Levels.List do
	Levels.ById[level.id] = level
end

function Levels.get(id: number)
	return Levels.ById[id]
end

-- Layout characters that aren't cells.
local HOLES = { ["#"] = true, d = true, h = true, G = true }

local VALID_CHARS = {
	["."] = true,
	["#"] = true,
	d = true,
	b = true,
	n = true,
	r = true,
	e = true,
	t = true,
	g = true,
	G = true,
	h = true,
	x = true,
	q = true,
	k = true,
	z = true,
	i = true,
	a = true,
	A = true,
	l = true,
	L = true,
	u = true,
	v = true,
	V = true,
	j = true,
	C = true,
	O = true,
	T = true,
	E = true,
	P = true,
	N = true,
	R = true,
	B = true,
	W = true,
	K = true,
	J = true,
	X = true,
	Z = true,
	Y = true,
	Q = true,
	o = true,
	D = true,
	["^"] = true,
	["&"] = true,
	["$"] = true,
	["="] = true,
	["+"] = true,
	["*"] = true,
	U = true,
	I = true,
	H = true,
	y = true,
	m = true,
	M = true,
	f = true,
	F = true,
	w = true,
	p = true,
	c = true,
	s = true,
	S = true,
	["1"] = true,
	["2"] = true,
	["3"] = true,
}
local DIFFICULTIES = { Normal = true, Tough = true, ["Super Tough"] = true }
Levels.MAX_SIZE = 10

--[[
	Portals must link two different board cells, each cell may be one
	portal's entrance and one portal's exit at most, and falling must never
	loop (following portals and cells below from any cell ends).
]]
-- Checks a level's fences: each one on the edge between two board cells, once.
function Levels.checkFences(level): string?
	local fences = level.fences
	if fences == nil then
		return nil
	end
	if type(fences) ~= "table" then
		return "fences must be a list"
	end
	local layout = level.layout
	local function isCell(x, y)
		local row = layout[y]
		return row ~= nil and type(x) == "number" and x >= 1 and x <= #row and x == math.floor(x) and not HOLES[string.sub(row, x, x)]
	end
	local seen = {}
	for i, f in fences do
		local side = type(f) == "table" and type(f[3]) == "string" and string.lower(f[3])
		if side ~= "r" and side ~= "d" then
			return "fence " .. i .. " must be { x, y, \"r\" or \"d\" } (\"R\" or \"D\" for a hedge)"
		end
		local x, y = f[1], f[2]
		local ox, oy = if side == "r" then x + 1 else x, if side == "d" then (y or 0) + 1 else y
		if not (isCell(x, y) and isCell(ox, oy)) then
			return "fence " .. i .. " must sit between two board cells"
		end
		local key = string.format("%d,%d,%s", x, y, side)
		if seen[key] then
			return "fence " .. i .. " is listed twice"
		end
		seen[key] = true
	end
	return nil
end

function Levels.checkPortals(level): string?
	local portals = level.portals
	if portals == nil then
		return nil
	end
	if type(portals) ~= "table" then
		return "portals must be a list"
	end
	local layout = level.layout
	local function isCell(x, y)
		local row = layout[y]
		return row ~= nil and type(x) == "number" and x >= 1 and x <= #row and x == math.floor(x) and not HOLES[string.sub(row, x, x)]
	end
	local outOf, into = {}, {}
	for i, portal in portals do
		local from, to = type(portal) == "table" and portal.from, type(portal) == "table" and portal.to
		if type(from) ~= "table" or type(to) ~= "table" or not isCell(from[1], from[2]) or not isCell(to[1], to[2]) then
			return "portal " .. i .. " must link two board cells"
		end
		local a, b = from[1] .. "," .. from[2], to[1] .. "," .. to[2]
		if a == b then
			return "portal " .. i .. " goes nowhere"
		end
		if outOf[a] or into[b] then
			return "portal " .. i .. " shares an entrance or exit with another"
		end
		outOf[a] = to
		into[b] = from
	end
	-- Where a piece falls from (x, y), as Board.cellBelow does it.
	local function below(x, y)
		local target = outOf[x .. "," .. y]
		if target then
			return target[1], target[2]
		end
		for yy = y + 1, #layout do
			if isCell(x, yy) then
				local feeder = into[x .. "," .. yy]
				if feeder and (feeder[1] ~= x or feeder[2] ~= y) then
					return nil
				end
				return x, yy
			end
		end
		return nil
	end
	local cells = #layout * #layout[1]
	for y = 1, #layout do
		for x = 1, #layout[1] do
			if isCell(x, y) then
				local cx, cy = x, y
				for _ = 1, cells + 1 do
					cx, cy = below(cx, cy)
					if not cx then
						break
					end
				end
				if cx then
					return string.format("portals make pieces fall in a loop from %d,%d", x, y)
				end
			end
		end
	end
	return nil
end

-- Returns nil if the level is well-formed, or a message saying what's wrong.
function Levels.validate(level): string?
	if type(level.id) ~= "number" then
		return "id must be a number"
	end
	if not DIFFICULTIES[level.difficulty] then
		return "unknown difficulty " .. tostring(level.difficulty)
	end
	if type(level.moves) ~= "number" or level.moves < 1 then
		return "moves must be at least 1"
	end
	if #level.colors < 3 or #level.colors > Tiles.Count then
		return "levels need 3 to 6 tile colours"
	end
	for _, name in level.colors do
		if not Tiles.ByName[name] then
			return "unknown tile " .. tostring(name)
		end
	end
	local height = #level.layout
	if height < 3 or height > Levels.MAX_SIZE then
		return "layout must be 3 to " .. Levels.MAX_SIZE .. " rows"
	end
	local width = #level.layout[1]
	if width < 3 or width > Levels.MAX_SIZE then
		return "layout must be 3 to " .. Levels.MAX_SIZE .. " columns"
	end
	local mud, bales, frost, weeds, pumpkins, clover, stones, baskets, goo, buried, springs, tarps, webs, quilts, tins, sacks, snowballs, clay, letters, buckets, boxes, hives, trucks, snails, buds, lambs, pens, spots, trays, bins, floods, pumps, packets, burrows, jars, chests, vanes, vines, mist, birds, frames, pots, trees, cages, bushes = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

	for y, row in level.layout do
		if #row ~= width then
			return "layout row " .. y .. " has the wrong width"
		end
		for x = 1, width do
			local ch = string.sub(row, x, x)
			if not VALID_CHARS[ch] then
				return string.format("bad layout character %q at %d,%d", ch, x, y)
			end
			if ch == "m" or ch == "M" then
				mud += 1
			elseif ch == "1" or ch == "2" or ch == "3" then
				bales += 1
			elseif ch == "f" or ch == "F" then
				frost += 1
			elseif ch == "w" then
				weeds += 1
			elseif ch == "c" then
				clover += 1
			elseif ch == "s" or ch == "S" then
				stones += 1
			elseif ch == "h" then
				local below = false
				for yy = y + 1, height do
					below = below or not HOLES[string.sub(level.layout[yy], x, x)]
				end
				if not below then
					return string.format("hen house at %d,%d has no cell below it", x, y)
				end
				if not table.find(level.colors, "Egg") then
					return "hen houses lay eggs: add Egg to the colours"
				end
			elseif ch == "g" or ch == "e" then
				goo += 1
			elseif ch == "b" then
				buried += 1
			elseif ch == "G" then
				springs += 1
			elseif ch == "t" then
				tarps += 1
			elseif ch == "n" then
				webs += 1
			elseif ch == "q" then
				quilts += 1
			elseif ch == "k" then
				tins += 1
			elseif ch == "z" then
				sacks += 1
			elseif ch == "i" then
				snowballs += 1
			elseif ch == "a" or ch == "A" then
				clay += 1
			elseif ch == "l" then
				letters += 1
			elseif ch == "u" then
				buckets += 1
			elseif ch == "v" or ch == "V" then
				boxes += 1
			elseif ch == "j" then
				hives += 1
			elseif ch == "C" then
				trucks += 1
			elseif ch == "O" then
				snails += 1
			elseif ch == "T" then
				buds += 1
			elseif ch == "^" then
				frames += 1
			elseif ch == "&" then
				pots += 1
			elseif ch == "$" then
				trees += 1
			elseif ch == "*" then
				bushes += 1
			elseif ch == "E" then
				lambs += 1
			elseif ch == "P" then
				pens += 1
			elseif ch == "N" then
				spots += 1
			elseif ch == "R" then
				trays += 1
			elseif ch == "B" then
				bins += 1
			elseif ch == "W" then
				floods += 1
			elseif ch == "H" then
				pumps += 1
			elseif ch == "K" then
				packets += 1
			elseif ch == "J" then
				jars += 1
			elseif ch == "X" then
				chests += 1
			elseif ch == "Z" then
				vanes += 1
			elseif ch == "D" then
				birds += 1
			elseif ch == "Y" then
				vines += 1
			elseif ch == "Q" then
				mist += 1
			elseif ch == "I" then
				burrows += 1
			elseif ch == "d" then
				baskets += 1
				local below = false
				for yy = y + 1, height do
					below = below or not HOLES[string.sub(level.layout[yy], x, x)]
				end
				if not below then
					return string.format("basket at %d,%d has no cell below it", x, y)
				end
			elseif ch == "p" then
				pumpkins += 1
				local below = false
				for yy = y + 1, height do
					below = below or not HOLES[string.sub(level.layout[yy], x, x)]
				end
				if not below then
					return string.format("pumpkin at %d,%d is already at the bottom", x, y)
				end
			elseif ch == "o" then
				pumpkins += 1
			end
		end
	end
	local portalError = Levels.checkPortals(level) or Levels.checkFences(level)
	if portalError then
		return portalError
	end
	if #level.goals == 0 then
		return "level needs at least one goal"
	end
	if pumpkins > 0 or baskets > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Pumpkins"
		end
		if not wanted then
			return "pumpkins or baskets in the layout but no pumpkins goal"
		end
	end
	if springs > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Goo"
		end
		if not wanted then
			return "goo springs in the layout but no goo goal"
		end
	end
	if sacks > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Clover"
		end
		if not wanted then
			return "seed sacks in the layout but no clover goal"
		end
	end
	if trucks > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "HayBale"
		end
		if not wanted then
			return "hay trucks in the layout but no hay bale goal"
		end
	end
	if burrows > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Gophers"
		end
		if not wanted then
			return "gopher burrows in the layout but no gophers goal"
		end
	end
	if mist > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Mist"
		end
		if not wanted then
			return "mist in the layout but no mist goal"
		end
	end
	if vines > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Vines"
		end
		if not wanted then
			return "vines in the layout but no vines goal"
		end
	end
	if birds > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Birds"
		end
		if not wanted then
			return "songbirds in the layout but no birds goal"
		end
	end
	if vanes > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Vanes"
		end
		if not wanted then
			return "weathervanes in the layout but no vanes goal"
		end
	end
	if chests > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Tools"
		end
		if not wanted then
			return "tool chests in the layout but no tools goal"
		end
	end
	if jars > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Jars"
		end
		if not wanted then
			return "jam jars in the layout but no jars goal"
		end
	end
	if packets > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Packets"
		end
		if not wanted then
			return "seed packets in the layout but no packets goal"
		end
	end
	if floods > 0 or pumps > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Floods"
		end
		if not wanted then
			return "flood water or pumps in the layout but no floods goal"
		end
		if floods == 0 or pumps == 0 then
			return "flood water needs a hand pump, and a pump needs flood water"
		end
	end
	if bins > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Bins"
		end
		if not wanted then
			return "compost bins in the layout but no bins goal"
		end
	end
	if trays > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Trays"
		end
		if not wanted then
			return "seed trays in the layout but no trays goal"
		end
	end
	if spots > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Fireflies"
		end
		if not wanted then
			return "firefly spots in the layout but no fireflies goal"
		end
	end
	if lambs > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Lambs"
		end
		if not wanted then
			return "lambs in the layout but no lambs goal"
		end
		if pens == 0 then
			return "lambs in the layout but no pen"
		end
	end
	-- Fruit cages: each connected group of "=" and "+" cells needs a peg.
	do
		local seen = {}
		local function caged(x, y)
			local row = level.layout[y]
			local ch = row and string.sub(row, x, x)
			return ch == "=" or ch == "+"
		end
		for y = 1, height do
			for x = 1, width do
				if caged(x, y) and not seen[y * 1000 + x] then
					cages += 1
					local pegs = 0
					local stack = { { x, y } }
					seen[y * 1000 + x] = true
					while #stack > 0 do
						local c = table.remove(stack)
						if string.sub(level.layout[c[2]], c[1], c[1]) == "+" then
							pegs += 1
						end
						for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
							local nx, ny = c[1] + d[1], c[2] + d[2]
							if caged(nx, ny) and not seen[ny * 1000 + nx] then
								seen[ny * 1000 + nx] = true
								table.insert(stack, { nx, ny })
							end
						end
					end
					if pegs == 0 then
						return string.format("fruit cage at %d,%d has no pegs", x, y)
					end
				end
			end
		end
	end
	if bushes > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Berries"
		end
		if not wanted then
			return "berry bushes in the layout but no berries goal"
		end
	end
	if cages > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Cages"
		end
		if not wanted then
			return "fruit cages in the layout but no cages goal"
		end
	end
	if trees > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Apples"
		end
		if not wanted then
			return "apple trees in the layout but no apples goal"
		end
	end
	if pots > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Pots"
		end
		if not wanted then
			return "stew pots in the layout but no pots goal"
		end
	end
	if frames > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Frames"
		end
		if not wanted then
			return "cold frames in the layout but no frames goal"
		end
	end
	if buds > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Blooms"
		end
		if not wanted then
			return "tulip buds in the layout but no blooms goal"
		end
	end
	if snails > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Goo"
		end
		if not wanted then
			return "snails in the layout but no goo goal"
		end
	end
	if hives > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Honey"
		end
		if not wanted then
			return "beehives in the layout but no honey goal"
		end
	end
	if buckets > 0 then
		local wanted = false
		for _, goal in level.goals do
			wanted = wanted or goal.kind == "Mud"
		end
		if not wanted then
			return "mud buckets in the layout but no mud goal"
		end
	end
	if tins < quilts then
		return "quilts need one sewing tin per quilt cell (" .. quilts .. " cells, " .. tins .. " tins)"
	end
	for _, goal in level.goals do
		if goal.kind == "Collect" then
			if not table.find(level.colors, goal.tile) then
				return "collect goal tile " .. tostring(goal.tile) .. " is not in the level's colours"
			end
			if type(goal.count) ~= "number" or goal.count < 1 then
				return "collect goal needs a count"
			end
		elseif goal.kind == "Mud" then
			if mud == 0 and buckets == 0 then
				return "mud goal but no mud or mud buckets in the layout"
			end
		elseif goal.kind == "HayBale" then
			if bales == 0 and trucks == 0 then
				return "hay bale goal but no bales or hay trucks in the layout"
			end
		elseif goal.kind == "Frost" then
			if frost == 0 then
				return "frost goal but no frost in the layout"
			end
		elseif goal.kind == "Weeds" then
			if weeds == 0 then
				return "weeds goal but no weeds in the layout"
			end
		elseif goal.kind == "Stones" then
			if stones == 0 then
				return "stones goal but no stone walls in the layout"
			end
		elseif goal.kind == "Goo" then
			if goo == 0 then
				return "goo goal but no goo in the layout"
			end
		elseif goal.kind == "Webs" then
			if webs == 0 then
				return "webs goal but no webs in the layout"
			end
		elseif goal.kind == "Honey" then
			if hives == 0 then
				return "honey goal but no beehives in the layout"
			end
			if type(goal.count) ~= "number" or goal.count < 1 then
				return "honey goal needs a count"
			end
		elseif goal.kind == "Gophers" then
			if burrows < 2 then
				return "gophers goal needs at least 2 burrows to hop between"
			end
		elseif goal.kind == "Mist" then
			if mist == 0 then
				return "mist goal but no mist in the layout"
			end
		elseif goal.kind == "Vines" then
			if vines == 0 then
				return "vines goal but no vines in the layout"
			end
		elseif goal.kind == "Birds" then
			if birds == 0 then
				return "birds goal but no songbirds in the layout"
			end
		elseif goal.kind == "Vanes" then
			if vanes == 0 then
				return "vanes goal but no weathervanes in the layout"
			end
		elseif goal.kind == "Tools" then
			if chests == 0 then
				return "tools goal but no tool chests in the layout"
			end
		elseif goal.kind == "Jars" then
			if jars == 0 then
				return "jars goal but no jam jars in the layout"
			end
		elseif goal.kind == "Packets" then
			if packets == 0 then
				return "packets goal but no seed packets in the layout"
			end
		elseif goal.kind == "Floods" then
			if floods == 0 then
				return "floods goal but no flood water in the layout"
			end
		elseif goal.kind == "Bins" then
			if bins == 0 then
				return "bins goal but no compost bins in the layout"
			end
		elseif goal.kind == "Trays" then
			if trays == 0 then
				return "trays goal but no seed trays in the layout"
			end
		elseif goal.kind == "Fireflies" then
			if spots == 0 then
				return "fireflies goal but no firefly spots in the layout"
			end
			if type(goal.count) ~= "number" or goal.count < 1 then
				return "fireflies goal needs a count"
			end
		elseif goal.kind == "Lambs" then
			if lambs == 0 then
				return "lambs goal but no lambs in the layout"
			end
		elseif goal.kind == "Berries" then
			if bushes == 0 then
				return "berries goal but no berry bushes in the layout"
			end
			if type(goal.count) ~= "number" or goal.count < 1 then
				return "berries goal needs a count"
			end
		elseif goal.kind == "Cages" then
			if cages == 0 then
				return "cages goal but no fruit cages in the layout"
			end
		elseif goal.kind == "Apples" then
			if trees == 0 then
				return "apples goal but no apple trees in the layout"
			end
		elseif goal.kind == "Pots" then
			if pots == 0 then
				return "pots goal but no stew pots in the layout"
			end
		elseif goal.kind == "Frames" then
			if frames == 0 then
				return "frames goal but no cold frames in the layout"
			end
		elseif goal.kind == "Blooms" then
			if buds == 0 then
				return "blooms goal but no tulip buds in the layout"
			end
		elseif goal.kind == "Boxes" then
			if boxes == 0 then
				return "boxes goal but no produce box stacks in the layout"
			end
		elseif goal.kind == "Letters" then
			if letters == 0 then
				return "letters goal but no mailbox with a letter in the layout"
			end
		elseif goal.kind == "Clay" then
			if clay == 0 then
				return "clay goal but no clay in the layout"
			end
		elseif goal.kind == "Snowballs" then
			if snowballs == 0 then
				return "snowballs goal but no snowballs in the layout"
			end
		elseif goal.kind == "Quilts" then
			if quilts == 0 then
				return "quilts goal but no quilts in the layout"
			end
		elseif goal.kind == "Tarps" then
			if tarps == 0 then
				return "tarps goal but no tarps in the layout"
			end
		elseif goal.kind == "Statues" then
			if buried == 0 then
				return "statues goal but no buried statues in the layout"
			end
		elseif goal.kind == "Fences" then
			local breakable = false
			for _, f in level.fences or {} do
				breakable = breakable or f[3] == "r" or f[3] == "d"
			end
			if not breakable then
				return "fences goal but no fences (hedges don't count)"
			end
		elseif goal.kind == "Clover" then
			if clover == 0 and sacks == 0 then
				return "clover goal but no clover or seed sacks in the layout"
			end
		elseif goal.kind == "Pumpkins" then
			if type(goal.count) ~= "number" or goal.count < math.max(1, pumpkins) then
				return "pumpkins goal needs a count of at least the pumpkins in the layout"
			end
		else
			return "unknown goal kind " .. tostring(goal.kind)
		end
	end
	return nil
end

return Levels
