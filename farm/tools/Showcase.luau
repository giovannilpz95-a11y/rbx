-- Lays the art models out on a patch of grass for previews and budget checks.

local Kit = require("../src/shared/Art/Kit")
local Palette = require("../src/shared/Art/Palette")
local ArtCrops = require("../src/shared/Art/Crops")
local ArtAnimals = require("../src/shared/Art/Animals")
local ArtBuildings = require("../src/shared/Art/Buildings")
local ArtFactories = require("../src/shared/Art/Factories")
local ArtHouses = require("../src/shared/Art/Houses")
local ArtCommunity = require("../src/shared/Art/Community")
local ArtDecor = require("../src/shared/Art/Decor")
local ArtMarket = require("../src/shared/Art/Market")
local ArtRail = require("../src/shared/Art/Rail")
local ArtItemProps = require("../src/shared/Art/ItemProps")
local ArtMotion = require("../src/shared/Art/Motion")
local ArtFolk = require("../src/shared/Art/Folk")
local ArtPickups = require("../src/shared/Art/Pickups")
local ArtTown = require("../src/shared/Art/Town")
local Items = require("../src/shared/Items")

local Showcase = {}

local CROPS = { "Wheat", "Corn", "Carrots", "Sugarcane", "Cotton", "Tomatoes", "PineTrees" }

local function ground(root: Instance, size: number)
	local b = Kit.builder(root, CFrame.new(), false)
	b.block("Ground", Vector3.new(size, 1, size), Vector3.new(0, -0.5, 0), Palette.grass)
end

local function field(root: Instance, at: CFrame): Part
	local b = Kit.builder(root, at, true)
	local bed = b.block("Field", Vector3.new(8, 1, 8), Vector3.new(0, 0.5, 0), Palette.soil)
	ArtCrops.dressBed(bed)
	return bed
end

local SCENES: { [string]: (Instance) -> () } = {}

-- Crops: one column per crop, one row per stage (front row = seeded)
SCENES.crops = function(root)
	ground(root, 90)
	for i, crop in CROPS do
		for stage = 1, 4 do
			local at = CFrame.new((i - 3.5) * 11, 0, (stage - 2.5) * 11)
			local bed = field(root, at)
			local m = ArtCrops.build(crop, stage, bed.CFrame * CFrame.new(0, 0.5, 0), { 220, 60, 50 })
			m.Parent = bed
		end
	end
	-- An empty, freshly dug field in front of the first row
	local bed = field(root, CFrame.new(-2.5 * 11, 0, -27.5))
	ArtCrops.tilled(bed.CFrame * CFrame.new(0, 0.5, 0)).Parent = bed
end

local ANIMAL_SPOTS = {
	Vector3.new(-3.5, 0, -2.5),
	Vector3.new(0, 0, -2.5),
	Vector3.new(3.5, 0, -2.5),
	Vector3.new(-3.5, 0, 2.5),
	Vector3.new(0, 0, 2.5),
	Vector3.new(3.5, 0, 2.5),
}

SCENES.animals = function(root)
	ground(root, 70)
	for i, penId in { "CowBarn", "ChickenCoop", "SheepFold" } do
		local at = CFrame.new((i - 2) * 15, 0, 0)
		local b = Kit.builder(root, at, true)
		b.block("Floor", Vector3.new(12, 0.4, 12), Vector3.new(0, 0.2, 0), ArtAnimals.FLOOR_COLOR[penId])
		local pen = Kit.model(penId, root)
		ArtAnimals.pen(penId, at * CFrame.new(0, 0.4, 0), pen)
		-- The Cow Barn is hungry; the others are fed with products waiting in the crate
		ArtAnimals.setPenState(pen, i ~= 1, i ~= 1)
		for j, spot in ANIMAL_SPOTS do
			local a = ArtAnimals.animal(
				penId,
				at * CFrame.new(spot + Vector3.new(0, 0.4, 0)) * Kit.yaw(j * 50),
				"Animal_" .. j
			)
			a.Parent = root
			if j % 2 == 0 then
				local p = ArtAnimals.product(
					penId,
					at * CFrame.new(spot + Vector3.new(0, 0.4 + ArtAnimals.HEIGHT[penId], 0)),
					"Product_" .. j
				)
				p.Parent = root
			end
		end
	end
end

-- Pen upgrade looks: the Cow Barn at levels 1-5, then the Coop and the Fold at level 5 with
-- their gates swung open
SCENES.upgrades = function(root)
	ground(root, 110)
	local rows = {
		{ "CowBarn", 1 },
		{ "CowBarn", 2 },
		{ "CowBarn", 3 },
		{ "CowBarn", 4 },
		{ "CowBarn", 5 },
		{ "ChickenCoop", 5 },
		{ "SheepFold", 5 },
	}
	for i, row in rows do
		local penId, level = row[1], row[2]
		local at = if i <= 5 then CFrame.new((i - 3) * 16, 0, -10) else CFrame.new((i - 6.5) * 16, 0, 10)
		local b = Kit.builder(root, at, true)
		b.block("Floor", Vector3.new(12, 0.4, 12), Vector3.new(0, 0.2, 0), ArtAnimals.FLOOR_COLOR[penId])
		local pen = Kit.model(penId, root)
		ArtAnimals.pen(penId, at * CFrame.new(0, 0.4, 0), pen)
		ArtAnimals.setPenLevel(pen, penId, level)
		if i > 5 then
			local gate = pen:FindFirstChild("Gate", true) :: BasePart
			gate.CFrame = ArtMotion.gateCFrame(gate, 1) :: CFrame
		end
	end
end

-- Barn look 2 with a full overflow pile, the Tool Shed with every tool, and the held tools
SCENES.barn2 = function(root)
	ground(root, 80)
	local barnAt = CFrame.new(0, 0, 0)
	local barn = ArtBuildings.barn(root, barnAt, 14, 16)
	ArtBuildings.setBarnLook(barn, 2)
	ArtBuildings.setBarnOverflow(barn, 1)
	local shed = ArtBuildings.toolShed(root, barnAt * CFrame.new(-14 / 2 - 2.2, 0, 1) * Kit.yaw(90))
	ArtBuildings.setToolShedTools(shed, { Shovel = 1, Axe = 1, Saw = 1 })
	for i, id in { "Tool_Scythe", "Tool_SeedBag", "Tool_WateringCan" } do
		local tool = ArtItemProps.held(id, CFrame.new(-6 + i * 3, 2, -16)) :: Model
		tool.Parent = root
	end
end

-- The Town Hall at 1-3 storeys, the guides and the Builder, the Puzzle Porch, pickups, and a
-- patch of locked land with its signpost
SCENES.town = function(root)
	ground(root, 120)
	for i = 1, 3 do
		ArtTown.townHall(root, CFrame.new((i - 2) * 18, 0, 0), i)
	end
	for i, role in ArtFolk.ROLES do
		ArtFolk.build(role, CFrame.new(-8 + i * 3, 0, -14)).Parent = root
	end
	ArtTown.porch(root, CFrame.new(16, 0, -14))
	for i, kind in ArtPickups.KINDS do
		ArtPickups.build(kind, CFrame.new(-22 + i * 2, 2, -14)).Parent = root
	end
	local b = Kit.builder(root, CFrame.new(), false)
	local min, max = Vector3.new(-30, 0, 12), Vector3.new(30, 0, 44)
	b.block("Locked", Vector3.new(60, 0.2, 32), Vector3.new(0, 0.1, 28), Palette.grassWild:Lerp(Palette.cocoa, 0.25))
	for _, spot in ArtTown.scatter(min, max, 12) do
		ArtTown.obstacle(spot.id, root, CFrame.new(spot.at + Vector3.new(0, 0.2, 0)) * Kit.yaw(spot.yaw))
	end
	ArtTown.signpost(root, CFrame.new(0, 0.2, 28) * Kit.yaw(180))
end

SCENES.buildings = function(root)
	ground(root, 90)
	ArtBuildings.barn(root, CFrame.new(-22, 0, 0), 14, 16)
	local boardRoot = Kit.builder(root, CFrame.new(0, 0, 0), true)
	local board =
		boardRoot.block("OrderBoard", Vector3.new(0.5, 7, 10), CFrame.new(0, 6, 0) * Kit.yaw(180), Palette.cork)
	ArtBuildings.orderBoard(board, 6)
	ArtBuildings.dock(root, CFrame.new(12, 0, 0))
	local truck = boardRoot.block("Truck", Vector3.new(6, 3, 10), Vector3.new(12, 2.5, 0), Palette.roofMustard)
	ArtBuildings.truck(truck)
	ArtBuildings.gate(root, CFrame.new(0, 0, 20))
end

SCENES.factories = function(root)
	ground(root, 90)
	for i, id in { "Bakery", "FeedMill", "Dairy", "SugarMill", "TextileMill" } do
		local m = Kit.model(id, root)
		ArtFactories.build(id, m, CFrame.new((i - 3) * 14, 0, 0))
	end
end

-- The content bank's factories (level 13+), in unlock order
SCENES.bankFactories = function(root)
	ground(root, 90)
	for i, id in { "SnackFactory", "Diner", "PaperMill", "IceCreamParlor" } do
		local m = Kit.model(id, root)
		ArtFactories.build(id, m, CFrame.new((i - 2.5) * 14, 0, 0))
	end
end

SCENES.houses = function(root)
	ground(root, 100)
	for i, id in ArtHouses.TYPES do
		local m = Kit.model(id, root)
		ArtHouses.build(id, m, CFrame.new((i - 4) * 13, 0, 0))
	end
end

SCENES.community = function(root)
	ground(root, 140)
	for i, id in ArtCommunity.TYPES do
		local m = Kit.model(id, root)
		local row = (i - 1) // 5
		ArtCommunity.build(id, m, CFrame.new(((i - 1) % 5 - 2) * 15, 0, row * 16))
	end
end

-- A whole start area laid out like PlotService does it (positions copied from its LAYOUT),
-- with a mix of crop stages, full pens and part of Main Street built.
SCENES.plot = function(root)
	local b = Kit.builder(root, CFrame.new(), false)
	b.block("Wild", Vector3.new(200, 1, 200), Vector3.new(0, -0.5, 20), Palette.grassWild)
	b.block("StartArea", Vector3.new(96, 0.2, 96), Vector3.new(0, 0.1, 0), Palette.grass)
	b.block("SpinePath", Vector3.new(8, 0.2, 58), Vector3.new(0, 0.3, 19), Palette.path)
	b.block("FarmLane", Vector3.new(44, 0.2, 8), Vector3.new(-18, 0.3, -22), Palette.path)
	b.block("CrossPath", Vector3.new(8, 0.2, 20), Vector3.new(0, 0.3, -16), Palette.path)
	b.block("GateRoad", Vector3.new(8, 0.2, 48), Vector3.new(0, 0.3, 72), Palette.path)
	b.block("MainStreet", Vector3.new(184, 0.2, 8), Vector3.new(0, 0.3, 75), Palette.path)
	local fields = {
		{ -34, -31, "Wheat", 4 },
		{ -22, -31, "Wheat", 3 },
		{ -10, -31, "Corn", 4 },
		{ -34, -13, "Carrots", 4 },
		{ -22, -13, "Sugarcane", 4 },
		{ -10, -13, "Cotton", 4 },
		{ -34, -43, "Wheat", 1 },
		{ -22, -43, "Corn", 2 },
		{ -10, -43, "Carrots", 3 },
		{ 2, -43, "Wheat", 4 },
	}
	for _, f in fields do
		local bedPart = field(root, CFrame.new(f[1], 0, f[2]))
		ArtCrops.build(f[3], f[4], bedPart.CFrame * CFrame.new(0, 0.5, 0), { 220, 60, 50 }).Parent = bedPart
	end
	local pens =
		{ CowBarn = Vector3.new(-12, 0, 6), ChickenCoop = Vector3.new(-26, 0, 6), SheepFold = Vector3.new(-40, 0, 6) }
	for id, pos in pens do
		b.block("Floor", Vector3.new(12, 0.4, 12), pos + Vector3.new(0, 0.4, 0), ArtAnimals.FLOOR_COLOR[id])
		local facing = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * Kit.yaw(180)
		ArtAnimals.pen(id, facing, root)
		for j, spot in ANIMAL_SPOTS do
			ArtAnimals.animal(id, facing * CFrame.new(spot) * Kit.yaw(({ 160, 200, 175, 20, -15, 200 })[j])).Parent =
				root
			if j == 2 or j == 6 then
				ArtAnimals.product(id, facing * CFrame.new(spot + Vector3.new(0, ArtAnimals.HEIGHT[id] + 0.3, 0))).Parent =
					root
			end
		end
	end
	local factories = { Bakery = 16, FeedMill = 2, Dairy = -12, SugarMill = -26, TextileMill = -40 }
	for id, z in factories do
		ArtFactories.build(id, Kit.model(id, root), CFrame.new(30, 0, z) * Kit.yaw(90))
	end
	ArtBuildings.barn(root, CFrame.new(-28, 0, 30) * Kit.yaw(-90), 14, 16)
	local board = b.block("OrderBoard", Vector3.new(0.5, 7, 10), Vector3.new(12, 6, 34), Palette.cork)
	ArtBuildings.orderBoard(board, 6)
	ArtBuildings.dock(root, CFrame.new(26, 0, 36))
	ArtBuildings.truck(b.block("Truck", Vector3.new(6, 3, 10), Vector3.new(26, 2.5, 36), Palette.cork))
	ArtBuildings.gate(root, CFrame.new(0, 0, 47) * Kit.yaw(180))
	local d = Kit.builder(root, CFrame.new(0, 0.25, 0), false)
	for i, spot in
		{
			Vector3.new(42, 0, 44),
			Vector3.new(-44, 0, 44),
			Vector3.new(-45, 0, 21),
			Vector3.new(45, 0, 30),
			Vector3.new(44, 0, -46),
			Vector3.new(-44, 0, -47),
		}
	do
		Kit.tree(d, "Tree", spot, if i % 2 == 0 then 1.1 else 0.9, Palette.treeTop, Palette.treeTopDark, Palette.trunk)
	end
	for i, spot in
		{
			Vector3.new(-6, 0, 36),
			Vector3.new(-6, 0, 26),
			Vector3.new(6, 0, 26),
			Vector3.new(-16, 0, 44),
			Vector3.new(16, 0, 44),
		}
	do
		Kit.bush(d, "Bush", spot, 1, Palette.treeTop, if i % 2 == 0 then Palette.flowerPink else Palette.flowerYellow)
	end
	local houses = {
		{ -10, 54, "Cottage" },
		{ -10, 64, "Bungalow" },
		{ -20, 54, "LeanTo" },
		{ -20, 64, "RowHouse" },
		{ 10, 54, "Farmhouse" },
		{ 10, 64, "Duplex" },
		{ -30, 54, "Townhouse" },
	}
	for i, h in houses do
		local turn = if h[2] < 60 then 0 else 180
		ArtHouses.build(
			h[3],
			Kit.model(h[3], root),
			CFrame.new(h[1], 0, h[2]) * Kit.yaw(turn),
			{ size = 8, roof = ArtHouses.ROOF_TINTS[(i % 3) + 1] }
		)
	end
	for i, id in { "VillageWell", "PicnicPavilion", "Schoolhouse" } do
		ArtCommunity.build(id, Kit.model(id, root), CFrame.new(-13 - (i - 1) * 15, 0, 86), 12)
	end
end

SCENES.decor = function(root)
	ground(root, 70)
	local row = {
		{ "GravelPath", -18, -12 },
		{ "BrickPath", -13, -12 },
		{ "PicketFence", -8, -12 },
		{ "HedgeRow", -3, -12 },
		{ "FlowerBed", 2, -12 },
		{ "LampPost", 7, -12 },
		{ "Bench", 14, -12 },
		{ "HayBales", -16, -2 },
		{ "OakTree", -6, -2 },
		{ "PicnicTable", 4, -2 },
		{ "Pond", -10, 12 },
		{ "StoneFountain", 6, 12 },
	}
	for _, d in row do
		local m = Kit.model(d[1], root)
		ArtDecor.build(d[1], m, CFrame.new(d[2], 0, d[3]))
	end
end

-- The train set at the station, and two Market stalls
SCENES.rail = function(root)
	ground(root, 80)
	ArtRail.station(root, CFrame.new(0, 0, 0))
	for i, kind in { "Buffer", "Straight", "Crossing", "Straight" } do
		ArtRail.track(kind, root, CFrame.new(-24 + (i - 1) * 16, 0, -6.5) * Kit.yaw(180))
	end
	ArtRail.engine(root, CFrame.new(-4, 0, -6.5))
	for i = 1, 2 do
		local car = ArtRail.cargoCar(root, CFrame.new(-15 - (i - 1) * 10.6, 0, -6.5))
		ArtRail.setCarCrates(car, i + 1)
	end
	ArtRail.helpCrate(root, CFrame.new(7, 1.2, 1))
	local stall = ArtMarket.stall(root, CFrame.new(-10, 0, -22) * Kit.yaw(180), "Teal")
	ArtMarket.pennant(stall, CFrame.new(-6.2, 6, -20.2) * Kit.yaw(180))
	ArtMarket.stall(root, CFrame.new(4, 0, -22) * Kit.yaw(180), "Plum")
end

-- The Town Express station with the giant train on a curve, and the Event Tent
SCENES.express = function(root)
	ground(root, 100)
	local station = ArtRail.expressStation(root, CFrame.new(0, 0, 0))
	ArtRail.setExpressProgress(station, 0.55)
	for i = 1, 3 do
		ArtRail.track("Straight", root, CFrame.new(-24 + (i - 1) * 16, 0, -9) * Kit.yaw(180))
	end
	ArtRail.track("Curve", root, CFrame.new(24, 0, -9))
	ArtRail.engine(root, CFrame.new(10, 0, -9), ArtRail.EXPRESS_SCALE)
	for i = 1, 2 do
		local car = ArtRail.cargoCar(root, CFrame.new(-7 - (i - 1) * 16.6, 0, -9), ArtRail.EXPRESS_SCALE)
		ArtRail.setCarCrates(car, i + 1)
	end
	local tent = ArtTown.eventTent(root, CFrame.new(-30, 0, -32) * Kit.yaw(180))
	ArtTown.setEventTent(tent, true, Palette.plum)
	ArtTown.eventTent(root, CFrame.new(-10, 0, -32) * Kit.yaw(180))
end

-- The level 13+ decorations, two rows
SCENES.decor2 = function(root)
	ground(root, 60)
	local row = {
		{ "SteppingStones", -15, -8 },
		{ "FarmLane", -10, -8 },
		{ "RailFence", -5, -8 },
		{ "StoneWall", 0, -8 },
		{ "PottedFlowers", 5, -8 },
		{ "SunflowerPatch", 10, -8 },
		{ "Scarecrow", 15, -8 },
		{ "RoundPine", -14, 4 },
		{ "BlossomTree", -4, 4 },
		{ "Topiary", 4, 4 },
		{ "Birdbath", 9, 4 },
		{ "GardenSwing", 16, 4 },
	}
	for _, d in row do
		local m = Kit.model(d[1], root)
		ArtDecor.build(d[1], m, CFrame.new(d[2], 0, d[3]))
	end
end

SCENES.decor3 = function(root)
	ground(root, 60)
	local row = {
		{ "DaffodilBed", -15, -8 },
		{ "PalmPair", -9, -8 },
		{ "FishingJetty", -3, -8 },
		{ "GardenObelisk", 3, -8 },
		{ "DeckChairs", 9, -8 },
		{ "PumpkinCart", 15, -8 },
		{ "RoseBed", -15, 6 },
		{ "IrisBed", -9, 6 },
		{ "Rowboat", -3, 6 },
		{ "Treehouse", 3, 6 },
		{ "TieredFountain", 9, 6 },
		{ "WeepingWillow", 15, 6 },
	}
	for _, d in row do
		local m = Kit.model(d[1], root)
		ArtDecor.build(d[1], m, CFrame.new(d[2], 0, d[3]))
	end
end

SCENES.items = function(root)
	ground(root, 40)
	local ids = {}
	for id in Items do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in { "Shovel", "Axe", "Saw" } do
		table.insert(ids, id)
	end
	for i, id in ids do
		local col, row = (i - 1) % 8, (i - 1) // 8
		ArtItemProps.build(id, CFrame.new(-10.5 + col * 3, 0, -6 + row * 3.5)).Parent = root
	end
end

function Showcase.build(name: string, root: Instance)
	if name == "all" then
		for key, scene in SCENES do
			local m = Instance.new("Model")
			m.Name = key
			scene(m)
			m.Parent = root
		end
		return
	end
	local scene = SCENES[name]
	assert(scene, "unknown scene " .. name)
	scene(root)
end

Showcase.SCENES = SCENES

return Showcase
