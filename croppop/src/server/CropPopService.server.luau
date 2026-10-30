--[[
	Crop Pop server: hands out level seeds, checks finished runs by replay,
	and keeps Hearts and boosters.

	Remotes (created in ReplicatedStorage.CropPopRemotes):
	  GetProgress()                       -> progress (see RunStore.getProgress)
	  StartLevel(levelId, preBoosters?)   -> { token, levelId, seed, startPowerUps, progress } | { error }
	  FinishLevel(token, actions)         -> { won, levelId, rewards?, chest?, firstWin?, progress } | { error }
	                                         (rewards.coins includes leftover-move and Trail Chest coins)
	  BuyHearts(packIndex)                -> progress | { error }
	  BuyBooster(kind)                    -> progress | { error }
	  BuyContinue(token, actions)         -> { continues, progress } | { error }   (+5 moves once out of moves)
	  ClaimHeartGifts()                   -> { claimed, from, progress } | { error }  (neighbors' hearts into empty ones)

	Farm hooks in ServerStorage:
	  CropPopLevelWon (BindableEvent, fired)     (player, levelId, rewards, firstWin) after a verified win
	  CropPopLoadSave (BindableFunction, ours)   (player, puzzleBlock?) once the farm profile loads
	  CropPopGetSave  (BindableFunction, ours)   (player) -> puzzleBlock, for the farm's saves
	  CropPopSpendGems (BindableFunction, farm's) (player, amount, reason) -> boolean
	  CropPopGetGems   (BindableFunction, farm's, optional) (player) -> number, for "Not enough 💎" states

	Neighbor hooks in ServerStorage (the caller checks the two are neighbors):
	  CropPopGiftHeart       (BindableFunction, ours) (fromPlayer, toUserId) -> (ok, message?)
	                           one heart into their gift box; message is for the sender
	  CropPopHeartGiftStatus (BindableFunction, ours) (player) -> { sentTo = { userId }, left, perDay }

	Gift boxes live in the CropPopHeartGifts DataStore so they reach players who
	are offline or on another server; Studio keeps them in memory.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local GiftInbox = require(script.Parent.GiftInbox)
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

local function getGems(userId: number): number?
	local hook = ServerStorage:FindFirstChild("CropPopGetGems")
	local player = Players:GetPlayerByUserId(userId)
	if not hook or not player then
		return nil
	end
	local ok, gems = pcall(function()
		return (hook :: BindableFunction):Invoke(player)
	end)
	return if ok and type(gems) == "number" then gems else nil
end

-- Studio keeps gift boxes in memory, so tests never touch real saves.
local function giftInbox()
	if RunService:IsStudio() then
		return GiftInbox.memory()
	end
	local ok, store = pcall(function()
		return game:GetService("DataStoreService"):GetDataStore("CropPopHeartGifts")
	end)
	if not ok then
		warn("[CropPop] no gift box store:", store)
		return GiftInbox.memory()
	end
	return GiftInbox.dataStore(store)
end

local random = Random.new()
local store = RunStore.new({
	clock = os.clock,
	now = os.time,
	newSeed = function()
		return random:NextInteger(1, 2 ^ 31 - 1)
	end,
	spendGems = spendGems,
	getGems = getGems,
	-- In Studio every test level is open; live servers follow the Crop Pop Trail order.
	unlockAll = RunService:IsStudio(),
	devActions = RunService:IsStudio(), -- the "Dev: 1 move" button
	autoLoad = false,
	giftInbox = giftInbox(),
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
	store:refreshGifts(player.UserId)
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

remote("ClaimHeartGifts", function(player)
	return reply(store:claimGifts(player.UserId))
end)

-- What the sender sees when a gift doesn't go.
local GIFT_MESSAGES = {
	["already sent today"] = "You already sent them a heart today.",
	["no gifts left today"] = "You've sent all your hearts for today.",
	["their gift box is full"] = "Their gift box is full.",
	["that's you"] = "You can't send a heart to yourself.",
	["loading"] = "Still loading, try again in a moment.",
}

local giftHeart = Instance.new("BindableFunction")
giftHeart.Name = "CropPopGiftHeart"
giftHeart.OnInvoke = function(fromPlayer, toUserId)
	local ok, result, err = pcall(store.sendHeart, store, fromPlayer.UserId, toUserId)
	if not ok then
		warn("[CropPop] heart gift failed for", fromPlayer.Name, result)
		return false, "Couldn't send the heart, try again later."
	end
	if not result then
		return false, GIFT_MESSAGES[err] or "Couldn't send the heart, try again later."
	end
	return true, string.format("Heart sent! %d left today.", result.left)
end
giftHeart.Parent = ServerStorage

local giftStatus = Instance.new("BindableFunction")
giftStatus.Name = "CropPopHeartGiftStatus"
giftStatus.OnInvoke = function(player)
	return store:giftStatus(player.UserId)
end
giftStatus.Parent = ServerStorage

-- Studio only: empty the hearts so the refill offer can be checked quickly.
if RunService:IsStudio() then
	remote("DevEmptyHearts", function(player)
		return reply(store:devSetHearts(player.UserId, 0))
	end)
	remote("DevAddBoosters", function(player, count)
		return reply(store:devAddBoosters(player.UserId, if type(count) == "number" then math.clamp(count, 1, 10) else 5))
	end)
	remote("DevGiftHeart", function(player)
		return reply(store:devGiftSelf(player.UserId))
	end)
end

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
