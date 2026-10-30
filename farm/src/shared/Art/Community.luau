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

ArtCommunity.TYPES = {} :: { string }
for id in TYPES do
	table.insert(ArtCommunity.TYPES, id)
end
table.sort(ArtCommunity.TYPES)

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
