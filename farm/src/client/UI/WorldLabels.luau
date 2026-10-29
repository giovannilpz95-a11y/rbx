--!strict
-- In-world status for your own plot: a timer or a "ready" bubble over each bed, each factory's
-- current job or finished goods, each pen's products or hunger, and the order cards on the
-- Order Board's face.
-- Countdowns run locally from the server timestamps (Design/11 UI & UX ready bubbles).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Animals = require(Shared.Config.Animals)
local Balance = require(Shared.Config.Balance)
local Crops = require(Shared.Config.Crops)
local Factories = require(Shared.Config.Factories)
local Items = require(Shared.Items)
local Pen = require(Shared.Pen)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Ui = require(script.Parent.Ui)

local WorldLabels = {}

local plot: Model? = nil
local bedLabels: { [string]: TextLabel } = {}
local factoryLabels: { [string]: TextLabel } = {}
local penLabels: { [string]: TextLabel } = {}
local boardText: TextLabel? = nil

local function billboard(adornee: BasePart, offsetY: number, maxDistance: number?): TextLabel
	local gui = Ui.new("BillboardGui", {
		Name = "FarmStatus",
		Adornee = adornee,
		Size = UDim2.fromOffset(120, 34),
		StudsOffset = Vector3.new(0, offsetY, 0),
		MaxDistance = maxDistance or 90,
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
	table.clear(factoryLabels)
	for _, id in Balance.enabledFactories do
		local building = model:WaitForChild(id)
		factoryLabels[id] = billboard(building:WaitForChild("Body") :: BasePart, 10.5, 60)
	end
	table.clear(penLabels)
	for _, id in Balance.enabledPens do
		local pen = model:WaitForChild(id)
		penLabels[id] = billboard(pen:WaitForChild("Floor") :: BasePart, 8.5, 60)
	end

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

	for id, label in factoryLabels do
		local preview = ClientStore.factoryPreview(id)
		local gui = label.Parent :: BillboardGui
		gui.Enabled = preview ~= nil
		if preview == nil then
			continue
		end
		label.BackgroundColor3 = Ui.colors.bar
		if not preview.built then
			label.Text = if state.level < Factories[id].unlockLevel
				then "Level " .. Factories[id].unlockLevel
				else "Build me"
		elseif preview.underConstruction then
			label.Text = "Building " .. Timer.format(Timer.remaining(preview.constructionReadyAt, now))
		elseif preview.outputCount > 0 then
			label.Text = string.format("%d ready!", preview.outputCount)
			label.BackgroundColor3 = Color3.fromRGB(90, 160, 60)
		elseif #preview.queue > 0 and preview.queue[1].readyAt then
			local job = preview.queue[1]
			label.Text = Items[job.recipe].displayName .. " " .. Timer.format(Timer.remaining(job.readyAt, now))
		else
			label.Text = "Idle"
		end
	end

	for id, label in penLabels do
		local def = Animals.pens[id]
		local pen = state.pens[id]
		local gui = label.Parent :: BillboardGui
		gui.Enabled = pen ~= nil
		if pen == nil then
			continue
		end
		label.BackgroundColor3 = Ui.colors.bar
		if not pen.built then
			label.Text = if state.level < def.unlockLevel then "Level " .. def.unlockLevel else "Build me"
		elseif not Pen.isOperational(pen, now) then
			label.Text = "Building " .. Timer.format(Timer.remaining(pen.constructionReadyAt, now))
		else
			local counts = Pen.counts(pen, now)
			if counts.ready > 0 then
				label.Text = string.format("%d %s ready!", counts.ready, def.productName)
				label.BackgroundColor3 = Color3.fromRGB(90, 160, 60)
			elseif counts.hungry > 0 then
				local hasFeed = (pen.feedLeft or 0) > 0 or ClientStore.itemCount(def.feed) > 0
				label.Text = if hasFeed then "Hungry" else "Needs " .. Items[def.feed].displayName
				label.BackgroundColor3 = Color3.fromRGB(200, 120, 50)
			elseif counts.nextReadyAt then
				label.Text = def.productName .. " " .. Timer.format(Timer.remaining(counts.nextReadyAt, now))
			end
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
