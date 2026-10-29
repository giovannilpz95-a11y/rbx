--!strict
-- The ONLY place Coins, Gems and XP change (Design/09 Roblox Architecture §3).
-- XP gains also level the player up and pay the level-up reward.

local AnalyticsService = game:GetService("AnalyticsService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Progression = require(Shared.Progression)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)

local EconomyService = {}

local CURRENCIES = { Coins = true, Gems = true, XP = true }

local function logEconomy(
	player: Player,
	currency: string,
	flow: Enum.AnalyticsEconomyFlowType,
	amount: number,
	balance: number,
	reason: string
)
	if currency == "XP" then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			currency,
			amount,
			balance,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			reason
		)
	end)
end

local function checkLevelUp(player: Player, data: { [string]: any })
	local newLevel = Progression.levelFor(data.currencies.XP)
	while data.level < newLevel do
		data.level += 1
		local coins, gems = Progression.reward(data.level)
		if coins > 0 then
			EconomyService.add(player, "Coins", coins, "levelup")
		end
		if gems > 0 then
			EconomyService.add(player, "Gems", gems, "levelup")
		end
		pcall(function()
			local reached = data.level - 1
			AnalyticsService:LogProgressionCompleteEvent(player, "Level", reached, "Level " .. reached)
		end)
		DataService.markDirty(player, true)
		NetService.popup(player, { kind = "LevelUp", level = data.level, coins = coins, gems = gems })
	end
end

function EconomyService.add(player: Player, currency: string, amount: number, reason: string)
	assert(CURRENCIES[currency], "Unknown currency " .. currency)
	assert(amount >= 0 and amount % 1 == 0, "Bad amount")
	local data = DataService.get(player)
	if data == nil or amount == 0 then
		return
	end
	data.currencies[currency] += amount
	logEconomy(player, currency, Enum.AnalyticsEconomyFlowType.Source, amount, data.currencies[currency], reason)
	if currency == "XP" then
		checkLevelUp(player, data)
	end
	DataService.markDirty(player)
end

-- Returns false (and changes nothing) when the player can't afford it.
function EconomyService.spend(player: Player, currency: string, amount: number, reason: string): boolean
	assert(CURRENCIES[currency] and currency ~= "XP", "Can't spend " .. currency)
	assert(amount >= 0 and amount % 1 == 0, "Bad amount")
	local data = DataService.get(player)
	if data == nil or data.currencies[currency] < amount then
		return false
	end
	if amount == 0 then
		return true
	end
	data.currencies[currency] -= amount
	logEconomy(player, currency, Enum.AnalyticsEconomyFlowType.Sink, amount, data.currencies[currency], reason)
	DataService.markDirty(player)
	return true
end

function EconomyService.canAfford(player: Player, currency: string, amount: number): boolean
	local data = DataService.get(player)
	return data ~= nil and data.currencies[currency] >= amount
end

return EconomyService
