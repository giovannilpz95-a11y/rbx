--!strict
-- Glue between the farm and Crop Pop (croppop/), both server-side, through ServerStorage:
--   * CropPopLevelWon (BindableEvent, theirs): (player, levelId, rewards, firstWin) after the
--     replay check; rewards = { coins, xp } are paid through EconomyService.
--   * CropPopLoadSave / CropPopGetSave (BindableFunctions, theirs): Crop Pop's save block
--     (Hearts, boosters, progress) lives in the farm profile as `puzzle`. We hand it over
--     once the profile loads and copy it back before every save.
--   * CropPopGetGems (BindableFunction, ours): (player) -> number, the current Gem balance
--     (0 while the farm is still loading), so buy buttons can show "not enough" up front.
--   * CropPopSpendGems (BindableFunction, ours): (player, amount, reason) -> boolean, so
--     Hearts and boosters are paid from the one Gem wallet.
-- Amounts are still checked so a bad payload can't mint or drain currency.

local ServerStorage = game:GetService("ServerStorage")

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)

local CropPopBridge = {}

local MAX_REWARD = 10000
local MAX_GEM_SPEND = 1000
local FIND_TIMEOUT = 8 -- Crop Pop starts a fresh run if it hears nothing within 10 s

-- Players whose saved block Crop Pop has accepted. Until then its live state may be a
-- fresh default, which must never overwrite their real save.
local handedOver: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local saveHooked = false

local function amount(value: any, max: number): number
	if type(value) ~= "number" or value ~= value or value < 0 or value > max then
		return 0
	end
	return math.floor(value)
end

local function isPlayer(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player")
end

local function onLevelWon(player: Player, levelId: any, rewards: any, _firstWin: any)
	if not isPlayer(player) or type(rewards) ~= "table" or DataService.get(player) == nil then
		return
	end
	local coins, xp = amount(rewards.coins, MAX_REWARD), amount(rewards.xp, MAX_REWARD)
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

local function spendGems(player: any, gems: any, reason: any): boolean
	if not isPlayer(player) or DataService.get(player) == nil then
		return false
	end
	local cost = amount(gems, MAX_GEM_SPEND)
	if cost < 1 or cost ~= gems then
		return false
	end
	local tag = if type(reason) == "string" then reason:sub(1, 64) else "CropPop"
	if not EconomyService.spend(player, "Gems", cost, tag) then
		return false
	end
	DataService.markDirty(player, true)
	NetService.pushState(player)
	return true
end

local function hookSave(getSave: BindableFunction)
	if saveHooked then
		return
	end
	saveHooked = true
	DataService.onBeforeSave(function(player, data)
		if not handedOver[player] then
			return
		end
		local block = getSave:Invoke(player)
		if type(block) == "table" then
			data.puzzle = block
		end
	end)
end

-- Called by Main once the player's profile has loaded.
function CropPopBridge.playerLoaded(player: Player)
	task.spawn(function()
		local loadSave = ServerStorage:WaitForChild("CropPopLoadSave", FIND_TIMEOUT)
		local data = DataService.get(player)
		if loadSave == nil or not loadSave:IsA("BindableFunction") or data == nil then
			return
		end
		local ok, err = pcall(function()
			(loadSave :: BindableFunction):Invoke(player, data.puzzle)
		end)
		if ok then
			handedOver[player] = true
		else
			warn("[CropPopBridge] CropPopLoadSave failed:", err)
		end
	end)
end

local function onChild(child: Instance)
	if child.Name == "CropPopLevelWon" and child:IsA("BindableEvent") then
		child.Event:Connect(onLevelWon)
	elseif child.Name == "CropPopGetSave" and child:IsA("BindableFunction") then
		hookSave(child)
	end
end

function CropPopBridge.init()
	local spend = Instance.new("BindableFunction")
	spend.Name = "CropPopSpendGems"
	spend.OnInvoke = spendGems
	spend.Parent = ServerStorage

	local balance = Instance.new("BindableFunction")
	balance.Name = "CropPopGetGems"
	balance.OnInvoke = function(player: any): number
		local data = if isPlayer(player) then DataService.get(player) else nil
		return if data then data.currencies.Gems else 0
	end
	balance.Parent = ServerStorage

	-- Crop Pop may start before or after us, and may not be in the place at all.
	ServerStorage.ChildAdded:Connect(onChild)
	for _, child in ServerStorage:GetChildren() do
		onChild(child)
	end
end

return CropPopBridge
