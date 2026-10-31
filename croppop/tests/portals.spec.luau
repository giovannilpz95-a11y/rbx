-- Portals: pieces leaving an entrance land in its exit instead of the cell below.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

-- A 4x4 board with a portal from the bottom of column 1 to the top of column 4.
local LAYOUT = { "....", "....", "....", "...." }
local PORTALS = { { from = { 1, 4 }, to = { 4, 1 } } }

test("the board links portal cells and falls through them", function()
	local board = Board.fromLayout(LAYOUT, PORTALS)
	local entrance, exit = board:get(1, 4), board:get(4, 1)
	eq(entrance.portalOut, exit)
	eq(exit.portalIn, entrance)
	eq(board:cellBelow(1, 4), exit, "an entrance falls into its exit")
	eq(board:cellAbove(4, 1), entrance, "an exit is fed by its entrance")
	eq(board:cellBelow(1, 3), entrance, "cells above an entrance fall into it as usual")
	falsy(board:isExit(entrance), "pumpkins don't leave from an entrance")
	truthy(board:isExit(board:get(4, 4)))
end)

test("gravity moves pieces through the portal and doesn't spawn in its exit", function()
	local board = Board.fromLayout(LAYOUT, PORTALS)
	local rng = Rng.new(3)
	board:fillInitial(rng, { 1, 2, 3, 4, 5 })
	-- Empty the top of column 4 and its whole column below; column 1 feeds it.
	local fed = board:get(1, 4).piece
	for y = 1, 4 do
		board:get(4, y).piece = nil
	end
	local moves, spawns = board:applyGravity(rng, { 1, 2, 3, 4, 5 })
	local through = false
	for _, m in moves do
		if m.id == fed.id then
			through = m.fromX == 1 and m.toX == 4
		end
	end
	truthy(through, "column 1's bottom piece came out in column 4")
	for _, sp in spawns do
		truthy(sp.toX ~= 4 or sp.toY ~= 1 or sp.fromX ~= 4, "nothing spawns into the exit from above")
		eq(sp.fromX, sp.toX)
	end
	board:eachCell(function(cell)
		truthy(cell.piece ~= nil, "every cell is filled at " .. cell.x .. "," .. cell.y)
	end)
end)

test("levels check their portals", function()
	local function make(portals)
		local l = Helpers.level({ layout = { "........", "........", "........", "...##...", "........", "........", "........", "........" } })
		l.portals = portals
		return l
	end
	eq(Levels.validate(make({ { from = { 2, 3 }, to = { 7, 5 } } })), nil)
	truthy(Levels.validate(make({ { from = { 4, 4 }, to = { 7, 5 } } })), "entrance on a hole")
	truthy(Levels.validate(make({ { from = { 2, 3 }, to = { 2, 3 } } })), "goes nowhere")
	truthy(Levels.validate(make({ { from = { 2, 3 }, to = { 7, 5 } }, { from = { 2, 3 }, to = { 6, 5 } } })), "two from one cell")
	truthy(Levels.validate(make({ { from = { 2, 8 }, to = { 2, 1 } } })), "a loop down column 2")
	truthy(Levels.validate(make("lots")), "not a list")
	truthy(Levels.validate(make({ { from = { 2 }, to = { 7, 5 } } })), "bad position")
end)

test("a portal level plays and replays the same on the server", function()
	local level = Helpers.level({
		layout = { "........", "........", "........", "########", "........", "........", "........", "........" },
		portals = { { from = { 2, 3 }, to = { 7, 5 } }, { from = { 7, 3 }, to = { 2, 5 } } },
	})
	eq(Levels.validate(level), nil)
	for seed = 1, 5 do
		local live = Engine.new(level, seed)
		local actions = {}
		local rng = Rng.new(seed)
		while live.status == "Playing" and #actions < 30 do
			local m = rng:pick(live:listPossibleMoves())
			live:trySwap(m[1], m[2], m[3], m[4])
			table.insert(actions, m)
		end
		live.board:eachCell(function(cell)
			truthy(cell.piece ~= nil or cell.bale > 0, "no gaps left at " .. cell.x .. "," .. cell.y)
		end)
		local again = Engine.new(level, seed)
		for _, m in actions do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), live:hash())
	end
end)

test("level text writes portals", function()
	local level = Helpers.level({ portals = { { from = { 2, 3 }, to = { 7, 5 } } } })
	local text = CropPop.LevelText.write(level)
	truthy(string.find(text, "portals = {", 1, true), text)
	truthy(string.find(text, "{ from = { 2, 3 }, to = { 7, 5 } },", 1, true), text)
	falsy(string.find(CropPop.LevelText.write(Helpers.level()), "portals", 1, true))
end)
