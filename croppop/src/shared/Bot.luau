--[[
	A simple test player for tuning levels. It plays a level on many seeds
	and reports how often it wins. Its moves are random, but it prefers
	setting off power-ups, matching under a pumpkin and matching on clover
	that still has bare cells to spread to, so its win rate is a
	rough lower bound on a person's. Use it to compare levels, not as the
	final word on difficulty.
]]

local Engine = require(script.Parent.Engine)
local Matcher = require(script.Parent.Matcher)
local Rng = require(script.Parent.Rng)

local Bot = {}

export type Report = {
	games: number,
	wins: number,
	winRate: number,
	avgMovesLeft: number, -- on wins
	avgGoalShare: number, -- on losses: how much of the goals it got done (0..1)
}

local function goalShare(pop): number
	local done, total = 0, 0
	for _, goal in pop.goals.list do
		done += math.min(goal.progress, goal.target)
		total += goal.target
	end
	return if total > 0 then done / total else 1
end

-- Moves that touch a cell under a pumpkin (a match there brings it down).
local function underPumpkins(board, moves)
	local lowest = {} -- column -> lowest pumpkin's y
	board:eachCell(function(cell)
		if cell.piece and cell.piece.pumpkin then
			lowest[cell.x] = math.max(lowest[cell.x] or 0, cell.y)
		end
	end)
	if next(lowest) == nil then
		return nil
	end
	local out = {}
	for _, m in moves do
		local underA = lowest[m[1]] and m[2] > lowest[m[1]]
		local underB = lowest[m[3]] and m[4] > lowest[m[3]]
		if underA or underB then
			table.insert(out, m)
		end
	end
	return out
end

-- Moves whose match takes in a clover cell and a bare one (so clover spreads).
local function spreadsClover(board, moves)
	local any, bare = false, false
	board:eachCell(function(cell)
		any = any or cell.clover
		bare = bare or not cell.clover
	end)
	if not (any and bare) then
		return nil
	end
	local out = {}
	for _, m in moves do
		local a, b = board:get(m[1], m[2]), board:get(m[3], m[4])
		a.piece, b.piece = b.piece, a.piece
		local spreads = false
		for _, group in Matcher.findGroups(board, {}) do
			local hasClover, hasBare = false, false
			for _, cell in group.cells do
				hasClover = hasClover or cell.clover
				hasBare = hasBare or not cell.clover
			end
			spreads = spreads or (hasClover and hasBare)
		end
		a.piece, b.piece = b.piece, a.piece
		if spreads then
			table.insert(out, m)
		end
	end
	return out
end

-- Picks a move: a power-up swap if there is one, then one under a pumpkin,
-- otherwise a random move.
local function chooseMove(pop, rng)
	local moves = pop:listPossibleMoves()
	local board = pop.board
	local powered = {}
	for _, m in moves do
		local a, b = board:get(m[1], m[2]), board:get(m[3], m[4])
		if (a.piece and a.piece.power) or (b.piece and b.piece.power) then
			table.insert(powered, m)
		end
	end
	if #powered > 0 and rng:int(1, 3) > 1 then
		return rng:pick(powered)
	end
	-- Only on boards with pumpkins, so other levels' tuning stays the same.
	local pumpkinMoves = underPumpkins(board, moves)
	if pumpkinMoves and #pumpkinMoves > 0 and rng:int(1, 3) > 1 then
		return rng:pick(pumpkinMoves)
	end
	local cloverMoves = spreadsClover(board, moves)
	if cloverMoves and #cloverMoves > 0 and rng:int(1, 3) > 1 then
		return rng:pick(cloverMoves)
	end
	return rng:pick(moves)
end

function Bot.play(level, games: number?, firstSeed: number?): Report
	games = games or 50
	local rng = Rng.new(firstSeed or 1)
	local wins, movesLeft, share = 0, 0, 0
	for _ = 1, games :: number do
		local pop = Engine.new(level, rng:int(1, 2 ^ 31 - 1))
		while pop.status == "Playing" and #pop:listPossibleMoves() > 0 do
			local m = chooseMove(pop, rng)
			pop:trySwap(m[1], m[2], m[3], m[4])
		end
		if pop.status == "Won" then
			wins += 1
			movesLeft += if pop.bonus then pop.bonus.moves else pop.movesLeft
		else
			share += goalShare(pop)
		end
	end
	local losses = (games :: number) - wins
	return {
		games = games :: number,
		wins = wins,
		winRate = wins / (games :: number),
		avgMovesLeft = if wins > 0 then movesLeft / wins else 0,
		avgGoalShare = if losses > 0 then share / losses else 1,
	}
end

return Bot
