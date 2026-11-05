--!strict
-- The Plot Showcase (Config/Showcase, shared/Showcase; Design/14 F3). Once an hour, for five
-- minutes, every farm on the server that opted in shows a sunflower banner over its gate.
-- Visitors who stay a while on one get a rating card (1-3 sunflowers). When it ends the farm
-- with the most sunflowers gets a ribbon on its gate for a week; voters get a little XP. The
-- banners and ribbons are drawn by the clients from the workspace's "Showcase" attribute.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Showcase)
local Net = require(Shared.Net)
local Showcase = require(Shared.Showcase)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local NoticeService = require(script.Parent.NoticeService)
local PlotService = require(script.Parent.PlotService)
local SocialService = require(script.Parent.SocialService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local ShowcaseService = {}

local DAY = 86400

-- This Showcase: started at, votes per owner, time each visitor spent on each farm, the
-- cards already sent, and XP votes per voter
type Run = {
	startsAt: number,
	votes: { [number]: { Showcase.Vote } },
	dwell: { [Player]: { [number]: number } },
	carded: { [Player]: { [number]: boolean } },
	paid: { [Player]: number },
}
local run: Run? = nil
local waiveDwell = false -- Studio: rate straight away
local published = ""

local function optedIn(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil and data.showcase.optIn == true
end

local function publish(now: number)
	local plots = {}
	if run then
		for _, owner in Players:GetPlayers() do
			local gate = optedIn(owner) and PlotService.gateCFrame(owner)
			if gate then
				local p = gate.Position
				table.insert(plots, { id = owner.UserId, x = p.X, y = p.Y, z = p.Z })
			end
		end
	end
	local ribbons = {}
	for _, owner in Players:GetPlayers() do
		local data = DataService.get(owner)
		local gate = data and data.showcase.ribbonUntil > now and PlotService.gateCFrame(owner)
		if gate then
			local p = gate.Position
			table.insert(ribbons, { id = owner.UserId, x = p.X, y = p.Y, z = p.Z })
		end
	end
	local _, endsAt = Showcase.window(now)
	local text = if #plots == 0 and #ribbons == 0
		then ""
		else HttpService:JSONEncode({ endsAt = if run then endsAt else 0, plots = plots, ribbons = ribbons })
	if text ~= published then
		published = text
		Workspace:SetAttribute("Showcase", text)
	end
end

local function start(now: number)
	local startsAt = Showcase.window(now)
	run = { startsAt = startsAt, votes = {}, dwell = {}, carded = {}, paid = {} }
	local shown = 0
	for _, p in Players:GetPlayers() do
		if optedIn(p) then
			shown += 1
		end
	end
	if shown == 0 then
		return -- nothing on show: no announcement
	end
	for _, p in Players:GetPlayers() do
		NetService.popup(p, {
			kind = "Showcase",
			step = "start",
			text = string.format(
				"Plot Showcase! %d farm%s on show for 5 minutes: visit a farm with a 🌻 banner and rate it.",
				shown,
				if shown == 1 then " is" else "s are"
			),
		})
	end
end

local function finish(now: number)
	local r = run
	run = nil
	waiveDwell = false
	if r == nil then
		return
	end
	local winnerId, total = Showcase.winner(r.votes)
	for ownerId, list in r.votes do
		local owner = SocialService.playerByUserId(ownerId)
		local data = owner and DataService.get(owner)
		if owner and data then
			local got = Showcase.total(list)
			data.showcase.sunflowers += got
			local won = ownerId == winnerId
			if won then
				data.showcase.wins += 1
				data.showcase.ribbonUntil = now + Config.ribbonDays * DAY
			end
			DataService.markDirty(owner, true)
			NetService.pushState(owner)
			NetService.popup(owner, {
				kind = "Showcase",
				step = "results",
				text = if won
					then string.format(
						"Your farm won the Plot Showcase with %s 🌻! A ribbon hangs on your gate for a week.",
						tostring(got)
					)
					else string.format(
						"Your farm got %s 🌻 from %d visitor%s in the Plot Showcase.",
						tostring(got),
						#list,
						if #list == 1 then "" else "s"
					),
			})
			TelemetryService.custom(owner, "ShowcaseVotes", #list, if won then "won" else "shown")
		end
	end
	if winnerId then
		local owner = SocialService.playerByUserId(winnerId)
		if owner then
			NoticeService.post(
				string.format("%s's farm won the Plot Showcase with %s 🌻", owner.DisplayName, tostring(total))
			)
		end
	end
end

-- Count time on farms on show (called every second during a Showcase); send a rating card
-- when a visitor has stayed long enough
local function track(r: Run)
	for _, visitor in Players:GetPlayers() do
		local ownerId = visitor:GetAttribute("OnPlot")
		if type(ownerId) == "number" and ownerId ~= 0 and ownerId ~= visitor.UserId then
			local owner = SocialService.playerByUserId(ownerId)
			if owner and optedIn(owner) then
				local mine = r.dwell[visitor] or {}
				r.dwell[visitor] = mine
				mine[ownerId] = (mine[ownerId] or 0) + 1
				local carded = r.carded[visitor] or {}
				r.carded[visitor] = carded
				local data = DataService.get(visitor)
				if
					not carded[ownerId]
					and data
					and data.level >= Config.minLevel
					and (mine[ownerId] >= Config.dwellSeconds or waiveDwell)
				then
					carded[ownerId] = true
					NetService.popup(
						visitor,
						{ kind = "Showcase", step = "rate", owner = ownerId, name = owner.DisplayName }
					)
				end
			end
		end
	end
end

function ShowcaseService.rate(player: Player, ownerId: any, stars: any): (boolean, string?)
	local r = run
	local now = Clock.now()
	if r == nil or not Showcase.canRate(now) or type(ownerId) ~= "number" then
		return false, "The Plot Showcase is over"
	end
	local data = DataService.get(player)
	local owner = SocialService.playerByUserId(ownerId)
	if data == nil or owner == nil then
		return false
	end
	local list = r.votes[ownerId] or {}
	local already = false
	for _, v in list do
		if v.voter == player.UserId then
			already = true
		end
	end
	local dwell = if waiveDwell then math.huge else ((r.dwell[player] or {})[ownerId] or 0)
	local why = Showcase.check(data.level, player.UserId, ownerId, optedIn(owner), dwell, already, stars)
	if why == "junk" then
		return false
	elseif why then
		return false, why
	end
	local weight = if SocialService.isFriend(player, owner) then Config.friendWeight else 1
	table.insert(list, { voter = player.UserId, stars = stars, weight = weight })
	r.votes[ownerId] = list
	local paid = r.paid[player] or 0
	if paid < Config.xpVotesMax then
		r.paid[player] = paid + 1
		EconomyService.add(player, "XP", Config.xpPerVote, "showcase_vote")
	end
	NetService.popup(player, {
		kind = "Showcase",
		step = "rated",
		text = string.format(
			"You gave %s's farm %s.%s",
			owner.DisplayName,
			string.rep("🌻", stars),
			if paid < Config.xpVotesMax then string.format("  +%d XP", Config.xpPerVote) else ""
		),
	})
	return true
end

local function setOptIn(player: Player, value: any): (boolean, string?)
	if value ~= "On" and value ~= "Off" then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	data.showcase.optIn = value == "On"
	publish(Clock.now())
	return true
end

function ShowcaseService.debug(player: Player): (boolean, string?)
	if not RunService:IsStudio() then
		return false
	end
	if not optedIn(player) then
		return false, "Dev: opt in first (Settings > Show my farm in the Plot Showcase)"
	end
	local now = Clock.now()
	Showcase.setPreview(now)
	Workspace:SetAttribute("ShowcasePreview", now)
	if run then
		finish(now)
	end
	start(now)
	waiveDwell = true
	publish(now)
	NetService.toast(player, "Dev: a Plot Showcase now (no 20-second wait)")
	return true
end

function ShowcaseService.init()
	NetService.on(Net.Showcase_Rate, 2, 4, ShowcaseService.rate)
	NetService.on(Net.Showcase_OptIn, 2, 3, setOptIn)
	NetService.on(Net.Debug_Showcase, 1, 2, ShowcaseService.debug)
	Players.PlayerRemoving:Connect(function(player)
		if run then
			run.dwell[player] = nil
			run.carded[player] = nil
			run.paid[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			local now = Clock.now()
			local on = Showcase.isOn(now)
			local startsAt = Showcase.window(now)
			if run and (not on or run.startsAt ~= startsAt) and not Showcase.canRate(now) then
				finish(now)
			elseif run == nil and on then
				-- Only when a farm here is on show (and someone could visit it)
				local any = false
				for _, p in Players:GetPlayers() do
					if optedIn(p) then
						any = true
					end
				end
				if any and #Players:GetPlayers() >= (if RunService:IsStudio() then 1 else 2) then
					start(now)
				end
			end
			local r = run
			if r and on then
				track(r)
			end
			publish(now)
			task.wait(1)
		end
	end)
end

return ShowcaseService
