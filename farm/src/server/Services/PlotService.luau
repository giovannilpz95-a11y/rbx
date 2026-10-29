--!strict
-- Builds the greybox world from plain blocks and keeps each plot's visuals in step with its
-- owner's data. Design/15 3D World & Avatar Play §2 (scale, layout, hub) and
-- Design/09 Roblox Architecture §7 (slots, ownership attributes).
--
-- Plot-local axes: +Z is "south" (the gate, facing the hub), -Z is "north" (the fields).
-- Only the 96 x 96 stud start area is built; the rest of the 192 x 192 plot is wild grass.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Animals = require(Shared.Config.Animals)
local Balance = require(Shared.Config.Balance)
local Crops = require(Shared.Config.Crops)
local Factories = require(Shared.Config.Factories)
local Pen = require(Shared.Pen)
local Profile = require(Shared.Profile)
local Timer = require(Shared.Timer)
local Town = require(Shared.Config.Town)
local TownRules = require(Shared.TownRules)

local DataService = require(script.Parent.DataService)
local Clock = require(script.Parent.Parent.Util.Clock)

local PlotService = {}

local CELL = 224 -- 192 plot + 32 road (15 §2)
local PLOT_SIZE = 192
local START_SIZE = 96
local HUB_HALF = CELL

local COLORS = {
	ground = Color3.fromRGB(96, 140, 72),
	wild = Color3.fromRGB(78, 120, 60),
	start = Color3.fromRGB(120, 168, 88),
	road = Color3.fromRGB(110, 110, 115),
	path = Color3.fromRGB(196, 176, 140),
	hub = Color3.fromRGB(150, 150, 140),
	soil = Color3.fromRGB(110, 76, 50),
	sprout = Color3.fromRGB(110, 190, 80),
	barn = Color3.fromRGB(170, 60, 50),
	penFloor = Color3.fromRGB(196, 168, 100),
	fence = Color3.fromRGB(140, 100, 60),
	roof = Color3.fromRGB(90, 70, 60),
	glass = Color3.fromRGB(170, 210, 230),
	board = Color3.fromRGB(150, 110, 70),
	truck = Color3.fromRGB(60, 110, 190),
	crate = Color3.fromRGB(190, 150, 90),
}

-- Main Street: the strip between the gate and the Ring Road (local z 48..96), with two
-- back-to-back rows of 8 x 8 House lots, a street, and a row of 12 x 12 Community Building
-- lots. Lots nearest the gate road come first; the truck's lane (x 20..34) stays clear.
local function mainStreetLots(): ({ Vector3 }, { Vector3 })
	local houses, community = {}, {}
	for step = 1, 9 do
		local x = step * 10
		for _, side in { -1, 1 } do
			if side == 1 and (x == 20 or x == 30) then
				continue
			end
			table.insert(houses, Vector3.new(side * x, 0, 54))
			table.insert(houses, Vector3.new(side * x, 0, 64))
		end
	end
	for step = 1, 6 do
		local x = 13 + (step - 1) * 15
		for _, side in { -1, 1 } do
			if side == 1 and x == 28 then
				continue
			end
			table.insert(community, Vector3.new(side * x, 0, 86))
		end
	end
	return houses, community
end
local HOUSE_LOTS, COMMUNITY_LOTS = mainStreetLots()

-- Plot-local positions (studs). Fields are 2 x 2 tiles (8 x 8 studs).
local LAYOUT = {
	houseLots = HOUSE_LOTS,
	communityLots = COMMUNITY_LOTS, -- by Community Building order

	fields = {
		F1 = Vector3.new(-34, 0, -31),
		F2 = Vector3.new(-22, 0, -31),
		F3 = Vector3.new(-10, 0, -31),
		F4 = Vector3.new(-34, 0, -13),
		F5 = Vector3.new(-22, 0, -13),
		F6 = Vector3.new(-10, 0, -13),
	} :: { [string]: Vector3 },
	-- Factory row on the east side, the first one nearest the spawn. Each output table stands
	-- on the factory's west side, facing the spine path.
	factories = {
		Bakery = Vector3.new(30, 0, 16),
		FeedMill = Vector3.new(30, 0, 2),
		Dairy = Vector3.new(30, 0, -12),
		SugarMill = Vector3.new(30, 0, -26),
		TextileMill = Vector3.new(30, 0, -40),
	} :: { [string]: Vector3 },
	factoryOutputOffset = Vector3.new(-10, 0, 0),
	-- Pen row between the fields and the Barn, the Cow Barn nearest the spine
	pens = {
		CowBarn = Vector3.new(-12, 0, 6),
		ChickenCoop = Vector3.new(-26, 0, 6),
		SheepFold = Vector3.new(-40, 0, 6),
	} :: { [string]: Vector3 },
	barn = Vector3.new(-28, 0, 30),
	orderBoard = Vector3.new(12, 0, 34),
	truck = Vector3.new(26, 0, 36),
	spawn = Vector3.new(0, 0, 16), -- far enough inside that the camera behind you clears the gate
}
PlotService.LAYOUT = LAYOUT

type Slot = { index: number, cframe: CFrame, owner: Player? }

local slots: { Slot } = {}
local plotsFolder: Folder
local plotsByPlayer: { [Player]: Model } = {}
local slotByPlayer: { [Player]: Slot } = {}
local fieldVisualState: { [Player]: { [string]: string } } = {}
local factoryVisualState: { [Player]: { [string]: string } } = {}
local penVisualState: { [Player]: { [string]: string } } = {}
local townVisualState: { [Player]: { [string]: string } } = {}
local truckBusy: { [Player]: boolean } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function label(parent: Instance, text: string, offsetY: number, size: UDim2?, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size or UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance or 120
	local text_ = Instance.new("TextLabel")
	text_.Name = "Text"
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.TextScaled = true
	text_.Font = Enum.Font.GothamBold
	text_.TextColor3 = Color3.new(1, 1, 1)
	text_.TextStrokeTransparency = 0.4
	text_.Text = text
	text_.Parent = gui
	gui.Parent = parent
	return gui
end

---------------------------------------------------------------------------------------------
-- Shared world: ground, hub, ring road, empty plot pads
---------------------------------------------------------------------------------------------

local function buildWorld()
	-- Clear what a Studio template leaves behind: its spawn would put players on the hub
	-- floor at random, and its Baseplate z-fights with our ground.
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") or (child:IsA("BasePart") and child.Name == "Baseplate") then
			child:Destroy()
		end
	end

	local map = Instance.new("Folder")
	map.Name = "FarmMap"
	map.Parent = Workspace

	local extent = CELL * 4 + 200
	part({
		Name = "Ground",
		Size = Vector3.new(extent, 2, extent),
		Position = Vector3.new(0, -1, 0),
		Color = COLORS.ground,
		Material = Enum.Material.Grass,
		Parent = map,
	})
	part({
		Name = "Hub",
		Size = Vector3.new(HUB_HALF * 2, 0.2, HUB_HALF * 2),
		Position = Vector3.new(0, 0.1, 0),
		Color = COLORS.hub,
		Material = Enum.Material.Cobblestone,
		Parent = map,
	})

	-- Ring Road on all four sides, running the full width so corner plots reach it too
	local roadLen = CELL * 4
	local roadMid = HUB_HALF + 8
	for _, spec in
		{
			{ 0, -roadMid, roadLen, 16 },
			{ 0, roadMid, roadLen, 16 },
			{ -roadMid, 0, 16, roadLen },
			{ roadMid, 0, 16, roadLen },
		}
	do
		part({
			Name = "RingRoad",
			Size = Vector3.new(spec[3], 0.2, spec[4]),
			Position = Vector3.new(spec[1], 0.12, spec[2]),
			Color = COLORS.road,
			Material = Enum.Material.Asphalt,
			Parent = map,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = COLORS.path
	spawn.Parent = map

	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	-- 12 slots: the outer ring of a 4 x 4 grid of cells; each plot's gate faces the hub.
	local positions = {}
	for _, x in { -336, -112, 112, 336 } do
		table.insert(positions, { x, -336, Vector3.new(0, 0, 1) })
		table.insert(positions, { x, 336, Vector3.new(0, 0, -1) })
	end
	for _, z in { -112, 112 } do
		table.insert(positions, { -336, z, Vector3.new(1, 0, 0) })
		table.insert(positions, { 336, z, Vector3.new(-1, 0, 0) })
	end
	for index, spec in positions do
		local center = Vector3.new(spec[1], 0, spec[2])
		local towardHub: Vector3 = spec[3]
		-- local +Z must point toward the hub; a CFrame looks down its -Z
		local cframe = CFrame.lookAt(center, center - towardHub)
		table.insert(slots, { index = index, cframe = cframe, owner = nil })
		part({
			Name = "PlotPad_" .. index,
			Size = Vector3.new(PLOT_SIZE, 0.1, PLOT_SIZE),
			CFrame = cframe * CFrame.new(0, 0.05, 0),
			Color = COLORS.wild,
			Material = Enum.Material.Grass,
			Parent = map,
		})
	end
end

---------------------------------------------------------------------------------------------
-- One player's plot
---------------------------------------------------------------------------------------------

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- A factory: body with a production window, chimney, and an output table facing the spine.
local function buildFactory(plot: Model, id: string, at: (Vector3, number) -> CFrame)
	local def = Factories[id]
	local pos = LAYOUT.factories[id]
	local factory = Instance.new("Model")
	factory.Name = id
	factory.Parent = plot
	local body = part({
		Name = "Body",
		Size = Vector3.new(12, 10, 10),
		CFrame = at(pos, 5),
		Color = rgb(def.color),
		Parent = factory,
	})
	body:SetAttribute("Interact", "Factory")
	body:SetAttribute("FactoryId", id)
	part({
		Name = "Roof",
		Size = Vector3.new(13, 1.5, 11),
		CFrame = at(pos, 10.75),
		Color = COLORS.roof,
		Parent = factory,
	})
	part({
		Name = "Window",
		Size = Vector3.new(0.3, 4, 6),
		CFrame = at(pos + Vector3.new(-6.1, 0, 0), 5),
		Color = COLORS.glass,
		Transparency = 0.4,
		Material = Enum.Material.Glass,
		Parent = factory,
	})
	local chimney = part({
		Name = "Chimney",
		Size = Vector3.new(2, 4, 2),
		CFrame = at(pos + Vector3.new(3, 0, -2), 13),
		Color = COLORS.roof,
		Parent = factory,
	})
	local smoke = Instance.new("Smoke")
	smoke.Enabled = false
	smoke.RiseVelocity = 4
	smoke.Size = 2
	smoke.Parent = chimney
	local outputTable = part({
		Name = "OutputTable",
		Size = Vector3.new(3, 3, 8),
		CFrame = at(pos + LAYOUT.factoryOutputOffset, 1.5),
		Color = COLORS.board,
		Parent = factory,
	})
	outputTable:SetAttribute("Interact", "FactoryOutput")
	outputTable:SetAttribute("FactoryId", id)
	-- Names only show up close: the row's buildings stand 14 studs apart (status bubbles
	-- come from the client)
	label(body, def.displayName, 7, UDim2.fromOffset(140, 28), 40)
end

-- Where each animal stands in a 12 x 12 pen (3 x 2 grid), and its greybox size.
local ANIMAL_SPOTS = {
	Vector3.new(-3.5, 0, -2.5),
	Vector3.new(0, 0, -2.5),
	Vector3.new(3.5, 0, -2.5),
	Vector3.new(-3.5, 0, 2.5),
	Vector3.new(0, 0, 2.5),
	Vector3.new(3.5, 0, 2.5),
}
local ANIMAL_SIZES: { [string]: Vector3 } = {
	CowBarn = Vector3.new(2.2, 2.4, 3.6),
	ChickenCoop = Vector3.new(1.2, 1.2, 1.2),
	SheepFold = Vector3.new(2, 2, 2.8),
}

-- A pen: a floor you tap (feed / collect), a low fence and up to six animals.
local function buildPen(plot: Model, id: string, at: (Vector3, number) -> CFrame)
	local def = Animals.pens[id]
	local pos = LAYOUT.pens[id]
	local pen = Instance.new("Model")
	pen.Name = id
	pen.Parent = plot
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(12, 0.4, 12),
		CFrame = at(pos, 0.4),
		Color = COLORS.penFloor,
		Material = Enum.Material.Sand,
		Parent = pen,
	})
	floor:SetAttribute("Interact", "Pen")
	floor:SetAttribute("PenId", id)
	-- Fences and animals let taps through to the floor
	for _, spec in
		{
			{ Vector3.new(0, 0, -6), Vector3.new(12, 1.6, 0.3) },
			{ Vector3.new(0, 0, 6), Vector3.new(12, 1.6, 0.3) },
			{ Vector3.new(-6, 0, 0), Vector3.new(0.3, 1.6, 12) },
			{ Vector3.new(6, 0, 0), Vector3.new(0.3, 1.6, 12) },
		}
	do
		local fence = part({
			Name = "Fence",
			Size = spec[2],
			CFrame = at(pos + spec[1], 1.4),
			Color = COLORS.fence,
			CanCollide = false,
			Parent = pen,
		})
		fence.CanQuery = false
	end
	local size = ANIMAL_SIZES[id] or Vector3.new(2, 2, 2)
	for i, spot in ANIMAL_SPOTS do
		local animal = part({
			Name = "Animal_" .. i,
			Size = size,
			CFrame = at(pos + spot, 0.6 + size.Y / 2),
			Color = rgb(def.color),
			CanCollide = false,
			Transparency = 1,
			Parent = pen,
		})
		animal.CanQuery = false
		local product = part({
			Name = "Product_" .. i,
			Size = Vector3.new(1, 1, 1),
			CFrame = animal.CFrame * CFrame.new(0, size.Y / 2 + 1, 0),
			Color = rgb(def.productColor),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Transparency = 1,
			Parent = pen,
		})
		product.CanQuery = false
	end
	label(floor, def.displayName, 5, UDim2.fromOffset(140, 28), 40)
end

local function buildPlot(player: Player, slot: Slot): Model
	local origin = slot.cframe
	local function at(localPos: Vector3, y: number): CFrame
		return origin * CFrame.new(localPos.X, y, localPos.Z)
	end

	local model = Instance.new("Model")
	model.Name = "Plot_" .. slot.index
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("SlotIndex", slot.index)

	part({
		Name = "StartArea",
		Size = Vector3.new(START_SIZE, 0.2, START_SIZE),
		CFrame = at(Vector3.zero, 0.15),
		Color = COLORS.start,
		Material = Enum.Material.Grass,
		Parent = model,
	})
	-- Spine path from the gate to the factory row, and the farm lane between the field rows
	part({
		Name = "SpinePath",
		Size = Vector3.new(8, 0.2, 58),
		CFrame = at(Vector3.new(0, 0, 19), 0.3),
		Color = COLORS.path,
		Parent = model,
	})
	part({
		Name = "FarmLane",
		Size = Vector3.new(44, 0.2, 8),
		CFrame = at(Vector3.new(-18, 0, -22), 0.3),
		Color = COLORS.path,
		Parent = model,
	})
	part({
		Name = "CrossPath",
		Size = Vector3.new(8, 0.2, 20),
		CFrame = at(Vector3.new(0, 0, -16), 0.3),
		Color = COLORS.path,
		Parent = model,
	})

	-- Gate with the owner's name, facing the Ring Road
	for _, x in { -6, 6 } do
		part({
			Name = "GatePost",
			Size = Vector3.new(1.5, 10, 1.5),
			CFrame = at(Vector3.new(x, 0, 47), 5),
			Color = COLORS.board,
			Parent = model,
		})
	end
	local arch = part({
		Name = "GateArch",
		Size = Vector3.new(14, 1.5, 1.5),
		CFrame = at(Vector3.new(0, 0, 47), 10.5),
		Color = COLORS.board,
		Parent = model,
	})
	-- A painted name sign on the arch (readable from both sides) instead of a floating
	-- label, so it never overlaps the Order Board from the default camera.
	local sign = part({
		Name = "GateSign",
		Size = Vector3.new(14, 3, 0.4),
		CFrame = at(Vector3.new(0, 0, 47), 12.75),
		Color = COLORS.board,
		Parent = model,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 30
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Text = player.DisplayName .. "'s Farm"
		text.Parent = surface
		surface.Parent = sign
	end

	local spawnPad = part({
		Name = "SpawnPad",
		Size = Vector3.new(6, 0.2, 6),
		CFrame = at(LAYOUT.spawn, 0.35),
		Color = COLORS.hub,
		CanCollide = false,
		Parent = model,
	})
	spawnPad.Transparency = 0.5

	-- Main Street: the gate road down to the Ring Road and the street between the lot rows
	part({
		Name = "GateRoad",
		Size = Vector3.new(8, 0.2, 48),
		CFrame = at(Vector3.new(0, 0, 72), 0.3),
		Color = COLORS.path,
		Parent = model,
	})
	part({
		Name = "MainStreet",
		Size = Vector3.new(184, 0.2, 8),
		CFrame = at(Vector3.new(0, 0, 75), 0.3),
		Color = COLORS.path,
		Parent = model,
	})
	local townFolder = Instance.new("Folder")
	townFolder.Name = "Town"
	townFolder.Parent = model

	-- Fields
	local fieldsFolder = Instance.new("Folder")
	fieldsFolder.Name = "Fields"
	fieldsFolder.Parent = model
	for id, pos in LAYOUT.fields do
		local bed = part({
			Name = "Field_" .. id,
			Size = Vector3.new(8, 1, 8),
			CFrame = at(pos, 0.5),
			Color = COLORS.soil,
			Material = Enum.Material.Ground,
			Parent = fieldsFolder,
		})
		bed:SetAttribute("Interact", "Field")
		bed:SetAttribute("FieldId", id)
		local crop = part({
			Name = "Crop",
			Size = Vector3.new(6, 0.2, 6),
			CFrame = bed.CFrame * CFrame.new(0, 0.6, 0),
			Color = COLORS.sprout,
			CanCollide = false,
			Transparency = 1,
			Parent = bed,
		})
		crop.CanTouch = false
	end

	-- Barn
	local barn = part({
		Name = "Barn",
		Size = Vector3.new(16, 14, 14),
		CFrame = at(LAYOUT.barn, 7),
		Color = COLORS.barn,
		Parent = model,
	})
	barn:SetAttribute("Interact", "Barn")
	part({
		Name = "BarnRoof",
		Size = Vector3.new(17, 2, 15),
		CFrame = at(LAYOUT.barn, 15),
		Color = COLORS.roof,
		Parent = model,
	})
	part({
		Name = "BarnDoor",
		Size = Vector3.new(0.4, 8, 6),
		CFrame = at(LAYOUT.barn + Vector3.new(8.1, 0, 0), 4),
		Color = COLORS.roof,
		Parent = model,
	})
	label(barn, "Barn", 9)

	for _, id in Balance.enabledFactories do
		buildFactory(model, id, at)
	end
	for _, id in Balance.enabledPens do
		buildPen(model, id, at)
	end

	-- Order Board with the truck waiting at its dock
	local board = part({
		Name = "OrderBoard",
		Size = Vector3.new(0.5, 7, 10),
		CFrame = at(LAYOUT.orderBoard, 6),
		Color = COLORS.board,
		Parent = model,
	})
	board:SetAttribute("Interact", "OrderBoard")
	for _, dz in { -4, 4 } do
		part({
			Name = "BoardPost",
			Size = Vector3.new(0.8, 3, 0.8),
			CFrame = at(LAYOUT.orderBoard + Vector3.new(0, 0, dz), 1.5),
			Color = COLORS.roof,
			Parent = model,
		})
	end

	local truck = part({
		Name = "Truck",
		Size = Vector3.new(6, 3, 10),
		CFrame = at(LAYOUT.truck, 2.5),
		Color = COLORS.truck,
		CanCollide = false,
		Parent = model,
	})
	local cab = part({
		Name = "Cab",
		Size = Vector3.new(6, 5, 4),
		CFrame = truck.CFrame * CFrame.new(0, 1, 7),
		Color = COLORS.truck,
		CanCollide = false,
		Parent = truck,
	})
	cab.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = truck
	weld.Part1 = cab
	weld.Parent = truck
	model:SetAttribute("TruckHome", truck.CFrame)

	model.PrimaryPart = model:FindFirstChild("StartArea") :: BasePart
	model.Parent = plotsFolder
	return model
end

---------------------------------------------------------------------------------------------
-- Visuals that follow the data
---------------------------------------------------------------------------------------------

-- One town building: a block with a roof, tapped to open the Town panel. Rebuilt when its
-- state changes (greybox; the art pass swaps in models).
local function townBlock(
	folder: Instance,
	name: string,
	at: CFrame,
	size: Vector3,
	color: Color3,
	building: boolean,
	labelText: string?
)
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Model")
	holder.Name = name
	local body = part({
		Name = "Body",
		Size = size,
		CFrame = at * CFrame.new(0, size.Y / 2 + 0.3, 0),
		Color = if building then COLORS.crate else color,
		Transparency = if building then 0.45 else 0,
		Parent = holder,
	})
	body:SetAttribute("Interact", "Town")
	local roof = part({
		Name = "Roof",
		Size = Vector3.new(size.X + 1, 1.2, size.Z + 1),
		CFrame = at * CFrame.new(0, size.Y + 0.9, 0),
		Color = COLORS.roof,
		Transparency = if building then 0.45 else 0,
		Parent = holder,
	})
	roof.CanQuery = false
	if labelText then
		label(body, labelText, size.Y / 2 + 3, UDim2.fromOffset(140, 28), 40)
	end
	holder.Parent = folder
end

local function refreshTown(player: Player, model: Model, data: { [string]: any }, now: number)
	local folder = model:FindFirstChild("Town")
	local slot = slotByPlayer[player]
	if folder == nil or slot == nil then
		return
	end
	local cache = townVisualState[player]
	for _, house in data.town.houses do
		local def = Town.houses[house.type]
		local pos = LAYOUT.houseLots[house.lot]
		if def == nil or pos == nil then
			continue
		end
		local name = "House_" .. house.lot
		local state = house.type .. ":" .. tostring(TownRules.isDone(house, now))
		if cache[name] ~= state then
			cache[name] = state
			-- Bigger Houses stand taller (greybox)
			local height = 4 + def.population / 5
			townBlock(
				folder,
				name,
				slot.cframe * CFrame.new(pos),
				Vector3.new(7, height, 7),
				Color3.fromRGB(def.color[1], def.color[2], def.color[3]),
				not TownRules.isDone(house, now),
				nil
			)
		end
	end
	for id, entry in data.town.community do
		local def = Town.community[id]
		local pos = def and LAYOUT.communityLots[def.order]
		if def == nil or pos == nil then
			continue
		end
		local name = "Community_" .. id
		local state = tostring(TownRules.isDone(entry, now))
		if cache[name] ~= state then
			cache[name] = state
			townBlock(
				folder,
				name,
				slot.cframe * CFrame.new(pos),
				Vector3.new(11, 7, 11),
				Color3.fromRGB(def.color[1], def.color[2], def.color[3]),
				not TownRules.isDone(entry, now),
				def.displayName
			)
		end
	end
end

local function refreshFields(player: Player, model: Model, data: { [string]: any }, now: number)
	local cache = fieldVisualState[player]
	local fieldsFolder = model:FindFirstChild("Fields")
	if fieldsFolder == nil then
		return
	end
	for id, field in data.fields do
		local state = if field.crop == nil
			then "empty"
			elseif Timer.isReady(field.readyAt, now) then "ready:" .. field.crop
			else "growing:" .. field.crop
		if cache[id] == state then
			continue
		end
		cache[id] = state
		local bed = fieldsFolder:FindFirstChild("Field_" .. id) :: BasePart?
		if bed == nil then
			continue
		end
		bed:SetAttribute("Crop", field.crop)
		bed:SetAttribute("ReadyAt", field.readyAt)
		local crop = bed:FindFirstChild("Crop") :: BasePart
		if field.crop == nil then
			crop.Transparency = 1
		elseif state:sub(1, 5) == "ready" then
			local rgb = Crops[field.crop].color
			crop.Transparency = 0
			crop.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
			crop.Size = Vector3.new(6, 3, 6)
			crop.CFrame = bed.CFrame * CFrame.new(0, 2, 0)
		else
			crop.Transparency = 0
			crop.Color = COLORS.sprout
			crop.Size = Vector3.new(6, 0.8, 6)
			crop.CFrame = bed.CFrame * CFrame.new(0, 0.9, 0)
		end
	end
end

local function refreshFactory(player: Player, model: Model, id: string, factory: { [string]: any }, now: number)
	local def = Factories[id]
	local building = model:FindFirstChild(id)
	if def == nil or building == nil then
		return
	end
	-- Preview where the queue stands now without changing saved data.
	local queue = Profile.deepCopy(factory.queue)
	local output = Profile.deepCopy(factory.output)
	Timer.advanceQueue(queue, output, now, def.trayCapacity)
	local outputCount = Timer.countOutput(output)
	local underConstruction = factory.built and factory.constructionReadyAt ~= nil and now < factory.constructionReadyAt
	local busy = #queue > 0 and queue[1].startedAt ~= nil
	local state =
		string.format("%s:%s:%s:%d", tostring(factory.built), tostring(underConstruction), tostring(busy), outputCount)

	local cache = factoryVisualState[player]
	if cache[id] == state then
		return
	end
	cache[id] = state

	local transparency = if not factory.built then 0.75 elseif underConstruction then 0.4 else 0
	for _, child in building:GetChildren() do
		if
			child:IsA("BasePart")
			and child.Name ~= "Window"
			and child.Name ~= "OutputTable"
			and child.Name ~= "Crate"
		then
			child.Transparency = transparency
		end
	end
	local smoke = (building:FindFirstChild("Chimney") :: BasePart):FindFirstChildOfClass("Smoke")
	if smoke then
		smoke.Enabled = busy
	end

	-- One crate per finished item on the output table
	for _, child in building:GetChildren() do
		if child.Name == "Crate" then
			child:Destroy()
		end
	end
	local outputTable = building:FindFirstChild("OutputTable") :: BasePart
	for i = 1, outputCount do
		local row = (i - 1) % 4
		local layer = (i - 1) // 4
		local crate = part({
			Name = "Crate",
			Size = Vector3.new(1.6, 1.4, 1.6),
			CFrame = outputTable.CFrame * CFrame.new(0, 2.2 + layer * 1.45, -3 + row * 2),
			Color = COLORS.crate,
			CanCollide = false,
		})
		crate.CanQuery = false
		crate.Parent = building
	end
end

local function refreshPen(player: Player, model: Model, id: string, pen: { [string]: any }, now: number)
	local def = Animals.pens[id]
	local building = model:FindFirstChild(id)
	if def == nil or building == nil then
		return
	end
	local underConstruction = pen.built and not Pen.isOperational(pen, now)
	local marks = {}
	for i, animal in pen.animals do
		marks[i] = if animal.readyAt == nil then "h" elseif now >= animal.readyAt then "r" else "p"
	end
	local state = string.format("%s:%s:%s", tostring(pen.built), tostring(underConstruction), table.concat(marks))
	local cache = penVisualState[player]
	if cache[id] == state then
		return
	end
	cache[id] = state

	local shell = if not pen.built then 0.75 elseif underConstruction then 0.4 else 0
	for _, child in building:GetChildren() do
		if child.Name == "Floor" or child.Name == "Fence" then
			(child :: BasePart).Transparency = shell
		end
	end
	for i = 1, #ANIMAL_SPOTS do
		local animal = building:FindFirstChild("Animal_" .. i) :: BasePart?
		local product = building:FindFirstChild("Product_" .. i) :: BasePart?
		local mark = marks[i]
		if animal then
			animal.Transparency = if mark == nil then 1 elseif underConstruction then 0.5 else 0
		end
		if product then
			product.Transparency = if mark == "r" then 0 else 1
		end
	end
end

function PlotService.refresh(player: Player)
	local model = plotsByPlayer[player]
	local data = DataService.get(player)
	if model == nil or data == nil then
		return
	end
	local now = Clock.now()
	refreshFields(player, model, data, now)
	for id, factory in data.factories do
		refreshFactory(player, model, id, factory, now)
	end
	for id, pen in data.pens do
		refreshPen(player, model, id, pen, now)
	end
	refreshTown(player, model, data, now)
end

---------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------

function PlotService.assign(player: Player): Model?
	for _, slot in slots do
		if slot.owner == nil then
			slot.owner = player
			slotByPlayer[player] = slot
			fieldVisualState[player] = {}
			factoryVisualState[player] = {}
			penVisualState[player] = {}
			townVisualState[player] = {}
			local model = buildPlot(player, slot)
			plotsByPlayer[player] = model
			PlotService.refresh(player)
			return model
		end
	end
	return nil
end

function PlotService.release(player: Player)
	local model = plotsByPlayer[player]
	if model then
		model:Destroy()
	end
	local slot = slotByPlayer[player]
	if slot then
		slot.owner = nil
	end
	plotsByPlayer[player] = nil
	slotByPlayer[player] = nil
	fieldVisualState[player] = nil
	factoryVisualState[player] = nil
	penVisualState[player] = nil
	townVisualState[player] = nil
	truckBusy[player] = nil
end

function PlotService.getPlot(player: Player): Model?
	return plotsByPlayer[player]
end

function PlotService.spawnCFrame(player: Player): CFrame?
	local slot = slotByPlayer[player]
	if slot == nil then
		return nil
	end
	-- Stand on the spawn pad facing north, up the spine path
	return slot.cframe * CFrame.new(LAYOUT.spawn.X, 4, LAYOUT.spawn.Z)
end

-- World position of a hands-on target, for the server reach check.
function PlotService.worldPosition(player: Player, localPos: Vector3): Vector3?
	local slot = slotByPlayer[player]
	if slot == nil then
		return nil
	end
	return (slot.cframe * CFrame.new(localPos)).Position
end

function PlotService.fieldPosition(player: Player, fieldId: string): Vector3?
	local pos = LAYOUT.fields[fieldId]
	return if pos then PlotService.worldPosition(player, pos) else nil
end

function PlotService.factoryOutputPosition(player: Player, factoryId: string): Vector3?
	local pos = LAYOUT.factories[factoryId]
	return if pos then PlotService.worldPosition(player, pos + LAYOUT.factoryOutputOffset) else nil
end

function PlotService.penPosition(player: Player, penId: string): Vector3?
	local pos = LAYOUT.pens[penId]
	return if pos then PlotService.worldPosition(player, pos) else nil
end

-- The delivery truck drives out of the gate and comes back (cosmetic).
function PlotService.driveTruck(player: Player, returnSeconds: number)
	local model = plotsByPlayer[player]
	if model == nil or truckBusy[player] then
		return
	end
	local truck = model:FindFirstChild("Truck") :: BasePart?
	local home = model:GetAttribute("TruckHome") :: CFrame?
	if truck == nil or home == nil then
		return
	end
	truckBusy[player] = true
	local away = home * CFrame.new(0, 0, 70)
	local leg = math.clamp(returnSeconds / 2, 2, 6)
	task.spawn(function()
		local out = TweenService:Create(
			truck,
			TweenInfo.new(leg, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = away }
		)
		out:Play()
		out.Completed:Wait()
		truck.Transparency = 1
		local cab = truck:FindFirstChild("Cab") :: BasePart?
		if cab then
			cab.Transparency = 1
		end
		task.wait(math.max(0, returnSeconds - leg * 2))
		if truck.Parent == nil then
			return
		end
		truck.Transparency = 0
		if cab then
			cab.Transparency = 0
		end
		local back = TweenService:Create(
			truck,
			TweenInfo.new(leg, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = home }
		)
		back:Play()
		back.Completed:Wait()
		truckBusy[player] = nil
	end)
end

function PlotService.init()
	buildWorld()

	-- Visuals that change with time alone (crops ripening, factories finishing goods,
	-- animals finishing products)
	task.spawn(function()
		while true do
			task.wait(1)
			for player in plotsByPlayer do
				PlotService.refresh(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(PlotService.release)
end

return PlotService
