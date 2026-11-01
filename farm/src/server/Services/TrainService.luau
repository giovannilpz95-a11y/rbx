--!strict
-- The Train Station (Design/05 Train Station; Config/Train, shared/Train): the first train pulls
-- in at level 5, and two more can be bought at 14 and 25 (Coins). Each train waits at the
-- platform with cars asking for goods. Load what you can from the Barn (XP at once), send it
-- off, and a few hours later every loaded car brings back the reward shown on it, plus a bonus
-- when every car went out loaded. The station is placed like any building (Layout kind
-- "station"); each train has its own track in front of it.
--
--   Train_Load(train, car) | Train_Send(train) | Train_SpeedUp(train) | Train_Unload(train)
--   | Train_Buy() | Train_Flag(train, car)
--
-- Help Crates (level 7): one car a train can carry a help flag, and neighbors on the server
-- load it from their own Barns (Services/HelpService Help_Train). A flagged car is left out of
-- the train's union so its parts can carry what it asks for.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtMerge = require(Shared.Art.Merge)
local ArtRail = require(Shared.Art.Rail)
local Config = require(Shared.Config.Train)
local Items = require(Shared.Items)
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)
local Palette = require(Shared.Art.Palette)
local QuarryConfig = require(Shared.Config.Quarry)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local Tools = require(Shared.Config.Tools)
local Train = require(Shared.Train)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local TrainService = {}

local ID = "Station"
local KEY = Layout.key("station", ID)

local visual: { [Player]: { [string]: string } } = {}
local placing: { [Player]: boolean } = {}
local announced: { [Player]: { [number]: number } } = {}

local function perPlayer<T>(map: { [Player]: { [any]: T } }, player: Player): { [any]: T }
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
TrainService.changed = changed

-- A reward's name with its count ("2 Pickaxes", "1 Bricks")
function TrainService.rewardName(item: string, qty: number): string
	local tool = Tools.tools[item]
	local name = if tool
		then (if qty == 1 then tool.displayName else tool.plural)
		elseif item == QuarryConfig.pickaxe then (if qty == 1 then "Pickaxe" else "Pickaxes")
		elseif Items[item] then Items[item].displayName
		else item
	return string.format("%d %s", qty, name)
end

-- Rewards go past the Barn's cap (as the Town Express); tools and Pickaxes to the Tool Shed
local function give(data: { [string]: any }, rewards: { [string]: number })
	for item, qty in rewards do
		if Tools.tools[item] or item == QuarryConfig.pickaxe then
			data.toolShed.items[item] = (data.toolShed.items[item] or 0) + qty
		else
			data.inventory.items[item] = (data.inventory.items[item] or 0) + qty
		end
	end
end

local function describe(rewards: { [string]: number }): string
	local parts = {}
	for item, qty in rewards do
		table.insert(parts, TrainService.rewardName(item, qty))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

---------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------

-- The first train turns up when the farm reaches the Station's level (any action, or a refresh)
local function ensure(player: Player, data: { [string]: any }): boolean
	if Train.ensure(data) then
		DataService.markDirty(player, true)
		return true
	end
	return false
end

function TrainService.load(player: Player, index: any, carIndex: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local car, reason = Train.canLoad(data, index, carIndex, Clock.now())
	if car == nil then
		return false, reason
	end
	if not InventoryService.remove(player, { [car.item] = car.qty }) then
		return false, string.format("That car needs %d %s from the Barn", car.qty, Items[car.item].displayName)
	end
	Train.load(car)
	EconomyService.add(player, "XP", Train.carXp(car), "train_load")
	changed(player)
	return true
end

function TrainService.send(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local line, reason = Train.canSend(data, index)
	if line == nil then
		return false, reason
	end
	Train.send(data, line, Clock.now(), Clock.getTimeScale())
	TelemetryService.custom(player, "TrainSend", Train.loadedCount(line), tostring(index))
	changed(player)
	return true
end

function TrainService.speedUp(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local line = Train.line(data, index)
	local now = Clock.now()
	if line == nil or not Train.isAway(line, now) then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.train((line.returnAt :: number) - now), "speedup_train") then
		return false, "Not enough Gems"
	end
	Train.speedUp(line, now)
	changed(player)
	return true
end

function TrainService.unload(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local rewards = Train.unload(data, index, Clock.now())
	if rewards == nil then
		return false
	end
	give(data, rewards)
	if next(rewards) then
		NetService.toast(player, "The train brought back " .. describe(rewards) .. ".")
	else
		NetService.toast(player, "The train came back empty. Load its cars before it goes next time.")
	end
	changed(player)
	return true
end

function TrainService.flag(player: Player, index: any, carIndex: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local ok, reason = Train.flag(data, index, carIndex, Clock.now())
	if not ok then
		return false, reason
	end
	changed(player)
	return true
end

-- Where car `carIndex` of an owner's train stands in the world (for a helper's reach check)
function TrainService.carPosition(owner: Player, index: number, carIndex: number): Vector3?
	local plot = PlotService.getPlot(owner)
	local station = plot and plot:FindFirstChild(ID)
	local train = station and station:FindFirstChild("Train" .. index)
	local car = train and train:FindFirstChild("Car" .. carIndex)
	if car and car:IsA("Model") then
		return car:GetPivot().Position
	end
	return nil
end

function TrainService.buy(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	ensure(player, data)
	local ok, reason = Train.canBuy(data)
	if not ok then
		return false, reason
	end
	local index, def = Train.nextTrain(data)
	if index == nil or def == nil then
		return false
	end
	if def.coins > 0 and not EconomyService.spend(player, "Coins", def.coins, "train_buy") then
		return false, string.format("Train %d costs %d Coins", index, def.coins)
	end
	Train.buy(data)
	TelemetryService.custom(player, "TrainBuy", index)
	NetService.toast(player, string.format("Train %d pulled into your station. Load its cars and send it off!", index))
	changed(player)
	return true
end

---------------------------------------------------------------------------------------------
-- The station on the plot
---------------------------------------------------------------------------------------------

local function boardLine(index: number, line: Train.Line, now: number): string
	if Train.isBack(line, now) then
		return string.format("%d  Back!", index)
	elseif Train.isAway(line, now) then
		return string.format("%d  %s", index, Timer.format((line.returnAt :: number) - now))
	end
	return string.format("%d  Loading %d/%d", index, Train.loadedCount(line), #line.cars)
end

local function build(player: Player, plot: Model, spot: Layout.Spot): Model?
	local origin = PlotService.originCFrame(player)
	if origin == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = ID
	model:SetAttribute("LayoutKey", KEY)
	local base = origin * CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, math.rad(spot.r), 0)
	model:SetAttribute("BaseCFrame", base)

	-- Everything that never moves (the station and the tracks) is merged into one union
	local static = Instance.new("Model")
	static.Name = "Static"
	static.Parent = model
	local _, platform, board = ArtRail.farmStation(static, base)
	platform:SetAttribute("Interact", "Train")
	platform:SetAttribute("Train", 0)
	PlotService.label(platform, "Train Station", 6, UDim2.fromOffset(150, 28), 80)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "TimerGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Palette.cream
	text.Text = ""
	text.Parent = surface
	surface.Parent = board
	board:SetAttribute("Interact", "Train")
	board:SetAttribute("Train", 0)

	model.Parent = plot
	task.spawn(ArtMerge.merge, static, platform)
	return model
end

-- A train at its track: the engine and its cars, each car's sign naming what it wants and
-- crates on the loaded ones. Merged into one union with its crates (each load rebuilds the
-- train); the signs stay apart.
local function buildTrain(model: Model, index: number, line: Train.Line)
	local base = model:GetAttribute("BaseCFrame") :: CFrame
	local holder = Instance.new("Model")
	holder.Name = "Train" .. index
	local engine, cars, signs = ArtRail.farmTrain(holder, base, index, #line.cars)
	for i, car in line.cars do
		ArtRail.setCarCrates(cars[i], if car.loaded then ArtRail.CAR_CRATES else 0)
		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Front
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 60
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = if car.loaded then Palette.leaf else Palette.cocoa
		text.Text = if car.loaded then "✓" else string.format("%d\n%s", car.qty, Items[car.item].displayName)
		text.Parent = surface
		surface.Parent = signs[i]
	end
	-- A tap anywhere on the train opens its panel (or unloads it once it's back)
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("Interact", "Train")
			d:SetAttribute("Train", index)
		end
	end
	-- A car flagged for help stays out of the union, and says what it wants, so a visiting
	-- neighbor can tap it
	local skip = {}
	for i, car in line.cars do
		if car.flagged and not car.loaded then
			skip[cars[i].Name] = true
			for _, d in cars[i]:GetDescendants() do
				if d:IsA("BasePart") then
					d:SetAttribute("Interact", "TrainCar")
					d:SetAttribute("Car", i)
					d:SetAttribute("Item", car.item)
					d:SetAttribute("Qty", car.qty)
					d.CanQuery = true
				end
			end
			PlotService.label(
				signs[i],
				string.format("Help: %d %s", car.qty, Items[car.item].displayName),
				2.5,
				UDim2.fromOffset(150, 26),
				120
			)
		end
	end
	holder.Parent = model
	local chassis = engine:FindFirstChild("Chassis") :: BasePart?
	if chassis then
		task.spawn(ArtMerge.merge, holder, chassis, { skip = skip })
	end
end

-- Where the station stands: its saved spot, or (the first time) the nearest open spot to the
-- player, saved and offered for placing
local function spotFor(player: Player, data: { [string]: any }): Layout.Spot?
	local spot = Layout.spot(data, KEY)
	if spot or placing[player] then
		return spot
	end
	placing[player] = true
	spot = PlotService.findOpenSpot(player, data, "station", PlotService.nearPlayer(player))
	placing[player] = nil
	if spot == nil then
		return nil
	end
	data.layout[KEY] = spot
	DataService.markDirty(player, true)
	NetService.toast(
		player,
		"Your first train has pulled into the new Train Station. Walk it where you like, then tap the train to load it."
	)
	if (data.tutorial and data.tutorial.step or 0) == 0 then
		PlotService.offerPlace(player, data, KEY)
	else
		-- The first-session guide is still running (it points at the usual spots): offer the
		-- placing once it's over
		data.trains.placeOffer = true
	end
	return spot
end

local function trainKey(line: Train.Line, now: number): string
	if Train.isAway(line, now) then
		return "away"
	end
	local parts = { if Train.isBack(line, now) then "back" else "here" }
	for _, car in line.cars do
		table.insert(parts, car.item .. (if car.loaded then "+" elseif car.flagged then "?" else "-"))
	end
	return table.concat(parts, ",")
end

local function refresh(player: Player, plot: Model, data: { [string]: any }, now: number)
	if not Layout.exists(data, "station", ID) then
		return
	end
	ensure(player, data)
	local seen = perPlayer(visual, player)
	local model = plot:FindFirstChild(ID) :: Model?
	if model == nil then
		local spot = spotFor(player, data)
		if spot == nil then
			return
		end
		model = build(player, plot, spot)
		table.clear(seen)
		if model == nil then
			return
		end
	end
	local station = model :: Model
	if data.trains.placeOffer and (data.tutorial and data.tutorial.step or 0) == 0 then
		data.trains.placeOffer = nil
		DataService.markDirty(player, true)
		NetService.toast(player, "Walk the Train Station where you like (Move works any time too).")
		PlotService.offerPlace(player, data, KEY)
	end
	local lines = Train.lines(data)
	local board = {}
	for index = 1, #ArtRail.FARM_LANES do
		local line = lines[index]
		local key = if line then trainKey(line, now) else "none"
		local name = "Train" .. index
		if seen[name] ~= key then
			seen[name] = key
			local old = station:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			if line and not Train.isAway(line, now) then
				buildTrain(station, index, line)
			end
		end
		if line then
			table.insert(board, boardLine(index, line, now))
		end
	end
	-- The Help Board in the Neighbors panel reads this
	if typeof(player) == "Instance" then
		player:SetAttribute("TrainHelp", Train.helpText(data))
	end
	local gui = station:FindFirstChild("TimerGui", true)
	local text = gui and gui:FindFirstChild("Text") :: TextLabel?
	if text then
		text.Text = table.concat(board, "\n")
	end
end

-- A toast when a train comes back while its owner is here
local function tick(player: Player)
	local data = DataService.get(player)
	if data == nil or data.trains == nil then
		return
	end
	local now = Clock.now()
	local told = perPlayer(announced, player)
	for index, line in Train.lines(data) do
		local returnAt = line.returnAt
		if returnAt and now >= returnAt and told[index] ~= returnAt then
			told[index] = returnAt
			if now - returnAt < 5 then
				NetService.toast(player, string.format("Train %d is back at the station. Tap it to unload.", index))
			end
		end
	end
end

function TrainService.init()
	PlotService.addFeature("station", {
		refresh = refresh,
		model = function(plot: Model, id: string): Instance?
			return plot:FindFirstChild(id)
		end,
	})
	NetService.on(Net.Train_Load, 2, 4, TrainService.load)
	NetService.on(Net.Train_Send, 1, 2, TrainService.send)
	NetService.on(Net.Train_SpeedUp, 1, 2, TrainService.speedUp)
	NetService.on(Net.Train_Unload, 1, 3, TrainService.unload)
	NetService.on(Net.Train_Buy, 1, 2, TrainService.buy)
	NetService.on(Net.Train_Flag, 2, 4, TrainService.flag)

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

return TrainService
