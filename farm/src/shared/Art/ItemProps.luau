--!strict
-- A small 3D prop for every Barn item: crops as harvested bundles, animal products, factory
-- goods and building materials (Design/16 Model Catalog §2.3, §3.6). The same prop is the
-- item's UI icon (ArtIcons puts it in a ViewportFrame) and can sit on output tables in the
-- world. Each prop is about 2 studs across, stands on y = 0, faces local -Z and stays within
-- PARTS_MAX parts. Unknown ids get a plain crate with a coloured band.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtItemProps = {}

ArtItemProps.PARTS_MAX = 8
ArtItemProps.SIZE = 2.2 -- studs; every prop fits in a box this wide

local QUIET = { shadow = false }

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function tilt(x: number, y: number, z: number, rx: number, ry: number, rz: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

-- A feed sack with a band in the animal's colour. 4 parts.
local function sack(b: Kit.Builder, band: Color3)
	b.block("Sack", Vector3.new(1.5, 1.6, 1.1), at(0, 0.8, 0), Palette.sack, QUIET)
	b.block("SackTop", Vector3.new(1.1, 0.4, 0.8), at(0, 1.8, 0), Palette.sack, QUIET)
	b.post("Tie", 0.25, 0.9, at(0, 1.62, 0), Palette.woodDark, QUIET)
	b.block("Band", Vector3.new(1.55, 0.45, 1.15), at(0, 0.8, 0), band, QUIET)
end

local BUILDERS: { [string]: (Kit.Builder) -> () } = {
	-- Crops ---------------------------------------------------------------------------------
	Wheat = function(b)
		-- A sheaf: a stalk bundle tied with a band, ears fanned on top
		b.post("Stalks", 1.6, 0.8, at(0, 0.8, 0), Palette.wheat, QUIET)
		b.post("Band", 0.3, 0.9, at(0, 0.9, 0), Palette.woodDark, QUIET)
		for i, angle in { -24, 0, 24 } do
			b.block(
				"Ear",
				Vector3.new(0.45, 0.9, 0.45),
				tilt(math.sin(math.rad(angle)) * 0.5, 1.9 - math.abs(angle) / 120, 0, 0, 0, -angle),
				if i == 2 then Palette.wheatHead else Palette.wheat:Lerp(Palette.wheatHead, 0.5),
				QUIET
			)
		end
	end,
	Corn = function(b)
		b.cyl("Cob", 1.9, 0.85, tilt(0, 0.9, 0, 0, 20, 35), Palette.corn, QUIET)
		b.block("Husk", Vector3.new(1.2, 0.2, 0.7), tilt(-0.55, 0.3, 0.15, 0, 20, 55), Palette.cornLeaf, QUIET)
		b.block("Husk", Vector3.new(1.2, 0.2, 0.7), tilt(-0.35, 0.35, -0.3, 0, -10, 20), Palette.cornLeaf, QUIET)
	end,
	Carrots = function(b)
		for i, x in { -0.4, 0.4 } do
			local lean = if i == 1 then 12 else -12
			b.cyl("Carrot", 1.5, 0.6, tilt(x, 0.75, 0, 0, 0, 90 + lean), Palette.carrot, QUIET)
			b.ball("Tip", 0.35, tilt(x + math.sin(math.rad(lean)) * 0.75, 0.05, 0, 0, 0, 0), Palette.carrot, QUIET)
			b.block(
				"Top",
				Vector3.new(0.25, 0.8, 0.5),
				tilt(x - math.sin(math.rad(lean)) * 0.8, 1.85, 0, 0, 0, lean),
				Palette.carrotTop,
				QUIET
			)
		end
	end,
	Sugarcane = function(b)
		for i, x in { -0.5, 0, 0.5 } do
			local h = 2 - math.abs(x) * 0.6
			b.post(
				"Cane",
				h,
				0.4,
				tilt(x, h / 2, 0, 0, 0, x * 10),
				if i == 2 then Palette.canePlum else Palette.cane,
				QUIET
			)
		end
		b.post("Band", 0.25, 1.5, at(0, 0.7, 0), Palette.woodDark, QUIET)
	end,
	Cotton = function(b)
		b.block("Husk", Vector3.new(1.4, 0.5, 1.0), at(0, 0.25, 0), Palette.cottonHusk, QUIET)
		b.ball("Boll", 1.1, at(-0.35, 0.85, 0), Palette.cotton, QUIET)
		b.ball("Boll", 1.1, at(0.4, 0.8, 0.1), Palette.cotton, QUIET)
		b.ball("Boll", 1.0, at(0, 1.4, -0.05), Palette.cotton, QUIET)
	end,
	Strawberries = function(b)
		for i, p in { Vector3.new(-0.45, 0.5, 0), Vector3.new(0.45, 0.45, 0.1) } do
			local d = if i == 1 then 1 else 0.9
			b.ball("Berry", d, at(p.X, p.Y, p.Z), Palette.roofRed, QUIET)
			b.block(
				"Cap",
				Vector3.new(0.6, 0.15, 0.6),
				tilt(p.X, p.Y + d / 2 - 0.05, p.Z, 0, 45, 0),
				Palette.leafLight,
				QUIET
			)
		end
	end,
	Potatoes = function(b)
		b.ball("Potato", 1.1, at(-0.4, 0.5, 0), Palette.woodLight, QUIET)
		b.ball("Potato", 0.95, at(0.45, 0.45, 0.15), Palette.cork, QUIET)
		b.ball("Potato", 0.85, at(0.05, 1.05, 0.05), Palette.woodLight:Lerp(Palette.cork, 0.5), QUIET)
	end,
	Tomatoes = function(b)
		b.ball("Tomato", 1.5, at(0, 0.75, 0), Palette.roofRed, QUIET)
		b.block("Leaf", Vector3.new(0.9, 0.12, 0.3), tilt(0, 1.48, 0, 0, 0, 0), Palette.leaf, QUIET)
		b.block("Leaf", Vector3.new(0.9, 0.12, 0.3), tilt(0, 1.48, 0, 0, 90, 0), Palette.leaf, QUIET)
		b.post("Stem", 0.3, 0.15, at(0, 1.6, 0), Palette.leaf, QUIET)
	end,
	Pumpkins = function(b)
		-- Three lobes side by side read as a ribbed pumpkin
		local rib = Palette.carrot:Lerp(Palette.bread, 0.4)
		b.ball("Lobe", 1.5, at(-0.5, 0.75, 0.1), rib, QUIET)
		b.ball("Lobe", 1.5, at(0.5, 0.75, 0.1), rib, QUIET)
		b.ball("Pumpkin", 1.6, at(0, 0.8, -0.1), Palette.carrot, QUIET)
		b.post("Stem", 0.5, 0.3, at(0, 1.75, 0), Palette.woodDark, QUIET)
		b.block("Leaf", Vector3.new(0.7, 0.12, 0.45), tilt(0.35, 1.68, 0, 0, 30, -15), Palette.leaf, QUIET)
	end,
	Cocoa = function(b)
		local pod = tilt(0, 0.75, 0, 0, 25, 20)
		b.cyl("Pod", 1, 1, pod, Palette.bread, QUIET)
		b.ball("End", 1, pod * at(0.5, 0, 0), Palette.bread, QUIET)
		b.ball("End", 1, pod * at(-0.5, 0, 0), Palette.brick, QUIET)
		b.post("Stem", 0.4, 0.15, pod * at(1.05, 0, 0) * CFrame.Angles(0, 0, math.rad(-60)), Palette.woodDark, QUIET)
	end,

	-- Animal products -------------------------------------------------------------------------
	Eggs = function(b)
		b.post("Nest", 0.5, 2, at(0, 0.25, 0), Palette.straw, QUIET)
		b.ball("Egg", 0.85, at(-0.35, 0.8, 0), Palette.egg, QUIET)
		b.ball("Egg", 0.8, at(0.4, 0.78, 0.1), Palette.egg, QUIET)
		b.ball("Egg", 0.75, at(0, 0.95, 0.35), Palette.cream, QUIET)
	end,
	Milk = function(b)
		b.post("Bottle", 1.5, 0.9, at(0, 0.75, 0), Palette.milk, QUIET)
		b.post("Neck", 0.4, 0.6, at(0, 1.65, 0), Palette.milk, QUIET)
		b.post("Cap", 0.25, 0.68, at(0, 1.95, 0), Palette.gems:Lerp(Palette.roofTeal, 0.5), QUIET)
		b.block("Label", Vector3.new(0.6, 0.5, 0.1), at(0, 0.8, -0.45), Palette.sky, QUIET)
	end,
	Wool = function(b)
		b.ball("Wool", 1.4, at(-0.25, 0.7, 0), Palette.wool, QUIET)
		b.ball("Wool", 1.1, at(0.45, 0.55, 0.1), Palette.wool, QUIET)
		b.block("Ribbon", Vector3.new(1.5, 0.3, 0.35), tilt(0, 0.85, -0.1, 0, 0, -10), Palette.plum, QUIET)
	end,

	-- Factory goods -----------------------------------------------------------------------------
	Bread = function(b)
		b.cyl("Loaf", 1.8, 1.3, at(0, 0.65, 0), Palette.bread, QUIET)
		for _, x in { -0.9, 0.9 } do
			b.ball("End", 1.3, at(x * 0.75, 0.65, 0), Palette.bread, QUIET)
		end
		for _, x in { -0.5, 0.15, 0.8 } do
			b.block("Slash", Vector3.new(0.5, 0.12, 0.9), tilt(x - 0.15, 1.28, 0, 0, 30, 0), Palette.cream, QUIET)
		end
	end,
	Bagel = function(b)
		for i = 0, 5 do
			local a = i * math.pi / 3
			b.ball("Ring", 0.8, at(math.cos(a) * 0.65, 0.4, math.sin(a) * 0.65), Palette.bread, QUIET)
		end
		b.post("Seeds", 0.1, 0.9, at(0, 0.62, 0), Palette.seed, QUIET)
	end,
	Butter = function(b)
		b.post("Dish", 0.25, 2, at(0, 0.12, 0), Palette.sky, QUIET)
		b.block("Butter", Vector3.new(1.3, 0.75, 0.85), at(0, 0.62, 0), Palette.wheatHead, QUIET)
		b.block("Pat", Vector3.new(0.5, 0.2, 0.4), tilt(0.2, 1.1, 0, 0, 20, 0), Palette.corn, QUIET)
	end,
	Cheese = function(b)
		-- Seen from the front, the wedge's triangle points left; the rind is the tall end
		b.wedge("Wedge", Vector3.new(1, 1.2, 2), tilt(0, 0.6, 0, 0, 90, 0), Palette.roofMustard, QUIET)
		b.block("Rind", Vector3.new(0.2, 1.22, 1.02), at(1, 0.6, 0), Palette.coins, QUIET)
		b.ball("Hole", 0.35, at(0.45, 0.4, -0.45), Palette.bread, QUIET)
		b.ball("Hole", 0.25, at(0.75, 0.85, -0.45), Palette.bread, QUIET)
	end,
	ChickenFeed = function(b)
		sack(b, Palette.henWing)
	end,
	CowFeed = function(b)
		sack(b, Palette.cowPatch)
	end,
	SheepFeed = function(b)
		sack(b, Palette.sky)
	end,
	Cookies = function(b)
		for i = 0, 2 do
			b.cyl(
				"Cookie",
				0.3,
				1.5,
				tilt(i * 0.08, 0.15 + i * 0.32, 0, 0, 0, 90),
				Palette.bread:Lerp(Palette.wheat, 0.3),
				QUIET
			)
		end
		b.ball("Chip", 0.25, at(-0.3, 0.97, -0.2), Palette.cocoa, QUIET)
		b.ball("Chip", 0.25, at(0.3, 0.97, 0.15), Palette.cocoa, QUIET)
	end,
	CottonFabric = function(b)
		b.cyl("Bolt", 2, 1.1, at(0, 0.55, 0), Palette.cream, QUIET)
		for _, x in { -0.55, 0.55 } do
			b.cyl("Stripe", 0.3, 1.14, at(x, 0.55, 0), Palette.sky, QUIET)
		end
		b.block("Tail", Vector3.new(1.4, 0.1, 0.8), at(0, 0.05, -0.75), Palette.cream, QUIET)
	end,
	Cream = function(b)
		b.post("Jar", 1.3, 1.2, at(0, 0.65, 0), Palette.cream, QUIET)
		b.post("Lid", 0.3, 1.3, at(0, 1.45, 0), Palette.sky, QUIET)
		b.ball("Swirl", 0.6, at(0, 1.7, 0), Palette.milk, QUIET)
	end,
	Shirt = function(b)
		b.block("Body", Vector3.new(1.2, 1.5, 0.35), at(0, 0.75, 0), Palette.sky, QUIET)
		b.block("Sleeve", Vector3.new(0.55, 0.6, 0.34), tilt(-0.8, 1.2, 0, 0, 0, 35), Palette.sky, QUIET)
		b.block("Sleeve", Vector3.new(0.55, 0.6, 0.34), tilt(0.8, 1.2, 0, 0, 0, -35), Palette.sky, QUIET)
		b.wedge("Collar", Vector3.new(0.6, 0.3, 0.1), tilt(0, 1.38, -0.2, 0, 0, 180), Palette.cream, QUIET)
		b.block("Pocket", Vector3.new(0.35, 0.3, 0.05), at(0.3, 1, -0.19), Palette.cream, QUIET)
	end,
	Sugar = function(b)
		local cube = Palette.cream:Lerp(Palette.wheat, 0.2)
		b.block("Cube", Vector3.new(0.85, 0.85, 0.85), tilt(-0.45, 0.43, 0, 0, 15, 0), cube, QUIET)
		b.block("Cube", Vector3.new(0.85, 0.85, 0.85), tilt(0.45, 0.43, 0.1, 0, -10, 0), cube, QUIET)
		b.block("Cube", Vector3.new(0.85, 0.85, 0.85), tilt(0, 1.28, 0.05, 0, 30, 0), Palette.cream, QUIET)
	end,
	WoolScarf = function(b)
		local stripe = Palette.cream
		b.block("Fold", Vector3.new(1.8, 0.35, 0.8), at(0, 0.18, 0), Palette.roofRed, QUIET)
		b.block("Fold", Vector3.new(1.6, 0.35, 0.8), tilt(0.1, 0.52, 0, 0, 8, 0), Palette.roofRed, QUIET)
		b.block("Stripe", Vector3.new(0.25, 0.37, 0.82), tilt(-0.35, 0.52, 0, 0, 8, 0), stripe, QUIET)
		b.block("Stripe", Vector3.new(0.25, 0.37, 0.82), tilt(0.45, 0.52, 0, 0, 8, 0), stripe, QUIET)
		b.block("Tail", Vector3.new(0.7, 0.2, 1.2), tilt(-0.7, 0.86, -0.2, 0, -20, 0), Palette.roofRed, QUIET)
		b.block("Fringe", Vector3.new(0.7, 0.12, 0.3), tilt(-0.9, 0.86, -0.85, 0, -20, 0), stripe, QUIET)
	end,
	Popcorn = function(b)
		b.post("Tub", 1.4, 1.3, at(0, 0.7, 0), Palette.roofRed, QUIET)
		b.post("Band", 0.3, 1.34, at(0, 0.9, 0), Palette.cream, QUIET)
		b.ball("Pop", 0.8, at(-0.3, 1.5, 0), Palette.cream, QUIET)
		b.ball("Pop", 0.8, at(0.35, 1.55, 0.15), Palette.cream, QUIET)
		b.ball("Pop", 0.7, at(0, 1.85, -0.2), Palette.cream, QUIET)
	end,
	StrawberryMilkshake = function(b)
		b.post("Glass", 1.5, 0.95, at(0, 0.75, 0), Palette.flowerPink, QUIET)
		b.ball("Cream", 0.95, at(0, 1.6, 0), Palette.cream, QUIET)
		b.ball("Berry", 0.4, at(0.1, 2.05, 0), Palette.roofRed, QUIET)
		b.block("Straw", Vector3.new(0.15, 1.2, 0.15), tilt(-0.3, 1.9, 0, 0, 0, 15), Palette.sky, QUIET)
	end,
	FarmBurger = function(b)
		b.post("BunBottom", 0.4, 1.8, at(0, 0.2, 0), Palette.bread, QUIET)
		b.post("Patty", 0.4, 1.9, at(0, 0.6, 0), Palette.cocoa, QUIET)
		b.block("Cheese", Vector3.new(1.5, 0.12, 1.5), tilt(0, 0.85, 0, 0, 45, 0), Palette.roofMustard, QUIET)
		b.post("Lettuce", 0.15, 2, at(0, 0.95, 0), Palette.leafLight, QUIET)
		b.ball("BunTop", 1.8, at(0, 1.2, 0), Palette.bread, QUIET)
	end,
	Yarn = function(b)
		b.ball("Yarn", 1.5, at(0, 0.75, 0), Palette.plum, QUIET)
		b.cyl("Wrap", 0.25, 1.55, tilt(0, 0.75, 0, 0, 0, 30), Palette.plum:Lerp(Palette.cream, 0.25), QUIET)
		b.block("Strand", Vector3.new(0.9, 0.12, 0.12), tilt(0.75, 0.15, -0.3, 0, 30, 0), Palette.plum, QUIET)
	end,

	-- Building materials -----------------------------------------------------------------------
	Bricks = function(b)
		b.block("Brick", Vector3.new(1.6, 0.6, 0.8), at(-0.2, 0.3, 0), Palette.brick, QUIET)
		b.block(
			"Brick",
			Vector3.new(1.6, 0.6, 0.8),
			tilt(0.25, 0.3, 0.3, 0, 90, 0),
			Palette.brick:Lerp(Palette.roofRed, 0.3),
			QUIET
		)
		b.block("Brick", Vector3.new(1.6, 0.6, 0.8), tilt(0, 0.9, 0.1, 0, 15, 0), Palette.brick, QUIET)
	end,
	Hinges = function(b)
		b.block("Leaf", Vector3.new(0.8, 1.6, 0.12), tilt(-0.4, 0.8, 0, 0, -20, 0), Palette.metal, QUIET)
		b.block("Leaf", Vector3.new(0.8, 1.6, 0.12), tilt(0.4, 0.8, 0, 0, 20, 0), Palette.metal, QUIET)
		b.post("Pin", 1.8, 0.3, at(0, 0.9, -0.12), Palette.stoneDark, QUIET)
	end,
	Nails = function(b)
		for i, x in { -0.5, 0, 0.5 } do
			local lean = (i - 2) * 14
			b.post("Nail", 1.6, 0.18, tilt(x, 0.8, 0, 0, 0, lean), Palette.metal, QUIET)
			b.post("Head", 0.12, 0.45, tilt(x, 0.8, 0, 0, 0, lean) * at(0, 0.8, 0), Palette.stoneDark, QUIET)
		end
	end,
	Paint = function(b)
		b.post("Can", 1.4, 1.3, at(0, 0.7, 0), Palette.metal, QUIET)
		b.post("Paint", 0.2, 1.1, at(0, 1.45, 0), Palette.roofTeal, QUIET)
		b.block("Label", Vector3.new(0.9, 0.7, 0.1), at(0, 0.7, -0.64), Palette.roofTeal, QUIET)
		b.block("Drip", Vector3.new(0.2, 0.6, 0.08), at(-0.35, 1.2, -0.66), Palette.roofTeal, QUIET)
	end,
	Panes = function(b)
		b.block("Frame", Vector3.new(1.6, 1.8, 0.18), at(0, 0.9, 0), Palette.woodLight, QUIET)
		b.block("Glass", Vector3.new(1.3, 1.5, 0.2), at(0, 0.9, 0), Palette.glass, QUIET)
		b.block("Bar", Vector3.new(0.15, 1.5, 0.22), at(0, 0.9, 0), Palette.woodLight, QUIET)
		b.block("Bar", Vector3.new(1.3, 0.15, 0.22), at(0, 0.9, 0), Palette.woodLight, QUIET)
	end,
	Planks = function(b)
		b.block("Plank", Vector3.new(2, 0.35, 0.7), at(0, 0.18, -0.35), Palette.woodLight, QUIET)
		b.block("Plank", Vector3.new(2, 0.35, 0.7), at(0, 0.18, 0.4), Palette.wood, QUIET)
		b.block("Plank", Vector3.new(2, 0.35, 0.7), tilt(0, 0.53, 0, 0, 30, 0), Palette.woodLight, QUIET)
	end,
	-- Tools (Config/Tools: dropped by harvests, spent on land clearing) -----------------------
	Shovel = function(b)
		-- Leaning at 45 degrees: D-grip up and right, blade down and left
		local tool = CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(-45))
		b.cyl("Grip", 0.6, 0.22, tool * at(0, 1, 0), Palette.woodDark, QUIET)
		b.post("Handle", 1.5, 0.2, tool * at(0, 0.25, 0), Palette.wood, QUIET)
		b.post("Collar", 0.25, 0.3, tool * at(0, -0.55, 0), Palette.stoneDark, QUIET)
		b.block("Blade", Vector3.new(0.8, 0.75, 0.12), tool * at(0, -0.95, 0), Palette.metal, QUIET)
		b.block(
			"Tip",
			Vector3.new(0.56, 0.56, 0.11),
			tool * at(0, -1.3, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Palette.metal,
			QUIET
		)
	end,
	Axe = function(b)
		local tool = CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(25))
		b.post("Handle", 2.1, 0.22, tool, Palette.wood, QUIET)
		b.post("Wrap", 0.45, 0.27, tool * at(0, -0.75, 0), Palette.roofRed, QUIET)
		b.block("Head", Vector3.new(0.8, 0.5, 0.3), tool * at(0.25, 0.8, 0), Palette.stoneDark, QUIET)
		b.block("Edge", Vector3.new(0.18, 0.85, 0.28), tool * at(0.7, 0.8, 0), Palette.metal, QUIET)
	end,
	Saw = function(b)
		local tool = CFrame.new(-0.15, 1, 0) * CFrame.Angles(0, 0, math.rad(20))
		b.block("Blade", Vector3.new(2, 0.7, 0.08), tool, Palette.metal, QUIET)
		for i, x in { -0.65, 0, 0.65 } do
			b.block(
				"Tooth",
				Vector3.new(0.28, 0.28, 0.07),
				tool * at(x, -0.35, 0) * CFrame.Angles(0, 0, math.rad(45)),
				if i == 2 then Palette.stoneDark else Palette.metal,
				QUIET
			)
		end
		b.block("Handle", Vector3.new(0.6, 0.8, 0.22), tool * at(1.2, 0.05, 0), Palette.wood, QUIET)
		b.block("Grip", Vector3.new(0.25, 0.45, 0.24), tool * at(1.3, 0.05, 0), Palette.woodDark, QUIET)
	end,
}

local function crate(b: Kit.Builder)
	b.block("Crate", Vector3.new(1.6, 1.4, 1.6), at(0, 0.7, 0), Palette.crate, QUIET)
	b.block("Band", Vector3.new(1.65, 0.35, 1.65), at(0, 0.7, 0), Palette.woodDark, QUIET)
end

function ArtItemProps.has(id: string): boolean
	return BUILDERS[id] ~= nil
end

-- Builds the prop for `id` with its bottom centre at `cf` (front at local -Z). Parts have
-- CanQuery off so taps pass through to whatever the prop sits on.
function ArtItemProps.build(id: string, cf: CFrame?, name: string?): Model
	local model = Kit.model(name or id)
	local b = Kit.builder(model, cf or CFrame.new(), false)
	local builder = BUILDERS[id] or crate
	builder(b)
	return model
end

return ArtItemProps
