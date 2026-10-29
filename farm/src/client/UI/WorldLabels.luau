--!strict
-- In-world status for your own plot: a timer or a "ready" bubble over each bed, the Bakery's
-- current job or finished goods, and the order cards on the Order Board's face.
-- Countdowns run locally from the server timestamps (Design/11 UI & UX ready bubbles).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Crops = require(Shared.Config.Crops)
local Items = require(Shared.Items)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Ui = require(script.Parent.Ui)

local WorldLabels = {}

local plot: Model? = nil
local bedLabels: { [string]: TextLabel } = {}
local bakeryLabel: TextLabel? = nil
local boardText: TextLabel? = nil

local function billboard(adornee: BasePart, offsetY: number): TextLabel
	local gui = Ui.new("BillboardGui", {
		Name = "FarmStatus",
		Adornee = adornee,
		Size = UDim2.fromOffset(120, 34),
		StudsOffset = Vector3.new(0, offsetY, 0),
		MaxDistance = 90,
		AlwaysOnTop = true,
		Parent = adornee,
	})
	local label = Ui.label("", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.colors.bar,
		BackgroundTransparency = 0.35,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Parent = gui,
	})
	Ui.corner(10).Parent = label
	Ui.padding(3).Parent = label
	return label
end

local function attach(model: Model)
	plot = model
	table.clear(bedLabels)
	local fields = model:WaitForChild("Fields")
	for _, bed in fields:GetChildren() do
		local id = bed:GetAttribute("FieldId")
		if bed:IsA("BasePart") and type(id) == "string" then
			bedLabels[id] = billboard(bed, 4)
		end
	end
	local bakery = model:WaitForChild("Bakery")
	bakeryLabel = billboard(bakery:WaitForChild("Body") :: BasePart, 11)

	local board = model:WaitForChild("OrderBoard") :: BasePart
	local surface = Ui.new("SurfaceGui", {
		Name = "FarmOrders",
		Adornee = board,
		Face = Enum.NormalId.Left,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		Parent = board,
	})
	boardText = Ui.label("", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.colors.panel,
		BackgroundTransparency = 0,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = surface,
	})
	Ui.padding(12).Parent = boardText
end

local function render()
	local state = ClientStore.state
	if plot == nil or state == nil then
		return
	end
	local now = ClientStore.now()

	for id, label in bedLabels do
		local field = state.fields[id]
		local gui = label.Parent :: BillboardGui
		if field == nil or field.crop == nil then
			gui.Enabled = false
		elseif Timer.isReady(field.readyAt, now) then
			gui.Enabled = true
			label.Text = Crops[field.crop].displayName .. " ready!"
			label.BackgroundColor3 = Color3.fromRGB(90, 160, 60)
		else
			gui.Enabled = true
			label.Text = Timer.format(Timer.remaining(field.readyAt, now))
			label.BackgroundColor3 = Ui.colors.bar
		end
	end

	local preview = ClientStore.factoryPreview("Bakery")
	if bakeryLabel and preview then
		local gui = bakeryLabel.Parent :: BillboardGui
		gui.Enabled = true
		if not preview.built then
			bakeryLabel.Text = "Build me"
		elseif preview.underConstruction then
			bakeryLabel.Text = "Building " .. Timer.format(Timer.remaining(preview.constructionReadyAt, now))
		elseif preview.outputCount > 0 then
			bakeryLabel.Text = string.format("%d ready!", preview.outputCount)
		elseif #preview.queue > 0 and preview.queue[1].readyAt then
			local job = preview.queue[1]
			bakeryLabel.Text = Items[job.recipe].displayName .. " " .. Timer.format(Timer.remaining(job.readyAt, now))
		else
			bakeryLabel.Text = "Idle"
		end
	end

	if boardText then
		local lines = { "ORDER BOARD" }
		for _, slot in state.board do
			if slot.order then
				local parts = {}
				for item, qty in slot.order.wants do
					table.insert(parts, string.format("%d %s", qty, Items[item].displayName))
				end
				table.sort(parts)
				table.insert(lines, table.concat(parts, ", "))
			else
				table.insert(lines, "(truck on the way)")
			end
		end
		boardText.Text = table.concat(lines, "\n")
	end
end

function WorldLabels.setPlot(model: Model)
	attach(model)
	render()
end

function WorldLabels.init()
	ClientStore.changed.Event:Connect(render)
	task.spawn(function()
		while true do
			task.wait(0.5)
			render()
		end
	end)
end

return WorldLabels
