--!strict
-- The Tool Trader (Township's Tool Exchange; Config/ToolTrader, shared/ToolTrader): an empty
-- lot turns up on the farm at level 60 (placed like any building, Layout kind "trader").
-- Build it once and its first offer slot opens; two more can be bought. Each offer trades
-- Bricks, Panes or Planks for power tools, which Community Buildings need from level 60.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtToolTrader = require(Shared.Art.ToolTrader)
local Config = require(Shared.Config.ToolTrader)
local Items = require(Shared.Items)
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)
local Palette = require(Shared.Art.Palette)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local ToolTrader = require(Shared.ToolTrader)
local TownRules = require(Shared.TownRules)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local ToolTraderService = {}

local KEY = Layout.key("trader", "ToolTrader")
local visual: { [Player]: string } = {}
local placing: { [Player]: boolean } = {}

local function changed(player: Player)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.pushState(player)
end

local function name(id: string): string
	local def = Items[id]
	return if def then def.displayName else id
end

---------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------

function ToolTraderService.build(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = ToolTrader.canBuild(data, TownRules.population(data, now))
	if not ok then
		return false, reason
	end
	if not EconomyService.spend(player, "Coins", Config.buildCoins, "trader_build") then
		return false, string.format("The Tool Trader costs %d Coins", Config.buildCoins)
	end
	ToolTrader.build(data, now, Random.new():NextInteger(1, 2147483646), Clock.getTimeScale())
	EconomyService.add(player, "XP", Config.buildXp, "trader_build")
	TelemetryService.custom(player, "TraderBuild", 0, "ToolTrader")
	changed(player)
	return true
end

function ToolTraderService.speedUp(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local readyAt = data.toolTrader.readyAt
	local now = Clock.now()
	if readyAt == nil or now >= readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(readyAt - now), "speedup_trader") then
		return false, "Not enough Gems"
	end
	ToolTrader.finishBuild(data, now)
	ToolTrader.settle(data, now)
	changed(player)
	return true
end

function ToolTraderService.buySlot(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = ToolTrader.canBuySlot(data, now)
	if not ok then
		return false, reason
	end
	local coins = ToolTrader.nextSlotCoins(data) :: number
	if not EconomyService.spend(player, "Coins", coins, "trader_slot") then
		return false, string.format("Another slot costs %d Coins", coins)
	end
	ToolTrader.buySlot(data, now)
	NetService.toast(player, "A new offer slot opened at the Tool Trader.")
	changed(player)
	return true
end

function ToolTraderService.trade(player: Player, slot: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	ToolTrader.settle(data, now)
	local ok, reason = ToolTrader.canTrade(data, slot, now)
	if not ok then
		return false, reason
	end
	local offer = ToolTrader.offer(data, slot) :: ToolTrader.Offer
	local cost = offer.cost :: { [string]: number }
	local tools = offer.tools :: { [string]: number }
	if not InventoryService.has(player, cost) then
		return false, "You need " .. ToolTrader.describe(cost, name) .. " in the Barn"
	end
	-- The materials go first, so the tools always have room (an offer asks for more items
	-- than it gives); if they somehow don't fit, the materials come back
	InventoryService.remove(player, cost)
	if not InventoryService.add(player, tools) then
		InventoryService.add(player, cost)
		return false, "The Barn is full"
	end
	ToolTrader.trade(data, slot)
	NetService.toast(player, "Traded for " .. ToolTrader.describe(tools, name) .. ".")
	TelemetryService.custom(player, "TraderTrade", 0, "ToolTrader")
	changed(player)
	return true
end

function ToolTraderService.dump(player: Player, slot: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	if not ToolTrader.canDump(data, slot, now) then
		return false
	end
	ToolTrader.dump(data, slot, now, Clock.getTimeScale())
	changed(player)
	return true
end

function ToolTraderService.skip(player: Player, slot: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	if type(slot) ~= "number" then
		return false
	end
	local offer = ToolTrader.offer(data, slot)
	local now = Clock.now()
	if offer == nil or offer.waitUntil == nil or now >= offer.waitUntil then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.production(offer.waitUntil - now), "speedup_trader") then
		return false, "Not enough Gems"
	end
	ToolTrader.skip(data, slot, now)
	changed(player)
	return true
end

---------------------------------------------------------------------------------------------
-- The trader on the plot
---------------------------------------------------------------------------------------------

local function build(player: Player, plot: Model, spot: Layout.Spot): Model?
	local origin = PlotService.originCFrame(player)
	if origin == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "ToolTrader"
	model:SetAttribute("LayoutKey", KEY)
	local base = origin * CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.r), 0)
	model:SetAttribute("BaseCFrame", base)
	local parts = ArtToolTrader.build(model, base)
	PlotService.label(parts.body, "Tool Trader", 3, UDim2.fromOffset(150, 28), 60)
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
	ArtToolTrader.setState(model, "Lot")
	model.Parent = plot
	return model
end

-- Where the trader stands: its saved spot, or (the first time) the nearest open spot to the
-- player, saved and offered for placing
local function spotFor(player: Player, data: { [string]: any }): Layout.Spot?
	local spot = Layout.spot(data, KEY)
	if spot or placing[player] then
		return spot
	end
	placing[player] = true
	spot = PlotService.findOpenSpot(player, data, "trader", PlotService.nearPlayer(player))
	placing[player] = nil
	if spot == nil then
		return nil
	end
	data.layout[KEY] = spot
	DataService.markDirty(player, true)
	NetService.toast(
		player,
		"A lot for a Tool Trader turned up on your farm. Walk it where you like, then tap its counter."
	)
	PlotService.offerPlace(player, data, KEY)
	return spot
end

local function boardText(data: { [string]: any }, now: number): string
	local trader = data.toolTrader
	if trader.readyAt == nil then
		return "Coming soon"
	elseif now < trader.readyAt then
		return "Building\n" .. Timer.format(trader.readyAt - now)
	end
	for i = 1, trader.slots or 1 do
		local offer = ToolTrader.offer(data, i)
		if offer and offer.tools then
			return "Offers!"
		end
	end
	return "New offers soon"
end

local function refresh(player: Player, plot: Model, data: { [string]: any }, now: number)
	if not Layout.exists(data, "trader", "ToolTrader") then
		return
	end
	local model = plot:FindFirstChild("ToolTrader")
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
	local trader = data.toolTrader
	local building = trader.readyAt ~= nil and now < trader.readyAt
	local open = ToolTrader.isOpen(data, now)
	local key = string.format("%s:%s:%d", tostring(open), tostring(building), trader.slots or 1)
	if visual[player] ~= key then
		visual[player] = key
		PlotService.setScaffold(model :: Model, building, ArtToolTrader.SIZE, ArtToolTrader.SIZE, 6)
		ArtToolTrader.setState(model :: Model, if open or building then "Open" else "Lot")
		ArtToolTrader.setSlots(model :: Model, if open then trader.slots or 1 else 0)
	end
	local gui = (model :: Model):FindFirstChild("TimerGui", true)
	local text = gui and gui:FindFirstChild("Text") :: TextLabel?
	if text then
		text.Text = boardText(data, now)
	end
end

-- New offers once a dump's wait is over (and the first ones once it's built)
local function tick(player: Player)
	local data = DataService.get(player)
	if data == nil or data.toolTrader == nil then
		return
	end
	if ToolTrader.settle(data, Clock.now()) then
		DataService.markDirty(player, true)
		PlotService.refresh(player)
		NetService.pushState(player)
	end
end

function ToolTraderService.init()
	PlotService.addFeature("trader", {
		refresh = refresh,
		model = function(plot: Model): Instance?
			return plot:FindFirstChild("ToolTrader")
		end,
	})
	NetService.on(Net.Trader_Build, 1, 2, ToolTraderService.build)
	NetService.on(Net.Trader_SpeedUp, 1, 2, ToolTraderService.speedUp)
	NetService.on(Net.Trader_BuySlot, 1, 2, ToolTraderService.buySlot)
	NetService.on(Net.Trader_Trade, 1, 3, ToolTraderService.trade)
	NetService.on(Net.Trader_Dump, 1, 3, ToolTraderService.dump)
	NetService.on(Net.Trader_Skip, 1, 3, ToolTraderService.skip)

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

return ToolTraderService
