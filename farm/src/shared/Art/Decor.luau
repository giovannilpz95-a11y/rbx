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
}

function ArtDecor.has(id: string): boolean
	return BUILDERS[id] ~= nil
end

function ArtDecor.isPath(id: string): boolean
	return id == "GravelPath" or id == "BrickPath"
end

-- Builds decoration `id` into `parent`, centred on `origin`.
function ArtDecor.build(id: string, parent: Instance, origin: CFrame)
	local builder = BUILDERS[id]
	if builder then
		builder(Kit.builder(parent, origin, true))
	end
end

return ArtDecor
