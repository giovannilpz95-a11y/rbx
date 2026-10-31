--!strict
-- The six MVP factories: Bakery, Feed Mill, Dairy, Sugar Mill, Textile Mill, Tailor.
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
ArtFactories.QUEUE_SHOWN = 6 -- queued jobs show as crates by the table, two layers of three
-- Finished goods show on the output table up to this many (the part-cut pass: a full tray of
-- 6-8 props on every factory cost ~450 parts a plot); the panel still counts them all
ArtFactories.GOODS_SHOWN = 3

-- What the server's merge of a working factory (Art/Merge) leaves out: the moving gimmick,
-- the queue crates and goods that come and go, the output table (a tap target of its own)
-- and the glow parts that light up while it works.
ArtFactories.MERGE_SKIP = {
	Anim = true,
	Queue = true,
	Goods = true,
	OutputTable = true,
	OvenGlow = true,
	NeonSign = true,
	FurnaceGlow = true,
} :: { [string]: boolean }

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

-- Paper Mill (content bank, level 18): a timber-framed mill with cream walls, a teal gable
-- roof and a giant paper roll on a cradle above the door that turns while it works.
local function paperMill(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.cream, Palette.stone)
	local d = b.into(body, true)
	for _, x in { -4.8, 4.8 } do
		for _, z in { -5.8, 5.8 } do
			d.block("Post", Vector3.new(0.6, WALL, 0.6), Vector3.new(x, PLINTH + WALL / 2, z), Palette.woodDark)
		end
	end
	d.block(
		"Beam",
		Vector3.new(ArtFactories.WIDTH + 0.3, 0.5, ArtFactories.DEPTH + 0.3),
		Vector3.new(0, TOP - 0.25, 0),
		Palette.woodDark,
		{ shadow = false }
	)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 13.4, 3.6, Palette.roofTeal)
	local chimney = d.block("Chimney", Vector3.new(1.4, 3.4, 1.4), Vector3.new(-3.4, TOP + 2.6, 3.6), Palette.brick)
	-- The roll: two cradle arms on the roof ridge hold a fat cream roll with a teal core
	local rollAt = Vector3.new(1.4, TOP + 5.2, 0)
	for _, x in { -1.6, 1.6 } do
		d.block(
			"Cradle",
			Vector3.new(0.4, 2.2, 0.8),
			Vector3.new(rollAt.X + x * 1.6, TOP + 4, 0),
			Palette.wood,
			{ shadow = false }
		)
	end
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.cyl("Roll", 4.4, 2.6, CFrame.new(rollAt), Palette.cream)
	a.cyl("Core", 4.6, 0.9, CFrame.new(rollAt), Palette.roofTeal, { shadow = false })
	a.block("Tail", Vector3.new(3.6, 0.1, 2.2), CFrame.new(rollAt + Vector3.new(0, -1.25, -1.1)), Palette.cream, {
		shadow = false,
	})
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.woodDark, Palette.glass)
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofTeal, Palette.cream)
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.block("Sheet", Vector3.new(1.1, 1.4, 0.15), at, Palette.cream, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(-3.6, TOP + 1.6, -4.4), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
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

-- Pastry Shop (content bank, level 24): a butter-yellow shop under a chocolate roof, a
-- striped awning over the display window, a giant muffin by the chimney, and a rolling pin
-- on two cradles that rolls while it works.
local function pastryShop(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.wheat:Lerp(Palette.cream, 0.55), Palette.stoneLight)
	local d = b.into(body, true)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 13.4, 3.2, Palette.cocoa, Palette.cream)
	local chimney = d.block("Chimney", Vector3.new(1.4, 3.2, 1.4), Vector3.new(-3.6, TOP + 2.6, 3.6), Palette.brick)
	-- The giant muffin: a paper cup and a domed top with a berry, on the roof's front slope
	local muffin = Vector3.new(-3, TOP + 2.2, -1.6)
	d.post("MuffinCup", 2, 2.6, muffin, Palette.flowerPink)
	d.ball("MuffinTop", 3.2, muffin + Vector3.new(0, 1.3, 0), Palette.bread)
	d.ball("Berry", 0.8, muffin + Vector3.new(0, 2.85, 0), Palette.plum, { shadow = false })
	-- The rolling pin: two cradle arms on the ridge hold it; the pin and its handles roll
	local pinAt = Vector3.new(2.4, TOP + 4.6, 0)
	for _, x in { -1.9, 1.9 } do
		d.block(
			"Cradle",
			Vector3.new(0.4, 1.6, 0.8),
			Vector3.new(pinAt.X + x, TOP + 3.6, 0),
			Palette.woodDark,
			{ shadow = false }
		)
	end
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.cyl("Pin", 3.4, 1.4, CFrame.new(pinAt), Palette.woodLight)
	a.cyl("Handle", 5.4, 0.5, CFrame.new(pinAt), Palette.wood, { shadow = false })
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.cream, Palette.glass)
	for _, stripe in { { -3.2, Palette.cocoa }, { -0.8, Palette.cream } } do
		d.block(
			"Awning",
			Vector3.new(2.4, 0.3, 1.4),
			CFrame.new(stripe[1], PLINTH + 5.6, FRONT - 0.6) * CFrame.Angles(math.rad(18), 0, 0),
			stripe[2],
			{ shadow = false }
		)
	end
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.cocoa, Palette.cream)
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.ball("Muffin", 1.2, at, Palette.bread, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.6, 4.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Jam Kitchen (content bank, level 27): a pink-washed cottage kitchen under a plum roof, a
-- giant jar of strawberry jam on the roof whose lid hops while it cooks, and a striped awning.
local function jamKitchen(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.cream:Lerp(Palette.flowerPink, 0.25), Palette.stoneLight)
	local d = b.into(body, true)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 13.4, 3, Palette.roofPlum, Palette.cream)
	local chimney = d.block("Chimney", Vector3.new(1.4, 3, 1.4), Vector3.new(-3.6, TOP + 2.4, 3.6), Palette.brick)
	-- The giant jar: red jam, a cream label band, and a lid that hops
	local jar = Vector3.new(1.4, TOP + 3.6, 0)
	d.post("Jar", 3.4, 3, jar, Palette.roofRed)
	d.post("Label", 1.2, 3.1, jar + Vector3.new(0, -0.2, 0), Palette.cream, { shadow = false })
	local anim = animFolder(model)
	b.into(anim, false).post("Lid", 0.7, 3.3, jar + Vector3.new(0, 2.05, 0), Palette.roofMustard)
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.cream, Palette.glass)
	for _, stripe in { { -3.2, Palette.roofRed }, { -0.8, Palette.cream } } do
		d.block(
			"Awning",
			Vector3.new(2.4, 0.3, 1.4),
			CFrame.new(stripe[1], PLINTH + 5.6, FRONT - 0.6) * CFrame.Angles(math.rad(18), 0, 0),
			stripe[2],
			{ shadow = false }
		)
	end
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofPlum, Palette.cream)
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.ball("Berry", 1.2, at, Palette.roofRed, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.6, 4.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Rubber Works (content bank, level 29): a grey works shed under a curved metal roof. Two big
-- press rollers stand on a frame on the roof, squeezing a dark rubber sheet, and the lower
-- one turns while it works. A stack of tyres leans by the door.
local function rubberWorks(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.stoneLight:Lerp(Palette.sky, 0.15), Palette.stoneDark)
	local d = b.into(body, true)
	Kit.archRoof(d, "Roof", Vector3.new(0, TOP, 0), 11, 13, 2.6, 4, 0.5, Palette.metal)
	local chimney = d.post("Chimney", 3.4, 1.2, Vector3.new(-3.6, TOP + 3.4, 4), Palette.stoneDark)
	-- The press: two posts carrying the rollers, the top one still, the sheet between them
	local press = Vector3.new(1.2, TOP + 4.2, 0)
	for _, x in { -2.6, 2.6 } do
		d.block("PressPost", Vector3.new(0.5, 3.4, 0.8), Vector3.new(press.X + x, TOP + 3.2, 0), Palette.woodDark)
	end
	d.cyl("TopRoller", 4.6, 1.2, CFrame.new(press + Vector3.new(0, 0.9, 0)), Palette.metal)
	d.block("Sheet", Vector3.new(4.2, 0.15, 2.6), press + Vector3.new(0, 0.2, -1.2), Palette.tire, { shadow = false })
	local anim = animFolder(model)
	b.into(anim, false).cyl("Roller", 4.6, 1.2, CFrame.new(press + Vector3.new(0, -0.45, 0)), Palette.stoneDark)
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.cream, Palette.glass)
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofTeal, Palette.cream)
	-- Tyres stacked by the door
	for i = 0, 2 do
		d.cyl(
			"Tyre",
			0.6,
			1.6,
			CFrame.new(4.6, 0.3 + i * 0.62, FRONT - 1.6) * CFrame.Angles(0, 0, math.rad(90)),
			Palette.tire
		)
	end
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.ball("RubberBall", 1.2, at, Palette.tire:Lerp(Palette.cream, 0.15), { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.6, 4.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Prep Kitchen (content bank, level 31): a cream kitchen block under a red gable, a giant
-- mixing bowl on the roof with a dough paddle that turns while it works, and flour sacks by
-- the door.
local function prepKitchen(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.cream, Palette.stoneLight)
	local d = b.into(body, true)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 13.4, 3, Palette.roofRed, Palette.cream)
	local chimney = d.block("Chimney", Vector3.new(1.4, 3, 1.4), Vector3.new(-3.6, TOP + 2.4, 3.6), Palette.brick)
	-- The giant bowl on its stand, with a ball of dough and the paddle turning above it
	local bowl = Vector3.new(1.6, TOP + 3.4, 0)
	d.post("BowlStand", 1.6, 1.4, bowl + Vector3.new(0, -1.3, 0), Palette.woodDark)
	d.post("Bowl", 1.8, 3.6, bowl, Palette.sky:Lerp(Palette.cream, 0.4))
	d.ball("Dough", 2.4, bowl + Vector3.new(0, 0.9, 0), Palette.bread:Lerp(Palette.cream, 0.5), { shadow = false })
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.post("Paddle", 3, 0.3, bowl + Vector3.new(0, 1.8, 0), Palette.woodLight)
	a.block("Blade", Vector3.new(2.2, 0.6, 0.2), bowl + Vector3.new(0, 1.2, 0), Palette.woodLight, { shadow = false })
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.cream, Palette.glass)
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofRed, Palette.cream)
	for i, x in { 4.4, 5.2 } do
		d.block("Sack", Vector3.new(0.9, 1.3, 0.8), CFrame.new(x, 0.65, FRONT - 1.4) * Kit.yaw(i * 15), Palette.sack)
	end
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.ball("DoughBall", 1.2, at, Palette.bread:Lerp(Palette.cream, 0.5), { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.6, 4.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Molding Works (content bank, level 34): a sky-blue works shed under a flat roof with a
-- sawtooth skylight. A press on the roof stamps down onto a mould while it works, a hopper
-- of pellets feeds it, and a crate of fresh bottles waits by the door.
local function moldingWorks(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.sky:Lerp(Palette.cream, 0.35), Palette.stoneDark)
	local d = b.into(body, true)
	d.block("Roof", Vector3.new(11.4, 0.5, 9.4), Vector3.new(0, TOP + 0.25, 0), Palette.stoneDark)
	d.wedge("Skylight", Vector3.new(10.4, 1.6, 2.4), CFrame.new(0, TOP + 1.3, 2.6), Palette.glass)
	local chimney = d.post("Chimney", 2.6, 1, Vector3.new(-4, TOP + 1.8, 3.4), Palette.metal)
	-- The press: a frame on the roof, the mould block under it and the hopper beside it
	local press = Vector3.new(1.4, TOP + 0.5, -1.2)
	for _, x in { -1.8, 1.8 } do
		d.block("PressPost", Vector3.new(0.5, 4.2, 0.6), press + Vector3.new(x, 2.1, 0), Palette.metal)
	end
	d.block("PressBeam", Vector3.new(4.1, 0.6, 0.8), press + Vector3.new(0, 4.4, 0), Palette.metal)
	d.block("Mould", Vector3.new(2.6, 0.9, 1.6), press + Vector3.new(0, 0.45, 0), Palette.roofTeal)
	d.wedge(
		"Hopper",
		Vector3.new(1.6, 1.8, 1.6),
		CFrame.new(press + Vector3.new(-3.4, 1.4, 0)) * Kit.yaw(180),
		Palette.roofMustard
	)
	local anim = animFolder(model)
	b.into(anim, false).post("Press", 1, 1.8, press + Vector3.new(0, 2.6, 0), Palette.stoneDark)
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.cream, Palette.glass)
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofTeal, Palette.cream)
	-- A crate of bottles by the door
	d.block("Crate", Vector3.new(1.6, 0.8, 1.2), Vector3.new(4.8, 0.4, FRONT - 1.6), Palette.wood)
	for i, x in { -0.4, 0.4 } do
		d.post(
			"Bottle",
			0.9,
			0.4,
			Vector3.new(4.8 + x, 1.25, FRONT - 1.6),
			if i == 1 then Palette.sky else Palette.lime,
			{ shadow = false }
		)
	end
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.post("BottleIcon", 1.2, 0.6, at, Palette.sky, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.6, 4.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Homewares Shop (content bank, level 37): a mustard workshop under a gabled roof with a
-- striped awning over the window. A giant scrub brush on a roof frame turns while it works,
-- and a bucket of suds and a stack of brushes wait by the door.
local function homewaresShop(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.roofMustard:Lerp(Palette.cream, 0.45), Palette.wood)
	local d = b.into(body, true)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 9.4, 2.4, Palette.roofTeal, Palette.cream)
	local chimney = d.post("Chimney", 2.4, 1, Vector3.new(-4, TOP + 2.2, 2.6), Palette.brick)
	-- The roof frame holding the brush: two posts and the brush's axle along X
	local brush = Vector3.new(1, TOP + 3.6, -1.6)
	for _, x in { -2.4, 2.4 } do
		d.block("BrushPost", Vector3.new(0.5, 3.6, 0.5), brush + Vector3.new(x, -1.4, 0), Palette.woodDark)
	end
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.cyl("Brush", 4.2, 1.2, brush, Palette.wood)
	for i = 0, 3 do
		local turn = CFrame.new(brush) * CFrame.Angles(i * math.pi / 2, 0, 0)
		a.block("Bristles", Vector3.new(3.8, 0.5, 0.5), turn * CFrame.new(0, 0.75, 0), Palette.cream)
	end
	-- Awning over the window, in two colours
	for i = 0, 3 do
		d.block(
			"Awning",
			Vector3.new(1, 0.2, 1.4),
			CFrame.new(-3.5 + i, PLINTH + 5, FRONT - 0.6) * CFrame.Angles(math.rad(-18), 0, 0),
			if i % 2 == 0 then Palette.roofRed else Palette.cream,
			{ shadow = false }
		)
	end
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.cream, Palette.glass)
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofRed, Palette.cream)
	-- A bucket of suds and a stack of brushes by the door
	d.post("Bucket", 0.9, 1, Vector3.new(4.9, 0.45, FRONT - 1.4), Palette.sky)
	d.ball("Suds", 1, Vector3.new(4.9, 1, FRONT - 1.4), Palette.cream, { shadow = false })
	d.block("Brushes", Vector3.new(1.4, 0.6, 0.8), Vector3.new(4.9, 0.3, FRONT - 2.8), Palette.wood)
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.block("BrushIcon", Vector3.new(1.2, 0.5, 0.2), at, Palette.roofMustard, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.6, 3.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Candy Factory (level 39, placed by the player): a pink-and-cream striped sweet shop under a
-- cream roof, a giant lollipop on the ridge whose swirl turns while it works, a jar of jelly
-- beans by the door and a striped candy cane post.
local function candyFactory(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.flowerPink:Lerp(Palette.cream, 0.35), Palette.cream)
	local d = b.into(body, true)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 9.4, 2.4, Palette.cream, Palette.flowerPink)
	local chimney = d.post("Chimney", 2.4, 1, Vector3.new(4, TOP + 2.2, 2.6), Palette.flowerPink)
	-- The lollipop: a stick up from the ridge and a disc facing the front, its swirl turning
	local pop = CFrame.new(-1, TOP + 5.2, -0.6) * CFrame.Angles(0, math.rad(90), 0)
	d.post("Stick", 2.6, 0.4, Vector3.new(-1, TOP + 2.8, -0.6), Palette.cream)
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.cyl("Swirl", 0.6, 3.8, pop, Palette.flowerPink)
	for i = 0, 2 do
		a.block("SwirlStripe", Vector3.new(0.7, 3.4, 0.45), pop * CFrame.Angles(i * math.pi / 3, 0, 0), Palette.cream)
	end
	-- Striped awning over the window
	for i = 0, 3 do
		d.block(
			"Awning",
			Vector3.new(1, 0.2, 1.4),
			CFrame.new(-3.5 + i, PLINTH + 5, FRONT - 0.6) * CFrame.Angles(math.rad(-18), 0, 0),
			if i % 2 == 0 then Palette.flowerPink else Palette.cream,
			{ shadow = false }
		)
	end
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.cream, Palette.glass)
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofTeal, Palette.cream)
	-- A big jar of jelly beans and a candy cane post by the door
	d.post("Jar", 1.6, 1.2, Vector3.new(4.9, 0.8, FRONT - 1.4), Palette.glass)
	d.ball("Beans", 1, Vector3.new(4.9, 0.7, FRONT - 1.4), Palette.flowerYellow, { shadow = false })
	d.post("CandyCane", 2.6, 0.4, Vector3.new(-5, 1.3, FRONT - 1.2), Palette.roofRed)
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.ball("CandyIcon", 0.7, at, Palette.flowerPink, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.6, -3.4), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Cantina (level 43, placed by the player): a terracotta adobe restaurant with a flat roof
-- and rounded beams poking out under it, a cactus by the door, a string of pepper lanterns and
-- a pepper-shaped sign on the roof that glows while it cooks.
local function cantina(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.carrot:Lerp(Palette.cream, 0.55), Palette.brick)
	local d = b.into(body, true)
	d.block("Roof", Vector3.new(11.6, 0.8, 9.6), Vector3.new(0, TOP + 0.4, 0), Palette.brick)
	d.block("Parapet", Vector3.new(11.6, 0.8, 0.5), Vector3.new(0, TOP + 1.2, FRONT + 0.25), Palette.brick)
	local chimney = d.post("Chimney", 2, 1, Vector3.new(4, TOP + 1.8, 2.6), Palette.cream)
	for i = 0, 3 do
		d.post("Beam", 0.9, 0.4, CFrame.new(-4 + i * 2.6, TOP - 0.6, FRONT - 0.2) * Kit.yaw(90), Palette.woodDark)
	end
	-- The pepper sign on the roof: a red pod with a green stalk, glowing while it works
	d.block("SignPost", Vector3.new(0.4, 1.4, 0.4), Vector3.new(-2.4, TOP + 1.5, FRONT + 1), Palette.woodDark)
	d.block("NeonSign", Vector3.new(3.6, 1.2, 0.4), Vector3.new(-2.4, TOP + 2.8, FRONT + 1), Palette.roofRed)
	d.block("Stalk", Vector3.new(0.5, 0.6, 0.3), Vector3.new(-0.4, TOP + 3.2, FRONT + 1), Palette.leaf)
	-- Lantern string over the door and window
	d.block("Lanterns", Vector3.new(8, 0.1, 0.1), Vector3.new(0, PLINTH + 5.2, FRONT - 0.4), Palette.woodDark)
	for i = 0, 3 do
		d.ball(
			"Lantern",
			0.5,
			Vector3.new(-3 + i * 2, PLINTH + 4.9, FRONT - 0.4),
			if i % 2 == 0 then Palette.roofRed else Palette.flowerYellow,
			{ shadow = false }
		)
	end
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.2, FRONT), 3, 2.2, Palette.cream, Palette.glass)
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.2, Palette.woodDark, Palette.cream)
	-- A cactus in a pot by the door
	d.post("Pot", 0.8, 1.1, Vector3.new(4.9, 0.4, FRONT - 1.4), Palette.brick)
	d.post("Cactus", 2, 0.7, Vector3.new(4.9, 1.8, FRONT - 1.4), Palette.leaf)
	d.post("CactusArm", 0.8, 0.4, Vector3.new(5.3, 2.1, FRONT - 1.4), Palette.leaf)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.4, -3.4), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = animFolder(model) }
end

-- Stationery Shop (level 46, placed by the player): a tidy blue shop with a white roof, a
-- giant yellow pencil on the roof that taps up and down as it writes while it works, a stack
-- of paper by the door and a ruler for a sign.
local function stationeryShop(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.sky:Lerp(Palette.cream, 0.4), Palette.cream)
	local d = b.into(body, true)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 9.4, 2.4, Palette.cream, Palette.sky)
	local chimney = d.post("Chimney", 2.4, 1, Vector3.new(4, TOP + 2.2, 2.6), Palette.stoneLight)
	-- The pencil on its frame: a post either side, the pencil hanging point-down between them
	local pencil = Vector3.new(-1, TOP + 4.4, -1.4)
	d.block("PencilFrame", Vector3.new(4.4, 0.4, 0.4), pencil + Vector3.new(0, 2.6, 0), Palette.woodDark)
	for _, x in { -2, 2 } do
		d.block("FramePost", Vector3.new(0.4, 4, 0.4), pencil + Vector3.new(x, 0.8, 0), Palette.woodDark)
	end
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.post("Pencil", 3.4, 0.8, pencil, Palette.flowerYellow)
	a.wedge(
		"PencilTip",
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(pencil - Vector3.new(0, 2.1, 0)) * CFrame.Angles(math.rad(180), 0, 0),
		Palette.wood
	)
	a.post("Eraser", 0.5, 0.82, pencil + Vector3.new(0, 1.95, 0), Palette.flowerPink)
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.4, FRONT), 3.4, 2.4, Palette.cream, Palette.glass)
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofTeal, Palette.cream)
	-- A stack of paper by the door
	d.block("Paper", Vector3.new(1.4, 1, 1), Vector3.new(4.9, 0.5, FRONT - 1.4), Palette.cream)
	d.block(
		"PaperBand",
		Vector3.new(1.42, 0.2, 1.02),
		Vector3.new(4.9, 0.5, FRONT - 1.4),
		Palette.roofRed,
		{ shadow = false }
	)
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.block("RulerIcon", Vector3.new(1.4, 0.35, 0.2), at, Palette.flowerYellow, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.6, -3.4), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Furniture Workshop (level 47, placed by the player): a timber workshop with a big round saw
-- blade on the gable end that spins while it works, planks stacked by the door and a finished
-- chair out front.
local function furnitureWorkshop(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.woodLight, Palette.woodDark)
	local d = b.into(body, true)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 9.4, 2.6, Palette.roofTeal, Palette.cream)
	local chimney = d.post("Chimney", 2.4, 1, Vector3.new(-4, TOP + 2.2, 2.6), Palette.brick)
	-- The saw blade on the front gable, its hub on the wall
	local saw = CFrame.new(0, TOP + 0.9, FRONT - 0.5) * Kit.yaw(90)
	d.cyl("SawHub", 0.6, 0.8, saw * CFrame.new(0.3, 0, 0), Palette.stoneDark)
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.cyl("Saw", 0.2, 2.6, saw, Palette.stoneLight)
	for i = 0, 1 do
		a.block("SawTooth", Vector3.new(0.22, 2.9, 0.3), saw * CFrame.Angles(i * math.pi / 2, 0, 0), Palette.stoneDark)
	end
	Kit.window(d, "Window", CFrame.new(-2.6, PLINTH + 3.2, FRONT), 3, 2.2, Palette.cream, Palette.glass)
	Kit.door(d, "Door", CFrame.new(2.8, PLINTH, FRONT), 2.6, 4.2, Palette.woodDark, Palette.cream)
	-- Planks stacked by the door and a chair out front
	d.block("Planks", Vector3.new(1.2, 0.9, 3), Vector3.new(5, 0.45, FRONT - 1.8), Palette.wood)
	d.block("ChairSeat", Vector3.new(1.2, 0.25, 1.2), Vector3.new(-4.6, 1, FRONT - 1.6), Palette.roofRed)
	d.block("ChairBack", Vector3.new(1.2, 1.2, 0.25), Vector3.new(-4.6, 1.6, FRONT - 1.05), Palette.roofRed)
	d.block("ChairLegs", Vector3.new(1, 0.9, 1), Vector3.new(-4.6, 0.45, FRONT - 1.6), Palette.woodDark)
	Kit.sproutTag(d, Vector3.new(4.4, TOP + 1.6, 3.4), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Smelter (level 21, beside the Quarry): a fieldstone forge under a slate roof with a tall
-- round brick stack. The furnace mouth beside the door glows while it smelts, an anvil stands
-- out front and a stack of Bars waits on a pallet. The second Smelter wears a teal roof.
local function smelter(model: Model, b: Kit.Builder, roof: Color3?): Parts
	local body = shell(b, Palette.stoneLight, Palette.stoneDark)
	local d = b.into(body, true)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 13.4, 3, roof or Palette.stoneDark, Palette.cream)
	d.post("Stack", 9, 2.6, Vector3.new(-3, TOP + 3.5, 3.4), Palette.brick, { collide = true })
	d.post("StackBand", 0.6, 2.9, Vector3.new(-3, TOP + 6.4, 3.4), Palette.stoneDark, { shadow = false })
	local chimney = d.post("Chimney", 0.6, 2.2, Vector3.new(-3, TOP + 8.3, 3.4), Palette.stoneDark)
	-- The furnace mouth: a brick surround, a dark throat and the glow
	d.block("Furnace", Vector3.new(3.6, 3.4, 0.8), Vector3.new(-2.2, PLINTH + 1.7, FRONT - 0.3), Palette.brick)
	d.block("Throat", Vector3.new(2.4, 1.8, 0.2), Vector3.new(-2.2, PLINTH + 1.5, FRONT - 0.75), Palette.stoneDark)
	d.block(
		"FurnaceGlow",
		Vector3.new(2, 0.8, 0.2),
		Vector3.new(-2.2, PLINTH + 1.1, FRONT - 0.9),
		Palette.carrot,
		{ shadow = false }
	)
	Kit.window(d, "Window", CFrame.new(-2.2, PLINTH + 5, FRONT), 2.6, 1.6, Palette.woodDark, Palette.glass)
	Kit.door(d, "Door", CFrame.new(2.6, PLINTH, FRONT), 2.6, 4.6, Palette.woodDark, Palette.stoneDark)
	-- The anvil by the door
	local anvil = Vector3.new(4.4, 0, FRONT - 2.6)
	d.block("AnvilFoot", Vector3.new(0.9, 1.2, 0.9), anvil + Vector3.new(0, 0.6, 0), Palette.woodDark)
	d.block("Anvil", Vector3.new(1.8, 0.6, 0.9), anvil + Vector3.new(0, 1.5, 0), Palette.metal)
	-- Bars on a pallet against the wall
	local pallet = Vector3.new(-4.4, 0, FRONT - 2.4)
	d.block("Pallet", Vector3.new(1.8, 0.3, 1.8), pallet + Vector3.new(0, 0.15, 0), Palette.wood, { shadow = false })
	for i, bar in
		{ { -0.4, 0, Palette.brick:Lerp(Palette.carrot, 0.5) }, { 0.4, 0, Palette.coins }, { 0, 1, Palette.metal } }
	do
		d.block(
			"Bar",
			Vector3.new(0.7, 0.4, 1.4),
			CFrame.new(pallet + Vector3.new(bar[1], 0.5 + bar[2] * 0.42, 0)) * Kit.yaw(if i == 3 then 90 else 0),
			bar[3],
			{ shadow = false }
		)
	end
	local anim = animFolder(model)
	sign(d, Vector3.new(2.6, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.block("BarIcon", Vector3.new(1.4, 0.6, 0.3), at, Palette.coins, { shadow = false })
	end)
	Kit.sproutTag(d, Vector3.new(3.6, TOP + 1.6, 4.6), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

-- Tailor (level 12): a lilac boutique under a plum gable roof, with a striped awning over
-- the display window, a dress form at the door, and a giant four-hole button standing on the
-- ridge that rolls while it works.
local function tailor(model: Model, b: Kit.Builder): Parts
	local body = shell(b, Palette.roofPlum:Lerp(Palette.cream, 0.82), Palette.stoneLight)
	local d = b.into(body, true)
	d.block(
		"Beam",
		Vector3.new(ArtFactories.WIDTH + 0.3, 0.5, ArtFactories.DEPTH + 0.3),
		Vector3.new(0, TOP - 0.25, 0),
		Palette.cream,
		{ shadow = false }
	)
	Kit.gableRoof(d, "Roof", Vector3.new(0, TOP, 0), 11.4, 13.4, 3.6, Palette.roofPlum)
	local chimney = d.block("Chimney", Vector3.new(1.2, 3, 1.2), Vector3.new(3.8, TOP + 2.4, 3.4), Palette.brick)
	-- The button: a pink disc facing the street, its four holes turning with it
	local buttonAt = Vector3.new(-1, TOP + 5.6, 0)
	local face = CFrame.new(buttonAt) * TURN
	local anim = animFolder(model)
	local a = b.into(anim, false)
	a.cyl("Button", 0.7, 3.6, face, Palette.flowerPink)
	for _, offset in
		{ Vector3.new(-0.5, 0.5, 0), Vector3.new(0.5, 0.5, 0), Vector3.new(-0.5, -0.5, 0), Vector3.new(0.5, -0.5, 0) }
	do
		a.cyl("Hole", 0.8, 0.45, CFrame.new(buttonAt + offset) * TURN, Palette.roofPlum, { shadow = false })
	end
	Kit.window(d, "Window", CFrame.new(-2, PLINTH + 3.2, FRONT), 3.6, 2.8, Palette.cream, Palette.glass)
	for i, color in { Palette.roofPlum, Palette.cream, Palette.roofPlum } do
		d.block(
			"Awning",
			Vector3.new(1.4, 0.3, 1.4),
			CFrame.new(-3.4 + (i - 1) * 1.4, PLINTH + 5.4, FRONT - 0.6) * CFrame.Angles(math.rad(18), 0, 0),
			color,
			{ shadow = false }
		)
	end
	Kit.door(d, "Door", CFrame.new(3, PLINTH, FRONT), 2.4, 4.4, Palette.roofPlum, Palette.cream)
	-- The dress form by the door: a stand, a skirt and a bust
	local form = Vector3.new(0.9, PLINTH, FRONT - 1.4)
	d.post("FormStand", 1.6, 0.25, form + Vector3.new(0, 0.8, 0), Palette.woodDark)
	d.post("Skirt", 1.4, 1.3, form + Vector3.new(0, 2.2, 0), Palette.flowerPink)
	d.ball("Bust", 1.1, form + Vector3.new(0, 3.3, 0), Palette.cream)
	sign(d, Vector3.new(3, PLINTH + 6.2, FRONT - 0.2), function(s, at)
		s.block("Needle", Vector3.new(0.2, 1.6, 0.15), at * CFrame.Angles(0, 0, math.rad(30)), Palette.metal, {
			shadow = false,
		})
		s.block(
			"Thread",
			Vector3.new(0.9, 0.2, 0.15),
			at + Vector3.new(0, -0.4, 0),
			Palette.roofPlum,
			{ shadow = false }
		)
	end)
	Kit.sproutTag(d, Vector3.new(-3.8, TOP + 1.6, 4.4), 2.5, Palette.wood, Palette.lime)
	local window = model:FindFirstChild("Window", true) :: BasePart
	return { body = body, chimney = chimney, outputTable = outputTable(b), window = window, anim = anim }
end

local BUILDERS: { [string]: (Model, Kit.Builder) -> Parts } = {
	Bakery = bakery,
	FeedMill = feedMill,
	Dairy = dairy,
	SugarMill = sugarMill,
	TextileMill = textileMill,
	Tailor = tailor,
	SnackFactory = snackFactory,
	Diner = diner,
	PaperMill = paperMill,
	-- The second Feed Mill (level 19): the same mill under a red roof, so the two tell apart
	FeedMill2 = function(model: Model, b: Kit.Builder): Parts
		return feedMill(model, b, Palette.roofRed)
	end,
	IceCreamParlor = iceCreamParlor,
	PastryShop = pastryShop,
	JamKitchen = jamKitchen,
	RubberWorks = rubberWorks,
	PrepKitchen = prepKitchen,
	MoldingWorks = moldingWorks,
	HomewaresShop = homewaresShop,
	CandyFactory = candyFactory,
	Cantina = cantina,
	StationeryShop = stationeryShop,
	FurnitureWorkshop = furnitureWorkshop,
	Smelter = smelter,
	Smelter2 = function(model: Model, b: Kit.Builder): Parts
		return smelter(model, b, Palette.roofTeal)
	end,
	-- The third Feed Mill (level 44) and third Smelter (level 45) wear plum roofs
	FeedMill3 = function(model: Model, b: Kit.Builder): Parts
		return feedMill(model, b, Palette.roofPlum)
	end,
	Smelter3 = function(model: Model, b: Kit.Builder): Parts
		return smelter(model, b, Palette.roofPlum)
	end,
}

function ArtFactories.has(id: string): boolean
	return BUILDERS[id] ~= nil
end

-- Build factory `id` into `model` at `cf` (bottom-centre, front at local -Z).
function ArtFactories.build(id: string, model: Model, cf: CFrame): Parts
	local build = BUILDERS[id] or bakery
	model:SetAttribute("FactoryOrigin", cf)
	return build(model, Kit.builder(model, cf, true))
end

-- Shows `waiting` queued jobs (not the one in progress) as small crates stacked beside the
-- output table, up to QUEUE_SHOWN. Rebuilt each call into a "Queue" model.
function ArtFactories.setQueue(model: Model, waiting: number)
	local old = model:FindFirstChild("Queue")
	if old then
		old:Destroy()
	end
	local origin = model:GetAttribute("FactoryOrigin")
	local n = math.clamp(math.floor(waiting), 0, ArtFactories.QUEUE_SHOWN)
	if n == 0 or typeof(origin) ~= "CFrame" then
		return
	end
	local queue = Kit.model("Queue", model)
	local b = Kit.builder(queue, origin, false)
	for i = 1, n do
		local row, layer = (i - 1) % 3, (i - 1) // 3
		b.block(
			"QueueCrate",
			Vector3.new(1.3, 1.1, 1.3),
			CFrame.new(5.4, 0.55 + layer * 1.15, ArtFactories.TABLE_Z + 1.5 - row * 1.5) * Kit.yaw(layer * 12),
			if layer == 0 then Palette.crate else Palette.crate:Lerp(Palette.cream, 0.2)
		)
	end
end

-- Which finished goods stand on the output table, at most GOODS_SHOWN: one of each kind
-- waiting first (in `ids` order), then more of them in turn, so a mixed tray shows its mix.
function ArtFactories.goodsShown(ids: { string }, output: { [string]: number }): { string }
	local shown = {}
	local round = 1
	while #shown < ArtFactories.GOODS_SHOWN do
		local added = false
		for _, id in ids do
			if (output[id] or 0) >= round and #shown < ArtFactories.GOODS_SHOWN then
				table.insert(shown, id)
				added = true
			end
		end
		if not added then
			break
		end
		round += 1
	end
	return shown
end

return ArtFactories
