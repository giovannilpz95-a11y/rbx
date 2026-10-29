--!strict
-- UI colours (Design/25 UI Style Guide). Bright, warm and saturated, with cocoa brown instead
-- of black for text and outlines. The shared brand colours (cream, cocoa, Coins, Gems, XP,
-- grass, wood) use the same hex values as the 3D world palette in farm/src/shared/Art/Palette.

local function hex(value: string): Color3
	return Color3.fromRGB(
		tonumber(string.sub(value, 2, 3), 16) :: number,
		tonumber(string.sub(value, 4, 5), 16) :: number,
		tonumber(string.sub(value, 6, 7), 16) :: number
	)
end

-- A darker shade of a colour, for button lips, outlines and text strokes.
local function shade(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

-- Perceived brightness 0-1, to pick light or dark text on a colour.
local function luminance(color: Color3): number
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

export type ButtonColors = { face: Color3, lip: Color3 }

local Palette = {
	hex = hex,
	shade = shade,
	luminance = luminance,

	-- Shared with the 3D world palette
	cream = hex("#FFF6E5"),
	cocoa = hex("#4A3426"),
	coins = hex("#FFC93C"),
	gems = hex("#29C7AC"),
	xp = hex("#8BD346"),
	grass = hex("#7BC96F"),
	wood = hex("#C98A4B"),

	-- Surfaces
	panel = hex("#FFF6E5"), -- window body
	paper = hex("#FCEBC8"), -- inset area inside a window
	card = hex("#FFFFFF"), -- rows and slots
	edge = hex("#B9824A"), -- window and card outlines
	ribbon = hex("#3FA9E0"), -- window title plaque
	ribbonLip = hex("#2A7DB8"),
	scrim = hex("#2B1D14"),

	-- Text
	text = hex("#4A3426"),
	muted = hex("#8C7360"),
	textOnColor = hex("#FFFFFF"),
	accentText = hex("#C2561A"), -- orange text that stays readable on cream

	-- Status
	ready = hex("#6CC24A"),
	warn = hex("#FFA62B"),
	timer = hex("#4A3426"),
	locked = hex("#C9C1B3"),
	badge = hex("#EF5A4C"),

	-- Buttons: face colour and the darker lip under it
	button = {
		primary = { face = hex("#6CC24A"), lip = hex("#3F8F2B") }, -- go / confirm / collect
		secondary = { face = hex("#45A6E5"), lip = hex("#2C73B0") }, -- info / navigation / toggles
		premium = { face = hex("#29C7AC"), lip = hex("#178A77") }, -- spends Gems
		attention = { face = hex("#FFA62B"), lip = hex("#D9731A") }, -- big action, armed confirm
		danger = { face = hex("#EF5A4C"), lip = hex("#B23A2F") }, -- close, discard, sell all
		neutral = { face = hex("#FFF6E5"), lip = hex("#C9A877") }, -- unpicked options
		disabled = { face = hex("#C9C1B3"), lip = hex("#9C9384") },
	} :: { [string]: ButtonColors },
}

-- The lip for any face colour: a named variant's lip when the face matches one, else a
-- darker shade. Lets code keep setting BackgroundColor3 on a themed button.
function Palette.lipFor(face: Color3): Color3
	for _, colors in Palette.button do
		local f = colors.face
		if math.abs(f.R - face.R) < 0.004 and math.abs(f.G - face.G) < 0.004 and math.abs(f.B - face.B) < 0.004 then
			return colors.lip
		end
	end
	return shade(face, 0.7)
end

return Palette
