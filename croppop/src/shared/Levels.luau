--[[
	Crop Pop test levels (original layouts, first-pass tuning).

	Layout characters:
	  .  plain cell          #  hole (not part of the board)
	  m  mud, 1 layer        M  mud, 2 layers
	  1 2 3  hay bale with that many layers

	Rewards are first-pass placeholders until the economy thread sets them.
	The real ~100 levels will come from the Studio level editor (P2).
]]

local Tiles = require(script.Parent.Tiles)

local Levels = {}

Levels.List = {
	{
		id = 1,
		name = "Sunny Start",
		difficulty = "Normal",
		moves = 18,
		colors = { "Tomato", "Egg", "Carrot", "Corn", "Milk" },
		layout = {
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
			".......",
		},
		goals = {
			{ kind = "Collect", tile = "Tomato", count = 12 },
			{ kind = "Collect", tile = "Carrot", count = 12 },
		},
		rewards = { coins = 20, xp = 4 },
	},
	{
		id = 2,
		name = "Muddy Furrows",
		difficulty = "Normal",
		moves = 22,
		colors = { "Tomato", "Egg", "Carrot", "Corn", "Wool" },
		layout = {
			"........",
			".mmmmmm.",
			"........",
			".mmmmmm.",
			"........",
			".mmmmmm.",
			"........",
			"........",
		},
		goals = {
			{ kind = "Mud" },
		},
		rewards = { coins = 25, xp = 5 },
	},
	{
		id = 3,
		name = "Bale Fence",
		difficulty = "Normal",
		moves = 24,
		colors = { "Egg", "Carrot", "Corn", "Milk", "Wool" },
		layout = {
			"........",
			"........",
			"........",
			"111..111",
			"........",
			"........",
			"2......2",
			"22....22",
		},
		goals = {
			{ kind = "HayBale" },
		},
		rewards = { coins = 25, xp = 5 },
	},
	{
		id = 4,
		name = "Corn Maze",
		difficulty = "Normal",
		moves = 25,
		colors = { "Tomato", "Egg", "Carrot", "Corn", "Milk", "Wool" },
		layout = {
			"##.....##",
			"#.......#",
			".........",
			"....#....",
			"...###...",
			"....#....",
			".........",
			"#.......#",
			"##.....##",
		},
		goals = {
			{ kind = "Collect", tile = "Corn", count = 25 },
			{ kind = "Collect", tile = "Egg", count = 20 },
		},
		rewards = { coins = 30, xp = 6 },
	},
	{
		id = 5,
		name = "Harvest Mix",
		difficulty = "Tough",
		moves = 28,
		colors = { "Tomato", "Egg", "Carrot", "Corn", "Wool" },
		layout = {
			"#......#",
			"..mmmm..",
			".m2..2m.",
			".m....m.",
			".m....m.",
			".m2..2m.",
			"..mmmm..",
			"#......#",
		},
		goals = {
			{ kind = "Mud" },
			{ kind = "HayBale" },
			{ kind = "Collect", tile = "Wool", count = 15 },
		},
		rewards = { coins = 50, xp = 10 },
	},
}

Levels.ById = {}
for _, level in Levels.List do
	Levels.ById[level.id] = level
end

function Levels.get(id: number)
	return Levels.ById[id]
end

local VALID_CHARS = { ["."] = true, ["#"] = true, m = true, M = true, ["1"] = true, ["2"] = true, ["3"] = true }
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
	local mud, bales = 0, 0
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
		else
			return "unknown goal kind " .. tostring(goal.kind)
		end
	end
	return nil
end

return Levels
