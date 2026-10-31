--[[
	Crop Pop level editor (Studio only, in Play mode).

		LevelEditor.open()        -- from the Trail's "Dev: Editor" button or the F6 key

	Paint the board, pick tile colours, goals and moves, then:
	  Test play   plays it offline (no hearts, no rewards)
	  Bot check   plays it 50 times with the test bot and shows the win rate
	  Export      writes it as Luau for a Levels set file (in the box and in Output)

	A Studio plugin can reuse the same pieces later; this keeps level editing
	inside the current Play-mode workflow.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CropPop = require(ReplicatedStorage:WaitForChild("CropPop"))
local PuzzleScreen = require(script.Parent.PuzzleScreen)
local TileStyle = require(script.Parent.TileStyle)

local Levels, LevelText, Bot, Tiles = CropPop.Levels, CropPop.LevelText, CropPop.Bot, CropPop.Tiles
local Colors = TileStyle.Board

local LevelEditor = {}

local ROW_HEIGHT = 36
local BOT_GAMES = 50
local DIFFICULTIES = { "Normal", "Tough", "Super Tough" }
-- First-pass rewards by difficulty until the economy thread sets them.
local REWARDS = { Normal = { coins = 25, xp = 5 }, Tough = { coins = 50, xp = 10 }, ["Super Tough"] = { coins = 75, xp = 15 } }

-- Paint brushes in two rows: layout character and label.
local BRUSH_ROWS = {
	Brushes = {
		{ char = ".", label = "Cell" },
		{ char = "#", label = "Hole" },
		{ char = "m", label = "Mud" },
		{ char = "M", label = "Mud 2" },
		{ char = "1", label = "🌾1" },
		{ char = "2", label = "🌾2" },
		{ char = "3", label = "🌾3" },
	},
	MoreBrushes = {
		{ char = "f", label = "❄️1" },
		{ char = "F", label = "❄️2" },
		{ char = "w", label = "🌿 Weed" },
		{ char = "p", label = "🎃" },
		{ char = "c", label = "🍀" },
		{ char = "s", label = "🧱1" },
		{ char = "S", label = "🧱2" },
		{ char = "d", label = TileStyle.BasketGlyph },
		{ char = "g", label = TileStyle.GoalGlyphs.Goo },
		{ char = "h", label = TileStyle.HenGlyph },
		{ char = "x", label = TileStyle.CrateGlyph },
		{ char = "b", label = TileStyle.GoalGlyphs.Statues },
		{ char = "G", label = TileStyle.SpringGlyph },
		-- Not a layout character: tap an entrance, then its exit; tap either end again to remove it.
		{ char = "o", label = "🌀" },
		-- Not a layout character either: tap a cell, then a neighbour, to add or remove the fence between.
		{ char = "|", label = "🚧" },
	},
}
local PORTAL = "o" -- the portal brush
local FENCE = "|" -- the fence brush
-- Layout characters that aren't board cells (no portal end or fence there).
local NOT_CELL = { ["#"] = true, d = true, h = true, G = true }
local GOAL_KINDS = { "Collect", "Mud", "HayBale", "Frost", "Weeds", "Pumpkins", "Clover", "Stones", "Fences", "Goo", "Statues" }
local GOAL_BUTTONS = {
	Collect = "+ Collect",
	Mud = "+ Mud",
	HayBale = "+ Bales",
	Frost = "+ Frost",
	Weeds = "+ Weeds",
	Pumpkins = "+ 🎃",
	Clover = "+ 🍀",
	Stones = "+ 🧱",
	Fences = "+ 🚧",
	Goo = "+ 🟢",
	Statues = "+ 🗿",
}

local ui = nil
local state = nil -- the level being edited

-- Level state ----------------------------------------------------------------

local function blankLevel()
	local grid = {}
	for y = 1, 8 do
		grid[y] = {}
		for x = 1, 8 do
			grid[y][x] = "."
		end
	end
	return {
		id = #Levels.List + 1,
		name = "New Level",
		difficulty = "Normal",
		moves = 20,
		colors = { "Tomato", "Egg", "Carrot", "Corn", "Milk" },
		grid = grid,
		goals = { { kind = "Collect", tile = "Tomato", count = 15 } },
		portals = {},
		fences = {},
		brush = ".",
		loadId = 1,
	}
end

local function fromLevel(level)
	local grid = {}
	for y, row in level.layout do
		grid[y] = {}
		for x = 1, #row do
			grid[y][x] = string.sub(row, x, x)
		end
	end
	local goals = {}
	for _, goal in level.goals do
		table.insert(goals, table.clone(goal))
	end
	local portals = {}
	for _, portal in level.portals or {} do
		table.insert(portals, { from = table.clone(portal.from), to = table.clone(portal.to) })
	end
	local fences = {}
	for _, f in level.fences or {} do
		table.insert(fences, table.clone(f))
	end
	return {
		id = level.id,
		name = level.name,
		difficulty = level.difficulty,
		moves = level.moves,
		colors = table.clone(level.colors),
		grid = grid,
		goals = goals,
		portals = portals,
		fences = fences,
		brush = ".",
		loadId = level.id,
	}
end

-- The level table the engine, the validator and the exporter use.
local function toLevel()
	local layout = {}
	for y, row in state.grid do
		layout[y] = table.concat(row)
	end
	local colors = {}
	for _, name in Tiles.Names do -- keep the standard tile order
		if table.find(state.colors, name) then
			table.insert(colors, name)
		end
	end
	local goals = {}
	for _, goal in state.goals do
		table.insert(goals, table.clone(goal))
	end
	local portals = nil
	if #state.portals > 0 then
		portals = {}
		for _, portal in state.portals do
			table.insert(portals, { from = table.clone(portal.from), to = table.clone(portal.to) })
		end
	end
	local fences = nil
	if #state.fences > 0 then
		fences = {}
		for _, f in state.fences do
			table.insert(fences, table.clone(f))
		end
	end
	return {
		id = state.id,
		name = state.name,
		difficulty = state.difficulty,
		moves = state.moves,
		colors = colors,
		layout = layout,
		portals = portals,
		fences = fences,
		goals = goals,
		rewards = table.clone(REWARDS[state.difficulty]),
	}
end

local function width(): number
	return #state.grid[1]
end

local function height(): number
	return #state.grid
end

local function resize(dw: number, dh: number)
	local w = math.clamp(width() + dw, 3, Levels.MAX_SIZE)
	local h = math.clamp(height() + dh, 3, Levels.MAX_SIZE)
	local grid = {}
	for y = 1, h do
		grid[y] = {}
		for x = 1, w do
			grid[y][x] = state.grid[y] and state.grid[y][x] or "."
		end
	end
	state.grid = grid
	-- Portals with an end outside the new size go.
	for i = #state.portals, 1, -1 do
		local portal = state.portals[i]
		if math.max(portal.from[1], portal.to[1]) > w or math.max(portal.from[2], portal.to[2]) > h then
			table.remove(state.portals, i)
		end
	end
	state.portalStart = nil
	for i = #state.fences, 1, -1 do
		local f = state.fences[i]
		if f[1] + (if f[3] == "r" then 1 else 0) > w or f[2] + (if f[3] == "d" then 1 else 0) > h then
			table.remove(state.fences, i)
		end
	end
	state.fenceStart = nil
end

-- Small UI helpers ---------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(radius, 0)
	c.Parent = parent
end

local function textItem(className: string, parent: Instance, name: string, text: string, size: UDim2): any
	local item = Instance.new(className)
	item.Name = name
	item.Text = text
	item.Size = size
	item.Font = TileStyle.Font
	item.TextScaled = true
	item.TextColor3 = Colors.text
	item.BackgroundTransparency = 1
	item.Parent = parent
	return item
end

local function button(parent: Instance, name: string, text: string, size: UDim2, onClick: () -> ()): TextButton
	local b = textItem("TextButton", parent, name, text, size)
	b.BackgroundTransparency = 0
	b.BackgroundColor3 = Colors.accent
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	corner(b, 0.25)
	b.Activated:Connect(onClick)
	return b
end

-- A horizontal row in the side panel.
local function row(name: string, order: number, rows: number?): Frame
	local r = Instance.new("Frame")
	r.Name = name
	r.LayoutOrder = order
	r.Size = UDim2.new(1, -8, 0, ROW_HEIGHT * (rows or 1))
	r.BackgroundTransparency = 1
	r.Parent = ui.panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = r
	return r
end

local function clearRows()
	for _, child in ui.panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Drawing ------------------------------------------------------------------------

local render -- forward declaration

local function setStatus(text: string)
	state.status = text
	if ui then
		ui.status.Text = text
	end
end

local function cellLook(char: string): (Color3, string)
	if char == "#" then
		return Colors.backdrop, ""
	elseif char == "m" then
		return Color3.fromRGB(170, 126, 86), ""
	elseif char == "M" then
		return Colors.mud, ""
	elseif char == "1" or char == "2" or char == "3" then
		return Colors.bale, "🌾" .. char
	elseif char == "f" then
		return Colors.frost, "❄️"
	elseif char == "F" then
		return Colors.frost, "❄️2"
	elseif char == "w" then
		return Colors.weed, "🌿"
	elseif char == "p" then
		return TileStyle.Pumpkin.color, TileStyle.Pumpkin.glyph
	elseif char == "c" then
		return TileStyle.Board.clover, TileStyle.GoalGlyphs.Clover
	elseif char == "s" or char == "S" then
		return TileStyle.Board.stone, TileStyle.GoalGlyphs.Stones .. (if char == "S" then "2" else "")
	elseif char == "d" then
		return TileStyle.Board.basket, TileStyle.BasketGlyph
	elseif char == "g" then
		return TileStyle.Board.goo, TileStyle.GoalGlyphs.Goo
	elseif char == "h" then
		return TileStyle.Board.hen, TileStyle.HenGlyph
	elseif char == "x" then
		return TileStyle.Board.crate, TileStyle.CrateGlyph
	elseif char == "b" then
		return TileStyle.Board.buried, TileStyle.GoalGlyphs.Statues
	elseif char == "G" then
		return TileStyle.Board.spring, TileStyle.SpringGlyph
	end
	return Colors.cellLight, ""
end

-- The portal using (x, y) as its entrance or exit: its index and which end.
local function portalAt(x: number, y: number): (number?, string?)
	for i, portal in state.portals do
		if portal.from[1] == x and portal.from[2] == y then
			return i, "from"
		elseif portal.to[1] == x and portal.to[2] == y then
			return i, "to"
		end
	end
	return nil, nil
end

-- The portal brush: tap an entrance, then its exit; tap a portal end to remove it.
local function tapPortal(x: number, y: number)
	local i = portalAt(x, y)
	if i then
		table.remove(state.portals, i)
		state.portalStart = nil
	elseif NOT_CELL[state.grid[y][x]] then
		return
	elseif not state.portalStart then
		state.portalStart = { x, y }
	elseif state.portalStart[1] ~= x or state.portalStart[2] ~= y then
		table.insert(state.portals, { from = state.portalStart, to = { x, y } })
		state.portalStart = nil
	end
end

-- The fence brush: tap a cell, then a neighbour, to add or remove the fence between them.
local function tapFence(x: number, y: number)
	local start = state.fenceStart
	if not start or math.abs(start[1] - x) + math.abs(start[2] - y) ~= 1 then
		state.fenceStart = if NOT_CELL[state.grid[y][x]] then nil else { x, y }
		return
	end
	state.fenceStart = nil
	if NOT_CELL[state.grid[y][x]] then
		return
	end
	local fx, fy = math.min(x, start[1]), math.min(y, start[2])
	local side = if start[2] == y then "r" else "d"
	for i, f in state.fences do
		if f[1] == fx and f[2] == fy and f[3] == side then
			table.remove(state.fences, i)
			return
		end
	end
	table.insert(state.fences, { fx, fy, side })
end

-- A hole or basket can't hold a portal end or a fence.
local function dropPortalsAt(x: number, y: number)
	local i = portalAt(x, y)
	while i do
		table.remove(state.portals, i)
		i = portalAt(x, y)
	end
	for j = #state.fences, 1, -1 do
		local f = state.fences[j]
		local ox, oy = f[1] + (if f[3] == "r" then 1 else 0), f[2] + (if f[3] == "d" then 1 else 0)
		if (f[1] == x and f[2] == y) or (ox == x and oy == y) then
			table.remove(state.fences, j)
		end
	end
end

-- Fence marks for a cell's own right and bottom edges, and a ? on a fence's first tap.
local function fenceText(x: number, y: number): string
	local text = ""
	for _, f in state.fences do
		if f[1] == x and f[2] == y then
			text ..= if f[3] == "r" then " |" else " _"
		end
	end
	if state.fenceStart and state.fenceStart[1] == x and state.fenceStart[2] == y then
		text ..= "🚧?"
	end
	return text
end

local function renderGrid()
	for _, child in ui.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local w, h = width(), height()
	ui.gridAspect.AspectRatio = w / h
	for y = 1, h do
		for x = 1, w do
			local color, text = cellLook(state.grid[y][x])
			local portal, side = portalAt(x, y)
			if portal then
				text ..= string.format("🌀%d%s", portal, if side == "from" then "▼" else "▲")
			elseif state.portalStart and state.portalStart[1] == x and state.portalStart[2] == y then
				text ..= "🌀?"
			end
			text ..= fenceText(x, y)
			local cell = textItem("TextButton", ui.grid, string.format("Cell%d_%d", x, y), text, UDim2.fromScale(1 / w, 1 / h))
			cell.Position = UDim2.fromScale((x - 1) / w, (y - 1) / h)
			cell.BackgroundTransparency = 0
			cell.BackgroundColor3 = color
			cell.BorderSizePixel = 1
			cell.BorderColor3 = Colors.backdrop
			cell.TextColor3 = Colors.baleText
			cell.AutoButtonColor = false
			cell.Activated:Connect(function()
				if state.brush == PORTAL then
					tapPortal(x, y)
				elseif state.brush == FENCE then
					tapFence(x, y)
				else
					state.grid[y][x] = state.brush
					if NOT_CELL[state.brush] then
						dropPortalsAt(x, y)
					end
				end
				render()
			end)
		end
	end
end

local function goalLabel(goal): string
	if goal.kind == "Collect" then
		return TileStyle.Glyphs[Tiles.ByName[goal.tile]] .. " " .. goal.tile
	elseif goal.kind == "Mud" then
		return "🟫 all mud"
	elseif goal.kind == "Frost" then
		return "❄️ all frost"
	elseif goal.kind == "Weeds" then
		return "🌿 all weeds"
	elseif goal.kind == "Pumpkins" then
		return "🎃 pumpkins"
	elseif goal.kind == "Clover" then
		return "🍀 cover it"
	elseif goal.kind == "Stones" then
		return "🧱 all stone"
	elseif goal.kind == "Fences" then
		return "🚧 all fences"
	elseif goal.kind == "Goo" then
		return "🟢 all goo"
	elseif goal.kind == "Statues" then
		return "🗿 all statues"
	end
	return "🌾 all bales"
end

local function stepper(parent: Instance, name: string, value: string, onChange: (number) -> ())
	button(parent, name .. "Down", "−", UDim2.fromOffset(32, ROW_HEIGHT - 4), function()
		onChange(-1)
	end)
	textItem("TextLabel", parent, name, value, UDim2.fromOffset(70, ROW_HEIGHT - 6))
	button(parent, name .. "Up", "+", UDim2.fromOffset(32, ROW_HEIGHT - 4), function()
		onChange(1)
	end)
end

local function renderPanel()
	clearRows()
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	-- Load, the actions and the status line sit at the top so adding goals
	-- doesn't push them around (LayoutOrder 2 to 4); the rest follow.
	local title = row("Title", 1)
	order = 10
	textItem("TextLabel", title, "Label", "Level editor", UDim2.new(0.6, 0, 1, 0))
	button(title, "Close", "Back", UDim2.new(0.35, 0, 1, -4), function()
		LevelEditor.close()
		PuzzleScreen.open()
	end)

	local nameRow = row("NameRow", nextOrder())
	textItem("TextLabel", nameRow, "Label", "Name", UDim2.new(0.25, 0, 1, -8))
	local nameBox = textItem("TextBox", nameRow, "Box", state.name, UDim2.new(0.72, 0, 1, -4))
	nameBox.BackgroundTransparency = 0
	nameBox.BackgroundColor3 = Color3.new(1, 1, 1)
	nameBox.ClearTextOnFocus = false
	nameBox.FocusLost:Connect(function()
		state.name = nameBox.Text
	end)

	local sizeRow = row("BoardSize", nextOrder())
	stepper(sizeRow, "Width", "W " .. width(), function(d)
		resize(d, 0)
		render()
	end)
	stepper(sizeRow, "Height", "H " .. height(), function(d)
		resize(0, d)
		render()
	end)

	for _, rowName in { "Brushes", "MoreBrushes" } do
		local brushes = BRUSH_ROWS[rowName]
		local brushRow = row(rowName, nextOrder())
		for i, brush in brushes do
			local b = button(brushRow, "Brush" .. brush.char, brush.label, UDim2.new(1 / #brushes, -4, 1, -4), function()
				state.brush = brush.char
				render()
			end)
			b.LayoutOrder = i
			b.BackgroundColor3 = if state.brush == brush.char then Colors.accent else Colors.locked
		end
	end

	local movesRow = row("Moves", nextOrder())
	stepper(movesRow, "Moves", state.moves .. " moves", function(d)
		state.moves = math.clamp(state.moves + d, 5, 60)
		render()
	end)
	button(movesRow, "Difficulty", state.difficulty, UDim2.fromOffset(110, ROW_HEIGHT - 4), function()
		local i = table.find(DIFFICULTIES, state.difficulty) or 1
		state.difficulty = DIFFICULTIES[i % #DIFFICULTIES + 1]
		render()
	end)

	local colorRow = row("Colors", nextOrder())
	for i, name in Tiles.Names do
		local on = table.find(state.colors, name) ~= nil
		local b = button(colorRow, name, TileStyle.Glyphs[i], UDim2.new(1 / #Tiles.Names, -4, 1, -4), function()
			local at = table.find(state.colors, name)
			if at then
				table.remove(state.colors, at)
			else
				table.insert(state.colors, name)
			end
			render()
		end)
		b.LayoutOrder = i
		b.BackgroundColor3 = if on then TileStyle.Colors[i] else Colors.locked
		b.BackgroundTransparency = if on then 0 else 0.5
	end

	-- The add buttons go above the goals so they stay put as goals are added.
	local addGoalOrder = nextOrder()
	for i, goal in state.goals do
		local goalRow = row("Goal" .. i, nextOrder())
		local label = button(goalRow, "Kind", goalLabel(goal), UDim2.fromOffset(120, ROW_HEIGHT - 4), function()
			-- Tap a collect goal to move it to the next tile colour.
			if goal.kind == "Collect" then
				local at = table.find(state.colors, goal.tile) or 0
				goal.tile = state.colors[at % math.max(1, #state.colors) + 1] or goal.tile
				render()
			end
		end)
		label.BackgroundColor3 = Colors.option
		label.TextColor3 = Colors.text
		if goal.kind == "Collect" then
			stepper(goalRow, "Count", tostring(goal.count), function(d)
				goal.count = math.clamp(goal.count + d * 5, 5, 200)
				render()
			end)
		elseif goal.kind == "Pumpkins" then
			stepper(goalRow, "Count", tostring(goal.count), function(d)
				goal.count = math.clamp(goal.count + d, 1, 20)
				render()
			end)
		end
		button(goalRow, "Remove", "X", UDim2.fromOffset(32, ROW_HEIGHT - 4), function()
			table.remove(state.goals, i)
			render()
		end)
	end
	local addRow = row("AddGoal", addGoalOrder)
	for _, kind in GOAL_KINDS do
		button(addRow, "Add" .. kind, GOAL_BUTTONS[kind], UDim2.new(1 / #GOAL_KINDS, -4, 1, -4), function()
			if #state.goals >= 3 then
				setStatus("3 goals at most.")
				return
			end
			if kind == "Collect" then
				table.insert(state.goals, { kind = "Collect", tile = state.colors[1] or "Tomato", count = 15 })
			elseif kind == "Pumpkins" then
				table.insert(state.goals, { kind = "Pumpkins", count = 3 })
			else
				table.insert(state.goals, { kind = kind })
			end
			render()
		end)
	end

	local loadRow = row("Load", 2)
	stepper(loadRow, "LoadId", "Level " .. state.loadId, function(d)
		state.loadId = math.clamp(state.loadId + d, 1, #Levels.List)
		render()
	end)
	button(loadRow, "LoadLevel", "Load", UDim2.fromOffset(60, ROW_HEIGHT - 4), function()
		LevelEditor.load(Levels.get(state.loadId))
	end)
	button(loadRow, "New", "New", UDim2.fromOffset(60, ROW_HEIGHT - 4), function()
		state = blankLevel()
		render()
	end)

	local actions = row("Actions", 3)
	button(actions, "TestPlay", "Test play", UDim2.new(1 / 3, -4, 1, -4), LevelEditor.testPlay)
	button(actions, "BotCheck", "Bot check", UDim2.new(1 / 3, -4, 1, -4), LevelEditor.botCheck)
	button(actions, "Export", "Export", UDim2.new(1 / 3, -4, 1, -4), LevelEditor.export)

	local statusRow = row("StatusRow", 4, 2)
	local status = textItem("TextLabel", statusRow, "Status", state.status or "", UDim2.new(1, 0, 1, 0))
	status.TextWrapped = true
	status.TextColor3 = Colors.accent
	ui.status = status

	local exportRow = row("ExportRow", nextOrder(), 5)
	local box = textItem("TextBox", exportRow, "Text", state.exported or "", UDim2.new(1, 0, 1, 0))
	box.TextScaled = false
	box.TextSize = 12
	box.Font = Enum.Font.Code
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.BackgroundTransparency = 0
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	ui.exportBox = box
end

render = function()
	renderGrid()
	renderPanel()
	local err = Levels.validate(toLevel())
	if err then
		ui.status.Text = "⚠️ " .. err
	end
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CropPopEditor"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 21
	gui.Enabled = false

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Colors.backdrop
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local gridArea = Instance.new("Frame")
	gridArea.Name = "GridArea"
	gridArea.Position = UDim2.new(0, 12, 0, 64)
	gridArea.Size = UDim2.new(0.55, -18, 1, -76)
	gridArea.BackgroundTransparency = 1
	gridArea.Parent = backdrop
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.fromScale(1, 1)
	grid.BackgroundTransparency = 1
	grid.Parent = gridArea
	local gridAspect = Instance.new("UIAspectRatioConstraint")
	gridAspect.Parent = grid

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Panel"
	panel.Position = UDim2.new(0.55, 6, 0, 64)
	panel.Size = UDim2.new(0.45, -18, 1, -76)
	panel.BackgroundColor3 = Colors.panel
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 6
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new()
	panel.Parent = backdrop
	corner(panel, 0.02)
	local panelLayout = Instance.new("UIListLayout")
	panelLayout.Padding = UDim.new(0, 6)
	panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	panelLayout.Parent = panel
	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingTop = UDim.new(0, 6)
	panelPadding.Parent = panel

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return { gui = gui, grid = grid, gridAspect = gridAspect, panel = panel }
end

-- Public API ---------------------------------------------------------------------

function LevelEditor.open()
	if not RunService:IsStudio() then
		return
	end
	if not ui then
		ui = build()
	end
	state = state or blankLevel()
	ui.gui.Enabled = true
	render()
end

function LevelEditor.close()
	if ui then
		ui.gui.Enabled = false
	end
end

function LevelEditor.isOpen(): boolean
	return ui ~= nil and ui.gui.Enabled
end

function LevelEditor.load(level)
	if not level then
		return
	end
	state = fromLevel(level)
	if ui then
		render()
	end
end

-- The level as it stands, and the validator's complaint if any.
function LevelEditor.current()
	local level = toLevel()
	return level, Levels.validate(level)
end

function LevelEditor.testPlay()
	local level, err = LevelEditor.current()
	if err then
		setStatus("Can't play yet: " .. err)
		return
	end
	LevelEditor.close()
	PuzzleScreen.playTest(level, LevelEditor.open)
end

function LevelEditor.botCheck()
	local level, err = LevelEditor.current()
	if err then
		setStatus("Can't check yet: " .. err)
		return
	end
	setStatus("The bot is playing...")
	local report = Bot.play(level, BOT_GAMES, os.time())
	local losses = report.games - report.wins
	local lossText = if losses == 0 then "no losses" else string.format("%d%% of goals done on losses", math.round(report.avgGoalShare * 100))
	setStatus(string.format(
		"Bot wins %d%% of %d games (%.1f moves left on wins; %s). The bot plays randomly, so people do better.",
		math.round(report.winRate * 100),
		report.games,
		report.avgMovesLeft,
		lossText
	))
	return report
end

function LevelEditor.export(): string?
	local level, err = LevelEditor.current()
	if err then
		setStatus("Fix this first: " .. err)
		return nil
	end
	local text = LevelText.write(level)
	state.exported = text
	if ui then
		ui.exportBox.Text = text
	end
	print("[CropPop] Level " .. level.id .. " for Levels/" .. Levels.setFor(level.id) .. ".luau:\n" .. text)
	setStatus("Exported. Paste it from the box or Output into Levels/" .. Levels.setFor(level.id) .. ".luau.")
	return text
end

-- For tests: paint one cell with a brush character ("o" taps the portal brush, "|" the fence brush).
function LevelEditor.paint(x: number, y: number, char: string)
	state.brush = char
	if char == PORTAL then
		tapPortal(x, y)
	elseif char == FENCE then
		tapFence(x, y)
	else
		state.grid[y][x] = char
		if NOT_CELL[char] then
			dropPortalsAt(x, y)
		end
	end
	if ui then
		render()
	end
end

return LevelEditor
