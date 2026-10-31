--!strict
-- Houses for the town (Design/16 Model Catalog §2.9, Design/07 Town Building). One builder per
-- house type id. Every House has a loaf-arch door, a plinth and a Sprout Tag, and comes in the three roof tints for free. Built for a square lot (10 studs by
-- default) with the front door at local -Z. Budget ≤ 18 parts (16 for one-family houses), since
-- a plot holds dozens of House copies.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtHouses = {}

ArtHouses.PARTS_MAX = 18 -- every copy counts against the plot budget (2,500)
ArtHouses.ROOF_TINTS = { Palette.roofRed, Palette.roofTeal, Palette.roofMustard }

export type Options = {
	size: number?, -- lot width and depth in studs (default 10)
	roof: Color3?, -- roof tint (default: the type's own)
}

local PLINTH = 0.6
local STORY = 6.5

local function flowerBox(b: Kit.Builder, at: CFrame, w: number)
	b.block("Flowers", Vector3.new(w, 0.6, 0.6), at * CFrame.new(0, 0.2, -0.35), Palette.flowerPink, { shadow = false })
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
		Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1.4, d + 1.6, 5, roof)
		t.post("Chimney", 4, 1.6, Vector3.new(w / 2 - 1.5, PLINTH + h + 3, 1.6), Palette.stone)
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
			Kit.window(t, "Window", at, 1.6, 1.8, Palette.cream, Palette.glass)
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
		Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, z - 0.6), w + 1.4, d + 3.4, 3, roof)
		local porchZ = front(d) + z
		t.block("Porch", Vector3.new(w, 0.5, 2.6), Vector3.new(0, 0.55, porchZ - 1.3), Palette.woodLight)
		for _, x in { -1, 1 } do
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
				tint
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
				Palette.glass
			)
		end
		Kit.sproutTag(t, Vector3.new(half / 2, PLINTH + h + 4.4, 0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Farmhouse: an L-shaped two-story house with a porch roof over the door, a lean-to wing, a
-- big stone chimney and a weathervane arrow on the ridge.
TYPES.Farmhouse = {
	roof = Palette.roofRed,
	build = function(b, s, roof)
		local w, d, h = s * 0.6, s * 0.85, STORY * 1.7
		local x0 = -s * 0.18
		local body = walls(b, w, d, h, Palette.cream:Lerp(Palette.wheat, 0.15), x0, 0)
		local t = b.into(body, true)
		Kit.gableRoof(t, "Roof", CFrame.new(x0, PLINTH + h, 0) * Kit.yaw(90), d + 1.2, w + 1.2, 4.2, roof)
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
		t.wedge("WingRoof", Vector3.new(ww + 1, 2.6, wd + 1.2), Vector3.new(wx + 0.3, PLINTH + wh + 1.3, wz), roof)
		t.block(
			"PorchRoof",
			Vector3.new(s * 0.62, 0.4, 2.6),
			CFrame.new(x0, PLINTH + 5, front(d) - 1.1) * CFrame.Angles(math.rad(-12), 0, 0),
			roof
		)
		Kit.door(t, "Door", CFrame.new(x0, PLINTH, front(d)), 2.2, 4.2, Palette.roofTeal, Palette.cream)
		Kit.window(t, "Window", CFrame.new(x0, PLINTH + STORY + 2.2, front(d)), 1.8, 2, Palette.cream, Palette.glass)
		t.block(
			"Chimney",
			Vector3.new(1.8, h + 3, 1.8),
			Vector3.new(x0 - w / 2 - 0.4, PLINTH + (h + 3) / 2, d / 4),
			Palette.stone
		)
		t.block(
			"VaneArrow",
			Vector3.new(1.6, 0.4, 0.15),
			Vector3.new(x0, PLINTH + h + 4.9, d / 3),
			Palette.coins:Lerp(Palette.wood, 0.4),
			{ shadow = false }
		)
		Kit.sproutTag(t, Vector3.new(x0, PLINTH + h + 4.2, -d / 5), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Duplex: a mirror-twin house, left half teal and right half mustard, with the doors side by
-- side in the middle.
TYPES.Duplex = {
	roof = Palette.roofTeal,
	build = function(b, s, roof)
		local w, d, h = s * 0.92, s * 0.75, STORY * 1.6
		local body = walls(b, w, d, h, Palette.oat)
		local t = b.into(body, true)
		local half = w / 2
		local tints = { roof, if roof == Palette.roofMustard then Palette.roofTeal else Palette.roofMustard }
		for i, x in { -half / 2, half / 2 } do
			Kit.gableRoof(t, "Roof", CFrame.new(x, PLINTH + h, 0) * Kit.yaw(90), d + 1.4, half + 0.4, 3.6, tints[i])
			local inner = if i == 1 then 1 else -1
			Kit.door(t, "Door", CFrame.new(x + inner * 1, PLINTH, front(d)), 2, 4, tints[i], Palette.cream)
			Kit.window(
				t,
				"Window",
				CFrame.new(x, PLINTH + STORY + 1.8, front(d)),
				1.8,
				1.8,
				Palette.cream,
				Palette.glass
			)
		end
		Kit.sproutTag(t, Vector3.new(0, PLINTH + h + 3.6, 0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Townhouse: three stories of painted brick under a cream cornice, and a roof terrace with a
-- row of plants and a little umbrella.
TYPES.Townhouse = {
	roof = Palette.roofRed,
	build = function(b, s, roof)
		local w, d, h = s * 0.8, s * 0.8, STORY * 2.6
		local body = walls(b, w, d, h, Palette.brick)
		local t = b.into(body, true)
		t.block("Cornice", Vector3.new(w + 0.8, 0.6, d + 0.8), Vector3.new(0, PLINTH + h + 0.3, 0), Palette.cream)
		t.block(
			"Plants",
			Vector3.new(w - 1.6, 0.8, 0.8),
			Vector3.new(0, PLINTH + h + 1, d / 2 - 0.8),
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
		Kit.door(t, "Door", CFrame.new(-1.8, PLINTH, front(d)), 2, 4.2, Palette.roofTeal, Palette.cream)
		Kit.window(t, "Window", CFrame.new(1.6, PLINTH + 2.6, front(d)), 1.8, 1.8, Palette.cream, Palette.glass)
		Kit.window(t, "Window", CFrame.new(1.6, PLINTH + STORY + 1.6, front(d)), 1.6, 2, Palette.cream, Palette.glass)
		Kit.window(
			t,
			"Window",
			CFrame.new(-1.8, PLINTH + STORY * 2 + 1.2, front(d)),
			1.6,
			2,
			Palette.cream,
			Palette.glass
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
		Kit.gableRoof(t, "Roof", Vector3.new(x0, PLINTH + h, 0), w + 1.4, d + 1.4, 3.6, roof)
		-- Garden room: a low glass box with a cream frame and a flat roof
		local gx = x0 + w / 2 + s * 0.14
		t.block(
			"GardenGlass",
			Vector3.new(s * 0.24, 4.2, d * 0.66),
			Vector3.new(gx, 2.1, 0.6),
			Palette.glass,
			{ shadow = false }
		)
		t.block("GardenRoof", Vector3.new(s * 0.28, 0.4, d * 0.72), Vector3.new(gx, 4.4, 0.6), Palette.cream)
		Kit.door(t, "Door", CFrame.new(x0, PLINTH, front(d)), 2.2, 4.4, Palette.roofTeal, Palette.cream)
		for _, x in { -1, 1 } do
			Kit.window(
				t,
				"Window",
				CFrame.new(x0 + x * (w / 2 - 1.3), PLINTH + STORY + 2, front(d)),
				1.5,
				2,
				Palette.cream,
				Palette.glass
			)
		end
		t.ball("Topiary", 1.8, Vector3.new(x0 - 2.4, 0.9, front(d) - 1.2), Palette.treeTop)
		Kit.sproutTag(t, Vector3.new(x0 + w / 4, PLINTH + h + 3.4, 0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Thatched Longhouse (content bank, level 17): a long, low timber house under a deep straw
-- roof, with a stone chimney at one end and a flower box under the windows.
TYPES.ThatchedLonghouse = {
	roof = Palette.straw,
	build = function(b, s, roof)
		local w, d, h = s * 0.9, s * 0.6, STORY - 1
		local body = walls(b, w, d, h, Palette.woodLight)
		local t = b.into(body, true)
		Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1.6, d + 2, 4, roof)
		Kit.door(t, "Door", CFrame.new(0, PLINTH, front(d)), 2, 4, Palette.woodDark, Palette.cream)
		for _, x in { -1, 1 } do
			Kit.window(t, "Window", CFrame.new(x * w / 3, PLINTH + 3, front(d)), 1.6, 1.6, Palette.cream, Palette.glass)
		end
		flowerBox(t, CFrame.new(-w / 3, PLINTH + 2, front(d)), 2)
		chimney(t, Vector3.new(w / 2 - 1, PLINTH + h, d / 4), 4.5, Palette.stone)
		Kit.sproutTag(t, Vector3.new(-w / 4, PLINTH + h + 3.6, 0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Corner Flats (content bank, level 20): a two-storey block of flats in warm brick with a
-- cream cornice, two front doors, and a lower side wing with a flat roof and a planter.
TYPES.CornerFlats = {
	roof = Palette.roofTeal,
	build = function(b, s, roof)
		local w, d, h = s * 0.6, s * 0.75, STORY * 1.7
		local x = -s * 0.15
		local body = walls(b, w, d, h, Palette.brick, x)
		local t = b.into(body, true)
		t.block("Cornice", Vector3.new(w + 0.8, 0.8, d + 0.8), Vector3.new(x, PLINTH + h + 0.4, 0), Palette.cream)
		-- The side wing, one storey, its flat roof in the house's tint
		local ww, wx = s * 0.32, s * 0.31
		t.block("Wing", Vector3.new(ww, STORY - 1, d - 1), Vector3.new(wx, PLINTH + (STORY - 1) / 2, 0.5), Palette.oat)
		t.block("WingRoof", Vector3.new(ww + 0.6, 0.6, d - 0.4), Vector3.new(wx, PLINTH + STORY - 0.7, 0.5), roof)
		for _, dx in { -w / 4, w / 4 } do
			Kit.door(t, "Door", CFrame.new(x + dx, PLINTH, front(d)), 1.6, 3.6, roof, Palette.cream)
			Kit.window(
				t,
				"Window",
				CFrame.new(x + dx, PLINTH + STORY + 1.6, front(d)),
				1.6,
				1.8,
				Palette.cream,
				Palette.glass
			)
		end
		flowerBox(t, CFrame.new(wx, PLINTH + STORY - 0.2, front(d) + 0.5), ww)
		Kit.sproutTag(t, Vector3.new(x, PLINTH + h + 0.8, d / 4), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Lakeside Manor (content bank, level 22): a tall pale-blue manor under a steep roof, a
-- deep front porch, and a little pond with a rowboat at its side.
TYPES.LakesideManor = {
	roof = Palette.roofTeal,
	build = function(b, s, roof)
		local w, d, h = s * 0.62, s * 0.62, STORY * 1.8
		local x0, z0 = -s * 0.12, s * 0.08
		local body = walls(b, w, d, h, Palette.sky:Lerp(Palette.cream, 0.55), x0, z0)
		local t = b.into(body, true)
		Kit.gableRoof(t, "Roof", Vector3.new(x0, PLINTH + h, z0), w + 1.2, d + 1.2, 4.2, roof)
		local face = z0 - d / 2
		t.block("Porch", Vector3.new(w + 0.6, 0.4, 2), Vector3.new(x0, PLINTH + STORY - 1.4, face - 1), Palette.cream)
		Kit.door(t, "Door", CFrame.new(x0, PLINTH, face), 2, 4, roof, Palette.cream)
		for _, x in { -1, 1 } do
			Kit.window(
				t,
				"Window",
				CFrame.new(x0 + x * (w / 2 - 1.3), PLINTH + STORY + 1.6, face),
				1.5,
				1.8,
				Palette.cream,
				Palette.glass
			)
		end
		-- The pond on the open side, with a little rowboat
		local px = x0 + w / 2 + s * 0.13
		t.post("Pond", 0.2, s * 0.24, Vector3.new(px, 0.15, face + 0.6), Palette.water, { shadow = false })
		t.block("Rowboat", Vector3.new(0.8, 0.4, 1.6), Vector3.new(px, 0.4, face + 0.6), Palette.wood)
		Kit.sproutTag(t, Vector3.new(x0 - w / 4, PLINTH + h + 3.6, z0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Hearth House (content bank, level 24): a long cream house of one and a half storeys with
-- dark timber posts, a door in the middle under a fat stone chimney that serves both rooms,
-- and a window either side.
TYPES.HearthHouse = {
	roof = Palette.roofRed,
	build = function(b, s, roof)
		local w, d, h = s * 0.84, s * 0.56, STORY * 1.25
		local z0 = s * 0.1
		local body = walls(b, w, d, h, Palette.cream:Lerp(Palette.oat, 0.35), 0, z0)
		local t = b.into(body, true)
		Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, z0), w + 1, d + 1.2, 3.4, roof)
		chimney(t, Vector3.new(0, PLINTH + h + 1, z0 + 0.6), 4.2, Palette.stone)
		local face = z0 + front(d)
		for _, x in { -w / 2 + 0.3, w / 2 - 0.3 } do
			t.block("Timber", Vector3.new(0.5, h, 0.3), Vector3.new(x, PLINTH + h / 2, face - 0.1), Palette.woodDark)
		end
		Kit.door(t, "Door", CFrame.new(0, PLINTH, face), 1.8, 3.8, roof, Palette.woodDark)
		for _, x in { -1, 1 } do
			Kit.window(
				t,
				"Window",
				CFrame.new(x * w / 4 + x * 0.3, PLINTH + 2.4, face),
				1.6,
				1.6,
				Palette.woodDark,
				Palette.glass
			)
		end
		flowerBox(t, CFrame.new(-w / 4 - 0.3, PLINTH + 1.3, face), 1.8)
		Kit.sproutTag(t, Vector3.new(w / 3, PLINTH + h + 2, z0), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Twin Gables (content bank, level 26): a pair of tall butter-yellow homes under one roofline
-- of two front-facing gables, with a front door and a window each.
TYPES.TwinGables = {
	roof = Palette.roofTeal,
	build = function(b, s, roof)
		local w, d, h = s * 0.82, s * 0.62, STORY * 1.55
		local body = walls(b, w, d, h, Palette.flowerYellow:Lerp(Palette.cream, 0.6), 0, 0.3)
		local t = b.into(body, true)
		-- Two gables facing the street: each roof's ridge runs front to back
		for _, x in { -w / 4, w / 4 } do
			Kit.gableRoof(t, "Roof", CFrame.new(x, PLINTH + h, 0.3) * Kit.yaw(90), d + 1, w / 2 + 0.4, 2.8, roof)
		end
		local face = 0.3 + front(d)
		for _, x in { -w / 4, w / 4 } do
			Kit.door(t, "Door", CFrame.new(x, PLINTH, face), 1.6, 3.6, roof, Palette.cream)
			Kit.window(t, "Window", CFrame.new(x, PLINTH + STORY + 1.4, face), 1.5, 1.8, Palette.cream, Palette.glass)
		end
		Kit.sproutTag(t, Vector3.new(0, PLINTH + h + 1.6, 0.3), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Canal House (content bank, level 28): a tall, narrow brick house with a stepped gable to
-- the street, a cream hoist beam under the peak, and a door up a short stoop.
TYPES.CanalHouse = {
	roof = Palette.roofMustard,
	build = function(b, s, roof)
		local w, d, h = s * 0.56, s * 0.7, STORY * 2
		local body = walls(b, w, d, h, Palette.brick, 0, 0.3)
		local t = b.into(body, true)
		local face = 0.3 + front(d)
		-- The stepped gable: three brick steps rising over the front wall, capped in the roof tint
		for i, sw in { w, w * 0.66, w * 0.33 } do
			t.block(
				"Step",
				Vector3.new(sw, 1.1, 0.8),
				Vector3.new(0, PLINTH + h + i * 1.1 - 0.55, face + 0.4),
				Palette.brick
			)
		end
		t.block("Roof", Vector3.new(w + 0.4, 0.6, d + 0.4), Vector3.new(0, PLINTH + h + 0.3, 0.3), roof)
		t.block("Cap", Vector3.new(w * 0.33 + 0.4, 0.4, 1), Vector3.new(0, PLINTH + h + 3.5, face + 0.4), roof)
		t.block("Hoist", Vector3.new(0.4, 0.4, 1.4), Vector3.new(0, PLINTH + h + 1.4, face - 0.5), Palette.cream)
		t.block("Stoop", Vector3.new(2.4, 0.8, 1.2), Vector3.new(0, PLINTH + 0.4, face - 0.6), Palette.stone)
		Kit.door(t, "Door", CFrame.new(0, PLINTH + 0.8, face), 1.6, 3.4, roof, Palette.cream)
		for _, y in { STORY + 0.8, STORY * 1.6 } do
			Kit.window(t, "Window", CFrame.new(0, PLINTH + y, face), 1.4, 1.8, Palette.cream, Palette.glass)
		end
		Kit.sproutTag(t, Vector3.new(0, PLINTH + h + 0.6, d / 4), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Courtyard Flats (content bank, level 34): a three-storey block of warm sandstone in two
-- wings around a little front courtyard with a tree, balconies on the upper floors and a flat
-- roof with a water tank.
TYPES.CourtyardFlats = {
	roof = Palette.roofRed,
	build = function(b, s, roof)
		local w, d, h = s * 0.84, s * 0.62, STORY * 2.6
		local body = walls(b, w, d, h, Palette.wheat:Lerp(Palette.brick, 0.2), 0, 0.3)
		local t = b.into(body, true)
		local face = 0.3 + front(d)
		t.block("Roof", Vector3.new(w + 0.4, 0.5, d + 0.4), Vector3.new(0, PLINTH + h + 0.25, 0.3), roof)
		t.post("Tank", 1.4, 1.4, Vector3.new(w / 4, PLINTH + h + 1.2, 0.3 + d / 6), Palette.metal)
		-- The courtyard: a low wall either side of the gap and a tree in the middle
		for _, x in { -w / 3, w / 3 } do
			t.block("CourtWall", Vector3.new(w / 4, 0.8, 0.3), Vector3.new(x, PLINTH + 0.4, face - 1.6), Palette.cream)
		end
		t.ball("Tree", 1.8, Vector3.new(-w / 5, PLINTH + 2.2, face - 0.9), Palette.leaf)
		Kit.door(t, "Door", CFrame.new(w / 8, PLINTH, face), 1.8, 3.4, roof, Palette.cream)
		-- Balconies on the upper floors
		for i, y in { STORY * 1.2, STORY * 2 } do
			t.block(
				"Balcony",
				Vector3.new(w * 0.7, 0.3, 0.9),
				Vector3.new(0, PLINTH + y, face - 0.45),
				if i == 1 then Palette.cream else roof
			)
			Kit.window(t, "Window", CFrame.new(-w / 4, PLINTH + y + 1.1, face), 1.4, 1.6, Palette.cream, Palette.glass)
		end
		Kit.sproutTag(t, Vector3.new(-w / 4, PLINTH + h + 0.6, d / 4), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Terrace Condos (content bank, level 32): a modern block of two stacked flats, the upper one
-- set back behind a railed terrace, under a flat roof, with a side stair to the top door.
TYPES.Condos = {
	roof = Palette.roofTeal,
	build = function(b, s, roof)
		local w, d, h = s * 0.8, s * 0.64, STORY
		local body = walls(b, w, d, h, Palette.cream, 0, 0.3)
		local t = b.into(body, true)
		local face = 0.3 + front(d)
		-- The upper flat, set back, and the terrace rail along the lower roof's edge
		t.block(
			"Upper",
			Vector3.new(w, STORY, d * 0.6),
			Vector3.new(0, PLINTH + h + STORY / 2, 0.3 + d * 0.2),
			Palette.sky:Lerp(Palette.cream, 0.6)
		)
		t.block(
			"Roof",
			Vector3.new(w + 0.4, 0.4, d * 0.6 + 0.4),
			Vector3.new(0, PLINTH + h + STORY + 0.2, 0.3 + d * 0.2),
			roof
		)
		t.block("Rail", Vector3.new(w, 0.8, 0.2), Vector3.new(0, PLINTH + h + 0.4, face + 0.1), Palette.metal)
		-- The side stair
		t.wedge("Stair", Vector3.new(1.2, h, 2.4), CFrame.new(w / 2 + 0.6, PLINTH + h / 2, face + 1.4), Palette.stone)
		Kit.door(t, "Door", CFrame.new(-w / 4, PLINTH, face), 1.6, 3.4, roof, Palette.cream)
		Kit.window(t, "Window", CFrame.new(w / 5, PLINTH + 1.8, face), 2.4, 1.6, Palette.cream, Palette.glass)
		Kit.window(t, "Window", CFrame.new(0, PLINTH + h + 1.6, face + d * 0.4), 2.4, 1.6, Palette.cream, Palette.glass)
		Kit.sproutTag(t, Vector3.new(-w / 4, PLINTH + h + STORY + 0.6, d / 4), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Ivy Apartments (content bank, level 31): a wide three-storey block of honey stone with
-- ivy climbing one corner, a flat roof with a parapet, and a shared front door under a canopy.
TYPES.IvyApartments = {
	roof = Palette.roofTeal,
	build = function(b, s, roof)
		local w, d, h = s * 0.82, s * 0.6, STORY * 2.6
		local body = walls(b, w, d, h, Palette.wheat:Lerp(Palette.cream, 0.5), 0, 0.3)
		local t = b.into(body, true)
		t.block("Roof", Vector3.new(w + 0.4, 0.5, d + 0.4), Vector3.new(0, PLINTH + h + 0.25, 0.3), roof)
		t.block("Parapet", Vector3.new(w + 0.4, 0.6, 0.3), Vector3.new(0, PLINTH + h + 0.8, 0.3 + front(d)), roof)
		local face = 0.3 + front(d)
		-- Ivy up the left corner
		t.block(
			"Ivy",
			Vector3.new(1.4, h * 0.85, 0.3),
			Vector3.new(-w / 2 + 0.6, PLINTH + h * 0.43, face - 0.1),
			Palette.leaf
		)
		t.ball("IvyTop", 1.6, Vector3.new(-w / 2 + 0.6, PLINTH + h * 0.85, face - 0.1), Palette.leafLight)
		Kit.door(t, "Door", CFrame.new(0, PLINTH, face), 2, 3.6, roof, Palette.cream)
		t.block("Canopy", Vector3.new(3, 0.3, 1.2), Vector3.new(0, PLINTH + 4, face - 0.6), roof)
		for _, x in { -w / 4, w / 4 } do
			Kit.window(t, "Window", CFrame.new(x, PLINTH + STORY * 1.6, face), 1.6, 1.8, Palette.cream, Palette.glass)
		end
		Kit.sproutTag(t, Vector3.new(w / 4, PLINTH + h + 0.6, d / 4), 2.5, Palette.wood, Palette.lime)
		return body
	end,
}

-- Brick Townhouse (content bank, level 29): a tall red-brick house with a cream-trimmed bay
-- window pushed out at the front, a steep gable roof and a door up two steps.
TYPES.BrickTownhouse = {
	roof = Palette.roofPlum,
	build = function(b, s, roof)
		local w, d, h = s * 0.6, s * 0.66, STORY * 2
		local body = walls(b, w, d, h, Palette.brick:Lerp(Palette.roofRed, 0.25), 0, 0.3)
		local t = b.into(body, true)
		Kit.gableRoof(t, "Roof", CFrame.new(0, PLINTH + h, 0.3) * Kit.yaw(90), d + 1, w + 0.8, 3.4, roof)
		local face = 0.3 + front(d)
		-- The bay: a cream box pushed out from the left of the front, with a window and a lid
		local bayX = -w / 4
		t.block(
			"Bay",
			Vector3.new(w / 2, STORY - 0.4, 1),
			Vector3.new(bayX, PLINTH + STORY / 2, face - 0.5),
			Palette.cream
		)
		t.block("BayLid", Vector3.new(w / 2 + 0.4, 0.4, 1.4), Vector3.new(bayX, PLINTH + STORY, face - 0.5), roof)
		Kit.window(t, "Window", CFrame.new(bayX, PLINTH + STORY / 2, face - 1), 1.6, 1.6, Palette.cream, Palette.glass)
		Kit.window(t, "Window", CFrame.new(0, PLINTH + STORY * 1.5, face), 1.6, 1.8, Palette.cream, Palette.glass)
		t.block("Steps", Vector3.new(1.8, 0.6, 1), Vector3.new(w / 4, PLINTH + 0.3, face - 0.5), Palette.stone)
		Kit.door(t, "Door", CFrame.new(w / 4, PLINTH + 0.6, face), 1.5, 3.4, roof, Palette.cream)
		Kit.sproutTag(t, Vector3.new(0, PLINTH + h + 0.6, d / 4), 2.5, Palette.wood, Palette.lime)
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
