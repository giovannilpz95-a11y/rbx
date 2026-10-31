--!strict
-- Community Buildings for Main Street (Design/16 Model Catalog §2.10, Design/07 Town
-- Building): the nine a level-12 player can build, plus the content bank's (level 13+). Same rules as Houses, and each has one big
-- readable "sign object" so its job is clear from the Overview camera. Built for a square lot
-- (12 studs by default) with the front at local -Z. Budget ≤ 24 parts; aim for 20, since a
-- level-30 plot holds about 28 of them.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtCommunity = {}

ArtCommunity.PARTS_MAX = 24

local PLINTH = 0.6
local TURN = CFrame.Angles(0, math.rad(90), 0)

-- A rectangular hall: plinth and walls. Returns the walls (tap target).
local function hall(b: Kit.Builder, w: number, d: number, h: number, wall: Color3): Part
	b.block("Plinth", Vector3.new(w + 0.6, PLINTH, d + 0.6), Vector3.new(0, PLINTH / 2, 0), Palette.stone)
	return b.block("Body", Vector3.new(w, h, d), Vector3.new(0, PLINTH + h / 2, 0), wall, { collide = true })
end

-- A sign disc on the front: wood rim and cream face, centred at `at`, facing -Z. 2 parts.
local function disc(b: Kit.Builder, at: Vector3, size: number)
	b.cyl("SignRim", 0.3, size + 0.5, CFrame.new(at) * TURN, Palette.woodDark, { shadow = false })
	b.cyl("Sign", 0.3, size, CFrame.new(at + Vector3.new(0, 0, -0.1)) * TURN, Palette.cream, { shadow = false })
end

type Build = (b: Kit.Builder, s: number) -> BasePart

local TYPES: { [string]: Build } = {}

-- Village Well: a round stone well under a little shingle roof, with a bucket on the rope.
TYPES.VillageWell = function(b, s)
	b.block("Paving", Vector3.new(s * 0.7, 0.3, s * 0.7), Vector3.new(0, 0.15, 0), Palette.path)
	local body = b.post("Body", 2.4, 4.4, Vector3.new(0, 1.5, 0), Palette.stone, { collide = true })
	local t = b.into(body, true)
	t.post("Rim", 0.5, 4.8, Vector3.new(0, 2.9, 0), Palette.stoneLight)
	t.post("Water", 0.2, 3.6, Vector3.new(0, 2.7, 0), Palette.water, { shadow = false })
	for _, x in { -2, 2 } do
		t.block("Post", Vector3.new(0.5, 4.6, 0.5), Vector3.new(x, 4.8, 0), Palette.woodDark)
	end
	t.cyl("Winch", 4.4, 0.6, Vector3.new(0, 5.8, 0), Palette.wood)
	t.block("Rope", Vector3.new(0.12, 1.6, 0.12), Vector3.new(0.6, 4.9, 0), Palette.cream, { shadow = false })
	t.post("Bucket", 0.8, 0.8, Vector3.new(0.6, 3.8, 0), Palette.wood, { shadow = false })
	Kit.gableRoof(t, "Roof", Vector3.new(0, 7, 0), 5.4, 3.6, 1.8, Palette.roofRed)
	for i, x in { -3.6, 3.6 } do
		Kit.bush(t, "Bush", Vector3.new(x, 0.3, if i == 1 then 2.4 else -2.4), 1, Palette.treeTop, Palette.flowerYellow)
	end
	Kit.sproutTag(t, Vector3.new(0, 8.9, 0), 1.2, Palette.wood, Palette.lime)
	return body
end

-- Picnic Pavilion: an open pavilion on four posts under a striped red-and-cream roof, with
-- two picnic tables underneath.
TYPES.PicnicPavilion = function(b, s)
	local w, d = s * 0.85, s * 0.7
	local body = b.block("Body", Vector3.new(w, 0.5, d), Vector3.new(0, 0.25, 0), Palette.woodLight, { collide = true })
	local t = b.into(body, true)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			t.block(
				"Post",
				Vector3.new(0.6, 5.2, 0.6),
				Vector3.new(x * (w / 2 - 0.5), 3.1, z * (d / 2 - 0.5)),
				Palette.cream
			)
		end
	end
	Kit.gableRoof(t, "Roof", Vector3.new(0, 5.7, 0), w + 1.6, d + 1.6, 3, Palette.roofRed)
	t.block(
		"RoofStripe",
		Vector3.new(1.4, 0.2, d + 1.4),
		CFrame.new(-2.2, 7.2, 0) * Kit.yaw(0),
		Palette.cream,
		{ shadow = false }
	)
	for _, x in { -2.2, 2.2 } do
		t.block("Table", Vector3.new(2.6, 0.3, 1.6), Vector3.new(x, 1.5, 0), Palette.wood)
		t.block("TableLeg", Vector3.new(0.4, 1, 0.4), Vector3.new(x, 0.95, 0), Palette.woodDark, { shadow = false })
		t.block("Bench", Vector3.new(2.6, 0.25, 0.5), Vector3.new(x, 0.95, -1.3), Palette.wood, { shadow = false })
		t.block("Bench", Vector3.new(2.6, 0.25, 0.5), Vector3.new(x, 0.95, 1.3), Palette.wood, { shadow = false })
	end
	t.block("Basket", Vector3.new(0.9, 0.6, 0.7), Vector3.new(2.2, 1.95, 0), Palette.straw, { shadow = false })
	Kit.sproutTag(t, Vector3.new(0, 8.8, 0), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Schoolhouse: a red schoolhouse with cream trim and a bell tower over the door.
TYPES.Schoolhouse = function(b, s)
	local w, d, h = s * 0.8, s * 0.7, 6.5
	local body = hall(b, w, d, h, Palette.barnRed)
	local t = b.into(body, true)
	Kit.gableRoof(t, "Roof", CFrame.new(0, PLINTH + h, 0) * Kit.yaw(90), d + 1.2, w + 1.2, 3.4, Palette.stoneDark)
	t.block("Tower", Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, PLINTH + h + 3.4, -d / 2 + 1.6), Palette.cream)
	t.ball(
		"Bell",
		1.3,
		Vector3.new(0, PLINTH + h + 3.4, -d / 2 + 0.25),
		Palette.coins:Lerp(Palette.wood, 0.35),
		{ shadow = false }
	)
	Kit.gableRoof(t, "TowerRoof", Vector3.new(0, PLINTH + h + 4.7, -d / 2 + 1.6), 3.2, 3.2, 2, Palette.roofRed)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, -d / 2), 2.4, 4.4, Palette.cream, Palette.cream:Lerp(Palette.wood, 0.3))
	for _, x in { -1, 1 } do
		Kit.window(
			t,
			"Window",
			CFrame.new(x * (w / 2 - 1.7), PLINTH + 3.4, -d / 2),
			1.8,
			2.4,
			Palette.cream,
			Palette.glass
		)
	end
	t.block(
		"Slate",
		Vector3.new(3, 1.2, 0.2),
		Vector3.new(0, PLINTH + 5.6, -d / 2 - 0.15),
		Palette.leaf:Lerp(Palette.cocoa, 0.5),
		{ shadow = false }
	)
	Kit.sproutTag(t, Vector3.new(0, PLINTH + h + 6.7, -d / 2 + 1.6), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Clinic: a cream building with sky-blue trim and a big green leaf-and-plus sign (a green plus,
-- never a red cross: that emblem is protected).
TYPES.Clinic = function(b, s)
	local w, d, h = s * 0.85, s * 0.7, 7
	local body = hall(b, w, d, h, Palette.cream)
	local t = b.into(body, true)
	t.block("Roof", Vector3.new(w + 1, 0.8, d + 1), Vector3.new(0, PLINTH + h + 0.4, 0), Palette.sky)
	t.block("RoofBox", Vector3.new(w * 0.6, 1.6, d * 0.6), Vector3.new(0, PLINTH + h + 1.6, 0.6), Palette.stoneLight)
	disc(t, Vector3.new(0, PLINTH + h + 2.4, -d / 2 + 0.2), 3.4)
	t.block(
		"Plus",
		Vector3.new(2.2, 0.7, 0.3),
		Vector3.new(0, PLINTH + h + 2.4, -d / 2 - 0.15),
		Palette.leafLight,
		{ shadow = false }
	)
	t.block(
		"Plus",
		Vector3.new(0.7, 2.2, 0.3),
		Vector3.new(0, PLINTH + h + 2.4, -d / 2 - 0.15),
		Palette.leafLight,
		{ shadow = false }
	)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, -d / 2), 2.8, 4.4, Palette.glass, Palette.sky)
	t.block(
		"Canopy",
		Vector3.new(4.4, 0.35, 1.8),
		Vector3.new(0, PLINTH + 4.9, -d / 2 - 0.9),
		Palette.sky,
		{ shadow = false }
	)
	for _, x in { -1, 1 } do
		Kit.window(t, "Window", CFrame.new(x * (w / 2 - 1.8), PLINTH + 3.6, -d / 2), 2, 2.2, Palette.sky, Palette.glass)
	end
	Kit.sproutTag(t, Vector3.new(w / 2 - 1.5, PLINTH + h + 0.8, d / 2 - 1.5), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Fire Hall: a red hall with a tall hose tower, a big cream garage door and a hose drum.
TYPES.FireHall = function(b, s)
	local w, d, h = s * 0.85, s * 0.75, 7
	local body = hall(b, w, d, h, Palette.roofRed)
	local t = b.into(body, true)
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1, d + 1.2, 2.6, Palette.stoneDark)
	t.block(
		"Tower",
		Vector3.new(3, 6, 3),
		Vector3.new(w / 2 - 1.5, PLINTH + h + 3, d / 2 - 1.5),
		Palette.roofRed:Lerp(Palette.brick, 0.4),
		{ collide = true }
	)
	Kit.gableRoof(
		t,
		"TowerRoof",
		Vector3.new(w / 2 - 1.5, PLINTH + h + 6, d / 2 - 1.5),
		3.6,
		3.6,
		1.8,
		Palette.stoneDark
	)
	t.block("GarageFrame", Vector3.new(5.4, 5.2, 0.25), Vector3.new(-0.8, PLINTH + 2.6, -d / 2 - 0.12), Palette.cream)
	t.block(
		"Garage",
		Vector3.new(4.6, 4.6, 0.3),
		Vector3.new(-0.8, PLINTH + 2.3, -d / 2 - 0.3),
		Palette.cream:Lerp(Palette.stoneLight, 0.4)
	)
	for i = 1, 3 do
		t.block(
			"GarageLine",
			Vector3.new(4.6, 0.15, 0.1),
			Vector3.new(-0.8, PLINTH + i * 1.2, -d / 2 - 0.48),
			Palette.stoneDark,
			{ shadow = false }
		)
	end
	t.cyl("HoseDrum", 1.2, 2, CFrame.new(w / 2 - 1, PLINTH + 1.4, -d / 2 - 0.9), Palette.roofMustard)
	t.ball("Siren", 1, Vector3.new(w / 2 - 1.5, PLINTH + h + 8.6, d / 2 - 1.5), Palette.coins, { shadow = false })
	Kit.window(t, "Window", CFrame.new(w / 2 - 1.5, PLINTH + 4.6, -d / 2), 1.6, 1.8, Palette.cream, Palette.glass)
	Kit.sproutTag(t, Vector3.new(-1.5, PLINTH + h + 2.6, 0), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Post Office: a sky-blue-roofed hall with a giant envelope sign and a round post box by the
-- door.
TYPES.PostOffice = function(b, s)
	local w, d, h = s * 0.8, s * 0.7, 6.5
	local body = hall(b, w, d, h, Palette.oat)
	local t = b.into(body, true)
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1.2, d + 1.4, 3.6, Palette.glassDeep)
	-- Envelope sign standing on the roof ridge
	local env = Vector3.new(0, PLINTH + h + 5, -0.2)
	t.block("Envelope", Vector3.new(4.4, 2.8, 0.4), env, Palette.cream)
	t.wedge(
		"EnvelopeFlap",
		Vector3.new(4.4, 1.3, 0.2),
		CFrame.new(env + Vector3.new(0, 0.75, -0.3)) * CFrame.Angles(math.rad(-90), 0, 0) * Kit.yaw(180),
		Palette.stoneLight,
		{ shadow = false }
	)
	t.ball("Seal", 0.8, env + Vector3.new(0, 0.1, -0.35), Palette.roofRed, { shadow = false })
	Kit.door(t, "Door", CFrame.new(-1.4, PLINTH, -d / 2), 2.4, 4.4, Palette.glassDeep, Palette.cream)
	Kit.window(t, "Window", CFrame.new(2.2, PLINTH + 3.2, -d / 2), 2.4, 2.2, Palette.cream, Palette.glass)
	t.post("PostBox", 2.4, 1.2, Vector3.new(-w / 2 - 0.4, 1.2, -d / 2 - 1), Palette.roofRed)
	t.ball("PostBoxTop", 1.2, Vector3.new(-w / 2 - 0.4, 2.4, -d / 2 - 1), Palette.roofRed, { shadow = false })
	Kit.sproutTag(t, Vector3.new(w / 3, PLINTH + h + 3.6, 0), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Tea Room: a pink-washed café with a striped awning, two little tables out front and a giant
-- teacup on the roof.
TYPES.TeaRoom = function(b, s)
	local w, d, h = s * 0.8, s * 0.65, 6.5
	local pink = Palette.cream:Lerp(Palette.flowerPink, 0.45)
	local body = hall(b, w, d, h, pink)
	local t = b.into(body, true)
	t.block("Roof", Vector3.new(w + 0.8, 0.7, d + 0.8), Vector3.new(0, PLINTH + h + 0.35, 0), Palette.plum)
	local cup = Vector3.new(0, PLINTH + h + 0.7, 0)
	t.post("Saucer", 0.4, 4.6, cup + Vector3.new(0, 0.2, 0), Palette.cream)
	t.post("Cup", 2.4, 3.2, cup + Vector3.new(0, 1.6, 0), Palette.cream)
	t.post("Tea", 0.2, 2.8, cup + Vector3.new(0, 2.75, 0), Palette.wood, { shadow = false })
	t.block("Handle", Vector3.new(1, 1.4, 0.4), cup + Vector3.new(2, 1.7, 0), Palette.cream, { shadow = false })
	for i = 0, 3 do
		local color = if i % 2 == 0 then Palette.roofRed else Palette.cream
		t.block(
			"Awning",
			Vector3.new(w / 4, 0.3, 2),
			CFrame.new(-w / 2 + w / 8 + i * w / 4, PLINTH + 5, -d / 2 - 0.9) * CFrame.Angles(math.rad(20), 0, 0),
			color,
			{ shadow = false }
		)
	end
	Kit.door(t, "Door", CFrame.new(1.8, PLINTH, -d / 2), 2.2, 4.2, Palette.plum, Palette.cream)
	Kit.window(t, "Window", CFrame.new(-1.6, PLINTH + 2.8, -d / 2), 3, 2.4, Palette.cream, Palette.glass)
	for _, x in { -3.2, 0 } do
		t.post("CafeTable", 0.25, 1.4, Vector3.new(x, 1.3, -d / 2 - 2.6), Palette.cream, { shadow = false })
		t.block(
			"CafeLeg",
			Vector3.new(0.25, 1.2, 0.25),
			Vector3.new(x, 0.6, -d / 2 - 2.6),
			Palette.cocoa,
			{ shadow = false }
		)
	end
	Kit.sproutTag(t, Vector3.new(-w / 2 + 1.2, PLINTH + h + 0.7, d / 2 - 1.2), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Library: a brick hall with cream columns and steps, and a roof shaped like an open book.
TYPES.Library = function(b, s)
	local w, d, h = s * 0.85, s * 0.7, 7
	local body = hall(b, w, d, h, Palette.brick:Lerp(Palette.woodDark, 0.3))
	local t = b.into(body, true)
	t.block("Cornice", Vector3.new(w + 0.8, 0.6, d + 0.8), Vector3.new(0, PLINTH + h + 0.3, 0), Palette.cream)
	-- Open book: two tilted covers with cream pages
	for _, side in { -1, 1 } do
		local at = CFrame.new(side * (w / 4), PLINTH + h + 1.5, 0) * CFrame.Angles(0, 0, math.rad(side * -14))
		t.block("Cover", Vector3.new(w / 2 + 0.4, 0.5, d + 0.6), at, Palette.roofTeal)
		t.block(
			"Pages",
			Vector3.new(w / 2 - 0.2, 0.4, d - 0.2),
			at * CFrame.new(0, 0.45, 0),
			Palette.cream,
			{ shadow = false }
		)
	end
	t.block(
		"Spine",
		Vector3.new(0.6, 1.2, d + 0.6),
		Vector3.new(0, PLINTH + h + 0.9, 0),
		Palette.roofTeal:Lerp(Palette.cocoa, 0.3)
	)
	for _, x in { -2.6, -1, 1, 2.6 } do
		t.post("Column", h - 0.4, 0.7, Vector3.new(x, PLINTH + (h - 0.4) / 2 + 0.4, -d / 2 - 0.8), Palette.cream)
	end
	t.block("Pediment", Vector3.new(6.6, 0.6, 1.6), Vector3.new(0, PLINTH + h - 0.1, -d / 2 - 0.8), Palette.cream)
	t.block("Steps", Vector3.new(6.6, 0.4, 1.8), Vector3.new(0, 0.2, -d / 2 - 0.9), Palette.stoneLight)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, -d / 2), 2, 4.2, Palette.woodDark, Palette.cream)
	Kit.sproutTag(t, Vector3.new(0, PLINTH + h + 1.4, 0), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Bandstand: an open octagonal gazebo on a raised floor, cream posts and a stepped roof in
-- red and cream, with a giant music note on top.
TYPES.Bandstand = function(b, s)
	local r = s * 0.38
	local body = b.post("Body", 1.2, r * 2 + 0.6, Vector3.new(0, 0.6, 0), Palette.stoneLight, { collide = true })
	local t = b.into(body, true)
	t.post("Floor", 0.3, r * 2, Vector3.new(0, 1.35, 0), Palette.woodLight, { shadow = false })
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		t.block(
			"Post",
			Vector3.new(0.45, 4.4, 0.45),
			Vector3.new(math.sin(a) * (r - 0.4), 3.6, math.cos(a) * (r - 0.4)),
			Palette.cream
		)
	end
	t.post("Roof", 0.9, r * 2 + 1.4, Vector3.new(0, 6.2, 0), Palette.roofRed)
	t.post("Roof", 0.8, r * 1.4, Vector3.new(0, 7, 0), Palette.cream)
	t.post("Roof", 0.8, r * 0.8, Vector3.new(0, 7.8, 0), Palette.roofRed)
	-- Music note: a ball head and a stem with a flag
	t.ball("NoteHead", 1.3, Vector3.new(-0.3, 9, 0), Palette.cocoa)
	t.block("NoteStem", Vector3.new(0.3, 2.6, 0.3), Vector3.new(0.3, 10.1, 0), Palette.cocoa, { shadow = false })
	t.block(
		"NoteFlag",
		Vector3.new(1, 0.4, 0.3),
		CFrame.new(0.75, 11.2, 0) * CFrame.Angles(0, 0, math.rad(-30)),
		Palette.cocoa,
		{ shadow = false }
	)
	t.block("Steps", Vector3.new(2.4, 0.6, 1.2), Vector3.new(0, 0.3, -r - 0.5), Palette.stoneLight)
	Kit.bush(t, "Bush", Vector3.new(-r - 0.6, 0, -r + 1), 0.9, Palette.treeTop, Palette.flowerPink)
	Kit.bush(t, "Bush", Vector3.new(r + 0.6, 0, -r + 1), 0.9, Palette.treeTop, Palette.flowerYellow)
	return body
end

-- Clock Tower (content bank, level 13): a stone hall with a tall square tower, a big clock
-- face on the front and a pointed teal cap with a weather vane.
TYPES.ClockTower = function(b, s)
	local w, d, h = s * 0.8, s * 0.6, 5
	local body = hall(b, w, d, h, Palette.stone)
	local t = b.into(body, true)
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1, d + 1, 2.6, Palette.roofRed)
	local tw, th = 3.6, 9
	t.block("Tower", Vector3.new(tw, th, tw), Vector3.new(0, PLINTH + h + th / 2 - 1, 0), Palette.stoneLight)
	t.block("Ledge", Vector3.new(tw + 0.6, 0.5, tw + 0.6), Vector3.new(0, PLINTH + h + th - 1, 0), Palette.cream)
	t.wedge(
		"Cap",
		Vector3.new(tw + 0.4, 3, (tw + 0.4) / 2),
		CFrame.new(0, PLINTH + h + th + 0.75, -(tw + 0.4) / 4),
		Palette.roofTeal
	)
	t.wedge(
		"Cap",
		Vector3.new(tw + 0.4, 3, (tw + 0.4) / 2),
		CFrame.new(0, PLINTH + h + th + 0.75, (tw + 0.4) / 4) * CFrame.Angles(0, math.rad(180), 0),
		Palette.roofTeal
	)
	t.block(
		"Vane",
		Vector3.new(0.2, 1.6, 0.2),
		Vector3.new(0, PLINTH + h + th + 3, 0),
		Palette.metal,
		{ shadow = false }
	)
	t.block(
		"VaneArrow",
		Vector3.new(1.4, 0.2, 0.2),
		Vector3.new(0, PLINTH + h + th + 3.4, 0),
		Palette.metal,
		{ shadow = false }
	)
	-- Clock: the sign disc with two hands
	local face = Vector3.new(0, PLINTH + h + th - 3.2, -tw / 2 - 0.2)
	disc(t, face, 2.8)
	t.block(
		"HourHand",
		Vector3.new(0.2, 0.9, 0.1),
		face + Vector3.new(0, 0.4, -0.25),
		Palette.cocoa,
		{ shadow = false }
	)
	t.block(
		"MinuteHand",
		Vector3.new(1.1, 0.16, 0.1),
		face + Vector3.new(0.5, 0, -0.25),
		Palette.cocoa,
		{ shadow = false }
	)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, -d / 2), 2.4, 4, Palette.woodDark, Palette.cream)
	t.block("Steps", Vector3.new(4, 0.4, 1.4), Vector3.new(0, 0.2, -d / 2 - 0.7), Palette.stoneLight)
	Kit.sproutTag(t, Vector3.new(w / 2 - 1.2, PLINTH + h + 1.2, d / 2 - 1.2), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Greenhouse (content bank, level 14): a long glass house on a brick base with a cream frame,
-- flowering plants inside and a big flower on the gable.
TYPES.Greenhouse = function(b, s)
	local w, d, h = s * 0.85, s * 0.6, 1.2
	local body = hall(b, w, d, h, Palette.brick)
	local t = b.into(body, true)
	t.block(
		"Glass",
		Vector3.new(w - 0.2, 4, d - 0.2),
		Vector3.new(0, PLINTH + h + 2, 0),
		Palette.glass,
		{ shadow = false }
	)
	for _, x in { -w / 2, w / 2 } do
		t.block("Frame", Vector3.new(0.3, 4, d), Vector3.new(x, PLINTH + h + 2, 0), Palette.cream, { shadow = false })
	end
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h + 4, 0), w + 0.6, d + 0.6, 2.4, Palette.glassDeep)
	for _, x in { -w / 4, w / 4 } do
		Kit.bush(t, "Plant", Vector3.new(x, PLINTH + h, 0), 0.8, Palette.leaf, Palette.flowerPink)
	end
	Kit.door(t, "Door", CFrame.new(0, PLINTH, -d / 2), 2.2, 4.2, Palette.roofTeal, Palette.cream)
	-- Gable flower: a yellow middle and four pink petals
	local at = Vector3.new(0, PLINTH + h + 6.9, -d / 2 - 0.1)
	t.ball("FlowerMiddle", 1, at, Palette.flowerYellow, { shadow = false })
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		t.ball(
			"Petal",
			0.9,
			at + Vector3.new(math.cos(a) * 0.75, math.sin(a) * 0.75, 0.1),
			Palette.flowerPink,
			{ shadow = false }
		)
	end
	Kit.sproutTag(t, Vector3.new(w / 2 - 1, PLINTH + h + 5.2, d / 2 - 1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Bathhouse (content bank, level 15): a pale-blue tiled hall under a teal arch roof, with a
-- round wooden tub on the sign wall and steam puffing from a stone chimney.
TYPES.Bathhouse = function(b, s)
	local w, d, h = s * 0.8, s * 0.6, 4.4
	local body = hall(b, w, d, h, Palette.sky)
	local t = b.into(body, true)
	Kit.archRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 0.8, d + 0.8, 2.4, 4, 0.5, Palette.roofTeal)
	t.post("Chimney", 3, 1.4, Vector3.new(w / 2 - 1.6, PLINTH + h + 2.4, d / 4), Palette.stone)
	for i, y in { 1.2, 2.5 } do
		t.ball(
			"Steam",
			0.9 + i * 0.3,
			Vector3.new(w / 2 - 1.6 + i * 0.3, PLINTH + h + 3.9 + y, d / 4),
			Palette.flowerWhite,
			{ shadow = false, transparency = 0.3 }
		)
	end
	-- Sign object: a round wooden tub with water and a bubble, over the door
	local tub = Vector3.new(0, PLINTH + h + 1.2, -d / 2 - 0.6)
	t.post("Tub", 1.4, 3, tub, Palette.wood)
	t.post("TubWater", 0.2, 2.5, tub + Vector3.new(0, 0.65, 0), Palette.water, { shadow = false })
	t.ball("Bubble", 0.8, tub + Vector3.new(0.5, 1.1, 0), Palette.flowerWhite, { shadow = false })
	Kit.door(t, "Door", CFrame.new(0, PLINTH, -d / 2), 2.4, 3.6, Palette.woodDark, Palette.cream)
	for _, x in { -w / 3, w / 3 } do
		Kit.window(t, "Window", CFrame.new(x, PLINTH + 2.6, -d / 2), 1.6, 1.4, Palette.cream, Palette.glass)
	end
	Kit.bush(t, "Bush", Vector3.new(-w / 2 + 0.8, 0.3, -d / 2 - 1.2), 0.9, Palette.treeTop, Palette.flowerPink)
	Kit.sproutTag(t, Vector3.new(-w / 2 + 1.2, PLINTH + h + 1, d / 2 - 1.2), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Art Studio (content bank, level 16): a cream studio with a plum gable roof and a big
-- skylight, and a giant easel with a painted canvas out front. The roof's sign is a paint
-- palette with three colour dots.
TYPES.ArtStudio = function(b, s)
	local w, d, h = s * 0.7, s * 0.55, 5
	local body = hall(b, w, d, h, Palette.cream)
	local t = b.into(body, true)
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1, d + 1, 2.8, Palette.roofPlum)
	t.block(
		"Skylight",
		Vector3.new(w * 0.5, 0.3, d * 0.35),
		CFrame.new(0, PLINTH + h + 1.5, -d / 4) * CFrame.Angles(math.rad(-28), 0, 0),
		Palette.glass,
		{ shadow = false }
	)
	Kit.window(t, "Window", CFrame.new(-w / 4, PLINTH + 2.8, -d / 2), 2, 2.2, Palette.woodLight, Palette.glass)
	Kit.door(t, "Door", CFrame.new(w / 4, PLINTH, -d / 2), 2.2, 3.8, Palette.roofPlum, Palette.woodLight)
	-- Sign object: a paint palette on the gable with three colour dots
	local at = Vector3.new(0, PLINTH + h + 1.2, -d / 2 - 0.65)
	t.cyl("Palette", 0.3, 2.8, CFrame.new(at) * TURN, Palette.woodLight, { shadow = false })
	for i, color in { Palette.roofRed, Palette.flowerYellow, Palette.roofTeal } do
		local a = math.rad(i * 80 + 30)
		t.ball("PaintDot", 0.6, at + Vector3.new(math.cos(a) * 0.8, math.sin(a) * 0.8, -0.2), color, { shadow = false })
	end
	-- The easel on the lawn, angled toward the street
	local easel = CFrame.new(-w / 2 - 0.6, 0, -d / 2 - 1.6) * Kit.yaw(20)
	for _, x in { -0.7, 0.7 } do
		t.block(
			"EaselLeg",
			Vector3.new(0.25, 4.4, 0.25),
			easel * CFrame.new(x, 2.1, 0) * CFrame.Angles(math.rad(-8), 0, 0),
			Palette.woodDark
		)
	end
	t.block("Canvas", Vector3.new(2.4, 2, 0.2), easel * CFrame.new(0, 3, -0.4), Palette.flowerWhite)
	t.block(
		"Painting",
		Vector3.new(1.8, 0.7, 0.1),
		easel * CFrame.new(0, 2.7, -0.55),
		Palette.grassLight,
		{ shadow = false }
	)
	t.ball("PaintSun", 0.6, easel * CFrame.new(0.5, 3.4, -0.55).Position, Palette.flowerYellow, { shadow = false })
	Kit.sproutTag(t, Vector3.new(w / 2 - 1, PLINTH + h + 1.2, d / 2 - 1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Music Hall (content bank, level 17): a plum concert hall with a cream gable, a row of
-- golden organ pipes on the roof and a big music note over the door.
TYPES.MusicHall = function(b, s)
	local w, d, h = s * 0.8, s * 0.6, 5.4
	local body = hall(b, w, d, h, Palette.plum)
	local t = b.into(body, true)
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1, d + 1, 2.6, Palette.cream)
	for i, x in { -1.2, 0, 1.2 } do
		local tall = 3 + (if i == 2 then 1.4 else 0)
		t.post("Pipe", tall, 0.8, Vector3.new(x, PLINTH + h + 2 + tall / 2, d / 4), Palette.coins)
	end
	-- Sign object: a music note (head and stem) over the door
	local note = Vector3.new(0, PLINTH + h - 1.2, -d / 2 - 0.4)
	t.ball("NoteHead", 1.2, note, Palette.cocoa, { shadow = false })
	t.block("NoteStem", Vector3.new(0.25, 2, 0.25), note + Vector3.new(0.5, 1, 0), Palette.cocoa, { shadow = false })
	Kit.door(t, "Door", CFrame.new(0, PLINTH, -d / 2), 2.6, 3.8, Palette.woodDark, Palette.cream)
	for _, x in { -w / 3, w / 3 } do
		Kit.window(t, "Window", CFrame.new(x, PLINTH + 2.8, -d / 2), 1.4, 2.2, Palette.cream, Palette.glass)
	end
	Kit.sproutTag(t, Vector3.new(-w / 2 + 1.2, PLINTH + h + 1.2, d / 2 - 1.2), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Stargazing Tower (content bank, level 18): a slim round stone tower on a small base,
-- a navy dome with a slot, and a big brass telescope poking out at the sky.
TYPES.StargazingTower = function(b, s)
	local r = s * 0.22
	b.block("Plinth", Vector3.new(s * 0.6, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, 0), Palette.stone)
	local body = b.post("Body", 9, r * 2, Vector3.new(0, PLINTH + 4.5, 0), Palette.stoneLight, { collide = true })
	local t = b.into(body, true)
	t.post("Band", 0.6, r * 2 + 0.4, Vector3.new(0, PLINTH + 9, 0), Palette.cream)
	t.ball("Dome", r * 2 + 0.2, Vector3.new(0, PLINTH + 9.3, 0), Palette.plum)
	t.block(
		"Slot",
		Vector3.new(0.8, r + 0.4, 0.3),
		CFrame.new(0, PLINTH + 10.6, -r * 0.7) * CFrame.Angles(math.rad(-30), 0, 0),
		Palette.cocoa,
		{ shadow = false }
	)
	-- Sign object: the telescope, tilted up out of the slot
	local scope = CFrame.new(0.6, PLINTH + 11.2, -r * 0.8) * CFrame.Angles(math.rad(-40), 0, 0)
	t.post("Telescope", 4, 1, scope * CFrame.new(0, 0, 0), Palette.coins)
	t.post("Lens", 0.4, 1.3, scope * CFrame.new(0, 2, 0), Palette.cream)
	-- Gold stars on the dome
	for i = 0, 2 do
		local a = math.rad(i * 120 + 30)
		t.ball(
			"Star",
			0.6,
			Vector3.new(math.cos(a) * r, PLINTH + 10.4, math.sin(a) * r),
			Palette.flowerYellow,
			{ shadow = false }
		)
	end
	Kit.door(t, "Door", CFrame.new(0, PLINTH, -r), 1.8, 3.6, Palette.woodDark, Palette.cream)
	Kit.window(t, "Window", CFrame.new(0, PLINTH + 6, -r), 1.2, 1.6, Palette.cream, Palette.glassDeep)
	Kit.bush(t, "Bush", Vector3.new(-r - 1.2, 0.3, -r), 0.9, Palette.treeTop, Palette.flowerWhite)
	Kit.sproutTag(t, Vector3.new(r + 1.2, PLINTH, r), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Rose Garden (content bank, level 19): a lawn of rose bushes around a small round glass
-- garden house with a domed glass roof, behind a rose arch on the path from the street.
TYPES.RoseGarden = function(b, s)
	local w = s * 0.85
	local body = b.block("Body", Vector3.new(w, 0.4, w), Vector3.new(0, 0.2, 0), Palette.grassLight, { collide = true })
	local t = b.into(body, true)
	t.block("Path", Vector3.new(1.8, 0.1, w / 2), Vector3.new(0, 0.45, -w / 4), Palette.path, { shadow = false })
	-- The glass house at the back of the lawn
	local back = w / 6
	t.post("Floor", 0.4, 5.4, Vector3.new(0, 0.6, back), Palette.stoneLight)
	t.post("Walls", 3.6, 4.6, Vector3.new(0, 2.6, back), Palette.glass)
	t.ball("Dome", 4.8, Vector3.new(0, 4.4, back), Palette.glass)
	t.ball("Finial", 0.6, Vector3.new(0, 6.9, back), Palette.coins, { shadow = false })
	Kit.door(t, "Door", CFrame.new(0, 0.8, back - 2.3), 1.6, 3, Palette.cream, Palette.woodLight)
	-- Sign object: a rose arch over the path, roses on the crossbar
	local arch = -w / 2 + 1
	for _, x in { -1.4, 1.4 } do
		t.block("ArchPost", Vector3.new(0.4, 4.4, 0.4), Vector3.new(x, 2.6, arch), Palette.cream)
	end
	t.block("ArchTop", Vector3.new(3.6, 0.5, 0.6), Vector3.new(0, 5, arch), Palette.leaf)
	for _, x in { -0.9, 0.9 } do
		t.ball("Rose", 0.9, Vector3.new(x, 5.4, arch - 0.2), Palette.roofRed, { shadow = false })
	end
	-- Rose bushes in the four corners
	local c = w / 2 - 1.4
	for i, at in { Vector3.new(-c, 0.4, -c), Vector3.new(c, 0.4, -c), Vector3.new(-c, 0.4, c), Vector3.new(c, 0.4, c) } do
		Kit.bush(t, "RoseBush", at, 0.9, Palette.leaf, if i % 2 == 0 then Palette.flowerPink else Palette.roofRed)
	end
	Kit.sproutTag(t, Vector3.new(c, 0.4, 0), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Seed Exchange (content bank, level 21): a sage-green market hall with a mustard gable roof,
-- a seed-sack counter out front, and a giant seed packet on the gable as its sign.
TYPES.SeedExchange = function(b, s)
	local w, d, h = s * 0.7, s * 0.55, 5
	local body = hall(b, w, d, h, Palette.leafLight:Lerp(Palette.cream, 0.4))
	local t = b.into(body, true)
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1, d + 1, 2.8, Palette.roofMustard)
	Kit.door(t, "Door", CFrame.new(w / 4, PLINTH, -d / 2), 2.2, 3.8, Palette.woodDark, Palette.cream)
	Kit.window(t, "Window", CFrame.new(-w / 4, PLINTH + 2.8, -d / 2), 2, 2, Palette.cream, Palette.glass)
	-- Sign object: a seed packet (paper, a picture band and a sprout) on the gable
	local packet = Vector3.new(0, PLINTH + h + 1.1, -d / 2 - 0.65)
	t.block("Packet", Vector3.new(2, 2.6, 0.3), packet, Palette.cream, { shadow = false })
	t.block(
		"PacketBand",
		Vector3.new(2.02, 0.9, 0.32),
		packet + Vector3.new(0, -0.5, 0),
		Palette.roofRed,
		{ shadow = false }
	)
	t.ball("PacketSeed", 0.7, packet + Vector3.new(0, 0.5, -0.2), Palette.lime, { shadow = false })
	-- The counter out front, with seed sacks on it
	local counter = Vector3.new(-w / 4, 0, -d / 2 - 1.6)
	t.block("Counter", Vector3.new(3.2, 1.4, 1.2), counter + Vector3.new(0, 0.7, 0), Palette.wood)
	for i, x in { -0.8, 0.8 } do
		t.ball("SeedSack", 1.1, counter + Vector3.new(x, 1.8, 0), if i == 1 then Palette.sack else Palette.straw)
	end
	Kit.bush(t, "Bush", Vector3.new(w / 2 + 0.8, 0.3, -d / 2 + 0.6), 0.9, Palette.treeTop, Palette.flowerYellow)
	Kit.sproutTag(t, Vector3.new(-w / 2 + 1.2, PLINTH + h + 1.2, d / 2 - 1.2), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Puppet Theatre (content bank, level 22): a little crimson theatre with a gold-trimmed gable,
-- a stage window between two drawn curtains, and a giant marionette dangling over the door.
TYPES.PuppetTheatre = function(b, s)
	local w, d, h = s * 0.72, s * 0.6, 5.6
	local body = hall(b, w, d, h, Palette.barnRed)
	local t = b.into(body, true)
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + h, 0), w + 1, d + 1, 3, Palette.plum)
	t.block("Trim", Vector3.new(w + 0.4, 0.5, d + 0.4), Vector3.new(0, PLINTH + h - 0.25, 0), Palette.coins)
	-- The stage: a cream opening framed by two curtains
	local face = -d / 2
	t.block("Stage", Vector3.new(4, 2.6, 0.3), Vector3.new(-w / 6, PLINTH + 2.6, face - 0.15), Palette.cream)
	for _, x in { -1.6, 1.6 } do
		t.block(
			"Curtain",
			Vector3.new(1, 2.8, 0.3),
			Vector3.new(-w / 6 + x, PLINTH + 2.6, face - 0.3),
			Palette.roofRed,
			{ shadow = false }
		)
	end
	Kit.door(t, "Door", CFrame.new(w / 3, PLINTH, face), 1.8, 3.6, Palette.woodDark, Palette.coins)
	-- Sign object: a marionette on strings from a crossbar on the gable
	local bar = Vector3.new(0, PLINTH + h + 1.4, face - 0.7)
	t.block("Crossbar", Vector3.new(2.4, 0.3, 0.3), bar, Palette.woodDark, { shadow = false })
	t.block("String", Vector3.new(0.08, 1.2, 0.08), bar + Vector3.new(0, -0.7, 0), Palette.cream, { shadow = false })
	t.ball("PuppetHead", 0.9, bar + Vector3.new(0, -1.6, 0), Palette.skinTan, { shadow = false })
	t.block(
		"PuppetBody",
		Vector3.new(0.9, 1.2, 0.5),
		bar + Vector3.new(0, -2.6, 0),
		Palette.flowerYellow,
		{ shadow = false }
	)
	Kit.sproutTag(t, Vector3.new(w / 2 - 1.2, PLINTH + h + 1.2, d / 2 - 1.2), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Botanical Arch (content bank, level 23): a stone garden arch wound with vines and roses,
-- flower beds either side, and a small glass dome of rare plants behind it.
TYPES.BotanicalArch = function(b, s)
	local w = s * 0.8
	local body = b.block("Body", Vector3.new(w, 0.4, w), Vector3.new(0, 0.2, 0), Palette.grassLight, { collide = true })
	local t = b.into(body, true)
	t.block("Path", Vector3.new(2, 0.1, w), Vector3.new(0, 0.45, 0), Palette.path, { shadow = false })
	-- Sign object: the arch, two stone piers and a curved top, wound with vines and roses
	local front = -w / 4
	for _, x in { -1.8, 1.8 } do
		t.block("Pier", Vector3.new(1, 5.4, 1), Vector3.new(x, 3.1, front), Palette.stoneLight)
	end
	t.cyl("ArchTop", 1, 4.6, CFrame.new(0, 5.8, front) * CFrame.Angles(0, math.rad(90), 0), Palette.stoneLight)
	t.block("Vine", Vector3.new(4.8, 0.6, 1.2), Vector3.new(0, 6.4, front), Palette.leaf, { shadow = false })
	for i, x in { -1.4, 0, 1.4 } do
		t.ball(
			"Rose",
			0.7,
			Vector3.new(x, 6.8, front - 0.4),
			if i == 2 then Palette.flowerYellow else Palette.flowerPink,
			{ shadow = false }
		)
	end
	-- The glass dome of rare plants behind the arch
	local back = w / 4
	t.post("DomeBase", 0.6, 4.4, Vector3.new(0, 0.7, back), Palette.stone)
	t.ball("Dome", 4.4, Vector3.new(0, 1.4, back), Palette.glass)
	t.ball("Palm", 2, Vector3.new(0, 2, back), Palette.treeTop, { shadow = false })
	-- Flower beds either side of the path
	for _, x in { -w / 2 + 1.2, w / 2 - 1.2 } do
		Kit.bush(t, "FlowerBed", Vector3.new(x, 0.4, front), 0.9, Palette.leafLight, Palette.flowerYellow)
	end
	Kit.sproutTag(t, Vector3.new(w / 2 - 1, 0.4, w / 2 - 1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Amphitheatre (content bank, level 24): open-air stone seating in three stepped rows facing a
-- wooden stage under a cream band shell, with a red curtain behind and the two theatre masks
-- on the shell's crown.
TYPES.Amphitheatre = function(b, s)
	local w = s * 0.85
	local body = b.block("Body", Vector3.new(w, 0.4, w), Vector3.new(0, 0.2, 0), Palette.stoneLight, { collide = true })
	local t = b.into(body, true)
	-- The seating: each row back from the stage is wider and a step higher
	for i = 1, 3 do
		local rise = 0.6 * i
		t.block(
			"Seats",
			Vector3.new(w - 3.6 + i * 1.1, rise, 1.3),
			Vector3.new(0, 0.4 + rise / 2, -1.3 * i + 0.2),
			if i == 2 then Palette.stone else Palette.stoneLight
		)
	end
	-- The stage and its band shell on two columns
	local stageZ = w / 2 - 1.9
	t.block("Stage", Vector3.new(w - 1.6, 0.8, 3.4), Vector3.new(0, 0.8, stageZ), Palette.woodLight)
	local columnX = w / 2 - 1.2
	for _, x in { -columnX, columnX } do
		t.post("Column", 3.6, 0.7, Vector3.new(x, 3, stageZ), Palette.cream)
	end
	Kit.archRoof(t, "Shell", Vector3.new(0, 4.8, stageZ), columnX * 2 + 0.7, 3.6, 2.6, 4, 0.4, Palette.cream)
	t.block(
		"Curtain",
		Vector3.new(w - 3, 3.4, 0.3),
		Vector3.new(0, 2.9, w / 2 - 0.5),
		Palette.roofRed,
		{ shadow = false }
	)
	-- Sign object: the two theatre masks on the shell's crown
	for i, x in { -0.6, 0.6 } do
		t.ball(
			"Mask",
			1,
			Vector3.new(x, 7.9, stageZ - 1.9),
			if i == 1 then Palette.cream else Palette.flowerYellow,
			{ shadow = false }
		)
	end
	Kit.sproutTag(t, Vector3.new(w / 2 - 1, 0.4, -w / 2 + 1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Sculpture Park (content bank, level 25): a lawn with a path through it, three stone plinths
-- of sculptures (a stack of stone balls, a teal ring and a tilted mustard block), a bench and a
-- clipped hedge.
TYPES.SculpturePark = function(b, s)
	local w = s * 0.8
	local body = b.block("Body", Vector3.new(w, 0.4, w), Vector3.new(0, 0.2, 0), Palette.grassLight, { collide = true })
	local t = b.into(body, true)
	t.block("Path", Vector3.new(2, 0.1, w), Vector3.new(0, 0.45, 0), Palette.path, { shadow = false })
	-- Sign object: the big ring on the front plinth by the path
	local ringAt = Vector3.new(-2.6, 0, -w / 4)
	t.block("Plinth", Vector3.new(2, 1.4, 2), ringAt + Vector3.new(0, 1.1, 0), Palette.stoneLight)
	t.cyl(
		"Ring",
		0.6,
		3.6,
		CFrame.new(ringAt + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Palette.roofTeal
	)
	t.cyl(
		"RingHole",
		0.65,
		2,
		CFrame.new(ringAt + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Palette.grassLight,
		{ shadow = false }
	)
	-- The stacked stones and the tilted block on the far plinths
	local stackAt = Vector3.new(2.6, 0, -w / 4)
	t.block("Plinth", Vector3.new(1.6, 1, 1.6), stackAt + Vector3.new(0, 0.9, 0), Palette.stone)
	for i, d in { 1.6, 1.2, 0.8 } do
		t.ball("Stone", d, stackAt + Vector3.new(0, 1.1 + i * 0.95, 0), Palette.stoneLight)
	end
	local blockAt = Vector3.new(2.6, 0, w / 4)
	t.block("Plinth", Vector3.new(1.8, 0.8, 1.8), blockAt + Vector3.new(0, 0.8, 0), Palette.stone)
	t.block(
		"Cube",
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(blockAt + Vector3.new(0, 2.2, 0)) * CFrame.Angles(math.rad(35), math.rad(45), 0),
		Palette.roofMustard
	)
	-- A bench facing the path, and a clipped hedge behind it
	local benchAt = Vector3.new(-2.6, 0, w / 4)
	t.block("Bench", Vector3.new(2.4, 0.3, 0.9), benchAt + Vector3.new(0, 1, 0), Palette.wood)
	t.block("BenchBack", Vector3.new(2.4, 0.8, 0.2), benchAt + Vector3.new(-0, 1.5, 0.45), Palette.wood)
	t.block("Hedge", Vector3.new(w - 1, 1.2, 0.9), Vector3.new(0, 1, w / 2 - 0.6), Palette.leaf)
	Kit.sproutTag(t, Vector3.new(w / 2 - 1, 0.4, -w / 2 + 1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Big Top (content bank, level 26): a round circus tent in red and cream rings on a sandy
-- ring, a pole through the peak with a pennant, and a dark entrance flap at the front.
TYPES.BigTop = function(b, s)
	local w = s * 0.85
	local body = b.block("Body", Vector3.new(w, 0.4, w), Vector3.new(0, 0.2, 0), Palette.grassLight, { collide = true })
	local t = b.into(body, true)
	t.post("Ring", 0.1, w - 0.4, Vector3.new(0, 0.45, 0), Palette.straw, { shadow = false })
	local r = w - 2
	t.post("Wall", 3.2, r, Vector3.new(0, 2, 0), Palette.roofRed)
	-- The roof: rings narrowing to the peak, red and cream in turn
	for i, d in { r + 0.6, r * 0.75, r * 0.5, r * 0.26 } do
		t.post(
			"Canvas",
			0.9,
			d,
			Vector3.new(0, 3.6 + i * 0.85, 0),
			if i % 2 == 1 then Palette.cream else Palette.roofRed
		)
	end
	t.post("Pole", 2.4, 0.3, Vector3.new(0, 8.4, 0), Palette.woodDark)
	t.block("Pennant", Vector3.new(1.2, 0.7, 0.1), Vector3.new(0.6, 9.2, 0), Palette.roofMustard, { shadow = false })
	-- Sign object: the entrance, a dark doorway with its flaps tied back in stripes
	local face = -r / 2
	t.block("Entrance", Vector3.new(2.2, 2.8, 0.4), Vector3.new(0, 1.8, face - 0.05), Palette.cocoa)
	for _, x in { -1.3, 1.3 } do
		t.wedge("Flap", Vector3.new(0.6, 2.8, 0.4), CFrame.new(x, 1.8, face - 0.3), Palette.cream)
	end
	Kit.sproutTag(t, Vector3.new(w / 2 - 1, 0.4, -w / 2 + 1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Bus Depot (content bank, level 27): a long garage under a flat teal roof with two big bay
-- doors, a yellow town bus parked out front, and a bus-stop sign by the kerb.
TYPES.BusDepot = function(b, s)
	local w, d, h = s * 0.82, s * 0.5, 4.6
	local z0 = s * 0.15
	b.block("Plinth", Vector3.new(w + 0.6, PLINTH, d + 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(w, h, d),
		Vector3.new(0, PLINTH + h / 2, z0),
		Palette.stoneLight,
		{ collide = true }
	)
	local t = b.into(body, true)
	t.block("Roof", Vector3.new(w + 0.8, 0.6, d + 0.8), Vector3.new(0, PLINTH + h + 0.3, z0), Palette.roofTeal)
	local face = z0 - d / 2
	for _, x in { -w / 4, w / 4 } do
		t.block(
			"BayDoor",
			Vector3.new(w / 2 - 1, h - 1, 0.3),
			Vector3.new(x, PLINTH + (h - 1) / 2, face - 0.1),
			Palette.cocoa
		)
	end
	-- Sign object: the town bus parked in front, a sky-blue window band and four wheels
	local bus = Vector3.new(-0.6, 0, face - 2.2)
	t.block("Bus", Vector3.new(5.6, 2.2, 1.9), bus + Vector3.new(0, 1.6, 0), Palette.roofMustard)
	t.block("BusWindows", Vector3.new(5.4, 0.7, 1.95), bus + Vector3.new(0, 2.1, 0), Palette.sky, { shadow = false })
	for _, x in { -1.8, 1.8 } do
		t.cyl("Wheel", 2, 0.9, CFrame.new(bus + Vector3.new(x, 0.45, 0)) * TURN, Palette.tire, { shadow = false })
	end
	-- The bus-stop sign by the kerb
	t.post("StopPole", 3, 0.2, Vector3.new(w / 2 - 0.6, 1.5, face - 2.4), Palette.metal)
	t.cyl("StopSign", 0.2, 1.1, CFrame.new(w / 2 - 0.6, 3.2, face - 2.4) * TURN, Palette.roofRed, { shadow = false })
	Kit.sproutTag(t, Vector3.new(w / 2 - 1, PLINTH + h + 0.6, z0 + d / 4), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Filling Station (content bank, level 28): a little red-roofed kiosk beside a canopy on four
-- posts sheltering two old-fashioned pumps, with a round sign on a pole.
TYPES.FillingStation = function(b, s)
	local w = s * 0.85
	local body = b.block("Body", Vector3.new(w, 0.4, w), Vector3.new(0, 0.2, 0), Palette.road, { collide = true })
	local t = b.into(body, true)
	-- The kiosk at the back
	local kz = w / 2 - 2
	t.block("Kiosk", Vector3.new(4.4, 3.6, 3), Vector3.new(-w / 4, 2.2, kz), Palette.cream)
	t.block("KioskRoof", Vector3.new(5, 0.6, 3.6), Vector3.new(-w / 4, 4.3, kz), Palette.roofRed)
	Kit.door(t, "Door", CFrame.new(-w / 4, 0.4, kz - 1.5), 1.4, 2.8, Palette.roofRed, Palette.cream)
	-- The canopy over the pumps
	local cz = -0.6
	for _, x in { -2.6, 2.6 } do
		for _, z in { cz - 1.6, cz + 1.6 } do
			t.post("CanopyPost", 4, 0.4, Vector3.new(x + w / 8, 2.4, z), Palette.cream)
		end
	end
	t.block("Canopy", Vector3.new(6.6, 0.6, 4.4), Vector3.new(w / 8, 4.7, cz), Palette.roofRed)
	-- Sign object: the two pumps, red with cream faces
	for _, x in { -1, 1 } do
		t.block("Pump", Vector3.new(0.9, 2, 0.7), Vector3.new(w / 8 + x * 1.2, 1.4, cz), Palette.roofRed)
		t.block(
			"PumpFace",
			Vector3.new(0.7, 0.6, 0.1),
			Vector3.new(w / 8 + x * 1.2, 1.9, cz - 0.4),
			Palette.cream,
			{ shadow = false }
		)
	end
	t.post("SignPole", 4.6, 0.3, Vector3.new(w / 2 - 0.8, 2.7, -w / 2 + 0.8), Palette.metal)
	t.cyl("Sign", 0.3, 1.6, CFrame.new(w / 2 - 0.8, 5.4, -w / 2 + 0.8) * TURN, Palette.roofMustard, { shadow = false })
	Kit.sproutTag(t, Vector3.new(-w / 2 + 1, 0.4, -w / 2 + 1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Loop Coaster (content bank, level 36): a sky-blue track climbing to a red loop over a
-- station shed, with a little train of cars waiting at the platform.
TYPES.LoopCoaster = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.85, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(3.4, 2.4, 2.2),
		Vector3.new(-s * 0.25, PLINTH + 1.2, z0 - s * 0.12),
		Palette.cream,
		{ collide = true }
	)
	local t = b.into(body, true)
	local sx, sz = -s * 0.25, z0 - s * 0.12
	t.block("StationRoof", Vector3.new(3.8, 0.3, 2.6), Vector3.new(sx, PLINTH + 2.55, sz), Palette.roofRed)
	Kit.door(t, "Door", CFrame.new(sx, PLINTH, sz - 1.1), 1.2, 1.8, Palette.roofTeal, Palette.cream)
	-- The lift hill: a sloped track on a trestle, then the loop
	t.block(
		"Track",
		Vector3.new(0.6, 0.3, s * 0.6),
		CFrame.new(s * 0.05, PLINTH + 3.2, z0) * CFrame.Angles(math.rad(25), 0, 0),
		Palette.sky
	)
	t.block("Trestle", Vector3.new(0.4, 4, 0.4), Vector3.new(s * 0.05, PLINTH + 2, z0 + s * 0.15), Palette.metal)
	local loop = Vector3.new(s * 0.28, PLINTH + 4.2, z0)
	t.cyl("Loop", 0.5, 6, CFrame.new(loop) * Kit.yaw(0), Palette.roofRed)
	t.cyl("LoopHole", 0.6, 4.8, CFrame.new(loop) * Kit.yaw(0), Palette.grassLight)
	t.block("LoopLeg", Vector3.new(0.5, 1.4, 0.5), loop - Vector3.new(0, 3.5, 0), Palette.metal)
	for i = 0, 2 do
		t.block(
			"Car",
			Vector3.new(0.9, 0.6, 0.9),
			Vector3.new(sx - 1 + i * 1, PLINTH + 0.3, sz - 2),
			if i % 2 == 0 then Palette.roofMustard else Palette.roofTeal
		)
	end
	Kit.sproutTag(t, Vector3.new(sx + 1.4, PLINTH + 3.2, sz), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Pet Parlor (content bank, level 38): a pink shop with a big paw-print sign, a bone over
-- the door, a doghouse beside it and a little fenced run out front.
TYPES.PetParlor = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.8, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.5, 4.2, s * 0.32),
		Vector3.new(-s * 0.08, PLINTH + 2.1, z0 + s * 0.08),
		Palette.flowerPink:Lerp(Palette.cream, 0.4),
		{ collide = true }
	)
	local t = b.into(body, true)
	local bx, face = -s * 0.08, z0 + s * 0.08 - s * 0.16
	Kit.gableRoof(
		t,
		"Roof",
		Vector3.new(bx, PLINTH + 4.2, z0 + s * 0.08),
		s * 0.54,
		s * 0.36,
		1.8,
		Palette.roofPlum,
		Palette.cream
	)
	Kit.door(t, "Door", CFrame.new(bx + s * 0.1, PLINTH, face), 1.4, 2.6, Palette.roofTeal, Palette.cream)
	Kit.window(t, "Window", CFrame.new(bx - s * 0.1, PLINTH + 2, face), 1.8, 1.4, Palette.cream, Palette.glass)
	-- The paw sign: a pad and three toes
	t.ball("Paw", 1.1, Vector3.new(bx, PLINTH + 3.7, face - 0.1), Palette.cocoa)
	for i = -1, 1 do
		t.ball("Toe", 0.5, Vector3.new(bx + i * 0.55, PLINTH + 4.4, face - 0.1), Palette.cocoa)
	end
	-- Doghouse and the fenced run
	t.block("Doghouse", Vector3.new(1.6, 1.3, 1.6), Vector3.new(s * 0.28, PLINTH + 0.65, z0 + s * 0.1), Palette.roofRed)
	t.wedge("DogRoof", Vector3.new(1.8, 0.7, 1.8), CFrame.new(s * 0.28, PLINTH + 1.65, z0 + s * 0.1), Palette.wood)
	t.block("Fence", Vector3.new(s * 0.7, 0.6, 0.2), Vector3.new(0, PLINTH + 0.3, z0 - s * 0.25), Palette.cream)
	Kit.sproutTag(t, Vector3.new(bx - s * 0.18, PLINTH + 5.4, z0 + s * 0.1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Sports Arena (content bank, level 37): an open oval stand of seats around a green pitch,
-- floodlights on two masts, and a ticket gate at the front.
TYPES.SportsArena = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.85, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.7, 2.4, 1.6),
		Vector3.new(0, PLINTH + 1.2, z0 + s * 0.2),
		Palette.cream,
		{ collide = true }
	)
	local t = b.into(body, true)
	-- The pitch, with the side stands and the low front wall
	t.block(
		"Pitch",
		Vector3.new(s * 0.56, 0.2, s * 0.3),
		Vector3.new(0, PLINTH + 0.1, z0 - s * 0.02),
		Palette.grassLight
	)
	t.block("Stripe", Vector3.new(0.3, 0.22, s * 0.3), Vector3.new(0, PLINTH + 0.12, z0 - s * 0.02), Palette.cream)
	for _, x in { -1, 1 } do
		t.wedge(
			"Stand",
			Vector3.new(s * 0.32, 2, 1.6),
			CFrame.new(x * s * 0.35, PLINTH + 1, z0 - s * 0.02) * Kit.yaw(x * 90),
			Palette.roofTeal
		)
		t.block("Mast", Vector3.new(0.4, 6, 0.4), Vector3.new(x * s * 0.38, PLINTH + 3, z0 + s * 0.22), Palette.metal)
		t.block(
			"Lights",
			Vector3.new(1.6, 0.8, 0.4),
			Vector3.new(x * s * 0.38, PLINTH + 6.2, z0 + s * 0.2),
			Palette.cream
		)
	end
	t.block("FrontWall", Vector3.new(s * 0.56, 0.8, 0.3), Vector3.new(0, PLINTH + 0.4, z0 - s * 0.2), Palette.roofRed)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, z0 - s * 0.21), 1.4, 2, Palette.roofMustard, Palette.cream)
	t.ball("Ball", 0.6, Vector3.new(s * 0.08, PLINTH + 0.5, z0), Palette.cream)
	Kit.sproutTag(t, Vector3.new(s * 0.3, PLINTH + 3.2, z0 + s * 0.2), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Sky Wheel (content bank, level 35): a big wheel on two splayed legs over a ticket booth,
-- its rim ringed with coloured gondolas.
TYPES.SkyWheel = function(b, s)
	local z0 = s * 0.15
	local r = s * 0.36
	local hub = PLINTH + r + 1.4
	b.block("Plinth", Vector3.new(s * 0.8, PLINTH, s * 0.4), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(2.6, 2.2, 1.8),
		Vector3.new(0, PLINTH + 1.1, z0 - 1.6),
		Palette.cream,
		{ collide = true }
	)
	local t = b.into(body, true)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, z0 - 2.5), 1.2, 1.8, Palette.flowerPink, Palette.cream)
	for _, x in { -1, 1 } do
		t.block(
			"Leg",
			Vector3.new(0.5, hub - PLINTH, 0.5),
			CFrame.new(x * r * 0.35, PLINTH + (hub - PLINTH) / 2, z0 + 0.6) * CFrame.Angles(0, 0, math.rad(x * 14)),
			Palette.metal
		)
	end
	-- The rim and the hub (a thin wheel facing the street)
	t.cyl("Rim", 0.4, r * 2, CFrame.new(0, hub, z0) * Kit.yaw(90), Palette.flowerPink)
	t.cyl("Spokes", 0.5, r * 1.6, CFrame.new(0, hub, z0) * Kit.yaw(90), Palette.cream)
	t.cyl("Hub", 0.8, 1, CFrame.new(0, hub, z0) * Kit.yaw(90), Palette.metal)
	local colors =
		{ Palette.roofTeal, Palette.roofMustard, Palette.sky, Palette.roofRed, Palette.lime, Palette.roofPlum }
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		t.block(
			"Gondola",
			Vector3.new(1, 0.9, 1),
			Vector3.new(math.cos(a) * r, hub + math.sin(a) * r - 0.5, z0 - 0.4),
			colors[i + 1]
		)
	end
	Kit.sproutTag(t, Vector3.new(1.6, PLINTH + 2.8, z0 - 1.6), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Signal Tower (content bank, level 34): a tall red and white lattice mast on a concrete
-- equipment hut, a dish halfway up and a light at the top.
TYPES.SignalTower = function(b, s)
	local w, d, h = s * 0.45, s * 0.4, 4
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.7, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(w, h, d),
		Vector3.new(0, PLINTH + h / 2, z0 + d / 4),
		Palette.stoneLight,
		{ collide = true }
	)
	local t = b.into(body, true)
	local face = z0 + d / 4 - d / 2
	t.block("Roof", Vector3.new(w + 0.4, 0.4, d + 0.4), Vector3.new(0, PLINTH + h + 0.2, z0 + d / 4), Palette.stoneDark)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, face), 1.6, 2.6, Palette.roofRed, Palette.metal)
	-- The mast in bands of red and white, narrowing as it climbs
	local base = PLINTH + h + 0.4
	for i = 0, 3 do
		t.block(
			"Mast",
			Vector3.new(1.4 - i * 0.25, 3, 1.4 - i * 0.25),
			Vector3.new(0, base + 1.5 + i * 3, z0 + d / 4),
			if i % 2 == 0 then Palette.roofRed else Palette.cream
		)
	end
	t.cyl("Dish", 0.3, 1.8, CFrame.new(0.9, base + 5, z0 + d / 4) * CFrame.Angles(0, 0, math.rad(90)), Palette.cream)
	t.ball("Beacon", 0.7, Vector3.new(0, base + 12.4, z0 + d / 4), Palette.roofRed, { shadow = false })
	Kit.sproutTag(t, Vector3.new(w / 2 - 0.6, PLINTH + h + 0.6, z0), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Broadcast Studio (content bank, level 33): a two-storey studio block with a red "on air"
-- lamp over the door, a satellite dish on the roof and a lattice aerial with a red tip.
TYPES.BroadcastStudio = function(b, s)
	local w, d, h = s * 0.7, s * 0.5, 7
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(w + 0.6, PLINTH, d + 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(w, h, d),
		Vector3.new(0, PLINTH + h / 2, z0),
		Palette.stoneLight,
		{ collide = true }
	)
	local t = b.into(body, true)
	local face = z0 - d / 2
	t.block("Band", Vector3.new(w + 0.2, 0.5, d + 0.2), Vector3.new(0, PLINTH + 3.5, z0), Palette.roofTeal)
	t.block("Roof", Vector3.new(w + 0.5, 0.5, d + 0.5), Vector3.new(0, PLINTH + h + 0.25, z0), Palette.stoneDark)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, face), 2, 2.6, Palette.roofTeal, Palette.metal)
	t.block(
		"OnAir",
		Vector3.new(1.8, 0.6, 0.2),
		Vector3.new(0, PLINTH + 3.1, face - 0.1),
		Palette.roofRed,
		{ shadow = false }
	)
	Kit.window(t, "Window", CFrame.new(-w / 3, PLINTH + 5, face), 2, 1.4, Palette.cream, Palette.glass)
	Kit.window(t, "Window", CFrame.new(w / 3, PLINTH + 5, face), 2, 1.4, Palette.cream, Palette.glass)
	-- Sign object: the dish and the aerial on the roof
	t.post("DishPost", 1, 0.3, Vector3.new(-w / 4, PLINTH + h + 1, z0), Palette.metal)
	t.cyl("Dish", 0.3, 2.4, CFrame.new(-w / 4, PLINTH + h + 1.9, z0) * CFrame.Angles(0, 0, math.rad(60)), Palette.cream)
	t.post("Aerial", 5, 0.3, Vector3.new(w / 4, PLINTH + h + 2.5, z0 + d / 6), Palette.metal)
	t.ball("AerialTip", 0.6, Vector3.new(w / 4, PLINTH + h + 5.2, z0 + d / 6), Palette.roofRed, { shadow = false })
	Kit.sproutTag(t, Vector3.new(w / 2 - 1, PLINTH + h + 0.6, z0 - d / 4), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Grand Hotel (content bank, level 32): a wide four-storey hotel in cream and red, a gold-
-- trimmed entrance canopy over the steps, and a tall roof sign.
TYPES.GrandHotel = function(b, s)
	local w, d, h = s * 0.8, s * 0.5, 10
	local z0 = s * 0.12
	b.block("Plinth", Vector3.new(w + 0.6, PLINTH, d + 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body =
		b.block("Body", Vector3.new(w, h, d), Vector3.new(0, PLINTH + h / 2, z0), Palette.cream, { collide = true })
	local t = b.into(body, true)
	local face = z0 - d / 2
	-- Red floor bands
	for _, y in { 3.4, 6.6 } do
		t.block("Band", Vector3.new(w + 0.2, 0.5, d + 0.2), Vector3.new(0, PLINTH + y, z0), Palette.roofRed)
	end
	t.block("Roof", Vector3.new(w + 0.6, 0.6, d + 0.6), Vector3.new(0, PLINTH + h + 0.3, z0), Palette.roofRed)
	-- The entrance canopy and steps
	t.block("Canopy", Vector3.new(4, 0.4, 2.4), Vector3.new(0, PLINTH + 3, face - 1.2), Palette.coins)
	t.block("Steps", Vector3.new(3.4, 0.5, 1.4), Vector3.new(0, PLINTH + 0.25, face - 0.7), Palette.stoneLight)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, face), 2.2, 2.8, Palette.roofRed, Palette.coins)
	Kit.window(t, "Window", CFrame.new(-w / 3, PLINTH + 5, face), 2.2, 1.6, Palette.cream, Palette.glass)
	Kit.window(t, "Window", CFrame.new(w / 3, PLINTH + 5, face), 2.2, 1.6, Palette.cream, Palette.glass)
	-- Sign object: the roof sign on two legs
	for _, x in { -1.6, 1.6 } do
		t.block("SignLeg", Vector3.new(0.3, 1.4, 0.3), Vector3.new(x, PLINTH + h + 1.3, face + 0.6), Palette.metal)
	end
	t.block(
		"RoofSign",
		Vector3.new(4.4, 1.2, 0.3),
		Vector3.new(0, PLINTH + h + 2.4, face + 0.6),
		Palette.roofRed,
		{ shadow = false }
	)
	Kit.sproutTag(t, Vector3.new(-w / 2 + 1, PLINTH + h + 0.6, z0 + d / 4), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Office Block (content bank, level 31): a tall glass-banded tower on a stone base, a flat
-- roof with a water tank, and a revolving-door porch with a flagpole.
TYPES.OfficeBlock = function(b, s)
	local w, d, h = s * 0.55, s * 0.55, 11
	b.block("Plinth", Vector3.new(w + 1.2, PLINTH, d + 1.2), Vector3.new(0, PLINTH / 2, 0), Palette.stone)
	local body =
		b.block("Body", Vector3.new(w, h, d), Vector3.new(0, PLINTH + h / 2, 0), Palette.stoneLight, { collide = true })
	local t = b.into(body, true)
	local face = -d / 2
	-- Glass bands across the front, two floors apart
	for _, y in { 4, 7.4 } do
		t.block(
			"Band",
			Vector3.new(w - 0.6, 1.6, 0.2),
			Vector3.new(0, PLINTH + y, face - 0.1),
			Palette.glassDeep,
			{ shadow = false }
		)
	end
	t.block("Roof", Vector3.new(w + 0.4, 0.5, d + 0.4), Vector3.new(0, PLINTH + h + 0.25, 0), Palette.stoneDark)
	t.post("Tank", 1.8, 1.6, Vector3.new(w / 4, PLINTH + h + 1.4, d / 4), Palette.wood)
	t.block("TankLid", Vector3.new(1.8, 0.3, 1.8), Vector3.new(w / 4, PLINTH + h + 2.45, d / 4), Palette.roofTeal)
	-- The porch with its door
	t.block("Porch", Vector3.new(3.4, 3, 1.6), Vector3.new(0, PLINTH + 1.5, face - 0.8), Palette.roofTeal)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, face - 1.6), 1.8, 2.6, Palette.glass, Palette.metal)
	-- Sign object: the flagpole and flag by the porch
	t.post("Flagpole", 7, 0.2, Vector3.new(w / 2 + 0.6, 3.5, face - 1), Palette.metal)
	t.block(
		"Flag",
		Vector3.new(1.6, 1, 0.1),
		Vector3.new(w / 2 + 1.4, 6.4, face - 1),
		Palette.roofRed,
		{ shadow = false }
	)
	Kit.sproutTag(t, Vector3.new(-w / 4, PLINTH + h + 0.6, d / 4), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Open-Air Cinema (content bank, level 30): a big white screen on dark posts at the back, a
-- little ticket booth with a striped roof, and a row of speaker posts out front.
TYPES.OpenAirCinema = function(b, s)
	local w = s * 0.85
	local body = b.block("Body", Vector3.new(w, 0.4, w), Vector3.new(0, 0.2, 0), Palette.grass, { collide = true })
	local t = b.into(body, true)
	-- Sign object: the screen, a cream face in a dark frame on two posts
	local sz = w / 2 - 1
	for _, x in { -w / 3, w / 3 } do
		t.post("ScreenPost", 7, 0.5, Vector3.new(x, 3.9, sz), Palette.woodDark)
	end
	t.block("ScreenFrame", Vector3.new(w * 0.72, 4.4, 0.4), Vector3.new(0, 5.2, sz), Palette.stoneDark)
	t.block(
		"Screen",
		Vector3.new(w * 0.66, 3.8, 0.2),
		Vector3.new(0, 5.2, sz - 0.25),
		Palette.cream,
		{ shadow = false }
	)
	-- The ticket booth at the front corner
	local booth = Vector3.new(-w / 2 + 2, 0, -w / 2 + 2)
	t.block("Booth", Vector3.new(2.6, 3, 2.6), booth + Vector3.new(0, 1.9, 0), Palette.roofRed)
	t.block("BoothRoof", Vector3.new(3.2, 0.5, 3.2), booth + Vector3.new(0, 3.65, 0), Palette.cream)
	Kit.window(t, "Window", CFrame.new(booth + Vector3.new(0, 2.2, -1.3)), 1.6, 1, Palette.cream, Palette.glass)
	-- Speaker posts in a row, where the cars park
	for _, x in { -1, 1.5, 4 } do
		t.post("Speaker", 1.6, 0.25, Vector3.new(x, 1.2, -0.5), Palette.metal)
		t.block(
			"SpeakerBox",
			Vector3.new(0.6, 0.5, 0.4),
			Vector3.new(x, 2.2, -0.5),
			Palette.stoneDark,
			{ shadow = false }
		)
	end
	Kit.sproutTag(t, Vector3.new(w / 2 - 1, 0.4, -w / 2 + 1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Cab Stand (content bank, level 29): a little dispatch booth under a striped awning, a
-- yellow cab with a roof light waiting at the kerb, and a tall checkered sign.
TYPES.CabStand = function(b, s)
	local w = s * 0.85
	local body = b.block("Body", Vector3.new(w, 0.4, w), Vector3.new(0, 0.2, 0), Palette.road, { collide = true })
	local t = b.into(body, true)
	-- The booth at the back
	local bz = w / 2 - 2.2
	t.block("Booth", Vector3.new(4, 3.6, 3.2), Vector3.new(-w / 4, 2.2, bz), Palette.cream)
	t.block("BoothRoof", Vector3.new(4.6, 0.5, 3.8), Vector3.new(-w / 4, 4.25, bz), Palette.roofTeal)
	t.block(
		"Awning",
		Vector3.new(4.2, 0.3, 1.4),
		CFrame.new(-w / 4, 3.4, bz - 2.2) * CFrame.Angles(math.rad(18), 0, 0),
		Palette.roofMustard,
		{ shadow = false }
	)
	Kit.window(t, "Window", CFrame.new(-w / 4, 2.4, bz - 1.6), 2.4, 1.4, Palette.cream, Palette.glass)
	-- Sign object: the cab, yellow with a dark window band, a roof light and four wheels
	local cab = Vector3.new(w / 8, 0, -0.8)
	t.block("Cab", Vector3.new(4.2, 1.4, 2), cab + Vector3.new(0, 1.2, 0), Palette.roofMustard)
	t.block("CabTop", Vector3.new(2.4, 0.9, 1.9), cab + Vector3.new(-0.2, 2.35, 0), Palette.roofMustard)
	t.block(
		"CabWindows",
		Vector3.new(2.2, 0.6, 1.95),
		cab + Vector3.new(-0.2, 2.35, 0),
		Palette.glassDeep,
		{ shadow = false }
	)
	t.block(
		"RoofLight",
		Vector3.new(0.8, 0.35, 0.5),
		cab + Vector3.new(-0.2, 2.95, 0),
		Palette.cream,
		{ shadow = false }
	)
	for _, x in { -1.3, 1.3 } do
		t.cyl("Wheel", 2.1, 0.8, CFrame.new(cab + Vector3.new(x, 0.4, 0)) * TURN, Palette.tire, { shadow = false })
	end
	-- The checkered sign on its pole
	local pole = Vector3.new(w / 2 - 0.8, 0, -w / 2 + 0.8)
	t.post("SignPole", 4.6, 0.3, pole + Vector3.new(0, 2.7, 0), Palette.metal)
	t.block("Sign", Vector3.new(1.8, 1, 0.2), pole + Vector3.new(0, 5.3, 0), Palette.roofMustard, { shadow = false })
	t.block("Checks", Vector3.new(1.85, 0.3, 0.22), pole + Vector3.new(0, 5.3, 0), Palette.tire, { shadow = false })
	Kit.sproutTag(t, Vector3.new(-w / 2 + 1, 0.4, -w / 2 + 1), 2.5, Palette.wood, Palette.lime)
	return body
end

ArtCommunity.TYPES = {} :: { string }
for id in TYPES do
	table.insert(ArtCommunity.TYPES, id)
end
table.sort(ArtCommunity.TYPES)

-- Weather Station (content bank, level 39): a white hut with a lattice mast beside it, the
-- mast topped by a radar dome, a wind vane and a spinning-cup anemometer, and a striped
-- windsock on a pole out front.
TYPES.WeatherStation = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.8, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.42, 4, s * 0.34),
		Vector3.new(-s * 0.12, PLINTH + 2, z0 + s * 0.06),
		Palette.cream,
		{ collide = true }
	)
	local t = b.into(body, true)
	local bx, face = -s * 0.12, z0 + s * 0.06 - s * 0.17
	t.block("Roof", Vector3.new(s * 0.46, 0.5, s * 0.38), Vector3.new(bx, PLINTH + 4.25, z0 + s * 0.06), Palette.sky)
	Kit.door(t, "Door", CFrame.new(bx + s * 0.08, PLINTH, face), 1.4, 2.8, Palette.sky, Palette.cream)
	Kit.window(t, "Window", CFrame.new(bx - s * 0.09, PLINTH + 2.2, face), 1.8, 1.4, Palette.cream, Palette.glass)
	-- The mast: a tall post, a radar dome on top, a vane and the anemometer's cups
	local mx, mz = s * 0.22, z0 + s * 0.1
	t.post("Mast", 9, 0.6, Vector3.new(mx, PLINTH + 4.5, mz), Palette.stoneLight)
	t.ball("Radar", 2.2, Vector3.new(mx, PLINTH + 9.6, mz), Palette.cream)
	t.block("Vane", Vector3.new(2.4, 0.2, 0.2), Vector3.new(mx, PLINTH + 7.6, mz), Palette.roofRed)
	t.block("CupArm", Vector3.new(0.15, 0.15, 2.2), Vector3.new(mx, PLINTH + 8.3, mz), Palette.stoneDark)
	for _, dz in { -1.1, 1.1 } do
		t.ball("Cup", 0.6, Vector3.new(mx, PLINTH + 8.3, mz + dz), Palette.sky)
	end
	-- The windsock out front
	t.post("SockPole", 3, 0.25, Vector3.new(s * 0.3, PLINTH + 1.5, z0 - s * 0.22), Palette.stoneLight)
	t.block(
		"Windsock",
		Vector3.new(1.6, 0.5, 0.5),
		Vector3.new(s * 0.3 - 0.9, PLINTH + 2.8, z0 - s * 0.22),
		Palette.carrot
	)
	Kit.sproutTag(t, Vector3.new(bx - s * 0.12, PLINTH + 5.2, z0 + s * 0.1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Skydiving School (content bank, level 40): a sky-blue clubhouse beside a jump tower with a
-- railed platform, a striped parachute canopy floating above the field and a red-and-white
-- landing target on the grass.
TYPES.SkydivingSchool = function(b, s)
	local z0 = s * 0.1
	local up = CFrame.Angles(0, 0, math.rad(90)) -- a Kit cylinder standing upright
	b.block("Plinth", Vector3.new(s * 0.8, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.4, 3.8, s * 0.3),
		Vector3.new(-s * 0.16, PLINTH + 1.9, z0 + s * 0.1),
		Palette.sky:Lerp(Palette.cream, 0.35),
		{ collide = true }
	)
	local t = b.into(body, true)
	local bx, face = -s * 0.16, z0 + s * 0.1 - s * 0.15
	Kit.gableRoof(
		t,
		"Roof",
		Vector3.new(bx, PLINTH + 3.8, z0 + s * 0.1),
		s * 0.44,
		s * 0.34,
		1.6,
		Palette.roofMustard,
		Palette.cream
	)
	Kit.door(t, "Door", CFrame.new(bx + s * 0.08, PLINTH, face), 1.4, 2.8, Palette.roofMustard, Palette.cream)
	Kit.window(t, "Window", CFrame.new(bx - s * 0.08, PLINTH + 2.1, face), 1.8, 1.4, Palette.cream, Palette.glass)
	-- The jump tower: two legs, a platform with its rail
	local tx, tz = s * 0.2, z0 + s * 0.12
	for _, dx in { -0.9, 0.9 } do
		t.post("TowerLeg", 6, 0.4, Vector3.new(tx + dx, PLINTH + 3, tz), Palette.stoneLight)
	end
	t.block("Platform", Vector3.new(2.6, 0.3, 2.2), Vector3.new(tx, PLINTH + 6.15, tz), Palette.wood)
	t.block("TowerRail", Vector3.new(2.6, 0.6, 0.15), Vector3.new(tx, PLINTH + 6.6, tz + 1.05), Palette.roofRed)
	-- The parachute: a wide canopy, its crown and a jumper hanging under it
	local px, pz = s * 0.05, z0 - s * 0.05
	t.cyl("Canopy", 0.5, 4.4, CFrame.new(px, PLINTH + 10, pz) * up, Palette.roofRed)
	t.cyl("CanopyCrown", 0.5, 2.4, CFrame.new(px, PLINTH + 10.45, pz) * up, Palette.cream)
	t.block("Jumper", Vector3.new(0.6, 1, 0.6), Vector3.new(px, PLINTH + 7.6, pz), Palette.roofMustard)
	-- The landing target on the grass in front
	t.cyl("Target", 0.1, 3.4, CFrame.new(s * 0.18, PLINTH + 0.05, z0 - s * 0.2) * up, Palette.cream)
	t.cyl("TargetEye", 0.12, 1.4, CFrame.new(s * 0.18, PLINTH + 0.07, z0 - s * 0.2) * up, Palette.roofRed)
	Kit.sproutTag(t, Vector3.new(bx - s * 0.12, PLINTH + 5.2, z0 + s * 0.15), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Comic Shop (content bank, level 41): a bright yellow corner shop with a big shop window, a
-- red awning, a starburst speech-bubble sign on the roof and a spinner rack out front.
TYPES.ComicShop = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.8, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.56, 5, s * 0.34),
		Vector3.new(0, PLINTH + 2.5, z0 + s * 0.08),
		Palette.flowerYellow,
		{ collide = true }
	)
	local t = b.into(body, true)
	local face = z0 + s * 0.08 - s * 0.17
	t.block("Roof", Vector3.new(s * 0.6, 0.5, s * 0.38), Vector3.new(0, PLINTH + 5.25, z0 + s * 0.08), Palette.roofPlum)
	-- The shop front: a wide window under a striped awning, the door to one side
	t.block(
		"ShopWindow",
		Vector3.new(s * 0.3, 2.4, 0.2),
		Vector3.new(-s * 0.08, PLINTH + 1.9, face - 0.05),
		Palette.glass
	)
	for i = 0, 3 do
		t.block(
			"Awning",
			Vector3.new(s * 0.08, 0.2, 1.4),
			CFrame.new(-s * 0.2 + i * s * 0.08, PLINTH + 3.6, face - 0.6) * CFrame.Angles(math.rad(-18), 0, 0),
			if i % 2 == 0 then Palette.roofRed else Palette.cream,
			{ shadow = false }
		)
	end
	Kit.door(t, "Door", CFrame.new(s * 0.18, PLINTH, face), 1.4, 2.8, Palette.roofPlum, Palette.cream)
	-- The roof sign: a starburst bubble with a little tail
	t.ball("Bubble", 2.6, Vector3.new(0, PLINTH + 7, face + 0.8), Palette.cream)
	t.block("Burst", Vector3.new(3.2, 0.9, 0.3), Vector3.new(0, PLINTH + 7, face - 0.4), Palette.roofRed)
	t.wedge("BubbleTail", Vector3.new(0.3, 0.8, 0.8), CFrame.new(0.9, PLINTH + 5.7, face + 0.8), Palette.cream)
	-- A spinner rack of comics by the door
	t.post("Rack", 2, 0.25, Vector3.new(s * 0.3, PLINTH + 1, face - 1.2), Palette.stoneDark)
	t.block("Comics", Vector3.new(0.9, 1, 0.9), Vector3.new(s * 0.3, PLINTH + 1.4, face - 1.2), Palette.sky)
	Kit.sproutTag(t, Vector3.new(-s * 0.22, PLINTH + 6, z0 + s * 0.15), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Lifeboat Station (content bank, level 42): a white boathouse with a red roof, a lookout
-- tower with a lamp room, an orange lifeboat on its launch ramp and a life ring on the wall.
TYPES.LifeboatStation = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.8, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.44, 4, s * 0.34),
		Vector3.new(-s * 0.1, PLINTH + 2, z0 + s * 0.08),
		Palette.cream,
		{ collide = true }
	)
	local t = b.into(body, true)
	local bx, face = -s * 0.1, z0 + s * 0.08 - s * 0.17
	Kit.gableRoof(
		t,
		"Roof",
		Vector3.new(bx, PLINTH + 4, z0 + s * 0.08),
		s * 0.48,
		s * 0.38,
		1.8,
		Palette.roofRed,
		Palette.cream
	)
	-- The big boat doors and the life ring beside them
	t.block("BoatDoor", Vector3.new(3, 3, 0.2), Vector3.new(bx - s * 0.05, PLINTH + 1.5, face - 0.05), Palette.sky)
	t.cyl("LifeRing", 0.3, 1.2, CFrame.new(bx + s * 0.14, PLINTH + 2.6, face - 0.15) * Kit.yaw(90), Palette.carrot)
	-- The lookout tower: a stone column, a glass lamp room and a little cap
	local tx, tz = s * 0.22, z0 + s * 0.12
	t.block("Tower", Vector3.new(2, 7, 2), Vector3.new(tx, PLINTH + 3.5, tz), Palette.cream)
	t.block("TowerBand", Vector3.new(2.1, 0.8, 2.1), Vector3.new(tx, PLINTH + 5, tz), Palette.roofRed)
	t.block("LampRoom", Vector3.new(1.6, 1.4, 1.6), Vector3.new(tx, PLINTH + 7.7, tz), Palette.glass)
	t.wedge("TowerCap", Vector3.new(2, 0.9, 2), CFrame.new(tx, PLINTH + 8.85, tz), Palette.roofRed)
	-- The lifeboat on its ramp in front of the doors
	t.block("Ramp", Vector3.new(2.6, 0.2, 3), Vector3.new(bx - s * 0.05, PLINTH + 0.1, face - 1.6), Palette.wood)
	t.block("Lifeboat", Vector3.new(1.8, 1, 2.6), Vector3.new(bx - s * 0.05, PLINTH + 0.7, face - 1.6), Palette.carrot)
	t.block(
		"Gunwale",
		Vector3.new(1.9, 0.25, 2.7),
		Vector3.new(bx - s * 0.05, PLINTH + 1.25, face - 1.6),
		Palette.cream
	)
	Kit.sproutTag(t, Vector3.new(bx - s * 0.14, PLINTH + 5.6, z0 + s * 0.12), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Grocery Store (content bank, level 43): a wide shop with a glass front under a green
-- awning, a flat roof with a big sign, crates of produce out front and a shopping trolley.
TYPES.GroceryStore = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.85, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.66, 4.4, s * 0.36),
		Vector3.new(0, PLINTH + 2.2, z0 + s * 0.08),
		Palette.cream,
		{ collide = true }
	)
	local t = b.into(body, true)
	local face = z0 + s * 0.08 - s * 0.18
	t.block("Roof", Vector3.new(s * 0.7, 0.5, s * 0.4), Vector3.new(0, PLINTH + 4.65, z0 + s * 0.08), Palette.leaf)
	t.block("SignBoard", Vector3.new(s * 0.4, 1.4, 0.3), Vector3.new(0, PLINTH + 5.6, face + 0.3), Palette.leaf)
	t.block("SignFace", Vector3.new(s * 0.34, 0.9, 0.1), Vector3.new(0, PLINTH + 5.6, face + 0.12), Palette.cream)
	t.block(
		"GlassFront",
		Vector3.new(s * 0.5, 2.6, 0.2),
		Vector3.new(-s * 0.04, PLINTH + 1.6, face - 0.05),
		Palette.glass
	)
	t.block(
		"Awning",
		Vector3.new(s * 0.62, 0.25, 1.6),
		CFrame.new(0, PLINTH + 3.4, face - 0.7) * CFrame.Angles(math.rad(-15), 0, 0),
		Palette.leaf
	)
	Kit.door(t, "Door", CFrame.new(s * 0.25, PLINTH, face), 1.6, 2.8, Palette.glass, Palette.cream)
	-- Produce crates and a trolley out front
	for i, color in { Palette.roofRed, Palette.flowerYellow, Palette.carrot } do
		t.block(
			"Crate",
			Vector3.new(1.1, 0.7, 0.9),
			Vector3.new(-s * 0.26 + (i - 1) * 1.3, PLINTH + 0.35, face - 1.3),
			Palette.wood
		)
		t.ball("Produce", 0.8, Vector3.new(-s * 0.26 + (i - 1) * 1.3, PLINTH + 0.85, face - 1.3), color)
	end
	t.block("Trolley", Vector3.new(1, 0.9, 1.4), Vector3.new(s * 0.33, PLINTH + 0.75, face - 1.4), Palette.stoneLight)
	Kit.sproutTag(t, Vector3.new(-s * 0.26, PLINTH + 5.4, z0 + s * 0.15), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Glasshouse (content bank, level 44): a big glass-paned conservatory on a brick base, a
-- glass lantern roof along its ridge, tall palms inside and planters at the door.
TYPES.Glasshouse = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.85, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.62, 1.2, s * 0.4),
		Vector3.new(0, PLINTH + 0.6, z0 + s * 0.05),
		Palette.brick,
		{ collide = true }
	)
	local t = b.into(body, true)
	local face = z0 + s * 0.05 - s * 0.2
	t.block("Glass", Vector3.new(s * 0.6, 3.6, s * 0.38), Vector3.new(0, PLINTH + 3, z0 + s * 0.05), Palette.glass)
	t.block("Frame", Vector3.new(s * 0.62, 0.3, s * 0.4), Vector3.new(0, PLINTH + 4.95, z0 + s * 0.05), Palette.cream)
	Kit.gableRoof(
		t,
		"Roof",
		Vector3.new(0, PLINTH + 5.1, z0 + s * 0.05),
		s * 0.62,
		s * 0.4,
		2,
		Palette.glassDeep,
		Palette.cream
	)
	for _, x in { -s * 0.15, 0, s * 0.15 } do
		t.block("Mullion", Vector3.new(0.25, 3.6, 0.25), Vector3.new(x, PLINTH + 3, face - 0.02), Palette.cream)
	end
	-- Palms growing inside, poking up toward the roof
	for _, x in { -s * 0.18, s * 0.18 } do
		t.ball("Palm", 2.4, Vector3.new(x, PLINTH + 4.2, z0 + s * 0.08), Palette.treeTop)
	end
	Kit.door(t, "Door", CFrame.new(s * 0.08, PLINTH + 1.2, face), 1.6, 2.6, Palette.cream, Palette.glass)
	for _, x in { -s * 0.3, s * 0.3 } do
		t.block("Planter", Vector3.new(1.4, 0.7, 1), Vector3.new(x, PLINTH + 0.35, face - 1), Palette.wood)
		t.ball("Bloom", 1.1, Vector3.new(x, PLINTH + 0.95, face - 1), Palette.flowerPink)
	end
	Kit.sproutTag(t, Vector3.new(-s * 0.26, PLINTH + 6, z0 + s * 0.15), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Splash Park (content bank, level 45): a pool deck with a blue pool, a tall slide tower
-- whose tube curls down into the water, a mushroom fountain and a ticket hut.
TYPES.SplashPark = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.85, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.26, 3, s * 0.2),
		Vector3.new(-s * 0.26, PLINTH + 1.5, z0 - s * 0.12),
		Palette.cream,
		{ collide = true }
	)
	local t = b.into(body, true)
	t.block(
		"HutRoof",
		Vector3.new(s * 0.3, 0.4, s * 0.24),
		Vector3.new(-s * 0.26, PLINTH + 3.2, z0 - s * 0.12),
		Palette.roofTeal
	)
	Kit.door(t, "Door", CFrame.new(-s * 0.26, PLINTH, z0 - s * 0.22), 1.4, 2.4, Palette.roofTeal, Palette.cream)
	-- The pool and its rim
	t.block(
		"PoolRim",
		Vector3.new(s * 0.5, 0.4, s * 0.34),
		Vector3.new(s * 0.12, PLINTH + 0.2, z0 + s * 0.06),
		Palette.cream
	)
	t.block(
		"Water",
		Vector3.new(s * 0.44, 0.42, s * 0.28),
		Vector3.new(s * 0.12, PLINTH + 0.22, z0 + s * 0.06),
		Palette.glassDeep
	)
	-- The slide tower, its platform and the tube sloping down into the pool
	local tx, tz = -s * 0.26, z0 + s * 0.16
	t.block("SlideTower", Vector3.new(2, 6, 2), Vector3.new(tx, PLINTH + 3, tz), Palette.flowerYellow)
	t.block("SlideTop", Vector3.new(2.4, 0.4, 2.4), Vector3.new(tx, PLINTH + 6.2, tz), Palette.roofRed)
	t.block(
		"Slide",
		Vector3.new(1.2, 0.5, 8),
		CFrame.new(tx + 3.4, PLINTH + 3.4, tz) * Kit.yaw(90) * CFrame.Angles(math.rad(-38), 0, 0),
		Palette.roofRed
	)
	-- A mushroom fountain in the shallow end
	t.post("Stem", 2.2, 0.4, Vector3.new(s * 0.26, PLINTH + 1.1, z0 - s * 0.02), Palette.cream)
	t.cyl(
		"Cap",
		0.4,
		2.4,
		CFrame.new(s * 0.26, PLINTH + 2.3, z0 - s * 0.02) * CFrame.Angles(0, 0, math.rad(90)),
		Palette.flowerPink
	)
	Kit.sproutTag(t, Vector3.new(tx, PLINTH + 7.4, tz), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Car Show (content bank, level 46): a glass showroom under a red roof band, a red car on a
-- turntable out front, a classic car on the forecourt and two flag poles.
TYPES.CarShow = function(b, s)
	local z0 = s * 0.1
	local up = CFrame.Angles(0, 0, math.rad(90))
	b.block("Plinth", Vector3.new(s * 0.85, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.6, 4, s * 0.28),
		Vector3.new(0, PLINTH + 2, z0 + s * 0.13),
		Palette.glass,
		{ collide = true }
	)
	local t = b.into(body, true)
	local face = z0 + s * 0.13 - s * 0.14
	t.block(
		"RoofBand",
		Vector3.new(s * 0.64, 0.8, s * 0.32),
		Vector3.new(0, PLINTH + 4.4, z0 + s * 0.13),
		Palette.roofRed
	)
	t.block("SignFace", Vector3.new(s * 0.3, 0.5, 0.1), Vector3.new(0, PLINTH + 4.4, face - 0.07), Palette.cream)
	Kit.door(t, "Door", CFrame.new(s * 0.2, PLINTH, face), 1.6, 3, Palette.cream, Palette.glass)
	-- The turntable and its car
	local cx, cz = -s * 0.12, z0 - s * 0.12
	t.cyl("Turntable", 0.3, 4.4, CFrame.new(cx, PLINTH + 0.15, cz) * up, Palette.stoneLight)
	t.block("Car", Vector3.new(3.4, 0.9, 1.7), Vector3.new(cx, PLINTH + 0.85, cz), Palette.roofRed)
	t.block("CarTop", Vector3.new(1.8, 0.7, 1.5), Vector3.new(cx + 0.2, PLINTH + 1.65, cz), Palette.glass)
	-- A classic car on the forecourt
	local kx, kz = s * 0.2, z0 - s * 0.15
	t.block("Classic", Vector3.new(3, 0.9, 1.6), Vector3.new(kx, PLINTH + 0.75, kz), Palette.flowerYellow)
	t.block("ClassicTop", Vector3.new(1.5, 0.6, 1.4), Vector3.new(kx - 0.3, PLINTH + 1.5, kz), Palette.cream)
	for _, x in { -s * 0.38, s * 0.38 } do
		t.post("FlagPole", 5, 0.2, Vector3.new(x, PLINTH + 2.5, z0 - s * 0.24), Palette.stoneLight)
		t.block("Flag", Vector3.new(1.2, 0.8, 0.1), Vector3.new(x + 0.6, PLINTH + 4.5, z0 - s * 0.24), Palette.roofRed)
	end
	Kit.sproutTag(t, Vector3.new(-s * 0.26, PLINTH + 5.4, z0 + s * 0.18), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Hydro Dam (content bank, level 47): a curved grey dam wall holding back a blue reservoir,
-- water spilling from two sluices into a pool below, and a control house on top.
TYPES.HydroDam = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.85, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.75, 4.4, 1.6),
		Vector3.new(0, PLINTH + 2.2, z0),
		Palette.stoneLight,
		{ collide = true }
	)
	local t = b.into(body, true)
	t.block(
		"Reservoir",
		Vector3.new(s * 0.75, 3.6, s * 0.22),
		Vector3.new(0, PLINTH + 1.8, z0 + s * 0.14),
		Palette.glassDeep
	)
	t.block("Walkway", Vector3.new(s * 0.77, 0.3, 2), Vector3.new(0, PLINTH + 4.55, z0), Palette.stone)
	for _, x in { -s * 0.15, s * 0.15 } do
		t.block("Sluice", Vector3.new(1.4, 1, 0.4), Vector3.new(x, PLINTH + 3, z0 - 0.9), Palette.stoneDark)
		t.block("Spill", Vector3.new(1.2, 3, 0.3), Vector3.new(x, PLINTH + 1.5, z0 - 1.1), Palette.glass)
	end
	t.block("Pool", Vector3.new(s * 0.6, 0.2, s * 0.14), Vector3.new(0, PLINTH + 0.1, z0 - s * 0.12), Palette.glassDeep)
	-- The control house on the walkway
	t.block("ControlHouse", Vector3.new(3, 2.4, 1.8), Vector3.new(s * 0.26, PLINTH + 5.9, z0), Palette.cream)
	t.block("ControlRoof", Vector3.new(3.4, 0.3, 2.2), Vector3.new(s * 0.26, PLINTH + 7.25, z0), Palette.roofTeal)
	Kit.window(t, "Window", CFrame.new(s * 0.26, PLINTH + 5.8, z0 - 0.9), 1.6, 1, Palette.cream, Palette.glass)
	Kit.sproutTag(t, Vector3.new(-s * 0.3, PLINTH + 5.4, z0), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Fashion Studio (content bank, level 48): a tall pink boutique with a black awning, big
-- display windows with two mannequins, and a runway out front lined with lights.
TYPES.FashionStudio = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.8, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.5, 6, s * 0.3),
		Vector3.new(0, PLINTH + 3, z0 + s * 0.12),
		Palette.flowerPink:Lerp(Palette.cream, 0.5),
		{ collide = true }
	)
	local t = b.into(body, true)
	local face = z0 + s * 0.12 - s * 0.15
	t.block(
		"Roof",
		Vector3.new(s * 0.54, 0.5, s * 0.34),
		Vector3.new(0, PLINTH + 6.25, z0 + s * 0.12),
		Palette.stoneDark
	)
	t.block(
		"Awning",
		Vector3.new(s * 0.5, 0.25, 1.4),
		CFrame.new(0, PLINTH + 3.9, face - 0.7) * CFrame.Angles(math.rad(-12), 0, 0),
		Palette.stoneDark
	)
	t.block(
		"Display",
		Vector3.new(s * 0.36, 2.6, 0.2),
		Vector3.new(-s * 0.04, PLINTH + 1.9, face - 0.05),
		Palette.glass
	)
	for _, x in { -s * 0.15, s * 0.05 } do
		t.post("Mannequin", 2, 0.5, Vector3.new(x, PLINTH + 1.4, face + 0.5), Palette.cream)
		t.block("Gown", Vector3.new(0.9, 1.2, 0.9), Vector3.new(x, PLINTH + 1, face + 0.5), Palette.plum)
	end
	Kit.door(t, "Door", CFrame.new(s * 0.18, PLINTH, face), 1.4, 3, Palette.stoneDark, Palette.cream)
	-- The runway with its lights
	t.block("Runway", Vector3.new(2, 0.3, s * 0.2), Vector3.new(0, PLINTH + 0.15, face - s * 0.12), Palette.roofRed)
	for _, x in { -1.1, 1.1 } do
		t.block(
			"Lights",
			Vector3.new(0.2, 0.2, s * 0.2),
			Vector3.new(x, PLINTH + 0.2, face - s * 0.12),
			Palette.flowerYellow
		)
	end
	t.block("Upper", Vector3.new(s * 0.3, 1.4, 0.2), Vector3.new(0, PLINTH + 5, face - 0.05), Palette.glass)
	Kit.sproutTag(t, Vector3.new(-s * 0.2, PLINTH + 6.9, z0 + s * 0.15), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Film Studio (content bank, level 49): a dark sound stage with a curved roof, a big film
-- camera on a tripod out front, a clapperboard sign and a spotlight on a stand.
TYPES.FilmStudio = function(b, s)
	local z0 = s * 0.1
	b.block("Plinth", Vector3.new(s * 0.85, PLINTH, s * 0.6), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.62, 4.6, s * 0.34),
		Vector3.new(0, PLINTH + 2.3, z0 + s * 0.1),
		Palette.stoneDark:Lerp(Palette.sky, 0.25),
		{ collide = true }
	)
	local t = b.into(body, true)
	local face = z0 + s * 0.1 - s * 0.17
	t.cyl("Roof", s * 0.62, s * 0.34, CFrame.new(0, PLINTH + 4.6, z0 + s * 0.1), Palette.stoneLight)
	t.block(
		"StageDoor",
		Vector3.new(3.2, 3.4, 0.2),
		Vector3.new(-s * 0.12, PLINTH + 1.7, face - 0.05),
		Palette.flowerYellow
	)
	Kit.door(t, "Door", CFrame.new(s * 0.18, PLINTH, face), 1.4, 2.8, Palette.roofRed, Palette.cream)
	-- The clapperboard sign over the doors
	t.block("Clapper", Vector3.new(3, 1.2, 0.2), Vector3.new(0, PLINTH + 5.4, face + 0.6), Palette.stoneDark)
	t.block(
		"ClapperTop",
		Vector3.new(3, 0.35, 0.22),
		CFrame.new(0, PLINTH + 6.2, face + 0.6) * CFrame.Angles(0, 0, math.rad(8)),
		Palette.cream
	)
	-- The camera on its tripod and a spotlight
	local cx, cz = s * 0.22, z0 - s * 0.16
	t.post("Tripod", 2, 0.3, Vector3.new(cx, PLINTH + 1, cz), Palette.stoneDark)
	t.block("Camera", Vector3.new(1.6, 1, 0.9), Vector3.new(cx, PLINTH + 2.4, cz), Palette.stoneDark)
	t.cyl("Lens", 0.6, 0.6, CFrame.new(cx - 1.1, PLINTH + 2.4, cz), Palette.glassDeep)
	t.cyl("Reel", 0.2, 1, CFrame.new(cx, PLINTH + 3.3, cz) * Kit.yaw(90), Palette.stoneLight)
	t.post("LampStand", 3, 0.25, Vector3.new(-s * 0.3, PLINTH + 1.5, z0 - s * 0.18), Palette.stoneLight)
	t.block(
		"Spotlight",
		Vector3.new(1, 1, 1.2),
		Vector3.new(-s * 0.3, PLINTH + 3.3, z0 - s * 0.18),
		Palette.flowerYellow
	)
	Kit.sproutTag(t, Vector3.new(-s * 0.26, PLINTH + 6.3, z0 + s * 0.15), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Courthouse (content bank, level 50): a pale stone hall with a columned portico under a
-- triangular pediment, wide front steps and a golden pair of scales on the roof.
TYPES.Courthouse = function(b, s)
	local z0 = s * 0.12
	local body = hall(b, s * 0.66, s * 0.4, 5, Palette.cream:Lerp(Palette.stoneLight, 0.4))
	local t = b.into(body, true)
	local face = -s * 0.2
	t.block("Cornice", Vector3.new(s * 0.7, 0.5, s * 0.44), Vector3.new(0, PLINTH + 5.25, 0), Palette.cream)
	t.wedge(
		"Pediment",
		Vector3.new(s * 0.66, 1.6, 1.2),
		CFrame.new(0, PLINTH + 6.3, face - 0.4) * Kit.yaw(180),
		Palette.cream
	)
	for i = -2, 2 do
		t.post("Column", 4.6, 0.6, Vector3.new(i * s * 0.12, PLINTH + 2.6, face - 1.4), Palette.cream)
	end
	t.block("Portico", Vector3.new(s * 0.62, 0.4, 2), Vector3.new(0, PLINTH + 5.1, face - 1), Palette.cream)
	t.block("Steps", Vector3.new(s * 0.6, 0.4, 1.4), Vector3.new(0, 0.2, face - 2.2), Palette.stoneLight)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, face), 1.6, 3.2, Palette.woodDark, Palette.cream)
	-- The scales on the roof: a post, a beam and two pans
	t.post("ScalePost", 2, 0.25, Vector3.new(0, PLINTH + 6.4, z0), Palette.coins)
	t.block("ScaleBeam", Vector3.new(3, 0.2, 0.2), Vector3.new(0, PLINTH + 7.4, z0), Palette.coins)
	for _, x in { -1.4, 1.4 } do
		t.cyl("Pan", 0.15, 0.9, CFrame.new(x, PLINTH + 6.8, z0) * CFrame.Angles(0, 0, math.rad(90)), Palette.coins)
	end
	Kit.sproutTag(t, Vector3.new(s * 0.26, PLINTH + 5.9, s * 0.12), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Kart Track (content bank, level 51): an oval of grey track round a grass infield, a little
-- red kart on the straight, a small grandstand at the back and a chequered flag.
TYPES.KartTrack = function(b, s)
	local up = CFrame.Angles(0, 0, math.rad(90))
	b.cyl("Track", 0.3, s * 0.9, CFrame.new(0, 0.15, 0) * up, Palette.stoneDark)
	b.cyl("Infield", 0.35, s * 0.55, CFrame.new(0, 0.18, 0) * up, Palette.grassLight)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.4, 2.4, 1.8),
		Vector3.new(0, 1.2, s * 0.32),
		Palette.roofRed,
		{ collide = true }
	)
	local t = b.into(body, true)
	t.block(
		"Seats",
		Vector3.new(s * 0.4, 0.6, 1.6),
		CFrame.new(0, 2.4, s * 0.31) * CFrame.Angles(math.rad(-20), 0, 0),
		Palette.flowerYellow
	)
	t.block("StandRoof", Vector3.new(s * 0.44, 0.3, 2.2), Vector3.new(0, 4, s * 0.33), Palette.cream)
	for _, x in { -s * 0.2, s * 0.2 } do
		t.post("StandPost", 1.6, 0.25, Vector3.new(x, 3.2, s * 0.4), Palette.metal)
	end
	-- The kart on the front straight
	local kz = -s * 0.36
	t.block("Kart", Vector3.new(2, 0.5, 1.1), Vector3.new(-1, 0.6, kz), Palette.roofRed)
	t.ball("Driver", 0.7, Vector3.new(-1.2, 1.2, kz), Palette.flowerYellow)
	for _, x in { -1.8, -0.2 } do
		t.cyl("Wheel", 0.3, 0.6, CFrame.new(x, 0.45, kz) * Kit.yaw(90), Palette.stoneDark)
	end
	-- The chequered flag on its pole at the finish line
	t.post("FlagPole", 4, 0.2, Vector3.new(2.6, 2, -s * 0.3), Palette.metal)
	t.block("Flag", Vector3.new(1.6, 1, 0.1), Vector3.new(3.4, 3.4, -s * 0.3), Palette.cream)
	t.block("FlagCheck", Vector3.new(0.8, 0.5, 0.12), Vector3.new(3, 3.65, -s * 0.3), Palette.stoneDark)
	t.block("FlagCheck", Vector3.new(0.8, 0.5, 0.12), Vector3.new(3.8, 3.15, -s * 0.3), Palette.stoneDark)
	t.block("FinishLine", Vector3.new(0.4, 0.05, s * 0.17), Vector3.new(1.6, 0.33, -s * 0.36), Palette.cream)
	Kit.sproutTag(t, Vector3.new(s * 0.18, 4.8, s * 0.33), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Fitness Club (content bank, level 52): a bright modern gym with a wall of glass, a giant
-- dumbbell on the roof and a running track stripe out front.
TYPES.FitnessClub = function(b, s)
	local body = hall(b, s * 0.7, s * 0.42, 4.4, Palette.cream)
	local t = b.into(body, true)
	local face = -s * 0.21
	t.block("Roof", Vector3.new(s * 0.74, 0.4, s * 0.46), Vector3.new(0, PLINTH + 4.6, 0), Palette.sky)
	t.block("GlassWall", Vector3.new(s * 0.44, 3, 0.2), Vector3.new(-s * 0.1, PLINTH + 2, face - 0.05), Palette.glass)
	Kit.door(t, "Door", CFrame.new(s * 0.24, PLINTH, face), 1.4, 3, Palette.sky, Palette.cream)
	-- The dumbbell on the roof: a bar and two weights
	t.cyl("Bar", s * 0.4, 0.3, CFrame.new(0, PLINTH + 5.8, 0), Palette.stoneLight)
	for _, x in { -s * 0.18, s * 0.18 } do
		t.cyl("Weight", 0.8, 2, CFrame.new(x, PLINTH + 5.8, 0), Palette.stoneDark)
	end
	-- The track stripe and a bench out front
	t.block("Track", Vector3.new(s * 0.7, 0.1, 1.6), Vector3.new(0, PLINTH + 0.05, face - 1.6), Palette.roofRed)
	t.block("TrackLine", Vector3.new(s * 0.7, 0.12, 0.15), Vector3.new(0, PLINTH + 0.06, face - 1.6), Palette.cream)
	t.block("Bench", Vector3.new(2, 0.3, 0.7), Vector3.new(-s * 0.26, PLINTH + 0.7, face - 3), Palette.wood)
	Kit.sproutTag(t, Vector3.new(s * 0.28, PLINTH + 5.2, s * 0.14), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Day Spa (content bank, level 53): a low timber pavilion with a deep roof, a round steaming
-- hot pool out front, two loungers and a stack of towels.
TYPES.DaySpa = function(b, s)
	local z0 = s * 0.14
	b.block("Plinth", Vector3.new(s * 0.8, PLINTH, s * 0.36), Vector3.new(0, PLINTH / 2, z0), Palette.stone)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.6, 3.6, s * 0.3),
		Vector3.new(0, PLINTH + 1.8, z0),
		Palette.woodLight,
		{ collide = true }
	)
	local t = b.into(body, true)
	local face = z0 - s * 0.15
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + 3.6, z0), s * 0.72, s * 0.4, 1.8, Palette.roofTeal, Palette.cream)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, face), 1.6, 3, Palette.roofTeal, Palette.cream)
	t.block("Screen", Vector3.new(2, 2, 0.2), Vector3.new(-s * 0.18, PLINTH + 1.6, face - 0.05), Palette.cream)
	-- The hot pool with its rim and the steam
	local up = CFrame.Angles(0, 0, math.rad(90))
	local pz = -s * 0.24
	t.cyl("PoolRim", 0.5, 4.4, CFrame.new(-s * 0.12, 0.25, pz) * up, Palette.stoneLight)
	t.cyl("Pool", 0.52, 3.6, CFrame.new(-s * 0.12, 0.27, pz) * up, Palette.sky)
	t.ball("Steam", 1.4, Vector3.new(-s * 0.12, 1.6, pz), Palette.cream, { transparency = 0.5, shadow = false })
	-- Loungers and towels
	t.block("Lounger", Vector3.new(1, 0.4, 2.6), Vector3.new(s * 0.2, 0.5, pz), Palette.cream)
	t.block("Towels", Vector3.new(0.8, 0.6, 0.8), Vector3.new(s * 0.32, 0.3, pz + 0.8), Palette.flowerPink)
	Kit.sproutTag(t, Vector3.new(s * 0.26, PLINTH + 5.6, z0 + 1), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Golf Club (content bank, level 54): a putting green with a flag in the hole, a sand bunker,
-- a little clubhouse with a striped awning and a giant golf ball on a tee as its sign.
TYPES.GolfClub = function(b, s)
	local up = CFrame.Angles(0, 0, math.rad(90))
	b.cyl("Green", 0.3, s * 0.8, CFrame.new(0, 0.15, -s * 0.05) * up, Palette.grassLight)
	local body = b.block(
		"Body",
		Vector3.new(s * 0.36, 3.4, s * 0.24),
		Vector3.new(-s * 0.18, PLINTH + 1.7, s * 0.26),
		Palette.cream,
		{ collide = true }
	)
	local t = b.into(body, true)
	t.block(
		"Plinth",
		Vector3.new(s * 0.4, PLINTH, s * 0.28),
		Vector3.new(-s * 0.18, PLINTH / 2, s * 0.26),
		Palette.stone
	)
	t.block(
		"Roof",
		Vector3.new(s * 0.4, 0.4, s * 0.28),
		Vector3.new(-s * 0.18, PLINTH + 3.6, s * 0.26),
		Palette.treeTopDark
	)
	t.block(
		"Awning",
		Vector3.new(s * 0.36, 0.25, 1.2),
		CFrame.new(-s * 0.18, PLINTH + 2.6, s * 0.14 - 0.6) * CFrame.Angles(math.rad(-15), 0, 0),
		Palette.roofRed
	)
	Kit.door(t, "Door", CFrame.new(-s * 0.18, PLINTH, s * 0.14), 1.4, 2.4, Palette.treeTopDark, Palette.cream)
	-- The hole with its flag, a bunker and the ball on its tee
	t.cyl("Hole", 0.32, 0.6, CFrame.new(s * 0.1, 0.16, -s * 0.12) * up, Palette.stoneDark)
	t.post("FlagPole", 3.6, 0.15, Vector3.new(s * 0.1, 1.8, -s * 0.12), Palette.cream)
	t.wedge("Flag", Vector3.new(0.1, 0.9, 1.4), CFrame.new(s * 0.1, 3.1, -s * 0.12 - 0.7), Palette.roofRed)
	t.cyl("Bunker", 0.32, 2.6, CFrame.new(-s * 0.2, 0.17, -s * 0.24) * up, Palette.wheat)
	t.post("Tee", 1.6, 0.4, Vector3.new(s * 0.26, 0.8, s * 0.22), Palette.wood)
	t.ball("Ball", 2.2, Vector3.new(s * 0.26, 2.6, s * 0.22), Palette.cream:Lerp(Palette.stoneLight, 0.2))
	Kit.sproutTag(t, Vector3.new(-s * 0.3, PLINTH + 4.4, s * 0.32), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Organ Hall (content bank, level 55): a tall warm-stone concert hall with a rose window and
-- a row of golden organ pipes rising behind a gable front.
TYPES.OrganHall = function(b, s)
	local body = hall(b, s * 0.56, s * 0.5, 6.4, Palette.wheat:Lerp(Palette.cream, 0.4))
	local t = b.into(body, true)
	local face = -s * 0.25
	Kit.gableRoof(t, "Roof", Vector3.new(0, PLINTH + 6.4, 0), s * 0.6, s * 0.54, 2.6, Palette.roofPlum, Palette.cream)
	-- The organ pipes behind the gable, tallest in the middle
	for i, hgt in { 3, 4.4, 5.6, 4.4, 3 } do
		local x = (i - 3) * 1
		t.post("Pipe", hgt, 0.7, Vector3.new(x, PLINTH + 6.4 + hgt / 2, s * 0.16), Palette.coins)
	end
	t.cyl("RoseWindow", 0.2, 2.2, CFrame.new(0, PLINTH + 4.6, face - 0.1) * Kit.yaw(90), Palette.glassDeep)
	t.cyl("RoseRim", 0.18, 2.6, CFrame.new(0, PLINTH + 4.6, face - 0.05) * Kit.yaw(90), Palette.cream)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, face), 1.8, 3.2, Palette.woodDark, Palette.cream)
	t.block("Steps", Vector3.new(s * 0.4, 0.4, 1.2), Vector3.new(0, 0.2, face - 0.9), Palette.stoneLight)
	for _, x in { -s * 0.2, s * 0.2 } do
		t.block("Banner", Vector3.new(1, 2.6, 0.15), Vector3.new(x, PLINTH + 3.4, face - 0.1), Palette.roofPlum)
	end
	Kit.sproutTag(t, Vector3.new(s * 0.22, PLINTH + 7, s * 0.14), 2.5, Palette.wood, Palette.lime)
	return body
end

function ArtCommunity.has(id: string): boolean
	return TYPES[id] ~= nil
end

-- Build Community Building `id` into `parent` at `cf` (lot centre on the ground, front at
-- local -Z). Returns the tap-target part.
function ArtCommunity.build(id: string, parent: Instance, cf: CFrame, size: number?): BasePart
	local build = TYPES[id] or TYPES.VillageWell
	return build(Kit.builder(parent, cf, true), size or 12)
end

return ArtCommunity
