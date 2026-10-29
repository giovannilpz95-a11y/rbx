--!strict
-- Fonts and sizes (Design/25 UI Style Guide). Fredoka One is the chunky rounded display face for
-- titles, buttons and numbers; Gotham is the plain face for longer body text. Both ship with
-- Roblox. Sizes are in pixels at the 1080p-equivalent scale; 14 is the floor (11 UI & UX).

local Type = {
	display = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bodyBold = Enum.Font.GothamBold,

	size = {
		title = 26, -- window titles
		heading = 20, -- section headings, big numbers
		button = 18,
		hud = 18, -- currency and level numbers
		body = 16,
		small = 14,
	},

	-- Outline on light text over colour, so it reads on any background
	strokeThickness = 1.5,
	strokeTransparency = 0.15,
}

return Type
