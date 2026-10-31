--!strict
-- Harbor & Far Isles (Features/F02, shared/Harbor): the old Harbor stands on the farm from
-- level 29 (placed like any building, Layout kind "harbor"). Repair it once and its first
-- Sailboat can sail to Blossom Cay; later isles open with Coins and tools, more boats are
-- bought, and a Ballast Bar sent along raises the odds of the rarer goods and a Sea Chest.
-- Everything a boat brings is rolled when it leaves. A Driftwood Crate washes up once a day.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtHarbor = require(Shared.Art.Harbor)
local Config = require(Shared.Config.Isles)
local DailyRules = require(Shared.Daily)
local Harbor = require(Shared.Harbor)
local Items = require(Shared.Items)
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)
local Palette = require(Shared.Art.Palette)
local QuarryConfig = require(Shared.Config.Quarry)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local HarborService = {}

local KEY = Layout.key("harbor", "Harbor")
local visual: { [Player]: string } = {}
local placing: { [Player]: boolean } = {}

local function changed(player: Player)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	NetService.pushState(player)
end

local function names(prize: { item: string, qty: number }): string
	local tool = Tools.tools[prize.item]
	local name = if tool
		then (if prize.qty == 1 then tool.displayName else tool.plural)
		elseif prize.item == QuarryConfig.pickaxe then (if prize.qty == 1 then "Pickaxe" else "Pickaxes")
		elseif Items[prize.item] then Items[prize.item].displayName
		else prize.item
	return string.format("%d %s", prize.qty, name)
end
HarborService.prizeName = names

-- Hand over a prize: Gems and Coins to the wallet, tools and Pickaxes to the Tool Shed, the
-- rest to the Barn (prizes go in even past the Barn's cap, like the level-up gifts)
local function give(player: Player, data: { [string]: any }, item: string, qty: number, reason: string)
	if item == "Gems" or item == "Coins" then
		EconomyService.add(player, item, qty, reason)
	elseif Tools.tools[item] or item == QuarryConfig.pickaxe then
		data.toolShed.items[item] = (data.toolShed.items[item] or 0) + qty
	else
		data.inventory.items[item] = (data.inventory.items[item] or 0) + qty
	end
end

---------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------

function HarborService.repair(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason = Harbor.canRepair(data)
	if not ok then
		return false, reason
	end
	if not EconomyService.spend(player, "Coins", Config.repairCoins, "harbor_repair") then
		return false, string.format("Repairing the Harbor costs %d Coins", Config.repairCoins)
	end
	Harbor.repair(data, Clock.now(), Random.new():NextInteger(1, 2147483646), Clock.getTimeScale())
	EconomyService.add(player, "XP", Config.repairXp, "harbor_repair")
	TelemetryService.custom(player, "HarborRepair", 0, "Harbor")
	changed(player)
	return true
end

function HarborService.speedUp(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local readyAt = data.harbor.readyAt
	local now = Clock.now()
	if readyAt == nil or now >= readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(readyAt - now), "speedup_harbor") then
		return false, "Not enough Gems"
	end
	Harbor.finishRepair(data, now)
	changed(player)
	return true
end

function HarborService.buyBoat(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local price, reason = Harbor.canBuyBoat(data, Clock.now())
	if price == nil then
		return false, reason
	end
	if price > 0 and not EconomyService.spend(player, "Coins", price, "harbor_boat") then
		return false, string.format("The next Sailboat costs %d Coins", price)
	end
	Harbor.buyBoat(data)
	TelemetryService.custom(player, "HarborBoat", #data.harbor.boats, "Harbor")
	changed(player)
	NetService.toast(player, "A new Sailboat is tied up at your Harbor")
	return true
end

function HarborService.unlockIsle(player: Player, isleId: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local ok, reason = Harbor.canUnlockIsle(data, isleId, now)
	if not ok then
		return false, reason
	end
	local def = Config.byId[isleId]
	local shed = data.toolShed.items
	for tool in Tools.tools do
		if (shed[tool] or 0) < def.unlockTools then
			return false,
				string.format("Reaching %s takes %d each of Shovels, Axes and Saws", def.displayName, def.unlockTools)
		end
	end
	if def.unlockCoins > 0 and not EconomyService.spend(player, "Coins", def.unlockCoins, "harbor_isle") then
		return false, string.format("Reaching %s costs %d Coins", def.displayName, def.unlockCoins)
	end
	for tool in Tools.tools do
		shed[tool] -= def.unlockTools
	end
	Harbor.unlockIsle(data, def.id, now, Clock.getTimeScale())
	if def.unlockXp > 0 then
		EconomyService.add(player, "XP", def.unlockXp, "harbor_isle")
	end
	TelemetryService.custom(player, "HarborIsle", def.order, def.id)
	changed(player)
	return true
end

function HarborService.finishIsle(player: Player, isleId: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local entry = type(isleId) == "string" and data.harbor.isles[isleId] or nil
	local now = Clock.now()
	if entry == nil or entry.readyAt == nil or now >= entry.readyAt then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.building(entry.readyAt - now), "speedup_isle") then
		return false, "Not enough Gems"
	end
	Harbor.finishIsle(data, isleId, now)
	changed(player)
	return true
end

-- Send a boat to an isle with an optional Ballast Bar from the Barn
function HarborService.send(player: Player, index: any, isleId: any, bar: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	if bar == false or bar == "" then
		bar = nil
	end
	local cost, reason = Harbor.canSend(data, index, isleId, bar, now)
	if cost == nil then
		return false, reason
	end
	if bar ~= nil and InventoryService.count(player, bar) < 1 then
		return false, string.format("You have no %s", Items[bar].displayName)
	end
	if not EconomyService.spend(player, "Coins", cost, "harbor_send") then
		return false, string.format("Sending a Sailboat there costs %d Coins", cost)
	end
	if bar ~= nil then
		InventoryService.remove(player, { [bar] = 1 })
	end
	Harbor.send(data, index, isleId, bar, now, Clock.getTimeScale())
	TelemetryService.custom(player, "HarborSend", Config.byId[isleId].order, if bar then bar else "NoBar")
	changed(player)
	return true
end

-- Unload a boat that's back: its crates into the Barn (they need room) and any Sea Chest
function HarborService.unload(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local boat = Harbor.boat(data, index)
	if boat == nil or boat.isle == nil then
		return false
	elseif not Harbor.isBack(boat, now) then
		return false, "That Sailboat is still at sea"
	end
	local units = Harbor.cargoUnits(boat)
	if InventoryService.space(player) < units then
		return false, string.format("Make room for %d goods in your Barn first", units)
	end
	local isle = Config.byId[boat.isle :: string]
	local firstTrip = (data.harbor.trips[isle.id] or 0) == 0
	local cargo, chest = Harbor.unload(data, index, now)
	if cargo == nil then
		return false
	end
	local goods, parts = {}, {}
	for _, crate in cargo do
		goods[crate.item] = (goods[crate.item] or 0) + crate.qty
		table.insert(parts, names(crate))
	end
	InventoryService.add(player, goods)
	local xp = 0
	for _, crate in cargo do
		xp += Items[crate.item].xpPerUnit * crate.qty
	end
	if xp > 0 then
		EconomyService.add(player, "XP", xp, "harbor_cargo")
	end
	local text = string.format("Back from %s: %s", isle.displayName, table.concat(parts, ", "))
	if chest then
		give(player, data, chest.item, chest.qty, "harbor_chest")
		text ..= string.format(". Sea Chest: %s!", names(chest))
	end
	if firstTrip then
		text ..= ". Townsfolk can now ask for " .. isle.displayName .. "'s goods on the Order Board."
	end
	TelemetryService.custom(player, "HarborUnload", #cargo, isle.id)
	changed(player)
	NetService.popup(player, { kind = "Crier", text = text })
	return true
end

function HarborService.skip(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local boat = Harbor.boat(data, index)
	if boat == nil or boat.returnAt == nil or now >= boat.returnAt then
		return false
	end
	local cost = Harbor.skipCost(boat, now)
	if cost > 0 and not EconomyService.spend(player, "Gems", cost, "skip_boat") then
		return false, "Not enough Gems"
	end
	Harbor.skip(boat, now)
	changed(player)
	return true
end

function HarborService.drift(player: Player): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local now = Clock.now()
	local day = DailyRules.utcDay(now)
	local ok, reason = Harbor.canOpenDrift(data, day, now)
	if not ok then
		return false, reason
	end
	local prize = Harbor.openDrift(data, day, now)
	give(player, data, prize.item, prize.qty, "harbor_drift")
	TelemetryService.custom(player, "HarborDrift", 1, "Harbor")
	changed(player)
	NetService.popup(player, { kind = "Crier", text = "The Driftwood Crate held " .. names(prize) })
	return true
end

---------------------------------------------------------------------------------------------
-- The Harbor on the plot
---------------------------------------------------------------------------------------------

local function build(player: Player, plot: Model, spot: Layout.Spot): Model?
	local origin = PlotService.originCFrame(player)
	if origin == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Harbor"
	model:SetAttribute("LayoutKey", KEY)
	local base = origin * CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.r), 0)
	model:SetAttribute("BaseCFrame", base)
	local parts = ArtHarbor.build(model, base)
	PlotService.label(parts.body, "Harbor", 6, UDim2.fromOffset(150, 28), 60)
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
	ArtHarbor.setState(model, "Broken")
	model.Parent = plot
	return model
end

-- Where the Harbor stands: its saved spot, or (the first time) the nearest open spot to the
-- player, saved and offered for placing
local function spotFor(player: Player, data: { [string]: any }): Layout.Spot?
	local spot = Layout.spot(data, KEY)
	if spot or placing[player] then
		return spot
	end
	placing[player] = true
	spot = PlotService.findOpenSpot(player, data, "harbor", PlotService.nearPlayer(player))
	placing[player] = nil
	if spot == nil then
		return nil
	end
	data.layout[KEY] = spot
	DataService.markDirty(player, true)
	NetService.toast(player, "An old Harbor stands on your farm now. Walk it where you like, then tap it to repair it.")
	PlotService.offerPlace(player, data, KEY)
	return spot
end

local function boardText(data: { [string]: any }, now: number): string
	local harbor = data.harbor
	if harbor.readyAt == nil then
		return "Needs repair"
	elseif now < harbor.readyAt then
		return "Repairing\n" .. Timer.format(harbor.readyAt - now)
	end
	local back, soonest = 0, math.huge
	for _, boat in harbor.boats do
		if boat.returnAt then
			if now >= boat.returnAt then
				back += 1
			else
				soonest = math.min(soonest, boat.returnAt - now)
			end
		end
	end
	if back > 0 then
		return string.format("%d %s back!", back, if back == 1 then "boat" else "boats")
	elseif soonest < math.huge then
		return "Next boat\n" .. Timer.format(soonest)
	end
	return "Boats ready"
end

local function refresh(player: Player, plot: Model, data: { [string]: any }, now: number)
	if not Layout.exists(data, "harbor", "Harbor") then
		return
	end
	local model = plot:FindFirstChild("Harbor")
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
	local harbor = data.harbor
	local repairing = harbor.readyAt ~= nil and now < harbor.readyAt
	local repaired = Harbor.isRepaired(data, now)
	local boats = {}
	local marks = {}
	for i, boat in harbor.boats do
		local state = if boat.isle == nil then "home" elseif Harbor.isBack(boat, now) then "back" else "away"
		boats[i] = state
		table.insert(marks, state)
	end
	local drift = repaired and harbor.driftDay ~= DailyRules.utcDay(now)
	local key =
		string.format("%s:%s:%s:%s", tostring(repaired), tostring(repairing), table.concat(marks, ","), tostring(drift))
	if visual[player] ~= key then
		visual[player] = key
		PlotService.setScaffold(model :: Model, repairing, ArtHarbor.WIDTH, ArtHarbor.DEPTH, 7)
		ArtHarbor.setState(model :: Model, if repaired then "Repaired" else "Broken")
		if repaired then
			ArtHarbor.setBoats(model :: Model, boats)
			ArtHarbor.setDrift(model :: Model, drift)
		end
	end
	local gui = (model :: Model):FindFirstChild("TimerGui", true)
	local text = gui and gui:FindFirstChild("Text") :: TextLabel?
	if text then
		text.Text = boardText(data, now)
	end
end

-- A toast when a boat gets home while its owner is here (PlotService's own 1 s refresh
-- updates the model)
local announced: { [Player]: { [number]: number } } = {}
local function tick(player: Player)
	local data = DataService.get(player)
	if data == nil or data.harbor == nil then
		return
	end
	local now = Clock.now()
	local seen = announced[player] or {}
	announced[player] = seen
	for i, boat in data.harbor.boats do
		if boat.returnAt and now >= boat.returnAt and seen[i] ~= boat.returnAt then
			seen[i] = boat.returnAt
			if boat.departAt and now - boat.returnAt < 5 then
				NetService.toast(
					player,
					string.format(
						"A Sailboat is back from %s. Tap it at your Harbor to unload.",
						Config.byId[boat.isle].displayName
					)
				)
			end
		end
	end
end

function HarborService.init()
	PlotService.addFeature("harbor", {
		refresh = refresh,
		model = function(plot: Model): Instance?
			return plot:FindFirstChild("Harbor")
		end,
	})
	NetService.on(Net.Harbor_Repair, 1, 2, HarborService.repair)
	NetService.on(Net.Harbor_SpeedUp, 1, 2, HarborService.speedUp)
	NetService.on(Net.Harbor_BuyBoat, 1, 2, HarborService.buyBoat)
	NetService.on(Net.Harbor_UnlockIsle, 1, 2, HarborService.unlockIsle)
	NetService.on(Net.Harbor_FinishIsle, 1, 2, HarborService.finishIsle)
	NetService.on(Net.Harbor_Send, 2, 4, HarborService.send)
	NetService.on(Net.Harbor_Unload, 2, 4, HarborService.unload)
	NetService.on(Net.Harbor_Skip, 2, 4, HarborService.skip)
	NetService.on(Net.Harbor_Drift, 1, 2, HarborService.drift)

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

return HarborService
