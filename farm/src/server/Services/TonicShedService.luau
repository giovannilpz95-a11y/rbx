--!strict
-- The Tonic Shed (Township's Laboratory; Config/Tonics, shared/Tonics, Features/F09): an empty
-- lot turns up on the farm at level 18 (placed like any building, Layout kind "tonics"). Build
-- it once, then switch on Farm Tonics: up to 3 at once, never two alike, each for a set time.
-- A tonic is switched on with Gems, or for free with one found in a Full Hold chest. What
-- they do is read by the other systems through Tonics.value (the modifier pipeline).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtTonicShed = require(Shared.Art.TonicShed)
local Config = require(Shared.Config.Tonics)
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)
local Palette = require(Shared.Art.Palette)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local Tonics = require(Shared.Tonics)
local TownRules = require(Shared.TownRules)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local TonicShedService = {}

local KEY = Layout.key("tonics", "TonicShed")
local visual: { [Player]: string } = {}
local placing: { [Player]: boolean } = {}

local function changed(player: Player)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.pushState(player)
end

---------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------

function TonicShedService.build(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = Tonics.canBuild(data, TownRules.population(data, now))
	if not ok then
		return false, reason
	end
	if not EconomyService.spend(player, "Coins", Config.buildCoins, "tonic_build") then
		return false, string.format("The Tonic Shed costs %d Coins", Config.buildCoins)
	end
	Tonics.build(data, now, Clock.getTimeScale())
	EconomyService.add(player, "XP", Config.buildXp, "tonic_build")
	TelemetryService.custom(player, "TonicShedBuild", 0, "TonicShed")
	changed(player)
	return true
end

function TonicShedService.speedUp(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local readyAt = data.tonics.readyAt
	local now = Clock.now()
	if readyAt == nil or now >= readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(readyAt - now), "speedup_tonicshed") then
		return false, "Not enough Gems"
	end
	Tonics.finishBuild(data, now)
	changed(player)
	return true
end

function TonicShedService.activate(player: Player, id: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	Tonics.prune(data, now)
	local how, reason = Tonics.canActivate(data, id, now)
	if how == nil then
		return false, reason
	end
	local def = Config.tonics[id]
	if how == "gems" and not EconomyService.spend(player, "Gems", def.gems :: number, "tonic_" .. id) then
		return false, string.format("%s costs %d Gems", def.displayName, def.gems :: number)
	end
	local entry = Tonics.activate(data, id, how, now, Clock.getTimeScale())
	NetService.toast(
		player,
		string.format(
			"%s is running for %s: %s.",
			def.displayName,
			Timer.format(entry.endsAt - now),
			def.effect:lower()
		)
	)
	TelemetryService.custom(player, "TonicOn", if how == "gems" then def.gems :: number else 0, id)
	changed(player)
	return true
end

function TonicShedService.cancel(player: Player, id: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if not Tonics.cancel(data, id, Clock.now()) then
		return false
	end
	NetService.toast(player, Config.tonics[id].displayName .. " stopped.")
	changed(player)
	return true
end

---------------------------------------------------------------------------------------------
-- The shed on the plot
---------------------------------------------------------------------------------------------

local function build(player: Player, plot: Model, spot: Layout.Spot): Model?
	local origin = PlotService.originCFrame(player)
	if origin == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "TonicShed"
	model:SetAttribute("LayoutKey", KEY)
	local base = origin * CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.r), 0)
	model:SetAttribute("BaseCFrame", base)
	local parts = ArtTonicShed.build(model, base)
	PlotService.label(parts.body, "Tonic Shed", 3, UDim2.fromOffset(150, 28), 60)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "TimerGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Palette.cocoa
	text.Text = ""
	text.Parent = surface
	surface.Parent = parts.board
	ArtTonicShed.setState(model, "Lot")
	model.Parent = plot
	return model
end

-- Where the shed stands: its saved spot, or (the first time) the nearest open spot to the
-- player, saved and offered for placing
local function spotFor(player: Player, data: { [string]: any }): Layout.Spot?
	local spot = Layout.spot(data, KEY)
	if spot or placing[player] then
		return spot
	end
	placing[player] = true
	spot = PlotService.findOpenSpot(player, data, "tonics", PlotService.nearPlayer(player))
	placing[player] = nil
	if spot == nil then
		return nil
	end
	data.layout[KEY] = spot
	DataService.markDirty(player, true)
	NetService.toast(
		player,
		"A lot for a Tonic Shed turned up on your farm. Walk it where you like, then tap its bench."
	)
	PlotService.offerPlace(player, data, KEY)
	return spot
end

local function boardText(data: { [string]: any }, now: number): string
	local shed = data.tonics
	if shed.readyAt == nil then
		return "Coming soon"
	elseif now < shed.readyAt then
		return "Building\n" .. Timer.format(shed.readyAt - now)
	end
	local n = Tonics.activeCount(data, now)
	if n == 0 then
		return "Tonics"
	end
	return string.format("%d running", n)
end

local function jarColors(data: { [string]: any }, now: number): ({ Color3 }, string)
	local colors, ids = {}, {}
	for _, entry in data.tonics.active do
		local def = Config.tonics[entry.id]
		if def and now < entry.endsAt then
			table.insert(colors, Color3.fromRGB(def.color[1], def.color[2], def.color[3]))
			table.insert(ids, entry.id)
		end
	end
	return colors, table.concat(ids, ",")
end

local function refresh(player: Player, plot: Model, data: { [string]: any }, now: number)
	if not Layout.exists(data, "tonics", "TonicShed") then
		return
	end
	local model = plot:FindFirstChild("TonicShed")
	if model == nil then
		local spot = spotFor(player, data)
		if spot == nil then
			return
		end
		model = build(player, plot, spot)
		visual[player] = nil
		if model == nil then
			return
		end
	end
	local shed = data.tonics
	local building = shed.readyAt ~= nil and now < shed.readyAt
	local open = Tonics.isOpen(data, now)
	local colors, ids = jarColors(data, now)
	local key = string.format("%s:%s:%s", tostring(open), tostring(building), ids)
	if visual[player] ~= key then
		visual[player] = key
		PlotService.setScaffold(model :: Model, building, ArtTonicShed.SIZE, ArtTonicShed.SIZE, 6)
		ArtTonicShed.setState(model :: Model, if open or building then "Open" else "Lot")
		ArtTonicShed.setJars(model :: Model, if open then colors else {})
	end
	local gui = (model :: Model):FindFirstChild("TimerGui", true)
	local text = gui and gui:FindFirstChild("Text") :: TextLabel?
	if text then
		text.Text = boardText(data, now)
	end
end

-- Tonics that run out are cleared, with a toast if their owner is here
local function tick(player: Player)
	local data = DataService.get(player)
	if data == nil or data.tonics == nil then
		return
	end
	local ended = Tonics.prune(data, Clock.now())
	if #ended > 0 then
		for _, id in ended do
			local def = Config.tonics[id]
			if def then
				NetService.toast(player, def.displayName .. " has worn off.")
			end
		end
		changed(player)
	end
end

function TonicShedService.init()
	PlotService.addFeature("tonics", {
		refresh = refresh,
		model = function(plot: Model): Instance?
			return plot:FindFirstChild("TonicShed")
		end,
	})
	NetService.on(Net.Tonic_Build, 1, 2, TonicShedService.build)
	NetService.on(Net.Tonic_SpeedUp, 1, 2, TonicShedService.speedUp)
	NetService.on(Net.Tonic_Activate, 1, 3, TonicShedService.activate)
	NetService.on(Net.Tonic_Cancel, 1, 3, TonicShedService.cancel)

	Players.PlayerRemoving:Connect(function(player)
		visual[player] = nil
		placing[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				tick(player)
			end
		end
	end)
end

return TonicShedService
