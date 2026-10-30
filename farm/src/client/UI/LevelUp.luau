--!strict
-- The level-up celebration (UI Reference & Gaps G1, Township's convention C12): a full-screen
-- moment with the big level star, the rewards (Coins, Gems and any gift items), a "New!" row
-- of what the level opens up (shared/Unlocks) and one Continue button. On Continue the rewards
-- fly into their HUD counters. Several level-ups in a row show one after another.
-- Continue: the button, a tap anywhere after half a second, Enter or the gamepad A button.
-- Studio only: U shows the window for the current level, for screenshots.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local ArtIcons = require(Shared.Art.Icons)
local Items = require(Shared.Items)
local Progression = require(Shared.Progression)
local Unlocks = require(Shared.Unlocks)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local Kit = Ui.theme.Kit
local Motion = Ui.theme.Motion
local Palette = Ui.theme.Palette
local Type = Ui.theme.Type

local LevelUp = {}

local GLYPHS: { [string]: string } = {
	Factory = "🏭",
	Pen = "🐾",
	House = "🏠",
	Community = "🏛️",
	Decor = "🌳",
	Daily = "🎁",
	Tools = "🧰",
	Materials = "🧱",
}
local KIND_NAMES: { [string]: string } = {
	Factory = "Factory",
	Pen = "Animals",
	Crop = "Crop",
	Recipe = "Recipe",
	House = "House",
	Community = "Town",
	Decor = "Decoration",
	Feature = "New",
}
local SKIP_AFTER = 0.5 -- a tap anywhere continues after this long (mobile checklist)

local gui: ScreenGui
local window: any -- UiTheme Kit.panel
local queue: { { [string]: any } } = {}
local showing = false
local shownAt = 0
local flyFrom: { { kind: string, gui: GuiObject, item: string? } } = {}

local function itemName(id: string): string
	local item = Items[id]
	return if item then item.displayName else id
end

-- Screen pixels of a GuiObject in this full-screen layer, moved into the HUD's space
-- (the HUD keeps the top bar inset; this window covers it).
local function hudPoint(object: GuiObject): Vector2
	local inset = GuiService:GetGuiInset()
	return Fx.centerOf(object) - inset
end

local function rewardChip(parent: Instance, order: number, text: string, build: (holder: Frame) -> ()): Frame
	local chip = Ui.new("Frame", {
		Name = "Reward",
		BackgroundColor3 = Palette.card,
		Size = UDim2.fromOffset(104, 48),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.corner(12), Kit.stroke(Palette.edge, 1.5, 0.4, true) })
	local holder = Ui.new("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(40, 40),
		Parent = chip,
	})
	build(holder)
	Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -50, 1, 0),
		Font = Type.display,
		TextSize = Type.size.heading,
		TextScaled = true,
		TextColor3 = Palette.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		Parent = chip,
	}, { Ui.new("UITextSizeConstraint", { MaxTextSize = Type.size.heading, MinTextSize = Type.size.small }) })
	return chip
end

local function unlockCard(parent: Instance, order: number, unlock: Unlocks.Unlock)
	local card = Ui.new("Frame", {
		Name = unlock.id,
		BackgroundColor3 = Palette.card,
		Size = UDim2.fromOffset(92, 104),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.corner(12), Kit.stroke(Palette.edge, 1.5, 0.4, true) })
	if unlock.item then
		local ok, icon = pcall(ArtIcons.viewport, unlock.item, 52)
		if ok then
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 6)
			icon.Parent = card
		end
	else
		Ui.new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(52, 52),
			Font = Type.display,
			TextSize = 38,
			Text = GLYPHS[unlock.id] or GLYPHS[unlock.kind] or "✨",
			Parent = card,
		})
	end
	Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0, 60),
		Size = UDim2.new(1, -8, 0, 26),
		Font = Type.display,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Palette.text,
		Text = if unlock.extra then "+1 " .. unlock.name else unlock.name,
		Parent = card,
	}, { Ui.new("UITextSizeConstraint", { MaxTextSize = Type.size.small, MinTextSize = 9 }) })
	Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0, 84),
		Size = UDim2.new(1, -8, 0, 16),
		Font = Type.body,
		TextSize = 12,
		TextColor3 = Palette.muted,
		Text = KIND_NAMES[unlock.kind] or "",
		Parent = card,
	})
	-- A little "New!" flag on the corner
	Ui.new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Palette.badge,
		Position = UDim2.new(1, 4, 0, -6),
		Size = UDim2.fromOffset(38, 18),
		Font = Type.display,
		TextSize = 12,
		TextColor3 = Palette.textOnColor,
		Text = "New!",
		ZIndex = 3,
		Parent = card,
	}, { Kit.corner(UDim.new(1, 0)) })
end

local function render(payload: { [string]: any })
	local body = window.body
	for _, child in body:GetChildren() do
		if not child:IsA("UICorner") then
			child:Destroy()
		end
	end
	table.clear(flyFrom)
	window.title.Text = "Level up!"

	local content = Ui.new("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 1, -66),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Palette.edge,
		Selectable = false,
		Parent = body,
	}, { Ui.list(8) })

	-- The big star with the new level, and a line beside it
	local top = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 92),
		LayoutOrder = 1,
		Parent = content,
	})
	local star = Kit.icon("XP", 92)
	star.Parent = top
	local number = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Type.display,
		TextSize = 36,
		TextColor3 = Palette.textOnColor,
		Text = tostring(payload.level),
		ZIndex = 4,
		Parent = star,
	})
	Kit.textOutline(number, Palette.shade(Palette.xp, 0.45))
	Motion.popIn(star)
	Motion.loop(star, { Rotation = 6 }, 1.2)
	Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(104, 8),
		Size = UDim2.new(1, -104, 0, 34),
		Font = Type.display,
		TextScaled = true,
		TextColor3 = Palette.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("You reached level %d!", payload.level),
		Parent = top,
	}, { Ui.new("UITextSizeConstraint", { MaxTextSize = Type.size.title, MinTextSize = Type.size.body }) })
	Ui.label("Your town is growing. Here's a gift, and what's new.", {
		Position = UDim2.fromOffset(104, 46),
		Size = UDim2.new(1, -104, 0, 40),
		TextWrapped = true,
		TextColor3 = Palette.muted,
		TextSize = Type.size.small,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = top,
	})

	-- Rewards (already in the wallet; these fly to the counters on Continue)
	local rewards = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = content,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(104, 48),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local order = 0
	for _, kind in { "Coins", "Gems" } do
		local amount = payload[string.lower(kind)] or 0
		if amount > 0 then
			order += 1
			local chip = rewardChip(rewards, order, "+" .. Ui.short(amount), function(holder)
				local icon = Kit.icon(kind, 40)
				icon.Parent = holder
			end)
			table.insert(flyFrom, { kind = kind, gui = chip })
		end
	end
	local gifts = {}
	for item in payload.gifts or {} do
		table.insert(gifts, item)
	end
	table.sort(gifts)
	for _, item in gifts do
		order += 1
		local chip = rewardChip(rewards, order, "x" .. tostring(payload.gifts[item]), function(holder)
			local ok, icon = pcall(ArtIcons.viewport, item, 40)
			if ok then
				icon.Parent = holder
			end
		end)
		chip.Name = itemName(item)
		table.insert(flyFrom, { kind = "Item", gui = chip, item = item })
	end
	if order == 0 then
		rewards.Visible = false
	end

	-- New! What this level opens up
	local unlocks = Unlocks.at(payload.level)
	if #unlocks > 0 then
		Ui.label("New!", { Font = Enum.Font.GothamBold, LayoutOrder = 3, Parent = content })
		local strip = Ui.new("ScrollingFrame", {
			Name = "NewStrip",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 120),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Palette.edge,
			Selectable = false,
			LayoutOrder = 4,
			Parent = content,
		}, {
			Ui.list(8, true),
			Ui.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2) }),
		})
		for i, unlock in unlocks do
			unlockCard(strip, i, unlock)
		end
	end

	local continue = Kit.button("Continue", "primary", {
		Name = "Continue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(200, 48),
		TextSize = Type.size.heading,
		Parent = body,
	})
	Kit.onTap(continue, LevelUp.continue)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = continue
	end
end

local function showNext()
	local payload = table.remove(queue, 1)
	if payload == nil then
		showing = false
		gui.Enabled = false
		return
	end
	showing = true
	shownAt = time()
	render(payload)
	gui.Enabled = true
	Motion.popIn(window.root)
end

-- Close the window, send the rewards flying, then show the next level-up if there is one.
function LevelUp.continue()
	if not showing then
		return
	end
	for _, entry in flyFrom do
		local from = hudPoint(entry.gui)
		if entry.kind == "Item" and entry.item then
			Fx.item(entry.item, from)
		else
			Fx.currency(entry.kind, from, 4)
		end
	end
	table.clear(flyFrom)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	showNext()
end

-- payload: { level, coins, gems, gifts = { [itemId] = qty }? } (the server's LevelUp pop-up)
function LevelUp.show(payload: { [string]: any })
	table.insert(queue, payload)
	if not showing then
		showNext()
	end
end

function LevelUp.isShowing(): boolean
	return showing
end

function LevelUp.init()
	gui = Ui.new("ScreenGui", {
		Name = "FarmLevelUp",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- The dim backdrop doubles as "tap anywhere to continue"
	local scrim = Ui.new("TextButton", {
		Name = "Scrim",
		AutoButtonColor = false,
		BackgroundColor3 = Palette.scrim,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Parent = gui,
	})
	scrim.Activated:Connect(function()
		if time() - shownAt >= SKIP_AFTER then
			LevelUp.continue()
		end
	end)
	window = Kit.panel(LevelUp.continue)
	window.root.AnchorPoint = Vector2.new(0.5, 0.5)
	window.root.Position = UDim2.fromScale(0.5, 0.52)
	window.root.Size = UDim2.new(0.92, 0, 0.84, 0)
	window.root.ZIndex = 2
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(480, 400) }).Parent = window.root
	window.root.Parent = gui

	Hud.levelUpHandler = LevelUp.show

	UserInputService.InputBegan:Connect(function(input, processed)
		if showing then
			local key = input.KeyCode
			if key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter or key == Enum.KeyCode.ButtonA then
				if time() - shownAt >= SKIP_AFTER then
					LevelUp.continue()
				end
			end
			return
		end
		if processed or not RunService:IsStudio() then
			return
		end
		if input.KeyCode == Enum.KeyCode.U then
			-- Preview for screenshots; nothing is granted
			local state = ClientStore.state
			local level = if state then state.level else 2
			local coins, gems = Progression.reward(level)
			LevelUp.show({ level = level, coins = coins, gems = gems, gifts = { Wheat = 2 }, preview = true })
		end
	end)
end

return LevelUp
