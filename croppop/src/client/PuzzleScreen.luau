--[[
	The Crop Pop screen: level select, the board with its top bar, and the
	win / out-of-moves panels.

		local PuzzleScreen = require(path.to.PuzzleScreen)
		PuzzleScreen.open()      -- level select
		PuzzleScreen.open(3)     -- straight into level 3
		PuzzleScreen.close()

	The Puzzle Porch and the Town Square cabinet should call open(). Until
	they exist, Main.client.luau adds a temporary button.

	The client plays the level locally with the seed the server handed out and
	sends its swaps when the level ends; the server replays them before paying.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CropPop = require(ReplicatedStorage:WaitForChild("CropPop"))
local BoardView = require(script.Parent.BoardView)
local TileStyle = require(script.Parent.TileStyle)

local Levels = CropPop.Levels
local Colors = TileStyle.Board

local PuzzleScreen = {}

local ui = nil -- built on first open
local current = nil -- the level being played
local busy = false

-- Small UI helpers -----------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(radius, 0)
	c.Parent = parent
end

local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = TileStyle.Font
	l.TextColor3 = Colors.text
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = Colors.accent
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Font = TileStyle.Font
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 0.3)
	local padding = Instance.new("UIPadding")
	padding.Name = "Padding"
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = b
	return b
end

local function remotes()
	return ReplicatedStorage:WaitForChild("CropPopRemotes", 10)
end

local function invoke(name: string, ...)
	local folder = remotes()
	if not folder then
		return { error = "Crop Pop isn't running on this server" }
	end
	local ok, result = pcall(function(...)
		return (folder:WaitForChild(name) :: RemoteFunction):InvokeServer(...)
	end, ...)
	if not ok then
		return { error = "couldn't reach the server" }
	end
	return result or { error = "no answer from the server" }
end

-- Building the screen ----------------------------------------------------------

local function buildUi()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CropPop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Colors.backdrop
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	-- Play area: top bar + board.
	local play = Instance.new("Frame")
	play.Name = "Play"
	play.Size = UDim2.fromScale(1, 1)
	play.BackgroundTransparency = 1
	play.Visible = false
	play.Parent = backdrop

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 44)
	topBar.Size = UDim2.new(0.96, 0, 0.12, 0)
	topBar.BackgroundColor3 = Colors.panel
	topBar.Parent = play
	corner(topBar, 0.2)
	local barSize = Instance.new("UISizeConstraint")
	barSize.MaxSize = Vector2.new(720, 110)
	barSize.Parent = topBar

	local levelName = label(topBar, "LevelName", "", UDim2.fromScale(0.3, 0.4), UDim2.fromScale(0.03, 0.08))
	levelName.TextXAlignment = Enum.TextXAlignment.Left
	local difficulty = label(topBar, "Difficulty", "", UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.03, 0.55))
	difficulty.TextXAlignment = Enum.TextXAlignment.Left
	difficulty.TextColor3 = Colors.accent

	local movesBox = Instance.new("Frame")
	movesBox.Name = "Moves"
	movesBox.AnchorPoint = Vector2.new(0.5, 0.5)
	movesBox.Position = UDim2.fromScale(0.42, 0.5)
	movesBox.Size = UDim2.fromScale(0.16, 0.84)
	movesBox.BackgroundColor3 = Colors.accent
	movesBox.Parent = topBar
	corner(movesBox, 0.25)
	local movesCount = label(movesBox, "Count", "0", UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0.04))
	movesCount.TextColor3 = Color3.new(1, 1, 1)
	local movesCaption = label(movesBox, "Caption", "moves", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.66))
	movesCaption.TextColor3 = Color3.new(1, 1, 1)

	local goals = Instance.new("Frame")
	goals.Name = "Goals"
	goals.Position = UDim2.fromScale(0.52, 0.1)
	goals.Size = UDim2.fromScale(0.36, 0.8)
	goals.BackgroundTransparency = 1
	goals.Parent = topBar
	local goalsLayout = Instance.new("UIListLayout")
	goalsLayout.FillDirection = Enum.FillDirection.Horizontal
	goalsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	goalsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	goalsLayout.Padding = UDim.new(0.03, 0)
	goalsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	goalsLayout.Parent = goals

	local closePlay = button(topBar, "Close", "X", UDim2.fromScale(0.08, 0.6), UDim2.fromScale(0.9, 0.2))

	local boardHolder = Instance.new("Frame")
	boardHolder.Name = "BoardHolder"
	-- Fills the space under the top bar; the board keeps its shape inside it and
	-- shrinks to whichever side runs out first (phones, landscape).
	boardHolder.AnchorPoint = Vector2.new(0.5, 0)
	boardHolder.Position = UDim2.new(0.5, 0, 0.12, 52)
	boardHolder.Size = UDim2.new(0.96, 0, 0.88, -60)
	boardHolder.BackgroundTransparency = 1
	boardHolder.Parent = play

	-- Level select.
	local levelSelect = Instance.new("Frame")
	levelSelect.Name = "LevelSelect"
	levelSelect.AnchorPoint = Vector2.new(0.5, 0.5)
	levelSelect.Position = UDim2.fromScale(0.5, 0.5)
	levelSelect.Size = UDim2.fromScale(0.9, 0.8)
	levelSelect.BackgroundColor3 = Colors.panel
	levelSelect.Parent = backdrop
	corner(levelSelect, 0.06)
	local selectSize = Instance.new("UISizeConstraint")
	selectSize.MaxSize = Vector2.new(520, 640)
	selectSize.Parent = levelSelect
	label(levelSelect, "Title", "Crop Pop Trail", UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.1, 0.03))
	local status = label(levelSelect, "Status", "", UDim2.fromScale(0.9, 0.05), UDim2.fromScale(0.05, 0.14))
	status.TextColor3 = Colors.accent
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.06, 0.21)
	list.Size = UDim2.fromScale(0.88, 0.62)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = levelSelect
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	local closeSelect = button(levelSelect, "Close", "Back to the farm", UDim2.fromScale(0.6, 0.09), UDim2.fromScale(0.2, 0.87))

	-- End-of-level panel.
	local panel = Instance.new("Frame")
	panel.Name = "EndPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.8, 0.42)
	panel.BackgroundColor3 = Colors.panel
	panel.Visible = false
	panel.ZIndex = 10
	panel.Parent = backdrop
	corner(panel, 0.08)
	local panelSize = Instance.new("UISizeConstraint")
	panelSize.MaxSize = Vector2.new(460, 320)
	panelSize.Parent = panel
	local panelTitle = label(panel, "Title", "", UDim2.fromScale(0.9, 0.22), UDim2.fromScale(0.05, 0.06))
	local panelBody = label(panel, "Body", "", UDim2.fromScale(0.9, 0.3), UDim2.fromScale(0.05, 0.32))
	panelBody.TextWrapped = true
	local primary = button(panel, "Primary", "", UDim2.fromScale(0.42, 0.2), UDim2.fromScale(0.05, 0.72))
	local secondary = button(panel, "Secondary", "", UDim2.fromScale(0.42, 0.2), UDim2.fromScale(0.53, 0.72))
	secondary.BackgroundColor3 = Colors.locked

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	return {
		gui = gui,
		play = play,
		levelName = levelName,
		difficulty = difficulty,
		movesCount = movesCount,
		goals = goals,
		closePlay = closePlay,
		boardHolder = boardHolder,
		select = levelSelect,
		status = status,
		list = list,
		closeSelect = closeSelect,
		panel = panel,
		panelTitle = panelTitle,
		panelBody = panelBody,
		primary = primary,
		secondary = secondary,
		panelActions = {},
	}
end

-- Top bar ----------------------------------------------------------------------

local function goalGlyph(goal): string
	if goal.kind == "Collect" then
		return TileStyle.Glyphs[goal.color] or "?"
	end
	return TileStyle.GoalGlyphs[goal.kind] or "?"
end

local function refreshHud()
	if not current then
		return
	end
	local state = current.game:getState()
	ui.movesCount.Text = tostring(state.movesLeft)
	for _, child in ui.goals:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, goal in state.goals do
		local box = Instance.new("Frame")
		box.Name = "Goal" .. i
		box.LayoutOrder = i
		box.Size = UDim2.fromScale(0.3, 1)
		box.BackgroundTransparency = 1
		box.Parent = ui.goals
		label(box, "Icon", goalGlyph(goal), UDim2.fromScale(1, 0.6), UDim2.fromScale(0, 0))
		local left = goal.target - goal.progress
		local count = label(box, "Count", if left <= 0 then "✅" else tostring(left), UDim2.fromScale(1, 0.4), UDim2.fromScale(0, 0.6))
		if left <= 0 then
			count.TextColor3 = Color3.fromRGB(60, 150, 60)
		end
	end
end

-- Panels -----------------------------------------------------------------------

local function showPanel(title: string, body: string, primaryText: string, onPrimary: () -> (), secondaryText: string, onSecondary: () -> ())
	ui.panelTitle.Text = title
	ui.panelBody.Text = body
	ui.primary.Text = primaryText
	ui.secondary.Text = secondaryText
	ui.panelActions.primary = onPrimary
	ui.panelActions.secondary = onSecondary
	ui.panel.Visible = true
end

local function hidePanel()
	ui.panel.Visible = false
end

local showLevelSelect -- forward declaration
local startLevel

local function rewardText(rewards): string
	if not rewards then
		return ""
	end
	local parts = {}
	if rewards.coins and rewards.coins > 0 then
		table.insert(parts, "+" .. rewards.coins .. " Coins")
	end
	if rewards.xp and rewards.xp > 0 then
		table.insert(parts, "+" .. rewards.xp .. " XP")
	end
	return table.concat(parts, "   ")
end

local function onLevelEnded()
	local run = current
	local status = run.game.status
	run.view:setEnabled(false)
	local result = invoke("FinishLevel", run.token, run.moves)
	if current ~= run then
		return -- the player left while the server was checking
	end
	if status == "Won" then
		if result.error then
			showPanel("Hmm, that didn't check out", "The server couldn't confirm this win (" .. tostring(result.error) .. ").", "Try again", function()
				startLevel(run.levelId)
			end, "Trail", showLevelSelect)
			return
		end
		local nextLevel = Levels.get(run.levelId + 1)
		showPanel(
			"Level complete!",
			rewardText(result.rewards),
			if nextLevel then "Next level" else "Trail",
			function()
				if nextLevel then
					startLevel(nextLevel.id)
				else
					showLevelSelect()
				end
			end,
			"Trail",
			showLevelSelect
		)
	else
		-- Paid continues (+5 moves) arrive with P2.
		showPanel("Out of moves", "So close! Give it another go.", "Retry", function()
			startLevel(run.levelId)
		end, "Trail", showLevelSelect)
	end
end

local function onSwap(x1: number, y1: number, x2: number, y2: number)
	local run = current
	if busy or not run or run.game.status ~= "Playing" then
		return
	end
	busy = true
	task.spawn(function()
		local ok, phases = run.game:trySwap(x1, y1, x2, y2)
		if ok then
			table.insert(run.moves, { x1, y1, x2, y2 })
			ui.movesCount.Text = tostring(run.game.movesLeft)
		end
		run.view:play(phases)
		if current == run then
			run.view:sync(run.game)
			refreshHud()
		end
		busy = false
		if current == run and run.game.status ~= "Playing" then
			onLevelEnded()
		end
	end)
end

-- Flow -------------------------------------------------------------------------

local function clearRun()
	if current then
		current.view:destroy()
		current = nil
	end
	busy = false
end

startLevel = function(levelId: number)
	hidePanel()
	local level = Levels.get(levelId)
	if not level then
		return
	end
	local run = invoke("StartLevel", levelId)
	if run.error then
		showLevelSelect("Couldn't start: " .. tostring(run.error))
		return
	end
	clearRun()
	local pop = CropPop.Engine.new(level, run.seed)
	local view = BoardView.new(ui.boardHolder, onSwap)
	current = { levelId = levelId, token = run.token, game = pop, view = view, moves = {} }
	view:load(pop)
	ui.levelName.Text = level.id .. ". " .. level.name
	ui.difficulty.Text = if level.difficulty == "Normal" then "" else level.difficulty
	refreshHud()
	ui.select.Visible = false
	ui.play.Visible = true
end

showLevelSelect = function(message: string?)
	hidePanel()
	clearRun()
	ui.play.Visible = false
	ui.select.Visible = true
	ui.status.Text = message or ""
	for _, child in ui.list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local progress = invoke("GetProgress")
	local highest = progress.highestBeaten or 0
	for _, level in Levels.List do
		local unlocked = progress.unlockAll or level.id <= highest + 1
		local beaten = level.id <= highest
		local text = string.format("%d  %s%s", level.id, level.name, if level.difficulty ~= "Normal" then "  (" .. level.difficulty .. ")" else "")
		if beaten then
			text ..= "  ✅"
		elseif not unlocked then
			text ..= "  🔒"
		end
		local row = button(ui.list, "Level" .. level.id, text, UDim2.new(1, -10, 0, 52), UDim2.new())
		row.LayoutOrder = level.id
		row.TextXAlignment = Enum.TextXAlignment.Left
		if not unlocked then
			row.BackgroundColor3 = Colors.locked
			row.AutoButtonColor = false
		else
			row.Activated:Connect(function()
				startLevel(level.id)
			end)
		end
	end
end

local function ensureUi()
	if ui then
		return
	end
	ui = buildUi()
	ui.closePlay.Activated:Connect(function()
		showLevelSelect()
	end)
	ui.closeSelect.Activated:Connect(function()
		PuzzleScreen.close()
	end)
	ui.primary.Activated:Connect(function()
		local action = ui.panelActions.primary
		if action then
			action()
		end
	end)
	ui.secondary.Activated:Connect(function()
		local action = ui.panelActions.secondary
		if action then
			action()
		end
	end)
end

-- Public API -------------------------------------------------------------------

function PuzzleScreen.open(levelId: number?)
	ensureUi()
	ui.gui.Enabled = true
	if levelId then
		startLevel(levelId)
	else
		showLevelSelect()
	end
end

function PuzzleScreen.close()
	if not ui then
		return
	end
	clearRun()
	hidePanel()
	ui.gui.Enabled = false
end

function PuzzleScreen.isOpen(): boolean
	return ui ~= nil and ui.gui.Enabled
end

-- The level being played, for debugging and tests.
function PuzzleScreen.currentRun()
	return current
end


return PuzzleScreen
