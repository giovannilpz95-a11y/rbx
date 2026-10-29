--[[
	Server-side replay check for Crop Pop.

	The server picks the seed when a level starts. When the client finishes, it
	sends the list of swaps it made; the server replays them with the same seed
	and only pays out if the replay wins within the move limit. Because the
	engine is deterministic, an honest client always matches.

	A move is { x1, y1, x2, y2 }. Paid continues (P2) will add a marker entry.
]]

local Engine = require(script.Parent.Engine)
local Levels = require(script.Parent.Levels)

local Replay = {}

Replay.MAX_MOVES = 200

export type Result = {
	ok: boolean, -- the move list was well-formed and every swap was legal
	won: boolean,
	reason: string?,
	movesUsed: number,
	hash: string?,
	stats: any?,
	bonusCoins: number?, -- from leftover moves on a win
}

local function isCoord(v): boolean
	return type(v) == "number" and v == math.floor(v) and v >= 1 and v <= Levels.MAX_SIZE
end

-- Checks the shape of untrusted input from a RemoteFunction. Returns a clean copy.
function Replay.sanitize(raw: any): ({ { number } }?, string?)
	if type(raw) ~= "table" then
		return nil, "moves must be a list"
	end
	local count = #raw
	if count > Replay.MAX_MOVES then
		return nil, "too many moves"
	end
	local clean = table.create(count)
	for i = 1, count do
		local m = raw[i]
		if type(m) ~= "table" or not (isCoord(m[1]) and isCoord(m[2]) and isCoord(m[3]) and isCoord(m[4])) then
			return nil, "bad move at " .. i
		end
		clean[i] = { m[1], m[2], m[3], m[4] }
	end
	return clean, nil
end

function Replay.run(level, seed: number, moves: { { number } }, options: Engine.Options?): Result
	local game = Engine.new(level, seed, options)
	for i, m in moves do
		if game.status ~= "Playing" then
			return { ok = false, won = false, reason = "move " .. i .. " after the level ended", movesUsed = i - 1 }
		end
		local ok = game:trySwap(m[1], m[2], m[3], m[4])
		if not ok then
			return { ok = false, won = false, reason = "illegal swap at move " .. i, movesUsed = i - 1 }
		end
	end
	return {
		ok = true,
		won = game.status == "Won",
		reason = if game.status == "Won" then nil else "goals not reached",
		movesUsed = #moves,
		hash = game:hash(),
		stats = game.stats,
		bonusCoins = if game.bonus then game.bonus.coins else 0,
	}
end

return Replay
