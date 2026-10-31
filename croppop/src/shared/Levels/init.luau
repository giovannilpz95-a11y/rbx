--[[
	Crop Pop levels: the shared API. The level data lives in the Set modules
	next to this one, 25 levels each, in play order.

	Layout characters:
	  .  plain cell          #  hole (not part of the board)
	  m  mud, 1 layer        M  mud, 2 layers
	  f  frost, 1 layer      F  frost, 2 layers (the tile is frozen in place)
	  w  weed (spreads when a swap pulls none)
	  p  pumpkin (drop it to the bottom of its column; not on a column's bottom cell)
	  c  clover (matches on it spread it; a Clover goal covers the board)
	  s  stone wall, 1 layer   S  stone wall, 2 layers (only blasts break stone)
	  g  goo over the tile (a match or blast on it clears it; after a swap that
	     clears none, it spreads to a neighbouring tile; covering the board loses)
	  d  pumpkin basket: not a cell (pieces fall past it); a match next to it or
	     a blast on it drops a pumpkin into the cell below. Needs a Pumpkins goal,
	     and then pumpkins come only from baskets, not from refills.
	  1 2 3  hay bale with that many layers

	Fences sit outside the layout too, as `fences = { { x, y, "r" | "d" } }`: a
	fence on the edge right of (x, y) ("r") or below it ("d"). Nothing swaps
	across a fence; only blasts break it (the Fences goal).

	Portals sit outside the layout, as `portals = { { from = { x, y }, to = { x, y } } }`:
	pieces falling out of `from` land in `to` instead of the cell below.

	Difficulty: every 5th level is Tough, and every 10th from level 20 is
	Super Tough. Levels 6 onwards come from tools/levelgen.luau, with moves
	tuned by the test bot; the level editor (Studio) is for hand changes.
	Rewards are first-pass placeholders until the economy thread sets them.
]]

local Tiles = require(script.Parent.Tiles)

local Levels = {}

Levels.SETS = { "Set01", "Set02", "Set03", "Set04", "Set05", "Set06", "Set07", "Set08", "Set09", "Set10", "Set11" }

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
local HOLES = { ["#"] = true, d = true }

local VALID_CHARS = {
	["."] = true,
	["#"] = true,
	d = true,
	g = true,
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
		if type(f) ~= "table" or (f[3] ~= "r" and f[3] ~= "d") then
			return "fence " .. i .. " must be { x, y, \"r\" or \"d\" }"
		end
		local x, y = f[1], f[2]
		local ox, oy = if f[3] == "r" then x + 1 else x, if f[3] == "d" then (y or 0) + 1 else y
		if not (isCell(x, y) and isCell(ox, oy)) then
			return "fence " .. i .. " must sit between two board cells"
		end
		local key = string.format("%d,%d,%s", x, y, f[3])
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
	local mud, bales, frost, weeds, pumpkins, clover, stones, baskets, goo = 0, 0, 0, 0, 0, 0, 0, 0, 0
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
			elseif ch == "g" then
				goo += 1
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
	for _, goal in level.goals do
		if goal.kind == "Collect" then
			if not table.find(level.colors, goal.tile) then
				return "collect goal tile " .. tostring(goal.tile) .. " is not in the level's colours"
			end
			if type(goal.count) ~= "number" or goal.count < 1 then
				return "collect goal needs a count"
			end
		elseif goal.kind == "Mud" then
			if mud == 0 then
				return "mud goal but no mud in the layout"
			end
		elseif goal.kind == "HayBale" then
			if bales == 0 then
				return "hay bale goal but no bales in the layout"
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
		elseif goal.kind == "Fences" then
			if not level.fences or #level.fences == 0 then
				return "fences goal but no fences"
			end
		elseif goal.kind == "Clover" then
			if clover == 0 then
				return "clover goal but no clover in the layout"
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
