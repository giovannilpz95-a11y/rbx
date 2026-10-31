--!strict
-- Town Records (shared/Records, Config/Records): claims the next tier of a record for its
-- Gems and XP. Progress is counted by the farm services and read from the save.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Records)
local Net = require(Shared.Net)
local Badges = require(Shared.Badges)
local Records = require(Shared.Records)
local Trophies = require(Shared.Config.Trophies)

local BadgeService = require(script.Parent.BadgeService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local RecordsService = {}

function RecordsService.claim(player: Player, id: any): (boolean, string?)
	if not NetService.check.id(id) then
		return false
	end
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local tier, def = Records.claim(data, id, Clock.now())
	if tier == nil then
		return false, def :: string
	end
	local record = def :: Config.RecordDef
	EconomyService.add(player, "Gems", record.gems[tier], "record_" .. record.id)
	EconomyService.add(player, "XP", record.xp[tier], "record_" .. record.id)
	-- Gold (the last tier) also gives the record's trophy, to place from the Decor tab
	local trophy = if tier == #record.goals then Trophies.byRecord[record.id] else nil
	if trophy then
		data.trophies[trophy.id] = (data.trophies[trophy.id] or 0) + 1
	end
	TelemetryService.custom(player, "RecordTier", tier, record.id)
	BadgeService.award(player, Badges.forMedal(record.id, tier))
	NetService.popup(player, {
		kind = "RecordClaim",
		name = record.name,
		tier = Config.tiers[tier],
		gems = record.gems[tier],
		xp = record.xp[tier],
		trophy = if trophy then trophy.displayName else nil,
	})
	return true
end

function RecordsService.init()
	NetService.on(Net.Records_Claim, 2, 5, RecordsService.claim)
end

return RecordsService
