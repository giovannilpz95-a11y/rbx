--!strict
-- The MVP animals and their pens: Cows / Cow Barn, Chickens / Chicken Coop, Sheep / Sheep Fold.
-- Design/16 Model Catalog §2.2 and Design/03 Animals.
--
-- Animals are chunky and cute with big heads, so they read from the Overview camera. Built
-- from Parts (≤ 12 each) until rigged meshes exist; every animal is a Model so the pen can
-- show, hide and bob it as one piece. Pens are 12 x 12 studs with the front (gate) at local -Z.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtAnimals = {}

ArtAnimals.ANIMAL_PARTS_MAX = 12
ArtAnimals.PEN_PARTS_MAX = 40 -- not counting the animals and products

type AnimalBuild = (b: Kit.Builder) -> ()

-- "Loaf cow" (16 §2.2): a rounded loaf body, one caramel patch draped like a saddle blanket,
-- a wide pink muzzle and ears sticking straight out. 11 parts. About 2 x 3.6 x 2.7 studs.
local function cow(b: Kit.Builder)
	b.block("Body", Vector3.new(1.9, 1.5, 2.9), Vector3.new(0, 1.55, 0.25), Palette.cowCoat)
	b.block("Patch", Vector3.new(2.02, 1.05, 1.4), Vector3.new(0, 1.85, 0.55), Palette.cowPatch)
	b.block("Head", Vector3.new(1.45, 1.35, 1.2), Vector3.new(0, 2.2, -1.65), Palette.cowCoat)
	b.block("Muzzle", Vector3.new(1.35, 0.7, 0.5), Vector3.new(0, 1.85, -2.35), Palette.cowMuzzle)
	b.block("Ears", Vector3.new(2.5, 0.32, 0.4), Vector3.new(0, 2.6, -1.6), Palette.cowPatch)
	for _, x in { -0.36, 0.36 } do
		b.ball("Eye", 0.32, Vector3.new(x, 2.45, -2.25), Palette.eye, { shadow = false })
	end
	for _, x in { -0.62, 0.62 } do
		for _, z in { -0.85, 1.25 } do
			b.block("Leg", Vector3.new(0.5, 0.85, 0.5), Vector3.new(x, 0.42, z), Palette.cowCoat, { shadow = false })
		end
	end
end

-- "Dumpling hen": an almost-round cream body, honey-brown wings, a coral comb, a fan tail and
-- two stubby orange legs. 10 parts. About 1.3 x 1.6 x 2.1 studs.
local function chicken(b: Kit.Builder)
	b.ball("Body", 1.35, Vector3.new(0, 0.95, 0.1), Palette.hen)
	b.block(
		"Wings",
		Vector3.new(1.4, 0.45, 0.7),
		CFrame.new(0, 0.95, 0.25) * CFrame.Angles(math.rad(-12), 0, 0),
		Palette.henWing,
		{ shadow = false }
	)
	b.ball("Head", 0.85, Vector3.new(0, 1.65, -0.35), Palette.hen, { shadow = false })
	b.block("Comb", Vector3.new(0.18, 0.4, 0.55), Vector3.new(0, 2.12, -0.35), Palette.comb, { shadow = false })
	b.wedge("Beak", Vector3.new(0.3, 0.24, 0.35), Vector3.new(0, 1.6, -0.88), Palette.beak, { shadow = false })
	b.block(
		"Tail",
		Vector3.new(0.7, 0.65, 0.25),
		CFrame.new(0, 1.35, 0.75) * CFrame.Angles(math.rad(-25), 0, 0),
		Palette.henWing,
		{ shadow = false }
	)
	for _, x in { -0.22, 0.22 } do
		b.ball("Eye", 0.16, Vector3.new(x, 1.75, -0.72), Palette.eye, { shadow = false })
		b.block("Leg", Vector3.new(0.16, 0.45, 0.16), Vector3.new(x, 0.22, 0.05), Palette.beak, { shadow = false })
	end
end

-- "Cloud sheep": a body of overlapping wool puffs, a slate-blue face and legs (not black) and
-- a woolly fringe over the eyes. 10 parts. About 1.8 x 2.6 x 2.4 studs.
local function sheep(b: Kit.Builder)
	b.ball("Wool", 1.8, Vector3.new(0, 1.45, 0.4), Palette.wool)
	b.ball("Wool", 1.65, Vector3.new(0, 1.5, -0.35), Palette.wool)
	b.ball("Wool", 1.2, Vector3.new(0, 2.15, 0.05), Palette.wool)
	b.block("Face", Vector3.new(0.8, 0.95, 0.8), Vector3.new(0, 1.6, -1.15), Palette.sheepFace)
	b.ball("Fringe", 0.75, Vector3.new(0, 2.1, -1.1), Palette.wool, { shadow = false })
	b.block("Ears", Vector3.new(1.45, 0.25, 0.3), Vector3.new(0, 1.85, -1.05), Palette.sheepFace, { shadow = false })
	for _, x in { -0.45, 0.45 } do
		for _, z in { -0.55, 0.75 } do
			b.block("Leg", Vector3.new(0.3, 0.8, 0.3), Vector3.new(x, 0.4, z), Palette.sheepFace, { shadow = false })
		end
	end
end

local ANIMALS: { [string]: AnimalBuild } = {
	CowBarn = cow,
	ChickenCoop = chicken,
	SheepFold = sheep,
}

-- Height of each animal, so products can float just above it.
ArtAnimals.HEIGHT = { CowBarn = 2.8, ChickenCoop = 2.3, SheepFold = 2.7 } :: { [string]: number }

-- One animal of the pen `penId` standing at `cf` (its feet), facing local -Z.
function ArtAnimals.animal(penId: string, cf: CFrame, name: string?): Model
	local model = Kit.model(name or "Animal")
	local build = ANIMALS[penId] or cow
	build(Kit.builder(model, cf, false))
	return model
end

-- The product a ready animal shows above its head: a Milk bottle, two Eggs or a Wool puff.
-- 2 parts. `cf` is the bottom of the prop.
function ArtAnimals.product(penId: string, cf: CFrame, name: string?): Model
	local model = Kit.model(name or "Product")
	local b = Kit.builder(model, cf, false)
	local glow = { shadow = false }
	if penId == "ChickenCoop" then
		b.ball("Egg", 0.75, Vector3.new(-0.25, 0.4, 0), Palette.egg, glow)
		b.ball("Egg", 0.65, Vector3.new(0.3, 0.35, 0.1), Palette.egg, glow)
	elseif penId == "SheepFold" then
		b.ball("Wool", 1, Vector3.new(0, 0.5, 0), Palette.wool, glow)
		b.block("Ribbon", Vector3.new(1.05, 0.25, 0.3), Vector3.new(0, 0.55, 0), Palette.plum, glow)
	else
		b.post("Bottle", 1, 0.62, Vector3.new(0, 0.5, 0), Palette.milk, glow)
		b.post("Cap", 0.22, 0.48, Vector3.new(0, 1.1, 0), Palette.gems:Lerp(Palette.roofTeal, 0.5), glow)
	end
	return model
end

---------------------------------------------------------------------------------------------
-- Pens
---------------------------------------------------------------------------------------------

local HALF = 6 -- pens are 12 x 12

-- Four fence sides with a 3-stud gate gap at the front. 23 parts.
local function fenceRing(b: Kit.Builder, color: Color3)
	local h = 2.4
	Kit.fence(b, "Fence", Vector3.new(-HALF, 0, HALF), Vector3.new(HALF, 0, HALF), h, 3, color)
	Kit.fence(b, "Fence", Vector3.new(-HALF, 0, -HALF), Vector3.new(-HALF, 0, HALF), h, 3, color)
	Kit.fence(b, "Fence", Vector3.new(HALF, 0, -HALF), Vector3.new(HALF, 0, HALF), h, 3, color)
	Kit.fence(b, "Fence", Vector3.new(-HALF, 0, -HALF), Vector3.new(-1.5, 0, -HALF), h, 2, color)
	Kit.fence(b, "Fence", Vector3.new(1.5, 0, -HALF), Vector3.new(HALF, 0, -HALF), h, 2, color)
end

-- A hollowed log trough on the ground, with feed showing inside. 2 parts.
local function trough(b: Kit.Builder, at: Vector3, feed: Color3)
	b.block("Trough", Vector3.new(3, 0.8, 1.1), at + Vector3.new(0, 0.4, 0), Palette.woodDark)
	b.block("Feed", Vector3.new(2.6, 0.15, 0.75), at + Vector3.new(0, 0.82, 0), feed, { shadow = false })
end

-- Cow Barn: an open shed with a teal barrel roof over the back, a hay rack and a trough.
local function cowBarn(b: Kit.Builder)
	fenceRing(b, Palette.wood)
	b.block("BackWall", Vector3.new(11.4, 4.2, 0.5), Vector3.new(0, 2.1, HALF - 0.45), Palette.woodLight)
	for _, x in { -5.5, 5.5 } do
		b.block("ShedPost", Vector3.new(0.6, 4.4, 0.6), Vector3.new(x, 2.2, 2.4), Palette.woodDark)
	end
	-- Barrel roof over z 1.9 .. 6.5, running along X
	Kit.archRoof(b, "Roof", CFrame.new(0, 4.4, 4.2) * Kit.yaw(90), 5.4, 12.8, 1.6, 4, 0.5, Palette.roofTeal)
	b.block("HayRack", Vector3.new(3.2, 1.2, 0.8), Vector3.new(-2.5, 2.6, HALF - 1.1), Palette.straw)
	trough(b, Vector3.new(3.2, 0, -3.6), Palette.straw)
	Kit.sproutTag(b, Vector3.new(0, 6.0, 4.2), 1.2, Palette.wood, Palette.lime)
end

-- Chicken Coop: an A-frame hen house on stilts with a plank ramp, a round porthole door and a
-- mustard roof, in a straw yard.
local function chickenCoop(b: Kit.Builder)
	fenceRing(b, Palette.wood)
	local hx, hz = -2.4, 3.9
	for _, x in { -1.5, 1.5 } do
		b.block("Stilt", Vector3.new(0.4, 1.5, 2), Vector3.new(hx + x, 0.75, hz), Palette.woodDark)
	end
	b.block("House", Vector3.new(3.8, 2, 2.6), Vector3.new(hx, 2.5, hz), Palette.oat, { collide = true })
	Kit.gableRoof(b, "Roof", Vector3.new(hx, 3.5, hz), 4.6, 3.4, 1.9, Palette.roofMustard)
	b.cyl("Porthole", 0.2, 1, CFrame.new(hx, 2.5, hz - 1.35) * Kit.yaw(90), Palette.cocoa)
	b.block(
		"Ramp",
		Vector3.new(0.9, 0.2, 2.2),
		CFrame.new(hx, 0.85, hz - 2.2) * CFrame.Angles(math.rad(-36), 0, 0),
		Palette.woodLight
	)
	b.block("NestBoxes", Vector3.new(1.6, 1.2, 2), Vector3.new(hx + 2.7, 0.6, hz + 0.2), Palette.roofMustard)
	b.block(
		"Straw",
		Vector3.new(1.4, 0.3, 1.8),
		Vector3.new(hx + 2.7, 1.3, hz + 0.2),
		Palette.straw,
		{ shadow = false }
	)
	trough(b, Vector3.new(3.2, 0, -3.6), Palette.straw)
	Kit.sproutTag(b, Vector3.new(hx, 5.4, hz), 1.2, Palette.wood, Palette.lime)
end

-- Sheep Fold: a round low stone wall (an octagon, the one round pen among square ones) with a
-- small plum-roofed shelter at the back.
local function sheepFold(b: Kit.Builder)
	local radius = 5.7
	local side = 2 * radius * math.tan(math.rad(22.5))
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
		if i == 4 then
			continue -- the gap at the front (local -Z) is the way in
		end
		b.block(
			"Fence",
			Vector3.new(side + 0.5, 1.6, 0.9),
			CFrame.lookAt(dir * radius + Vector3.new(0, 0.8, 0), dir * (radius + 1) + Vector3.new(0, 0.8, 0)),
			if i % 2 == 0 then Palette.stone else Palette.stoneLight
		)
	end
	for _, x in { -2.6, 2.6 } do
		b.block("ShedPost", Vector3.new(0.5, 3.4, 0.5), Vector3.new(x, 1.7, 2.4), Palette.woodDark)
	end
	b.block("BackBoard", Vector3.new(5.6, 3.2, 0.4), Vector3.new(0, 1.6, 4.9), Palette.woodLight)
	Kit.gableRoof(b, "Roof", Vector3.new(0, 3.4, 3.65), 6.6, 3.4, 1.5, Palette.roofPlum)
	b.block("Stool", Vector3.new(0.9, 0.9, 0.9), Vector3.new(3.4, 0.45, 1.2), Palette.wood)
	trough(b, Vector3.new(-2.6, 0, -2.6), Palette.wheatGreen)
	Kit.sproutTag(b, Vector3.new(0, 5, 3.65), 1.2, Palette.wood, Palette.lime)
end

local PENS: { [string]: (Kit.Builder) -> () } = {
	CowBarn = cowBarn,
	ChickenCoop = chickenCoop,
	SheepFold = sheepFold,
}

ArtAnimals.FLOOR_COLOR = {
	CowBarn = Palette.grassLight,
	ChickenCoop = Palette.straw,
	SheepFold = Palette.grassLight,
} :: { [string]: Color3 }

-- Build a pen's fences and buildings into `parent`. `cf` is the pen's bottom-centre with the
-- gate at local -Z. Taps on these parts don't count; the pen's Floor is the tap target.
function ArtAnimals.pen(penId: string, cf: CFrame, parent: Instance)
	local build = PENS[penId] or cowBarn
	build(Kit.builder(parent, cf, false))
end

return ArtAnimals
