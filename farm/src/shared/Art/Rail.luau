--!strict
-- The train set (16 Model Catalog §2.7, Model List - Town & Factories §5, P1 for the week-6
-- Train update): the Train Station, the "teapot" engine, cargo cars, the Help Crate and the
-- track pieces. All original, built from Parts as the source for single meshes later.
-- The station's front (the track side) faces local -Z; the train runs along local +X.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtRail = {}

ArtRail.STATION_PARTS_MAX = 44
ArtRail.ENGINE_PARTS_MAX = 15
ArtRail.CAR_PARTS_MAX = 10 -- with all 3 crates loaded
ArtRail.CAR_CRATES = 3
ArtRail.HELPCRATE_PARTS_MAX = 5
ArtRail.TRACK_PARTS_MAX = 9 -- the Curve; the others are 6 or fewer
ArtRail.TRACK_TYPES = { "Straight", "Buffer", "Crossing", "Curve" }
ArtRail.EXPRESS_PARTS_MAX = 60
ArtRail.EXPRESS_SIZE = Vector3.new(48, 0, 14) -- the Town Express hub station's footprint
ArtRail.EXPRESS_SCALE = 1.6 -- the giant server train: the same engine and cars, bigger
ArtRail.EXPRESS_TIERS = { 0.25, 0.5, 0.75, 1 } -- reward tiers (14 Multiplayer Features C1)
ArtRail.CURVE_RADIUS = 20 -- the Curve turns 45 degrees toward local -Z over this radius
ArtRail.CURVE_DEGREES = 45

ArtRail.STATION_SIZE = Vector3.new(32, 0, 14) -- footprint: width (X) x depth (Z)
ArtRail.TRACK_LENGTH = 16
ArtRail.CAR_LENGTH = 10
ArtRail.ENGINE_LENGTH = 12
ArtRail.GAUGE = 3 -- rail centre to rail centre
ArtRail.RAIL_TOP = 0.7 -- wheels sit on this height

local QUIET = { shadow = false }
local SOLID = { collide = true }
local FLOOR = 1.2 -- platform top

---------------------------------------------------------------------------------------------
-- Train Station: a long timber platform under a teal barrel-roof canopy, a ticket booth with
-- a loaf-arch window, a hanging station clock, a departure board on the back wall, a bench and
-- a small loading crane that swings crates into the cars. Returns the model, the departure
-- board (for a SurfaceGui) and the crane (its "Jib" carries a HingeCFrame to swing about).
---------------------------------------------------------------------------------------------

function ArtRail.station(parent: Instance, cf: CFrame): (Model, Part, Model)
	local model = Kit.model("TrainStation", parent)
	local b = Kit.builder(model, cf, true)
	b.block("Platform", Vector3.new(30, FLOOR, 8), Vector3.new(0, FLOOR / 2, 0), Palette.woodLight, SOLID)
	b.block("EdgeLine", Vector3.new(30, 0.1, 0.5), Vector3.new(0, FLOOR + 0.05, -3.6), Palette.roofMustard, QUIET)
	b.block("Steps", Vector3.new(2, FLOOR / 2, 8), Vector3.new(16, FLOOR / 4, 0), Palette.wood, SOLID)

	-- Canopy: four posts and a three-slab barrel roof running along the platform
	for _, x in { -9, 9 } do
		for _, z in { -3, 3 } do
			b.post("CanopyPost", 5.6, 0.5, Vector3.new(x, FLOOR + 2.8, z), Palette.cream)
		end
	end
	Kit.archRoof(b, "Canopy", CFrame.new(0, FLOOR + 5.6, 0) * Kit.yaw(90), 8.6, 22, 1.8, 3, 0.4, Palette.roofTeal)
	local sign = b.block("StationSign", Vector3.new(8, 1.4, 0.3), Vector3.new(0, FLOOR + 6.3, -4.1), Palette.cream)
	b.block("SignTrim", Vector3.new(8.6, 1.9, 0.2), Vector3.new(0, FLOOR + 6.3, -3.95), Palette.wood, QUIET)
	Kit.sproutTag(b, Vector3.new(0, FLOOR + 7.4, 0), 1.2, Palette.wood, Palette.lime)

	-- Station clock hanging from the canopy, facing the track
	local face = CFrame.new(-4.5, FLOOR + 4.6, -2.6) * Kit.yaw(90)
	b.block("ClockHanger", Vector3.new(0.15, 1, 0.15), Vector3.new(-4.5, FLOOR + 5.4, -2.6), Palette.cocoa, QUIET)
	b.cyl("ClockRim", 0.35, 1.9, face, Palette.cocoa)
	b.cyl("Clock", 0.4, 1.5, face * CFrame.new(0.05, 0, 0), Palette.cream, QUIET)
	local hand =
		b.block("ClockHand", Vector3.new(0.12, 0.6, 0.05), CFrame.new(-4.5, FLOOR + 4.85, -2.85), Palette.cocoa, QUIET)
	-- the client ticks it round this point
	hand:SetAttribute("HingeCFrame", CFrame.new(-4.5, FLOOR + 4.6, -2.85))

	-- Back wall with the departure board, and a bench in front of it
	b.block("BackWall", Vector3.new(18, 3.4, 0.4), Vector3.new(0, FLOOR + 1.7, 3.8), Palette.oat, SOLID)
	local board = b.block("DepartureBoard", Vector3.new(6, 2, 0.2), Vector3.new(4.5, FLOOR + 2.1, 3.5), Palette.cocoa)
	b.block("BoardFrame", Vector3.new(6.5, 2.5, 0.15), Vector3.new(4.5, FLOOR + 2.1, 3.58), Palette.wood, QUIET)
	b.block("Bench", Vector3.new(4, 0.35, 1.2), Vector3.new(-4, FLOOR + 1.1, 2.8), Palette.wood)
	b.block("BenchLegs", Vector3.new(3.6, 0.9, 0.9), Vector3.new(-4, FLOOR + 0.45, 2.8), Palette.woodDark, QUIET)

	-- Ticket booth at the west end: a cream hut with a loaf-arch window and a red gable roof
	b.block("Booth", Vector3.new(5, 5, 5), Vector3.new(-12.5, FLOOR + 2.5, 0.5), Palette.cream, SOLID)
	Kit.window(b, "TicketWindow", CFrame.new(-12.5, FLOOR + 2.6, -2), 2, 1.6, Palette.wood, Palette.glass, true)
	Kit.gableRoof(b, "BoothRoof", Vector3.new(-12.5, FLOOR + 5, 0.5), 5.8, 6, 2.2, Palette.roofRed)

	-- Two flower barrels by the steps
	for _, z in { -2.4, 2.4 } do
		b.post("Barrel", 1.2, 1.3, Vector3.new(13.5, FLOOR + 0.6, z), Palette.wood)
		Kit.bush(b, "Flowers", Vector3.new(13.5, FLOOR + 1.1, z), 0.6, Palette.treeTop)
	end

	-- Loading crane at the east end: a mast with a jib reaching out over the track, a rope and
	-- a crate on the hook
	local crane = Kit.model("Crane", model)
	local c = b.into(crane, true)
	c.post("Mast", 6, 0.7, Vector3.new(11, FLOOR + 3, 2.6), Palette.woodDark)
	local jib = c.block("Jib", Vector3.new(0.5, 0.5, 7.4), Vector3.new(11, FLOOR + 6, -0.5), Palette.roofMustard)
	jib:SetAttribute("HingeCFrame", cf * CFrame.new(11, FLOOR + 6, 2.6))
	c.block("Rope", Vector3.new(0.12, 2.6, 0.12), Vector3.new(11, FLOOR + 4.6, -3.8), Palette.sack, QUIET)
	c.block("CraneCrate", Vector3.new(1.4, 1.2, 1.4), Vector3.new(11, FLOOR + 2.8, -3.8), Palette.crate)
	return model, board, crane
end

---------------------------------------------------------------------------------------------
-- Engine: the "teapot engine", a squat brick-red boiler with gold bands, a cab, a scoop
-- cowcatcher and a flowerpot smokestack with an L Sprout Tag. Front at local +X, wheels on
-- the rails at local y = RAIL_TOP. The "Stack" part is where the client puffs smoke.
---------------------------------------------------------------------------------------------

function ArtRail.engine(parent: Instance, cf: CFrame, scale: number?): Model
	local model = Kit.model("Engine", parent)
	local b = Kit.builder(model, cf, true, scale)
	local axle = ArtRail.RAIL_TOP + 1.1
	local deck = axle + 0.7
	b.block("Chassis", Vector3.new(11, 0.8, 3.8), Vector3.new(0, deck, 0), Palette.cocoa)
	for _, x in { -3.4, 0, 3.4 } do
		b.cyl("Wheels", 4.2, 2.2, CFrame.new(x, axle, 0) * Kit.yaw(90), Palette.tire)
	end
	b.cyl("Boiler", 6.4, 4, Vector3.new(1.4, deck + 2.3, 0), Palette.barnRed)
	for _, x in { -0.4, 3.2 } do
		b.cyl("Band", 0.4, 4.2, Vector3.new(x, deck + 2.3, 0), Palette.coins, QUIET)
	end
	b.block("Cab", Vector3.new(3.4, 4.6, 3.8), Vector3.new(-3.6, deck + 2.7, 0), Palette.barnRed)
	b.block("CabRoof", Vector3.new(4.2, 0.45, 4.4), Vector3.new(-3.6, deck + 5.2, 0), Palette.roofMustard)
	b.wedge("Cowcatcher", Vector3.new(3.4, 1.3, 1.4), CFrame.new(5.9, axle + 0.2, 0) * Kit.yaw(-90), Palette.coins)
	b.ball(
		"Headlamp",
		1,
		Vector3.new(4.7, deck + 3.4, 0),
		Palette.lantern,
		{ shadow = false, material = Enum.Material.Neon }
	)
	b.post("Stack", 1.5, 1.4, Vector3.new(3.2, deck + 5, 0), Palette.brick)
	b.post("StackRim", 0.35, 1.8, Vector3.new(3.2, deck + 5.8, 0), Palette.brick:Lerp(Palette.cream, 0.3), QUIET)
	Kit.sproutTag(b, Vector3.new(3.2, deck + 6, 0), 2.5, Palette.wood, Palette.lime)
	return model
end

---------------------------------------------------------------------------------------------
-- Cargo car: a flatbed with low mustard rails, a sign holder showing the requested item, and
-- three crate slots that fill as the order is loaded (setCarCrates). Centred on `cf`, running
-- along local X.
---------------------------------------------------------------------------------------------

function ArtRail.cargoCar(parent: Instance, cf: CFrame, scale: number?): (Model, Part)
	local model = Kit.model("CargoCar", parent)
	local b = Kit.builder(model, cf, true, scale)
	model:SetAttribute("Scale", scale or 1)
	local axle = ArtRail.RAIL_TOP + 0.9
	local deck = axle + 0.8
	b.block("Bed", Vector3.new(9.6, 0.6, 3.8), Vector3.new(0, deck, 0), Palette.woodLight)
	for _, z in { -1.8, 1.8 } do
		b.block("Rail", Vector3.new(9.6, 0.6, 0.25), Vector3.new(0, deck + 0.6, z), Palette.roofMustard)
	end
	for _, x in { -3, 3 } do
		b.cyl("Wheels", 4, 1.8, CFrame.new(x, axle, 0) * Kit.yaw(90), Palette.tire)
	end
	b.block("SignPost", Vector3.new(0.25, 1.6, 0.25), Vector3.new(-4.4, deck + 1.1, 0), Palette.woodDark, QUIET)
	local sign = b.block("ItemSign", Vector3.new(1.4, 1.4, 0.2), Vector3.new(-4.4, deck + 2.4, 0), Palette.cream)
	return model, sign
end

-- Shows `count` crates (0-3) in the car's slots, from the front.
function ArtRail.setCarCrates(car: Model, count: number)
	local old = car:FindFirstChild("Crates")
	if old then
		old:Destroy()
	end
	count = math.clamp(math.floor(count), 0, ArtRail.CAR_CRATES)
	if count == 0 then
		return
	end
	local crates = Kit.model("Crates", car)
	local bed = car:FindFirstChild("Bed") :: BasePart
	local scale = (car:GetAttribute("Scale") :: number?) or 1
	local b = Kit.builder(crates, bed.CFrame, true, scale)
	for i = 1, count do
		-- the bed is 0.6 thick, so a 2-stud crate sits 1.3 above its centre
		b.block("Crate", Vector3.new(2.4, 2, 2.6), Vector3.new(3 - (i - 1) * 3, 1.3, 0), Palette.crate)
	end
end

---------------------------------------------------------------------------------------------
-- Help Crate: a crate on the platform with a tall pole and a heart-and-leaf help flag
-- (08 Social & Events). The "HelpFlag" carries a HingeCFrame at the pole for waving.
---------------------------------------------------------------------------------------------

function ArtRail.helpCrate(parent: Instance, cf: CFrame): Model
	local model = Kit.model("HelpCrate", parent)
	local b = Kit.builder(model, cf, true)
	b.block("Crate", Vector3.new(2, 1.8, 2), Vector3.new(0, 0.9, 0), Palette.crate, SOLID)
	b.block("Band", Vector3.new(2.05, 0.3, 2.05), Vector3.new(0, 1.2, 0), Palette.woodDark, QUIET)
	b.post("Pole", 3.6, 0.2, Vector3.new(0.8, 3.6, 0.8), Palette.cocoa)
	local flag = b.block("HelpFlag", Vector3.new(1.6, 1.1, 0.1), Vector3.new(1.6, 4.8, 0.8), Palette.flowerPink, QUIET)
	flag:SetAttribute("HingeCFrame", cf * CFrame.new(0.8, 4.8, 0.8))
	b.ball("Leaf", 0.6, Vector3.new(1.6, 4.8, 0.72), Palette.lime, QUIET)
	return model
end

---------------------------------------------------------------------------------------------
-- Track pieces, 16 studs long along local X: honey-wood sleepers, lavender-grey rails. The
-- Buffer stop ends a line at +X; the Crossing lays road planks over the rails and has a
-- striped barrier ("Barrier", HingeCFrame at its post) that lowers when the train passes.
---------------------------------------------------------------------------------------------

local function rails(b: Kit.Builder, length: number, x: number)
	for _, z in { -ArtRail.GAUGE / 2, ArtRail.GAUGE / 2 } do
		b.block("Rail", Vector3.new(length, 0.35, 0.35), Vector3.new(x, ArtRail.RAIL_TOP - 0.18, z), Palette.stone)
	end
end

local TRACKS: { [string]: (Kit.Builder, CFrame) -> () } = {
	Straight = function(b)
		rails(b, ArtRail.TRACK_LENGTH, 0)
		for _, x in { -6, -2, 2, 6 } do
			b.block("Sleeper", Vector3.new(1.2, 0.35, 4.6), Vector3.new(x, 0.18, 0), Palette.woodLight, QUIET)
		end
	end,
	Buffer = function(b)
		rails(b, 10, -3)
		for _, x in { -6, -2 } do
			b.block("Sleeper", Vector3.new(1.2, 0.35, 4.6), Vector3.new(x, 0.18, 0), Palette.woodLight, QUIET)
		end
		b.block("Stop", Vector3.new(1.2, 1.6, 4.4), Vector3.new(2.6, 0.8, 0), Palette.woodDark, SOLID)
		b.block("StopBeam", Vector3.new(0.6, 0.7, 4.8), Vector3.new(1.8, 1.4, 0), Palette.barnRed)
	end,
	-- A gentle 45-degree curve: starts at local x = -8 heading +X like the Straight, and bends
	-- toward -Z around a centre at (-8, 0, -CURVE_RADIUS). Rails in three chords each.
	Curve = function(b)
		local r, sweep = ArtRail.CURVE_RADIUS, math.rad(ArtRail.CURVE_DEGREES)
		local centre = Vector3.new(-8, 0, -r)
		local function at(radius: number, a: number): Vector3
			return centre + Vector3.new(radius * math.sin(a), 0, radius * math.cos(a))
		end
		for _, offset in { -ArtRail.GAUGE / 2, ArtRail.GAUGE / 2 } do
			local radius = r - offset
			for i = 0, 2 do
				local a0, a1 = sweep * i / 3, sweep * (i + 1) / 3
				local p0, p1 = at(radius, a0), at(radius, a1)
				local mid = (p0 + p1) / 2
				b.block(
					"Rail",
					Vector3.new((p1 - p0).Magnitude + 0.2, 0.35, 0.35),
					CFrame.lookAt(mid, mid + (p1 - p0)) * Kit.yaw(90) + Vector3.new(0, ArtRail.RAIL_TOP - 0.18, 0),
					Palette.stone
				)
			end
		end
		for i = 1, 3 do
			local a = sweep * (i - 0.5) / 3
			local p = at(r, a)
			b.block(
				"Sleeper",
				Vector3.new(1.2, 0.35, 4.6),
				CFrame.lookAt(p, centre) + Vector3.new(0, 0.18, 0),
				Palette.woodLight,
				QUIET
			)
		end
	end,
	Crossing = function(b, cf)
		rails(b, ArtRail.TRACK_LENGTH, 0)
		b.block("Planks", Vector3.new(6, 0.5, 5), Vector3.new(0, 0.25, 0), Palette.path, QUIET)
		b.post("BarrierPost", 2.4, 0.5, Vector3.new(-3.6, 1.2, -3.4), Palette.cream)
		-- a two-tone arm in two halves; the client swings every "Barrier" part about the post
		for i, color in { Palette.roofRed, Palette.cream } do
			local arm = b.block("Barrier", Vector3.new(0.3, 0.3, 3), Vector3.new(-3.6, 2.2, -4.65 + i * 3), color)
			arm:SetAttribute("HingeCFrame", cf * CFrame.new(-3.6, 2.2, -3.4))
		end
	end,
}

---------------------------------------------------------------------------------------------
-- Town Express hub station (14 Multiplayer Features C1, Model List §5): the Town Square's big
-- station for the whole-server train. A long platform under a two-bay teal canopy, a clock
-- tower with a whistle bell in the middle, a wide server board (SurfaceGui: crates loaded,
-- time left) and four tier flags on poles that rise as the server fills the train
-- (setExpressProgress). Front (track side) faces local -Z. Returns the model and the board.
---------------------------------------------------------------------------------------------

function ArtRail.expressStation(parent: Instance, cf: CFrame): (Model, Part)
	local model = Kit.model("ExpressStation", parent)
	local b = Kit.builder(model, cf, true)
	b.block("Platform", Vector3.new(46, FLOOR, 10), Vector3.new(0, FLOOR / 2, 0), Palette.woodLight, SOLID)
	b.block("EdgeLine", Vector3.new(46, 0.1, 0.5), Vector3.new(0, FLOOR + 0.05, -4.6), Palette.roofMustard, QUIET)
	for _, x in { -23.5, 23.5 } do
		b.block("Steps", Vector3.new(1.4, FLOOR / 2, 10), Vector3.new(x, FLOOR / 4, 0), Palette.wood, SOLID)
	end
	-- Two canopy bays either side of the tower
	for _, side in { -1, 1 } do
		local cx = side * 13
		for _, x in { cx - 7, cx + 7 } do
			for _, z in { -3.8, 3.8 } do
				b.post("CanopyPost", 6, 0.6, Vector3.new(x, FLOOR + 3, z), Palette.cream)
			end
		end
		Kit.archRoof(b, "Canopy", CFrame.new(cx, FLOOR + 6, 0) * Kit.yaw(90), 10.6, 16, 2, 3, 0.4, Palette.roofTeal)
	end
	-- The clock tower: a brick tower with a clock on the front, a gold whistle bell in an open
	-- belfry, a mustard cap and an XL Sprout Tag
	b.block("Tower", Vector3.new(6, 12, 6), Vector3.new(0, FLOOR + 6, 1), Palette.brick, SOLID)
	b.block("TowerBand", Vector3.new(6.4, 0.6, 6.4), Vector3.new(0, FLOOR + 8.4, 1), Palette.cream, QUIET)
	local face = CFrame.new(0, FLOOR + 10, -2.05) * Kit.yaw(90)
	b.cyl("ClockRim", 0.3, 3.6, face, Palette.cream)
	b.cyl("Clock", 0.3, 3, face * CFrame.new(0.08, 0, 0), Palette.oat, QUIET)
	local hand =
		b.block("ClockHand", Vector3.new(0.2, 1.2, 0.1), Vector3.new(0, FLOOR + 10.5, -2.3), Palette.cocoa, QUIET)
	hand:SetAttribute("HingeCFrame", cf * CFrame.new(0, FLOOR + 10, -2.3))
	for _, x in { -2.6, 2.6 } do
		b.block("Belfry", Vector3.new(0.8, 3, 0.8), Vector3.new(x, FLOOR + 13.5, 1), Palette.cream)
	end
	local bell = b.ball("Bell", 1.6, Vector3.new(0, FLOOR + 13.4, 1), Palette.coins, QUIET)
	bell:SetAttribute("HingeCFrame", bell.CFrame * CFrame.new(0, 1, 0))
	b.block("TowerCap", Vector3.new(7, 0.8, 7), Vector3.new(0, FLOOR + 15.4, 1), Palette.roofMustard)
	b.ball("Dome", 3.4, Vector3.new(0, FLOOR + 16.2, 1), Palette.roofTeal)
	Kit.sproutTag(b, Vector3.new(0, FLOOR + 17.6, 1), 4, Palette.wood, Palette.lime)
	-- The server board up on posts above the back wall, left of the tower, high enough to read
	-- over a parked train from the square
	local BOARD_Y = FLOOR + 10.2
	b.block("BackWall", Vector3.new(16, 3.6, 0.4), Vector3.new(-13, FLOOR + 1.8, 4.8), Palette.oat, SOLID)
	for _, x in { -18.6, -7.4 } do
		b.post(
			"BoardPost",
			BOARD_Y - FLOOR - 3.6,
			0.4,
			Vector3.new(x, (FLOOR + 3.6 + BOARD_Y) / 2, 4.8),
			Palette.woodDark
		)
	end
	local board = b.block("ExpressBoard", Vector3.new(10, 3, 0.2), Vector3.new(-13, BOARD_Y, 4.5), Palette.cocoa)
	b.block("BoardFrame", Vector3.new(10.6, 3.6, 0.15), Vector3.new(-13, BOARD_Y, 4.58), Palette.wood, QUIET)
	-- Four tier flags on the right, lowered until the server reaches that share of the train
	for i = 1, #ArtRail.EXPRESS_TIERS do
		local x = 8 + (i - 1) * 3.6
		b.post("FlagPole", 7, 0.25, Vector3.new(x, FLOOR + 3.5, 4.2), Palette.cocoa)
		local high = CFrame.new(x + 0.9, FLOOR + 6.3, 4.2)
		local flag = b.block("TierFlag", Vector3.new(1.6, 1.1, 0.12), high, Palette.cream)
		flag:SetAttribute("Tier", i)
		flag:SetAttribute("HighCFrame", cf * high)
		flag:SetAttribute("LowCFrame", cf * (high - Vector3.new(0, 4.4, 0)))
	end
	-- Two flower barrels by the steps
	for _, x in { -21.5, 21.5 } do
		b.post("Barrel", 1.2, 1.3, Vector3.new(x, FLOOR + 0.6, 3.6), Palette.wood)
		Kit.bush(b, "Flowers", Vector3.new(x, FLOOR + 1.1, 3.6), 0.6, Palette.treeTop, Palette.flowerPink)
	end
	ArtRail.setExpressProgress(model, 0)
	return model, board
end

-- Raises the tier flags the server has reached (`fraction` of the train loaded, 0-1) and
-- paints them gold; the rest hang low in cream.
function ArtRail.setExpressProgress(station: Model, fraction: number)
	for _, d in station:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "TierFlag" then
			local tier = ArtRail.EXPRESS_TIERS[d:GetAttribute("Tier") :: number]
			local reached = tier ~= nil and fraction >= tier
			local cf = d:GetAttribute(if reached then "HighCFrame" else "LowCFrame")
			if typeof(cf) == "CFrame" then
				d.CFrame = cf
			end
			d.Color = if reached then Palette.coins else Palette.cream
		end
	end
	station:SetAttribute("Progress", fraction)
end

-- `scale` builds a bigger piece (the Town Express runs on EXPRESS_SCALE track: a scaled piece
-- is TRACK_LENGTH x scale long, with the gauge to match the scaled train)
function ArtRail.track(kind: string, parent: Instance, cf: CFrame, scale: number?): Model
	local model = Kit.model("Track_" .. kind, parent)
	local builder = TRACKS[kind] or TRACKS.Straight
	builder(Kit.builder(model, cf, false, scale), cf)
	return model
end

return ArtRail
