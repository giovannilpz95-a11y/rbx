--!strict
-- Building blocks for the Township-like look (Design/25 UI Style Guide): chunky glossy buttons
-- with a darker lip, cream windows with a ribbon title and a round red close button, currency
-- pills with an icon hanging off the left end, glossy progress bars, badges, toasts and the
-- in-world status bubbles. Everything is drawn from frames, so no image assets are needed;
-- the art pass can swap icons for sprites later without changing callers.

local Format = require(script.Parent.Format)
local Motion = require(script.Parent.Motion)
local Palette = require(script.Parent.Palette)
local Type = require(script.Parent.Type)

local Kit = {}

local function make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end
Kit.make = make

local function childOfClass(instance: Instance, className: string): Instance?
	for _, child in instance:GetChildren() do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

function Kit.corner(radius: UDim | number): UICorner
	return make("UICorner", { CornerRadius = if typeof(radius) == "number" then UDim.new(0, radius) else radius })
end

function Kit.stroke(color: Color3, thickness: number?, transparency: number?, border: boolean?): UIStroke
	local stroke = make("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
	})
	if border then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	return stroke
end

-- Vertical gloss: full colour at the top fading to `bottom` brightness.
function Kit.gloss(bottom: number?): UIGradient
	local b = bottom or 0.86
	return make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(b, b, b)),
	})
end

-- An outline around light text so it reads on colour (Contextual stroke = the glyphs).
function Kit.textOutline(label: TextLabel | TextButton, color: Color3): UIStroke
	local stroke = make("UIStroke", {
		Name = "TextOutline",
		Color = color,
		Thickness = Type.strokeThickness,
		Transparency = Type.strokeTransparency,
	})
	stroke.Parent = label
	return stroke
end

---------------------------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------------------------

local MIRRORED = {
	"Text",
	"TextSize",
	"TextScaled",
	"Font",
	"TextColor3",
	"TextWrapped",
	"RichText",
	"TextXAlignment",
	"TextYAlignment",
	"LineHeight",
}

--[[
	Turns a TextButton into a chunky button: a darker lip under a glossy face, an outline,
	a shine strip, and outlined text that sinks into the lip when pressed.

	The button itself stays the API: keep setting Text, TextSize, Font, TextColor3 or
	BackgroundColor3 on it (the face follows, and the lip is picked to match), and keep
	connecting to Activated. A UIPadding on the button moves onto the text.
]]
function Kit.skinButton(button: TextButton, variant: string?, lipHeight: number?): TextButton
	if variant and Palette.button[variant] then
		button.BackgroundColor3 = Palette.button[variant].face
	end
	local lip = lipHeight or 4
	local cornerInstance = childOfClass(button, "UICorner") :: UICorner?
	local radius = if cornerInstance then cornerInstance.CornerRadius else UDim.new(0, 12)

	local lipFrame = make("Frame", {
		Name = "ButtonLip",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = button,
	}, { make("UICorner", { CornerRadius = radius }) })
	local outline = Kit.stroke(Palette.cocoa, 1.5, 0.45, true)
	outline.Parent = lipFrame
	local face = make("Frame", {
		Name = "ButtonFace",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -lip),
		ZIndex = 2,
		Parent = button,
	}, { make("UICorner", { CornerRadius = radius }), Kit.gloss(0.88) })
	make("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 5, 0, 3),
		Size = UDim2.new(1, -10, 0.3, 0),
		ZIndex = 3,
		Parent = face,
	}, { make("UICorner", { CornerRadius = radius }) })
	local label = make("TextLabel", {
		Name = "ButtonLabel",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -lip),
		ZIndex = 4,
		Parent = button,
	})
	local textOutline = Kit.textOutline(label, Palette.cocoa)

	-- Text sizing and padding belong to the visible text, not the art behind it, including
	-- ones the caller adds after skinning.
	local function adopt(child: Instance)
		if child:IsA("UIPadding") or child:IsA("UITextSizeConstraint") then
			child.Parent = label
		end
	end
	for _, child in button:GetChildren() do
		adopt(child)
	end
	button.ChildAdded:Connect(adopt)

	local function syncColor()
		local faceColor = button.BackgroundColor3
		local lipColor = Palette.lipFor(faceColor)
		face.BackgroundColor3 = faceColor
		lipFrame.BackgroundColor3 = lipColor
		textOutline.Color = Palette.shade(lipColor, 0.8)
	end
	local function syncText()
		for _, key in MIRRORED do
			(label :: any)[key] = (button :: any)[key]
		end
		-- Outline light text only; dark text on a light face reads fine without it.
		local light = Palette.luminance(button.TextColor3) > 0.6
		textOutline.Enabled = light
	end
	syncColor()
	syncText()

	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.TextTransparency = 1
	button.BorderSizePixel = 0

	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(syncColor)
	for _, key in MIRRORED do
		button:GetPropertyChangedSignal(key):Connect(syncText)
	end
	if cornerInstance then
		cornerInstance:GetPropertyChangedSignal("CornerRadius"):Connect(function()
			for _, part in { lipFrame, face, face:FindFirstChild("Shine") } do
				local c = childOfClass(part :: Instance, "UICorner") :: UICorner?
				if c then
					c.CornerRadius = (cornerInstance :: UICorner).CornerRadius
				end
			end
		end)
	end

	Motion.press(button, function(pressed)
		local sink = if pressed then lip - 1 else 0
		face.Position = UDim2.fromOffset(0, sink)
		label.Position = UDim2.fromOffset(0, sink)
	end)
	return button
end

-- A new themed TextButton. `props` are applied before skinning (Size, Position, Parent...).
function Kit.button(text: string, variant: string?, props: { [string]: any }?): TextButton
	local button = make("TextButton", {
		Text = text,
		Font = Type.display,
		TextSize = Type.size.button,
		TextColor3 = Palette.textOnColor,
		Size = UDim2.fromOffset(110, 40),
	}, { Kit.corner(12) })
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
	Kit.skinButton(button, variant or "primary")
	if parent then
		button.Parent = parent
	end
	return button
end

---------------------------------------------------------------------------------------------
-- Surfaces
---------------------------------------------------------------------------------------------

-- A white rounded card for list rows and item slots.
function Kit.card(props: { [string]: any }?): Frame
	local card = make("Frame", {
		BackgroundColor3 = Palette.card,
		BorderSizePixel = 0,
	}, { Kit.corner(12), Kit.stroke(Palette.edge, 1.5, 0.55) })
	if props then
		for key, value in props do
			(card :: any)[key] = value
		end
	end
	return card
end

-- Gives an existing Frame (or a TextLabel used as a box) the window look: cream body,
-- honey-brown outline, and a soft gloss on Frames (a gradient would tint a label's text).
function Kit.skinPanel(frame: GuiObject)
	frame.BackgroundColor3 = Palette.panel
	frame.BorderSizePixel = 0
	Kit.stroke(Palette.edge, 3, 0, true).Parent = frame
	if frame:IsA("Frame") and childOfClass(frame, "UIGradient") == nil then
		Kit.gloss(0.96).Parent = frame
	end
end

export type Panel = {
	root: Frame,
	card: Frame,
	ribbon: Frame,
	title: TextLabel,
	close: TextButton,
	body: Frame,
}

--[[
	A window: drop shadow, cream card with an outline, a blue ribbon title plaque
	sitting on the top edge, a round red close button on the top-right corner and
	a paper-coloured inset `body` for content. Size and place `root` yourself.
]]
function Kit.panel(onClose: () -> ()): Panel
	local root = make("Frame", { Name = "Window", BackgroundTransparency = 1 })
	make("Frame", {
		Name = "Shadow",
		ZIndex = 1,
		BackgroundColor3 = Palette.scrim,
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}, { Kit.corner(20) })
	local card = make("Frame", {
		Name = "Card",
		ZIndex = 2,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}, { Kit.corner(20) })
	Kit.skinPanel(card)
	local body = make("Frame", {
		Name = "Body",
		BackgroundColor3 = Palette.paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 1, -48),
		Parent = card,
	}, { Kit.corner(14) })

	local ribbon = make("Frame", {
		Name = "Ribbon",
		ZIndex = 3,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.ribbonLip,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.62, 0, 0, 46),
		Parent = root,
	}, {
		Kit.corner(16),
		Kit.stroke(Palette.cocoa, 1.5, 0.45, true),
		make("UISizeConstraint", { MinSize = Vector2.new(200, 0) }),
	})
	local ribbonFace = make("Frame", {
		Name = "Face",
		BackgroundColor3 = Palette.ribbon,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -5),
		Parent = ribbon,
	}, { Kit.corner(16), Kit.gloss(0.85) })
	local title = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Type.display,
		TextSize = Type.size.title - 2,
		TextColor3 = Palette.textOnColor,
		Text = "",
		Parent = ribbonFace,
	}, {
		make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		make("UITextSizeConstraint", { MaxTextSize = Type.size.title - 2, MinTextSize = Type.size.small }),
	})
	title.TextScaled = true
	Kit.textOutline(title, Palette.ribbonLip)

	local close = Kit.button("X", "danger", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(42, 42),
		TextSize = 22,
		ZIndex = 5,
		Parent = root,
	})
	local closeCorner = childOfClass(close, "UICorner") :: UICorner
	closeCorner.CornerRadius = UDim.new(1, 0)
	for _, part in { close:FindFirstChild("ButtonLip"), close:FindFirstChild("ButtonFace") } do
		local c = childOfClass(part :: Instance, "UICorner") :: UICorner
		c.CornerRadius = UDim.new(1, 0)
	end
	close.Activated:Connect(onClose)

	return { root = root, card = card, ribbon = ribbon, title = title, close = close, body = body }
end

---------------------------------------------------------------------------------------------
-- Icons (our own simple shapes; the art pass can replace them with sprites)
---------------------------------------------------------------------------------------------

local function disc(color: Color3, size: UDim2, parent: Instance, rotation: number?, zIndex: number?): Frame
	return make("Frame", {
		ZIndex = zIndex or 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = rotation or 0,
		Size = size,
		Parent = parent,
	})
end

-- kind: "Coins" | "Gems" | "XP" | "Barn". Returns a square Frame of `size` pixels.
function Kit.icon(kind: string, size: number): Frame
	local holder = make("Frame", {
		Name = kind .. "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
	}, { make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	if kind == "Coins" then
		local coin = disc(Palette.coins, UDim2.fromScale(0.9, 0.9), holder)
		Kit.corner(UDim.new(1, 0)).Parent = coin
		Kit.stroke(Palette.shade(Palette.coins, 0.62), 2, 0, true).Parent = coin
		local inner = disc(Palette.shade(Palette.coins, 0.9), UDim2.fromScale(0.6, 0.6), coin)
		Kit.corner(UDim.new(1, 0)).Parent = inner
		local shine = disc(Color3.new(1, 1, 1), UDim2.fromScale(0.22, 0.22), coin, 0, 2)
		shine.Position = UDim2.fromScale(0.3, 0.3)
		shine.BackgroundTransparency = 0.25
		Kit.corner(UDim.new(1, 0)).Parent = shine
	elseif kind == "Gems" then
		local gem = disc(Palette.gems, UDim2.fromScale(0.66, 0.66), holder, 45)
		Kit.corner(4).Parent = gem
		Kit.stroke(Palette.shade(Palette.gems, 0.55), 2, 0, true).Parent = gem
		Kit.gloss(0.75).Parent = gem
		local shine = disc(Color3.new(1, 1, 1), UDim2.fromScale(0.34, 0.34), gem)
		shine.Position = UDim2.fromScale(0.32, 0.32)
		shine.BackgroundTransparency = 0.35
		Kit.corner(3).Parent = shine
	elseif kind == "XP" then
		-- An eight-point star: two squares, a darker rim under a lighter middle
		local rim = Palette.shade(Palette.xp, 0.68)
		disc(rim, UDim2.fromScale(0.74, 0.74), holder, 0, 1)
		disc(rim, UDim2.fromScale(0.74, 0.74), holder, 45, 1)
		disc(Palette.xp, UDim2.fromScale(0.62, 0.62), holder, 0, 2)
		disc(Palette.xp, UDim2.fromScale(0.62, 0.62), holder, 45, 2)
	elseif kind == "Barn" then
		-- A little barn: red roof (a turned square) over a wooden body with a dark door
		local roofColor = Palette.hex("#D9534F")
		local roof = disc(roofColor, UDim2.fromScale(0.58, 0.58), holder, 45, 1)
		roof.Position = UDim2.fromScale(0.5, 0.42)
		Kit.corner(3).Parent = roof
		Kit.stroke(Palette.shade(roofColor, 0.6), 2, 0, true).Parent = roof
		local body = disc(Palette.wood, UDim2.fromScale(0.66, 0.42), holder, 0, 2)
		body.Position = UDim2.fromScale(0.5, 0.7)
		Kit.corner(3).Parent = body
		Kit.stroke(Palette.shade(Palette.wood, 0.55), 2, 0, true).Parent = body
		local door = disc(Palette.shade(Palette.wood, 0.55), UDim2.fromScale(0.3, 0.7), body)
		door.Position = UDim2.fromScale(0.5, 0.65)
		Kit.corner(2).Parent = door
	end
	return holder
end

---------------------------------------------------------------------------------------------
-- HUD pieces
---------------------------------------------------------------------------------------------

export type Pill = { frame: Frame, label: TextLabel, icon: Frame }

-- A cream pill with a dark outline, an icon hanging off its left end and a number.
function Kit.pill(iconKind: string, width: number, props: { [string]: any }?): Pill
	local frame = make("Frame", {
		Name = iconKind .. "Pill",
		BackgroundColor3 = Palette.cream,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, 32),
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Palette.cocoa, 2, 0.1, true), Kit.gloss(0.92) })
	local icon = Kit.icon(iconKind, 40)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, -14, 0.5, 0)
	icon.ZIndex = 2
	icon.Parent = frame
	local label = make("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -38, 1, 0),
		Font = Type.display,
		TextSize = Type.size.hud,
		TextColor3 = Palette.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "0",
		Parent = frame,
	})
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	return { frame = frame, label = label, icon = icon }
end

export type Bar = { track: Frame, fill: Frame }

-- A glossy progress bar; set the fill with Kit.setBar.
function Kit.bar(color: Color3, props: { [string]: any }?): Bar
	local track = make("Frame", {
		Name = "Bar",
		BackgroundColor3 = Palette.shade(Palette.paper, 0.82),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, { Kit.corner(UDim.new(1, 0)) })
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Kit.corner(UDim.new(1, 0)), Kit.gloss(0.8) })
	if props then
		for key, value in props do
			(track :: any)[key] = value
		end
	end
	return { track = track, fill = fill }
end

function Kit.setBar(bar: Bar, ratio: number)
	local r = math.clamp(ratio, 0, 1)
	bar.fill.Visible = r > 0
	Motion.tween(bar.fill, 0.25, { Size = UDim2.fromScale(r, 1) })
end

-- A red count bubble on a button's top-right corner. Text "" hides it.
function Kit.badge(parent: GuiObject, text: string): TextLabel
	local badge = parent:FindFirstChild("Badge") :: TextLabel?
	if badge == nil then
		local created = make("TextLabel", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.badge,
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(22, 22),
			Font = Type.display,
			TextSize = Type.size.small,
			TextColor3 = Palette.textOnColor,
			ZIndex = 6,
			Parent = parent,
		}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Color3.new(1, 1, 1), 2, 0, true) })
		badge = created
	end
	local b = badge :: TextLabel
	b.Text = text
	b.Visible = text ~= ""
	return b
end

-- A toast pill that pops in, waits, fades and removes itself. variant "celebrate" uses the ribbon blue.
function Kit.toast(parent: Instance, text: string, variant: string?, seconds: number?): TextLabel
	local celebrate = variant == "celebrate"
	local label = make("TextLabel", {
		Name = "Toast",
		BackgroundColor3 = if celebrate then Palette.ribbon else Palette.cream,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, if celebrate then 44 else 36),
		Font = Type.display,
		TextSize = if celebrate then Type.size.heading else Type.size.hud - 1,
		TextColor3 = if celebrate then Palette.textOnColor else Palette.text,
		TextWrapped = true,
		Text = text,
		Parent = parent,
	}, {
		Kit.corner(UDim.new(1, 0)),
		Kit.stroke(if celebrate then Palette.ribbonLip else Palette.cocoa, 2, 0.1, true),
		make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	})
	if celebrate then
		Kit.textOutline(label, Palette.ribbonLip)
	end
	Motion.popIn(label)
	task.delay(seconds or 3, function()
		local fade = Motion.time.fade
		Motion.tween(label, fade, { TextTransparency = 1, BackgroundTransparency = 1 })
		for _, child in label:GetChildren() do
			if child:IsA("UIStroke") then
				Motion.tween(child, fade, { Transparency = 1 })
			end
		end
		task.delay(fade, function()
			label:Destroy()
		end)
	end)
	return label
end

---------------------------------------------------------------------------------------------
-- In-world status bubbles
---------------------------------------------------------------------------------------------

-- Styles a BillboardGui label as a status bubble: rounded, white rim, outlined text.
function Kit.skinBubble(label: TextLabel)
	label.Font = Type.display
	label.TextColor3 = Palette.textOnColor
	label.BackgroundColor3 = Palette.timer
	label.BackgroundTransparency = 0.15
	label.TextStrokeColor3 = Palette.cocoa
	label.TextStrokeTransparency = 0.4
	local c = childOfClass(label, "UICorner") :: UICorner?
	if c then
		c.CornerRadius = UDim.new(1, 0)
	else
		Kit.corner(UDim.new(1, 0)).Parent = label
	end
	Kit.stroke(Color3.new(1, 1, 1), 2.5, 0, true).Parent = label
end

---------------------------------------------------------------------------------------------
-- Tabs, steppers, have/need chips, portraits, icon bubbles and edge icons
-- (Design/UI Reference & Gaps G13: the parts most of the bigger screens are built from)
---------------------------------------------------------------------------------------------

local function applyProps(instance: Instance, props: { [string]: any }?)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
end

-- Pointer press, for buttons that act on the press itself: a window that re-renders between
-- press and release would otherwise swallow the tap (the farm panels refresh every second).
local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Calls `fn` once per tap, from the press or from Activated (keyboard and gamepad),
-- whichever comes first.
local function onTap(button: TextButton, fn: () -> ())
	local last = -1
	local function fire()
		if time() - last < 0.35 or not button.Active then
			return
		end
		last = time()
		fn()
	end
	button.InputBegan:Connect(function(input)
		if isPress(input) then
			fire()
		end
	end)
	button.Activated:Connect(fire)
end
Kit.onTap = onTap

export type Tabs = { frame: Frame, buttons: { [string]: TextButton } }

--[[
	A row of tabs across the top of a window (Township splits big windows into 2-6 tabs and
	never goes deeper). The picked tab is blue, the rest cream. Tapping another tab calls
	onSelect(name); the caller keeps which one is picked and rebuilds. `badges` puts a red
	count on a tab ("" hides it). Tabs are 44 px tall, the touch minimum.
]]
function Kit.tabs(
	names: { string },
	selected: string,
	onSelect: (name: string) -> (),
	props: { [string]: any }?,
	badges: { [string]: string }?
): Tabs
	local gap = 6
	local frame = make("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, gap),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	applyProps(frame, props)
	local count = math.max(#names, 1)
	local buttons = {}
	for i, name in names do
		local picked = name == selected
		local button = Kit.button(name, if picked then "secondary" else "neutral", {
			Name = name,
			LayoutOrder = i,
			Size = UDim2.new(1 / count, -gap * (count - 1) / count, 0, 44),
			TextSize = Type.size.body,
			TextScaled = true,
			TextColor3 = if picked then Palette.textOnColor else Palette.text,
			Parent = frame,
		})
		make("UITextSizeConstraint", { MaxTextSize = Type.size.body, MinTextSize = Type.size.small - 2 }).Parent =
			button
		make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }).Parent = button
		if badges and badges[name] then
			Kit.badge(button, badges[name])
		end
		if not picked then
			onTap(button, function()
				onSelect(name)
			end)
		end
		buttons[name] = button
	end
	return { frame = frame, buttons = buttons }
end

export type Stepper = {
	frame: Frame,
	label: TextLabel,
	minus: TextButton,
	plus: TextButton,
	get: () -> number,
	set: (value: number) -> (),
}

-- − value + for picking a quantity. Calls onChange(value) after each step; the ends grey out.
function Kit.stepper(
	value: number,
	min: number,
	max: number,
	onChange: (value: number) -> (),
	props: { [string]: any }?
): Stepper
	local frame = make("Frame", {
		Name = "Stepper",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(150, 44),
	})
	applyProps(frame, props)
	local minus = Kit.button("−", "secondary", {
		Name = "Minus",
		Size = UDim2.new(0, 44, 1, 0),
		TextSize = 24,
		Parent = frame,
	})
	local plus = Kit.button("+", "secondary", {
		Name = "Plus",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 44, 1, 0),
		TextSize = 24,
		Parent = frame,
	})
	local label = make("TextLabel", {
		Name = "Value",
		BackgroundColor3 = Palette.card,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 48, 0, 2),
		Size = UDim2.new(1, -96, 1, -8),
		Font = Type.display,
		TextSize = Type.size.heading,
		TextColor3 = Palette.text,
		Parent = frame,
	}, { Kit.corner(10), Kit.stroke(Palette.edge, 1.5, 0.3, true) })
	local current = math.clamp(value, min, math.max(min, max))
	local function show()
		label.Text = tostring(current)
		minus.Active = current > min
		plus.Active = current < max
		minus.BackgroundColor3 = if minus.Active then Palette.button.secondary.face else Palette.button.disabled.face
		plus.BackgroundColor3 = if plus.Active then Palette.button.secondary.face else Palette.button.disabled.face
	end
	local function set(v: number)
		local clamped = math.clamp(math.floor(v + 0.5), min, math.max(min, max))
		if clamped ~= current then
			current = clamped
			show()
			onChange(current)
		end
	end
	onTap(minus, function()
		set(current - 1)
	end)
	onTap(plus, function()
		set(current + 1)
	end)
	show()
	return {
		frame = frame,
		label = label,
		minus = minus,
		plus = plus,
		get = function()
			return current
		end,
		set = set,
	}
end

export type NeedChip = { frame: Frame, iconSlot: Frame, label: TextLabel, met: boolean }

--[[
	An item requirement: an icon slot (put the item's icon in `iconSlot`) and "have/need".
	Red when short, green with a tick on the icon once covered. `have` above `need` shows as
	need/need, so a full Barn doesn't read as a strange 57/3. Numbers use the HUD size (18).
]]
function Kit.needChip(have: number, need: number, props: { [string]: any }?): NeedChip
	local met = have >= need
	local frame = make("Frame", {
		Name = "NeedChip",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(84, 36),
	})
	applyProps(frame, props)
	local iconSlot = make("Frame", {
		Name = "IconSlot",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = frame,
	}, { make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local label = make("TextLabel", {
		Name = "Count",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -38, 1, 0),
		Font = Type.display,
		TextSize = Type.size.hud,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if met then Palette.button.primary.lip else Palette.button.danger.lip,
		Text = string.format("%d/%d", math.min(have, need), need),
		Parent = frame,
	}, { make("UITextSizeConstraint", { MaxTextSize = Type.size.hud, MinTextSize = Type.size.small }) })
	if met then
		local tick = make("TextLabel", {
			Name = "Tick",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.ready,
			Position = UDim2.fromOffset(30, 28),
			Size = UDim2.fromOffset(16, 16),
			Font = Type.display,
			TextSize = 12,
			TextColor3 = Palette.textOnColor,
			Text = "✓",
			ZIndex = 6,
			Parent = frame,
		}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Color3.new(1, 1, 1), 1.5, 0, true) })
		tick.Visible = true
	end
	return { frame = frame, iconSlot = iconSlot, label = label, met = met }
end

export type PortraitLook = {
	skin: Color3,
	hat: Color3,
	style: string, -- "sunhat" | "cap" | "scarf" | "hardhat" | "hair"
	backdrop: Color3?,
}
export type Portrait = { frame: Frame, face: Frame, plate: TextLabel? }

-- A peg-folk face in a round frame (Design/16 Model Catalog 2.15: big round head, dot eyes,
-- rosy cheeks), with a hat by style. `name` adds a plate under it. Drawn from frames; the
-- art pass can drop a rendered headshot into `face` instead.
function Kit.portrait(look: PortraitLook, size: number, name: string?, props: { [string]: any }?): Portrait
	local frame = make("Frame", {
		Name = "Portrait",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size + (if name then 14 else 0)),
	})
	applyProps(frame, props)
	local ring = make("Frame", {
		Name = "Ring",
		BackgroundColor3 = look.backdrop or Palette.hex("#BFE6F7"),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(size, size),
		Parent = frame,
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Palette.cocoa, 2.5, 0.1, true) })
	local function blob(color: Color3, x: number, y: number, w: number, h: number, round: boolean?, z: number?): Frame
		return make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			ZIndex = z or 1,
			Parent = ring,
		}, { Kit.corner(if round == false then UDim.new(0.25, 0) else UDim.new(1, 0)) })
	end
	-- Shoulders, head, face
	blob(Palette.shade(look.hat, 0.85), 0.5, 1.02, 0.9, 0.42, true, 1)
	local face = blob(look.skin, 0.5, 0.6, 0.62, 0.58, true, 2)
	face.Name = "Face"
	blob(Palette.cocoa, 0.4, 0.6, 0.07, 0.08, true, 3)
	blob(Palette.cocoa, 0.6, 0.6, 0.07, 0.08, true, 3)
	local cheek = Palette.hex("#F28B82")
	blob(cheek, 0.33, 0.7, 0.11, 0.07, true, 3).BackgroundTransparency = 0.25
	blob(cheek, 0.67, 0.7, 0.11, 0.07, true, 3).BackgroundTransparency = 0.25
	blob(Palette.shade(look.skin, 0.55), 0.5, 0.76, 0.14, 0.04, true, 3)
	-- Hat (or hair) over the top of the head
	local hat = look.hat
	local style = look.style
	if style == "sunhat" then
		blob(hat, 0.5, 0.35, 0.98, 0.14, true, 4)
		blob(hat, 0.5, 0.27, 0.5, 0.22, true, 4)
		blob(Palette.shade(hat, 0.7), 0.5, 0.33, 0.5, 0.05, false, 5)
	elseif style == "cap" then
		blob(hat, 0.5, 0.33, 0.6, 0.26, true, 4)
		blob(Palette.shade(hat, 0.8), 0.68, 0.42, 0.42, 0.07, true, 4)
	elseif style == "scarf" then
		blob(hat, 0.5, 0.38, 0.68, 0.34, true, 4)
		blob(hat, 0.78, 0.5, 0.14, 0.12, true, 4)
		blob(Palette.shade(hat, 0.75), 0.5, 0.45, 0.62, 0.04, false, 5)
	elseif style == "hardhat" then
		blob(hat, 0.5, 0.33, 0.6, 0.28, true, 4)
		blob(Palette.shade(hat, 0.85), 0.5, 0.43, 0.78, 0.06, false, 4)
		blob(Palette.grass, 0.5, 0.3, 0.1, 0.1, true, 5)
	else
		blob(hat, 0.5, 0.36, 0.64, 0.3, true, 4)
		blob(hat, 0.24, 0.52, 0.12, 0.22, true, 1)
		blob(hat, 0.76, 0.52, 0.12, 0.22, true, 1)
	end
	local plate: TextLabel? = nil
	if name then
		local created = make("TextLabel", {
			Name = "NamePlate",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Palette.ribbon,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 8, 0, 20),
			Font = Type.display,
			TextScaled = true,
			TextColor3 = Palette.textOnColor,
			Text = name,
			ZIndex = 6,
			Parent = frame,
		}, {
			Kit.corner(UDim.new(1, 0)),
			Kit.stroke(Palette.ribbonLip, 1.5, 0, true),
			make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }),
			make("UITextSizeConstraint", { MaxTextSize = Type.size.small, MinTextSize = 9 }),
		})
		Kit.textOutline(created, Palette.ribbonLip)
		plate = created
	end
	return { frame = frame, face = face, plate = plate }
end

export type IconBubble = { frame: Frame, iconSlot: Frame, count: TextLabel }

--[[
	A ready bubble for the world (Township's convention C4): a round white-rimmed bubble with
	the product's picture and a count. Put the icon in `iconSlot`; Kit.setIconBubble sets the
	count ("" leaves just the picture, centred). Fills its parent, usually a BillboardGui.
]]
function Kit.iconBubble(props: { [string]: any }?): IconBubble
	local frame = make("Frame", {
		Name = "IconBubble",
		BackgroundColor3 = Palette.ready,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, { Kit.corner(UDim.new(1, 0)), Kit.stroke(Color3.new(1, 1, 1), 2.5, 0, true), Kit.gloss(0.85) })
	applyProps(frame, props)
	local iconSlot = make("Frame", {
		Name = "IconSlot",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.new(1, -8, 1, -6),
		Parent = frame,
	}, { make("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	local count = make("TextLabel", {
		Name = "Count",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.new(0.5, -4, 0.8, 0),
		Font = Type.display,
		TextScaled = true,
		TextColor3 = Palette.textOnColor,
		Text = "",
		Parent = frame,
	})
	Kit.textOutline(count, Palette.cocoa)
	return { frame = frame, iconSlot = iconSlot, count = count }
end

function Kit.setIconBubble(bubble: IconBubble, countText: string)
	bubble.count.Text = countText
	bubble.count.Visible = countText ~= ""
	if countText == "" then
		bubble.iconSlot.AnchorPoint = Vector2.new(0.5, 0.5)
		bubble.iconSlot.Position = UDim2.fromScale(0.5, 0.5)
	else
		bubble.iconSlot.AnchorPoint = Vector2.new(0, 0.5)
		bubble.iconSlot.Position = UDim2.new(0, 4, 0.5, 0)
	end
end

export type EdgeIcon = { button: TextButton, timer: TextLabel }

-- A round icon for the screen edge (convention C10): a glyph, a small countdown under it
-- (Kit.setEdgeTimer) and a red dot (Kit.badge on `button`). For timed offers, events and passes.
function Kit.edgeIcon(glyph: string, props: { [string]: any }?): EdgeIcon
	local button = Kit.button(glyph, "neutral", {
		Name = "EdgeIcon",
		Size = UDim2.fromOffset(54, 54),
		TextSize = 26,
		TextColor3 = Palette.text,
	})
	for _, part in { button, button:FindFirstChild("ButtonLip"), button:FindFirstChild("ButtonFace") } do
		local c = childOfClass(part :: Instance, "UICorner") :: UICorner?
		if c then
			c.CornerRadius = UDim.new(1, 0)
		end
	end
	local timer = make("TextLabel", {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.timer,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(52, 18),
		Font = Type.display,
		TextSize = 12,
		TextColor3 = Palette.textOnColor,
		Text = "",
		ZIndex = 6,
		Parent = button,
	}, { Kit.corner(UDim.new(1, 0)) })
	timer.Visible = false
	applyProps(button, props)
	return { button = button, timer = timer }
end

-- Sets an edge icon's countdown; "" hides it.
function Kit.setEdgeTimer(edge: EdgeIcon, text: string)
	edge.timer.Text = text
	edge.timer.Visible = text ~= ""
end

-- 12400 -> "12.4K"
Kit.short = Format.short

return Kit
