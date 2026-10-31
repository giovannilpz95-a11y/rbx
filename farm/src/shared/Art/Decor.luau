--!strict
-- The decorations players buy and place (Design/07 Town Building, 16 Model Catalog §2.11), in
-- the same chunky style as the rest of the farm. Each builder fills a footprint centred on
-- `origin` (on the ground, front at local -Z) and stays within PARTS_MAX parts; paths stay
-- within PATH_PARTS_MAX because players lay a lot of them. Parts keep CanQuery on, so a tap
-- on any of them reaches the tap target they are parented under.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtDecor = {}

ArtDecor.PARTS_MAX = 12
ArtDecor.PATH_PARTS_MAX = 3

local QUIET = { shadow = false }
local SOLID = { collide = true } -- avatars bump into the big solid pieces
local LIFT = 0.25 -- paths sit just above the plot's own path strips, so they never flicker

local function at(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local BUILDERS: { [string]: (Kit.Builder) -> () } = {
	GravelPath = function(b)
		b.block("Path", Vector3.new(3.9, 0.2, 3.9), at(0, LIFT + 0.1, 0), Palette.path, QUIET)
		b.block(
			"Stone",
			Vector3.new(1.2, 0.22, 0.9),
			CFrame.new(-0.8, LIFT + 0.12, -0.7) * Kit.yaw(20),
			Palette.pathEdge,
			QUIET
		)
		b.block(
			"Stone",
			Vector3.new(0.9, 0.22, 0.8),
			CFrame.new(0.9, LIFT + 0.12, 0.8) * Kit.yaw(-15),
			Palette.stoneLight,
			QUIET
		)
	end,
	BrickPath = function(b)
		b.block("Path", Vector3.new(3.9, 0.2, 3.9), at(0, LIFT + 0.1, 0), Palette.brick, QUIET)
		for _, z in { -1, 1 } do
			b.block(
				"Course",
				Vector3.new(3.9, 0.22, 0.25),
				at(0, LIFT + 0.11, z),
				Palette.brick:Lerp(Palette.cream, 0.35),
				QUIET
			)
		end
	end,
	PicketFence = function(b)
		local white = Palette.cream
		for _, y in { 0.9, 1.9 } do
			b.block("Rail", Vector3.new(4, 0.3, 0.2), at(0, y, 0.15), Palette.wood, QUIET)
		end
		for _, x in { -1.4, 0, 1.4 } do
			b.block("Picket", Vector3.new(0.6, 2.4, 0.25), at(x, 1.2, 0), white)
			b.block(
				"Point",
				Vector3.new(0.43, 0.43, 0.25),
				CFrame.new(x, 2.4, 0) * CFrame.Angles(0, 0, math.rad(45)),
				white,
				QUIET
			)
		end
	end,
	HedgeRow = function(b)
		b.block("Hedge", Vector3.new(3.8, 1.8, 1.6), at(0, 0.9, 0), Palette.grassDark, SOLID)
		for i, x in { -1.2, 0, 1.2 } do
			b.ball("Top", 1.7, at(x, 1.9, 0), if i == 2 then Palette.treeTop else Palette.treeTopDark)
		end
		b.ball("Flower", 0.45, at(-0.6, 1.5, -0.8), Palette.flowerPink, QUIET)
		b.ball("Flower", 0.45, at(0.9, 1.2, -0.8), Palette.flowerWhite, QUIET)
	end,
	FlowerBed = function(b)
		b.block("Border", Vector3.new(3.6, 0.8, 3.6), at(0, 0.4, 0), Palette.wood, SOLID)
		b.block("Soil", Vector3.new(3, 0.2, 3), at(0, 0.82, 0), Palette.soil, QUIET)
		b.block("Leaves", Vector3.new(2.6, 0.5, 2.6), at(0, 1.1, 0), Palette.leafLight, QUIET)
		for i, spot in { at(-0.8, 1.6, -0.8), at(0.8, 1.7, -0.5), at(-0.3, 1.75, 0.8), at(0.9, 1.6, 0.9) } do
			local color = ({ Palette.flowerPink, Palette.flowerYellow, Palette.plum, Palette.flowerWhite })[i]
			b.ball("Flower", 0.9, spot, color, QUIET)
		end
	end,
	OakTree = function(b)
		Kit.tree(b, "Oak", at(0, 0, 0), 1.3, Palette.treeTop, Palette.treeTopDark, Palette.trunk)
		b.ball("Oak", 3.2, at(-1.4, 5.4, -0.6), Palette.treeTopDark)
		b.block("Roots", Vector3.new(2, 0.4, 2), CFrame.new(0, 0.2, 0) * Kit.yaw(45), Palette.trunk, QUIET)
	end,
	HayBales = function(b)
		local bale = Palette.straw
		for _, spot in { CFrame.new(-1.7, 1.25, 0), CFrame.new(1.7, 1.25, 0), CFrame.new(0, 3.5, 0) } do
			local turned = spot * CFrame.Angles(0, math.rad(90), 0)
			b.cyl("Bale", 3, 2.5, turned, bale, SOLID)
			b.cyl("Band", 0.25, 2.55, turned * CFrame.new(-0.7, 0, 0), Palette.wheat, QUIET)
			b.cyl("Band", 0.25, 2.55, turned * CFrame.new(0.7, 0, 0), Palette.wheat, QUIET)
		end
	end,
	Pond = function(b)
		b.post("Rim", 0.6, 11.4, at(0, 0.3, 0), Palette.stoneLight)
		b.post("Water", 0.2, 10, at(0, 0.55, 0), Palette.water, QUIET)
		b.post("Lily", 0.1, 1.6, at(-2.2, 0.68, -1.5), Palette.leafLight, QUIET)
		b.post("Lily", 0.1, 1.2, at(-0.8, 0.68, -2.6), Palette.leaf, QUIET)
		b.ball("Bloom", 0.5, at(-2.2, 0.85, -1.5), Palette.flowerPink, QUIET)
		for i, x in { 3, 3.6, 4.1 } do
			local h = 2.2 - i * 0.3
			b.post("Reed", h, 0.25, at(x, 0.6 + h / 2, 2 - i * 0.6), Palette.leaf, QUIET)
		end
		b.ball("Rock", 1.6, at(-3.6, 0.6, 3), Palette.stone)
	end,
	LampPost = function(b)
		b.post("Base", 0.6, 1.2, at(0, 0.3, 0), Palette.stoneDark)
		b.post("Pole", 6, 0.4, at(0, 3.6, 0), Palette.cocoa, SOLID)
		b.block(
			"Lantern",
			Vector3.new(1.1, 1.3, 1.1),
			at(0, 7.2, 0),
			Palette.lantern,
			{ material = Enum.Material.Neon }
		)
		b.block("Cap", Vector3.new(1.5, 0.35, 1.5), at(0, 8, 0), Palette.cocoa, QUIET)
		b.ball("Finial", 0.5, at(0, 8.35, 0), Palette.coins, QUIET)
	end,
	Bench = function(b)
		for i, z in { -0.4, 0.3 } do
			b.block(
				"Seat",
				Vector3.new(5.6, 0.3, 0.65),
				at(0, 1.5, z),
				if i == 1 then Palette.woodLight else Palette.wood
			)
		end
		for _, y in { 2.3, 3 } do
			b.block(
				"Back",
				Vector3.new(5.6, 0.45, 0.25),
				CFrame.new(0, y, 0.85) * CFrame.Angles(math.rad(-10), 0, 0),
				Palette.woodLight
			)
		end
		for _, x in { -2.4, 2.4 } do
			b.block("Side", Vector3.new(0.35, 1.5, 1.6), at(x, 0.75, 0.1), Palette.cocoa, SOLID)
			b.block("Arm", Vector3.new(0.45, 0.25, 1.6), at(x, 2.05, 0.1), Palette.cocoa, QUIET)
		end
	end,
	PicnicTable = function(b)
		b.block("Top", Vector3.new(5.6, 0.35, 2.8), at(0, 2.6, 0), Palette.wood)
		b.block("Cloth", Vector3.new(3.6, 0.1, 2.9), at(0, 2.82, 0), Palette.roofRed, QUIET)
		for _, x in { -0.9, 0.9 } do
			b.block("Check", Vector3.new(0.6, 0.12, 2.92), at(x, 2.83, 0), Palette.cream, QUIET)
		end
		for _, z in { -2.2, 2.2 } do
			b.block("Seat", Vector3.new(5.6, 0.3, 1), at(0, 1.4, z), Palette.woodLight)
		end
		for _, x in { -2.2, 2.2 } do
			b.block("Legs", Vector3.new(0.4, 2.45, 5.2), at(x, 1.22, 0), Palette.woodDark, SOLID)
		end
		b.post("Pole", 3.4, 0.25, at(0, 4.4, 0), Palette.cream, QUIET)
		b.post("Shade", 0.5, 5, at(0, 6, 0), Palette.roofTeal)
		b.post("ShadeTop", 0.5, 2.6, at(0, 6.45, 0), Palette.cream, QUIET)
	end,
	StoneFountain = function(b)
		b.post("Basin", 1.4, 11, at(0, 0.7, 0), Palette.stoneLight, SOLID)
		b.post("Water", 0.2, 9.6, at(0, 1.35, 0), Palette.water, QUIET)
		b.post("Pillar", 3.4, 1.4, at(0, 3, 0), Palette.stone)
		b.post("Bowl", 0.8, 5, at(0, 4.9, 0), Palette.stoneLight)
		b.post("BowlWater", 0.15, 4.3, at(0, 5.32, 0), Palette.water, QUIET)
		b.post("Spout", 1.3, 0.6, at(0, 5.95, 0), Palette.stone, QUIET)
		b.ball("Splash", 1, at(0, 6.8, 0), Palette.glass, { shadow = false, transparency = 0.25 })
		for _, a in { 45, 135, 225, 315 } do
			local r = math.rad(a)
			b.ball(
				"Spray",
				0.55,
				at(math.cos(r) * 1.9, 5.6, math.sin(r) * 1.9),
				Palette.glass,
				{ shadow = false, transparency = 0.35 }
			)
		end
	end,
	-- Level 13+ decorations (Model List - Town & Factories §7, P1)
	SteppingStones = function(b)
		for i, spot in { at(-0.9, 0, -1), at(0.8, 0, 0.1), at(-0.6, 0, 1.2) } do
			local w = 1.6 - i * 0.15
			b.post(
				"Stone",
				0.22,
				w,
				spot + Vector3.new(0, LIFT + 0.11, 0),
				if i == 2 then Palette.stoneLight else Palette.stone,
				QUIET
			)
		end
	end,
	FarmLane = function(b)
		b.block("Lane", Vector3.new(3.9, 0.2, 3.9), at(0, LIFT + 0.1, 0), Palette.path, QUIET)
		for _, x in { -1, 1 } do
			b.block("Rut", Vector3.new(0.55, 0.22, 3.9), at(x, LIFT + 0.11, 0), Palette.soilLight, QUIET)
		end
	end,
	RailFence = function(b)
		for _, x in { -1.7, 1.7 } do
			b.block("Post", Vector3.new(0.5, 2.6, 0.5), at(x, 1.3, 0), Palette.woodDark, SOLID)
			b.block("Cap", Vector3.new(0.6, 0.2, 0.6), at(x, 2.7, 0), Palette.cocoa, QUIET)
		end
		for _, y in { 1, 2 } do
			b.block("Rail", Vector3.new(3.6, 0.35, 0.25), at(0, y, 0), Palette.wood, QUIET)
		end
	end,
	StoneWall = function(b)
		b.block("Wall", Vector3.new(4, 1.6, 1.4), at(0, 0.8, 0), Palette.stone, SOLID)
		b.block("Coping", Vector3.new(4, 0.35, 1.6), at(0, 1.78, 0), Palette.stoneLight, QUIET)
		-- a few odd-sized face stones, staggered like a dry-stone course
		for i, s in { { -1.2, 0.35, 1.3 }, { 0.2, 0.35, 1.1 }, { 1.4, 1.05, 0.9 } } do
			b.block(
				"Stone",
				Vector3.new(s[3], 0.5, 0.2),
				at(s[1], s[2], -0.71),
				if i == 2 then Palette.stoneDark else Palette.stoneLight,
				QUIET
			)
		end
		b.ball("Moss", 0.8, at(-1.6, 1.9, -0.3), Palette.leafLight, QUIET)
	end,
	PottedFlowers = function(b)
		for i, spot in { at(-0.9, 0, 0.4), at(0.9, 0, -0.5) } do
			local h = 1.4 - (i - 1) * 0.4
			b.post("Pot", h, 1.5, spot + Vector3.new(0, h / 2, 0), Palette.brick, SOLID)
			b.post("Rim", 0.25, 1.75, spot + Vector3.new(0, h, 0), Palette.brick:Lerp(Palette.cream, 0.3), QUIET)
			b.ball("Leaves", 1.4, spot + Vector3.new(0, h + 0.5, 0), Palette.leafLight, QUIET)
			b.ball(
				"Bloom",
				0.7,
				spot + Vector3.new(0.2, h + 1.1, -0.2),
				if i == 1 then Palette.flowerPink else Palette.flowerYellow,
				QUIET
			)
		end
	end,
	SunflowerPatch = function(b)
		b.block("Soil", Vector3.new(3.6, 0.35, 3.6), at(0, 0.18, 0), Palette.soil, QUIET)
		for i, spot in { at(-1, 0, 0.8), at(1, 0, 0.5), at(0, 0, -0.9) } do
			local h = 3.4 + i * 0.4
			b.post("Stalk", h, 0.25, spot + Vector3.new(0, h / 2, 0), Palette.leaf, QUIET)
			-- the head faces the front (local -Z), nodding down a little
			local head = CFrame.new(spot + Vector3.new(0, h + 0.2, -0.15))
				* CFrame.Angles(math.rad(-20), math.rad(90), 0)
			b.cyl("Petals", 0.25, 1.6, head, Palette.flowerYellow)
			if i == 3 then
				b.cyl("Face", 0.3, 0.8, head * CFrame.new(0.05, 0, 0), Palette.soilDark, QUIET)
			end
		end
	end,
	Scarecrow = function(b)
		b.post("Pole", 5, 0.35, at(0, 2.5, 0.2), Palette.woodDark, SOLID)
		b.block("Arms", Vector3.new(3.4, 0.3, 0.3), at(0, 3.6, 0.2), Palette.woodDark, QUIET)
		b.block("Shirt", Vector3.new(2, 1.7, 0.9), at(0, 3.2, 0), Palette.roofTeal)
		b.block("Patch", Vector3.new(0.5, 0.5, 0.1), at(0.45, 2.9, -0.47), Palette.roofMustard, QUIET)
		b.ball("Head", 1.3, at(0, 4.6, 0), Palette.sack)
		b.post("HatBrim", 0.15, 2, at(0, 5.15, 0), Palette.straw, QUIET)
		b.post("HatTop", 0.7, 1, at(0, 5.55, 0), Palette.straw, QUIET)
		for _, x in { -1.75, 1.75 } do
			b.ball("Straw", 0.5, at(x, 3.6, 0.2), Palette.wheat, QUIET)
		end
		b.ball("Crow", 0.6, at(1.3, 3.95, 0.2), Palette.cocoa, QUIET)
	end,
	RoundPine = function(b)
		b.post("Trunk", 2, 1, at(0, 1, 0), Palette.trunk)
		for i, d in { 5.6, 4.4, 3 } do
			b.ball("Pine", d, at(0, 1.6 + i * 1.7, 0), if i == 2 then Palette.treeTopDark else Palette.leaf)
		end
		b.ball("Cone", 0.5, at(1.2, 3.6, -1.9), Palette.woodDark, QUIET)
	end,
	BlossomTree = function(b)
		Kit.tree(
			b,
			"Blossom",
			at(0, 0, 0),
			1.2,
			Palette.flowerPink,
			Palette.flowerPink:Lerp(Palette.cream, 0.5),
			Palette.trunk
		)
		b.ball("Blossom", 2.6, at(-1.3, 5, -0.5), Palette.flowerPink:Lerp(Palette.plum, 0.15))
		for _, spot in { at(1.6, 0.12, -1.2), at(-1.4, 0.12, 1.5), at(0.4, 0.12, 2.2) } do
			b.post("Petals", 0.05, 0.9, spot, Palette.flowerPink, QUIET)
		end
	end,
	Topiary = function(b)
		b.post("Planter", 1.2, 2.4, at(0, 0.6, 0), Palette.stoneLight, SOLID)
		b.post("Stem", 1.6, 0.3, at(0, 1.9, 0), Palette.trunk, QUIET)
		b.ball("Ball", 2.2, at(0, 2.5, 0), Palette.treeTopDark)
		b.ball("Ball", 1.5, at(0, 4, 0), Palette.treeTop)
		b.ball("Ball", 0.8, at(0, 5, 0), Palette.treeTopDark, QUIET)
	end,
	Birdbath = function(b)
		b.post("Foot", 0.4, 1.8, at(0, 0.2, 0), Palette.stone, SOLID)
		b.post("Stem", 2, 0.7, at(0, 1.4, 0), Palette.stoneLight)
		b.post("Bowl", 0.5, 3, at(0, 2.6, 0), Palette.stoneLight)
		b.post("Water", 0.1, 2.5, at(0, 2.86, 0), Palette.water, QUIET)
		b.ball("Bird", 0.55, at(1, 3.1, 0.6), Palette.roofTeal, QUIET)
		b.ball("Beak", 0.2, at(1, 3.15, 0.3), Palette.beak, QUIET)
	end,
	GardenSwing = function(b)
		for _, x in { -3.4, 3.4 } do
			for _, z in { -0.9, 0.9 } do
				b.block(
					"Leg",
					Vector3.new(0.35, 5.6, 0.35),
					CFrame.new(x, 2.7, z * 0.55) * CFrame.Angles(math.rad(z > 0 and 10 or -10), 0, 0),
					Palette.woodDark,
					SOLID
				)
			end
		end
		b.block("Beam", Vector3.new(7.4, 0.4, 0.4), at(0, 5.5, 0), Palette.wood, QUIET)
		for _, x in { -1.5, 1.5 } do
			b.block("Rope", Vector3.new(0.1, 3, 0.1), at(x, 3.95, 0), Palette.sack, QUIET)
		end
		b.block("Seat", Vector3.new(3.6, 0.3, 1.1), at(0, 2.35, 0), Palette.roofMustard)
		b.block("Back", Vector3.new(3.6, 1, 0.2), at(0, 2.9, 0.5), Palette.roofMustard:Lerp(Palette.cream, 0.3), QUIET)
	end,
	-- Level 21-28 set: Township's level and price slots, our own pieces
	DaffodilBed = function(b)
		b.post("Rim", 0.7, 3.6, at(0, 0.35, 0), Palette.stoneLight, SOLID)
		b.post("Soil", 0.15, 3.1, at(0, 0.75, 0), Palette.soil, QUIET)
		b.post("Leaves", 0.45, 2.6, at(0, 1, 0), Palette.leaf, QUIET)
		for _, spot in { at(-0.8, 1.55, -0.6), at(0.85, 1.7, -0.3), at(0, 1.6, 0.85) } do
			-- a white star of petals with a deep yellow trumpet facing up
			b.post("Petals", 0.12, 1, spot, Palette.flowerWhite:Lerp(Palette.flowerYellow, 0.35), QUIET)
			b.post("Trumpet", 0.4, 0.45, spot + Vector3.new(0, 0.25, 0), Palette.carrot, QUIET)
		end
	end,
	PalmPair = function(b)
		b.post("Sand", 0.3, 3.8, at(0, 0.15, 0), Palette.oat, QUIET)
		for i, palm in { { at(-0.7, 0, 0.5), 4.6, -10 }, { at(0.8, 0, -0.6), 3.4, 14 } } do
			local foot, h, lean = palm[1] :: Vector3, palm[2] :: number, palm[3] :: number
			local trunk = CFrame.new(foot) * CFrame.Angles(0, 0, math.rad(lean)) * CFrame.new(0, h / 2, 0)
			b.block("Trunk", Vector3.new(0.45, h, 0.45), trunk, Palette.trunk)
			local top = (trunk * CFrame.new(0, h / 2, 0)).Position
			-- four fronds fanning out from the top and drooping at the tips
			for k = 0, 3 do
				b.block(
					"Frond",
					Vector3.new(2, 0.15, 0.6),
					CFrame.new(top)
						* Kit.yaw(k * 90 + i * 40)
						* CFrame.Angles(0, 0, math.rad(-28))
						* CFrame.new(0.9, 0, 0),
					if (k + i) % 2 == 0 then Palette.leafLight else Palette.leaf,
					QUIET
				)
			end
		end
		b.ball("Coconut", 0.45, at(-0.45, 4.45, 0.5), Palette.woodDark, QUIET)
	end,
	FishingJetty = function(b)
		-- planks running out over a patch of water at the back, with a rod over the end
		b.block("Water", Vector3.new(3.9, 0.15, 3.2), at(0, 0.08, 2.3), Palette.water, QUIET)
		b.block("Deck", Vector3.new(2.8, 0.3, 6), at(0, 0.9, -0.8), Palette.wood)
		for _, x in { -0.7, 0.7 } do
			b.block("Seam", Vector3.new(0.08, 0.32, 6), at(x, 0.9, -0.8), Palette.woodDark, QUIET)
		end
		for _, x in { -1.25, 1.25 } do
			for _, z in { -3.3, 1.8 } do
				b.post("Piling", 1.4, 0.45, at(x, 0.55, z), Palette.woodDark, SOLID)
			end
		end
		b.post("Bollard", 0.6, 0.5, at(1, 1.35, 1.2), Palette.woodDark, QUIET)
		b.post("Bucket", 0.6, 0.6, at(-0.8, 1.35, -0.4), Palette.metal, QUIET)
		b.block(
			"Rod",
			Vector3.new(0.1, 0.1, 3.2),
			CFrame.new(-0.6, 1.7, 2.2) * CFrame.Angles(math.rad(22), 0, 0),
			Palette.cocoa,
			QUIET
		)
	end,
	GardenObelisk = function(b)
		b.block("Plinth", Vector3.new(2.6, 0.8, 2.6), at(0, 0.4, 0), Palette.stoneDark, SOLID)
		b.block("Step", Vector3.new(1.9, 0.4, 1.9), at(0, 1, 0), Palette.stone, QUIET)
		b.block("Shaft", Vector3.new(1.1, 5, 1.1), at(0, 3.7, 0), Palette.stoneLight)
		b.block(
			"Tip",
			Vector3.new(0.8, 0.8, 0.8),
			CFrame.new(0, 6.3, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35)),
			Palette.coins,
			QUIET
		)
		b.block("Band", Vector3.new(1.25, 0.25, 1.25), at(0, 5.2, 0), Palette.coins, QUIET)
		b.block("Ivy", Vector3.new(0.12, 2.2, 0.6), at(-0.6, 2.4, -0.2), Palette.leaf, QUIET)
		b.block("Ivy", Vector3.new(0.6, 1.4, 0.12), at(0.15, 2, -0.6), Palette.leafLight, QUIET)
	end,
	DeckChairs = function(b)
		for i, x in { -1, 1 } do
			local stripe = if i == 1 then Palette.roofTeal else Palette.roofRed
			b.block("Frame", Vector3.new(1.2, 0.5, 2.6), at(x, 0.25, 0.1), Palette.wood, SOLID)
			b.block("Seat", Vector3.new(1.05, 0.15, 1.6), at(x, 0.58, -0.3), stripe:Lerp(Palette.cream, 0.25), QUIET)
			b.block(
				"Back",
				Vector3.new(1.05, 0.15, 1.3),
				CFrame.new(x, 1.05, 0.95) * CFrame.Angles(math.rad(50), 0, 0),
				stripe,
				QUIET
			)
		end
		b.post("Pole", 3.8, 0.15, at(0, 1.9, 1.4), Palette.metal, QUIET)
		b.post("Canopy", 0.3, 3.8, at(0, 3.85, 1.4), Palette.roofMustard, QUIET)
		b.ball("Top", 0.35, at(0, 4.1, 1.4), Palette.cream, QUIET)
		b.post("Table", 0.9, 0.7, at(0, 0.45, -1.3), Palette.woodLight, QUIET)
	end,
	PumpkinCart = function(b)
		b.block("Bed", Vector3.new(3, 0.7, 1.8), at(0, 1.25, 0), Palette.wood, SOLID)
		for _, z in { -1, 1 } do
			b.cyl("Wheel", 0.25, 1.6, CFrame.new(-0.4, 0.8, z) * Kit.yaw(90), Palette.woodDark, QUIET)
		end
		b.block("Handle", Vector3.new(1.6, 0.18, 1.2), at(1.85, 1.35, 0), Palette.woodDark, QUIET)
		b.block("Leg", Vector3.new(0.2, 0.9, 0.2), at(1.2, 0.45, 0), Palette.woodDark, QUIET)
		for i, spot in { at(-0.8, 1.95, -0.3), at(0.5, 1.95, 0.35), at(-0.1, 2.6, 0) } do
			local d = if i == 3 then 0.95 else 1.1
			b.ball("Pumpkin", d, spot, Palette.carrot)
			if i ~= 2 then
				b.block("Stem", Vector3.new(0.15, 0.3, 0.15), spot + Vector3.new(0, d / 2, 0), Palette.leaf, QUIET)
			end
		end
	end,
	RoseBed = function(b)
		b.block("Box", Vector3.new(3.6, 0.9, 3.6), at(0, 0.45, 0), Palette.woodLight, SOLID)
		b.block("Soil", Vector3.new(3.1, 0.2, 3.1), at(0, 0.92, 0), Palette.soilDark, QUIET)
		b.block("Trellis", Vector3.new(3.2, 2.4, 0.15), at(0, 2, 1.55), Palette.cream, QUIET)
		for _, spot in { at(-1, 1.5, 0.6), at(0.9, 1.6, 0.5), at(0, 1.45, -0.7) } do
			b.ball("Bush", 1.5, spot, Palette.treeTopDark)
		end
		for _, spot in { at(-1.1, 2.1, 0.3), at(0.7, 2.25, 0.1), at(0.2, 2, -1.1), at(-0.4, 2.9, 1.35) } do
			b.ball("Rose", 0.6, spot, Palette.roofRed, QUIET)
		end
	end,
	IrisBed = function(b)
		b.block("Planter", Vector3.new(3.6, 0.8, 1.8), at(0, 0.4, 0), Palette.stone, SOLID)
		b.block("Soil", Vector3.new(3.2, 0.15, 1.4), at(0, 0.82, 0), Palette.soil, QUIET)
		for i, x in { -1.1, 0, 1.1 } do
			local h = 1.8 + (i % 2) * 0.5
			b.block(
				"Blades",
				Vector3.new(0.5, h, 0.15),
				CFrame.new(x, 0.85 + h / 2, 0) * Kit.yaw(i * 30),
				Palette.leaf,
				QUIET
			)
			b.ball(
				"Iris",
				0.75,
				at(x + 0.15, 0.95 + h, -0.1),
				if i == 2 then Palette.plum:Lerp(Palette.cream, 0.3) else Palette.plum
			)
		end
		b.ball("Bud", 0.4, at(-0.5, 2, 0.3), Palette.flowerYellow, QUIET)
	end,
	Rowboat = function(b)
		local beached = CFrame.new(0, 0, 0) * Kit.yaw(20)
		b.post("Sand", 0.25, 3.9, at(0, 0.12, 0), Palette.oat, QUIET)
		b.block("Hull", Vector3.new(1.8, 0.8, 2.6), beached * CFrame.new(0, 0.6, 0.2), Palette.roofTeal, SOLID)
		b.block(
			"Bow",
			Vector3.new(1.27, 0.8, 1.27),
			beached * CFrame.new(0, 0.6, -1.1) * Kit.yaw(45),
			Palette.roofTeal,
			QUIET
		)
		b.block("Floor", Vector3.new(1.4, 0.1, 2.2), beached * CFrame.new(0, 0.95, 0.3), Palette.woodLight, QUIET)
		b.block("Thwart", Vector3.new(1.6, 0.15, 0.4), beached * CFrame.new(0, 1.05, 0.4), Palette.wood, QUIET)
		b.block("Trim", Vector3.new(1.85, 0.15, 0.15), beached * CFrame.new(0, 1, 1.45), Palette.cream, QUIET)
		b.block(
			"Oar",
			Vector3.new(0.15, 0.1, 3.2),
			beached * CFrame.new(1.2, 0.35, 0.2) * Kit.yaw(-8),
			Palette.woodDark,
			QUIET
		)
	end,
	Treehouse = function(b)
		b.post("Trunk", 7, 1.3, at(0, 3.5, 0.4), Palette.trunk, SOLID)
		b.block("Platform", Vector3.new(3.4, 0.3, 3.4), at(0, 4, 0), Palette.woodLight, QUIET)
		b.block("Hut", Vector3.new(2.4, 1.9, 2.2), at(0, 5.1, 0), Palette.wood)
		b.block(
			"Roof",
			Vector3.new(1.9, 1.9, 2.6),
			CFrame.new(0, 6.1, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Palette.roofRed,
			QUIET
		)
		b.block("Door", Vector3.new(0.8, 1.2, 0.1), at(-0.5, 4.75, -1.12), Palette.cocoa, QUIET)
		b.block("Window", Vector3.new(0.6, 0.5, 0.1), at(0.6, 5.3, -1.12), Palette.lantern, QUIET)
		b.block(
			"Ladder",
			Vector3.new(0.9, 4.4, 0.15),
			CFrame.new(-0.5, 2, -1.9) * CFrame.Angles(math.rad(-14), 0, 0),
			Palette.woodDark,
			QUIET
		)
		b.ball("Leaves", 3.4, at(-1, 7.4, 1.1), Palette.treeTop)
		b.ball("Leaves", 2.8, at(1.2, 7, 1.2), Palette.treeTopDark)
	end,
	TieredFountain = function(b)
		b.post("Basin", 0.9, 3.7, at(0, 0.45, 0), Palette.stoneLight, SOLID)
		b.post("Water", 0.15, 3.2, at(0, 0.9, 0), Palette.water, QUIET)
		b.post("Pillar", 1.6, 0.6, at(0, 1.7, 0), Palette.stone, QUIET)
		b.post("Bowl", 0.4, 2, at(0, 2.6, 0), Palette.stoneLight)
		b.post("BowlWater", 0.1, 1.7, at(0, 2.82, 0), Palette.water, QUIET)
		b.post("Top", 0.7, 0.35, at(0, 3.2, 0), Palette.stone, QUIET)
		b.ball("Finial", 0.45, at(0, 3.65, 0), Palette.stoneLight, QUIET)
		b.ball("Splash", 0.8, at(0, 4, 0), Palette.glass, { shadow = false, transparency = 0.3 })
	end,
	WeepingWillow = function(b)
		b.post("Trunk", 4, 1.1, at(0, 2, 0), Palette.trunk, SOLID)
		b.ball("Crown", 4.2, at(0, 5.2, 0), Palette.leafLight)
		b.ball("Crown", 2.6, at(0.4, 6.6, 0.3), Palette.leaf, QUIET)
		-- the curtain of drooping branches, hanging nearly to the ground all round
		for i = 0, 5 do
			local a = math.rad(i * 60 + 15)
			b.block(
				"Drape",
				Vector3.new(1.6, 3.6, 0.25),
				CFrame.new(math.cos(a) * 1.85, 3.3, math.sin(a) * 1.85) * Kit.yaw(-i * 60 - 15 + 90),
				if i % 2 == 0 then Palette.leaf else Palette.leafLight:Lerp(Palette.lime, 0.2),
				QUIET
			)
		end
	end,
	-- VIP gold fence (Model List §7, P1 with the VIP pass): gilded pickets with ball finials and
	-- a little Neon glint on the middle one. Not in Config/Decor until the VIP pass exists.
	GoldFence = function(b)
		local gold = Palette.coins
		for _, y in { 0.9, 1.9 } do
			b.block("Rail", Vector3.new(4, 0.3, 0.2), at(0, y, 0.15), gold:Lerp(Palette.woodDark, 0.25), QUIET)
		end
		for i, x in { -1.4, 0, 1.4 } do
			b.block("Picket", Vector3.new(0.5, 2.6, 0.25), at(x, 1.3, 0), gold)
			b.ball("Finial", 0.6, at(x, 2.75, 0), if i == 2 then gold:Lerp(Palette.cream, 0.3) else gold, QUIET)
		end
		b.block(
			"Glint",
			Vector3.new(0.15, 0.6, 0.05),
			CFrame.new(0.1, 2.85, -0.31) * CFrame.Angles(0, 0, math.rad(25)),
			Palette.cream,
			{ shadow = false, material = Enum.Material.Neon }
		)
	end,
}

-- Gold Town Record trophies (Config/Trophies): awarded, never sold. Each is a gold statue for
-- its record on a stone plinth with a gold trim band and a cream plaque. 1 x 1 tile.
local GOLD = Palette.coins
local GOLD_DARK = Palette.coins:Lerp(Palette.woodDark, 0.3)
local GOLD_LIGHT = Palette.coins:Lerp(Palette.cream, 0.35)
local TOP = 1.25 -- the plinth's top, where each statue stands

local function plinth(b: Kit.Builder)
	b.block("Plinth", Vector3.new(2.6, 1, 2.6), at(0, 0.5, 0), Palette.stoneLight, SOLID)
	b.block("Trim", Vector3.new(2.8, 0.25, 2.8), at(0, 1.12, 0), GOLD_DARK, QUIET)
	b.block("Plaque", Vector3.new(1.4, 0.45, 0.1), at(0, 0.5, -1.33), Palette.cream, QUIET)
end

local TROPHIES: { [string]: (Kit.Builder) -> () } = {
	-- Order Runner: a clipboard with its clip and two written lines
	Orders = function(b)
		local board = CFrame.new(0, TOP + 1.3, 0) * CFrame.Angles(math.rad(-12), 0, 0)
		b.block("Board", Vector3.new(1.7, 2.4, 0.25), board, GOLD)
		b.block("Clip", Vector3.new(0.8, 0.35, 0.4), board * CFrame.new(0, 1.15, 0), GOLD_DARK, QUIET)
		for i = 1, 2 do
			b.block(
				"Line",
				Vector3.new(1.1, 0.12, 0.05),
				board * CFrame.new(0, 0.5 - i * 0.5, -0.15),
				GOLD_LIGHT,
				QUIET
			)
		end
	end,
	-- Green Thumb: a bound wheat sheaf
	Harvest = function(b)
		for i, lean in { -14, 0, 14 } do
			local stalk = CFrame.new(0, TOP, 0) * CFrame.Angles(0, 0, math.rad(lean)) * CFrame.new(0, 1.2, 0)
			b.block("Stalk", Vector3.new(0.25, 2.4, 0.25), stalk, GOLD)
			b.ball("Head", 0.6, (stalk * CFrame.new(0, 1.35, 0)).Position, if i == 2 then GOLD_LIGHT else GOLD)
		end
		b.post("Band", 0.3, 0.75, at(0, TOP + 0.9, 0), GOLD_DARK, QUIET)
	end,
	-- Busy Workshop: an upright cog
	Goods = function(b)
		local face = CFrame.new(0, TOP + 1.4, 0) * Kit.yaw(90)
		b.cyl("Cog", 0.4, 2, face, GOLD)
		for _, spin in { 0, 45 } do
			b.block("Teeth", Vector3.new(0.35, 2.6, 0.35), face * CFrame.Angles(math.rad(spin), 0, 0), GOLD_DARK)
			b.block("Teeth", Vector3.new(0.35, 0.35, 2.6), face * CFrame.Angles(math.rad(spin), 0, 0), GOLD_DARK)
		end
		b.cyl("Hub", 0.6, 0.7, face, GOLD_LIGHT, QUIET)
	end,
	-- Barnyard Pal: a milk churn with its lid and handles
	Animals = function(b)
		b.post("Churn", 1.7, 1.5, at(0, TOP + 0.85, 0), GOLD)
		b.post("Neck", 0.6, 0.9, at(0, TOP + 2, 0), GOLD)
		b.post("Lid", 0.25, 1.1, at(0, TOP + 2.4, 0), GOLD_DARK, QUIET)
		b.ball("Knob", 0.35, at(0, TOP + 2.65, 0), GOLD_LIGHT, QUIET)
		for _, x in { -0.85, 0.85 } do
			b.block("Handle", Vector3.new(0.2, 0.5, 0.5), at(x, TOP + 1.5, 0), GOLD_DARK, QUIET)
		end
	end,
	-- Coin Jar: a stack of coins with one big coin standing up behind
	Coins = function(b)
		for i = 0, 2 do
			b.post(
				"Stack",
				0.3,
				1.2 - i * 0.05,
				at(-0.4, TOP + 0.15 + i * 0.32, -0.3),
				if i == 1 then GOLD_DARK else GOLD
			)
		end
		local coin = CFrame.new(0.3, TOP + 1.2, 0.3) * Kit.yaw(80)
		b.cyl("Coin", 0.3, 2.2, coin, GOLD)
		b.cyl("Face", 0.34, 1.5, coin, GOLD_LIGHT, QUIET)
	end,
	-- Growing Town: three peg-folk, tallest in the middle
	Population = function(b)
		for i, x in { -0.75, 0, 0.75 } do
			local h = if i == 2 then 1.4 else 1
			b.post("Body", h, 0.6, at(x, TOP + h / 2, if i == 2 then 0.2 else -0.1), GOLD)
			b.ball(
				"Head",
				0.55,
				at(x, TOP + h + 0.3, if i == 2 then 0.2 else -0.1),
				if i == 2 then GOLD_LIGHT else GOLD
			)
		end
	end,
	-- Home Builder: a little gabled house with a chimney and a door
	Houses = function(b)
		b.block("House", Vector3.new(1.8, 1.3, 1.6), at(0, TOP + 0.65, 0), GOLD)
		Kit.gableRoof(b, "Roof", at(0, TOP + 1.3, 0), 2.1, 1.9, 0.9, GOLD_DARK)
		b.block("Chimney", Vector3.new(0.35, 0.7, 0.35), at(0.5, TOP + 2, 0.4), GOLD, QUIET)
		b.block("Door", Vector3.new(0.5, 0.8, 0.08), at(0, TOP + 0.4, -0.82), GOLD_LIGHT, QUIET)
	end,
	-- Factory Row: a sawtooth-roofed mill with a tall chimney
	Factories = function(b)
		b.block("Mill", Vector3.new(2, 1.2, 1.6), at(0, TOP + 0.6, 0), GOLD)
		for _, x in { -0.5, 0.5 } do
			b.wedge("Tooth", Vector3.new(0.95, 0.6, 1.6), CFrame.new(x, TOP + 1.5, 0) * Kit.yaw(90), GOLD_DARK)
		end
		b.post("Chimney", 1.6, 0.4, at(0.75, TOP + 2, 0.5), GOLD)
		b.post("ChimneyCap", 0.2, 0.55, at(0.75, TOP + 2.85, 0.5), GOLD_LIGHT, QUIET)
	end,
	-- Pretty Plot: a tulip in bloom with two leaves
	Decor = function(b)
		b.post("Stem", 2, 0.22, at(0, TOP + 1, 0), GOLD_DARK)
		b.ball("Bloom", 1, at(0, TOP + 2.25, 0), GOLD)
		for _, sx in { -1, 1 } do
			b.block(
				"Petal",
				Vector3.new(0.35, 0.8, 0.5),
				CFrame.new(sx * 0.32, TOP + 2.5, 0) * CFrame.Angles(0, 0, math.rad(-sx * 15)),
				GOLD_LIGHT,
				QUIET
			)
			b.block(
				"Leaf",
				Vector3.new(0.7, 0.18, 0.35),
				CFrame.new(sx * 0.4, TOP + 0.7, 0) * CFrame.Angles(0, 0, math.rad(sx * 30)),
				GOLD,
				QUIET
			)
		end
	end,
	-- Helping Hand: a heart
	Helping = function(b)
		local heart = CFrame.new(0, TOP + 1.3, 0)
		b.block("Point", Vector3.new(1.3, 1.3, 0.6), heart * CFrame.Angles(0, 0, math.rad(45)), GOLD)
		for _, sx in { -1, 1 } do
			b.ball("Lobe", 1.3, (heart * CFrame.new(sx * 0.46, 0.5, 0)).Position, GOLD)
		end
		b.ball("Shine", 0.35, (heart * CFrame.new(-0.5, 0.8, -0.5)).Position, GOLD_LIGHT, QUIET)
	end,
}

for record, statue in TROPHIES do
	BUILDERS["Trophy" .. record] = function(b)
		plinth(b)
		statue(b)
	end
end

function ArtDecor.has(id: string): boolean
	return BUILDERS[id] ~= nil
end

function ArtDecor.isPath(id: string): boolean
	return id == "GravelPath" or id == "BrickPath" or id == "SteppingStones" or id == "FarmLane"
end

-- Builds decoration `id` into `parent`, centred on `origin`.
function ArtDecor.build(id: string, parent: Instance, origin: CFrame)
	local builder = BUILDERS[id]
	if builder then
		builder(Kit.builder(parent, origin, true))
	end
end

return ArtDecor
