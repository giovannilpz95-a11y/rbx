--!strict
-- Builds the world and each player's plot, and keeps the plot's visuals in step with its
-- owner's data. The models come from FarmShared.Art (Design/16 Model Catalog); this file
-- places them, sets the tap targets and drives their states. Design/15 3D World & Avatar Play §2 (scale, layout, hub) and
-- Design/09 Roblox Architecture §7 (slots, ownership attributes).
--
-- Plot-local axes: +Z is "south" (the gate, facing the hub), -Z is "north" (the fields).
-- Only the 96 x 96 stud start area is built; the rest of the 192 x 192 plot is wild grass.

local Lighting = game:GetService("Lighting")
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
local Land = require(Shared.Config.Land)
local Town = require(Shared.Config.Town)
local ArtAnimals = require(Shared.Art.Animals)
local ArtBuildings = require(Shared.Art.Buildings)
local ArtCommunity = require(Shared.Art.Community)
local ArtCrops = require(Shared.Art.Crops)
local ArtFactories = require(Shared.Art.Factories)
local ArtHouses = require(Shared.Art.Houses)
local ArtItemProps = require(Shared.Art.ItemProps)
local ArtLighting = require(Shared.Art.Lighting)
local Kit = require(Shared.Art.Kit)
local Palette = require(Shared.Art.Palette)
local TownRules = require(Shared.TownRules)

local DataService = require(script.Parent.DataService)
local Clock = require(script.Parent.Parent.Util.Clock)
local DecorModels = require(script.Parent.Parent.Util.DecorModels)

local PlotService = {}

local CELL = 224 -- 192 plot + 32 road (15 §2)
local PLOT_SIZE = 192
local START_SIZE = 96
local HUB_HALF = CELL

local COLORS = {
	ground = Palette.grassWild,
	wild = Palette.grassWild,
	start = Palette.grass,
	road = Palette.road,
	path = Palette.path,
	hub = Palette.hub,
	soil = Palette.soil,
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

	-- F1-F6 from the start; F7-F10 in a row north of them; F11-F22 in the West Meadow
	-- (land expansion 1), lined up with the start area's field rows.
	fields = (function()
		local fields: { [string]: Vector3 } = {
			F1 = Vector3.new(-34, 0, -31),
			F2 = Vector3.new(-22, 0, -31),
			F3 = Vector3.new(-10, 0, -31),
			F4 = Vector3.new(-34, 0, -13),
			F5 = Vector3.new(-22, 0, -13),
			F6 = Vector3.new(-10, 0, -13),
			F7 = Vector3.new(-34, 0, -43),
			F8 = Vector3.new(-22, 0, -43),
			F9 = Vector3.new(-10, 0, -43),
			F10 = Vector3.new(2, 0, -43),
		}
		local n = 11
		for _, z in { -43, -31, -19 } do
			for _, x in { -56, -68, -80, -92 } do
				fields["F" .. n] = Vector3.new(x, 0, z)
				n += 1
			end
		end
		return fields
	end)(),
	-- Land expansions 1-4: the plot-local rectangles each one clears (min corner, max corner)
	land = (function()
		local rects = {}
		for _, rect in Land.rects do -- stage 4 clears both corners (rects 4 and 5)
			table.insert(rects, { Vector3.new(rect.minX, 0, rect.minZ), Vector3.new(rect.maxX, 0, rect.maxZ) })
		end
		return rects
	end)(),
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

-- Decoration spots (plot-local, on the ground), clear of every building, path and lot.
local DECOR_TREES = {
	Vector3.new(42, 0, 44),
	Vector3.new(-44, 0, 44),
	Vector3.new(-45, 0, 21),
	Vector3.new(45, 0, 30),
	Vector3.new(44, 0, -46),
	Vector3.new(-44, 0, -47),
}
local DECOR_BUSHES = {
	Vector3.new(-6, 0, 36),
	Vector3.new(-6, 0, 26),
	Vector3.new(6, 0, 26),
	Vector3.new(-16, 0, 44),
	Vector3.new(16, 0, 44),
}

type Slot = { index: number, cframe: CFrame, owner: Player? }

local slots: { Slot } = {}
local plotsFolder: Folder
local plotsByPlayer: { [Player]: Model } = {}
local slotByPlayer: { [Player]: Slot } = {}
local fieldVisualState: { [Player]: { [string]: string } } = {}
local factoryVisualState: { [Player]: { [string]: string } } = {}
local penVisualState: { [Player]: { [string]: string } } = {}
local townVisualState: { [Player]: { [string]: string } } = {}
local landVisualState: { [Player]: { [number]: string } } = {}
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
	ArtLighting.apply(Lighting)
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

-- A factory (FarmShared.Art.Factories): the walls are the tap target, the output table in
-- front faces the spine path, and the chimney carries the working smoke.
local function buildFactory(plot: Model, id: string, at: (Vector3, number) -> CFrame)
	local def = Factories[id]
	local pos = LAYOUT.factories[id]
	local factory = Instance.new("Model")
	factory.Name = id
	-- The models face local -Z; turn them to face west, toward the spine path, so the output
	-- table lands at LAYOUT.factoryOutputOffset.
	local base = at(pos, 0) * Kit.yaw(90)
	factory:SetAttribute("BaseCFrame", base)
	local parts = ArtFactories.build(id, factory, base)
	parts.body:SetAttribute("Interact", "Factory")
	parts.body:SetAttribute("FactoryId", id)
	parts.outputTable:SetAttribute("Interact", "FactoryOutput")
	parts.outputTable:SetAttribute("FactoryId", id)
	parts.chimney.Name = "Chimney"
	parts.chimney.Parent = factory
	local smoke = Instance.new("Smoke")
	smoke.Enabled = false
	smoke.RiseVelocity = 4
	smoke.Size = 2
	smoke.Color = Palette.cream
	smoke.Opacity = 0.25
	smoke.Parent = parts.chimney
	-- Names only show up close: the row's buildings stand 14 studs apart (status bubbles
	-- come from the client)
	label(parts.body, def.displayName, 7, UDim2.fromOffset(140, 28), 40)
	factory.Parent = plot
end

-- Where each animal stands in a 12 x 12 pen (3 x 2 grid), with a little turn each so the
-- herd doesn't look lined up.
local ANIMAL_SPOTS = {
	Vector3.new(-3.5, 0, -2.5),
	Vector3.new(0, 0, -2.5),
	Vector3.new(3.5, 0, -2.5),
	Vector3.new(-3.5, 0, 2.5),
	Vector3.new(0, 0, 2.5),
	Vector3.new(3.5, 0, 2.5),
}
local ANIMAL_TURNS = { 160, 200, 175, 20, -15, 200 }

-- A pen: a floor you tap (feed / collect), its fences and shelter (FarmShared.Art.Animals) and
-- up to six animals, each with the product it shows when ready.
local function buildPen(plot: Model, id: string, at: (Vector3, number) -> CFrame)
	local def = Animals.pens[id]
	local pos = LAYOUT.pens[id]
	local pen = Instance.new("Model")
	pen.Name = id
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(12, 0.4, 12),
		CFrame = at(pos, 0.4),
		Color = ArtAnimals.FLOOR_COLOR[id] or Palette.grassLight,
		Parent = pen,
	})
	floor:SetAttribute("Interact", "Pen")
	floor:SetAttribute("PenId", id)
	-- The gate faces south (+Z), toward the Barn and the spawn. Fences and animals let taps
	-- through to the floor.
	local facing = at(pos, 0.6) * Kit.yaw(180)
	pen:SetAttribute("BaseCFrame", facing)
	ArtAnimals.pen(id, facing, pen)
	local height = ArtAnimals.HEIGHT[id] or 2.5
	for i, spot in ANIMAL_SPOTS do
		local stand = facing * CFrame.new(spot) * Kit.yaw(ANIMAL_TURNS[i])
		local animal = ArtAnimals.animal(id, stand, "Animal_" .. i)
		Kit.fade(animal, 1)
		animal.Parent = pen
		local product =
			ArtAnimals.product(id, facing * CFrame.new(spot + Vector3.new(0, height + 0.3, 0)), "Product_" .. i)
		Kit.fade(product, 1)
		product.Parent = pen
	end
	label(floor, def.displayName, 5, UDim2.fromOffset(140, 28), 40)
	pen.Parent = plot
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
	model:SetAttribute("PlotOrigin", origin) -- plot-local space for the client's placement ghost

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

	-- Gate with the owner's name, facing the Ring Road. A painted name sign on the gate
	-- (readable from both sides) instead of a floating label, so it never overlaps the Order
	-- Board from the default camera.
	local sign = ArtBuildings.gate(model, at(Vector3.new(0, 0, 47), 0) * Kit.yaw(180))
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
		text.TextColor3 = Palette.cocoa
		text.Text = player.DisplayName .. "'s Farm"
		text.Parent = surface
		surface.Parent = sign
	end

	-- A few trees and flowering bushes in the free corners and along the spine path
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local d = Kit.builder(decor, at(Vector3.zero, 0.25), false)
	for i, spot in DECOR_TREES do
		Kit.tree(d, "Tree", spot, if i % 2 == 0 then 1.1 else 0.9, Palette.treeTop, Palette.treeTopDark, Palette.trunk)
	end
	for i, spot in DECOR_BUSHES do
		Kit.bush(d, "Bush", spot, 1, Palette.treeTop, if i % 2 == 0 then Palette.flowerPink else Palette.flowerYellow)
	end
	-- Kit leaves non-colliding parts out of queries; placed decorations must still see them
	for _, part in decor:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = true
		end
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
	-- Beds are added by refreshFields as the farm earns them

	-- Land not cleared yet: a darker overlay with a sign per expansion
	local landFolder = Instance.new("Folder")
	landFolder.Name = "Land"
	landFolder.Parent = model
	for stage, def in Land.expansions do
		local rects = { LAYOUT.land[stage] }
		if stage == 4 then
			table.insert(rects, LAYOUT.land[5])
		end
		for i, rect in rects do
			local min, max = rect[1], rect[2]
			local center = (min + max) / 2
			local overlay = part({
				Name = string.format("Locked_%d_%d", stage, i),
				Size = Vector3.new(max.X - min.X - 1, 0.2, max.Z - min.Z - 1),
				CFrame = at(center, 0.2),
				Color = COLORS.wild:Lerp(Color3.new(0, 0, 0), 0.25),
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = landFolder,
			})
			overlay:SetAttribute("LandStage", stage)
			if i == 1 then
				label(overlay, def.displayName .. " (locked)", 4, UDim2.fromOffset(180, 30), 80)
			end
		end
	end

	-- Barn, door facing east toward the spine path
	local barn = ArtBuildings.barn(model, at(LAYOUT.barn, 0) * Kit.yaw(-90), 14, 16)
	barn:SetAttribute("Interact", "Barn")
	label(barn, "Barn", 12)

	for _, id in Balance.enabledFactories do
		buildFactory(model, id, at)
	end
	for _, id in Balance.enabledPens do
		buildPen(model, id, at)
	end

	-- Order Board with the truck waiting at its dock. The cards show on the board's west face.
	local board = part({
		Name = "OrderBoard",
		Size = Vector3.new(0.5, 7, 10),
		CFrame = at(LAYOUT.orderBoard, 6),
		Color = Palette.cork,
		Parent = model,
	})
	board:SetAttribute("Interact", "OrderBoard")
	ArtBuildings.orderBoard(board, 6)
	ArtBuildings.dock(model, at(LAYOUT.truck, 0))

	-- The truck's root is an invisible box the drive tween moves; the model is welded to it.
	local truck = part({
		Name = "Truck",
		Size = Vector3.new(6, 3, 10),
		CFrame = at(LAYOUT.truck, 2.5),
		CanCollide = false,
		Parent = model,
	})
	ArtBuildings.truck(truck)
	model:SetAttribute("TruckHome", truck.CFrame)

	model.PrimaryPart = model:FindFirstChild("StartArea") :: BasePart
	model.Parent = plotsFolder
	return model
end

---------------------------------------------------------------------------------------------
-- Visuals that follow the data
---------------------------------------------------------------------------------------------

-- Show or remove a construction scaffold around a building. `holder` must carry the
-- "BaseCFrame" attribute (its bottom-centre, front at local -Z).
local function setScaffold(holder: Instance, show: boolean, w: number, d: number, h: number)
	local existing = holder:FindFirstChild("Scaffold")
	if show and existing == nil then
		local base = holder:GetAttribute("BaseCFrame") :: CFrame?
		if base then
			Kit.scaffold(holder, base, w, d, h)
		end
	elseif not show and existing then
		existing:Destroy()
	end
end

-- One town building (FarmShared.Art.Houses / Community), tapped to open the Town panel.
-- Rebuilt when its state changes; while it's being built it stands faded in a scaffold.
local function townModel(
	folder: Instance,
	name: string,
	at: CFrame,
	kind: string,
	typeId: string,
	lotSize: number,
	tint: number,
	building: boolean,
	labelText: string?
)
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Model")
	holder.Name = name
	holder:SetAttribute("BaseCFrame", at)
	local body = if kind == "House"
		then ArtHouses.build(typeId, holder, at, { size = lotSize, roof = ArtHouses.ROOF_TINTS[(tint % 3) + 1] })
		else ArtCommunity.build(typeId, holder, at, lotSize)
	body.Name = "Body"
	body:SetAttribute("Interact", "Town")
	if building then
		Kit.fade(holder, 0.5)
		Kit.scaffold(holder, at, lotSize - 1, lotSize - 1, if kind == "House" then 8 else 9)
	end
	if labelText then
		label(body, labelText, 8, UDim2.fromOffset(140, 28), 40)
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
			-- The row nearest the gate faces it; the row behind faces Main Street
			local turn = if pos.Z < 60 then 0 else 180
			townModel(
				folder,
				name,
				slot.cframe * CFrame.new(pos) * Kit.yaw(turn),
				"House",
				house.type,
				8,
				house.lot,
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
			townModel(
				folder,
				name,
				slot.cframe * CFrame.new(pos),
				"Community",
				id,
				12,
				def.order,
				not TownRules.isDone(entry, now),
				def.displayName
			)
		end
	end
end

local function buildField(fieldsFolder: Instance, slot: Slot, id: string)
	local pos = LAYOUT.fields[id]
	if pos == nil then
		return
	end
	local bed = part({
		Name = "Field_" .. id,
		Size = Vector3.new(8, 1, 8),
		CFrame = slot.cframe * CFrame.new(pos.X, 0.5, pos.Z),
		Color = COLORS.soil,
	})
	bed:SetAttribute("Interact", "Field")
	bed:SetAttribute("FieldId", id)
	ArtCrops.dressBed(bed)
	-- The crop model for the current growth stage; refreshFields swaps it
	Kit.model("Crop", bed)
	bed.Parent = fieldsFolder
end

local function refreshLand(player: Player, model: Model, data: { [string]: any }, now: number)
	local folder = model:FindFirstChild("Land")
	if folder == nil then
		return
	end
	local cache = landVisualState[player]
	for stage, def in Land.expansions do
		local entry = data.land[stage]
		local state = if entry == nil then "locked" elseif TownRules.isDone(entry, now) then "open" else "clearing"
		if cache[stage] == state then
			continue
		end
		cache[stage] = state
		for _, overlay in folder:GetChildren() do
			if overlay:GetAttribute("LandStage") ~= stage then
				continue
			end
			if state == "open" then
				overlay:Destroy()
			else
				local sign = overlay:FindFirstChild("Label")
				local text = sign and sign:FindFirstChild("Text") :: TextLabel?
				if text then
					text.Text = def.displayName .. (if state == "clearing" then " (clearing...)" else " (locked)")
				end
			end
		end
	end
end

local function refreshFields(player: Player, model: Model, data: { [string]: any }, now: number)
	local cache = fieldVisualState[player]
	local fieldsFolder = model:FindFirstChild("Fields")
	local slot = slotByPlayer[player]
	if fieldsFolder == nil or slot == nil then
		return
	end
	for id in data.fields do
		if fieldsFolder:FindFirstChild("Field_" .. id) == nil then
			buildField(fieldsFolder, slot, id)
		end
	end
	for id, field in data.fields do
		-- Growth stage 1-4 (seeded, sprout, growing, ready). A Gem speed-up sets readyAt to
		-- now and leaves plantedAt alone, so progress comes from the two together.
		local stage = 0
		if field.crop ~= nil then
			local ready = Timer.isReady(field.readyAt, now)
			local span = (field.readyAt or now) - (field.plantedAt or now)
			local progress = if span > 0 then math.clamp((now - (field.plantedAt or now)) / span, 0, 1) else 1
			stage = ArtCrops.stageFor(progress, ready)
		end
		local state = if field.crop == nil then "empty" else string.format("%s:%d", field.crop, stage)
		if cache[id] == state then
			continue
		end
		local bed = fieldsFolder:FindFirstChild("Field_" .. id) :: BasePart?
		if bed == nil then
			continue
		end
		cache[id] = state
		bed:SetAttribute("Crop", field.crop)
		bed:SetAttribute("ReadyAt", field.readyAt)
		local old = bed:FindFirstChild("Crop")
		if old then
			old:Destroy()
		end
		if field.crop == nil then
			Kit.model("Crop", bed)
		else
			local def = Crops[field.crop]
			local crop =
				ArtCrops.build(field.crop, stage, bed.CFrame * CFrame.new(0, bed.Size.Y / 2, 0), def and def.color)
			crop.Parent = bed
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

	-- Not built yet: a faint ghost. Building: half-faded inside a scaffold. Built: solid.
	local fade = if not factory.built then 0.75 elseif underConstruction then 0.4 else 0
	setScaffold(building, underConstruction, 10, 12, 10)
	Kit.fade(building, fade, function(p)
		local name = p.Name
		return name == "OutputTable" or name == "TableTop" or p.Parent.Name == "Scaffold"
	end)
	-- The client's FactoryMotion turns the factory's moving parts while this is set
	building:SetAttribute("Busy", busy)
	local chimney = building:FindFirstChild("Chimney")
	local smoke = chimney and chimney:FindFirstChildOfClass("Smoke")
	if smoke then
		smoke.Enabled = busy
	end
	local glow = building:FindFirstChild("OvenGlow", true) :: BasePart?
	if glow then
		glow.Material = if busy then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end

	-- Each finished item stands on the output table as its own prop (FarmShared.Art.ItemProps):
	-- four along the table, then a second layer on top.
	for _, child in building:GetChildren() do
		if child.Name == "Goods" then
			child:Destroy()
		end
	end
	local outputTable = building:FindFirstChild("OutputTable", true) :: BasePart?
	if outputTable == nil then
		return
	end
	local ids = {}
	for itemId in output do
		table.insert(ids, itemId)
	end
	table.sort(ids)
	local tableTop = outputTable.Size.Y / 2 + 0.3
	local i = 0
	for _, itemId in ids do
		for _ = 1, output[itemId] do
			local row = i % 4
			local layer = i // 4
			local at = outputTable.CFrame * CFrame.new(0, tableTop + layer * 2.2, -3 + row * 2)
			ArtItemProps.build(itemId, at * Kit.yaw(-90), "Goods").Parent = building
			i += 1
		end
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
	setScaffold(building, underConstruction, 12, 12, 6)
	for _, child in building:GetChildren() do
		local name = child.Name
		if name:sub(1, 7) ~= "Animal_" and name:sub(1, 8) ~= "Product_" and name ~= "Scaffold" then
			Kit.fade(child, shell)
		end
	end
	for i = 1, #ANIMAL_SPOTS do
		local animal = building:FindFirstChild("Animal_" .. i)
		local product = building:FindFirstChild("Product_" .. i)
		local mark = marks[i]
		if animal then
			Kit.fade(animal, if mark == nil then 1 elseif underConstruction then 0.5 else 0)
		end
		if product then
			Kit.fade(product, if mark == "r" then 0 else 1)
		end
	end
end

-- Decorations: rebuilt whole when the saved list changes (it's small)
local decorVisualState: { [Player]: string } = {}

local function refreshDecor(player: Player, model: Model, data: { [string]: any })
	local parts = {}
	for _, p in data.decor do
		table.insert(parts, string.format("%s:%d:%d:%d", p.id, p.x, p.z, p.r))
	end
	local key = table.concat(parts, ";")
	if decorVisualState[player] == key then
		return
	end
	decorVisualState[player] = key
	local folder = model:FindFirstChild("Placed")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Placed"
		folder.Parent = model
	end
	folder:ClearAllChildren()
	local slot = slotByPlayer[player]
	for i, p in data.decor do
		local origin = slot.cframe * CFrame.new(p.x, 0.25, p.z) * CFrame.Angles(0, p.r * math.pi / 2, 0)
		DecorModels.build(p.id, origin, i).Parent = folder
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
	refreshLand(player, model, data, now)
	refreshDecor(player, model, data)
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
			landVisualState[player] = {}
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
	landVisualState[player] = nil
	decorVisualState[player] = nil
	truckBusy[player] = nil
end

-- Is anything solid on the plot (a building, field, fence...) inside this plot-local
-- footprint? Flat ground and paths don't count, and placed decorations (the "Placed" folder) are
-- checked by DecorRules. The built-in scenery trees in "Decor" do block.
function PlotService.blocked(player: Player, x: number, z: number, width: number, depth: number): boolean
	local model = plotsByPlayer[player]
	local slot = slotByPlayer[player]
	if model == nil or slot == nil then
		return true
	end
	local include = {}
	for _, child in model:GetChildren() do
		if child.Name ~= "Placed" then
			table.insert(include, child)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	-- From just above flat ground (paths, the start area) to head height
	local box = slot.cframe * CFrame.new(x, 3.3, z)
	return #Workspace:GetPartBoundsInBox(box, Vector3.new(width - 0.4, 5.4, depth - 0.4), params) > 0
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
		Kit.fade(truck, 1)
		task.wait(math.max(0, returnSeconds - leg * 2))
		if truck.Parent == nil then
			return
		end
		Kit.fade(truck, 0)
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
