--!strict
-- The Town Express (Design/14 Multiplayer Features C1, shared/Express): every 2 hours a giant
-- train pulls into its station north of the Town Square, and everyone on the server loads its
-- crates from their own Barns for 20 minutes. Each crate pays its goods' XP; every tier the
-- server reaches pays Coins and a prize to everyone who loaded at least one crate.
--
-- The train lives only on this server. Clients read it from the station's "Train" attribute
-- (JSON): the crates, the window, the tier prizes and who loaded how many.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtRail = require(Shared.Art.Rail)
local Balance = require(Shared.Config.Balance)
local Config = require(Shared.Config.Express)
local Express = require(Shared.Express)
local Items = require(Shared.Items)
local Kit = require(Shared.Art.Kit)
local Net = require(Shared.Net)
local Palette = require(Shared.Art.Palette)
local Timer = require(Shared.Timer)
local Tools = require(Shared.Config.Tools)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local NoticeService = require(script.Parent.NoticeService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local ExpressService = {}

-- The station stands north of the Town Square, its track side facing the square, so the train
-- stops between the two. (Station-local +X runs east to west here; the train always rolls
-- forward that way: in from the east, out to the west.)
ExpressService.STATION = CFrame.new(0, 0, -100) * Kit.yaw(180)
local SCALE = ArtRail.EXPRESS_SCALE
local TRACK_Z = -9.2 -- station-local: the track's centre line, clear of the platform edge
local TRACK_PIECES = 11 -- the longest train (10 cars) plus the run in and out
local DRIVE = 40 -- studs the train rolls arriving and leaving (it fades in and out over them)
local DRIVE_SECONDS = 6
local REACH = 80 -- studs from the station's centre a loader must be within (the train is long)

local train: Express.Train? = nil
local lastArrival = -1 -- the clock arrival already run (so a closed window doesn't reopen)
local seed = 1
local station: Model? = nil
local boardText: TextLabel? = nil
local trainModel: Model? = nil
local cars: { Model } = {}

local function trackCFrame(x: number): CFrame
	return ExpressService.STATION * CFrame.new(x, 0, TRACK_Z)
end

-- Where the train stands while it's in the station: the engine at the east end, cars behind
local function dockCFrame(): CFrame
	return trackCFrame(0)
end

local function publish()
	if station == nil then
		return
	end
	if train == nil then
		station:SetAttribute("Train", "")
		ArtRail.setExpressProgress(station, 0)
		return
	end
	local crates = {}
	for i, crate in train.crates do
		crates[i] = { item = crate.item, qty = crate.qty, filled = crate.by ~= nil }
	end
	station:SetAttribute(
		"Train",
		HttpService:JSONEncode({
			arrivedAt = train.arrivedAt,
			leavesAt = train.leavesAt,
			crates = crates,
			prizes = train.prizes,
			loaded = train.loaded,
			npc = train.npc,
		})
	)
	ArtRail.setExpressProgress(station, Express.filled(train) / math.max(1, #train.crates))
	for k, car in cars do
		local n = 0
		for i = (k - 1) * Config.cratesPerCar + 1, k * Config.cratesPerCar do
			local crate = train.crates[i]
			if crate and crate.by ~= nil then
				n += 1
			end
		end
		ArtRail.setCarCrates(car, n)
	end
end

-- Roll the train from `from` to `to`, fading it in (arriving) or out (leaving) on the way
local function drive(model: Model, from: CFrame, to: CFrame, arriving: boolean, done: (() -> ())?)
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local base = (p:GetAttribute("BaseTransparency") :: number?) or p.Transparency
			p:SetAttribute("BaseTransparency", base)
			parts[p] = base
		end
	end
	task.spawn(function()
		local start = os.clock()
		while model.Parent do
			local t = math.min(1, (os.clock() - start) / DRIVE_SECONDS)
			local eased = t * t * (3 - 2 * t)
			model:PivotTo(from:Lerp(to, eased))
			local seen = if arriving then eased else 1 - eased
			for p, base in parts do
				p.Transparency = 1 - (1 - base) * seen
			end
			if t >= 1 then
				break
			end
			task.wait()
		end
		if done then
			done()
		end
	end)
end

-- Build the engine and its cars at the dock, then roll them in from the west
local function buildTrain(count: number)
	if station == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = "ExpressTrain"
	cars = {}
	local dock = dockCFrame()
	local front = (count * ArtRail.CAR_LENGTH * SCALE + ArtRail.ENGINE_LENGTH * SCALE) / 2
	ArtRail.engine(model, dock * CFrame.new(front - ArtRail.ENGINE_LENGTH * SCALE / 2, 0, 0), SCALE)
	for k = 1, count do
		local x = front - ArtRail.ENGINE_LENGTH * SCALE - (k - 0.5) * ArtRail.CAR_LENGTH * SCALE
		local car = ArtRail.cargoCar(model, dock * CFrame.new(x, 0, 0), SCALE)
		car:SetAttribute("Car", k)
		for _, p in car:GetDescendants() do
			if p:IsA("BasePart") then
				p:SetAttribute("Interact", "Express")
			end
		end
		cars[k] = car
	end
	model.WorldPivot = dock
	model:PivotTo(dock * CFrame.new(-DRIVE, 0, 0))
	model.Parent = station
	trainModel = model
	drive(model, dock * CFrame.new(-DRIVE, 0, 0), dock, true)
end

local function playersHere(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if DataService.get(player) then
			table.insert(list, player)
		end
	end
	return list
end

-- A new train for the window that opened at `arrivedAt`
local function arrive(arrivedAt: number, leavesAt: number)
	local levels = {}
	for _, player in playersHere() do
		local data = DataService.get(player) :: { [string]: any }
		table.insert(levels, data.level)
	end
	local sorted = table.clone(levels)
	table.sort(sorted)
	local level = if #sorted > 0 then sorted[math.ceil(#sorted / 2)] else 1
	local new
	new, seed = Express.generate(arrivedAt, levels, Express.pool(level, Balance.enabledCrops), seed)
	new.leavesAt = leavesAt
	train = new
	buildTrain(new.cars)
	publish()
	for _, player in Players:GetPlayers() do
		NetService.toast(
			player,
			string.format(
				"Whistle! The Town Express is in the Town Square for %s. Load its %d crates together!",
				Timer.format(leavesAt - Clock.now()),
				#new.crates
			)
		)
	end
end

local function depart()
	local done = train
	train = nil
	publish()
	if done then
		local share = Express.filled(done) / math.max(1, #done.crates)
		NoticeService.post(
			string.format(
				"The Town Express left with %d of %d crates (%d%%)",
				Express.filled(done),
				#done.crates,
				math.floor(share * 100 + 0.5)
			)
		)
	end
	local model = trainModel
	trainModel = nil
	cars = {}
	if model then
		local dock = dockCFrame()
		drive(model, dock, dock * CFrame.new(DRIVE, 0, 0), false, function()
			model:Destroy()
		end)
	end
end

local function give(player: Player, data: { [string]: any }, item: string, qty: number)
	if Tools.tools[item] then
		data.toolShed.items[item] = (data.toolShed.items[item] or 0) + qty
	else
		data.inventory.items[item] = (data.inventory.items[item] or 0) + qty -- rewards go past the cap
	end
	DataService.markDirty(player, true)
end

local function prizeName(item: string, qty: number): string
	local tool = Tools.tools[item]
	local name = if tool
		then (if qty == 1 then tool.displayName else tool.plural)
		elseif Items[item] then Items[item].displayName
		else item
	return string.format("%d %s", qty, name)
end

-- Pay `player` every tier they're owed now
local function payTiers(player: Player)
	local data = DataService.get(player)
	if train == nil or data == nil then
		return
	end
	for _, tier in Express.collect(train, player.UserId) do
		local prize = train.prizes[tier]
		EconomyService.add(player, "Coins", prize.coins, "express_tier")
		local parts = { string.format("+%d Coins", prize.coins) }
		if prize.item and prize.qty then
			give(player, data, prize.item, prize.qty)
			table.insert(parts, "+" .. prizeName(prize.item, prize.qty))
		end
		NetService.popup(player, {
			kind = "Crier",
			text = string.format(
				"Town Express %d%% reached! %s",
				math.floor(Config.tiers[tier] * 100 + 0.5),
				table.concat(parts, "  ")
			),
		})
		NetService.pushState(player)
	end
end

local function payEveryone()
	for _, player in Players:GetPlayers() do
		payTiers(player)
	end
end

function ExpressService.load(player: Player, index: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local crate, reason = Express.canLoad(train, index, Clock.now())
	if crate == nil or train == nil then
		return false, reason
	end
	if not NetService.isNear(player, ExpressService.STATION.Position, REACH) then
		return false, "Walk over to the Town Express station, north of the Town Square"
	end
	local name = Items[crate.item].displayName
	if not InventoryService.remove(player, { [crate.item] = crate.qty }) then
		return false, string.format("That crate needs %d %s from your Barn", crate.qty, name)
	end
	Express.load(train, crate, player.UserId)
	EconomyService.add(player, "XP", Express.crateXp(crate), "express_crate")
	TelemetryService.custom(player, "ExpressCrate", 1, "Express")
	DataService.markDirty(player, true)
	NetService.pushState(player)
	payEveryone()
	publish()
	return true
end

local function refreshBoard(now: number)
	if boardText == nil then
		return
	end
	-- The title has its own line; the status gets two short lines so neither wraps or shrinks
	if train then
		boardText.Text = string.format(
			"%d / %d crates\n%s left",
			Express.filled(train),
			#train.crates,
			Timer.format(math.max(0, train.leavesAt - now))
		)
	else
		boardText.Text = "Next train in\n" .. Timer.format(Express.nextArrival(now) - now)
	end
end

local function tick()
	local now = Clock.now()
	if train then
		if now >= train.leavesAt then
			depart()
		else
			local index
			index, seed = Express.npcTick(train, now, seed, Clock.getTimeScale())
			if index then
				payEveryone()
				publish()
			end
		end
	else
		local arrivedAt, open = Express.window(now)
		if open and arrivedAt ~= lastArrival then
			lastArrival = arrivedAt
			arrive(arrivedAt, arrivedAt + Config.windowSeconds)
		end
	end
	refreshBoard(now)
end

-- Studio: a train now, for the length of a window from this moment (the clock's own trains
-- carry on afterwards)
function ExpressService.debugArrive(player: Player): (boolean, string?)
	if not RunService:IsStudio() then
		return false
	end
	if train then
		train.leavesAt = Clock.now()
		depart()
	end
	local now = Clock.now()
	arrive(now, now + Config.windowSeconds)
	NetService.toast(player, "Dev: the Town Express is in, north of the Town Square")
	return true
end

-- Studio: the train leaves now, the way it does when its window ends
function ExpressService.debugLeave(player: Player): (boolean, string?)
	if not RunService:IsStudio() then
		return false
	end
	if train == nil then
		return false, "Dev: no Town Express in the station"
	end
	train.leavesAt = Clock.now()
	depart()
	NetService.toast(player, "Dev: the Town Express left")
	return true
end

-- Studio: goods in the Barn for the next 3 crates still to load
function ExpressService.debugGoods(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	if train == nil then
		return false, "Dev: bring a Town Express in first"
	end
	local given = 0
	for _, crate in train.crates do
		if crate.by == nil and given < 3 then
			data.inventory.items[crate.item] = (data.inventory.items[crate.item] or 0) + crate.qty
			given += 1
		end
	end
	DataService.markDirty(player, true)
	NetService.pushState(player)
	NetService.toast(player, string.format("Dev: goods for %d Town Express crates in your Barn", given))
	return true
end

local function buildStation()
	local map = workspace:WaitForChild("FarmMap") -- PlotService builds the shared world first
	local model, board = ArtRail.expressStation(map, ExpressService.STATION)
	station = model
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and (p.Name == "Platform" or p.Name == "ExpressBoard" or p.Name == "Tower") then
			p:SetAttribute("Interact", "Express")
		end
	end
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.94, 0.34)
	title.Position = UDim2.fromScale(0.03, 0.04)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Palette.coins
	title.Text = "TOWN EXPRESS"
	title.Parent = surface
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(0.94, 0.58)
	text.Position = UDim2.fromScale(0.03, 0.4)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Palette.cream
	text.Text = ""
	text.Parent = surface
	surface.Parent = board
	boardText = text
	-- The track in front of the platform, with a buffer stop at each end
	local tracks = Instance.new("Model")
	tracks.Name = "ExpressTrack"
	local piece = ArtRail.TRACK_LENGTH * SCALE
	local first = -piece * (TRACK_PIECES - 1) / 2
	for i = 0, TRACK_PIECES - 1 do
		ArtRail.track("Straight", tracks, trackCFrame(first + i * piece), SCALE)
	end
	-- A Buffer piece's rails run from 8 studs behind its centre (x scale) to 2 in front
	local edge = -first + piece / 2
	ArtRail.track("Buffer", tracks, trackCFrame(-edge - 8 * SCALE) * Kit.yaw(180), SCALE)
	ArtRail.track("Buffer", tracks, trackCFrame(edge + 8 * SCALE), SCALE)
	tracks.Parent = model
	publish()
end

function ExpressService.init()
	NetService.on(Net.Express_Load, 3, 6, ExpressService.load)
	NetService.on(Net.Debug_Express, 1, 2, ExpressService.debugArrive)
	NetService.on(Net.Debug_ExpressLeave, 1, 2, ExpressService.debugLeave)
	NetService.on(Net.Debug_ExpressGoods, 1, 2, ExpressService.debugGoods)
	seed = Random.new():NextInteger(1, 2147483646)
	-- A train already in its window when the server starts runs for what's left of it
	task.spawn(function()
		buildStation()
		while true do
			tick()
			task.wait(1)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(5, function()
			if train and player.Parent then
				NetService.toast(
					player,
					string.format(
						"The Town Express is in the Town Square for %s more. Help load it!",
						Timer.format(math.max(0, train.leavesAt - Clock.now()))
					)
				)
			end
		end)
	end)
end

return ExpressService
