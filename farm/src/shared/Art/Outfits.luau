--!strict
-- Wardrobe pieces (Config/Wardrobe), worn on top of the player's own avatar. Each piece is
-- built around the centre of the body part it goes on (the Head or the UpperTorso; R6 uses
-- its Torso), front at local -Z, and gets that part's size so it fits small and big avatars.
-- A few parts each, all weightless and out of the way of clicks and touches.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtOutfits = {}

export type Built = { model: Model, attach: string }

local NO = { shadow = false }
local PUMPKIN = Color3.fromRGB(242, 140, 40)
local PUMPKIN_RIB = Color3.fromRGB(222, 118, 30)
local DENIM = Color3.fromRGB(74, 108, 168)
local DENIM_DARK = Color3.fromRGB(56, 84, 136)
local RIBBON_BLUE = Color3.fromRGB(70, 120, 210)
local SEED = Color3.fromRGB(110, 72, 40)

local UP = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing upright

-- A rosette facing local -Z at `cf`
local function rosette(b: Kit.Builder, cf: CFrame, size: number, color: Color3)
	b.cyl("Rosette", 0.08, size, cf * CFrame.Angles(0, math.rad(90), 0), color, NO)
	b.cyl(
		"RosetteHeart",
		0.1,
		size * 0.45,
		cf * CFrame.new(0, 0, -0.03) * CFrame.Angles(0, math.rad(90), 0),
		Palette.coins,
		NO
	)
	for _, side in { -1, 1 } do
		b.block(
			"Tail",
			Vector3.new(size * 0.2, size * 0.7, 0.05),
			cf * CFrame.new(side * size * 0.15, -size * 0.6, 0.02) * CFrame.Angles(0, 0, math.rad(side * 12)),
			color,
			NO
		)
	end
end

-- Straps from the front of the torso over the shoulders to its back
local function straps(b: Kit.Builder, size: Vector3, color: Color3, fromY: number)
	local front = -size.Z / 2 - 0.03
	local top = size.Y / 2
	for _, x in { -size.X * 0.22, size.X * 0.22 } do
		b.block("Strap", Vector3.new(0.18, top - fromY, 0.06), CFrame.new(x, (top + fromY) / 2, front), color, NO)
		b.block("Strap", Vector3.new(0.18, 0.06, size.Z + 0.12), CFrame.new(x, top + 0.03, 0), color, NO)
	end
end

local PIECES: { [string]: { attach: string, build: (Kit.Builder, Vector3) -> () } } = {
	---------------------------------------------------------------------------------------
	-- Hats (on top of the Head)
	---------------------------------------------------------------------------------------
	StrawHat = {
		attach = "Head",
		build = function(b, size)
			local y = size.Y / 2 - 0.05
			b.cyl("Brim", 0.1, size.X * 2.1, CFrame.new(0, y, 0) * UP, Palette.straw, NO)
			b.cyl("Crown", 0.55, size.X * 1.05, CFrame.new(0, y + 0.28, 0) * UP, Palette.straw, NO)
			b.cyl("Band", 0.14, size.X * 1.08, CFrame.new(0, y + 0.1, 0) * UP, Palette.roofRed, NO)
		end,
	},
	FarmerCap = {
		attach = "Head",
		build = function(b, size)
			local y = size.Y / 2 - 0.1
			b.cyl("Crown", 0.45, size.X * 1.06, CFrame.new(0, y + 0.18, 0) * UP, Palette.barnRed, NO)
			b.block(
				"Bill",
				Vector3.new(size.X * 0.8, 0.08, 0.65),
				CFrame.new(0, y + 0.0, -size.Z / 2 - 0.25),
				Palette.barnRed,
				NO
			)
			b.ball("Button", 0.18, CFrame.new(0, y + 0.42, 0), Palette.cream, NO)
			b.block("Patch", Vector3.new(0.4, 0.25, 0.05), CFrame.new(0, y + 0.2, -size.Z * 0.53), Palette.cream, NO)
		end,
	},
	Sunbonnet = {
		attach = "Head",
		build = function(b, size)
			local y = size.Y / 2 - 0.15
			b.cyl("Crown", 0.5, size.X * 1.1, CFrame.new(0, y + 0.15, 0.1) * UP, Palette.flowerPink, NO)
			b.cyl(
				"Brim",
				0.1,
				size.X * 1.7,
				CFrame.new(0, y - 0.05, -size.Z * 0.35) * CFrame.Angles(math.rad(-70), 0, 0) * UP,
				Palette.flowerPink,
				NO
			)
			b.block("Frill", Vector3.new(size.X * 1.1, 0.12, 0.15), CFrame.new(0, y + 0.42, 0.1), Palette.cream, NO)
			for _, x in { -1, 1 } do
				b.block(
					"Tie",
					Vector3.new(0.1, 0.7, 0.1),
					CFrame.new(x * size.X * 0.45, -size.Y * 0.35, -0.1),
					Palette.cream,
					NO
				)
			end
		end,
	},
	RanchHat = {
		attach = "Head",
		build = function(b, size)
			local y = size.Y / 2 - 0.05
			b.cyl("Brim", 0.1, size.X * 2.2, CFrame.new(0, y, 0) * UP, Palette.woodDark, NO)
			b.cyl("Crown", 0.7, size.X * 1.0, CFrame.new(0, y + 0.37, 0) * UP, Palette.woodDark, NO)
			b.block("Dent", Vector3.new(0.15, 0.1, size.Z * 0.7), CFrame.new(0, y + 0.72, 0), Palette.cocoa, NO)
			b.cyl("Band", 0.14, size.X * 1.03, CFrame.new(0, y + 0.12, 0) * UP, Palette.cream, NO)
		end,
	},
	BeekeeperVeil = {
		attach = "Head",
		build = function(b, size)
			local y = size.Y / 2 - 0.05
			b.cyl("Brim", 0.1, size.X * 2.1, CFrame.new(0, y, 0) * UP, Palette.cream, NO)
			b.cyl("Crown", 0.5, size.X * 1.05, CFrame.new(0, y + 0.25, 0) * UP, Palette.cream, NO)
			b.cyl(
				"Veil",
				size.Y * 1.05,
				size.X * 1.9,
				CFrame.new(0, y - size.Y * 0.53, 0) * UP,
				Palette.cream,
				{ shadow = false, transparency = 0.6 }
			)
		end,
	},
	SunflowerHat = {
		attach = "Head",
		build = function(b, size)
			local y = size.Y / 2 - 0.08
			b.cyl("Cap", 0.35, size.X * 1.06, CFrame.new(0, y + 0.12, 0) * UP, Palette.leaf, NO)
			local top = CFrame.new(0, y + 0.34, 0)
			b.cyl("Seeds", 0.12, size.X * 0.7, top * UP, SEED, NO)
			for i = 0, 7 do
				b.block(
					"Petal",
					Vector3.new(0.3, 0.06, size.X * 0.42),
					top * CFrame.Angles(0, math.rad(i * 45), 0) * CFrame.new(0, 0, -size.X * 0.5),
					Palette.flowerYellow,
					NO
				)
			end
		end,
	},
	PumpkinCap = {
		attach = "Head",
		build = function(b, size)
			local y = size.Y / 2 - 0.05
			b.ball("Pumpkin", size.X * 1.25, CFrame.new(0, y + 0.1, 0), PUMPKIN, NO)
			b.ball("Rib", size.X * 1.05, CFrame.new(-size.X * 0.32, y + 0.08, 0), PUMPKIN_RIB, NO)
			b.ball("Rib", size.X * 1.05, CFrame.new(size.X * 0.32, y + 0.08, 0), PUMPKIN_RIB, NO)
			b.post("Stem", 0.4, 0.22, CFrame.new(0, y + size.X * 0.65 + 0.1, 0), Palette.woodDark, NO)
			b.block(
				"Leaf",
				Vector3.new(0.5, 0.06, 0.3),
				CFrame.new(0.22, y + size.X * 0.62, 0) * CFrame.Angles(0, 0, math.rad(-20)),
				Palette.leaf,
				NO
			)
		end,
	},

	---------------------------------------------------------------------------------------
	-- Neck (round the top of the torso, at the front)
	---------------------------------------------------------------------------------------
	RedBandana = {
		attach = "UpperTorso",
		build = function(b, size)
			local top = size.Y / 2
			b.block(
				"Knot",
				Vector3.new(size.X * 0.55, 0.2, size.Z * 1.06),
				CFrame.new(0, top - 0.08, 0),
				Palette.roofRed,
				NO
			)
			b.block(
				"Point",
				Vector3.new(0.6, 0.6, 0.06),
				CFrame.new(0, top - 0.35, -size.Z / 2 - 0.04) * CFrame.Angles(0, 0, math.rad(45)),
				Palette.roofRed,
				NO
			)
			b.ball("Dot", 0.12, CFrame.new(0.1, top - 0.35, -size.Z / 2 - 0.08), Palette.cream, NO)
		end,
	},
	GinghamScarf = {
		attach = "UpperTorso",
		build = function(b, size)
			local top = size.Y / 2
			b.block(
				"Wrap",
				Vector3.new(size.X * 0.6, 0.28, size.Z * 1.08),
				CFrame.new(0, top - 0.1, 0),
				Palette.roofTeal,
				NO
			)
			b.block(
				"Check",
				Vector3.new(size.X * 0.61, 0.08, size.Z * 1.09),
				CFrame.new(0, top - 0.1, 0),
				Palette.cream,
				NO
			)
			b.block(
				"Tail",
				Vector3.new(0.28, 0.75, 0.06),
				CFrame.new(-0.15, top - 0.55, -size.Z / 2 - 0.04),
				Palette.roofTeal,
				NO
			)
			b.block(
				"Tail",
				Vector3.new(0.28, 0.6, 0.06),
				CFrame.new(0.18, top - 0.5, -size.Z / 2 - 0.06) * CFrame.Angles(0, 0, math.rad(10)),
				Palette.roofTeal,
				NO
			)
		end,
	},
	BlueRosette = {
		attach = "UpperTorso",
		build = function(b, size)
			rosette(b, CFrame.new(-size.X * 0.25, size.Y * 0.2, -size.Z / 2 - 0.05), 0.55, RIBBON_BLUE)
		end,
	},

	---------------------------------------------------------------------------------------
	-- Outfits (on the torso)
	---------------------------------------------------------------------------------------
	DenimOveralls = {
		attach = "UpperTorso",
		build = function(b, size)
			local front = -size.Z / 2 - 0.03
			b.block(
				"Bib",
				Vector3.new(size.X * 0.62, size.Y * 0.55, 0.06),
				CFrame.new(0, -size.Y * 0.2, front),
				DENIM,
				NO
			)
			b.block(
				"Waist",
				Vector3.new(size.X * 1.03, 0.3, size.Z * 1.06),
				CFrame.new(0, -size.Y / 2 + 0.15, 0),
				DENIM_DARK,
				NO
			)
			b.block("Pocket", Vector3.new(0.45, 0.3, 0.04), CFrame.new(0, -size.Y * 0.18, front - 0.03), DENIM_DARK, NO)
			straps(b, size, DENIM, size.Y * 0.07)
			for _, x in { -size.X * 0.22, size.X * 0.22 } do
				b.ball("Button", 0.14, CFrame.new(x, size.Y * 0.05, front - 0.05), Palette.coins, NO)
			end
		end,
	},
	GinghamApron = {
		attach = "UpperTorso",
		build = function(b, size)
			local front = -size.Z / 2 - 0.03
			b.block(
				"Apron",
				Vector3.new(size.X * 0.7, size.Y * 0.95, 0.06),
				CFrame.new(0, -size.Y * 0.35, front),
				Palette.cream,
				NO
			)
			b.block(
				"Stripe",
				Vector3.new(size.X * 0.71, 0.12, 0.07),
				CFrame.new(0, -size.Y * 0.55, front),
				Palette.roofRed,
				NO
			)
			b.block(
				"Stripe",
				Vector3.new(size.X * 0.71, 0.12, 0.07),
				CFrame.new(0, -size.Y * 0.1, front),
				Palette.roofRed,
				NO
			)
			b.block(
				"Pocket",
				Vector3.new(0.5, 0.3, 0.04),
				CFrame.new(0, -size.Y * 0.35, front - 0.04),
				Palette.roofRed,
				NO
			)
			b.block(
				"Tie",
				Vector3.new(size.X * 1.03, 0.15, size.Z * 1.05),
				CFrame.new(0, -size.Y * 0.3, 0),
				Palette.roofRed,
				NO
			)
			straps(b, size, Palette.cream, size.Y * 0.13)
		end,
	},
	RibbonSash = {
		attach = "UpperTorso",
		build = function(b, size)
			b.block(
				"Sash",
				Vector3.new(0.35, size.Y * 1.25, size.Z * 1.08),
				CFrame.Angles(0, 0, math.rad(38)),
				Palette.roofRed,
				NO
			)
			rosette(b, CFrame.new(size.X * 0.25, size.Y * 0.28, -size.Z / 2 - 0.06), 0.5, Palette.coins)
		end,
	},

	---------------------------------------------------------------------------------------
	-- Back (on the back of the torso, with straps)
	---------------------------------------------------------------------------------------
	WillowBasket = {
		attach = "UpperTorso",
		build = function(b, size)
			local back = size.Z / 2 + 0.42
			b.block(
				"Basket",
				Vector3.new(size.X * 0.62, size.Y * 0.75, 0.8),
				CFrame.new(0, -0.05, back),
				Palette.woodLight,
				NO
			)
			b.block("Weave", Vector3.new(size.X * 0.63, 0.1, 0.81), CFrame.new(0, -0.1, back), Palette.wood, NO)
			b.block("Rim", Vector3.new(size.X * 0.66, 0.14, 0.86), CFrame.new(0, size.Y * 0.37, back), Palette.wood, NO)
			b.ball("Apple", 0.35, CFrame.new(-0.2, size.Y * 0.42, back), Palette.roofRed, NO)
			b.block(
				"Bread",
				Vector3.new(0.5, 0.25, 0.3),
				CFrame.new(0.2, size.Y * 0.42, back + 0.1),
				Palette.woodLight,
				NO
			)
			straps(b, size, Palette.wood, -size.Y * 0.2)
		end,
	},
	WateringCan = {
		attach = "UpperTorso",
		build = function(b, size)
			local back = size.Z / 2 + 0.4
			b.post("Can", size.Y * 0.7, 0.75, CFrame.new(-0.15, -0.05, back), Palette.roofTeal, NO)
			b.block(
				"Spout",
				Vector3.new(0.14, 1.0, 0.14),
				CFrame.new(0.35, size.Y * 0.25, back) * CFrame.Angles(0, 0, math.rad(-40)),
				Palette.roofTeal,
				NO
			)
			b.cyl(
				"Rose",
				0.12,
				0.3,
				CFrame.new(0.7, size.Y * 0.5, back) * CFrame.Angles(0, 0, math.rad(50)),
				Palette.metal,
				NO
			)
			b.block("Handle", Vector3.new(0.12, 0.5, 0.12), CFrame.new(-0.6, 0, back), Palette.metal, NO)
			straps(b, size, Palette.woodDark, -size.Y * 0.2)
		end,
	},
	HayPack = {
		attach = "UpperTorso",
		build = function(b, size)
			local back = size.Z / 2 + 0.48
			b.block("Bale", Vector3.new(size.X * 0.8, size.Y * 0.7, 0.9), CFrame.new(0, 0, back), Palette.straw, NO)
			for _, x in { -size.X * 0.2, size.X * 0.2 } do
				b.block("Twine", Vector3.new(0.08, size.Y * 0.71, 0.91), CFrame.new(x, 0, back), Palette.woodDark, NO)
			end
			b.block("Tuft", Vector3.new(0.3, 0.25, 0.2), CFrame.new(0.15, size.Y * 0.38, back), Palette.coins, NO)
			straps(b, size, Palette.woodDark, -size.Y * 0.2)
		end,
	},
}

function ArtOutfits.has(id: string): boolean
	return PIECES[id] ~= nil
end

function ArtOutfits.names(): { string }
	local out = {}
	for id in PIECES do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

-- The body part a piece goes on (R15 name)
function ArtOutfits.attach(id: string): string?
	local spec = PIECES[id]
	return if spec then spec.attach else nil
end

-- A piece built around its body part's centre for a part of `size`, unanchored and
-- weightless, ready to weld
function ArtOutfits.build(id: string, size: Vector3): Built?
	local spec = PIECES[id]
	if spec == nil then
		return nil
	end
	local model = Kit.model("Outfit_" .. id)
	spec.build(Kit.builder(model, CFrame.new(), false), size)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	return { model = model, attach = spec.attach }
end

return ArtOutfits
