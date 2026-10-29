--!strict
-- Tiny helpers for building greybox UI in code.

local Ui = {}

Ui.colors = {
	panel = Color3.fromRGB(250, 244, 228),
	panelEdge = Color3.fromRGB(150, 110, 70),
	text = Color3.fromRGB(60, 45, 30),
	muted = Color3.fromRGB(130, 115, 95),
	button = Color3.fromRGB(110, 170, 80),
	buttonText = Color3.new(1, 1, 1),
	disabled = Color3.fromRGB(180, 175, 165),
	danger = Color3.fromRGB(200, 90, 70),
	bar = Color3.fromRGB(40, 40, 40),
	coins = Color3.fromRGB(240, 190, 40),
	gems = Color3.fromRGB(80, 200, 220),
	xp = Color3.fromRGB(120, 200, 90),
}

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: number?): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
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

function Ui.label(text: string, props: { [string]: any }?): TextLabel
	local label = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Ui.colors.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
		Text = text,
	})
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

function Ui.button(text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local button = Ui.new("TextButton", {
		BackgroundColor3 = Ui.colors.button,
		Font = Enum.Font.GothamBold,
		TextColor3 = Ui.colors.buttonText,
		TextSize = 15,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(90, 30),
		Text = text,
	}, { Ui.corner(6) })
	if props then
		for key, value in props do
			(button :: any)[key] = value
		end
	end
	button.Activated:Connect(function()
		if button.Active then
			onClick()
		end
	end)
	return button
end

function Ui.setEnabled(button: TextButton, enabled: boolean, color: Color3?)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then (color or Ui.colors.button) else Ui.colors.disabled
end

function Ui.clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end
end

return Ui
