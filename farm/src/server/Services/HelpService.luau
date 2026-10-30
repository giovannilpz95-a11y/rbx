--!strict
-- Helping Hands (Design/14 Multiplayer Features B1, MVP scope: water + harvest): a visitor
-- standing on a neighbor's plot can water a growing field (10% off its time left, once per
-- crop) or harvest a ready one into the OWNER's Barn. Helping never costs the owner anything
-- and the game, not the owner, pays the helper: Coins, XP and now and then a tool. One daily
-- budget per helper (40 actions, 15 on any one farm), and the owner's Helpers setting and
-- both players' block lists decide who may help.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Balance = require(Shared.Config.Balance)
local Crops = require(Shared.Config.Crops)
local Drops = require(Shared.Drops)
local Records = require(Shared.Records)
local Net = require(Shared.Net)
local Social = require(Shared.Config.Social)
local SocialRules = require(Shared.Social)
local Timer = require(Shared.Timer)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local FarmService = require(script.Parent.FarmService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local SocialService = require(script.Parent.SocialService)
local TownService = require(script.Parent.TownService)
local Clock = require(script.Parent.Parent.Util.Clock)

local HelpService = {}

local NOTIFY_SECONDS = 8 -- at most one "X is helping" toast per helper per owner this often

local rng = Random.new()
local lastNotified: { [Player]: { [number]: number } } = {}

-- Rewards only go to Roblox accounts a few days old, so fresh alts can't farm them (14 B1).
local function rewardsAllowed(helper: Player): boolean
	return RunService:IsStudio() or helper.AccountAge >= Social.helperMinAccountDays
end

-- Is the owner working their own plot right now? Then both get the Teamwork bonus.
local function ownerWorking(owner: Player): boolean
	return owner:GetAttribute("OnPlot") == owner.UserId and NetService.idleSeconds(owner) <= Social.teamworkSeconds
end

-- Everything a helping action needs checked before it happens. Returns the owner, their data
-- and the field, or a reason.
local function prepare(
	helper: Player,
	ownerUserId: any,
	fieldId: any
): (Player?, { [string]: any }?, { [string]: any }?, string?)
	if type(ownerUserId) ~= "number" or ownerUserId ~= ownerUserId or not NetService.check.id(fieldId) then
		return nil
	end
	local owner = SocialService.playerByUserId(ownerUserId)
	local helperData = DataService.get(helper)
	local data = owner and DataService.get(owner)
	if owner == nil or owner == helper or data == nil or helperData == nil then
		return nil
	end
	local field = data.fields[fieldId]
	if field == nil or field.crop == nil then
		return nil
	end
	-- (Studio skips the level gate so a fresh test farm can try helping right away)
	if helperData.level < Social.helpUnlockLevel and not RunService:IsStudio() then
		return nil, nil, nil, string.format("Helping Hands opens at level %d", Social.helpUnlockLevel)
	end
	local ok, reason = SocialService.canHelp(helper, owner)
	if not ok then
		return nil, nil, nil, reason
	end
	local pos = PlotService.fieldPosition(owner, fieldId)
	if pos == nil or not NetService.isNear(helper, pos, Balance.serverReachStuds) then
		return nil, nil, nil, "Walk closer to that field"
	end
	local total, onOwner = SocialRules.helpLeft(helperData.social, owner.UserId, SocialRules.utcDay(Clock.now()))
	if total <= 0 then
		return nil, nil, nil, "You've helped all you can today. Thank you! More tomorrow."
	elseif onOwner <= 0 then
		return nil, nil, nil, string.format("You've helped %s all you can today", owner.DisplayName)
	end
	return owner, data, field
end

-- Spend the action, pay the helper, and tell both players.
local function finish(helper: Player, owner: Player, action: string, cropName: string, coins: number, xp: number)
	local helperData = DataService.get(helper) :: { [string]: any }
	SocialRules.spendHelp(helperData.social, owner.UserId, SocialRules.utcDay(Clock.now()))
	Records.add(helperData, "help", 1)
	local teamwork = ownerWorking(owner)
	local tool: string? = nil
	if rewardsAllowed(helper) then
		if teamwork then
			xp += Social.teamworkXP
			EconomyService.add(owner, "XP", Social.teamworkXP, "help_teamwork")
		end
		EconomyService.add(helper, "Coins", coins, "help_" .. action)
		EconomyService.add(helper, "XP", xp, "help_" .. action)
		if rng:NextNumber() < Social.helperToolChance then
			tool = Drops.scarcestTool(helperData)
			TownService.give(helper, helperData, tool :: string)
		end
	else
		coins, xp = 0, 0
	end
	local left = SocialRules.helpLeft(helperData.social, owner.UserId, SocialRules.utcDay(Clock.now()))
	NetService.popup(helper, {
		kind = "Helped",
		owner = owner.DisplayName,
		action = action,
		crop = cropName,
		coins = coins,
		xp = xp,
		teamwork = teamwork and coins > 0,
		left = left,
	})

	DataService.markDirty(owner)
	NetService.pushState(owner)
	local now = os.clock()
	lastNotified[owner] = lastNotified[owner] or {}
	if now - (lastNotified[owner][helper.UserId] or -math.huge) >= NOTIFY_SECONDS then
		lastNotified[owner][helper.UserId] = now
		NetService.popup(owner, { kind = "HelpedYou", name = helper.DisplayName, action = action, crop = cropName })
	end
end

function HelpService.water(helper: Player, ownerUserId: any, fieldId: any): (boolean, string?)
	local owner, data, field, reason = prepare(helper, ownerUserId, fieldId)
	if owner == nil or data == nil or field == nil then
		return false, reason
	end
	local now = Clock.now()
	if Timer.isReady(field.readyAt, now) then
		return false, "That field is ready to harvest"
	elseif field.watered then
		return false, "That field has already been watered"
	end
	field.readyAt = SocialRules.wateredReadyAt(field.readyAt, now)
	field.watered = true
	PlotService.refresh(owner)
	finish(helper, owner, "watered", Crops[field.crop].displayName, 1, 1)
	return true
end

function HelpService.harvest(helper: Player, ownerUserId: any, fieldId: any): (boolean, string?)
	local owner, _, field, reason = prepare(helper, ownerUserId, fieldId)
	if owner == nil or field == nil then
		return false, reason
	end
	local crop = Crops[field.crop]
	local ok, why = FarmService.reap(owner, fieldId, helper)
	if not ok then
		return false, why
	end
	finish(helper, owner, "harvested", crop.displayName, SocialRules.helperCoins(crop.sellPrice, crop.yield), crop.xp)
	return true
end

function HelpService.init()
	NetService.on(Net.Help_Water, 4, 6, HelpService.water)
	NetService.on(Net.Help_Harvest, 4, 6, HelpService.harvest)
	Players.PlayerRemoving:Connect(function(player)
		lastNotified[player] = nil
		for _, byHelper in lastNotified do
			byHelper[player.UserId] = nil
		end
	end)
end

return HelpService
