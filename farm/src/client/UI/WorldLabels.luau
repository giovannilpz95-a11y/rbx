--!strict
-- In-world status for your own plot: a timer or a "ready" bubble over each bed, each factory's
-- current job or finished goods, each pen's products or hunger, Town construction timers, and
-- the order cards on the Order Board's face.
-- Countdowns run locally from the server timestamps (Design/11 UI & UX ready bubbles).
-- Ready bubbles show the product's picture and a count, Township style (UI Reference & Gaps
-- G2); text is only for timers and states like "Hungry".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Animals = require(Shared.Config.Animals)
local Balance = require(Shared.Config.Balance)
local Factories = require(Shared.Config.Factories)
local ArtIcons = require(Shared.Art.Icons)
local Items = require(Shared.Items)
local Pen = require(Shared.Pen)
local Timer = require(Shared.Timer)
local TownRules = require(Shared.TownRules)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Ui = require(script.Parent.Ui)

local WorldLabels = {}

local plot: Model? = nil
local bedLabels: { [string]: TextLabel } = {}
local factoryLabels: { [string]: TextLabel } = {}
local penLabels: { [string]: TextLabel } = {}
local boardText: TextLabel? = nil

local TEXT_SIZE = UDim2.fromOffset(120, 34)
local ICON_SIZE = UDim2.fromOffset(50, 50) -- picture only
local ICON_COUNT_SIZE = UDim2.fromOffset(84, 50) -- picture and a count

-- Each status billboard holds a text bubble (timers, states) and a picture bubble (ready).
-- `icons` keeps the ViewportFrame per item so a bubble isn't rebuilt every half second.
type PictureBubble = {
	bubble: any, -- UiTheme Kit.iconBubble
	item: string?,
	icons: { [string]: ViewportFrame },
}
local pictures: { [TextLabel]: PictureBubble } = setmetatable({}, { __mode = "k" }) :: any -- town bubbles come and go

local function billboard(adornee: BasePart, offsetY: number, maxDistance: number?): TextLabel
	local gui = Ui.new("BillboardGui", {
		Name = "FarmStatus",
		Adornee = adornee,
		Size = TEXT_SIZE,
		StudsOffset = Vector3.new(0, offsetY, 0),
		MaxDistance = maxDistance or 90,
		AlwaysOnTop = true,
		Parent = adornee,
	})
	local label = Ui.label("", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Parent = gui,
	})
	Ui.padding(4).Parent = label
	Ui.theme.Kit.skinBubble(label)
	local bubble = Ui.theme.Kit.iconBubble({ Visible = false, Parent = gui })
	pictures[label] = { bubble = bubble, item = nil, icons = {} }
	-- Ready bubbles bob gently so they catch the eye (12 Art & Audio Direction)
	local bob: Tween? = nil
	bubble.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		local ready = bubble.frame.Visible
		if ready and bob == nil then
			bob = Ui.theme.Motion.loop(gui, { StudsOffset = Vector3.new(0, offsetY + 0.6, 0) })
		elseif not ready and bob ~= nil then
			bob:Cancel()
			bob = nil
			gui.StudsOffset = Vector3.new(0, offsetY, 0)
		end
	end)
	return label
end

-- Show a timer or state as text on the bubble's dark (or `color`) pill.
local function showText(label: TextLabel, text: string, color: Color3?)
	local picture = pictures[label]
	if picture then
		picture.bubble.frame.Visible = false
	end
	label.Visible = true
	label.Text = text
	label.BackgroundColor3 = color or Ui.colors.bar
	local gui = label.Parent :: BillboardGui
	gui.Size = TEXT_SIZE
end

-- Show that `item` is ready, with its picture and a count ("" for none).
local function showReady(label: TextLabel, item: string, count: number?)
	local picture = pictures[label]
	if picture == nil then
		return
	end
	local Kit = Ui.theme.Kit
	if picture.item ~= item then
		if picture.item and picture.icons[picture.item] then
			picture.icons[picture.item].Parent = nil
		end
		local icon = picture.icons[item]
		if icon == nil then
			local ok, built = pcall(ArtIcons.viewport, item)
			if ok then
				icon = built
				picture.icons[item] = built
			end
		end
		if icon then
			icon.Size = UDim2.fromScale(1, 1)
			icon.Parent = picture.bubble.iconSlot
		end
		picture.item = item
	end
	local countText = if count and count > 1 then "x" .. count else ""
	Kit.setIconBubble(picture.bubble, countText)
	label.Visible = false
	label.Text = "" -- keeps the text-based checks (Guide, tests) from reading a stale timer
	label.BackgroundColor3 = Ui.colors.ready
	picture.bubble.frame.Visible = true
	local gui = label.Parent :: BillboardGui
	gui.Size = if countText == "" then ICON_SIZE else ICON_COUNT_SIZE
end

local function attach(model: Model)
	plot = model
	table.clear(bedLabels) -- beds arrive over time (new fields); render adds their labels
	-- Factory and pen labels are added by render as their buildings turn up: from level 34
	-- they only exist once the player has built and placed them
	table.clear(factoryLabels)
	table.clear(penLabels)

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
		Font = Ui.theme.Type.display,
		Parent = surface,
	})
	Ui.padding(12).Parent = boardText
end

-- A label on `part` of building `id`, kept in `labels`; made again if the building was rebuilt
local function labelOn(labels: { [string]: TextLabel }, id: string, partName: string, offsetY: number)
	local label = labels[id]
	local gui = label and label.Parent
	if gui and gui.Parent and gui.Parent:IsDescendantOf(plot :: Model) then
		return
	end
	local building = (plot :: Model):FindFirstChild(id)
	local part = building and building:FindFirstChild(partName)
	if part and part:IsA("BasePart") then
		labels[id] = billboard(part, offsetY, 60)
	else
		labels[id] = nil
	end
end

local function render()
	local state = ClientStore.state
	if plot == nil or state == nil then
		return
	end
	for _, id in Balance.enabledFactories do
		labelOn(factoryLabels, id, "Body", 10.5)
	end
	for _, id in Balance.enabledPens do
		labelOn(penLabels, id, "Floor", 8.5)
	end
	local now = ClientStore.now()

	local fieldsFolder = plot:FindFirstChild("Fields")
	if fieldsFolder then
		for id in state.fields do
			local bed = if bedLabels[id] == nil then fieldsFolder:FindFirstChild("Field_" .. id) else nil
			if bed and bed:IsA("BasePart") then
				bedLabels[id] = billboard(bed, 4)
			end
		end
	end
	for id, label in bedLabels do
		local field = state.fields[id]
		local gui = label.Parent :: BillboardGui
		if field == nil or field.crop == nil then
			gui.Enabled = false
		elseif Timer.isReady(field.readyAt, now) then
			gui.Enabled = true
			showReady(label, field.crop)
		else
			gui.Enabled = true
			showText(label, Timer.format(Timer.remaining(field.readyAt, now)))
		end
	end

	for id, label in factoryLabels do
		local preview = ClientStore.factoryPreview(id)
		local gui = label.Parent :: BillboardGui
		gui.Enabled = preview ~= nil
		if preview == nil then
			continue
		end
		if not preview.built then
			showText(
				label,
				if state.level < Factories[id].unlockLevel then "Level " .. Factories[id].unlockLevel else "Build me"
			)
		elseif preview.underConstruction then
			showText(label, "Building " .. Timer.format(Timer.remaining(preview.constructionReadyAt, now)))
		elseif preview.outputCount > 0 then
			-- The good there's most of on the table
			local best, bestQty = nil, 0
			for item, qty in preview.output do
				if qty > bestQty or (qty == bestQty and best and item < best) then
					best, bestQty = item, qty
				end
			end
			showReady(label, best or "", preview.outputCount)
		elseif #preview.queue > 0 and preview.queue[1].readyAt then
			local job = preview.queue[1]
			showText(label, Items[job.recipe].displayName .. " " .. Timer.format(Timer.remaining(job.readyAt, now)))
		else
			showText(label, "Idle")
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
		if not pen.built then
			showText(label, if state.level < def.unlockLevel then "Level " .. def.unlockLevel else "Build me")
		elseif not Pen.isOperational(pen, now) then
			showText(label, "Building " .. Timer.format(Timer.remaining(pen.constructionReadyAt, now)))
		else
			local counts = Pen.counts(pen, now)
			if counts.ready > 0 then
				showReady(label, def.product, counts.ready)
			elseif counts.hungry > 0 then
				local hasFeed = (pen.feedLeft or 0) > 0 or ClientStore.itemCount(def.feed) > 0
				showText(label, if hasFeed then "Hungry" else "Needs " .. Items[def.feed].displayName, Ui.colors.warn)
			elseif counts.nextReadyAt then
				showText(label, def.productName .. " " .. Timer.format(Timer.remaining(counts.nextReadyAt, now)))
			end
		end
	end

	-- Town buildings under construction: a countdown over each (the server swaps the block
	-- for the finished one, which drops the bubble)
	local town = plot:FindFirstChild("Town")
	if town and state.town then
		local function bubble(name: string, readyAt: number)
			local holder = town:FindFirstChild(name)
			local body = holder and holder:FindFirstChild("Body") :: BasePart?
			if body == nil then
				return
			end
			local gui = body:FindFirstChild("FarmStatus")
			local label = if gui
				then gui:FindFirstChildOfClass("TextLabel")
				else billboard(body, body.Size.Y / 2 + 3, 60)
			if label then
				showText(label, "Building " .. Timer.format(Timer.remaining(readyAt, now)))
			end
		end
		for _, house in state.town.houses do
			if not TownRules.isDone(house, now) then
				bubble("House_" .. house.lot, house.readyAt)
			end
		end
		for id, entry in state.town.community do
			if not TownRules.isDone(entry, now) then
				bubble("Community_" .. id, entry.readyAt)
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
