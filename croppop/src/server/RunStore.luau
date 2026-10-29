--[[
	Tracks each player's Crop Pop runs on the server.

	start() hands out a seed for one level; finish() replays the client's moves
	with that seed and only reports a win the replay agrees with. Pure Luau with
	an injectable clock so it can be tested outside Roblox.

	Progress is kept in memory for now. It moves into the `puzzle` save block
	(level, hearts, boosters, streak, beaten levels) with P2.
]]

local CropPop = require(game:GetService("ReplicatedStorage"):WaitForChild("CropPop"))

local RunStore = {}
RunStore.__index = RunStore

local MIN_START_GAP = 1 -- seconds between level starts per player
local MAX_RUN_SECONDS = 2 * 60 * 60

export type Config = {
	clock: () -> number,
	newSeed: () -> number,
	levels: any?, -- defaults to CropPop.Levels
	unlockAll: boolean?, -- Studio testing: skip the "beat the previous level" rule
}

function RunStore.new(config: Config)
	return setmetatable({
		clock = config.clock,
		newSeed = config.newSeed,
		levels = config.levels or CropPop.Levels,
		unlockAll = config.unlockAll == true,
		players = {}, -- userId -> { run, highestBeaten, lastStart, nextToken }
	}, RunStore)
end

function RunStore._player(self, userId: number)
	local record = self.players[userId]
	if not record then
		record = { run = nil, highestBeaten = 0, lastStart = -math.huge, nextToken = 1 }
		self.players[userId] = record
	end
	return record
end

function RunStore.getProgress(self, userId: number)
	return { highestBeaten = self:_player(userId).highestBeaten }
end

-- Loads saved progress (for when the save block exists).
function RunStore.setProgress(self, userId: number, highestBeaten: number)
	self:_player(userId).highestBeaten = highestBeaten
end

function RunStore.isUnlocked(self, userId: number, levelId: number): boolean
	return self.unlockAll or levelId <= self:_player(userId).highestBeaten + 1
end

-- Returns { token, levelId, seed } or nil and a reason.
function RunStore.start(self, userId: number, levelId: any)
	if type(levelId) ~= "number" then
		return nil, "bad level"
	end
	local level = self.levels.get(levelId)
	if not level then
		return nil, "no such level"
	end
	if not self:isUnlocked(userId, levelId) then
		return nil, "level locked"
	end
	local record = self:_player(userId)
	local now = self.clock()
	if now - record.lastStart < MIN_START_GAP then
		return nil, "too fast"
	end
	record.lastStart = now
	local token = record.nextToken
	record.nextToken += 1
	-- Starting a new run abandons any open one (Hearts will charge for that in P2).
	record.run = { token = token, levelId = levelId, seed = self.newSeed(), startedAt = now }
	return { token = token, levelId = levelId, seed = record.run.seed }
end

--[[
	Closes the open run. Returns { won, levelId, rewards?, firstWin? } or nil
	and a reason. The run is closed whatever the outcome, so a move list can
	only be checked once.
]]
function RunStore.finish(self, userId: number, token: any, rawMoves: any)
	local record = self:_player(userId)
	local run = record.run
	if not run or run.token ~= token then
		return nil, "no open run"
	end
	record.run = nil
	if self.clock() - run.startedAt > MAX_RUN_SECONDS then
		return nil, "run expired"
	end
	local moves, err = CropPop.Replay.sanitize(rawMoves)
	if not moves then
		return nil, err
	end
	local level = self.levels.get(run.levelId)
	local result = CropPop.Replay.run(level, run.seed, moves)
	if not result.ok then
		return nil, result.reason
	end
	if not result.won then
		return { won = false, levelId = run.levelId }
	end
	local firstWin = run.levelId > record.highestBeaten
	if firstWin then
		record.highestBeaten = run.levelId
	end
	return {
		won = true,
		levelId = run.levelId,
		rewards = table.clone(level.rewards),
		firstWin = firstWin,
		stats = result.stats,
	}
end

function RunStore.forget(self, userId: number)
	self.players[userId] = nil
end

return RunStore
