--!strict
-- The Otter Pond (Township's Otter Pond; Config/OtterPond, shared/OtterPond): an empty stony
-- pool turns up on the farm at level 58 (placed like any building, Layout kind "otters").
-- Build it once and the first otter moves in; two more can be bought. Give an otter an Egg,
-- Bacon or Fish and it goes fishing, coming back with Seaweed, Scallops and maybe Pearls.
-- What it brings is drawn when it's fed.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtOtterPond = require(Shared.Art.OtterPond)
local Config = require(Shared.Config.OtterPond)
local Items = require(Shared.Items)
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)
local OtterPond = require(Shared.OtterPond)
local Palette = require(Shared.Art.Palette)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local OtterPondService = {}

local KEY = Layout.key("otters", "OtterPond")
local visual: { [Player]: string } = {}
local placing: { [Player]: boolean } = {}

local function changed(player: Player)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.pushState(player)
end

local function catchText(catch: { [string]: number }): string
	local parts = {}
	for id, qty in catch do
		table.insert(parts, string.format("%d %s", qty, Items[id].displayName))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

---------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------

function OtterPondService.build(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason = OtterPond.canBuild(data)
	if not ok then
		return false, reason
	end
	if not EconomyService.spend(player, "Coins", Config.buildCoins, "otters_build") then
		return false, string.format("The Otter Pond costs %d Coins", Config.buildCoins)
	end
	OtterPond.build(data, Clock.now(), Random.new():NextInteger(1, 2147483646), Clock.getTimeScale())
	EconomyService.add(player, "XP", Config.buildXp, "otters_build")
	TelemetryService.custom(player, "OtterBuild", 0, "OtterPond")
	changed(player)
	return true
end

function OtterPondService.speedUp(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local readyAt = data.otterPond.readyAt
	local now = Clock.now()
	if readyAt == nil or now >= readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(readyAt - now), "speedup_otters") then
		return false, "Not enough Gems"
	end
	OtterPond.finishBuild(data, now)
	changed(player)
	return true
end

function OtterPondService.buyOtter(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason = OtterPond.canBuyOtter(data, Clock.now())
	if not ok then
		return false, reason
	end
	local coins = OtterPond.nextOtterCoins(data) :: number
	if not EconomyService.spend(player, "Coins", coins, "otters_buy") then
		return false, string.format("Another otter costs %d Coins", coins)
	end
	OtterPond.buyOtter(data)
	NetService.toast(player, "A new otter moved into the Otter Pond.")
	changed(player)
	return true
end

function OtterPondService.feed(player: Player, otter: any, food: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = OtterPond.canFeed(data, otter, food, now)
	if not ok then
		return false, reason
	end
	local item = Config.foods[food].item
	if not InventoryService.remove(player, { [item] = 1 }) then
		return false, string.format("You need %s in the Barn", Items[item].displayName)
	end
	OtterPond.feed(data, otter, food, now, Clock.getTimeScale())
	NetService.toast(player, "The otter slipped into the water to go fishing.")
	changed(player)
	return true
end

function OtterPondService.collect(player: Player, otter: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	if type(otter) ~= "number" then
		otter = OtterPond.firstDone(data, now)
		if otter == nil then
			return false
		end
	end
	local trip = OtterPond.trip(data, otter)
	if trip == nil then
		return false, "Give the otter an Egg, Bacon or Fish and it will go fishing"
	elseif now < trip.readyAt then
		return false, "The otter is still fishing: " .. Timer.format(trip.readyAt - now) .. " left"
	end
	local catch = trip.catch
	if next(catch) ~= nil and not InventoryService.add(player, catch) then
		return false, "The Barn is full"
	end
	OtterPond.collect(data, otter, now)
	for id, qty in catch do
		EconomyService.add(player, "XP", Config.goods[id].xp * qty, "otters_collect")
	end
	if next(catch) ~= nil then
		NetService.toast(player, "The otter brought back " .. catchText(catch) .. ".")
	end
	changed(player)
	return true
end

function OtterPondService.skip(player: Player, otter: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if type(otter) ~= "number" then
		return false
	end
	local trip = OtterPond.trip(data, otter)
	local now = Clock.now()
	if trip == nil or now >= trip.readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.production(trip.readyAt - now), "speedup_otters") then
		return false, "Not enough Gems"
	end
	OtterPond.skip(data, otter, now)
	changed(player)
	return true
end

---------------------------------------------------------------------------------------------
-- The pond on the plot
---------------------------------------------------------------------------------------------

local function build(player: Player, plot: Model, spot: Layout.Spot): Model?
	local origin = PlotService.originCFrame(player)
	if origin == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "OtterPond"
	model:SetAttribute("LayoutKey", KEY)
	local base = origin * CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.r), 0)
	model:SetAttribute("BaseCFrame", base)
	local parts = ArtOtterPond.build(model, base)
	PlotService.label(parts.body, "Otter Pond", 3, UDim2.fromOffset(150, 28), 60)
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
	ArtOtterPond.setState(model, "Dry")
	model.Parent = plot
	return model
end

-- Where the pond lies: its saved spot, or (the first time) the nearest open spot to the
-- player, saved and offered for placing
local function spotFor(player: Player, data: { [string]: any }): Layout.Spot?
	local spot = Layout.spot(data, KEY)
	if spot or placing[player] then
		return spot
	end
	placing[player] = true
	spot = PlotService.findOpenSpot(player, data, "otters", PlotService.nearPlayer(player))
	placing[player] = nil
	if spot == nil then
		return nil
	end
	data.layout[KEY] = spot
	DataService.markDirty(player, true)
	NetService.toast(
		player,
		"A spot for an Otter Pond turned up on your farm. Walk it where you like, then tap its dock."
	)
	PlotService.offerPlace(player, data, KEY)
	return spot
end

local function boardText(data: { [string]: any }, now: number): string
	local pond = data.otterPond
	if pond.readyAt == nil then
		return "Build me"
	elseif now < pond.readyAt then
		return "Building\n" .. Timer.format(pond.readyAt - now)
	end
	local soonest: number? = nil
	for i = 1, pond.otters or 1 do
		local trip = OtterPond.trip(data, i)
		if trip and now >= trip.readyAt then
			return "Catch ready!"
		elseif trip and (soonest == nil or trip.readyAt < soonest) then
			soonest = trip.readyAt
		end
	end
	if soonest then
		return "Fishing\n" .. Timer.format(soonest - now)
	end
	return "Feed the otters"
end

local function states(data: { [string]: any }, now: number): { string }
	local out = {}
	local pond = data.otterPond
	for i = 1, ArtOtterPond.OTTERS do
		if i > (pond.otters or 1) then
			out[i] = "none"
		else
			local trip = OtterPond.trip(data, i)
			out[i] = if trip == nil then "home" elseif now >= trip.readyAt then "back" else "away"
		end
	end
	return out
end

local function refresh(player: Player, plot: Model, data: { [string]: any }, now: number)
	if not Layout.exists(data, "otters", "OtterPond") then
		return
	end
	local model = plot:FindFirstChild("OtterPond")
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
	local pond = data.otterPond
	local building = pond.readyAt ~= nil and now < pond.readyAt
	local open = OtterPond.isOpen(data, now)
	local s = states(data, now)
	local key = string.format("%s:%s:%s", tostring(open), tostring(building), table.concat(s, ","))
	if visual[player] ~= key then
		visual[player] = key
		PlotService.setScaffold(model :: Model, building, ArtOtterPond.WIDTH, ArtOtterPond.DEPTH, 4)
		ArtOtterPond.setState(model :: Model, if open then "Open" else "Dry")
		if open then
			ArtOtterPond.setOtters(model :: Model, s)
		end
	end
	local gui = (model :: Model):FindFirstChild("TimerGui", true)
	local text = gui and gui:FindFirstChild("Text") :: TextLabel?
	if text then
		text.Text = boardText(data, now)
	end
end

-- A toast when an otter comes back while its owner is here
local announced: { [Player]: { [number]: number } } = {}
local function tick(player: Player)
	local data = DataService.get(player)
	if data == nil or data.otterPond == nil then
		return
	end
	local now = Clock.now()
	announced[player] = announced[player] or {}
	for i = 1, data.otterPond.otters or 1 do
		local trip = OtterPond.trip(data, i)
		if trip and now >= trip.readyAt and announced[player][i] ~= trip.readyAt then
			announced[player][i] = trip.readyAt
			if now - trip.readyAt < 5 then
				NetService.toast(player, "An otter is back with its catch. Tap the shells by its hut to collect.")
			end
		end
	end
end

function OtterPondService.init()
	PlotService.addFeature("otters", {
		refresh = refresh,
		model = function(plot: Model): Instance?
			return plot:FindFirstChild("OtterPond")
		end,
	})
	NetService.on(Net.Otter_Build, 1, 2, OtterPondService.build)
	NetService.on(Net.Otter_SpeedUp, 1, 2, OtterPondService.speedUp)
	NetService.on(Net.Otter_Buy, 1, 2, OtterPondService.buyOtter)
	NetService.on(Net.Otter_Feed, 1, 3, OtterPondService.feed)
	NetService.on(Net.Otter_Collect, 1, 3, OtterPondService.collect)
	NetService.on(Net.Otter_Skip, 1, 2, OtterPondService.skip)

	Players.PlayerRemoving:Connect(function(player)
		visual[player] = nil
		announced[player] = nil
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

return OtterPondService
