--!strict
-- Daily Quests (Design/08 Social & Events, shared/Quests): three a day from 00:00 UTC once
-- the first-session guide is done, progress counted by the farm services, rewards claimed
-- from the Quests panel, and a bonus chest for all three.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local DailyRules = require(Shared.Daily)
local Drops = require(Shared.Drops)
local Net = require(Shared.Net)
local Quests = require(Shared.Quests)
local Records = require(Shared.Records)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local QuestService = {}

-- Quest kind -> Town Records counter (orders are read from the save instead)
local RECORD_STAT = { harvest = "harvest", factory = "goods", animal = "animal" }

-- New day's list when the UTC day turns (or the guide just ended). Returns true if changed.
function QuestService.refresh(player: Player): boolean
	local data = DataService.get(player)
	if data == nil or not Quests.refresh(data, DailyRules.utcDay(Clock.now())) then
		return false
	end
	DataService.markDirty(player, true)
	return true
end

-- Called by the farm services after an action succeeded
function QuestService.progress(player: Player, kind: string, amount: number)
	local data = DataService.get(player)
	if data == nil or amount <= 0 then
		return
	end
	if RECORD_STAT[kind] then
		Records.add(data, RECORD_STAT[kind], amount)
	end
	QuestService.refresh(player)
	for _, index in Quests.add(data, kind, amount) do
		NetService.popup(player, { kind = "Quest", text = Quests.text(data.quests.list[index]) })
	end
end

function QuestService.claim(player: Player, index: any): (boolean, string?)
	if not NetService.check.int(index, 1, 3) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local def, reason = Quests.claim(data, index)
	if def == nil then
		return false, reason
	end
	EconomyService.add(player, "Coins", def.coins, "quest_" .. def.kind)
	EconomyService.add(player, "XP", def.xp, "quest_" .. def.kind)
	TelemetryService.custom(player, "DailyQuestDone", index, def.kind)
	NetService.popup(player, { kind = "QuestClaim", coins = def.coins, xp = def.xp })
	return true
end

function QuestService.reroll(player: Player, index: any): (boolean, string?)
	if not NetService.check.int(index, 1, 3) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	return Quests.reroll(data, index)
end

function QuestService.chest(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if not Quests.chestReady(data) then
		return false
	end
	local gems, tool = Quests.openChest(data, Drops.scarcestTool(data))
	if tool then
		data.toolShed.items[tool] = (data.toolShed.items[tool] or 0) + 1
		local balance = data.toolShed.items[tool]
		TelemetryService.economy(player, "Tools", "Source", 1, balance, "questchest", nil, tool .. "s")
		NetService.popup(player, { kind = "Drop", item = tool, name = Tools.tools[tool].displayName, tool = true })
	else
		EconomyService.add(player, "Gems", gems, "questchest")
		NetService.popup(player, { kind = "QuestChest", gems = gems })
	end
	return true
end

function QuestService.init()
	NetService.on(Net.Quest_Claim, 3, 5, QuestService.claim)
	NetService.on(Net.Quest_Reroll, 1, 2, QuestService.reroll)
	NetService.on(Net.Quest_Chest, 1, 2, QuestService.chest)

	-- The day turns at 00:00 UTC for everyone on the server; the guide can end any time
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				if QuestService.refresh(player) then
					NetService.pushState(player)
				end
			end
		end
	end)
end

return QuestService
