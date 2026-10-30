--!strict
-- The five MVP factories: Bakery, Feed Mill, Dairy, Sugar Mill, Textile Mill.
-- Design/16 Model Catalog §2.4 and Design/04 Factories & Recipes.
--
-- Each factory has its own roof shape (the main silhouette tool, 16 §1.2), one big moving
-- "gimmick" part in an Anim folder, a round product sign over the front, and an output table
-- in front of the door where finished goods appear. The footprint is 10 (X) x 12 (Z) studs
-- with the front at local -Z; the output table stands at local z = -10. Budget ≤ 80 parts.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtFactories = {}

ArtFactories.PARTS_MAX = 80
ArtFactories.WIDTH = 10
ArtFactories.DEPTH = 12
ArtFactories.TABLE_Z = -10

local TURN = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis from X to Z
local PLINTH = 0.75
local WALL = 7
local TOP = PLINTH + WALL
local FRONT = -ArtFactories.DEPTH / 2

export type Parts = {
	body: BasePart, -- the factory's tap target
	chimney: BasePart, -- where smoke or steam comes out
	outputTable: BasePart, -- finished goods sit on top; walk past to collect
	window: BasePart, -- the production window
	anim: Folder, -- the gimmick's moving parts, for client tweens
}

-- Plinth and rectangular walls. Returns the body (tap target).
local function shell(
	b: Kit.Builder,
	wall: Color3,
	plinth: Color3,
	width: number?,
	depth: number?,
	height: number?
): Part
	local w = width or ArtFactories.WIDTH
	local d = depth or ArtFactories.DEPTH
	local h = height or WALL
	b.block("Plinth", Vector3.new(w + 0.6, PLINTH, d + 0.6), Vector3.new(0, PLINTH / 2, 0), plinth)
	return b.block("Body", Vector3.new(w, h, d), Vector3.new(0, PLINTH + h / 2, 0), wall, { collide = true })
end

-- Round product sign above the door: a wood rim, a cream face and an icon. 2 parts + icon.
local function sign(b: Kit.Builder, at: Vector3, icon: (Kit.Builder, CFrame) -> ())
	local face = CFrame.new(at) * TURN
	b.cyl("SignRim", 0.3, 3.2, face, Palette.woodDark, { shadow = false })
	b.cyl("Sign", 0.3, 2.7, CFrame.new(at + Vector3.new(0, 0, -0.1)) * TURN, Palette.cream, { shadow = false })
	icon(b, CFrame.new(at + Vector3.new(0, 0, -0.35)))
end

-- The output table: a honey-wood counter with a cream top. The counter is the tap target and
-- runs along local X. 2 parts.
local function outputTable(b: Kit.Builder): BasePart
	local t = b.block(
		"OutputTable",
		Vector3.new(3, 2, 8),
		CFrame.new(0, 1, ArtFactories.TABLE_Z) * TURN,
		Palette.wood,
		{ collide = true }
	)
	b.into(t, true).block(
		"TableTop",
		Vector3.new(3.4, 0.3, 8.4),
		CFrame.new(0, 2.1, ArtFactories.TABLE_Z) * TURN,
		Palette.cream,
		{ shadow = false }
	)
	return t
end

local function animFolder(parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = "Anim"
	f.Parent = parent
	return f
end

---------------------------------------------------------------------------------------------

-- Bakery: the roof is a loaf, a golden-brown half-round scored with three cream slashes. A
-- stone oven chimney at the back, a big loaf-arch window onto the glowing oven and a red door.
local function bakery(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.oat, Palette.stone)
	local d = b.into(body, true)
	d.cyl("Roof", ArtFactories.DEPTH - 0.1, ArtFactories.WIDTH + 1.2, CFrame.new(0, TOP, 0) * TURN, Palette.bread)
	for _, z in { -3.2, 0, 3.2 } do
		d.block(
			"Slash",
			Vector3.new(3.6, 0.35, 0.7),
			CFrame.new(0, TOP + 5.55, z) * Kit.yaw(30),
			Palette.cream,
			{ shadow = false }
		)
	end
	local chimney = d.block(
		"Chimney",
		Vector3.new(1.8, 4.5, 1.8),
		CFrame.new(3, TOP + 4.2, 4) * CFrame.Angles(0, 0, math.rad(3)),
		Palette.stone
	)
	d.block(
		"ChimneyCap",
		Vector3.new(2.3, 0.5, 2.3),
		Vector3.new(3.1, TOP + 6.6, 4),
		Palette.stoneDark,
		{ shadow = false }
	)
	Kit.window(d, "Window", CFrame.new(-2.2, PLINTH + 3.4, FRONT), 3.2, 2.6, Palette.cream, Palette.cocoa, true)
	d.block(
		"OvenGlow",
		Vector3.new(2.2, 1, 0.2),
		Vector3.new(-2.2, PLINTH + 2.7, FRONT - 0.45),
		Palette.roofMustard,
		{ shadow = false }
	)
	d.block(
		"Awning",
		Vector3.new(4.6, 0.3, 1.4),
		CFrame.new(-2.2, PLINTH + 5.9, FRONT - 0.6) * CFrame.Angles(math.rad(18), 0, 0),
		Palette.roofRed,
		{ shadow = false }
	)
	Kit.door(d, "Door", CFrame.new(2.6, PLINTH, FRONT), 2.6, 4.6, Palette.roofRed, Palette.cream)
	sign(d, Vector3.new(2.6, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.block("Loaf", Vector3.new(1.7, 0.9, 0.4), at, Palette.bread, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(0, TOP + 5.6, -4), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = animFolder(model) }
end

-- Feed Mill: a squat round timber granary with a stepped mustard cone roof, a big paddle wheel
-- dipping into a stone water channel and a plank chute down to the table.
local function feedMill(model: Model, b: Kit.Builder, roof: Color3?): Parts
	b.post("Plinth", PLINTH, 11, Vector3.new(0, PLINTH / 2, 0), Palette.stone)
	local body = b.post("Body", WALL, 9.6, Vector3.new(0, PLINTH + WALL / 2, 0), Palette.woodLight, { collide = true })
	local d = b.into(body, true)
	for _, y in { 2.2, 5.6 } do
		d.post("Hoop", 0.5, 9.9, Vector3.new(0, PLINTH + y, 0), Palette.woodDark, { shadow = false })
	end
	local cone = { { 11.6, 1.5 }, { 8.6, 1.5 }, { 5.6, 1.5 } }
	local y = TOP
	for _, tier in cone do
		d.post("Roof", tier[2], tier[1], Vector3.new(0, y + tier[2] / 2, 0), roof or Palette.roofMustard)
		y += tier[2]
	end
	local chimney = d.block("Chimney", Vector3.new(2, 1.6, 2), Vector3.new(0, y + 0.8, 0), Palette.wood)
	-- Paddle wheel on the left side, in a stone channel
	local anim = animFolder(model)
	local a = b.into(anim, false)
	local hub = CFrame.new(-5.6, PLINTH + 2.6, 1)
	a.cyl("Wheel", 0.8, 5.6, hub, Palette.woodDark)
	for _, angle in { 0, 90 } do
		a.block("Paddle", Vector3.new(1.1, 6.4, 1.1), hub * CFrame.Angles(math.rad(angle), 0, 0), Palette.wood)
	end
	d.block("Channel", Vector3.new(2.2, 0.7, 7.5), Vector3.new(-5.6, 0.35, 1), Palette.stone)
	d.block("Water", Vector3.new(1.6, 0.2, 7.3), Vector3.new(-5.6, 0.75, 1), Palette.water, { shadow = false })
	Kit.door(d, "Door", CFrame.new(0, PLINTH, -4.6), 2.6, 4.4, Palette.woodDark, Palette.cream)
	Kit.window(d, "Window", CFrame.new(3.1, PLINTH + 4.2, -3.6) * Kit.yaw(-35), 1.6, 1.8, Palette.cream, Palette.glass)
	d.block(
		"Chute",
		Vector3.new(1.4, 0.3, 4.4),
		CFrame.new(3.4, 3.2, -5.6) * CFrame.Angles(math.rad(-28), math.rad(20), 0),
		Palette.woodLight
	)
	sign(d, Vector3.new(0, PLINTH + 6.4, -4.95), function(s, at)
		s.block("Sack", Vector3.new(1.2, 1.4, 0.4), at, Palette.sack, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(0, y + 1.6, 0), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Dairy: an oat-and-sky-blue gabled hall with a round tower capped like a milk-can lid, and a
-- wooden butter churn on the porch.
local function dairy(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.oat, Palette.stone)
	local d = b.into(body, true)
	Kit.gableRoof(
		d,
		"Roof",
		CFrame.new(0, TOP, 0) * Kit.yaw(90),
		ArtFactories.DEPTH + 1.2,
		ArtFactories.WIDTH + 1.4,
		4.2,
		Palette.glassDeep,
		Palette.cream
	)
	d.post("Tower", 11.5, 4.2, Vector3.new(3.6, PLINTH + 5.75, 4.2), Palette.cream, { collide = true })
	d.post("TowerBand", 0.6, 4.5, Vector3.new(3.6, PLINTH + 9.5, 4.2), Palette.sky, { shadow = false })
	d.post("TowerLid", 0.9, 5, Vector3.new(3.6, PLINTH + 11.9, 4.2), Palette.roofTeal)
	local chimney = d.ball("Chimney", 1.4, Vector3.new(3.6, PLINTH + 12.6, 4.2), Palette.roofTeal)
	Kit.window(d, "Window", CFrame.new(-2.4, PLINTH + 3.6, FRONT), 2.6, 2.4, Palette.cream, Palette.glass, true)
	Kit.door(d, "Door", CFrame.new(2.4, PLINTH, FRONT), 2.6, 4.6, Palette.sky, Palette.cream)
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.post("Churn", 2.4, 1.7, Vector3.new(-4.2, PLINTH + 1.2, FRONT - 1.4), Palette.wood)
	a.post("ChurnLid", 0.3, 1.9, Vector3.new(-4.2, PLINTH + 2.5, FRONT - 1.4), Palette.woodDark, { shadow = false })
	a.post("Plunger", 1.8, 0.3, Vector3.new(-4.2, PLINTH + 3.3, FRONT - 1.4), Palette.woodLight, { shadow = false })
	sign(d, Vector3.new(0, PLINTH + 9.2, FRONT - 0.35), function(s, at)
		s.post("Bottle", 1.3, 0.8, at, Palette.milk, { shadow = false })
		s.post("BottleCap", 0.3, 0.6, at * CFrame.new(0, 0.75, 0), Palette.roofTeal, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(-1, TOP + 4.5, 0), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Sugar Mill: a tall tower with a stone base and a wooden upper floor under a plum roof. A
-- giant screw press pokes up through the roof, turned by a capstan bar; cane bundles lean on
-- the side and two rollers stand by the door.
local function sugarMill(model: Model, b: Kit.Builder): Parts
	local lower = 5
	local body = shell(b, Palette.stoneLight, Palette.stoneDark, nil, nil, lower)
	local d = b.into(body, true)
	local upperH = 4.6
	local upperY = PLINTH + lower
	d.block(
		"Upper",
		Vector3.new(10.6, upperH, 12.6),
		Vector3.new(0, upperY + upperH / 2, 0),
		Palette.woodLight,
		{ collide = true }
	)
	d.block("Beam", Vector3.new(10.9, 0.5, 12.9), Vector3.new(0, upperY, 0), Palette.woodDark, { shadow = false })
	local roofY = upperY + upperH
	Kit.gableRoof(d, "Roof", Vector3.new(0, roofY, 0), 11.8, 13.6, 4, Palette.roofPlum, Palette.cream)
	local chimney = d.block("Chimney", Vector3.new(1.6, 4, 1.6), Vector3.new(-3.4, roofY + 3, 3.6), Palette.brick)
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.post("Screw", 6, 1.2, Vector3.new(1.5, roofY + 3.6, 0), Palette.metal)
	for _, dy in { 1.6, 3.2 } do
		a.post("Thread", 0.4, 2, Vector3.new(1.5, roofY + 1.4 + dy, 0), Palette.stoneDark, { shadow = false })
	end
	a.block("Capstan", Vector3.new(6, 0.5, 0.5), Vector3.new(1.5, roofY + 6.4, 0), Palette.woodDark)
	a.post("Hub", 0.8, 1.6, Vector3.new(1.5, roofY + 6.6, 0), Palette.wood, { shadow = false })
	for i, z in { -2.5, 0, 2.5 } do
		local color = if i == 2 then Palette.canePlum else Palette.cane
		d.post(
			"Cane",
			5,
			0.9,
			CFrame.new(-5.6, PLINTH + 2.3, z) * CFrame.Angles(math.rad((i - 2) * 6), 0, math.rad(-10)),
			color
		)
	end
	for _, y in { 0.9, 2.2 } do
		d.cyl("Roller", 2.6, 1.2, Vector3.new(-3.6, PLINTH + y, FRONT - 1), Palette.cream)
	end
	Kit.window(d, "Window", CFrame.new(-2.4, upperY + 2.2, FRONT - 0.3), 2.4, 2.2, Palette.cream, Palette.glass, true)
	Kit.window(d, "WindowB", CFrame.new(2.6, upperY + 2.2, FRONT - 0.3), 2.4, 2.2, Palette.cream, Palette.glass, true)
	Kit.door(d, "Door", CFrame.new(1.6, PLINTH, FRONT), 2.6, 4.4, Palette.roofPlum, Palette.cream)
	sign(d, Vector3.new(0, roofY + 1.6, FRONT - 0.9), function(s, at)
		s.block(
			"Cube",
			Vector3.new(1, 1, 0.4),
			at * CFrame.Angles(0, 0, math.rad(45)),
			Palette.cream:Lerp(Palette.wheat, 0.35),
			{ shadow = false }
		)
	end)
	Kit.sproutTag(d, Vector3.new(-1, roofY + 4.1, 0), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Textile Mill: a long hall with a three-tooth teal sawtooth roof (glazed on each tooth), a
-- giant spool on the roof, a big front window onto the loom and a line of fabric flags.
local function textileMill(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.oat, Palette.stone)
	local d = b.into(body, true)
	local tooth = (ArtFactories.DEPTH + 0.6) / 3
	for i = 0, 2 do
		local z = FRONT - 0.3 + tooth * (i + 0.5)
		d.wedge(
			"Roof",
			Vector3.new(ArtFactories.WIDTH + 0.8, 2.8, tooth),
			Vector3.new(0, TOP + 1.4, z),
			Palette.roofTeal
		)
		d.block(
			"RoofGlass",
			Vector3.new(ArtFactories.WIDTH + 0.4, 2.2, 0.2),
			Vector3.new(0, TOP + 1.3, z + tooth / 2 + 0.05),
			Palette.glass,
			{ shadow = false }
		)
	end
	local chimney = d.block("Chimney", Vector3.new(1.4, 3, 1.4), Vector3.new(-3.8, TOP + 2.8, 4), Palette.brick)
	local anim = animFolder(model)
	local a = b.into(anim, false)
	local spool = CFrame.new(1, TOP + 4.4, 0.4)
	a.cyl("Spool", 3.6, 2.4, spool, Palette.plum)
	for _, x in { -1.9, 1.9 } do
		a.cyl("SpoolEnd", 0.5, 3.6, spool * CFrame.new(x, 0, 0), Palette.wood)
	end
	d.block("SpoolStand", Vector3.new(4.6, 1.4, 0.8), Vector3.new(1, TOP + 2.6, 0.4), Palette.woodDark)
	Kit.window(d, "Window", CFrame.new(-1.6, PLINTH + 3.4, FRONT), 4.6, 3, Palette.cream, Palette.glass)
	d.block(
		"Loom",
		Vector3.new(3.8, 0.5, 0.3),
		Vector3.new(-1.6, PLINTH + 2.8, FRONT - 0.45),
		Palette.woodDark,
		{ shadow = false }
	)
	Kit.door(d, "Door", CFrame.new(3.4, PLINTH, FRONT), 2.4, 4.4, Palette.roofTeal, Palette.cream)
	-- Fabric flags on a line from the roof corner to a post by the table
	d.block("FlagPost", Vector3.new(0.4, 6.4, 0.4), Vector3.new(5.4, 3.2, FRONT - 2.6), Palette.woodDark)
	local from = Vector3.new(4.9, TOP + 0.6, FRONT + 0.2)
	local to = Vector3.new(5.4, 6.2, FRONT - 2.6)
	d.block(
		"FlagLine",
		Vector3.new(0.1, 0.1, (to - from).Magnitude),
		CFrame.lookAt((from + to) / 2, to),
		Palette.cocoa,
		{ shadow = false }
	)
	for i, color in { Palette.roofRed, Palette.roofMustard, Palette.sky, Palette.plum } do
		local p = from:Lerp(to, i / 5)
		d.block("Flag", Vector3.new(0.15, 0.8, 0.6), Vector3.new(p.X, p.Y - 0.45, p.Z), color, { shadow = false })
	end
	sign(d, Vector3.new(2.2, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.ball("Yarn", 1.4, at, Palette.plum, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(-2, TOP + 2.8, 4.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Snack Factory (content bank, level 14): red-and-cream striped walls under a flat roof with a
-- giant popcorn bucket on top; a kernel column pops up and down while it works.
local function snackFactory(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.cream, Palette.stone)
	local d = b.into(body, true)
	for _, x in { -3.5, 0, 3.5 } do
		d.block(
			"Stripe",
			Vector3.new(1.6, WALL - 0.4, ArtFactories.DEPTH + 0.1),
			Vector3.new(x, PLINTH + WALL / 2, 0),
			Palette.roofRed,
			{ shadow = false }
		)
	end
	d.block(
		"Roof",
		Vector3.new(ArtFactories.WIDTH + 1, 0.8, ArtFactories.DEPTH + 1),
		Vector3.new(0, TOP + 0.4, 0),
		Palette.roofMustard
	)
	-- The bucket: a red tub with cream bands and a heap of popcorn
	local bucketAt = Vector3.new(0, TOP + 2.8, 1)
	d.post("Bucket", 4, 4.4, bucketAt, Palette.roofRed)
	d.post("BucketBand", 0.6, 4.5, bucketAt + Vector3.new(0, 1, 0), Palette.cream, { shadow = false })
	d.post("BucketBand", 0.6, 4.5, bucketAt + Vector3.new(0, -1, 0), Palette.cream, { shadow = false })
	for i, off in
		{ Vector3.new(-1, 2.4, 0), Vector3.new(1, 2.4, 0.4), Vector3.new(0, 2.6, -0.9), Vector3.new(0.2, 3.1, 0.3) }
	do
		d.ball("Popcorn", if i == 4 then 1.6 else 1.4, bucketAt + off, Palette.cream)
	end
	local chimney = d.block("Chimney", Vector3.new(1.4, 3, 1.4), Vector3.new(-3.8, TOP + 2.3, -4), Palette.brick)
	local anim = animFolder(model)
	b.into(anim, false).post("Popper", 1.6, 1, bucketAt + Vector3.new(1.1, 2.6, -0.8), Palette.cream)
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.6, Palette.cream, Palette.glass, true)
	d.block(
		"Awning",
		Vector3.new(4.8, 0.3, 1.4),
		CFrame.new(-2, PLINTH + 5.9, FRONT - 0.6) * CFrame.Angles(math.rad(18), 0, 0),
		Palette.roofMustard,
		{ shadow = false }
	)
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofRed, Palette.cream)
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.ball("Kernel", 1.2, at, Palette.cream, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(3.6, TOP + 1.6, 4.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Diner (content bank, level 16): a mint roadside diner with a rounded roof, a long band of
-- windows, a red-and-cream awning and a giant burger on the roof by a neon sign that glows
-- while it works.
local function diner(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.gems:Lerp(Palette.cream, 0.55), Palette.stoneDark)
	local d = b.into(body, true)
	d.cyl("Roof", ArtFactories.DEPTH + 0.4, ArtFactories.WIDTH + 0.6, CFrame.new(0, TOP - 1.4, 0) * TURN, Palette.metal)
	d.block(
		"Trim",
		Vector3.new(ArtFactories.WIDTH + 0.2, 0.5, ArtFactories.DEPTH + 0.2),
		Vector3.new(0, PLINTH + 1.4, 0),
		Palette.roofRed,
		{ shadow = false }
	)
	d.block(
		"WindowBand",
		Vector3.new(ArtFactories.WIDTH - 1.4, 2.2, 0.2),
		Vector3.new(-0.6, PLINTH + 3.8, FRONT - 0.1),
		Palette.glass,
		{ shadow = false }
	)
	for _, x in { -3.2, -0.6, 2 } do
		d.block(
			"Mullion",
			Vector3.new(0.3, 2.2, 0.25),
			Vector3.new(x, PLINTH + 3.8, FRONT - 0.15),
			Palette.cream,
			{ shadow = false }
		)
	end
	local window = d.block(
		"Window",
		Vector3.new(2, 2.2, 0.25),
		Vector3.new(-1.9, PLINTH + 3.8, FRONT - 0.2),
		Palette.glass,
		{ shadow = false }
	)
	d.block(
		"Awning",
		Vector3.new(ArtFactories.WIDTH, 0.3, 1.4),
		CFrame.new(0, PLINTH + 5.6, FRONT - 0.6) * CFrame.Angles(math.rad(18), 0, 0),
		Palette.roofRed,
		{ shadow = false }
	)
	-- Giant burger on the roof: bun, lettuce, patty, cheese, bun
	local burger = Vector3.new(1.6, TOP + 2.6, 1.5)
	d.post("BunBottom", 0.8, 4, burger, Palette.bread)
	d.post("Patty", 0.8, 4.2, burger + Vector3.new(0, 0.8, 0), Palette.cocoa)
	d.post("Lettuce", 0.3, 4.5, burger + Vector3.new(0, 1.3, 0), Palette.leafLight, { shadow = false })
	d.block(
		"Cheese",
		Vector3.new(3.4, 0.25, 3.4),
		CFrame.new(burger + Vector3.new(0, 1.5, 0)) * Kit.yaw(45),
		Palette.roofMustard,
		{ shadow = false }
	)
	d.ball("BunTop", 4.2, burger + Vector3.new(0, 2.3, 0), Palette.bread)
	d.block("NeonSign", Vector3.new(4.6, 1.6, 0.4), Vector3.new(-2.4, TOP + 1.6, FRONT + 1), Palette.cream)
	d.block(
		"SignPost",
		Vector3.new(0.4, 1.2, 0.4),
		Vector3.new(-2.4, TOP + 0.4, FRONT + 1.2),
		Palette.metal,
		{ shadow = false }
	)
	local chimney = d.block("Chimney", Vector3.new(1.2, 2.6, 1.2), Vector3.new(-3.6, TOP + 0.8, 4.4), Palette.metal)
	Kit.door(d, "Door", CFrame.new(3.6, PLINTH, FRONT), 2.2, 4.4, Palette.roofRed, Palette.cream)
	sign(d, Vector3.new(3.6, PLINTH + 6.3, FRONT - 0.3), function(s, at)
		s.post("Shake", 1.2, 0.8, at * CFrame.Angles(0, 0, math.rad(90)), Palette.flowerPink, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(-3.4, TOP + 1.6, 1.6), 2.5, Palette.wood, Palette.lime)
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = animFolder(model) }
end

-- Ice Cream Parlor (content bank, level 20): a strawberry-pink parlor with a cream roof, a
-- striped awning over the serving hatch, and a giant cone on the roof whose cherry bobs
-- while it works.
local function iceCreamParlor(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.flowerPink:Lerp(Palette.cream, 0.45), Palette.stoneLight)
	local d = b.into(body, true)
	d.block(
		"Roof",
		Vector3.new(ArtFactories.WIDTH + 1, 0.8, ArtFactories.DEPTH + 1),
		Vector3.new(0, TOP + 0.4, 0),
		Palette.cream
	)
	-- The giant cone: a wafer cup, a strawberry scoop and a vanilla scoop
	local cone = Vector3.new(0.8, TOP + 2.3, 1.5)
	d.post("Cone", 3, 2.6, cone, Palette.bread)
	d.ball("Scoop", 3.4, cone + Vector3.new(0, 2.2, 0), Palette.flowerPink)
	d.ball("Scoop", 2.8, cone + Vector3.new(0, 4.1, 0), Palette.cream)
	local anim = animFolder(model)
	b.into(anim, false).post("Cherry", 0.8, 1, cone + Vector3.new(0, 5.8, 0), Palette.roofRed)
	local chimney = d.block("Chimney", Vector3.new(1.4, 2.6, 1.4), Vector3.new(-3.6, TOP + 2.1, 4), Palette.stone)
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.cream, Palette.glass)
	for _, stripe in { { -3.2, Palette.flowerPink }, { -0.8, Palette.cream } } do
		d.block(
			"Awning",
			Vector3.new(2.4, 0.3, 1.4),
			CFrame.new(stripe[1], PLINTH + 5.6, FRONT - 0.6) * CFrame.Angles(math.rad(18), 0, 0),
			stripe[2],
			{ shadow = false }
		)
	end
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofTeal, Palette.cream)
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.ball("Scoop", 1.2, at, Palette.flowerPink, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(3.6, TOP + 1.6, 4.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

local BUILDERS: { [string]: (Model, Kit.Builder) -> Parts } = {
	Bakery = bakery,
	FeedMill = feedMill,
	Dairy = dairy,
	SugarMill = sugarMill,
	TextileMill = textileMill,
	SnackFactory = snackFactory,
	Diner = diner,
	-- The second Feed Mill (level 19): the same mill under a red roof, so the two tell apart
	FeedMill2 = function(model: Model, b: Kit.Builder): Parts
		return feedMill(model, b, Palette.roofRed)
	end,
	IceCreamParlor = iceCreamParlor,
}

function ArtFactories.has(id: string): boolean
	return BUILDERS[id] ~= nil
end

-- Build factory `id` into `model` at `cf` (bottom-centre, front at local -Z).
function ArtFactories.build(id: string, model: Model, cf: CFrame): Parts
	local build = BUILDERS[id] or bakery
	return build(model, Kit.builder(model, cf, true))
end

return ArtFactories
