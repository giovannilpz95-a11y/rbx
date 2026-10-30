--!strict
-- The Quarry (Features/F01 Quarry & Smelter, shared/Quarry): reopen it once with Coins and a
-- wait, then dig its shaft from the Quarry panel, one Pickaxe a swing. The server rolls nothing:
-- every cell is fixed by the seed in the save, and each dig is checked for reach and Pickaxes.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Quarry)
local DailyRules = require(Shared.Daily)
local Land = require(Shared.Config.Land)
local Net = require(Shared.Net)
local Quarry = require(Shared.Quarry)
local Speedup = require(Shared.Speedup)
local TownRules = require(Shared.TownRules)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local QuarryService = {}

local MAX_ROW = 100000

function QuarryService.restore(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if data.quarry.readyAt ~= nil then
		return false
	end
	if data.level < Config.unlockLevel then
		return false, string.format("The Quarry reopens at level %d", Config.unlockLevel)
	end
	local now = Clock.now()
	if not TownRules.landDone(data, Config.land, now) then
		return false,
			string.format("The Quarry is in the %s. Clear it first.", Land.expansions[Config.land].displayName)
	end
	if not EconomyService.spend(player, "Coins", Config.restoreCost, "quarry_restore") then
		return false, string.format("Reopening the Quarry costs %d Coins", Config.restoreCost)
	end
	Quarry.restore(data, now + Clock.duration(Config.restoreSeconds), Random.new():NextInteger(1, 2147483646))
	EconomyService.add(player, "XP", Config.restoreXp, "quarry_restore")
	TelemetryService.custom(player, "QuarryRestore", 0, "Quarry")
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.toast(player, string.format("Reopening the Quarry. Here are %d Pickaxes to start.", Config.restoreGift))
	return true
end

-- Gems finish reopening now.
function QuarryService.speedUp(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local readyAt = data.quarry.readyAt
	local now = Clock.now()
	if readyAt == nil or now >= readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(readyAt - now), "speedup_quarry") then
		return false, "Not enough Gems"
	end
	data.quarry.readyAt = now
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function QuarryService.dig(player: Player, row: any, col: any): (boolean, string?)
	if not NetService.check.int(row, 1, MAX_ROW) or not NetService.check.int(col, 1, Config.width) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason = Quarry.canDig(data, row, col, Clock.now())
	if not ok then
		return false, reason
	end
	local result = Quarry.dig(data, row, col)
	if result.xp > 0 then
		EconomyService.add(player, "XP", result.xp, "quarry_ore")
	end
	if result.coins then
		EconomyService.add(player, "Coins", result.coins, "quarry_coins")
	end
	local ore = result.find and Config.ores[result.find]
	if ore then
		NetService.toast(player, "Found " .. ore.displayName .. "!")
	elseif result.pickaxes then
		NetService.toast(player, string.format("A Lost Lunchbox! %d Pickaxes inside", result.pickaxes))
	elseif result.coins then
		NetService.toast(player, string.format("A pile of %d Coins!", result.coins))
	end
	return true
end

function QuarryService.claimFree(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local given = Quarry.claimFree(data, DailyRules.utcDay(now), now)
	if given == 0 then
		return false
	end
	NetService.toast(player, string.format("%d free Pickaxes", given))
	return true
end

function QuarryService.init()
	NetService.on(Net.Quarry_Restore, 2, 3, QuarryService.restore)
	NetService.on(Net.Quarry_SpeedUp, 2, 3, QuarryService.speedUp)
	NetService.on(Net.Quarry_Dig, 1 / Config.digCooldown, 8, QuarryService.dig)
	NetService.on(Net.Quarry_Free, 2, 3, QuarryService.claimFree)
end

return QuarryService
