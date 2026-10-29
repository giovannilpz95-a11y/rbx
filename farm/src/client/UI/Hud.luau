--!strict
-- HUD: Coins / Gems / level + XP bar / Barn counter, paperwork buttons (Orders, Barn,
-- Buildings, Town), the big context action button and Sprint for touch, toasts and reward pop-ups.
-- Layout follows Design/11 UI & UX loosely; it is a greybox, not the final look.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Ui = require(script.Parent.Ui)

local Hud = {}

local gui: ScreenGui
local coinsLabel: TextLabel
local gemsLabel: TextLabel
local levelLabel: TextLabel
local xpFill: Frame
local barnLabel: TextLabel
local toastStack: Frame
local showPanel: (name: string) -> () = function() end
Hud.actionButton = nil :: TextButton?
Hud.sprintButton = nil :: TextButton?

local function statChip(parent: Instance, color: Color3, order: number): TextLabel
	local chip = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.bar,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(110, 34),
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.corner(17) })
	Ui.new(
		"Frame",
		{ BackgroundColor3 = color, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(6, 6), Parent = chip },
		{ Ui.corner(11) }
	)
	return Ui.label("0", {
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -40, 1, 0),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		Parent = chip,
	})
end

function Hud.toast(message: string)
	local label = Ui.label(message, {
		BackgroundColor3 = Ui.colors.bar,
		BackgroundTransparency = 0.2,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = toastStack,
	})
	Ui.corner(8).Parent = label
	task.delay(3, function()
		local tween =
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		label:Destroy()
	end)
end

function Hud.popup(payload: { [string]: any })
	if payload.kind == "LevelUp" then
		local parts = { string.format("Level %d!", payload.level) }
		if (payload.coins or 0) > 0 then
			table.insert(parts, string.format("+%d Coins", payload.coins))
		end
		if (payload.gems or 0) > 0 then
			table.insert(parts, string.format("+%d %s", payload.gems, if payload.gems == 1 then "Gem" else "Gems"))
		end
		Hud.toast(table.concat(parts, "   "))
	elseif payload.kind == "Field" then
		Hud.toast(string.format("Your town grew: a new field!  +%d XP", payload.xp))
	elseif payload.kind == "BarnUpgrade" then
		Hud.toast(string.format("Barn upgraded: room for %d!", payload.capacity))
	elseif payload.kind == "Drop" then
		Hud.toast(string.format("Found 1 %s!", payload.name))
	elseif payload.kind == "Order" then
		Hud.toast(string.format("Order delivered!  +%d Coins  +%d XP", payload.coins, payload.xp))
	elseif payload.kind == "Daily" then
		Hud.toast(string.format("Daily gift, day %d of %d:  %s", payload.day, payload.days, payload.reward))
	elseif payload.kind == "Away" then
		ClientStore.away = payload.lines
		showPanel("Away")
	end
end

function Hud.render(state: { [string]: any })
	coinsLabel.Text = tostring(state.currencies.Coins)
	gemsLabel.Text = tostring(state.currencies.Gems)
	levelLabel.Text = if state.atCap
		then string.format("Lv %d (max)", state.level)
		else string.format("Lv %d   %d / %d XP", state.level, state.xpIntoLevel, state.xpToNext)
	local ratio = if state.atCap or state.xpToNext == 0 then 1 else math.clamp(state.xpIntoLevel / state.xpToNext, 0, 1)
	xpFill.Size = UDim2.fromScale(ratio, 1)
	barnLabel.Text = string.format("Barn %d/%d", state.barnUsed, state.barnCapacity)
end

function Hud.init(openPanel: (name: string) -> (), onAction: (pressed: boolean) -> ())
	showPanel = openPanel
	local player = Players.LocalPlayer
	gui = Ui.new("ScreenGui", {
		Name = "FarmHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Top-left: currencies, level, Barn
	local top = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = gui,
	}, { Ui.list(8, true) })
	coinsLabel = statChip(top, Ui.colors.coins, 1)
	gemsLabel = statChip(top, Ui.colors.gems, 2)

	local levelChip = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.bar,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(200, 34),
		LayoutOrder = 3,
		ClipsDescendants = true,
		Parent = top,
	}, { Ui.corner(17) })
	xpFill = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.xp,
		BackgroundTransparency = 0.3,
		Size = UDim2.fromScale(0, 1),
		Parent = levelChip,
	})
	levelLabel = Ui.label("Lv 1", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Parent = levelChip,
	})
	barnLabel = statChip(top, Ui.colors.panelEdge, 4)
	barnLabel.TextSize = 15

	-- Right column: paperwork that works from anywhere on your plot
	local column = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 52),
		Size = UDim2.fromOffset(110, 260),
		Parent = gui,
	}, { Ui.list(8) })
	local buttons = {
		{ "Orders (O)", "Orders" },
		{ "Barn (B)", "Barn" },
		{ "Buildings (F)", "Buildings" },
		{ "Town (T)", "Town" },
	}
	if RunService:IsStudio() then
		table.insert(buttons, { "Debug (`)", "Debug" })
	end
	for i, spec in buttons do
		Ui.button(spec[1], function()
			openPanel(spec[2])
		end, { Size = UDim2.fromOffset(110, 38), LayoutOrder = i, Parent = column })
	end

	-- Bottom-right: the context action button (hold to sweep) and Sprint, mainly for touch
	local action = Ui.button("Use", function() end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -110),
		Size = UDim2.fromOffset(88, 88),
		TextSize = 16,
		BackgroundColor3 = Color3.fromRGB(230, 160, 50),
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
		Position = UDim2.new(1, -124, 1, -120),
		Size = UDim2.fromOffset(64, 40),
		Parent = gui,
	})
	Hud.sprintButton = sprint
	ClientStore.settingsChanged.Event:Connect(function(key, value)
		if key == "sprinting" then
			Ui.setEnabled(sprint, true, if value then Color3.fromRGB(70, 120, 200) else nil)
		end
	end)

	toastStack = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(0.5, 0, 0, 200),
		Parent = gui,
	}, { Ui.list(4), Ui.new("UISizeConstraint", { MaxSize = Vector2.new(420, 200) }) })

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
