--[[
	Crop Pop levels: the shared API. The level data lives in the Set modules
	next to this one, 25 levels each, in play order.

	Layout characters:
	  .  plain cell          #  hole (not part of the board)
	  m  mud, 1 layer        M  mud, 2 layers
	  f  frost, 1 layer      F  frost, 2 layers (the tile is frozen in place)
	  w  weed (spreads when a swap pulls none)
	  1 2 3  hay bale with that many layers

	Difficulty: every 5th level is Tough, and every 10th from level 20 is
	Super Tough. Levels 6 onwards come from tools/levelgen.luau, with moves
	tuned by the test bot; the level editor (Studio) is for hand changes.
	Rewards are first-pass placeholders until the economy thread sets them.
]]

local Tiles = require(script.Parent.Tiles)

local Levels = {}

Levels.SETS = { "Set01", "Set02", "Set03", "Set04" }

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

local VALID_CHARS = {
	["."] = true,
	["#"] = true,
	m = true,
	M = true,
	f = true,
	F = true,
	w = true,
	["1"] = true,
	["2"] = true,
	["3"] = true,
}
local DIFFICULTIES = { Normal = true, Tough = true, ["Super Tough"] = true }
Levels.MAX_SIZE = 10

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
	local mud, bales, frost, weeds = 0, 0, 0, 0
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
			end
		end
	end
	if #level.goals == 0 then
		return "level needs at least one goal"
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
		else
			return "unknown goal kind " .. tostring(goal.kind)
		end
	end
	return nil
end

return Levels
