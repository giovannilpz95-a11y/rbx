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

TileStyle.GoalGlyphs = {
	Mud = "🟫",
	HayBale = "🌾",
	Frost = "❄️",
	Weeds = "🌿",
	Pumpkins = "🎃",
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
	text = Palette.text,
	accent = Palette.button.attention.face, -- buttons, the moves box, a picked booster
	accentText = Palette.accentText, -- orange text on cream
	locked = Palette.button.disabled.face,
	selection = Color3.fromRGB(255, 255, 255),
	option = Palette.paper, -- an unpicked booster
}

TileStyle.Font = UiTheme.Type.display

return TileStyle
