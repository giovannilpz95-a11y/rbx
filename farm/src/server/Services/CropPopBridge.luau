--!strict
-- Pays Crop Pop wins into the farm economy. The Crop Pop server (croppop/) fires
-- ServerStorage.CropPopLevelWon(player, levelId, rewards, firstWin) after its replay check;
-- rewards = { coins: number, xp: number }. Both games are server code, but amounts are
-- still checked so a bad payload can't mint currency.

local ServerStorage = game:GetService("ServerStorage")

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)

local CropPopBridge = {}

local EVENT_NAME = "CropPopLevelWon"
local MAX_REWARD = 10000

local function amount(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value > MAX_REWARD then
		return 0
	end
	return math.floor(value)
end

local function onLevelWon(player: Player, levelId: any, rewards: any, _firstWin: any)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(rewards) ~= "table" then
		return
	end
	if DataService.get(player) == nil then
		return
	end
	local coins, xp = amount(rewards.coins), amount(rewards.xp)
	local reason = "croppop_" .. tostring(levelId)
	if coins > 0 then
		EconomyService.add(player, "Coins", coins, reason)
	end
	if xp > 0 then
		EconomyService.add(player, "XP", xp, reason)
	end
	DataService.markDirty(player, true)
	NetService.pushState(player)
end

local function hook(child: Instance)
	if child.Name == EVENT_NAME and child:IsA("BindableEvent") then
		child.Event:Connect(onLevelWon)
	end
end

function CropPopBridge.init()
	-- Crop Pop may start before or after us, and may not be in the place at all.
	ServerStorage.ChildAdded:Connect(hook)
	local existing = ServerStorage:FindFirstChild(EVENT_NAME)
	if existing then
		hook(existing)
	end
end

return CropPopBridge
