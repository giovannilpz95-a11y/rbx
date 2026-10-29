--[[
	Placeholder look for Crop Pop tiles until the art pass (12 Art & Audio Direction).

	Each tile has its own colour, glyph and corner shape so they can be told
	apart without relying on colour alone. The glyphs are standard emoji used
	as stand-ins; final tiles will be our own sprites on one sheet.
]]

local TileStyle = {}

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

TileStyle.GoalGlyphs = {
	Mud = "🟫",
	HayBale = "🌾",
}

TileStyle.Board = {
	backdrop = Color3.fromRGB(112, 168, 84),
	panel = Color3.fromRGB(250, 243, 222),
	cellLight = Color3.fromRGB(196, 224, 150),
	cellDark = Color3.fromRGB(178, 210, 132),
	mud = Color3.fromRGB(122, 84, 52),
	bale = Color3.fromRGB(226, 188, 92),
	baleText = Color3.fromRGB(110, 76, 30),
	text = Color3.fromRGB(70, 52, 34),
	accent = Color3.fromRGB(232, 120, 48),
	locked = Color3.fromRGB(190, 186, 176),
	selection = Color3.fromRGB(255, 255, 255),
}

TileStyle.Font = Enum.Font.FredokaOne

return TileStyle
