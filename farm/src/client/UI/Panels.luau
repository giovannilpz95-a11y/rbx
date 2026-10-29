--!strict
-- One panel open at a time: Orders, Barn, Bakery, the seed picker and (Studio only) Debug.
-- Panels re-render on every state change and once a second for countdowns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Balance = require(Shared.Config.Balance)
local Crops = require(Shared.Config.Crops)
local Factories = require(Shared.Config.Factories)
local Items = require(Shared.Items)
local Recipes = require(Shared.Config.Recipes)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Ui = require(script.Parent.Ui)

local Panels = {}

local gui: ScreenGui
local frame: Frame
local titleLabel: TextLabel
local body: ScrollingFrame
local current: string? = nil
local seedFieldId: string? = nil

-- Set by the reach controller: is the avatar close enough to collect from the Bakery tray?
Panels.canCollect = function(_factoryId: string): boolean
	return false
end

local function itemName(id: string): string
	local item = Items[id]
	return if item then item.displayName else id
end

local function wantsText(wants: { [string]: number }): (string, boolean)
	local parts = {}
	local complete = true
	local ids = {}
	for id in wants do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local have = ClientStore.itemCount(id)
		if have < wants[id] then
			complete = false
		end
		table.insert(parts, string.format("%s %d/%d", itemName(id), math.min(have, wants[id]), wants[id]))
	end
	return table.concat(parts, "   "), complete
end

local function row(height: number, order: number): Frame
	return Ui.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.3,
		Size = UDim2.new(1, -4, 0, height),
		LayoutOrder = order,
		Parent = body,
	}, { Ui.corner(6), Ui.padding(6) })
end

---------------------------------------------------------------------------------------------
-- Panel renderers
---------------------------------------------------------------------------------------------

local function renderOrders(state: { [string]: any })
	titleLabel.Text = "Order Board"
	local now = ClientStore.now()
	for i, slot in state.board do
		local card = row(64, i)
		if slot.order then
			local text, complete = wantsText(slot.order.wants)
			Ui.label(text, { Size = UDim2.new(1, -110, 0, 22), TextWrapped = true, Parent = card })
			Ui.label(string.format("+%d Coins   +%d XP", slot.order.rewardCoins, slot.order.rewardXP), {
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, -110, 0, 20),
				TextColor3 = Ui.colors.muted,
				TextSize = 14,
				Parent = card,
			})
			local deliver = Ui.button("Deliver", function()
				Remotes.fire("Order_Fulfill", i)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -36, 0, 0),
				Size = UDim2.fromOffset(70, 30),
				Parent = card,
			})
			Ui.setEnabled(deliver, complete)
			Ui.button("X", function()
				Remotes.fire("Order_Discard", i)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = Ui.colors.danger,
				Parent = card,
			})
		else
			local waitLeft = Timer.remaining(slot.refreshAt or 0, now)
			Ui.label(
				if waitLeft > 0 then "New order in " .. Timer.format(waitLeft) else "A new order is on its way...",
				{ TextColor3 = Ui.colors.muted, Parent = card }
			)
		end
	end
end

local function renderBarn(state: { [string]: any })
	titleLabel.Text = string.format("Barn  %d / %d", state.barnUsed, state.barnCapacity)
	local ids = {}
	for id in state.inventory do
		table.insert(ids, id)
	end
	table.sort(ids)
	if #ids == 0 then
		Ui.label("Empty. Harvest a field to fill it.", { TextColor3 = Ui.colors.muted, Parent = body })
	end
	for i, id in ids do
		local qty = state.inventory[id]
		local item = Items[id]
		local line = row(42, i)
		Ui.label(
			string.format("%s  x%d   (sells for %d each)", itemName(id), qty, if item then item.sellPrice else 0),
			{ Size = UDim2.new(1, -150, 1, 0), Parent = line }
		)
		Ui.button("Sell 1", function()
			Remotes.fire("Barn_Sell", id, 1)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -74, 0, 0),
			Size = UDim2.fromOffset(64, 30),
			Parent = line,
		})
		Ui.button("Sell all", function()
			Remotes.fire("Barn_Sell", id, qty)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(70, 30),
			BackgroundColor3 = Ui.colors.danger,
			Parent = line,
		})
	end
end

local function renderFactory(state: { [string]: any }, factoryId: string)
	local def = Factories[factoryId]
	local preview = ClientStore.factoryPreview(factoryId)
	titleLabel.Text = def.displayName
	if preview == nil then
		return
	end
	local now = ClientStore.now()

	if not preview.built then
		local line = row(80, 1)
		if state.level < def.unlockLevel then
			Ui.label(string.format("Unlocks at level %d.", def.unlockLevel), { Parent = line })
		else
			Ui.label(string.format("Build it for %d Coins (+%d XP).", def.buildCost, def.xp), { Parent = line })
			local build = Ui.button("Build", function()
				Remotes.fire("Factory_Build", factoryId)
			end, { Position = UDim2.fromOffset(0, 30), Parent = line })
			Ui.setEnabled(build, state.currencies.Coins >= def.buildCost)
		end
		return
	end
	if preview.underConstruction then
		Ui.label(
			"Building... " .. Timer.format(Timer.remaining(preview.constructionReadyAt, now)) .. " left",
			{ Parent = row(40, 1) }
		)
		return
	end

	-- Recipes (paperwork: queue from anywhere)
	local order = 1
	local recipeIds = {}
	for id, recipe in Recipes do
		if recipe.factory == factoryId then
			table.insert(recipeIds, id)
		end
	end
	table.sort(recipeIds)
	for _, id in recipeIds do
		local recipe = Recipes[id]
		local line = row(46, order)
		order += 1
		local inputs = {}
		local enough = true
		for input, qty in recipe.inputs do
			table.insert(inputs, string.format("%d %s", qty, itemName(input)))
			if ClientStore.itemCount(input) < qty then
				enough = false
			end
		end
		local locked = state.level < recipe.unlockLevel
		local text = string.format(
			"%s  <-  %s   (%s)",
			recipe.displayName,
			table.concat(inputs, ", "),
			Timer.format(recipe.seconds * (state.timeScale or 1))
		)
		if locked then
			text ..= string.format("   Lv %d", recipe.unlockLevel)
		end
		Ui.label(text, { Size = UDim2.new(1, -80, 1, 0), TextWrapped = true, TextSize = 15, Parent = line })
		local make = Ui.button("Make", function()
			Remotes.fire("Factory_Queue", factoryId, id)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(70, 30),
			Parent = line,
		})
		Ui.setEnabled(make, enough and not locked and #preview.queue < preview.slots)
	end

	-- Queue
	Ui.label(
		string.format("Queue  %d / %d", #preview.queue, preview.slots),
		{ Font = Enum.Font.GothamBold, LayoutOrder = order, Parent = body }
	)
	order += 1
	for i, job in preview.queue do
		local status = if job.readyAt then Timer.format(Timer.remaining(job.readyAt, now)) .. " left" else "waiting"
		Ui.label(
			string.format("%d. %s  %s", i, itemName(job.recipe), status),
			{ LayoutOrder = order, TextColor3 = Ui.colors.muted, Parent = body }
		)
		order += 1
	end

	-- Output tray (hands-on: walk past the table, or tap Collect when in reach)
	local tray = row(46, order)
	Ui.label(
		string.format("Ready on the table: %d / %d", preview.outputCount, def.trayCapacity),
		{ Size = UDim2.new(1, -100, 1, 0), Parent = tray }
	)
	local collect = Ui.button("Collect", function()
		Remotes.fire("Factory_Collect", factoryId)
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(84, 30),
		Parent = tray,
	})
	local near = Panels.canCollect(factoryId)
	Ui.setEnabled(collect, preview.outputCount > 0 and near)
	if preview.outputCount > 0 and not near then
		Ui.label(
			"Walk to the output table to collect.",
			{ LayoutOrder = order + 1, TextColor3 = Ui.colors.muted, TextSize = 14, Parent = body }
		)
	end
end

local function renderSeeds(state: { [string]: any })
	titleLabel.Text = "Plant a crop"
	for i, id in Balance.enabledCrops do
		local crop = Crops[id]
		local locked = state.level < crop.unlockLevel
		local cost = if crop.seedCost == 0
			then "free"
			else string.format("%d Coin%s", crop.seedCost, if crop.seedCost == 1 then "" else "s")
		local text = string.format(
			"%s   %s   %s",
			crop.displayName,
			cost,
			Timer.format(crop.growSeconds * (state.timeScale or 1))
		)
		if locked then
			text ..= string.format("   (level %d)", crop.unlockLevel)
		end
		local button = Ui.button(text, function()
			if seedFieldId then
				Remotes.fire("Farm_Plant", seedFieldId, id)
			end
			Panels.close()
		end, {
			Size = UDim2.new(1, -4, 0, 40),
			LayoutOrder = if id == state.settings.lastSeed then 0 else i,
			Parent = body,
		})
		Ui.setEnabled(button, not locked and state.currencies.Coins >= crop.seedCost)
	end
	Ui.label("Tip: hold the action button (E) and walk over empty beds to sow the same crop.", {
		TextColor3 = Ui.colors.muted,
		TextSize = 13,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 99,
		Parent = body,
	})
end

local function choiceRow(
	labelText: string,
	options: { any },
	isCurrent: (any) -> boolean,
	choose: (any) -> (),
	order: number
)
	local line = row(42, order)
	Ui.label(labelText, { Size = UDim2.new(0, 110, 1, 0), Parent = line })
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(110, 0),
		Size = UDim2.new(1, -110, 1, 0),
		Parent = line,
	}, { Ui.list(4, true) })
	for i, option in options do
		local button = Ui.button(tostring(option), function()
			choose(option)
		end, { Size = UDim2.fromOffset(52, 28), LayoutOrder = i, Parent = holder })
		if isCurrent(option) then
			button.BackgroundColor3 = Color3.fromRGB(70, 120, 200)
		end
	end
end

local function renderDebug(state: { [string]: any })
	titleLabel.Text = "Greybox tuning (Studio)"
	local settings = ClientStore.settings
	choiceRow("Reach", Balance.reachOptions, function(v)
		return settings.reach == v
	end, function(v)
		ClientStore.setSetting("reach", v)
	end, 1)
	choiceRow("Walk speed", Balance.walkSpeedOptions, function(v)
		return settings.walkSpeed == v
	end, function(v)
		ClientStore.setSetting("walkSpeed", v)
	end, 2)
	choiceRow("Timer length", Balance.timeScaleOptions, function(v)
		return (state.timeScale or 1) == v
	end, function(v)
		Remotes.fire("Debug_SetTimeScale", v)
	end, 3)
	Ui.label(
		"Timer length applies to timers started after the change.",
		{ TextColor3 = Ui.colors.muted, TextSize = 13, LayoutOrder = 4, Parent = body }
	)
end

---------------------------------------------------------------------------------------------

local function render()
	local state = ClientStore.state
	if current == nil or state == nil then
		return
	end
	Ui.clear(body)
	if current == "Orders" then
		renderOrders(state)
	elseif current == "Barn" then
		renderBarn(state)
	elseif current == "Bakery" then
		renderFactory(state, "Bakery")
	elseif current == "Seeds" then
		renderSeeds(state)
	elseif current == "Debug" then
		renderDebug(state)
	end
end

function Panels.open(name: string, fieldId: string?)
	if name == "Debug" and not RunService:IsStudio() then
		return
	end
	if current == name and name ~= "Seeds" then
		Panels.close()
		return
	end
	current = name
	seedFieldId = fieldId
	frame.Visible = true
	render()
end

function Panels.close()
	current = nil
	seedFieldId = nil
	frame.Visible = false
end

function Panels.isOpen(): boolean
	return current ~= nil
end

function Panels.init()
	gui = Ui.new("ScreenGui", {
		Name = "FarmPanels",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	frame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.9, 0.62),
		BackgroundColor3 = Ui.colors.panel,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.new("UIStroke", { Color = Ui.colors.panelEdge, Thickness = 3 }),
		Ui.new("UISizeConstraint", { MaxSize = Vector2.new(480, 420) }),
	})
	titleLabel = Ui.label("", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		Parent = frame,
	})
	Ui.button("X", Panels.close, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Ui.colors.danger,
		Parent = frame,
	})
	body = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.new(1, -20, 1, -56),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = frame,
	}, { Ui.list(6) })

	ClientStore.changed.Event:Connect(render)
	ClientStore.settingsChanged.Event:Connect(render)
	task.spawn(function()
		while true do
			task.wait(1)
			if current ~= nil and current ~= "Seeds" and current ~= "Debug" then
				render()
			end
		end
	end)
end

return Panels
