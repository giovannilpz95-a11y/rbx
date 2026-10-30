--!strict
-- The first-session guide on screen (shared/Tutorial): a card at the bottom with the
-- townsfolk guide's one line, and a bouncing pointer over the thing to walk to.
-- Greybox: the guides are names on a card until their models exist.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Tutorial = require(Shared.Tutorial)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local Guide = {}

local player = Players.LocalPlayer
local plot: Model? = nil
local card: Frame
local nameLabel: TextLabel
local textLabel: TextLabel
local skipButton: TextButton
local nextButton: TextButton
local pointer: BillboardGui
local target: string? = nil
local active = false -- a guide step is showing (the card hides while a panel is open)

local function bedsWhere(test: (bed: BasePart) -> boolean): { BasePart }
	local out = {}
	local fields = plot and plot:FindFirstChild("Fields")
	if fields == nil then
		return out
	end
	for _, bed in fields:GetChildren() do
		if bed:IsA("BasePart") and test(bed) then
			table.insert(out, bed)
		end
	end
	return out
end

local function nearest(parts: { BasePart }): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best, bestDistance = nil, math.huge
	for _, p in parts do
		local distance = if root then (p.Position - root.Position).Magnitude else 0
		if distance < bestDistance then
			best, bestDistance = p, distance
		end
	end
	return best
end

local function findInteract(kind: string, idAttribute: string?, id: string?): BasePart?
	if plot == nil then
		return nil
	end
	for _, d in plot:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Interact") == kind then
			if idAttribute == nil or d:GetAttribute(idAttribute) == id then
				return d
			end
		end
	end
	return nil
end

local function resolve(name: string?): BasePart?
	if name == nil then
		return nil
	end
	local now = ClientStore.now()
	if name == "ReadyField" then
		return nearest(bedsWhere(function(bed)
			local readyAt = bed:GetAttribute("ReadyAt")
			return bed:GetAttribute("Crop") ~= nil and typeof(readyAt) == "number" and readyAt <= now
		end))
	elseif name == "EmptyField" then
		return nearest(bedsWhere(function(bed)
			return bed:GetAttribute("Crop") == nil
		end))
	elseif name == "OrderBoard" then
		return findInteract("OrderBoard")
	end
	local kind, id = string.match(name, "^(%a+):(%w+)$")
	if kind == "Factory" then
		return findInteract("Factory", "FactoryId", id)
	elseif kind == "Pen" then
		return findInteract("Pen", "PenId", id)
	end
	return nil
end

local function render(state: { [string]: any }?)
	local step = state and Tutorial.current(state)
	active = step ~= nil
	card.Visible = active and not Panels.isOpen()
	target = step and step.target
	if step == nil or state == nil then
		pointer.Adornee = nil
		return
	end
	nameLabel.Text = step.guide
	textLabel.Text = step.text
	nextButton.Visible = step.done == nil
	skipButton.Visible = step.done ~= nil and state.tutorial.step >= Tutorial.skippableFrom
end

function Guide.setPlot(model: Model)
	plot = model
end

function Guide.init()
	local gui = Ui.new("ScreenGui", {
		Name = "FarmGuide",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	card = Ui.new("Frame", {
		-- Above the HUD's bottom button row (64 high, 14 up) so it never covers Orders
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.new(0.6, 0, 0, 74),
		BackgroundColor3 = Ui.colors.panel,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(10),
		Ui.padding(8),
		Ui.new("UIStroke", { Color = Ui.colors.panelEdge, Thickness = 2 }),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(520, 74) }),
	})
	nameLabel = Ui.label("", {
		Size = UDim2.new(1, -90, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Ui.colors.panelEdge,
		Parent = card,
	})
	textLabel = Ui.label("", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -90, 1, -20),
		TextWrapped = true,
		TextSize = 15,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local buttonProps = {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(80, 34),
		Parent = card,
	}
	nextButton = Ui.button("Got it", function()
		Remotes.fire("Tutorial_Next")
	end, table.clone(buttonProps))
	local skipProps = table.clone(buttonProps)
	skipProps.BackgroundColor3 = Ui.colors.selected
	skipButton = Ui.button("Skip", function()
		Remotes.fire("Tutorial_Skip")
	end, skipProps)

	pointer = Ui.new("BillboardGui", {
		Name = "GuidePointer",
		Size = UDim2.fromOffset(48, 48),
		StudsOffset = Vector3.new(0, 7, 0),
		AlwaysOnTop = true,
		Parent = gui,
	})
	Ui.label("▼", {
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextColor3 = Ui.colors.coins,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = pointer,
	})

	ClientStore.changed.Event:Connect(render)
	render(ClientStore.state)

	-- Re-aim at the nearest matching thing twice a second; bounce every frame
	task.spawn(function()
		while true do
			pointer.Adornee = if card.Visible then resolve(target) else nil
			task.wait(0.5)
		end
	end)
	RunService.RenderStepped:Connect(function()
		-- Out of the way while a panel is open: on a phone it sat across the panel's rows
		card.Visible = active and not Panels.isOpen()
		pointer.StudsOffset = Vector3.new(0, 7 + math.abs(math.sin(time() * 4)) * 1.5, 0)
	end)
end

return Guide
