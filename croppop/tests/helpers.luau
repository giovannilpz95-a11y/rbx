-- Shared helpers for the Crop Pop specs.

local Engine = CropPop.Engine
local Board = CropPop.Board

local Helpers = {}

local POWER_SUFFIX = {
	r = "SprayerRow",
	c = "SprayerColumn",
	b = "Bumblebee",
	h = "HayBomb",
}

-- A level with sensible defaults; pass fields to override.
function Helpers.level(fields)
	local level = {
		id = 999,
		name = "Test Plot",
		difficulty = "Normal",
		moves = 30,
		colors = { "Tomato", "Egg", "Carrot", "Corn", "Milk" },
		layout = {
			"........",
			"........",
			"........",
			"........",
			"........",
			"........",
			"........",
			"........",
		},
		goals = { { kind = "Collect", tile = "Tomato", count = 999 } },
		rewards = { coins = 0, xp = 0 },
	}
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

--[[
	Overwrites the board from rows of space-separated tokens:
	  1-6   a tile of that colour          1r 2c 3b 1h  that tile as a power-up
	  S     Sunflower                      B1 B2 B3     hay bale
	  W     weed                           1f 2F        frosted tile (1 or 2 layers)
	  x     filler (a 4/5 checkerboard that never matches on its own)
	  #     hole (must also be a hole in the layout)
	Tests use colours 1-3 for the tiles they care about.
]]
function Helpers.setBoard(pop, rows)
	local board = pop.board
	for y, row in rows do
		local x = 0
		for token in string.gmatch(row, "%S+") do
			x += 1
			local cell = board:get(x, y)
			if token == "#" then
				assert(cell == nil, "token # but layout has a cell at " .. x .. "," .. y)
			else
				assert(cell, "no cell at " .. x .. "," .. y)
				cell.bale = 0
				cell.weed = false
				cell.frost = 0
				if token == "x" then
					cell.piece = board:newPiece(if (x + y) % 2 == 0 then 4 else 5)
				elseif token == "S" then
					cell.piece = board:newPiece(0, "Sunflower")
				elseif token == "W" then
					cell.piece = nil
					cell.bale = 1
					cell.weed = true
				elseif string.sub(token, 1, 1) == "B" then
					cell.piece = nil
					cell.bale = tonumber(string.sub(token, 2)) :: number
				else
					local color = tonumber(string.sub(token, 1, 1))
					assert(color, "bad token " .. token)
					local suffix = string.sub(token, 2, 2)
					cell.piece = board:newPiece(color, POWER_SUFFIX[suffix])
					cell.frost = if suffix == "f" then 1 elseif suffix == "F" then 2 else 0
				end
			end
		end
		assert(x == board.width, "row " .. y .. " has " .. x .. " tokens, board is " .. board.width .. " wide")
	end
	assert(#rows == board.height, "expected " .. board.height .. " rows")
end

function Helpers.engine(fields, rows, seed)
	local pop = Engine.new(Helpers.level(fields), seed or 1)
	if rows then
		Helpers.setBoard(pop, rows)
	end
	return pop
end

function Helpers.phase(phases, kind, index)
	local n = 0
	for _, phase in phases do
		if phase.kind == kind then
			n += 1
			if n == (index or 1) then
				return phase
			end
		end
	end
	return nil
end

-- Set of "x,y" keys removed in a Pop phase.
function Helpers.removedAt(pop)
	local set, count = {}, 0
	for _, r in pop.removed do
		set[r.x .. "," .. r.y] = true
		count += 1
	end
	return set, count
end

function Helpers.emptySlots(board)
	local n = 0
	board:eachCell(function(cell)
		if Board.isEmptySlot(cell) then
			n += 1
		end
	end)
	return n
end

return Helpers
