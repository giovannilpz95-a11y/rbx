--!strict
-- The Duck Pond (Township's Duck Feeder; Config/DuckPond, shared/DuckPond): an overgrown pond
-- turns up on the farm at level 48 (placed like any building, Layout kind "pond"). Dig it out
-- once, then put a Bread, Bagel or Banana Bread in its feeder: ducks come, and when they leave
-- every duck has left a Down Feather and every drake a Colorful Feather too. How many come is
-- drawn when the food goes out.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtDuckPond = require(Shared.Art.DuckPond)
local Config = require(Shared.Config.DuckPond)
local DuckPond = require(Shared.DuckPond)
local Items = require(Shared.Items)
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)
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

local DuckPondService = {}

local KEY = Layout.key("pond", "DuckPond")
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

function DuckPondService.dig(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason = DuckPond.canDig(data)
	if not ok then
		return false, reason
	end
	if not EconomyService.spend(player, "Coins", Config.digCoins, "pond_dig") then
		return false, string.format("Digging out the Duck Pond costs %d Coins", Config.digCoins)
	end
	DuckPond.dig(data, Clock.now(), Random.new():NextInteger(1, 2147483646), Clock.getTimeScale())
	EconomyService.add(player, "XP", Config.digXp, "pond_dig")
	TelemetryService.custom(player, "PondDig", 0, "DuckPond")
	changed(player)
	return true
end

function DuckPondService.speedUp(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local readyAt = data.duckPond.readyAt
	local now = Clock.now()
	if readyAt == nil or now >= readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(readyAt - now), "speedup_pond") then
		return false, "Not enough Gems"
	end
	DuckPond.finishDig(data, now)
	changed(player)
	return true
end

function DuckPondService.feed(player: Player, food: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = DuckPond.canFeed(data, food, now)
	if not ok then
		return false, reason
	end
	local item = Config.foods[food].item
	if not InventoryService.remove(player, { [item] = 1 }) then
		return false, string.format("You need a %s in the Barn", Items[item].displayName)
	end
	local visit = DuckPond.feed(data, food, now, Clock.getTimeScale())
	NetService.toast(
		player,
		string.format(
			"%d %s came to the pond%s.",
			visit.ducks,
			if visit.ducks == 1 then "duck" else "ducks",
			if visit.drakes > 0 then string.format(", %d of them with green heads", visit.drakes) else ""
		)
	)
	changed(player)
	return true
end

function DuckPondService.collect(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local visit = data.duckPond.visit
	if visit == nil then
		return false, "Put some Bread in the feeder and ducks will come"
	elseif now < visit.readyAt then
		return false, "The ducks are still here: " .. Timer.format(visit.readyAt - now) .. " left"
	end
	local feathers = DuckPond.feathers(visit)
	if not InventoryService.add(player, feathers) then
		return false, "The Barn is full"
	end
	DuckPond.collect(data, now)
	for item, qty in feathers do
		EconomyService.add(player, "XP", Config.feathers[item].xp * qty, "pond_collect")
	end
	changed(player)
	return true
end

function DuckPondService.skip(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local visit = data.duckPond.visit
	local now = Clock.now()
	if visit == nil or now >= visit.readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.production(visit.readyAt - now), "speedup_pond") then
		return false, "Not enough Gems"
	end
	DuckPond.skip(data, now)
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
	model.Name = "DuckPond"
	model:SetAttribute("LayoutKey", KEY)
	local base = origin * CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.r), 0)
	model:SetAttribute("BaseCFrame", base)
	local parts = ArtDuckPond.build(model, base)
	PlotService.label(parts.body, "Duck Pond", 3, UDim2.fromOffset(150, 28), 60)
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
	ArtDuckPond.setState(model, "Overgrown")
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
	spot = PlotService.findOpenSpot(player, data, "pond", PlotService.nearPlayer(player))
	placing[player] = nil
	if spot == nil then
		return nil
	end
	data.layout[KEY] = spot
	DataService.markDirty(player, true)
	NetService.toast(
		player,
		"An overgrown pond turned up on your farm. Walk it where you like, then tap it to dig it out."
	)
	PlotService.offerPlace(player, data, KEY)
	return spot
end

local function boardText(data: { [string]: any }, now: number): string
	local pond = data.duckPond
	if pond.readyAt == nil then
		return "Needs digging out"
	elseif now < pond.readyAt then
		return "Digging\n" .. Timer.format(pond.readyAt - now)
	elseif pond.visit == nil then
		return "Feed the ducks"
	elseif now < pond.visit.readyAt then
		return "Ducks visiting\n" .. Timer.format(pond.visit.readyAt - now)
	end
	return "Feathers ready!"
end

local function refresh(player: Player, plot: Model, data: { [string]: any }, now: number)
	if not Layout.exists(data, "pond", "DuckPond") then
		return
	end
	local model = plot:FindFirstChild("DuckPond")
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
	local pond = data.duckPond
	local digging = pond.readyAt ~= nil and now < pond.readyAt
	local open = DuckPond.isOpen(data, now)
	local visit = pond.visit
	local ducks = if visit then visit.ducks else 0
	local drakes = if visit then visit.drakes else 0
	local done = DuckPond.isDone(data, now)
	local key = string.format("%s:%s:%d:%d:%s", tostring(open), tostring(digging), ducks, drakes, tostring(done))
	if visual[player] ~= key then
		visual[player] = key
		PlotService.setScaffold(model :: Model, digging, ArtDuckPond.SIZE, ArtDuckPond.SIZE, 4)
		ArtDuckPond.setState(model :: Model, if open then "Open" else "Overgrown")
		if open then
			-- The ducks swim off once their feathers are waiting
			ArtDuckPond.setDucks(model :: Model, if done then 0 else ducks, drakes, done)
		end
	end
	local gui = (model :: Model):FindFirstChild("TimerGui", true)
	local text = gui and gui:FindFirstChild("Text") :: TextLabel?
	if text then
		text.Text = boardText(data, now)
	end
end

-- A toast when the ducks leave while their owner is here
local announced: { [Player]: number } = {}
local function tick(player: Player)
	local data = DataService.get(player)
	if data == nil or data.duckPond == nil then
		return
	end
	local visit = data.duckPond.visit
	local now = Clock.now()
	if visit and now >= visit.readyAt and announced[player] ~= visit.readyAt then
		announced[player] = visit.readyAt
		if now - visit.readyAt < 5 then
			NetService.toast(player, "The ducks have gone and left feathers by the pond. Tap the pond to collect them.")
		end
	end
end

function DuckPondService.init()
	PlotService.addFeature("pond", {
		refresh = refresh,
		model = function(plot: Model): Instance?
			return plot:FindFirstChild("DuckPond")
		end,
	})
	NetService.on(Net.Pond_Dig, 1, 2, DuckPondService.dig)
	NetService.on(Net.Pond_SpeedUp, 1, 2, DuckPondService.speedUp)
	NetService.on(Net.Pond_Feed, 1, 3, DuckPondService.feed)
	NetService.on(Net.Pond_Collect, 1, 3, DuckPondService.collect)
	NetService.on(Net.Pond_Skip, 1, 2, DuckPondService.skip)

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

return DuckPondService
