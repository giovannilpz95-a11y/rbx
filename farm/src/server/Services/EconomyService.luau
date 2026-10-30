--!strict
-- The ONLY place Coins, Gems and XP change (Design/09 Roblox Architecture §3).
-- XP gains also level the player up and pay the level-up reward.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Progression = require(Shared.Progression)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local TelemetryService = require(script.Parent.TelemetryService)

local EconomyService = {}

local CURRENCIES = { Coins = true, Gems = true, XP = true }

local function logEconomy(
	player: Player,
	currency: string,
	flow: "Source" | "Sink",
	amount: number,
	balance: number,
	reason: string,
	transactionType: string?
)
	TelemetryService.economy(player, currency, flow, amount, balance, reason, transactionType)
end

local function checkLevelUp(player: Player, data: { [string]: any })
	local newLevel = Progression.levelFor(data.currencies.XP)
	while data.level < newLevel do
		TelemetryService.flush(player) -- send what was earned in the old level band first
		data.level += 1
		local coins, gems = Progression.reward(data.level)
		if coins > 0 then
			EconomyService.add(player, "Coins", coins, "levelup")
		end
		if gems > 0 then
			EconomyService.add(player, "Gems", gems, "levelup")
		end
		TelemetryService.levelUp(player, data.level - 1)
		DataService.markDirty(player, true)
		NetService.popup(player, { kind = "LevelUp", level = data.level, coins = coins, gems = gems })
	end
end

-- `transactionType`: an Enum.AnalyticsEconomyTransactionType name ("IAP" for Robux purchases)
function EconomyService.add(player: Player, currency: string, amount: number, reason: string, transactionType: string?)
	assert(CURRENCIES[currency], "Unknown currency " .. currency)
	assert(amount >= 0 and amount % 1 == 0, "Bad amount")
	local data = DataService.get(player)
	if data == nil or amount == 0 then
		return
	end
	data.currencies[currency] += amount
	logEconomy(player, currency, "Source", amount, data.currencies[currency], reason, transactionType)
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
	logEconomy(player, currency, "Sink", amount, data.currencies[currency], reason)
	DataService.markDirty(player)
	return true
end

function EconomyService.canAfford(player: Player, currency: string, amount: number): boolean
	local data = DataService.get(player)
	return data ~= nil and data.currencies[currency] >= amount
end

return EconomyService
