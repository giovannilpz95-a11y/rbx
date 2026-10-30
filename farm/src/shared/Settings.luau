--!strict
-- Player settings saved in the profile (data.settings; Design/11 UI & UX accessibility,
-- UI Reference & Gaps G7): sound volumes, text size, Reduce Motion and when a Gem spend
-- asks for a second tap. Pure, so the server can check every value and Lune can test it.

export type Option = {
	kind: "volume" | "choice" | "toggle",
	default: any,
	choices: { string }?,
}

local Settings = {}

Settings.volumeSteps = 10 -- volume sliders run 0..10; 10 is the designed mix

-- stylua: ignore
Settings.options = table.freeze({
	music = table.freeze({ kind = "volume", default = 10 }),
	sfx = table.freeze({ kind = "volume", default = 10 }), -- sound effects and the farm ambience
	ui = table.freeze({ kind = "volume", default = 10 }), -- button taps and pop-ups
	textSize = table.freeze({ kind = "choice", default = "Normal", choices = table.freeze({ "Normal", "Large", "Larger" }) }),
	reduceMotion = table.freeze({ kind = "toggle", default = false }),
	gemConfirm = table.freeze({ kind = "choice", default = "Always", choices = table.freeze({ "Always", "Over 10", "Never" }) }),
}) :: { [string]: Option }

-- Text size -> how much bigger panel text is drawn
Settings.textScale = table.freeze({ Normal = 1, Large = 1.12, Larger = 1.25 })

-- Gem spends above this many Gems still ask twice with "Over 10"
Settings.confirmOver = 10

function Settings.defaults(): { [string]: any }
	local out = {}
	for key, option in Settings.options do
		out[key] = option.default
	end
	return out
end

-- Is `value` allowed for setting `key`?
function Settings.valid(key: any, value: any): boolean
	local option = type(key) == "string" and Settings.options[key] or nil
	if option == nil then
		return false
	elseif option.kind == "volume" then
		return type(value) == "number" and value % 1 == 0 and value >= 0 and value <= Settings.volumeSteps
	elseif option.kind == "toggle" then
		return type(value) == "boolean"
	end
	return type(value) == "string" and table.find(option.choices :: { string }, value) ~= nil
end

-- A setting's value from the saved settings, falling back to its default.
function Settings.get(saved: { [string]: any }?, key: string): any
	local value = saved and saved[key]
	if value == nil or not Settings.valid(key, value) then
		return Settings.options[key].default
	end
	return value
end

-- Does spending `price` Gems need a second tap?
function Settings.confirmGems(saved: { [string]: any }?, price: number): boolean
	local mode = Settings.get(saved, "gemConfirm")
	if mode == "Never" then
		return false
	elseif mode == "Over 10" then
		return price > Settings.confirmOver
	end
	return true
end

return Settings
