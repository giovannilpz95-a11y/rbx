--!strict
-- Item props for the Far Isle goods and what's made from them (Features/F02; Config/Isles):
-- the same small-prop rules as Art/ItemProps, which merges these builders into its own. Each
-- stands on y = 0, faces local -Z, fits in a 2.2-stud box and stays within 8 parts.

local Kit = require("./Kit")
local Palette = require("./Palette")

local QUIET = { shadow = false }

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function tilt(x: number, y: number, z: number, rx: number, ry: number, rz: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local PEACH = rgb(250, 170, 110)
local MELON = rgb(70, 150, 70)
local PLUM = rgb(120, 60, 120)
local GRAPE = rgb(110, 70, 150)
local OLIVE = rgb(110, 130, 50)
local KEYLIME = rgb(160, 210, 80)
local BANANA = rgb(250, 215, 80)
local COCONUT = rgb(120, 80, 50)
local PINEAPPLE = rgb(230, 170, 50)
local FISH = rgb(110, 160, 200)
local SHRIMP = rgb(245, 140, 110)
local LOBSTER = rgb(210, 70, 60)
local AVOCADO = rgb(70, 110, 50)
local MANGO = rgb(250, 160, 60)
local ALOE = rgb(110, 170, 120)

-- A little pile of round fruit: three below, one on top, a leaf. 5 parts.
local function pile(color: Color3, size: number, leaf: Color3?): (Kit.Builder) -> ()
	return function(b)
		local r = size / 2
		b.ball("Fruit", size, at(-r * 0.9, r, r * 0.4), color, QUIET)
		b.ball("Fruit", size, at(r * 0.9, r, r * 0.4), color:Lerp(Palette.cream, 0.08), QUIET)
		b.ball("Fruit", size, at(0, r, -r * 0.8), color:Lerp(Palette.cocoa, 0.08), QUIET)
		b.ball("Fruit", size, at(0, r * 2.4, 0), color, QUIET)
		b.block("Leaf", Vector3.new(0.5, 0.08, 0.3), tilt(0.2, r * 3.4, 0, 0, 30, 20), leaf or Palette.leaf, QUIET)
	end
end

-- A jar of jam in the fruit's colour with a cream label and a lid. 3 parts.
local function jar(color: Color3, lid: Color3): (Kit.Builder) -> ()
	return function(b)
		b.post("Jar", 1.2, 1.1, at(0, 0.6, 0), color, QUIET)
		b.post("Label", 0.5, 1.14, at(0, 0.55, 0), Palette.cream, QUIET)
		b.post("Lid", 0.3, 1.2, at(0, 1.35, 0), lid, QUIET)
	end
end

local BUILDERS: { [string]: (Kit.Builder) -> () } = {
	-- Blossom Cay
	Peaches = pile(PEACH, 0.85),
	Watermelons = function(b)
		b.ball("Melon", 1.6, at(0, 0.8, 0), MELON, QUIET)
		b.block("Stripe", Vector3.new(0.18, 1.5, 1.55), at(-0.35, 0.8, 0), MELON:Lerp(Palette.cocoa, 0.3), QUIET)
		b.block("Stripe", Vector3.new(0.18, 1.5, 1.55), at(0.35, 0.8, 0), MELON:Lerp(Palette.cocoa, 0.3), QUIET)
		b.block("Slice", Vector3.new(0.9, 0.5, 0.25), tilt(0.4, 0.3, -0.95, 0, 0, 10), Palette.roofRed, QUIET)
		b.block("Rind", Vector3.new(0.9, 0.12, 0.27), tilt(0.42, 0.06, -0.95, 0, 0, 10), MELON, QUIET)
	end,
	Plums = pile(PLUM, 0.75),
	-- Vineyard Key
	Grapes = function(b)
		for i, p in { { 0, 1.5 }, { -0.3, 1.15 }, { 0.3, 1.15 }, { -0.15, 0.8 }, { 0.15, 0.8 }, { 0, 0.45 } } do
			b.ball("Grape", 0.5, at(p[1], p[2], 0), if i % 2 == 0 then GRAPE else GRAPE:Lerp(Palette.cream, 0.1), QUIET)
		end
		b.block("Stem", Vector3.new(0.12, 0.4, 0.12), at(0, 1.9, 0), Palette.woodDark, QUIET)
		b.block("Leaf", Vector3.new(0.6, 0.08, 0.45), tilt(0.3, 1.85, 0, 0, 20, 25), Palette.leaf, QUIET)
	end,
	Olives = function(b)
		b.post("Bowl", 0.4, 1.6, at(0, 0.2, 0), Palette.woodLight, QUIET)
		b.ball("Olive", 0.45, at(-0.35, 0.55, 0.1), OLIVE, QUIET)
		b.ball("Olive", 0.45, at(0.3, 0.55, 0.2), OLIVE:Lerp(Palette.cocoa, 0.2), QUIET)
		b.ball("Olive", 0.45, at(0, 0.55, -0.3), OLIVE, QUIET)
		b.ball("Olive", 0.45, at(0, 0.85, 0), OLIVE:Lerp(Palette.cream, 0.1), QUIET)
		b.block("Leaf", Vector3.new(0.7, 0.06, 0.2), tilt(0.2, 1.05, 0, 0, 30, 10), Palette.leafLight, QUIET)
	end,
	KeyLimes = pile(KEYLIME, 0.7, Palette.leafLight),
	-- Coconut Atoll
	Bananas = function(b)
		for i, z in { -0.3, 0, 0.3 } do
			b.cyl("Banana", 1.6, 0.4, tilt(0, 0.5 + i * 0.12, z, 0, 0, 70 + i * 6), BANANA, QUIET)
		end
		b.block("Stalk", Vector3.new(0.25, 0.4, 0.25), at(-0.25, 1.2, 0), Palette.woodDark, QUIET)
	end,
	Coconuts = function(b)
		b.ball("Coconut", 1.2, at(-0.3, 0.6, 0.1), COCONUT, QUIET)
		b.ball("Coconut", 1.0, at(0.5, 0.5, -0.1), COCONUT:Lerp(Palette.cocoa, 0.2), QUIET)
		b.ball("Half", 0.9, at(0.1, 0.35, -0.6), Palette.cream, QUIET)
	end,
	Pineapples = function(b)
		b.ball("Body", 1.3, at(0, 0.75, 0), PINEAPPLE, QUIET)
		b.block("Crown", Vector3.new(0.2, 0.8, 0.5), tilt(0, 1.7, 0, 0, 0, 15), Palette.leaf, QUIET)
		b.block("Crown", Vector3.new(0.2, 0.8, 0.5), tilt(0, 1.7, 0, 0, 0, -15), Palette.leafLight, QUIET)
		b.block("Crown", Vector3.new(0.5, 0.9, 0.2), at(0, 1.75, 0), Palette.leaf, QUIET)
	end,
	-- Reef Rock
	Fish = function(b)
		b.ball("Body", 1, at(0, 0.5, 0), FISH, QUIET)
		b.block("Body", Vector3.new(1.3, 0.8, 0.5), at(0.2, 0.5, 0), FISH, QUIET)
		b.wedge("Tail", Vector3.new(0.2, 0.8, 0.6), tilt(1.0, 0.5, 0, 0, 90, 0), FISH:Lerp(Palette.sky, 0.3), QUIET)
		b.ball("Eye", 0.18, at(-0.35, 0.6, -0.42), Palette.eye, QUIET)
	end,
	Shrimp = function(b)
		for i = 0, 3 do
			b.ball("Segment", 0.55 - i * 0.07, at(-0.5 + i * 0.35, 0.35 + math.sin(i) * 0.25, 0), SHRIMP, QUIET)
		end
		b.block("Tail", Vector3.new(0.3, 0.4, 0.5), at(0.85, 0.5, 0), SHRIMP:Lerp(Palette.cream, 0.2), QUIET)
	end,
	Lobsters = function(b)
		b.block("Shell", Vector3.new(1.4, 0.5, 0.6), at(0.1, 0.3, 0), LOBSTER, QUIET)
		b.ball("Head", 0.6, at(-0.6, 0.35, 0), LOBSTER, QUIET)
		b.block(
			"Claw",
			Vector3.new(0.6, 0.3, 0.35),
			tilt(-1.0, 0.3, -0.4, 0, 30, 0),
			LOBSTER:Lerp(Palette.cocoa, 0.15),
			QUIET
		)
		b.block(
			"Claw",
			Vector3.new(0.6, 0.3, 0.35),
			tilt(-1.0, 0.3, 0.4, 0, -30, 0),
			LOBSTER:Lerp(Palette.cocoa, 0.15),
			QUIET
		)
		b.block("Tail", Vector3.new(0.3, 0.2, 0.7), at(0.9, 0.2, 0), LOBSTER, QUIET)
	end,
	-- Cactus Cove
	Avocados = function(b)
		b.ball("Avocado", 1.1, at(-0.4, 0.55, 0.1), AVOCADO, QUIET)
		b.ball("Half", 1.0, at(0.45, 0.4, -0.1), rgb(200, 220, 120), QUIET)
		b.ball("Pit", 0.45, at(0.45, 0.75, -0.3), COCONUT, QUIET)
	end,
	Mangoes = pile(MANGO, 0.85),
	Aloe = function(b)
		b.post("Pot", 0.7, 1, at(0, 0.35, 0), Palette.brick, QUIET)
		for i, angle in { -30, -10, 10, 30 } do
			b.block(
				"Leaf",
				Vector3.new(0.25, 1.4, 0.18),
				tilt(angle / 60, 1.2, (i % 2) * 0.2 - 0.1, 0, 0, -angle),
				ALOE,
				QUIET
			)
		end
	end,
	-- Made from isle goods
	PeachMarmalade = jar(PEACH, Palette.roofTeal),
	WatermelonJam = jar(Palette.roofRed:Lerp(Palette.flowerPink, 0.4), MELON),
	PlumJam = jar(PLUM, Palette.roofMustard),
	GrapeJelly = jar(GRAPE, Palette.cream),
	BananaBread = function(b)
		b.block("Loaf", Vector3.new(1.8, 0.9, 1.1), at(0, 0.45, 0), Palette.bread:Lerp(Palette.cocoa, 0.3), QUIET)
		b.ball("Crust", 1.2, at(0, 0.95, 0), Palette.bread:Lerp(Palette.cocoa, 0.45), QUIET)
		b.cyl("Banana", 1.2, 0.3, tilt(0, 1.55, 0, 0, 0, 80), BANANA, QUIET)
	end,
}

return BUILDERS
