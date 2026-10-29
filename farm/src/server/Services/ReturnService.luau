--!strict
-- Reasons to come back (Design/01 Core Loop, 08 Social & Events): the "While you were
-- away" summary on join and the daily login calendar.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Away = require(Shared.Away)
local Daily = require(Shared.Config.Daily)
local DailyRules = require(Shared.Daily)
local Items = require(Shared.Items)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local Clock = require(script.Parent.Parent.Util.Clock)

local ReturnService = {}

-- Give today's login reward if one is due. Waits (retries later) while the Barn can't
-- take its item.
function ReturnService.claimDaily(player: Player): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local now = Clock.now()
	local reward, day = DailyRules.due(data, now)
	if reward == nil then
		return false
	end
	if reward.item and not InventoryService.add(player, { [reward.item] = 1 }) then
		return false
	end
	DailyRules.claim(data, now, day)
	local parts = {}
	if reward.coins then
		EconomyService.add(player, "Coins", reward.coins, "daily")
		table.insert(parts, string.format("%d Coins", reward.coins))
	end
	if reward.gems then
		EconomyService.add(player, "Gems", reward.gems, "daily")
		table.insert(parts, string.format("%d Gems", reward.gems))
	end
	if reward.item then
		table.insert(parts, "1 " .. Items[reward.item].displayName)
	end
	DataService.markDirty(player, true)
	local payload = { kind = "Daily", day = day, days = #Daily.days, reward = table.concat(parts, " + ") }
	NetService.whenReady(player, function()
		NetService.popup(player, payload)
		NetService.pushState(player)
	end)
	return true
end

-- Call on join, after offline production has landed.
function ReturnService.playerLoaded(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local lines = Away.summary(data, data.meta.lastSeenAt, Clock.now())
	if #lines > 0 then
		NetService.whenReady(player, function()
			NetService.popup(player, { kind = "Away", lines = lines })
		end)
	end
	ReturnService.claimDaily(player)
end

function ReturnService.init()
	-- DEV-only: try both without leaving for hours. Ignored outside Studio.
	NetService.on(Net.Debug_Away, 1, 2, function(player)
		local data = DataService.get(player)
		if not RunService:IsStudio() or data == nil then
			return false
		end
		local now = Clock.now()
		local lines = Away.summary(data, now - 2 * 3600, now)
		NetService.popup(player, { kind = "Away", lines = if #lines > 0 then lines else { "Nothing finished" } })
		data.daily.lastDay -= 1
		ReturnService.claimDaily(player)
		return true
	end)
	-- A new UTC day (or reaching level 5) while playing
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				ReturnService.claimDaily(player)
			end
		end
	end)
end

return ReturnService
