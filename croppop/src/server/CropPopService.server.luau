--[[
	Crop Pop server: hands out level seeds, checks finished runs by replay,
	and keeps Hearts and boosters.

	Remotes (created in ReplicatedStorage.CropPopRemotes):
	  GetProgress()                       -> progress (see RunStore.getProgress)
	  StartLevel(levelId, preBoosters?)   -> { token, levelId, seed, startPowerUps, progress } | { error }
	  FinishLevel(token, actions)         -> { won, levelId, rewards?, firstWin?, progress } | { error }
	  BuyHearts(packIndex)                -> progress | { error }
	  BuyBooster(kind)                    -> progress | { error }
	  BuyContinue(token, actions)         -> { continues, progress } | { error }   (+5 moves once out of moves)

	Farm hooks in ServerStorage:
	  CropPopLevelWon (BindableEvent, fired)     (player, levelId, rewards, firstWin) after a verified win
	  CropPopLoadSave (BindableFunction, ours)   (player, puzzleBlock?) once the farm profile loads
	  CropPopGetSave  (BindableFunction, ours)   (player) -> puzzleBlock, for the farm's saves
	  CropPopSpendGems (BindableFunction, farm's) (player, amount, reason) -> boolean
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local RunStore = require(script.Parent.RunStore)

local SAVE_WAIT_SECONDS = 10 -- play with a fresh state if the farm hasn't loaded a save by then
local FORGET_DELAY = 15 -- keep state readable for the farm's final save on leave

local function spendGems(userId: number, amount: number, reason: string): boolean
	local spend = ServerStorage:FindFirstChild("CropPopSpendGems")
	local player = Players:GetPlayerByUserId(userId)
	if not spend or not player then
		return false
	end
	local ok, charged = pcall(function()
		return (spend :: BindableFunction):Invoke(player, amount, reason)
	end)
	return ok and charged == true
end

local random = Random.new()
local store = RunStore.new({
	clock = os.clock,
	now = os.time,
	newSeed = function()
		return random:NextInteger(1, 2 ^ 31 - 1)
	end,
	spendGems = spendGems,
	-- In Studio every test level is open; live servers follow the Crop Pop Trail order.
	unlockAll = RunService:IsStudio(),
	devActions = RunService:IsStudio(), -- the "Dev: 1 move" button
	autoLoad = false,
})

local remotes = Instance.new("Folder")
remotes.Name = "CropPopRemotes"

local function remote(name: string, handler)
	local fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.OnServerInvoke = handler
	fn.Parent = remotes
end

local function reply(result, err)
	if result == nil then
		return { error = err }
	end
	return result
end

local levelWon = Instance.new("BindableEvent")
levelWon.Name = "CropPopLevelWon"
levelWon.Parent = ServerStorage

local loadSave = Instance.new("BindableFunction")
loadSave.Name = "CropPopLoadSave"
loadSave.OnInvoke = function(player, block)
	store:importSave(player.UserId, block)
	return true
end
loadSave.Parent = ServerStorage

local getSave = Instance.new("BindableFunction")
getSave.Name = "CropPopGetSave"
getSave.OnInvoke = function(player)
	return store:exportSave(player.UserId)
end
getSave.Parent = ServerStorage

remote("GetProgress", function(player)
	local progress = store:getProgress(player.UserId)
	progress.unlockAll = store.unlockAll
	return progress
end)

remote("StartLevel", function(player, levelId, preBoosters)
	return reply(store:start(player.UserId, levelId, preBoosters))
end)

remote("FinishLevel", function(player, token, moves)
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
end)

remote("BuyHearts", function(player, packIndex)
	return reply(store:buyHearts(player.UserId, packIndex))
end)

remote("BuyBooster", function(player, kind)
	return reply(store:buyBooster(player.UserId, kind))
end)

remote("BuyContinue", function(player, token, moves)
	local ok, result, err = pcall(store.buyContinue, store, player.UserId, token, moves)
	if not ok then
		warn("[CropPop] continue replay failed for", player.Name, result)
		return { error = "server error" }
	end
	return reply(result, err)
end)

local function onPlayerAdded(player: Player)
	local userId = player.UserId
	task.delay(SAVE_WAIT_SECONDS, function()
		if player.Parent and not store:getProgress(userId).loaded then
			store:markLoaded(userId)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	task.delay(FORGET_DELAY, function()
		if not Players:GetPlayerByUserId(userId) then
			store:forget(userId)
		end
	end)
end)

remotes.Parent = ReplicatedStorage
