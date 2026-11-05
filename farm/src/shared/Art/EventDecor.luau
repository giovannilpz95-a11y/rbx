--!strict
-- Event keepsakes (Config/Events keepsakes): decorations earned on an event's prize track or
-- bought in its Event Shop. Same rules as Art/Decor: each fills its footprint centred on the
-- origin (on the ground, front at local -Z) in at most 12 parts. Art/Decor adds these builders
-- to its own, so placing and the decoration tests treat them like any other piece.

local Kit = require("./Kit")
local Palette = require("./Palette")

local QUIET = { shadow = false }
local SOLID = { collide = true }

local RIBBON_BLUE = Color3.fromRGB(70, 120, 210)
local RIBBON_RED = Palette.roofRed
local RIBBON_GOLD = Palette.coins
local PUMPKIN = Color3.fromRGB(242, 140, 40)
local PUMPKIN_RIB = Color3.fromRGB(222, 118, 30)

-- A rosette: a disc with a gold centre and two tails, facing local -Z at `cf`
local function rosette(b: Kit.Builder, cf: CFrame, size: number, color: Color3)
	b.cyl("Rosette", 0.15, size, cf * CFrame.Angles(0, math.rad(90), 0), color, QUIET)
	b.cyl(
		"RosetteHeart",
		0.2,
		size * 0.45,
		cf * CFrame.new(0, 0, -0.05) * CFrame.Angles(0, math.rad(90), 0),
		RIBBON_GOLD,
		QUIET
	)
	b.block(
		"Tail",
		Vector3.new(size * 0.2, size * 0.7, 0.1),
		cf * CFrame.new(-size * 0.15, -size * 0.6, 0.05) * Kit.yaw(0) * CFrame.Angles(0, 0, math.rad(-12)),
		color,
		QUIET
	)
	b.block(
		"Tail",
		Vector3.new(size * 0.2, size * 0.7, 0.1),
		cf * CFrame.new(size * 0.15, -size * 0.6, 0.05) * CFrame.Angles(0, 0, math.rad(12)),
		color,
		QUIET
	)
end

local BUILDERS: { [string]: (Kit.Builder) -> () } = {
	-- Two posts with a string of pennants between them
	RibbonBunting = function(b)
		for _, x in { -1.6, 1.6 } do
			b.post("Post", 3.6, 0.3, CFrame.new(x, 1.8, 0), Palette.woodDark)
		end
		b.block("String", Vector3.new(3.2, 0.08, 0.08), CFrame.new(0, 3.3, 0), Palette.cream, QUIET)
		local colors = { RIBBON_RED, RIBBON_BLUE, RIBBON_GOLD, RIBBON_RED, RIBBON_BLUE }
		for i, color in colors do
			local x = -1.3 + (i - 1) * 0.65
			b.wedge(
				"Pennant",
				Vector3.new(0.08, 0.55, 0.45),
				CFrame.new(x, 2.95, 0) * CFrame.Angles(math.rad(180), math.rad(90), 0),
				color,
				QUIET
			)
		end
	end,

	-- A cloth-covered table with two pies and a rosette on the front
	PrizePieTable = function(b)
		b.block("Table", Vector3.new(3.4, 1.6, 2.2), CFrame.new(0, 0.8, 0), Palette.cream, SOLID)
		b.block("Cloth", Vector3.new(3.5, 0.2, 2.3), CFrame.new(0, 1.65, 0), RIBBON_RED)
		for _, x in { -0.8, 0.8 } do
			b.cyl(
				"Pie",
				0.35,
				1.2,
				CFrame.new(x, 1.95, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Palette.woodLight,
				QUIET
			)
			b.cyl("Crust", 0.1, 0.9, CFrame.new(x, 2.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Palette.wood, QUIET)
		end
		rosette(b, CFrame.new(0, 1.0, -1.16), 0.8, RIBBON_BLUE)
	end,

	-- A giant prize pumpkin on a hay bale with a blue rosette
	PrizePumpkin = function(b)
		b.block("Bale", Vector3.new(3.4, 1, 2.6), CFrame.new(0, 0.5, 0), Palette.straw, SOLID)
		b.ball("Pumpkin", 2.6, CFrame.new(0, 2.2, 0), PUMPKIN)
		b.ball("Rib", 2.2, CFrame.new(-0.8, 2.1, 0), PUMPKIN_RIB, QUIET)
		b.ball("Rib", 2.2, CFrame.new(0.8, 2.1, 0), PUMPKIN_RIB, QUIET)
		b.post("Stem", 0.6, 0.35, CFrame.new(0, 3.6, 0), Palette.woodDark, QUIET)
		rosette(b, CFrame.new(0, 0.6, -1.36), 0.7, RIBBON_BLUE)
	end,

	-- The grand prize: a wooden arch with bunting and a big blue rosette (2 x 1 tiles)
	BlueRibbonArch = function(b)
		for _, x in { -3.4, 3.4 } do
			b.block("Pillar", Vector3.new(0.8, 6, 0.8), CFrame.new(x, 3, 0), Palette.wood, SOLID)
		end
		b.block("Beam", Vector3.new(7.8, 0.8, 1), CFrame.new(0, 6.2, 0), Palette.woodDark)
		b.block("Sign", Vector3.new(4, 1.2, 0.2), CFrame.new(0, 5.2, -0.45), Palette.cream, QUIET)
		b.block("Drape", Vector3.new(6, 0.3, 0.12), CFrame.new(0, 5.65, -0.55), RIBBON_RED, QUIET)
		rosette(b, CFrame.new(0, 6.9, -0.6), 1.6, RIBBON_BLUE)
	end,

	-- A tall post with a striped pennant flag
	FairPennant = function(b)
		b.block("Base", Vector3.new(1.4, 0.4, 1.4), CFrame.new(0, 0.2, 0), Palette.woodDark)
		b.post("Pole", 5, 0.3, CFrame.new(0, 2.7, 0), Palette.cream)
		b.wedge(
			"Flag",
			Vector3.new(0.1, 1.2, 2),
			CFrame.new(0.95, 4.4, 0) * CFrame.Angles(0, math.rad(-90), math.rad(180)),
			RIBBON_BLUE,
			QUIET
		)
		b.wedge(
			"Stripe",
			Vector3.new(0.12, 0.5, 1.2),
			CFrame.new(0.6, 4.65, 0) * CFrame.Angles(0, math.rad(-90), math.rad(180)),
			RIBBON_GOLD,
			QUIET
		)
		b.ball("Knob", 0.45, CFrame.new(0, 5.3, 0), RIBBON_GOLD, QUIET)
	end,

	-- A little stall with a striped awning and jars on the counter
	JamStall = function(b)
		b.block("Counter", Vector3.new(3.4, 1.6, 1.6), CFrame.new(0, 0.8, 0.4), Palette.wood, SOLID)
		for _, x in { -1.55, 1.55 } do
			b.block("Post", Vector3.new(0.25, 3.4, 0.25), CFrame.new(x, 1.7, 1.1), Palette.woodDark)
		end
		for i = 0, 3 do
			local color = if i % 2 == 0 then RIBBON_RED else Palette.cream
			b.block(
				"Awning",
				Vector3.new(0.9, 0.2, 2.2),
				CFrame.new(-1.35 + i * 0.9, 3.45, 0.4) * CFrame.Angles(math.rad(-12), 0, 0),
				color,
				QUIET
			)
		end
		for i, color in { RIBBON_RED, Color3.fromRGB(150, 70, 160), RIBBON_GOLD } do
			b.cyl(
				"Jar",
				0.6,
				0.45,
				CFrame.new(-0.9 + (i - 1) * 0.9, 1.9, 0.1) * CFrame.Angles(0, 0, math.rad(90)),
				color,
				QUIET
			)
		end
	end,

	-- A scarecrow in a straw hat with a prize rosette
	RibbonScarecrow = function(b)
		b.post("Pole", 4, 0.3, CFrame.new(0, 2, 0), Palette.woodDark)
		b.block("Arms", Vector3.new(3, 0.3, 0.3), CFrame.new(0, 2.8, 0), Palette.woodDark)
		b.block("Shirt", Vector3.new(1.4, 1.5, 0.7), CFrame.new(0, 2.5, 0), RIBBON_BLUE)
		b.ball("Head", 1, CFrame.new(0, 3.75, 0), Palette.straw)
		b.cyl("Brim", 0.12, 1.8, CFrame.new(0, 4.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Palette.straw, QUIET)
		b.cyl("Crown", 0.5, 0.9, CFrame.new(0, 4.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Palette.straw, QUIET)
		rosette(b, CFrame.new(0.35, 2.75, -0.4), 0.5, RIBBON_RED)
	end,

	-- A hay ride wagon with bales (2 x 1 tiles)
	HayWagon = function(b)
		b.block("Bed", Vector3.new(6.4, 0.6, 3), CFrame.new(0, 1.4, 0), Palette.wood, SOLID)
		for _, x in { -2.2, 2.2 } do
			for _, z in { -1.6, 1.6 } do
				b.cyl("Wheel", 0.3, 1.8, CFrame.new(x, 0.9, z) * Kit.yaw(90), Palette.woodDark)
			end
		end
		b.block("Bale", Vector3.new(2.2, 1.1, 2.4), CFrame.new(-1.6, 2.25, 0), Palette.straw)
		b.block("Bale", Vector3.new(2.2, 1.1, 2.4), CFrame.new(1.2, 2.25, 0), Palette.straw)
		b.block("Bale", Vector3.new(2, 1, 2.2), CFrame.new(-0.2, 3.3, 0), Palette.straw)
		b.block("Tongue", Vector3.new(1.6, 0.25, 0.3), CFrame.new(-3.9, 1.2, 0), Palette.woodDark, QUIET)
	end,
}

-- County Fair Blue Ribbon cups (Config/Fair cups): a gold cup on a plinth with a blue rosette,
-- and what the cup is for on top
local function cup(b: Kit.Builder, topper: (Kit.Builder) -> ())
	b.block("Plinth", Vector3.new(2.4, 1.2, 2.4), CFrame.new(0, 0.6, 0), Palette.stone, SOLID)
	b.cyl("Foot", 0.3, 1.4, CFrame.new(0, 1.35, 0) * CFrame.Angles(0, 0, math.rad(90)), RIBBON_GOLD)
	b.post("Stem", 0.8, 0.35, CFrame.new(0, 1.9, 0), RIBBON_GOLD, QUIET)
	b.cyl("Bowl", 1.1, 1.5, CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(90)), RIBBON_GOLD)
	for _, x in { -0.95, 0.95 } do
		b.block("Handle", Vector3.new(0.25, 0.8, 0.25), CFrame.new(x, 2.85, 0), RIBBON_GOLD, QUIET)
	end
	rosette(b, CFrame.new(0, 0.7, -1.26), 0.7, RIBBON_BLUE)
	topper(b)
end

BUILDERS.ProduceCup = function(b)
	cup(b, function(t)
		t.ball("Pumpkin", 0.8, CFrame.new(0, 3.7, 0), PUMPKIN, QUIET)
	end)
end

BUILDERS.BakersCup = function(b)
	cup(b, function(t)
		t.cyl("Pie", 0.3, 1, CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Palette.woodLight, QUIET)
	end)
end

return table.freeze(BUILDERS)
