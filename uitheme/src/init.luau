--!strict
-- UiTheme: the shared look for every screen in the game (Design/25 UI Style Guide).
--
--     local UiTheme = require(ReplicatedStorage.UiTheme)
--     UiTheme.Kit.button("Collect", "primary", { Parent = frame })
--     label.TextColor3 = UiTheme.Palette.text
--
-- Format: number abbreviations. Palette: colours. Type: fonts and sizes. Motion: pop-ins, presses, bumps, counters.
-- Kit: buttons, windows, pills, bars, badges, toasts, bubbles and icons built from frames.

local Format = require(script.Format)
local Kit = require(script.Kit)
local Motion = require(script.Motion)
local Palette = require(script.Palette)
local Type = require(script.Type)

return {
	Format = Format,
	Kit = Kit,
	Motion = Motion,
	Palette = Palette,
	Type = Type,
}
