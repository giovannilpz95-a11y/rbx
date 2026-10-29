--[[
	Server-side replay check for Crop Pop.

	The server picks the seed when a level starts. When the client finishes, it
	sends the list of swaps it made; the server replays them with the same seed
	and only pays out if the replay wins within the move limit. Because the
	engine is deterministic, an honest client always matches.

	Each action is a swap { x1, y1, x2, y2 }, an in-level booster such as
	{ "Trowel", x, y }, or a paid continue { "Continue" } after running out of
	moves (see Engine.apply). The server checks the player owns the boosters
	and paid for the continues the replay used.
]]

local Boosters = require(script.Parent.Boosters)
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
	boostersUsed: { [string]: number }?,
	continues: number?, -- paid continues the replay took
	status: string?, -- the engine's status at the end: "Playing" | "Won" | "Lost"
}

local function isCoord(v): boolean
	return type(v) == "number" and v == math.floor(v) and v >= 1 and v <= Levels.MAX_SIZE
end

-- Checks the shape of untrusted input from a RemoteFunction. Returns a clean copy.
-- `allowDev` (Studio only) also accepts the { "DevOneMove" } test action.
function Replay.sanitize(raw: any, allowDev: boolean?): ({ { any } }?, string?)
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
		if type(m) ~= "table" then
			return nil, "bad move at " .. i
		end
		if m[1] == "Continue" then
			clean[i] = { "Continue" }
		elseif m[1] == "DevOneMove" and allowDev then
			clean[i] = { "DevOneMove" }
		elseif type(m[1]) == "string" then
			local info = Boosters.Info[m[1]]
			if not info or info.when ~= "in" then
				return nil, "bad booster at " .. i
			end
			local action = { m[1] }
			for k = 1, info.args do
				if not isCoord(m[k + 1]) then
					return nil, "bad booster at " .. i
				end
				action[k + 1] = m[k + 1]
			end
			clean[i] = action
		elseif isCoord(m[1]) and isCoord(m[2]) and isCoord(m[3]) and isCoord(m[4]) then
			clean[i] = { m[1], m[2], m[3], m[4] }
		else
			return nil, "bad move at " .. i
		end
	end
	return clean, nil
end

function Replay.run(level, seed: number, moves: { { any } }, options: Engine.Options?): Result
	local game = Engine.new(level, seed, options)
	for i, m in moves do
		-- A continue is the one action allowed after running out of moves.
		if game.status ~= "Playing" and not (m[1] == "Continue" and game.status == "Lost") then
			return { ok = false, won = false, reason = "move " .. i .. " after the level ended", movesUsed = i - 1 }
		end
		local ok = game:apply(m)
		if not ok then
			return { ok = false, won = false, reason = "illegal action at move " .. i, movesUsed = i - 1 }
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
		boostersUsed = game.boostersUsed,
		continues = game.continues,
		status = game.status,
	}
end

return Replay
