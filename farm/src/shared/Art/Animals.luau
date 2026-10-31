--!strict
-- The animals and their pens: Cows / Cow Barn, Chickens / Chicken Coop, Sheep / Sheep Fold,
-- (level 35) Bee Hives / Bee Yard and (level 42) Pigs / Pig Pen.
-- Design/16 Model Catalog §2.2 and Design/03 Animals.
--
-- Animals are chunky and cute with big heads, so they read from the Overview camera. Built
-- from Parts (≤ 12 each) until rigged meshes exist; every animal is a Model so the pen can
-- show, hide and bob it as one piece. Pens are 12 x 12 studs with the front (gate) at local -Z.

local Kit = require("./Kit")
local Merge = require("./Merge")
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

-- A bee hive: a stack of two honey-coloured boxes on a little stand with a plump striped bee
-- hovering over its roof. 9 parts. About 1.6 x 3 x 1.6 studs.
local function beeHive(b: Kit.Builder)
	b.block("Stand", Vector3.new(1.4, 0.3, 1.4), Vector3.new(0, 0.15, 0), Palette.woodDark)
	b.block("Box", Vector3.new(1.5, 0.7, 1.5), Vector3.new(0, 0.65, 0), Palette.roofMustard)
	b.block("Box", Vector3.new(1.5, 0.7, 1.5), Vector3.new(0, 1.37, 0), Palette.wheatHead)
	b.block("Lid", Vector3.new(1.7, 0.2, 1.7), Vector3.new(0, 1.82, 0), Palette.woodLight)
	b.block("Entrance", Vector3.new(0.6, 0.15, 0.1), Vector3.new(0, 0.45, -0.76), Palette.cocoa, { shadow = false })
	b.ball("Bee", 0.7, Vector3.new(0.2, 2.5, -0.2), Palette.flowerYellow)
	b.block("Stripe", Vector3.new(0.72, 0.18, 0.4), Vector3.new(0.2, 2.5, -0.2), Palette.cocoa, { shadow = false })
	for _, x in { -0.25, 0.25 } do
		b.block(
			"Wing",
			Vector3.new(0.45, 0.08, 0.3),
			CFrame.new(0.2 + x, 2.85, -0.1) * CFrame.Angles(0, 0, math.rad(x * 80)),
			Palette.flowerWhite,
			{ shadow = false }
		)
	end
end

-- "Barrel pig": a round pink barrel of a body, a big flat snout, floppy ears, short legs and
-- a curly tail. 11 parts. About 1.6 x 1.9 x 2.6 studs.
local function pig(b: Kit.Builder)
	local skin = Palette.flowerPink:Lerp(Palette.cream, 0.45)
	b.block("Body", Vector3.new(1.6, 1.3, 2.2), Vector3.new(0, 1.1, 0.25), skin)
	b.block("Head", Vector3.new(1.3, 1.15, 0.95), Vector3.new(0, 1.35, -1.2), skin)
	b.cyl("Snout", 0.35, 0.75, CFrame.new(0, 1.2, -1.82) * Kit.yaw(90), Palette.cowMuzzle)
	b.block(
		"Ears",
		Vector3.new(1.55, 0.18, 0.45),
		CFrame.new(0, 1.95, -1.2) * CFrame.Angles(math.rad(-20), 0, 0),
		Palette.cowMuzzle
	)
	for _, x in { -0.3, 0.3 } do
		b.ball("Eye", 0.24, Vector3.new(x, 1.6, -1.68), Palette.eye, { shadow = false })
	end
	for _, x in { -0.5, 0.5 } do
		for _, z in { -0.6, 1 } do
			b.block("Leg", Vector3.new(0.4, 0.5, 0.4), Vector3.new(x, 0.25, z), skin, { shadow = false })
		end
	end
	b.ball("Tail", 0.35, Vector3.new(0, 1.5, 1.4), Palette.cowMuzzle, { shadow = false })
end

local ANIMALS: { [string]: AnimalBuild } = {
	CowBarn = cow,
	ChickenCoop = chicken,
	SheepFold = sheep,
	BeeYard = beeHive,
	PigPen = pig,
}

-- Height of each animal, so products can float just above it.
ArtAnimals.HEIGHT =
	{ CowBarn = 2.8, ChickenCoop = 2.3, SheepFold = 2.7, BeeYard = 3, PigPen = 2.2 } :: { [string]: number }

-- One animal of the pen `penId` standing at `cf` (its feet), facing local -Z.
function ArtAnimals.animal(penId: string, cf: CFrame, name: string?): Model
	local model = Kit.model(name or "Animal")
	local build = ANIMALS[penId] or cow
	build(Kit.builder(model, cf, false))
	-- For the client's idle motion (Art/Motion): where the feet stand and which body it is
	model:SetAttribute("BaseCFrame", cf)
	model:SetAttribute("PenId", penId)
	return model
end

-- The parts of an animal that stay out of its merged look: a sheep's wool puffs regrow
-- (Art/Motion setWool resizes them)
ArtAnimals.MERGE_SKIP = { Wool = true, Fringe = true }

local looks: { [string]: Model } = {}

-- Merges one animal of each kind into a template (server, once; yields per kind). Pens built
-- afterwards get copies of it: one union per animal instead of ~10 parts (the part-cut pass).
-- The templates wait in `store` (ServerStorage), since a merge needs its model parented.
function ArtAnimals.mergeLooks(penIds: { string }, store: Instance, geometry: any?)
	local holder = Instance.new("Folder")
	holder.Name = "AnimalLooks"
	holder.Parent = store
	for _, penId in penIds do
		if looks[penId] == nil then
			local look = ArtAnimals.animal(penId, CFrame.new())
			look.Parent = holder
			if Merge.template(look, ArtAnimals.MERGE_SKIP, geometry) then
				looks[penId] = look
			end
		end
	end
end

-- An animal standing at `cf`: a copy of the merged template when there is one, else built.
function ArtAnimals.placed(penId: string, cf: CFrame, name: string): Model
	local look = looks[penId]
	if look then
		return Merge.place(look, cf, name)
	end
	return ArtAnimals.animal(penId, cf, name)
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
	elseif penId == "PigPen" then
		b.block("Bacon", Vector3.new(1.3, 0.15, 0.4), Vector3.new(0, 0.3, -0.25), Palette.cowMuzzle, glow)
		b.block("Bacon", Vector3.new(1.3, 0.15, 0.4), Vector3.new(0.1, 0.45, 0.2), Palette.roofRed, glow)
	elseif penId == "BeeYard" then
		b.block("Comb", Vector3.new(1.1, 0.9, 0.3), Vector3.new(0, 0.45, 0), Palette.roofMustard, glow)
		b.block("Drip", Vector3.new(0.3, 0.35, 0.32), Vector3.new(0.25, -0.05, 0), Palette.coins, glow)
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

-- Four fence sides with a 3-stud gate gap at the front. The back and the front carry the
-- corner posts, so the sides are just rails with one middle post. 19 parts.
local function fenceRing(b: Kit.Builder, color: Color3)
	local h = 2.4
	Kit.fence(b, "Fence", Vector3.new(-HALF, 0, HALF), Vector3.new(HALF, 0, HALF), h, 3, color)
	Kit.fence(b, "Fence", Vector3.new(-HALF, 0, -HALF), Vector3.new(-1.5, 0, -HALF), h, 2, color)
	Kit.fence(b, "Fence", Vector3.new(1.5, 0, -HALF), Vector3.new(HALF, 0, -HALF), h, 2, color)
	local post = color:Lerp(Color3.new(0, 0, 0), 0.12)
	for _, x in { -HALF, HALF } do
		for _, frac in { 0.45, 0.85 } do
			b.block("Fence", Vector3.new(0.25, 0.35, HALF * 2), Vector3.new(x, h * frac, 0), color)
		end
		b.block("FencePost", Vector3.new(0.5, h + 0.2, 0.5), Vector3.new(x, (h + 0.2) / 2, 0), post)
	end
end

-- A plank gate across the way in, hinged on its left post. It stays closed here; the
-- client's AnimalMotion swings it open on its hinge (ArtMotion.gateCFrame) when someone
-- walks up. 1 part.
local function gate(b: Kit.Builder, z: number, width: number)
	local g = b.block("Gate", Vector3.new(width - 0.3, 1.7, 0.2), Vector3.new(0, 1.15, z), Palette.woodLight)
	g:SetAttribute("ClosedCFrame", g.CFrame)
	g:SetAttribute("HingeCFrame", g.CFrame * CFrame.new(-(width - 0.3) / 2, 0, 0))
	g:SetAttribute("Swing", -100) -- degrees about the hinge: inward, away from whoever walks up
end

-- A hollowed log trough on the ground: a dark hollow, and the feed heaped in it while the
-- animals are fed (setPenState hides it when the pen needs feed). 3 parts.
local function trough(b: Kit.Builder, at: Vector3, feed: Color3)
	b.block("Trough", Vector3.new(3, 0.8, 1.1), at + Vector3.new(0, 0.4, 0), Palette.woodDark)
	b.block("Hollow", Vector3.new(2.6, 0.06, 0.75), at + Vector3.new(0, 0.81, 0), Palette.cocoa, { shadow = false })
	b.block("Feed", Vector3.new(2.6, 0.18, 0.75), at + Vector3.new(0, 0.86, 0), feed, { shadow = false })
end

-- The collection crate outside the gate (Design/15: walk past it to collect). The lid pops
-- swings open while products wait. 2 parts.
local function collectCrate(b: Kit.Builder, at: Vector3)
	b.block("CrateBox", Vector3.new(2, 1.3, 2), at + Vector3.new(0, 0.65, 0), Palette.crate)
	local lid = b.block("Lid", Vector3.new(2.15, 0.25, 2.15), at + Vector3.new(0, 1.42, 0), Palette.woodLight)
	-- setPenState swings it up on its back hinge while products wait
	local hinge = lid.CFrame * CFrame.new(0, -0.12, 1.07)
	lid:SetAttribute("ClosedCFrame", lid.CFrame)
	lid:SetAttribute("OpenCFrame", hinge * CFrame.Angles(math.rad(65), 0, 0) * hinge:ToObjectSpace(lid.CFrame))
end

ArtAnimals.CRATE_AT = Vector3.new(-3.6, 0, -7.6) -- outside the gate, to its left

-- Shows whether the pen's animals are fed (feed in the trough) and whether products wait in
-- the crate (lid open). Call after fading the pen, since this only hides parts.
function ArtAnimals.setPenState(pen: Instance, fed: boolean, waiting: boolean)
	for _, d in pen:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Feed" and not fed then
				d.Transparency = 1
			elseif d.Name == "Lid" then
				local cf = d:GetAttribute(if waiting then "OpenCFrame" else "ClosedCFrame")
				if typeof(cf) == "CFrame" then
					d.CFrame = cf
				end
			end
		end
	end
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
	gate(b, -HALF, 3)
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
	trough(b, Vector3.new(3.2, 0, -3.6), Palette.straw)
	gate(b, -HALF, 3)
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
	gate(b, -radius, side)
	Kit.sproutTag(b, Vector3.new(0, 5, 3.65), 1.2, Palette.wood, Palette.lime)
end

-- Bee Yard: a flower meadow inside a low hedge, with rows of pink and yellow blooms down
-- each side, a little honey house with a mustard roof at the back and a trough of feed.
local function beeYard(b: Kit.Builder)
	local h = 1.3
	b.block("Hedge", Vector3.new(HALF * 2, h, 0.9), Vector3.new(0, h / 2, HALF - 0.45), Palette.leaf)
	for _, x in { -HALF + 0.45, HALF - 0.45 } do
		b.block("Hedge", Vector3.new(0.9, h, HALF * 2 - 0.9), Vector3.new(x, h / 2, -0.45), Palette.leaf)
	end
	for _, x in { -(HALF + 1.5) / 2, (HALF + 1.5) / 2 } do
		b.block("Hedge", Vector3.new(HALF - 1.5, h, 0.9), Vector3.new(x, h / 2, -HALF + 0.45), Palette.leaf)
	end
	for i, x in { -3.8, 3.8 } do
		b.block(
			"Blooms",
			Vector3.new(1.2, 0.5, 6),
			Vector3.new(x, 0.25, -0.6),
			if i == 1 then Palette.flowerPink else Palette.flowerYellow,
			{ shadow = false }
		)
	end
	b.block("HoneyHouse", Vector3.new(3.4, 2.2, 2.2), Vector3.new(2.6, 1.1, 4), Palette.cream, { collide = true })
	Kit.gableRoof(b, "Roof", Vector3.new(2.6, 2.2, 4), 4, 2.8, 1.4, Palette.roofMustard)
	b.block("HoneyDoor", Vector3.new(1, 1.5, 0.1), Vector3.new(2.6, 0.75, 2.86), Palette.wood)
	trough(b, Vector3.new(-2.2, 0, 3.6), Palette.wheatHead)
	gate(b, -HALF, 3)
	Kit.sproutTag(b, Vector3.new(2.6, 4.2, 4), 1.2, Palette.wood, Palette.lime)
end

-- Pig Pen: a fenced yard with a round mud wallow, a low wooden sty with a rose roof at the
-- back and a trough by the gate.
local function pigPen(b: Kit.Builder)
	fenceRing(b, Palette.woodDark)
	b.cyl(
		"Mud",
		0.12,
		4.6,
		CFrame.new(2.4, 0.06, 0.4) * CFrame.Angles(0, 0, math.rad(90)),
		Palette.soil,
		{ shadow = false }
	)
	local hx, hz = -2.4, 3.8
	b.block("Sty", Vector3.new(4.4, 2, 2.8), Vector3.new(hx, 1, hz), Palette.woodLight, { collide = true })
	Kit.gableRoof(b, "Roof", Vector3.new(hx, 2, hz), 5.2, 3.6, 1.6, Palette.roofRed)
	b.block("StyDoor", Vector3.new(1.4, 1.3, 0.1), Vector3.new(hx, 0.65, hz - 1.42), Palette.cocoa)
	trough(b, Vector3.new(3.2, 0, -3.6), Palette.wheatHead)
	gate(b, -HALF, 3)
	Kit.sproutTag(b, Vector3.new(hx, 4.4, hz), 1.2, Palette.wood, Palette.lime)
end

local PENS: { [string]: (Kit.Builder) -> () } = {
	CowBarn = cowBarn,
	ChickenCoop = chickenCoop,
	SheepFold = sheepFold,
	BeeYard = beeYard,
	PigPen = pigPen,
}

ArtAnimals.FLOOR_COLOR = {
	CowBarn = Palette.grassLight,
	ChickenCoop = Palette.straw,
	SheepFold = Palette.grassLight,
	BeeYard = Palette.grassLight,
	PigPen = Palette.soilLight,
} :: { [string]: Color3 }

-- Build a pen's fences and buildings into `parent`. `cf` is the pen's bottom-centre with the
-- gate at local -Z. Taps on these parts don't count; the pen's Floor is the tap target.
function ArtAnimals.pen(penId: string, cf: CFrame, parent: Instance)
	local build = PENS[penId] or cowBarn
	local b = Kit.builder(parent, cf, false)
	build(b)
	collectCrate(b, ArtAnimals.CRATE_AT)
	parent:SetAttribute("PenOrigin", cf) -- for setPenLevel's add-ons
end

-- What the server's pen shell merge (Art/Merge mergeShell) leaves out: the tap Floor, the
-- animals and their products (they move and fade), the gate (it swings), the feed and crate
-- lid (setPenState) and the upgrade add-ons. PlotService names the six animals Animal_1-6.
ArtAnimals.SHELL_SKIP = { Floor = true, Gate = true, Feed = true, Lid = true, Upgrade = true } :: { [string]: boolean }
for i = 1, 6 do
	ArtAnimals.SHELL_SKIP["Animal_" .. i] = true
	ArtAnimals.SHELL_SKIP["Product_" .. i] = true
end

---------------------------------------------------------------------------------------------
-- Pen upgrade looks (Design/03 Animals, Pen Upgrades)
---------------------------------------------------------------------------------------------

ArtAnimals.PEN_LEVEL_MAX = 5
ArtAnimals.UPGRADE_PARTS_MAX = 10 -- add-ons at level 5, on top of PEN_PARTS_MAX

-- Each pen's accent, the same as its roof, for the painted trough, the picket fence and the
-- shade roof.
ArtAnimals.ACCENT = {
	CowBarn = Palette.roofTeal,
	ChickenCoop = Palette.roofMustard,
	SheepFold = Palette.roofPlum,
	BeeYard = Palette.roofMustard,
	PigPen = Palette.roofRed,
} :: { [string]: Color3 }

local TROUGH_AT = {
	CowBarn = Vector3.new(3.2, 0, -3.6),
	ChickenCoop = Vector3.new(3.2, 0, -3.6),
	SheepFold = Vector3.new(-2.6, 0, -2.6),
	BeeYard = Vector3.new(-2.2, 0, 3.6),
	PigPen = Vector3.new(3.2, 0, -3.6),
} :: { [string]: Vector3 }

-- Paints `p` (remembering its built color, so a lower level can put it back).
local function paint(p: BasePart, color: Color3?)
	local base = p:GetAttribute("BuiltColor")
	if typeof(base) ~= "Color3" then
		base = p.Color
		p:SetAttribute("BuiltColor", base)
	end
	p.Color = color or base :: Color3
end

-- Level 4: a canvas shade over the trough on two poles. 3 parts.
local function shade(b: Kit.Builder, trough: Vector3, accent: Color3)
	for _, x in { -1.9, 1.9 } do
		b.block("ShadePole", Vector3.new(0.3, 3.6, 0.3), trough + Vector3.new(x, 1.8, -0.9), Palette.woodDark)
	end
	b.block(
		"Shade",
		Vector3.new(4.4, 0.2, 2.6),
		CFrame.new(trough + Vector3.new(0, 3.5, 0)) * CFrame.Angles(math.rad(-12), 0, 0),
		accent
	)
end

-- Level 5: flower boxes at the front corners, clear of the crate (4 parts) and, on fenced
-- pens, stone footings under the front fence (2 parts).
local function flowerBoxes(b: Kit.Builder, fenced: boolean)
	for i, x in { -5.6, 5.6 } do
		b.block("FlowerBox", Vector3.new(1.4, 0.6, 0.5), Vector3.new(x, 0.3, -HALF - 0.6), Palette.woodLight)
		b.block(
			"Flowers",
			Vector3.new(1.2, 0.45, 0.35),
			Vector3.new(x, 0.8, -HALF - 0.6),
			if i == 1 then Palette.flowerPink else Palette.flowerYellow,
			{ shadow = false }
		)
	end
	if fenced then
		for _, sign in { -1, 1 } do
			b.block(
				"Footing",
				Vector3.new(HALF - 1.5 + 0.5, 0.5, 0.7),
				Vector3.new(sign * (HALF + 1.5) / 2, 0.25, -HALF),
				Palette.stoneLight
			)
		end
	end
end

-- Dresses `pen` (built by ArtAnimals.pen) for upgrade `level` 1-5:
--   2 painted trough, 3 picket fence in the pen's accent, 4 shade roof over the trough,
--   5 stone-footed front fence, flower boxes and a gold Sprout Tag.
-- Safe to call again with any level; it rebuilds the add-ons and repaints from scratch.
function ArtAnimals.setPenLevel(pen: Instance, penId: string, level: number)
	local accent = ArtAnimals.ACCENT[penId] or Palette.roofTeal
	local old = pen:FindFirstChild("Upgrade")
	if old then
		old:Destroy()
	end
	for _, d in pen:GetDescendants() do
		if not d:IsA("BasePart") or d:FindFirstAncestor("Upgrade") then
			continue
		end
		local name = d.Name
		if name == "Trough" then
			paint(d, if level >= 2 then accent else nil)
		elseif name == "Fence" then
			-- Wooden rails go cream like pickets; the Sheep Fold's stone wall is whitewashed
			paint(
				d,
				if level < 3 then nil elseif penId == "SheepFold" then Palette.cream:Lerp(accent, 0.2) else Palette.cream
			)
		elseif name == "FencePost" then
			paint(d, if level >= 3 then accent else nil)
		elseif name == "Leaf" and d.Parent and d.Parent.Name == "SproutTag" then
			paint(d, if level >= 5 then Palette.coins else nil)
		end
	end
	local origin = pen:GetAttribute("PenOrigin")
	if level < 4 or typeof(origin) ~= "CFrame" then
		return
	end
	local upgrade = Kit.model("Upgrade", pen)
	local b = Kit.builder(upgrade, origin, false)
	shade(b, TROUGH_AT[penId] or TROUGH_AT.CowBarn, accent)
	if level >= 5 then
		flowerBoxes(b, penId ~= "SheepFold" and penId ~= "BeeYard")
	end
end

return ArtAnimals
