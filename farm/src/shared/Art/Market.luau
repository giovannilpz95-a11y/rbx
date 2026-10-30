--!strict
-- The player Market stall (16 Model Catalog §2.8, Model List - Town & Factories §5, P1 for the
-- week-4 Market update): a wheeled cart stall with two big wagon wheels, a striped scalloped
-- awning in the player's chosen color, two shelves of display slots, a chalkboard price board
-- and a hand bell, plus the Featured pennant. All original. Front faces local -Z.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtMarket = {}

ArtMarket.STALL_PARTS_MAX = 30 -- the stall itself; the goods props on the slots are extra
ArtMarket.PENNANT_PARTS_MAX = 2
ArtMarket.SLOTS = 6
ArtMarket.STALL_SIZE = Vector3.new(10, 0, 6) -- footprint: width (X) x depth (Z)

-- The four awning colors from 12 (the player picks one)
ArtMarket.COLORS = {
	Red = Palette.roofRed,
	Teal = Palette.roofTeal,
	Mustard = Palette.roofMustard,
	Plum = Palette.roofPlum,
}

local QUIET = { shadow = false }
local SOLID = { collide = true }
local BED = 2.4 -- top of the cart bed

function ArtMarket.stall(parent: Instance, cf: CFrame, color: string?): (Model, Part)
	local model = Kit.model("MarketStall", parent)
	local b = Kit.builder(model, cf, true)
	b.block("Bed", Vector3.new(8, 1, 4.4), Vector3.new(0, BED - 0.5, 0), Palette.wood, SOLID)
	for _, x in { -4.3, 4.3 } do
		b.cyl("Wheel", 0.5, 3.4, Vector3.new(x, 1.7, 0.4), Palette.woodDark)
		b.cyl("Hub", 0.7, 0.9, Vector3.new(x, 1.7, 0.4), Palette.coins, QUIET)
	end
	b.block(
		"Handle",
		Vector3.new(0.3, 0.3, 2.4),
		CFrame.new(-3.6, 1.5, -2.9) * CFrame.Angles(math.rad(-20), 0, 0),
		Palette.woodDark,
		QUIET
	)
	-- Two stepped shelves along the back
	b.block("Shelf", Vector3.new(7.6, 0.8, 1.4), Vector3.new(0, BED + 0.4, 0.5), Palette.woodLight)
	b.block("Shelf", Vector3.new(7.6, 1.6, 1.3), Vector3.new(0, BED + 0.8, 1.75), Palette.woodLight)

	-- Awning: four posts and four tilted stripes (alternating with cream) with ball scallops
	-- along the front edge
	for _, x in { -3.8, 3.8 } do
		for _, z in { -2, 2 } do
			b.post("AwningPost", 4.4, 0.3, Vector3.new(x, BED + 2.2, z), Palette.cream)
		end
	end
	local tilt = CFrame.Angles(math.rad(-14), 0, 0) -- sloping down to the front
	for i = 1, 4 do
		local stripe = b.block(
			"Awning",
			Vector3.new(2.15, 0.3, 5.2),
			CFrame.new(-3.2 + (i - 1) * 2.13, BED + 4.85, -0.15) * tilt,
			if i % 2 == 1 then Palette.roofRed else Palette.cream
		)
		stripe:SetAttribute("Stripe", i % 2 == 1)
		local scallop = b.ball(
			"Awning",
			1,
			Vector3.new(-3.2 + (i - 1) * 2.13, BED + 4.05, -2.65),
			if i % 2 == 1 then Palette.roofRed else Palette.cream,
			QUIET
		)
		scallop:SetAttribute("Stripe", i % 2 == 1)
	end
	Kit.sproutTag(b, Vector3.new(0, BED + 5.6, 0.5), 1.2, Palette.wood, Palette.lime)

	-- Chalkboard price board hanging off the front, and a hand bell on the corner
	local board = b.block("PriceBoard", Vector3.new(3.2, 1.3, 0.2), Vector3.new(1.6, BED - 0.6, -2.35), Palette.cocoa)
	b.block("BoardFrame", Vector3.new(3.5, 1.6, 0.15), Vector3.new(1.6, BED - 0.6, -2.25), Palette.woodLight, QUIET)
	b.ball("Bell", 0.6, Vector3.new(-3.6, BED + 0.3, -1.6), Palette.coins, QUIET)
	b.block("BellHandle", Vector3.new(0.15, 0.6, 0.15), Vector3.new(-3.6, BED + 0.85, -1.6), Palette.woodDark, QUIET)

	-- Display slots: three on the front shelf, three on the back, for the goods props
	for i = 1, ArtMarket.SLOTS do
		local row = if i <= 3 then 0 else 1
		local x = -2.4 + ((i - 1) % 3) * 2.4
		local y = if row == 0 then BED + 0.8 else BED + 1.6
		local z = if row == 0 then 0.5 else 1.75
		model:SetAttribute("Slot" .. i, cf * CFrame.new(x, y, z))
	end
	ArtMarket.setStallColor(model, color or "Red")
	return model, board
end

-- Repaints the awning stripes in one of COLORS.
function ArtMarket.setStallColor(stall: Model, color: string)
	local c = ArtMarket.COLORS[color] or ArtMarket.COLORS.Red
	for _, d in stall:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Awning" and d:GetAttribute("Stripe") then
			d.Color = c
		end
	end
	stall:SetAttribute("Color", color)
end

-- The Featured pennant clipped to the stall's front post when a listing is featured: a
-- triangular gold flag. "Pennant" carries a HingeCFrame at its clip for waving.
function ArtMarket.pennant(parent: Instance, cf: CFrame): Model
	local model = Kit.model("FeaturedPennant", parent)
	local b = Kit.builder(model, cf, true)
	b.block("Clip", Vector3.new(0.4, 0.5, 0.4), Vector3.new(0, 0, 0), Palette.cocoa, QUIET)
	-- a wedge turned on its side reads as a triangle pointing outward
	local flag = b.wedge(
		"Pennant",
		Vector3.new(0.1, 1.4, 1.6),
		CFrame.new(0, -0.3, -0.95) * CFrame.Angles(0, 0, math.rad(90)),
		Palette.coins,
		QUIET
	)
	flag:SetAttribute("HingeCFrame", cf)
	return model
end

-- Where the stall's display slot `i` (1-SLOTS) is, for placing a goods prop.
function ArtMarket.slot(stall: Model, i: number): CFrame?
	local cf = stall:GetAttribute("Slot" .. i)
	return if typeof(cf) == "CFrame" then cf else nil
end

return ArtMarket
