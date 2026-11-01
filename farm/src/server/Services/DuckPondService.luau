--!strict
-- The Duck Pond (Township's Duck Feeder; Config/DuckPond, shared/DuckPond): an overgrown pond
-- turns up on the farm at level 48 (placed like any building, Layout kind "pond"). Dig it out
-- once, then put a Bread, Bagel or Banana Bread in its feeder: ducks come, and when they leave
-- every duck has left a Down Feather and every drake a Colorful Feather too. How many come is
-- drawn when the food goes out. A second pond, the Willow Pond, turns up at level 73
-- (Township's second Duck Feeder) and works the same way with its own visits.
--
-- Every remote takes the pond id last ("DuckPond" when left out, as older clients send).

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

local visual: { [Player]: { [string]: string } } = {}
local placing: { [Player]: { [string]: boolean } } = {}

-- The pond a request names, or nil when it names none we know
local function pondId(id: any): string?
	if id == nil then
		return "DuckPond"
	elseif type(id) == "string" and Config.ponds[id] then
		return id
	end
	return nil
end

local function perPlayer<T>(map: { [Player]: { [string]: T } }, player: Player): { [string]: T }
	local mine = map[player]
	if mine == nil then
		mine = {}
		map[player] = mine
	end
	return mine
end

local function changed(player: Player)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.pushState(player)
end

---------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------

function DuckPondService.dig(player: Player, which: any): (boolean, string?)
	local id = pondId(which)
	if id == nil then
		return false
	end
	local def = Config.ponds[id]
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason = DuckPond.canDig(data, id)
	if not ok then
		return false, reason
	end
	if not EconomyService.spend(player, "Coins", def.digCoins, "pond_dig") then
		return false, string.format("Digging out the %s costs %d Coins", def.displayName, def.digCoins)
	end
	DuckPond.dig(data, Clock.now(), Random.new():NextInteger(1, 2147483646), Clock.getTimeScale(), id)
	EconomyService.add(player, "XP", def.digXp, "pond_dig")
	TelemetryService.custom(player, "PondDig", 0, id)
	changed(player)
	return true
end

function DuckPondService.speedUp(player: Player, which: any): (boolean, string?)
	local id = pondId(which)
	if id == nil then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local readyAt = DuckPond.record(data, id).readyAt
	local now = Clock.now()
	if readyAt == nil or now >= readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(readyAt - now), "speedup_pond") then
		return false, "Not enough Gems"
	end
	DuckPond.finishDig(data, now, id)
	changed(player)
	return true
end

function DuckPondService.feed(player: Player, food: any, which: any): (boolean, string?)
	local id = pondId(which)
	if id == nil then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = DuckPond.canFeed(data, food, now, id)
	if not ok then
		return false, reason
	end
	local item = Config.foods[food].item
	if not InventoryService.remove(player, { [item] = 1 }) then
		return false, string.format("You need a %s in the Barn", Items[item].displayName)
	end
	local visit = DuckPond.feed(data, food, now, Clock.getTimeScale(), id)
	NetService.toast(
		player,
		string.format(
			"%d %s came to the %s%s.",
			visit.ducks,
			if visit.ducks == 1 then "duck" else "ducks",
			Config.ponds[id].displayName,
			if visit.drakes > 0 then string.format(", %d of them with green heads", visit.drakes) else ""
		)
	)
	changed(player)
	return true
end

function DuckPondService.collect(player: Player, which: any): (boolean, string?)
	local id = pondId(which)
	if id == nil then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local visit = DuckPond.record(data, id).visit
	if visit == nil then
		return false, "Put some Bread in the feeder and ducks will come"
	elseif now < visit.readyAt then
		return false, "The ducks are still here: " .. Timer.format(visit.readyAt - now) .. " left"
	end
	local feathers = DuckPond.feathers(visit)
	if not InventoryService.add(player, feathers) then
		return false, "The Barn is full"
	end
	DuckPond.collect(data, now, id)
	for item, qty in feathers do
		EconomyService.add(player, "XP", Config.feathers[item].xp * qty, "pond_collect")
	end
	changed(player)
	return true
end

function DuckPondService.skip(player: Player, which: any): (boolean, string?)
	local id = pondId(which)
	if id == nil then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local visit = DuckPond.record(data, id).visit
	local now = Clock.now()
	if visit == nil or now >= visit.readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.production(visit.readyAt - now), "speedup_pond") then
		return false, "Not enough Gems"
	end
	DuckPond.skip(data, now, id)
	changed(player)
	return true
end

---------------------------------------------------------------------------------------------
-- The pond on the plot
---------------------------------------------------------------------------------------------

local function build(player: Player, plot: Model, spot: Layout.Spot, id: string): Model?
	local origin = PlotService.originCFrame(player)
	if origin == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("LayoutKey", Layout.key("pond", id))
	model:SetAttribute("PondId", id) -- which pond a tap opens (ReachController)
	local base = origin * CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.r), 0)
	model:SetAttribute("BaseCFrame", base)
	local parts = ArtDuckPond.build(model, base)
	PlotService.label(parts.body, Config.ponds[id].displayName, 3, UDim2.fromOffset(150, 28), 60)
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
local function spotFor(player: Player, data: { [string]: any }, id: string): Layout.Spot?
	local key = Layout.key("pond", id)
	local spot = Layout.spot(data, key)
	local busy = perPlayer(placing, player)
	if spot or busy[id] then
		return spot
	end
	busy[id] = true
	spot = PlotService.findOpenSpot(player, data, "pond", PlotService.nearPlayer(player))
	busy[id] = nil
	if spot == nil then
		return nil
	end
	data.layout[key] = spot
	DataService.markDirty(player, true)
	NetService.toast(
		player,
		if id == "DuckPond"
			then "An overgrown pond turned up on your farm. Walk it where you like, then tap it to dig it out."
			else "A second overgrown pond, the Willow Pond, turned up on your farm. Walk it where you like, then tap it to dig it out."
	)
	PlotService.offerPlace(player, data, key)
	return spot
end

local function boardText(pond: { [string]: any }, now: number): string
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

local function refreshPond(player: Player, plot: Model, data: { [string]: any }, now: number, id: string)
	if not Layout.exists(data, "pond", id) then
		return
	end
	local seen = perPlayer(visual, player)
	local model = plot:FindFirstChild(id)
	if model == nil then
		local spot = spotFor(player, data, id)
		if spot == nil then
			return
		end
		model = build(player, plot, spot, id)
		seen[id] = nil
		if model == nil then
			return
		end
	end
	local pond = DuckPond.record(data, id)
	local digging = pond.readyAt ~= nil and now < pond.readyAt
	local open = DuckPond.isOpen(data, now, id)
	local visit = pond.visit
	local ducks = if visit then visit.ducks else 0
	local drakes = if visit then visit.drakes else 0
	local done = DuckPond.isDone(data, now, id)
	local key = string.format("%s:%s:%d:%d:%s", tostring(open), tostring(digging), ducks, drakes, tostring(done))
	if seen[id] ~= key then
		seen[id] = key
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
		text.Text = boardText(pond, now)
	end
end

local function refresh(player: Player, plot: Model, data: { [string]: any }, now: number)
	for id in Config.ponds do
		refreshPond(player, plot, data, now, id)
	end
end

-- A toast when the ducks leave while their owner is here
local announced: { [Player]: { [string]: number } } = {}
local function tick(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local now = Clock.now()
	local told = perPlayer(announced, player)
	for id, def in Config.ponds do
		local pond = data[def.save]
		local visit = pond and pond.visit
		if visit and now >= visit.readyAt and told[id] ~= visit.readyAt then
			told[id] = visit.readyAt
			if now - visit.readyAt < 5 then
				NetService.toast(
					player,
					string.format(
						"The ducks have gone and left feathers by the %s. Tap it to collect them.",
						def.displayName
					)
				)
			end
		end
	end
end

function DuckPondService.init()
	PlotService.addFeature("pond", {
		refresh = refresh,
		model = function(plot: Model, id: string): Instance?
			return plot:FindFirstChild(id)
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
