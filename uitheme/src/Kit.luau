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

-- 12400 -> "12.4K"
Kit.short = Format.short

return Kit
