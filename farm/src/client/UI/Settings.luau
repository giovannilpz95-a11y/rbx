--!strict
-- The Settings panel (UI Reference & Gaps G7; Design/11 UI & UX accessibility): sound volumes,
-- text size, Reduce Motion, when a Gem spend asks twice, and who may visit or help. Opens from
-- the ⚙ HUD button or K (Main.client). Values save in the profile (shared/Settings) and apply on this
-- client: Motion.reduced, Ui.textScale and the GameAudio volume groups.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Settings = require(Shared.Settings)
local Social = require(Shared.Config.Social)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local Kit = Ui.theme.Kit

local SettingsUi = {}

-- Setting -> the GameAudio volume groups it drives
local VOLUME_GROUPS: { [string]: { string } } = {
	music = { "Music" },
	sfx = { "Effects", "Ambience" },
	ui = { "Ui" },
}

-- GameAudio (the repo's audio/ project) is optional: without it the sliders still save
local audio: any = nil
local designed: { [string]: number } = {} -- each group's volume before we touched it

local function getAudio(): any
	if audio == nil then
		local module = ReplicatedStorage:FindFirstChild("GameAudio")
		if module == nil then
			return nil -- may still be loading
		end
		local ok, result = pcall(require, module)
		audio = if ok then result else false
	end
	return audio or nil
end

local applied: { [string]: any } = {}

-- Apply saved settings on this client. Runs on every snapshot; only changes act.
function SettingsUi.apply(saved: { [string]: any }?)
	local reduce = Settings.get(saved, "reduceMotion") == true
	Ui.theme.Motion.reduced = reduce

	local scale = Settings.textScale[Settings.get(saved, "textSize")] or 1
	if scale ~= Ui.textScale then
		Ui.textScale = scale
		Panels.refresh()
	end

	local a = getAudio()
	if a then
		for key, groups in VOLUME_GROUPS do
			local step = Settings.get(saved, key)
			if applied[key] ~= step then
				applied[key] = step
				for _, group in groups do
					local ok = pcall(function()
						if designed[group] == nil then
							designed[group] = a.getVolume(group)
						end
						a.setVolume(group, designed[group] * step / Settings.volumeSteps)
					end)
					if not ok then
						applied[key] = nil -- try again next snapshot
					end
				end
			end
		end
	end
end

-- Change a setting: show it at once, then tell the server to save it.
local function set(key: string, value: any)
	local state = ClientStore.state
	if state == nil or not Settings.valid(key, value) then
		return
	end
	state.settings[key] = value
	SettingsUi.apply(state.settings)
	Remotes.fire("Settings_Set", key, value)
	Panels.refresh()
end

local function heading(body: Instance, text: string, order: number)
	Ui.label(text, { Font = Enum.Font.GothamBold, LayoutOrder = order, Parent = body })
end

local function row(body: Instance, order: number, height: number?): Frame
	local card = Ui.card({ Size = UDim2.new(1, -8, 0, height or 56), LayoutOrder = order, Parent = body })
	Ui.padding(6).Parent = card
	return card
end

-- A labelled row of choices drawn as tabs (a segmented control)
local function choices(
	body: Instance,
	order: number,
	text: string,
	options: { string },
	current: string,
	choose: (string) -> ()
)
	local card = row(body, order)
	Ui.label(text, { Size = UDim2.new(0.38, 0, 1, 0), TextWrapped = true, Parent = card })
	Kit.tabs(options, current, choose, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0.62, 0, 0, 44),
		Parent = card,
	})
end

local function volume(body: Instance, order: number, text: string, key: string, saved: { [string]: any })
	local card = row(body, order)
	Ui.label(text, { Size = UDim2.new(1, -160, 1, 0), Parent = card })
	Kit.stepper(Settings.get(saved, key), 0, Settings.volumeSteps, function(v)
		set(key, v)
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(150, 44),
		Parent = card,
	})
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Settings"
	local saved = state.settings
	local order = 1
	local function nextOrder(): number
		order += 1
		return order
	end

	heading(body, "Sound (0 is off)", nextOrder())
	volume(body, nextOrder(), "Music", "music", saved)
	volume(body, nextOrder(), "Sound effects", "sfx", saved)
	volume(body, nextOrder(), "Button taps", "ui", saved)
	if getAudio() == nil then
		Ui.label("Sound isn't loaded in this place, so these only save for now.", {
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			LayoutOrder = nextOrder(),
			Parent = body,
		})
	end

	heading(body, "Screen", nextOrder())
	choices(
		body,
		nextOrder(),
		"Text size",
		Settings.options.textSize.choices :: { string },
		Settings.get(saved, "textSize"),
		function(v)
			set("textSize", v)
		end
	)
	choices(
		body,
		nextOrder(),
		"Reduce motion",
		{ "Off", "On" },
		if Settings.get(saved, "reduceMotion") then "On" else "Off",
		function(v)
			set("reduceMotion", v == "On")
		end
	)

	heading(body, "Gems", nextOrder())
	choices(
		body,
		nextOrder(),
		"Ask before spending",
		Settings.options.gemConfirm.choices :: { string },
		Settings.get(saved, "gemConfirm"),
		function(v)
			set("gemConfirm", v)
		end
	)
	Ui.label(
		string.format(
			"Always: every Gem spend takes two taps. Over %d: only spends above %d Gems. Never: one tap.",
			Settings.confirmOver,
			Settings.confirmOver
		),
		{
			Size = UDim2.new(1, -8, 0, 36),
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			TextWrapped = true,
			LayoutOrder = nextOrder(),
			Parent = body,
		}
	)

	-- Same options as the Neighbors panel, kept there too
	local social = state.social or {}
	heading(body, "Your farm", nextOrder())
	choices(
		body,
		nextOrder(),
		"Who may visit",
		Social.privacyOptions,
		social.privacy or Social.defaultPrivacy,
		function(v)
			Remotes.fire("Social_SetPrivacy", v)
		end
	)
	choices(
		body,
		nextOrder(),
		"Who may help",
		Social.helperOptions,
		social.helpers or Social.defaultHelpers,
		function(v)
			Remotes.fire("Social_SetHelpers", v)
		end
	)
end

function SettingsUi.init()
	Panels.register("Settings", render, { static = true })
	ClientStore.changed.Event:Connect(function(state)
		SettingsUi.apply(state.settings)
	end)
	if ClientStore.state then
		SettingsUi.apply(ClientStore.state.settings)
	end
end

return SettingsUi
