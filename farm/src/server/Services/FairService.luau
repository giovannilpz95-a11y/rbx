--!strict
-- The County Fair (Config/Fair, shared/Fair; Design/14 F1): entries during the weekend window,
-- judging at its close, ribbons and Blue Ribbon cups handed over, and the results on the
-- Notice Board for the farms on this server. While entries are open the fair's tent stands in
-- the Town Square.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtFairStand = require(Shared.Art.FairStand)
local Config = require(Shared.Config.Fair)
local Fair = require(Shared.Fair)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local PrizeRules = require(Shared.Prize)

local BadgeService = require(script.Parent.BadgeService)
local BadgeConfig = require(Shared.Config.Badges)
local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local NoticeService = require(script.Parent.NoticeService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)
local OpenGround = require(script.Parent.Parent.Util.OpenGround)

local FairService = {}

local ready: { [Player]: boolean } = {}
local tent: { model: Model, week: number }? = nil
local announced = 0 -- the week whose opening the Notice Board has shown

local DEBUG_CROP = "Wheat" -- every farm grows it

local TENT_ANGLES = { -90, -60, -120, -30, -150, 200, -20, 160 }
local TENT_RADII = { 27, 24, 30 }
local TENT_CLEARANCE = Vector3.new(10, 8, 10)
local TENT_CLEARANCE_AT = CFrame.new(0, 4.5, 0)

local function preview(startsAt: number)
	Fair.setPreview(startsAt)
	Workspace:SetAttribute("FairPreview", startsAt)
end

local function sync(player: Player): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local before = data.fair.week
	local results = Fair.sync(data, Clock.now())
	if #results > 0 then
		local parts = {}
		for _, r in results do
			local ribbon = Fair.ribbon(r.marks)
			table.insert(
				parts,
				string.format(
					"%s %s: %s (%d marks)",
					ribbon.icon,
					Config.classes[r.class].displayName,
					ribbon.displayName,
					r.marks
				)
			)
			if r.ribbon == "Blue" then
				NoticeService.post(
					string.format(
						"%s won a Blue Ribbon for %s at the County Fair",
						player.DisplayName,
						Config.classes[r.class].displayName
					)
				)
			end
			TelemetryService.custom(player, "FairRibbon", r.marks, r.class .. "_" .. r.ribbon)
		end
		local cups = 0
		for _, r in results do
			if r.cup then
				cups += 1
			end
		end
		NetService.popup(player, {
			kind = "Fair",
			step = "results",
			text = "County Fair results!  " .. table.concat(parts, "   ") .. (if cups > 0
				then "  A Blue Ribbon cup is in Build > Decorations."
				else ""),
		})
		if BadgeConfig.fair > 0 then
			BadgeService.award(player, BadgeConfig.fair) -- the County Fair badge, for any ribbon
		end
	end
	if #results > 0 or data.fair.week ~= before then
		DataService.markDirty(player, true)
		return true
	end
	return false
end

function FairService.enter(player: Player, class: any, a: any, b: any): (boolean, string?)
	sync(player)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local now = Clock.now()
	local okEnter, reason = Fair.canEnter(data, now, class, a, b)
	if not okEnter then
		return false, reason
	end
	Fair.enter(data, now, player.UserId, class, a, b)
	local entry = data.fair.entries[class]
	local name = if Items[entry.item] then Items[entry.item].displayName else entry.item
	local _, closes = Fair.window(now)
	TelemetryService.custom(player, "FairEntry", entry.marks, class)
	NetService.popup(player, {
		kind = "Fair",
		step = "entered",
		text = string.format(
			"Your %s%s is entered in %s! The judges score it in %s.",
			if entry.tier then entry.tier .. " " else "",
			if entry.garnish
				then string.format(
					"%s topped with %s %s",
					name,
					entry.garnish,
					if Items[entry.garnishCrop] then Items[entry.garnishCrop].displayName else entry.garnishCrop
				)
				else name,
			Config.classes[class].displayName,
			(function()
				local s = math.max(0, closes - now)
				return if s >= 86400
					then string.format("%dd %dh", s // 86400, (s % 86400) // 3600)
					else string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
			end)()
		),
	})
	return true
end

-- Studio: "open" starts a fair now, "judge" closes its entries now, "Starlit" / "Heirloom"
-- puts a Prize Crop of that tier in the Prize Basket (to test a Blue Ribbon)
function FairService.debug(player: Player, what: any): (boolean, string?)
	if not RunService:IsStudio() then
		return false
	end
	local now = Clock.now()
	if what == "Starlit" or what == "Heirloom" then
		local data = DataService.get(player)
		if data == nil then
			return false
		end
		if not PrizeRules.hasRoom(data) then
			return false, "Dev: your Prize Basket is full"
		end
		table.insert(data.prizes, { crop = DEBUG_CROP, tier = what })
		DataService.markDirty(player, true)
		NetService.toast(
			player,
			string.format("Dev: a %s %s is in your Prize Basket", what, Items[DEBUG_CROP].displayName)
		)
		return true
	elseif what == "open" then
		preview(now - 60)
	elseif what == "judge" then
		local opens = Fair.window(now)
		preview(now - Config.openSeconds - 1)
		-- Keep this week's entries: move them to the preview's week so they get judged
		for _, other in Players:GetPlayers() do
			local data = DataService.get(other)
			if data and data.fair.week == opens then
				data.fair.week = Fair.window(now)
			end
		end
	else
		return false
	end
	for _, other in Players:GetPlayers() do
		sync(other)
		NetService.pushState(other)
	end
	return true
end

local function updateTent(now: number)
	local week, closes = Fair.window(now)
	local open = now < closes
	if tent and (not open or tent.week ~= week) then
		tent.model:Destroy()
		tent = nil
	end
	if not open or tent then
		return
	end
	local cf = OpenGround.find(TENT_ANGLES, TENT_RADII, TENT_CLEARANCE, TENT_CLEARANCE_AT)
	if cf == nil then
		warn("[FairService] no open ground on the plaza for the County Fair tent")
		return
	end
	local built = ArtFairStand.build(PlotService.square.model, cf, "County Fair")
	built.model.Name = "CountyFairTent"
	for _, p in built.model:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("Interact", "CountyFair")
		end
	end
	tent = { model = built.model, week = week }
	if announced ~= week then
		announced = week
		NoticeService.post("The County Fair is open until Monday: enter a Prize Crop and your best bake")
	end
end

function FairService.init()
	if RunService:IsStudio() then
		preview(Clock.now() - 60) -- Studio previews an open fair
	end
	NetService.on(Net.Fair_Enter, 2, 3, FairService.enter)
	NetService.on(Net.Debug_Fair, 1, 2, FairService.debug)
	local function watch(player: Player)
		NetService.whenReady(player, function()
			ready[player] = true
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
	end)
	task.spawn(function()
		while true do
			updateTent(Clock.now())
			for player in ready do
				if player.Parent and sync(player) then
					NetService.pushState(player)
				end
			end
			task.wait(10)
		end
	end)
end

return FairService
