--!strict
-- Houses for the town (Design/16 Model Catalog §2.9, Design/07 Town Building). One builder per
-- house type id. Every House has a loaf-arch door, a plinth, flower boxes, a chimney and a
-- Sprout Tag, and comes in the three roof tints for free. Built for a square lot (10 studs by
-- default) with the front door at local -Z. Budget ≤ 40 parts.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtHouses = {}

ArtHouses.PARTS_MAX = 40
ArtHouses.ROOF_TINTS = { Palette.roofRed, Palette.roofTeal, Palette.roofMustard }

export type Options = {
	size: number?, -- lot width and depth in studs (default 10)
	roof: Color3?, -- roof tint (default: the type's own)
}

local PLINTH = 0.6
local STORY = 6.5

local function flowerBox(b: Kit.Builder, at: CFrame, w: number)
	b.block("FlowerBox", Vector3.new(w, 0.6, 0.7), at * CFrame.new(0, 0, -0.35), Palette.woodDark, { shadow = false })
	b.block(
		"Flowers",
		Vector3.new(w - 0.3, 0.5, 0.5),
		at * CFrame.new(0, 0.5, -0.4),
		Palette.flowerPink,
		{ shadow = false }
	)
end

-- Plinth plus walls; returns the wall block (the house's tap target).
local function walls(b: Kit.Builder, w: number, d: number, h: number, color: Color3, x: number?, z: number?): Part
	local ox, oz = x or 0, z or 0
	b.block("Plinth", Vector3.new(w + 0.5, PLINTH, d + 0.5), Vector3.new(ox, PLINTH / 2, oz), Palette.stone)
	return b.block("Body", Vector3.new(w, h, d), Vector3.new(ox, PLINTH + h / 2, oz), color, { collide = true })
end

local function chimney(b: Kit.Builder, at: Vector3, h: number, color: Color3)
	b.block(
		"Chimney",
		Vector3.new(1.4, h, 1.4),
		CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(3)),
		color
	)
	b.block(
		"ChimneyCap",
		Vector3.new(1.8, 0.4, 1.8),
		at + Vector3.new(0.1, h, 0),
		Palette.stoneDark,
		{ shadow = false }
	)
end

local function front(d: number): number
	return -d / 2
end

type Build = (b: Kit.Builder, s: number, roof: Color3) -> BasePart

local TYPES: { [string]: { build: Build, roof: Color3 } } = {}

-- Lean-To: a little plank shack with a single sloping roof. The cheapest first House.
TYPES.LeanTo = {
	roof = Palette.roofTeal,
	build = function(b, s, roof)
		local w, d, h = s * 0.8, s * 0.7, 5
		local body = walls(b, w, d, h, Palette.woodLight, 0, 0.5)
		local t = b.into(body, true)
		t.wedge("Roof", Vector3.new(w + 1.2, 2.4, d + 1.4), Vector3.new(0, PLINTH + h + 1.2, 0.5), roof)
		Kit.door(t, "Door", CFrame.new(-1.2, PLINTH, front(d) + 0.5), 2.2, 4, Palette.woodDark, Palette.cream)
		Kit.window(t, "Window", CFrame.new(1.8, PLINTH + 2.8, front(d) + 0.5), 1.6, 1.6, Palette.cream, Palette.glass)
		flowerBox(t, CFrame.new(1.8, PLINTH + 1.6, front(d) + 0.5), 2.2)
		t.block("Barrel", Vector3.new(1.3, 1.6, 1.3), Vector3.new(w / 2 + 0.3, 0.8, -1), Palette.wood)
		Kit.sproutTag(t, Vector3.new(0, PLINTH + h + 2.2, 2), 1.6, Palette.wood, Palette.lime)
		return body
	end,
}

-- Cottage: one story under a steep red gable, a round stone chimney and flower boxes under two
-- loaf windows.
TYPES.Cottage = {
	roof = Palette.roofRed,
	build = function(b, s, roof)
		local w, d, h = s * 0.85, s * 0.8, STORY
		local body = walls(b, w, d, h, Palette.oat)
		local t = b.into(body, true)
		Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1.4, d + 1.6, 5, roof, Palette.cream)
		t.post("Chimney", 4, 1.6, Vector3.new(w / 2 - 1.5, PLINTH + h + 3, 1.6), Palette.stone)
		t.post(
			"ChimneyCap",
			0.5,
			2,
			Vector3.new(w / 2 - 1.5, PLINTH + h + 5.1, 1.6),
			Palette.stoneDark,
			{ shadow = false }
		)
		Kit.door(
			t,
			"Door",
			CFrame.new(0, PLINTH, front(d)),
			2.4,
			4.4,
			Palette.roofRed:Lerp(Palette.cocoa, 0.25),
			Palette.cream
		)
		for _, x in { -1, 1 } do
			local at = CFrame.new(x * (w / 2 - 1.6), PLINTH + 3.2, front(d))
			Kit.window(t, "Window", at, 1.6, 1.8, Palette.cream, Palette.glass, true)
			flowerBox(t, at * CFrame.new(0, -1.5, 0), 2.2)
		end
		Kit.sproutTag(t, Vector3.new(-w / 4, PLINTH + h + 5.3, 0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Bungalow: wide and low under a shallow mustard roof, with a deep front porch and two chairs.
TYPES.Bungalow = {
	roof = Palette.roofMustard,
	build = function(b, s, roof)
		local w, d, h = s * 0.95, s * 0.65, 5.5
		local z = s * 0.15
		local body = walls(b, w, d, h, Palette.cream:Lerp(Palette.sky, 0.25), 0, z)
		local t = b.into(body, true)
		Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, z - 0.6), w + 1.4, d + 3.4, 3, roof, Palette.cream)
		local porchZ = front(d) + z
		t.block("Porch", Vector3.new(w, 0.5, 2.6), Vector3.new(0, 0.55, porchZ - 1.3), Palette.woodLight)
		for _, x in { -1, 1 } do
			t.block(
				"PorchPost",
				Vector3.new(0.5, h - 0.4, 0.5),
				Vector3.new(x * (w / 2 - 0.4), 0.8 + (h - 0.4) / 2, porchZ - 2.3),
				Palette.cream
			)
			t.block("Chair", Vector3.new(1, 1.2, 1), Vector3.new(x * 2.4, 1.4, porchZ - 1.2), Palette.wood)
		end
		Kit.door(t, "Door", CFrame.new(0, PLINTH, porchZ), 2.4, 4.2, Palette.roofTeal, Palette.cream)
		for _, x in { -1, 1 } do
			Kit.window(
				t,
				"Window",
				CFrame.new(x * (w / 2 - 1.5), PLINTH + 2.8, porchZ),
				1.8,
				1.8,
				Palette.cream,
				Palette.glass
			)
		end
		chimney(t, Vector3.new(-w / 2 + 1.2, PLINTH + h + 0.5, z + 1), 3, Palette.brick)
		Kit.sproutTag(t, Vector3.new(w / 4, PLINTH + h + 3.3, z - 0.6), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Row House: two narrow two-story units joined, each with its own door color, under a stepped
-- pair of gables.
TYPES.RowHouse = {
	roof = Palette.roofTeal,
	build = function(b, s, roof)
		local w, d, h = s * 0.9, s * 0.75, STORY * 2
		local body = walls(b, w, d, h, Palette.oat)
		local t = b.into(body, true)
		local half = w / 2
		for i, x in { -half / 2, half / 2 } do
			local tint = if i == 1 then roof else roof:Lerp(Palette.cream, 0.2)
			Kit.gableRoof(
				t,
				"Roof",
				CFrame.new(x, PLINTH + h + (i - 1) * 0.8, 0) * Kit.yaw(90),
				d + 1.4,
				half + 0.6,
				3.6,
				tint,
				Palette.cream
			)
			local doorColor = if i == 1 then Palette.roofRed else Palette.plum
			Kit.door(t, "Door", CFrame.new(x, PLINTH, front(d)), 2, 4, doorColor, Palette.cream)
			Kit.window(
				t,
				"Window",
				CFrame.new(x, PLINTH + STORY + 2.8, front(d)),
				1.8,
				2.2,
				Palette.cream,
				Palette.glass,
				true
			)
			flowerBox(t, CFrame.new(x, PLINTH + STORY + 1.3, front(d)), 2.4)
		end
		t.block(
			"Divider",
			Vector3.new(0.4, h, d + 0.2),
			Vector3.new(0, PLINTH + h / 2, 0),
			Palette.cream,
			{ shadow = false }
		)
		chimney(t, Vector3.new(half / 2, PLINTH + h + 2.2, d / 4), 3, Palette.brick)
		Kit.sproutTag(t, Vector3.new(half / 2, PLINTH + h + 4.4, 0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Farmhouse: an L-shaped two-story house with a wraparound porch, a big stone chimney and a
-- weathervane.
TYPES.Farmhouse = {
	roof = Palette.roofRed,
	build = function(b, s, roof)
		local w, d, h = s * 0.6, s * 0.85, STORY * 1.7
		local x0 = -s * 0.18
		local body = walls(b, w, d, h, Palette.cream:Lerp(Palette.wheat, 0.15), x0, 0)
		local t = b.into(body, true)
		Kit.gableRoof(
			t,
			"Roof",
			CFrame.new(x0, PLINTH + h, 0) * Kit.yaw(90),
			d + 1.2,
			w + 1.2,
			4.2,
			roof,
			Palette.cream
		)
		-- The short wing of the L
		local ww, wd, wh = s * 0.42, s * 0.5, STORY
		local wx, wz = s * 0.27, s * 0.17
		t.block(
			"Wing",
			Vector3.new(ww, wh, wd),
			Vector3.new(wx, PLINTH + wh / 2, wz),
			Palette.cream:Lerp(Palette.wheat, 0.15),
			{ collide = true }
		)
		Kit.gableRoof(t, "WingRoof", Vector3.new(wx + 0.3, PLINTH + wh, wz), ww + 1, wd + 1.2, 3, roof, Palette.cream)
		t.block("Porch", Vector3.new(s * 0.95, 0.4, 2.2), Vector3.new(0, 0.5, front(d) - 0.9), Palette.woodLight)
		t.block(
			"PorchRoof",
			Vector3.new(s * 0.62, 0.4, 2.6),
			CFrame.new(x0, PLINTH + 5, front(d) - 1.1) * CFrame.Angles(math.rad(-12), 0, 0),
			roof
		)
		for _, x in { x0 - w / 2 + 0.4, x0 + w / 2 - 0.4 } do
			t.block("PorchPost", Vector3.new(0.4, 4.6, 0.4), Vector3.new(x, 2.9, front(d) - 2), Palette.cream)
		end
		Kit.door(t, "Door", CFrame.new(x0, PLINTH, front(d)), 2.2, 4.2, Palette.roofTeal, Palette.cream)
		Kit.window(
			t,
			"Window",
			CFrame.new(x0, PLINTH + STORY + 2.2, front(d)),
			1.8,
			2,
			Palette.cream,
			Palette.glass,
			true
		)
		Kit.window(t, "Window", CFrame.new(wx, PLINTH + 3, wz - wd / 2), 1.8, 1.8, Palette.cream, Palette.glass)
		t.block(
			"Chimney",
			Vector3.new(1.8, h + 3, 1.8),
			Vector3.new(x0 - w / 2 - 0.4, PLINTH + (h + 3) / 2, d / 4),
			Palette.stone
		)
		t.block(
			"Vane",
			Vector3.new(0.15, 1.8, 0.15),
			Vector3.new(x0, PLINTH + h + 5, d / 3),
			Palette.cocoa,
			{ shadow = false }
		)
		t.block(
			"VaneArrow",
			Vector3.new(1.6, 0.4, 0.15),
			Vector3.new(x0, PLINTH + h + 5.6, d / 3),
			Palette.coins:Lerp(Palette.wood, 0.4),
			{ shadow = false }
		)
		Kit.sproutTag(t, Vector3.new(x0, PLINTH + h + 4.2, -d / 5), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Duplex: a mirror-twin house, left half teal and right half mustard, sharing one chimney and
-- a front step.
TYPES.Duplex = {
	roof = Palette.roofTeal,
	build = function(b, s, roof)
		local w, d, h = s * 0.92, s * 0.75, STORY * 1.6
		local body = walls(b, w, d, h, Palette.oat)
		local t = b.into(body, true)
		local half = w / 2
		local tints = { roof, if roof == Palette.roofMustard then Palette.roofTeal else Palette.roofMustard }
		for i, x in { -half / 2, half / 2 } do
			Kit.gableRoof(
				t,
				"Roof",
				CFrame.new(x, PLINTH + h, 0) * Kit.yaw(90),
				d + 1.4,
				half + 0.4,
				3.6,
				tints[i],
				Palette.cream
			)
			local inner = if i == 1 then 1 else -1
			Kit.door(t, "Door", CFrame.new(x + inner * 1, PLINTH, front(d)), 2, 4, tints[i], Palette.cream)
			Kit.window(
				t,
				"Window",
				CFrame.new(x - inner * 1.2, PLINTH + 2.6, front(d)),
				1.4,
				1.6,
				Palette.cream,
				Palette.glass
			)
			Kit.window(
				t,
				"Window",
				CFrame.new(x, PLINTH + STORY + 1.8, front(d)),
				1.8,
				1.8,
				Palette.cream,
				Palette.glass,
				true
			)
		end
		t.block("Step", Vector3.new(4.6, 0.4, 1.4), Vector3.new(0, 0.2, front(d) - 0.7), Palette.stone)
		chimney(t, Vector3.new(0, PLINTH + h + 2, 0), 3.2, Palette.brick)
		Kit.sproutTag(t, Vector3.new(0, PLINTH + h + 5.6, 0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Townhouse: three stories of painted brick, a bay window and a roof terrace with planters and
-- a little umbrella.
TYPES.Townhouse = {
	roof = Palette.roofRed,
	build = function(b, s, roof)
		local w, d, h = s * 0.8, s * 0.8, STORY * 2.6
		local body = walls(b, w, d, h, Palette.brick)
		local t = b.into(body, true)
		t.block("Cornice", Vector3.new(w + 0.8, 0.6, d + 0.8), Vector3.new(0, PLINTH + h + 0.3, 0), Palette.cream)
		for _, x in { -1, 1 } do
			t.block(
				"Parapet",
				Vector3.new(0.5, 1, d),
				Vector3.new(x * (w / 2 - 0.25), PLINTH + h + 1.1, 0),
				Palette.cream,
				{ shadow = false }
			)
		end
		t.block(
			"Planter",
			Vector3.new(w - 1.4, 0.8, 0.8),
			Vector3.new(0, PLINTH + h + 1, d / 2 - 0.8),
			Palette.woodDark
		)
		t.block(
			"Plants",
			Vector3.new(w - 1.6, 0.7, 0.6),
			Vector3.new(0, PLINTH + h + 1.7, d / 2 - 0.8),
			Palette.treeTop,
			{ shadow = false }
		)
		t.block(
			"UmbrellaPole",
			Vector3.new(0.2, 3, 0.2),
			Vector3.new(-1, PLINTH + h + 2.1, 0),
			Palette.cream,
			{ shadow = false }
		)
		t.post("Umbrella", 0.5, 3.6, Vector3.new(-1, PLINTH + h + 3.6, 0), roof)
		t.block("Bay", Vector3.new(3.2, 3, 1.2), Vector3.new(1.2, PLINTH + STORY + 1.6, front(d) - 0.6), Palette.cream)
		t.block(
			"BayGlass",
			Vector3.new(2.6, 2.2, 0.2),
			Vector3.new(1.2, PLINTH + STORY + 1.6, front(d) - 1.25),
			Palette.glass,
			{ shadow = false }
		)
		t.block(
			"BayRoof",
			Vector3.new(3.6, 0.4, 1.6),
			Vector3.new(1.2, PLINTH + STORY + 3.3, front(d) - 0.6),
			roof,
			{ shadow = false }
		)
		Kit.door(t, "Door", CFrame.new(-1.8, PLINTH, front(d)), 2, 4.2, Palette.roofTeal, Palette.cream)
		Kit.window(t, "Window", CFrame.new(1.6, PLINTH + 2.6, front(d)), 1.8, 1.8, Palette.cream, Palette.glass)
		Kit.window(
			t,
			"Window",
			CFrame.new(-1.8, PLINTH + STORY + 1.6, front(d)),
			1.6,
			2,
			Palette.cream,
			Palette.glass,
			true
		)
		Kit.window(
			t,
			"Window",
			CFrame.new(-1.8, PLINTH + STORY * 2 + 1.2, front(d)),
			1.6,
			2,
			Palette.cream,
			Palette.glass,
			true
		)
		Kit.window(
			t,
			"Window",
			CFrame.new(1.6, PLINTH + STORY * 2 + 1.2, front(d)),
			1.6,
			2,
			Palette.cream,
			Palette.glass,
			true
		)
		Kit.sproutTag(t, Vector3.new(w / 2 - 1, PLINTH + h + 0.6, d / 2 - 1.6), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Garden Villa (content bank, level 14): a wide two-story stone villa under a hipped-look
-- double gable, with a glass garden room on one side and a round topiary by the door.
TYPES.GardenVilla = {
	roof = Palette.roofMustard,
	build = function(b, s, roof)
		local w, d, h = s * 0.62, s * 0.75, STORY * 2 - 1
		local body = walls(b, w, d, h, Palette.stoneLight, -s * 0.12)
		local t = b.into(body, true)
		local x0 = -s * 0.12
		t.block("Band", Vector3.new(w + 0.3, 0.4, d + 0.3), Vector3.new(x0, PLINTH + STORY - 0.4, 0), Palette.cream)
		Kit.gableRoof(t, "Roof", Vector3.new(x0, PLINTH + h, 0), w + 1.4, d + 1.4, 3.6, roof, Palette.cream)
		t.post("Chimney", 3.4, 1.4, Vector3.new(x0 - w / 2 + 1.2, PLINTH + h + 2.2, 1.4), Palette.brick)
		-- Garden room: a low glass box with a cream frame and a flat roof
		local gx = x0 + w / 2 + s * 0.14
		t.block("GardenFloor", Vector3.new(s * 0.26, 0.6, d * 0.7), Vector3.new(gx, 0.3, 0.6), Palette.stone)
		t.block(
			"GardenGlass",
			Vector3.new(s * 0.24, 3.6, d * 0.66),
			Vector3.new(gx, 2.4, 0.6),
			Palette.glass,
			{ shadow = false }
		)
		t.block("GardenRoof", Vector3.new(s * 0.28, 0.4, d * 0.72), Vector3.new(gx, 4.4, 0.6), Palette.cream)
		Kit.bush(t, "Plant", Vector3.new(gx, 0.6, 0.6), 0.7, Palette.leaf, Palette.flowerPink)
		Kit.door(t, "Door", CFrame.new(x0, PLINTH, front(d)), 2.2, 4.4, Palette.roofTeal, Palette.cream)
		for _, x in { -1, 1 } do
			Kit.window(
				t,
				"Window",
				CFrame.new(x0 + x * (w / 2 - 1.3), PLINTH + STORY + 2, front(d)),
				1.5,
				2,
				Palette.cream,
				Palette.glass,
				true
			)
		end
		flowerBox(t, CFrame.new(x0, PLINTH + STORY + 0.4, front(d)), 2.6)
		t.ball("Topiary", 1.8, Vector3.new(x0 - 2.4, 1.6, front(d) - 1.2), Palette.treeTop)
		t.post("TopiaryPot", 0.8, 1.2, Vector3.new(x0 - 2.4, 0.4, front(d) - 1.2), Palette.brick)
		Kit.sproutTag(t, Vector3.new(x0 + w / 4, PLINTH + h + 3.4, 0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

ArtHouses.TYPES = {} :: { string }
for id in TYPES do
	table.insert(ArtHouses.TYPES, id)
end
table.sort(ArtHouses.TYPES)

function ArtHouses.has(id: string): boolean
	return TYPES[id] ~= nil
end

-- Build House `id` into `parent` at `cf` (lot centre on the ground, door at local -Z).
-- Returns the wall block, which the caller can use as the tap target.
function ArtHouses.build(id: string, parent: Instance, cf: CFrame, options: Options?): BasePart
	local def = TYPES[id] or TYPES.Cottage
	local size = if options and options.size then options.size else 10
	local roof = if options and options.roof then options.roof else def.roof
	return def.build(Kit.builder(parent, cf, true), size, roof)
end

return ArtHouses
