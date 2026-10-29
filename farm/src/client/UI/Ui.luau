--!strict
-- Helpers for building the farm UI in code. The look comes from the shared UiTheme
-- (Design/25 UI Style Guide): build with Ui.button / Ui.label / Ui.card and use Ui.colors
-- rather than raw Color3 values, so screens stay consistent when the theme changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTheme = require(ReplicatedStorage:WaitForChild("UiTheme"))

local Kit = UiTheme.Kit
local Palette = UiTheme.Palette
local Type = UiTheme.Type

local Ui = {}

Ui.theme = UiTheme

Ui.colors = {
	panel = Palette.panel,
	panelEdge = Palette.edge,
	text = Palette.text,
	muted = Palette.muted,
	button = Palette.button.primary.face,
	buttonText = Palette.textOnColor,
	disabled = Palette.button.disabled.face,
	danger = Palette.button.danger.face,
	selected = Palette.button.secondary.face, -- the picked option in a row of choices
	accent = Palette.button.attention.face, -- the big action button, an armed confirm
	bar = Palette.timer, -- dark status bubbles and counters
	ready = Palette.ready,
	warn = Palette.warn,
	coins = Palette.coins,
	gems = Palette.gems,
	xp = Palette.xp,
}

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	return Kit.make(className, props, children)
end

function Ui.corner(radius: number?): UICorner
	return Kit.corner(radius or 10)
end

function Ui.padding(px: number): UIPadding
	local d = UDim.new(0, px)
	return Ui.new("UIPadding", { PaddingTop = d, PaddingBottom = d, PaddingLeft = d, PaddingRight = d })
end

function Ui.list(padding: number?, horizontal: boolean?): UIListLayout
	return Ui.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	})
end

-- Body text in the plain face. Bold labels (Font = GothamBold) are headings, so they get the
-- rounded display face instead.
function Ui.label(text: string, props: { [string]: any }?): TextLabel
	local label = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Type.body,
		TextColor3 = Ui.colors.text,
		TextSize = Type.size.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
		Text = text,
	})
	if props then
		for key, value in props do
			if key == "Font" and value == Enum.Font.GothamBold then
				value = Type.display
			end
			(label :: any)[key] = value
		end
	end
	return label
end

-- A chunky themed button. Setting BackgroundColor3 (here or later) recolours the face and lip.
function Ui.button(text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local button = Ui.new("TextButton", {
		BackgroundColor3 = Ui.colors.button,
		Font = Type.display,
		TextColor3 = Ui.colors.buttonText,
		TextSize = 16,
		Size = UDim2.fromOffset(90, 32),
		Text = text,
	}, { Ui.corner(10) })
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(button :: any)[key] = value
			end
		end
	end
	Kit.skinButton(button, nil, 4)
	button.Activated:Connect(function()
		if button.Active then
			onClick()
		end
	end)
	if parent then
		button.Parent = parent
	end
	return button
end

function Ui.setEnabled(button: TextButton, enabled: boolean, color: Color3?)
	button.Active = enabled
	button.BackgroundColor3 = if enabled then (color or Ui.colors.button) else Ui.colors.disabled
end

-- A white rounded row for panel lists.
function Ui.card(props: { [string]: any }?): Frame
	return Kit.card(props)
end

-- 12400 -> "12.4K"
Ui.short = Kit.short

function Ui.clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end
end

return Ui
