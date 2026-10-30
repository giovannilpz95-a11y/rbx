--!strict
-- The Tinker's Guild (Features/F01 Quarry & Smelter, shared/Guild): build it once with Bars,
-- then spend Bars on factory upgrades from the Guild panel, one stat per upgrade.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Guild)
local Factories = require(Shared.Config.Factories)
local Guild = require(Shared.Guild)
local Net = require(Shared.Net)
local Speedup = require(Shared.Speedup)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local FactoryService = require(script.Parent.FactoryService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local GuildService = {}

function GuildService.build(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = Guild.canBuild(data, now)
	if not ok then
		return false, reason
	end
	if not InventoryService.remove(player, Config.buildBars) then
		return false, "The Tinker's Guild takes 6 Copper Bars and 2 Silver Bars. Smelt them at a Smelter."
	end
	data.guild.readyAt = now + Clock.duration(Config.buildSeconds)
	EconomyService.add(player, "XP", Config.buildXp, "build_Guild")
	TelemetryService.custom(player, "GuildBuilt", 0, "Guild")
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

-- Gems finish building it now.
function GuildService.speedUp(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local readyAt = data.guild.readyAt
	local now = Clock.now()
	if readyAt == nil or now >= readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(readyAt - now), "speedup_guild") then
		return false, "Not enough Gems"
	end
	data.guild.readyAt = now
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function GuildService.upgrade(player: Player, factoryId: any, stat: any): (boolean, string?)
	if not NetService.check.id(factoryId) or not NetService.check.id(stat) or Factories[factoryId] == nil then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	FactoryService.advance(player) -- the old shelf and time rules apply up to now
	local cost, reason = Guild.canUpgrade(data, factoryId, stat, Clock.now())
	if cost == nil then
		return false, reason
	end
	if not InventoryService.remove(player, cost) then
		return false, "Not enough Bars. Smelt more at a Smelter."
	end
	Guild.upgrade(data, factoryId, stat)
	TelemetryService.custom(
		player,
		"GuildUpgrade",
		Guild.level(Guild.levels(data, factoryId)),
		factoryId .. ":" .. stat
	)
	FactoryService.advance(player) -- a new shelf can restart a full factory
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.toast(
		player,
		string.format(
			"The %s is now level %d.",
			Factories[factoryId].displayName,
			Guild.level(Guild.levels(data, factoryId))
		)
	)
	return true
end

function GuildService.init()
	NetService.on(Net.Guild_Build, 1, 2, GuildService.build)
	NetService.on(Net.Guild_SpeedUp, 1, 2, GuildService.speedUp)
	NetService.on(Net.Guild_Upgrade, 2, 4, GuildService.upgrade)
end

return GuildService
