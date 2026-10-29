--[[
	Crop Pop server: hands out level seeds and checks finished runs by replay.

	Remotes (created in ReplicatedStorage.CropPopRemotes):
	  GetProgress()                 -> { highestBeaten }
	  StartLevel(levelId)           -> { token, levelId, seed } | { error }
	  FinishLevel(token, moves)     -> { won, levelId, rewards?, firstWin? } | { error }

	When a win checks out, ServerStorage.CropPopLevelWon fires with
	(player, levelId, rewards, firstWin) so the farm economy can pay Coins and XP.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local RunStore = require(script.Parent.RunStore)

local random = Random.new()
local store = RunStore.new({
	clock = os.clock,
	newSeed = function()
		return random:NextInteger(1, 2 ^ 31 - 1)
	end,
	-- In Studio every test level is open; live servers follow the Crop Pop Trail order.
	unlockAll = RunService:IsStudio(),
})

local remotes = Instance.new("Folder")
remotes.Name = "CropPopRemotes"

local getProgress = Instance.new("RemoteFunction")
getProgress.Name = "GetProgress"
getProgress.Parent = remotes

local startLevel = Instance.new("RemoteFunction")
startLevel.Name = "StartLevel"
startLevel.Parent = remotes

local finishLevel = Instance.new("RemoteFunction")
finishLevel.Name = "FinishLevel"
finishLevel.Parent = remotes

local levelWon = Instance.new("BindableEvent")
levelWon.Name = "CropPopLevelWon"
levelWon.Parent = ServerStorage

getProgress.OnServerInvoke = function(player)
	local progress = store:getProgress(player.UserId)
	progress.unlockAll = store.unlockAll
	return progress
end

startLevel.OnServerInvoke = function(player, levelId)
	local run, err = store:start(player.UserId, levelId)
	if not run then
		return { error = err }
	end
	return run
end

finishLevel.OnServerInvoke = function(player, token, moves)
	local ok, result, err = pcall(store.finish, store, player.UserId, token, moves)
	if not ok then
		warn("[CropPop] replay failed for", player.Name, result)
		return { error = "server error" }
	end
	if not result then
		warn("[CropPop] rejected run from", player.Name, err)
		return { error = err }
	end
	if result.won then
		levelWon:Fire(player, result.levelId, result.rewards, result.firstWin)
	end
	return result
end

Players.PlayerRemoving:Connect(function(player)
	store:forget(player.UserId)
end)

remotes.Parent = ReplicatedStorage
