--[[
	Placeholder look for Crop Pop tiles until the art pass (12 Art & Audio Direction).

	Each tile has its own colour, glyph and corner shape so they can be told
	apart without relying on colour alone. The glyphs are standard emoji used
	as stand-ins; final tiles will be our own sprites on one sheet.

	Screen colours and the font come from the shared UiTheme
	(Design/25 UI Style Guide), so Crop Pop matches the farm's look.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTheme = require(ReplicatedStorage:WaitForChild("UiTheme"))
local Palette = UiTheme.Palette

local TileStyle = {}

TileStyle.Theme = UiTheme

-- Indexed by tile colour id (see CropPop.Tiles.Names).
TileStyle.Colors = {
	Color3.fromRGB(222, 70, 56), -- Tomato
	Color3.fromRGB(247, 238, 214), -- Egg
	Color3.fromRGB(242, 140, 40), -- Carrot
	Color3.fromRGB(246, 206, 58), -- Corn
	Color3.fromRGB(160, 206, 240), -- Milk
	Color3.fromRGB(176, 124, 206), -- Wool
}

TileStyle.Glyphs = { "🍅", "🥚", "🥕", "🌽", "🥛", "🧶" }

-- UICorner radius as a fraction of the tile (0.5 = round).
TileStyle.Corners = { 0.5, 0.5, 0.12, 0.25, 0.18, 0.4 }

-- Emoji only: FredokaOne has no arrow or symbol glyphs, emoji use the emoji font.
TileStyle.PowerBadges = {
	SprayerRow = "↔️",
	SprayerColumn = "↕️",
	Bumblebee = "🐝",
	HayBomb = "💥",
}

TileStyle.Sunflower = { color = Color3.fromRGB(255, 196, 30), glyph = "🌻" }
TileStyle.Pumpkin = { color = Color3.fromRGB(196, 120, 52), glyph = "🎃", exit = "⬇️" }
-- A muddy pumpkin: the pumpkin dulled under brown mud, with a drop to say "wash me".
TileStyle.MuddyPumpkin = { color = Color3.fromRGB(110, 80, 50), glyph = "🎃", badge = "💧", textTransparency = 0.45 }
-- Portal ends: a swirl on a coloured disc, one colour per entrance/exit pair.
TileStyle.PortalGlyph = "🌀"
TileStyle.BasketGlyph = "🧺" -- a pumpkin basket (Unicode 11)
TileStyle.TreeGlyph = "🌳" -- an apple tree (its apples show as a count)
TileStyle.HenGlyph = "🐔" -- a hen house
TileStyle.CrateGlyph = "🎁" -- a surprise crate
TileStyle.SpringGlyph = "⛲" -- a goo spring
TileStyle.TruckGlyph = "🚚" -- a hay truck (the number is the bales it still carries)
TileStyle.SnailGlyph = "🐌" -- a garden snail (Unicode 6)
TileStyle.PenGlyph = "🏡" -- a lamb's pen (Unicode 6)
TileStyle.SpotGlyph = "·" -- a firefly spot that's dark for now
TileStyle.SeedGlyph = "🌰" -- a seed tray cell that hasn't sprouted yet
TileStyle.PumpGlyph = "⛽" -- a hand pump (it drains flood water)
TileStyle.BurrowGlyph = "🕳" -- an open gopher burrow with no gopher in it now
TileStyle.MowerGlyph = "✂" -- a lawn mower (the blades: there's no mower emoji)
TileStyle.PacketGlyph = "🎫" -- a seed packet (in the editor; on the board it shows its colour)
TileStyle.JarGlyph = "🏺" -- a jam jar (Unicode 8; Roblox has no 🫙, Unicode 14)
TileStyle.ChestGlyph = "🧰" -- a tool chest (Unicode 11); with its tools left once it's open
TileStyle.LockGlyph = "🔒" -- a tool chest that's still locked (only a blast opens it)
TileStyle.VaneArrows = { "⬆", "➡", "⬇", "⬅" } -- the side a weathervane points at (only matches there hit it)
TileStyle.BucketGlyph = "🥫" -- a mud bucket: a tin (Unicode 10; Roblox has no 🪣, Unicode 13)
TileStyle.ScarecrowGlyph = "🎩" -- a scarecrow's hat (no scarecrow emoji); dots show its charges
-- Mailboxes: shut, open with a letter, open and empty.
TileStyle.MailGlyphs = { closed = "📪", full = "📬", empty = "📭" }
TileStyle.SnowGlyph = "❄" -- a snowball's timer (no snowflake variant selector: it's a small badge)
TileStyle.SackGlyph = "🌱" -- a seed sack (hits sow clover near it)
TileStyle.TinGlyph = "🧵" -- a sewing tin (opening it sends a patch to a quilt)
-- Quilt patches, by cell (a checker of four fabrics).
TileStyle.QuiltPatchColors = {
	Color3.fromRGB(230, 120, 120),
	Color3.fromRGB(120, 170, 220),
	Color3.fromRGB(240, 200, 100),
	Color3.fromRGB(140, 200, 130),
}
TileStyle.RainbowGlyph = "🌈" -- a rainbow patch (its tile changes colour every swap)
-- The rainbow patch's stripes, left to right.
TileStyle.RainbowColors = {
	Color3.fromRGB(235, 90, 90),
	Color3.fromRGB(245, 180, 70),
	Color3.fromRGB(240, 230, 90),
	Color3.fromRGB(110, 200, 110),
	Color3.fromRGB(90, 150, 230),
	Color3.fromRGB(170, 110, 220),
}
TileStyle.PortalColors = {
	Color3.fromRGB(150, 110, 220),
	Color3.fromRGB(70, 170, 200),
	Color3.fromRGB(230, 140, 60),
	Color3.fromRGB(220, 90, 140),
}

TileStyle.GoalGlyphs = {
	Mud = "🟫",
	HayBale = "🌾",
	Frost = "❄️",
	Weeds = "🌿",
	Pumpkins = "🎃",
	Clover = "🍀",
	Stones = "🧱", -- the rock emoji (Unicode 13) does not render in Roblox
	Fences = "🚧", -- the wood emoji (Unicode 13) does not render in Roblox
	Goo = "🟢",
	Statues = "🗿", -- a buried statue
	Tarps = "🎪", -- a canvas tarp
	Webs = "🕸", -- a spider web over a tile
	Clay = "🏺", -- clay under the tiles
	Letters = "✉", -- a letter from a mailbox
	Boxes = "📦", -- a produce box off a stack
	Honey = "🍯", -- a honey jar from a beehive
	Blooms = "🌷", -- a tulip bud that has bloomed
	Lambs = "🐑", -- a lost lamb walked home
	Gophers = "🐹", -- a gopher caught in its burrow (the hamster: there's no gopher emoji)
	Packets = "🎫", -- an emptied seed packet (a paper ticket: there's no packet emoji)
	Jars = "🏺", -- a jam jar filled and cracked open
	Tools = "🔧", -- a tool taken out of a tool chest
	Vanes = "🐓", -- a weathervane's rooster, brought down
	Vines = "🍃", -- a vine cut off a tile
	Mist = "🌫", -- a patch of mist lifted (Unicode 7)
	Birds = "🐦", -- a songbird fed and flown off
	Frames = "🌱", -- a seedling freed from a cold frame
	Pots = "🍲", -- a stew pot taken off the boil
	Apples = "🍎", -- an apple shaken off an apple tree
	Floods = "💧", -- a flooded cell pumped dry
	Bins = "♻", -- a compost bin that has burst
	Trays = "🌼", -- a seed tray with every seed sprouted (the seedling is the seed sack)
	Fireflies = "✨", -- a firefly caught on a lit spot (there's no firefly emoji before Unicode 13)
	Snowballs = "☃", -- a snowball (the snowman: there's no snowball emoji)
	Quilts = "🧶", -- a patchwork quilt (yarn: there's no quilt emoji)
}

TileStyle.BoosterGlyphs = {
	SprayerStart = "💦",
	BombStart = "💥",
	SunflowerStart = "🌻",
	Trowel = "⛏️", -- no trowel emoji; the shovel (Unicode 13) does not render in Roblox
	Rake = "🧹",
	GardenGloves = "🧤",
	ShakeUp = "🔀",
}

TileStyle.Board = {
	backdrop = Palette.grass,
	panel = Palette.panel,
	cellLight = Color3.fromRGB(196, 224, 150),
	cellDark = Color3.fromRGB(178, 210, 132),
	mud = Color3.fromRGB(122, 84, 52),
	bale = Color3.fromRGB(226, 188, 92),
	baleText = Color3.fromRGB(110, 76, 30),
	frost = Color3.fromRGB(196, 232, 255),
	weed = Color3.fromRGB(96, 158, 66),
	clover = Color3.fromRGB(72, 170, 92),
	stone = Color3.fromRGB(150, 146, 140),
	basket = Color3.fromRGB(176, 128, 78),
	fence = Color3.fromRGB(122, 84, 46),
	hedge = Color3.fromRGB(64, 128, 58), -- a hedge: a fence nothing breaks
	hedgeEdge = Color3.fromRGB(30, 74, 30),
	goo = Color3.fromRGB(120, 200, 80),
	thickGoo = Color3.fromRGB(62, 140, 40), -- darker: two clears
	hen = Color3.fromRGB(196, 90, 70),
	crate = Color3.fromRGB(150, 110, 200),
	spring = Color3.fromRGB(70, 140, 60), -- a goo spring's basin
	tarp = Color3.fromRGB(196, 72, 64), -- red-and-cream canvas
	tarpText = Color3.fromRGB(255, 240, 214),
	buried = Color3.fromRGB(206, 170, 112), -- sandy soil over a buried statue
	quilt = Color3.fromRGB(238, 226, 200), -- a quilt cell still missing its patch
	quiltText = Color3.fromRGB(170, 140, 110),
	tin = Color3.fromRGB(110, 160, 190), -- a sewing tin
	sack = Color3.fromRGB(186, 150, 104), -- burlap
	snowText = Color3.fromRGB(40, 90, 150), -- a snowball's timer
	clay = Color3.fromRGB(196, 110, 70), -- terracotta under a tile
	mailbox = Color3.fromRGB(120, 150, 200), -- a mailbox's post
	scarecrow = Color3.fromRGB(214, 170, 90), -- straw
	bucket = Color3.fromRGB(150, 160, 170), -- a tin bucket
	box = Color3.fromRGB(205, 160, 105), -- cardboard produce boxes
	hive = Color3.fromRGB(236, 178, 52), -- a honeycomb beehive
	truck = Color3.fromRGB(196, 92, 70), -- a red hay truck
	snail = Color3.fromRGB(176, 214, 150), -- a snail on a leaf
	bud = Color3.fromRGB(150, 196, 120), -- a leafy tulip bud
	lamb = Color3.fromRGB(240, 236, 226), -- a woolly lamb
	pen = Color3.fromRGB(214, 180, 120), -- the straw of a lamb's pen
	bin = Color3.fromRGB(96, 140, 80), -- a green compost bin
	packet = Color3.fromRGB(244, 230, 196), -- a paper seed packet
	jar = Color3.fromRGB(196, 226, 232), -- an empty glass jam jar
	jarFull = Color3.fromRGB(200, 50, 80), -- a jam jar full of jam
	chest = Color3.fromRGB(120, 80, 50), -- a locked wooden tool chest
	chestOpen = Color3.fromRGB(190, 140, 90), -- an open tool chest
	vane = Color3.fromRGB(70, 80, 100), -- a wrought-iron weathervane
	web = Color3.fromRGB(240, 240, 250), -- a spider web over a tile
	vine = Color3.fromRGB(70, 150, 60), -- a green vine over a tile
	mist = Color3.fromRGB(215, 222, 230), -- mist hiding a tile
	wash = Color3.fromRGB(150, 210, 245), -- a splash washing a muddy pumpkin
	bird = Color3.fromRGB(120, 170, 120), -- a songbird's perch (tinted by the colour it wants)
	frame = Color3.fromRGB(150, 190, 205), -- a glass cold frame (paler as it opens)
	pot = Color3.fromRGB(70, 70, 78), -- a black iron stew pot
	tree = Color3.fromRGB(70, 130, 60), -- a leafy apple tree
	mower = Color3.fromRGB(200, 60, 50), -- a red lawn mower
	burrow = Color3.fromRGB(120, 86, 56), -- the earth round a gopher burrow
	mowed = Color3.fromRGB(150, 220, 120), -- freshly cut grass along a mowed row
	flood = Color3.fromRGB(70, 140, 220), -- flood water under a tile
	pump = Color3.fromRGB(170, 70, 60), -- a red cast-iron hand pump
	tray = Color3.fromRGB(132, 92, 60), -- the dark soil of a seed tray
	sprout = Color3.fromRGB(120, 190, 90), -- a seed tray cell that has sprouted
	glow = Color3.fromRGB(255, 232, 120), -- a lit firefly spot
	spot = Color3.fromRGB(70, 80, 60), -- a dark firefly spot
	budLit = Color3.fromRGB(246, 150, 190), -- a bud opening (charged)
	glaze = Color3.fromRGB(255, 244, 220), -- the shine on glazed clay
	text = Palette.text,
	accent = Palette.button.attention.face, -- buttons, the moves box, a picked booster
	accentText = Palette.accentText, -- orange text on cream
	locked = Palette.button.disabled.face,
	selection = Color3.fromRGB(255, 255, 255),
	option = Palette.paper, -- an unpicked booster
}

TileStyle.Font = UiTheme.Type.display

return TileStyle
