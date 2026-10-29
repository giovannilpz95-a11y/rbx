--!strict
-- HUD: level star + XP bar, Coins / Gems / Barn pills, paperwork buttons (Orders, Barn,
-- Buildings, Town), the big context action button and Sprint for touch, toasts and reward pop-ups.
-- Layout follows Design/11 UI & UX; the look comes from the UiTheme (Design/25 UI Style Guide).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Ui = require(script.Parent.Ui)

local Kit = Ui.theme.Kit
local Motion = Ui.theme.Motion
local Palette = Ui.theme.Palette
local Type = Ui.theme.Type

local Hud = {}

type Pill = { frame: Frame, label: TextLabel, icon: Frame }
type Bar = { track: Frame, fill: Frame }

local gui: ScreenGui
local coins: Pill
local gems: Pill
local barn: Pill
local levelLabel: TextLabel
local levelStar: Frame
local xpLabel: TextLabel
local xpBar: Bar
local toastStack: Frame
local shown: { [string]: number } = {} -- last values on screen, to tick up and bump on change
Hud.actionButton = nil :: TextButton?
Hud.sprintButton = nil :: TextButton?

function Hud.toast(message: string, variant: string?)
	Kit.toast(toastStack, message, variant)
end

function Hud.popup(payload: { [string]: any })
	if payload.kind == "LevelUp" then
		local parts = { string.format("Level %d!", payload.level) }
		if (payload.coins or 0) > 0 then
			table.insert(parts, string.format("+%d Coins", payload.coins))
		end
		if (payload.gems or 0) > 0 then
			table.insert(parts, string.format("+%d Gems", payload.gems))
		end
		Hud.toast(table.concat(parts, "   "), "celebrate")
		Motion.bump(levelStar, 1.35)
	elseif payload.kind == "Drop" then
		Hud.toast(string.format("Found 1 %s!", payload.name))
	elseif payload.kind == "Field" then
		Hud.toast(string.format("Your town grew: a new field!  +%d XP", payload.xp))
	elseif payload.kind == "Order" then
		Hud.toast(string.format("Order delivered!  +%d Coins  +%d XP", payload.coins, payload.xp))
	end
end

-- Counts a pill up or down to its new value and bumps its icon when it grows.
local function showNumber(key: string, label: TextLabel, icon: Instance, value: number)
	local before = shown[key]
	shown[key] = value
	if before == nil then
		label.Text = Ui.short(value)
		return
	end
	if value ~= before then
		Motion.tick(label, before, value, Ui.short)
		if value > before then
			Motion.bump(icon)
		end
	end
end

function Hud.render(state: { [string]: any })
	showNumber("Coins", coins.label, coins.icon, state.currencies.Coins)
	showNumber("Gems", gems.label, gems.icon, state.currencies.Gems)
	levelLabel.Text = tostring(state.level)
	xpLabel.Text = if state.atCap then "Max level" else string.format("%d / %d", state.xpIntoLevel, state.xpToNext)
	local ratio = if state.atCap or state.xpToNext == 0 then 1 else state.xpIntoLevel / state.xpToNext
	Kit.setBar(xpBar, ratio)
	barn.label.Text = string.format("%d/%d", state.barnUsed, state.barnCapacity)
	-- Orange when the Barn is 90% full (11 UI & UX)
	local nearlyFull = state.barnCapacity > 0 and state.barnUsed >= state.barnCapacity * 0.9
	barn.label.TextColor3 = if nearlyFull then Palette.accentText else Palette.text
end

-- A square HUD button: a big glyph over a small caption, plus a key hint on keyboards.
local function hudButton(glyph: string, caption: string, key: string, order: number, onClick: () -> ()): TextButton
	local button = Ui.button(string.format('%s\n<font size="12">%s</font>', glyph, caption), onClick, {
		Size = UDim2.fromOffset(64, 58),
		LayoutOrder = order,
		RichText = true,
		TextSize = 24,
		LineHeight = 0.9,
		TextColor3 = Palette.text,
		BackgroundColor3 = Palette.button.neutral.face,
	})
	if UserInputService.KeyboardEnabled then
		Ui.new("TextLabel", {
			Name = "KeyHint",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.cocoa,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(20, 20),
			Font = Type.display,
			TextSize = Type.size.small,
			TextColor3 = Palette.textOnColor,
			Text = key,
			ZIndex = 6,
			Parent = button,
		}, { Ui.corner(6) })
	end
	return button
end

function Hud.init(openPanel: (name: string) -> (), onAction: (pressed: boolean) -> ())
	local player = Players.LocalPlayer
	gui = Ui.new("ScreenGui", {
		Name = "FarmHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Top-left: level star on the XP bar, then Coins, Gems and Barn pills. Icons hang off
	-- each pill's left end, so the row leaves room for them.
	local top = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 40),
		Parent = gui,
	}, { Ui.list(24, true) })

	local xpPill = Ui.new("Frame", {
		Name = "XpPill",
		BackgroundColor3 = Palette.cream,
		Size = UDim2.fromOffset(170, 32),
		LayoutOrder = 1,
		Parent = top,
	}, { Ui.new("UICorner", { CornerRadius = UDim.new(1, 0) }), Kit.stroke(Palette.cocoa, 2, 0.1, true) })
	xpBar = Kit.bar(Palette.xp, {
		Position = UDim2.fromOffset(30, 6),
		Size = UDim2.new(1, -36, 1, -12),
		Parent = xpPill,
	})
	xpLabel = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -36, 1, 0),
		Font = Type.display,
		TextSize = Type.size.small,
		TextColor3 = Palette.textOnColor,
		Text = "",
		ZIndex = 2,
		Parent = xpPill,
	})
	Kit.textOutline(xpLabel, Palette.cocoa)
	levelStar = Kit.icon("XP", 54)
	levelStar.AnchorPoint = Vector2.new(0, 0.5)
	levelStar.Position = UDim2.new(0, -20, 0.5, 0)
	levelStar.ZIndex = 3
	levelStar.Parent = xpPill
	levelLabel = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Type.display,
		TextSize = 20,
		TextColor3 = Palette.textOnColor,
		Text = "1",
		ZIndex = 4,
		Parent = levelStar,
	})
	Kit.textOutline(levelLabel, Palette.shade(Palette.xp, 0.45))

	coins = Kit.pill("Coins", 116, { LayoutOrder = 2, Parent = top })
	gems = Kit.pill("Gems", 96, { LayoutOrder = 3, Parent = top })
	barn = Kit.pill("Barn", 104, { LayoutOrder = 4, Parent = top })

	-- Bottom row, left of Sprint: paperwork that works from anywhere on your plot. Kept off the
	-- right edge so it doesn't cover in-world bubbles, and clear of the touch thumbstick.
	-- Each entry: glyph, caption, keyboard hint, panel.
	local row = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -214, 1, -14),
		Size = UDim2.fromOffset(420, 60),
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 8),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local buttons = {
		{ "📋", "Orders", "O", "Orders" },
		{ "🧺", "Barn", "B", "Barn" },
		{ "🏠", "Build", "F", "Buildings" },
		{ "🏘️", "Town", "T", "Town" },
	}
	if RunService:IsStudio() then
		table.insert(buttons, { "🔧", "Debug", "`", "Debug" })
	end
	for i, spec in buttons do
		hudButton(spec[1], spec[2], spec[3], i, function()
			openPanel(spec[4])
		end).Parent = row
	end

	-- Bottom-right: the context action button (hold to sweep) and Sprint, mainly for touch
	local action = Ui.button("Use", function() end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -110),
		Size = UDim2.fromOffset(92, 92),
		TextSize = Type.size.button,
		BackgroundColor3 = Ui.colors.accent,
		Parent = gui,
	})
	local round = action:FindFirstChildOfClass("UICorner") :: UICorner
	round.CornerRadius = UDim.new(1, 0)
	action.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			onAction(true)
		end
	end)
	action.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			onAction(false)
		end
	end)
	Hud.actionButton = action

	local sprint = Ui.button("Sprint", function()
		ClientStore.setSetting("sprinting", not ClientStore.settings.sprinting)
	end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -128, 1, -118),
		Size = UDim2.fromOffset(72, 44),
		Parent = gui,
	})
	local function showSprint(on: boolean)
		sprint.BackgroundColor3 = if on then Ui.colors.selected else Palette.button.neutral.face
		sprint.TextColor3 = if on then Palette.textOnColor else Palette.text
	end
	showSprint(ClientStore.settings.sprinting == true)
	Hud.sprintButton = sprint
	ClientStore.settingsChanged.Event:Connect(function(key, value)
		if key == "sprinting" then
			showSprint(value == true)
		end
	end)

	toastStack = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.new(0.5, 0, 0, 220),
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(420, 220) }),
	})

	Remotes.get("Toast").OnClientEvent:Connect(Hud.toast)
	Remotes.get("Reward_Popup").OnClientEvent:Connect(Hud.popup)
	ClientStore.changed.Event:Connect(Hud.render)
end

function Hud.setActionLabel(text: string)
	if Hud.actionButton then
		Hud.actionButton.Text = text
	end
end

return Hud
