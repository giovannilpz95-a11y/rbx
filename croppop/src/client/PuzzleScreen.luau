--[[
	The Crop Pop screen: the Trail (level select, with Hearts), the pre-level
	booster picker, the board with its top bar and booster bar, and the
	win / out-of-moves panels.

		local PuzzleScreen = require(path.to.PuzzleScreen)
		PuzzleScreen.open()      -- the Trail
		PuzzleScreen.open(3)     -- straight to level 3's booster picker
		PuzzleScreen.close()

	The Puzzle Porch and the Town Square cabinet should call open(). Until
	they exist, Main.client.luau adds a temporary button.

	The client plays the level locally with the seed the server handed out and
	sends its swaps and booster uses when the level ends; the server replays
	them before paying, and only then charges the in-level boosters.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CropPop = require(ReplicatedStorage:WaitForChild("CropPop"))
local BoardView = require(script.Parent.BoardView)
local Sfx = require(script.Parent.Sfx)
local TileStyle = require(script.Parent.TileStyle)

local Kit = TileStyle.Theme.Kit
local Motion = TileStyle.Theme.Motion

local Boosters = CropPop.Boosters
local Hearts = CropPop.Hearts
local Levels = CropPop.Levels
local Colors = TileStyle.Board
local LOCKED_AHEAD = 4 -- locked levels shown on the trail past the next one
local ROW_STEP = 60 -- a trail row plus the list padding, in pixels
local Glyphs = TileStyle.BoosterGlyphs

local PuzzleScreen = {}

local ui = nil -- built on first open
local current = nil -- the level being played
local busy = false
local progress = nil -- the latest hearts / boosters / unlocks from the server
local progressAt = 0 -- os.clock() when it arrived, for the hearts countdown

local GEM_CONFIRM_OVER = 10 -- spends above this need a second tap (10 Monetization)

-- Glyphs for the free Hot Streak power-ups, matching the start boosters.
local POWER_GLYPHS = { Sprayer = Glyphs.SprayerStart, HayBomb = Glyphs.BombStart, Sunflower = Glyphs.SunflowerStart }

local function streak(): number
	return progress and progress.streak or 0
end

local function streakGlyphs(powers: { string }): string
	local parts = {}
	for _, power in powers do
		table.insert(parts, POWER_GLYPHS[power] or "?")
	end
	return table.concat(parts, " ")
end

local BOOSTER_HINTS = {
	Trowel = "⛏️ Tap a tile to break it.",
	Rake = "🧹 Tap a row to clear it.",
	GardenGloves = "🧤 Swap any two tiles next to each other.",
}

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
	-- The shared chunky look (Design/25 UI Style Guide); the button keeps its API.
	Kit.skinButton(b)
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
	Kit.gloss(0.82).Parent = backdrop

	-- Play area: top bar + board.
	local play = Instance.new("Frame")
	play.Name = "Play"
	play.Size = UDim2.fromScale(1, 1)
	play.BackgroundTransparency = 1
	play.Visible = false
	play.Parent = backdrop

	-- Positions for the top bar and board are set by applyLayout().
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundColor3 = Colors.panel
	topBar.Parent = play
	corner(topBar, 0.2)
	Kit.skinPanel(topBar)
	local barPadding = Instance.new("UIPadding")
	barPadding.PaddingLeft = UDim.new(0, 14)
	barPadding.PaddingRight = UDim.new(0, 14)
	barPadding.PaddingTop = UDim.new(0, 6)
	barPadding.PaddingBottom = UDim.new(0, 6)
	barPadding.Parent = topBar

	local levelName = label(topBar, "LevelName", "", UDim2.new(), UDim2.new())
	levelName.TextXAlignment = Enum.TextXAlignment.Left
	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MaxTextSize = 34
	nameSize.Parent = levelName
	local difficulty = label(topBar, "Difficulty", "", UDim2.new(), UDim2.new())
	difficulty.TextXAlignment = Enum.TextXAlignment.Left
	difficulty.TextColor3 = Colors.accentText

	local movesBox = Instance.new("Frame")
	movesBox.Name = "Moves"
	movesBox.AnchorPoint = Vector2.new(0.5, 0.5)
	movesBox.BackgroundColor3 = Colors.accent
	movesBox.Parent = topBar
	corner(movesBox, 0.25)
	local movesCount = label(movesBox, "Count", "0", UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0.04))
	movesCount.TextColor3 = Color3.new(1, 1, 1)
	local movesCaption = label(movesBox, "Caption", "moves", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.66))
	movesCaption.TextColor3 = Color3.new(1, 1, 1)

	local goals = Instance.new("Frame")
	goals.Name = "Goals"
	goals.BackgroundTransparency = 1
	goals.Parent = topBar
	local goalsLayout = Instance.new("UIListLayout")
	goalsLayout.FillDirection = Enum.FillDirection.Horizontal
	goalsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	goalsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	goalsLayout.Padding = UDim.new(0.03, 0)
	goalsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	goalsLayout.Parent = goals

	local closePlay = button(topBar, "Close", "X", UDim2.new(), UDim2.new())

	-- The board keeps its shape inside this and shrinks to whichever side runs out first.
	local boardHolder = Instance.new("Frame")
	boardHolder.Name = "BoardHolder"
	boardHolder.BackgroundTransparency = 1
	boardHolder.Parent = play

	-- Studio only: jump to the last move so the out-of-moves panel is quick to test.
	local devOneMove = nil
	if RunService:IsStudio() then
		devOneMove = button(topBar, "DevOneMove", "Dev: 1 move", UDim2.new(), UDim2.new())
		devOneMove.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
	end

	-- Level select.
	local levelSelect = Instance.new("Frame")
	levelSelect.Name = "LevelSelect"
	levelSelect.AnchorPoint = Vector2.new(0.5, 0.5)
	levelSelect.Position = UDim2.fromScale(0.5, 0.5)
	levelSelect.Size = UDim2.fromScale(0.9, 0.8)
	levelSelect.BackgroundColor3 = Colors.panel
	levelSelect.Parent = backdrop
	corner(levelSelect, 0.06)
	Kit.skinPanel(levelSelect)
	local selectSize = Instance.new("UISizeConstraint")
	selectSize.MaxSize = Vector2.new(520, 640)
	selectSize.Parent = levelSelect
	label(levelSelect, "Title", "Crop Pop Trail", UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.1, 0.03))
	local heartsLine = label(levelSelect, "Hearts", "", UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.13))
	local status = label(levelSelect, "Status", "", UDim2.fromScale(0.9, 0.045), UDim2.fromScale(0.05, 0.195))
	status.TextColor3 = Colors.accentText
	status.TextWrapped = true
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.06, 0.25)
	list.Size = UDim2.fromScale(0.88, 0.6)
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
	-- Studio only: empty the hearts to check the refill offer.
	local devNoHearts, devEditor, devLock = nil, nil, nil
	if RunService:IsStudio() then
		devNoHearts = button(levelSelect, "DevNoHearts", "Dev: 0 hearts", UDim2.fromScale(0.16, 0.09), UDim2.fromScale(0.82, 0.87))
		devNoHearts.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		devEditor = button(levelSelect, "DevEditor", "Dev: Editor", UDim2.fromScale(0.16, 0.09), UDim2.fromScale(0.02, 0.87))
		devEditor.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		-- Studio unlocks every level; this shows the Trail as a real player sees it.
		devLock = button(levelSelect, "DevLock", "Dev 🔒", UDim2.fromScale(0.08, 0.07), UDim2.fromScale(0.91, 0.03))
		devLock.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
	end

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
	Kit.skinPanel(panel)
	local panelSize = Instance.new("UISizeConstraint")
	panelSize.MaxSize = Vector2.new(460, 320)
	panelSize.Parent = panel
	local panelTitle = label(panel, "Title", "", UDim2.fromScale(0.9, 0.26), UDim2.fromScale(0.05, 0.05))
	local panelBody = label(panel, "Body", "", UDim2.fromScale(0.84, 0.3), UDim2.fromScale(0.08, 0.34))
	panelBody.TextWrapped = true
	local bodySize = Instance.new("UITextSizeConstraint")
	bodySize.MaxTextSize = 30
	bodySize.Parent = panelBody
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 48
	titleSize.Parent = panelTitle
	local primary = button(panel, "Primary", "", UDim2.fromScale(0.42, 0.18), UDim2.fromScale(0.05, 0.74))
	local secondary = button(panel, "Secondary", "", UDim2.fromScale(0.42, 0.18), UDim2.fromScale(0.53, 0.74))
	-- The title stays the biggest text in the panel.
	for _, b in { primary, secondary } do
		local buttonText = Instance.new("UITextSizeConstraint")
		buttonText.MaxTextSize = 26
		buttonText.Parent = b
	end
	secondary.BackgroundColor3 = Colors.locked

	-- In-level boosters: under the board on tall screens, in the side panel on wide ones.
	local boosterBar = Instance.new("Frame")
	boosterBar.Name = "Boosters"
	boosterBar.BackgroundTransparency = 1
	boosterBar.Parent = play
	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barLayout.Padding = UDim.new(0.02, 0)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = boosterBar
	local boosterButtons = {}
	for i, kind in Boosters.InLevel do
		local b = button(boosterBar, kind, Glyphs[kind], UDim2.fromScale(0.23, 1), UDim2.new())
		b.LayoutOrder = i
		b.BackgroundColor3 = Colors.panel
		-- Inside the button's top-right corner, above the themed face and text
		local count = label(b, "Count", "", UDim2.fromScale(0.34, 0.48), UDim2.new(1, -3, 0, 3))
		count.AnchorPoint = Vector2.new(1, 0)
		count.BackgroundTransparency = 0
		count.BackgroundColor3 = Colors.accent
		count.TextColor3 = Color3.new(1, 1, 1)
		count.ZIndex = 6
		corner(count, 0.5)
		boosterButtons[kind] = b
	end

	-- What an armed booster does, or a "Spend X Gems?" question. Sits above the
	-- boosters on tall screens and over the level name on wide ones, so the
	-- goals and moves stay in view.
	local hint = label(play, "BoosterHint", "", UDim2.new(), UDim2.new())
	hint.BackgroundTransparency = 0
	hint.BackgroundColor3 = Colors.panel
	hint.TextWrapped = true
	hint.Visible = false
	hint.ZIndex = 5
	corner(hint, 0.2)
	Kit.skinPanel(hint)
	local hintSize = Instance.new("UITextSizeConstraint")
	hintSize.MaxTextSize = 28
	hintSize.Parent = hint
	local hintPadding = Instance.new("UIPadding")
	hintPadding.PaddingLeft = UDim.new(0, 12)
	hintPadding.PaddingRight = UDim.new(0, 12)
	hintPadding.PaddingTop = UDim.new(0, 6)
	hintPadding.PaddingBottom = UDim.new(0, 6)
	hintPadding.Parent = hint

	-- Pre-level panel: pick boosters, then Play.
	local preLevel = Instance.new("Frame")
	preLevel.Name = "PreLevel"
	preLevel.AnchorPoint = Vector2.new(0.5, 0.5)
	preLevel.Position = UDim2.fromScale(0.5, 0.5)
	preLevel.Size = UDim2.fromScale(0.86, 0.6)
	preLevel.BackgroundColor3 = Colors.panel
	preLevel.Visible = false
	preLevel.ZIndex = 10
	preLevel.Parent = backdrop
	corner(preLevel, 0.06)
	Kit.skinPanel(preLevel)
	local preSize = Instance.new("UISizeConstraint")
	preSize.MaxSize = Vector2.new(460, 440)
	preSize.Parent = preLevel
	local preTitle = label(preLevel, "Title", "", UDim2.fromScale(0.9, 0.13), UDim2.fromScale(0.05, 0.04))
	local preTitleSize = Instance.new("UITextSizeConstraint")
	preTitleSize.MaxTextSize = 40
	preTitleSize.Parent = preTitle
	local preBody = label(preLevel, "Body", "Pick boosters for a strong start", UDim2.fromScale(0.84, 0.07), UDim2.fromScale(0.08, 0.19))
	preBody.TextWrapped = true
	local function capText(b: GuiObject)
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 26
		cap.Parent = b
	end
	local preButtons = {}
	for i, kind in Boosters.PreLevel do
		local b = button(preLevel, kind, "", UDim2.fromScale(0.84, 0.11), UDim2.fromScale(0.08, 0.17 + 0.13 * i))
		b.TextXAlignment = Enum.TextXAlignment.Left
		capText(b)
		preButtons[kind] = b
	end
	local prePlay = button(preLevel, "Play", "Play", UDim2.fromScale(0.42, 0.14), UDim2.fromScale(0.05, 0.8))
	local preBack = button(preLevel, "Back", "Trail", UDim2.fromScale(0.42, 0.14), UDim2.fromScale(0.53, 0.8))
	preBack.BackgroundColor3 = Colors.locked
	capText(prePlay)
	capText(preBack)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	return {
		gui = gui,
		play = play,
		levelName = levelName,
		difficulty = difficulty,
		movesCount = movesCount,
		goals = goals,
		closePlay = closePlay,
		devOneMove = devOneMove,
		topBar = topBar,
		movesBox = movesBox,
		boardHolder = boardHolder,
		select = levelSelect,
		heartsLine = heartsLine,
		status = status,
		list = list,
		closeSelect = closeSelect,
		devNoHearts = devNoHearts,
		devEditor = devEditor,
		devLock = devLock,
		panel = panel,
		panelTitle = panelTitle,
		panelBody = panelBody,
		primary = primary,
		secondary = secondary,
		panelActions = {},
		boosterBar = boosterBar,
		boosterButtons = boosterButtons,
		hint = hint,
		preLevel = preLevel,
		preTitle = preTitle,
		preBody = preBody,
		preButtons = preButtons,
		prePlay = prePlay,
		preBack = preBack,
		preSelected = {},
	}
end

-- Layout -----------------------------------------------------------------------
-- Tall screens get a bar across the top; wide screens (landscape phones, PCs)
-- get a panel on the left so the board can use the full height. The bar and
-- the board area are placed in pixels from the screen size; the board sits at
-- the top of its area, centred across it.

local ROBLOX_TOPBAR = 64 -- clear of Roblox's own buttons (58px)
local MARGIN = 12
local BOOSTER_BAR_HEIGHT = 64
local HINT_HEIGHT = 40

-- Where things sit inside the bar / panel, by scale.
local INNER = {
	tall = {
		levelName = { position = UDim2.fromScale(0.03, 0.08), size = UDim2.fromScale(0.3, 0.4) },
		difficulty = { position = UDim2.fromScale(0.03, 0.55), size = UDim2.fromScale(0.3, 0.3) },
		movesBox = { position = UDim2.fromScale(0.42, 0.5), size = UDim2.fromScale(0.16, 0.84) },
		goals = { position = UDim2.fromScale(0.52, 0.1), size = UDim2.fromScale(0.36, 0.8) },
		closePlay = { position = UDim2.fromScale(0.9, 0.2), size = UDim2.fromScale(0.08, 0.6) },
		devOneMove = { position = UDim2.fromScale(0.22, 0.55), size = UDim2.fromScale(0.12, 0.35) },
	},
	wide = {
		levelName = { position = UDim2.fromScale(0, 0.03), size = UDim2.fromScale(1, 0.1) },
		difficulty = { position = UDim2.fromScale(0, 0.13), size = UDim2.fromScale(1, 0.06) },
		movesBox = { position = UDim2.fromScale(0.5, 0.33), size = UDim2.fromScale(0.5, 0.2) },
		goals = { position = UDim2.fromScale(0, 0.45), size = UDim2.fromScale(1, 0.18) },
		closePlay = { position = UDim2.fromScale(0.25, 0.86), size = UDim2.fromScale(0.5, 0.1) },
		devOneMove = { position = UDim2.fromScale(0.25, 0.79), size = UDim2.fromScale(0.5, 0.05) },
	},
}

local function applyLayout()
	local screen = ui.gui.AbsoluteSize
	local w, h = screen.X, screen.Y
	if w <= 0 or h <= 0 then
		return -- not measured yet; AbsoluteSize changes again once it is
	end
	local mode = if w > h * 1.25 then "wide" else "tall"
	ui.layout = mode

	local barX, barW, barH, holderX, holderY, holderW, holderH
	local boosters, hint -- { x, y, w, h }
	if mode == "wide" then
		barX = MARGIN
		barW = math.min(w * 0.28, 340)
		barH = math.min(h - ROBLOX_TOPBAR - MARGIN, 520)
		holderX = barX + barW + MARGIN
		holderY = ROBLOX_TOPBAR -- board top lines up with the panel top
		holderW = w - holderX - MARGIN
		holderH = h - holderY - MARGIN
		boosters = { barX + 14, ROBLOX_TOPBAR + barH * 0.65, barW - 28, barH * 0.12 }
		hint = { barX, ROBLOX_TOPBAR, barW, barH * 0.21 } -- over the level name, clear of the goals
	else
		barW = math.min(w * 0.96, 720)
		barX = (w - barW) / 2
		barH = math.min(h * 0.12, 110)
		local boosterH = math.min(h * 0.08, BOOSTER_BAR_HEIGHT)
		local boostersY = h - 8 - boosterH
		local hintY = boostersY - 4 - HINT_HEIGHT -- a strip of its own above the boosters
		holderX = w * 0.02
		holderY = ROBLOX_TOPBAR + barH + 8
		holderW = w * 0.96
		holderH = hintY - 4 - holderY
		boosters = { barX, boostersY, barW, boosterH }
		hint = { barX, hintY, barW, HINT_HEIGHT }
	end
	ui.boosterBar.Position = UDim2.fromOffset(boosters[1], boosters[2])
	ui.boosterBar.Size = UDim2.fromOffset(boosters[3], boosters[4])
	ui.hint.Position = UDim2.fromOffset(hint[1], hint[2])
	ui.hint.Size = UDim2.fromOffset(hint[3], hint[4])

	ui.topBar.AnchorPoint = Vector2.new(0, 0)
	ui.topBar.Position = UDim2.fromOffset(barX, ROBLOX_TOPBAR)
	ui.topBar.Size = UDim2.fromOffset(barW, barH)
	ui.boardHolder.AnchorPoint = Vector2.new(0, 0)
	ui.boardHolder.Position = UDim2.fromOffset(holderX, holderY)
	ui.boardHolder.Size = UDim2.fromOffset(holderW, holderH)

	for key, spec in INNER[mode] do
		local item = ui[key]
		if item then -- devOneMove only exists in Studio
			item.Position = spec.position
			item.Size = spec.size
		end
	end
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
	ui.primary.BackgroundColor3 = Colors.accent
	ui.pendingSpend = nil
	-- Centre on the board (not the screen) when one is showing.
	local board = current and current.view.frame
	if board and ui.play.Visible then
		local origin = ui.panel.Parent.AbsolutePosition
		ui.panel.Position = UDim2.fromOffset(
			board.AbsolutePosition.X - origin.X + board.AbsoluteSize.X / 2,
			board.AbsolutePosition.Y - origin.Y + board.AbsoluteSize.Y / 2
		)
	else
		ui.panel.Position = UDim2.fromScale(0.5, 0.5)
	end
	-- Ignore clicks for a moment so a tap meant for the board can't hit a panel button.
	ui.panelShownAt = os.clock()
	Motion.popIn(ui.panel)
	ui.panel.Visible = true
end

local PANEL_CLICK_DELAY = 0.5

local function panelReady(): boolean
	return os.clock() - (ui.panelShownAt or 0) >= PANEL_CLICK_DELAY
end

local function hidePanel()
	ui.panel.Visible = false
end

local showLevelSelect -- forward declarations
local showPreLevel
local startLevel
local beginRun

local function clearRun()
	if current then
		current.view:destroy()
		current = nil
	end
	busy = false
end

-- Server progress ----------------------------------------------------------------

local function setProgress(p)
	if type(p) ~= "table" or type(p.hearts) ~= "table" then
		return
	end
	-- Only GetProgress says whether every level is open (Studio).
	if p.unlockAll == nil and progress then
		p.unlockAll = progress.unlockAll
	end
	progress = p
	progressAt = os.clock()
end

local function fetchProgress()
	setProgress(invoke("GetProgress"))
end

local function clockText(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Seconds left on a countdown from the last progress, counting down locally.
local function since(seconds: number?): number?
	if not seconds then
		return nil
	end
	return seconds - (os.clock() - progressAt)
end

local function heartsText(): string
	local hearts = progress and progress.hearts
	if not hearts then
		return ""
	end
	local unlimited = since(hearts.unlimitedSeconds)
	if unlimited and unlimited > 0 then
		return "❤️ Unlimited for " .. clockText(unlimited)
	end
	local text = string.format("❤️ %d/%d", hearts.count, hearts.max)
	local nextIn = since(hearts.secondsToNext)
	if nextIn then
		text ..= "   next in " .. clockText(nextIn)
	end
	if streak() > 0 then
		text ..= "   🔥 " .. streak()
	end
	return text
end

-- Most Gems the player can have after a charge failed for lack of them, when
-- the farm doesn't share the balance. Kept across progress updates; cleared
-- by a fresh look (stillShort) or a successful buy.
local shortBelow: number? = nil

-- False only when we know the player can't pay: the farm's Gem balance (if
-- it shares one) or a charge that failed for lack of Gems.
local function canAfford(gems: number): boolean
	local have = progress and progress.gems
	if type(have) == "number" then
		return have >= gems
	end
	return shortBelow == nil or gems <= shortBelow
end

local function noteShort(gems: number, err: any)
	if err == "not enough Gems" then
		shortBelow = math.min(shortBelow or math.huge, gems - 1)
	end
end

-- For a tap on a greyed "Not enough" offer: take a fresh look (they may have
-- bought Gems since) and say whether they still can't pay.
local function stillShort(gems: number): boolean
	if canAfford(gems) then
		return false
	end
	shortBelow = nil
	fetchProgress()
	return not canAfford(gems)
end

local function notEnoughText(gems: number): string
	return string.format("Not enough 💎 (this costs %d).", gems)
end

-- Spends above GEM_CONFIRM_OVER ask "Spend X Gems?" first and go through on a
-- second tap of the same thing. Returns true when it's OK to buy now.
local function askToSpend(key: string, gems: number): boolean
	if gems <= GEM_CONFIRM_OVER or ui.pendingSpend == key then
		ui.pendingSpend = nil
		return true
	end
	ui.pendingSpend = key
	return false
end

-- The Trail ------------------------------------------------------------------------

local renderTrail -- forward declaration
local devLocked = false -- Studio: show the Trail locked to real progress

local function buyHearts(packIndex: number, b: TextButton)
	local pack = Hearts.Packs[packIndex]
	if stillShort(pack.gems) then
		ui.status.Text = notEnoughText(pack.gems)
		renderTrail()
		return
	end
	if not askToSpend("Hearts" .. packIndex, pack.gems) then
		b.Text = string.format("Spend %d 💎?", pack.gems)
		return
	end
	local result = invoke("BuyHearts", packIndex)
	if result.error then
		noteShort(pack.gems, result.error)
		renderTrail()
		ui.status.Text = if result.error == "not enough Gems" then notEnoughText(pack.gems) else "Couldn't get hearts: " .. tostring(result.error)
		return
	end
	setProgress(result)
	ui.status.Text = ""
	renderTrail()
end

-- Heart packs that fit in the empty slots (the Township-style refill: only when empty), at the top of the list.
local function addHeartShop()
	local hearts = progress and progress.hearts
	if not (progress and progress.canBuy and hearts) or (hearts.unlimitedSeconds or 0) > 0 then
		return
	end
	local missing = hearts.max - hearts.count
	local fits = false
	for _, pack in Hearts.Packs do
		fits = fits or pack.count <= missing
	end
	if not fits then
		return
	end
	local row = Instance.new("Frame")
	row.Name = "GetHearts"
	row.LayoutOrder = 0
	row.Size = UDim2.new(1, -10, 0, 52)
	row.BackgroundTransparency = 1
	row.Parent = ui.list
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0.02, 0)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row
	for i, pack in Hearts.Packs do
		if pack.count <= missing then
			local width = math.min(0.6, 0.98 / #Hearts.Packs - 0.02)
			local b = button(row, "Pack" .. i, string.format("+%d ❤️ for %d 💎", pack.count, pack.gems), UDim2.fromScale(width, 1), UDim2.new())
			b.LayoutOrder = i
			b.BackgroundColor3 = if canAfford(pack.gems) then Color3.fromRGB(214, 72, 92) else Colors.locked
			b.Activated:Connect(function()
				buyHearts(i, b)
			end)
		end
	end
end

renderTrail = function()
	for _, child in ui.list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	ui.heartsLine.Text = heartsText()
	addHeartShop()
	local highest = progress and progress.highestBeaten or 0
	local unlockAll = progress and progress.unlockAll and not devLocked
	for _, level in Levels.List do
		-- Show a few locked levels ahead, not the whole trail.
		if not unlockAll and level.id > highest + 1 + LOCKED_AHEAD then
			local more = label(ui.list, "MoreAhead", string.format("🔒 %d more levels ahead", #Levels.List - level.id + 1), UDim2.new(1, -10, 0, 40), UDim2.new())
			more.LayoutOrder = level.id
			break
		end
		local unlocked = unlockAll or level.id <= highest + 1
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
				showPreLevel(level.id)
			end)
		end
	end
	-- Scroll so the next level to play is in view.
	ui.list.CanvasPosition = Vector2.new(0, math.max(0, (highest - 2) * ROW_STEP))
end

-- Ticks the hearts countdown once a second while the Trail is showing, and
-- asks the server again when a heart is due.
local tickerRunning = false
local function startHeartsTicker()
	if tickerRunning then
		return
	end
	tickerRunning = true
	local function tick()
		if not (ui.gui.Enabled and ui.select.Visible) then
			tickerRunning = false
			return
		end
		local hearts = progress and progress.hearts
		local unlimited = hearts and (hearts.unlimitedSeconds or 0) > 0 and hearts.unlimitedSeconds or nil
		local nextIn = hearts and (since(hearts.secondsToNext) or since(unlimited))
		if nextIn and nextIn <= 0 then
			fetchProgress()
			renderTrail()
		else
			ui.heartsLine.Text = heartsText()
		end
		task.delay(1, tick)
	end
	task.delay(1, tick)
end

-- The pre-level panel ----------------------------------------------------------------

local function renderPreLevel()
	local stock = progress and progress.boosters or {}
	local canBuy = progress and progress.canBuy
	for _, kind in Boosters.PreLevel do
		local b = ui.preButtons[kind]
		local info = Boosters.Info[kind]
		local have = stock[kind] or 0
		local picked = ui.preSelected[kind] == true
		b.BackgroundColor3 = if picked then Colors.accent else Colors.option
		b.TextColor3 = if picked then Color3.new(1, 1, 1) else Colors.text
		if ui.pendingSpend == kind then
			b.Text = string.format("%s  Spend %d 💎 on a %s?", Glyphs[kind], info.gems, info.name)
		elseif picked then
			b.Text = string.format("%s  %s  ✅", Glyphs[kind], info.name)
		elseif have > 0 then
			b.Text = string.format("%s  %s  x%d", Glyphs[kind], info.name, have)
		elseif canBuy and canAfford(info.gems) then
			b.Text = string.format("%s  %s  %d 💎", Glyphs[kind], info.name, info.gems)
		elseif canBuy then
			b.Text = string.format("%s  %s  %d 💎 (not enough 💎)", Glyphs[kind], info.name, info.gems)
			b.BackgroundColor3 = Colors.locked
		else
			b.Text = string.format("%s  %s  (none left)", Glyphs[kind], info.name)
		end
	end
end

local function onPreBooster(kind: string)
	if ui.preSelected[kind] then
		ui.preSelected[kind] = nil
	elseif ((progress and progress.boosters[kind]) or 0) > 0 then
		ui.preSelected[kind] = true
		ui.pendingSpend = nil
	elseif progress and progress.canBuy then
		local gems = Boosters.Info[kind].gems
		if stillShort(gems) then
			ui.preBody.Text = notEnoughText(gems)
		elseif askToSpend(kind, gems) then
			local result = invoke("BuyBooster", kind)
			if result.error then
				noteShort(gems, result.error)
				ui.preBody.Text = if result.error == "not enough Gems" then notEnoughText(gems) else "Couldn't buy it: " .. tostring(result.error)
			else
				setProgress(result)
				ui.preSelected[kind] = true
			end
		end
	end
	renderPreLevel()
end

showPreLevel = function(levelId: number)
	local level = Levels.get(levelId)
	if not level then
		return
	end
	hidePanel()
	clearRun()
	if not progress then
		fetchProgress()
	end
	ui.pendingSpend = nil
	ui.preLevelId = levelId
	ui.preSelected = {}
	ui.preTitle.Text = level.id .. ". " .. level.name
	local free = progress and progress.hotStreakPowers or {}
	ui.preBody.Text = if #free > 0
		then string.format("🔥 Hot Streak %d: free %s this level!", streak(), streakGlyphs(free))
		else "Pick boosters for a strong start"
	ui.play.Visible = false
	ui.select.Visible = false
	renderPreLevel()
	Motion.popIn(ui.preLevel)
	ui.preLevel.Visible = true
end

-- Playing ----------------------------------------------------------------------------

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
	local text = table.concat(parts, "   ")
	if rewards.bonusCoins and rewards.bonusCoins > 0 then
		text ..= "\n(" .. rewards.bonusCoins .. " bonus Coins from leftover moves)"
	end
	return text
end

local function finishRun(run)
	local status = run.game.status
	busy = true -- no taps while the server checks
	local result = invoke("FinishLevel", run.token, run.moves)
	busy = false
	setProgress(result.progress)
	if current ~= run then
		return -- the player left while the server was checking
	end
	if status == "Won" then
		if result.error then
			showPanel("Hmm, that didn't check out", "The server couldn't confirm this win (" .. tostring(result.error) .. ").", "Try again", function()
				showPreLevel(run.levelId)
			end, "Trail", showLevelSelect)
			return
		end
		local nextLevel = Levels.get(run.levelId + 1)
		local body = rewardText(result.rewards)
		if streak() >= 2 then
			body ..= string.format("\n🔥 Hot Streak: %d wins in a row!", streak())
		end
		showPanel(
			"Level complete!",
			body,
			if nextLevel then "Next level" else "Trail",
			function()
				if nextLevel then
					showPreLevel(nextLevel.id)
				else
					showLevelSelect()
				end
			end,
			"Trail",
			showLevelSelect
		)
	else
		local done, total = 0, 0
		for _, goal in run.game.goals.list do
			done += math.min(goal.progress, goal.target)
			total += goal.target
		end
		Sfx.event("Lose")
		local body = if total > 0 and done / total >= 0.75 then "So close! Give it another go." else "Give it another go!"
		if (result.lostStreak or 0) > 0 then
			body = string.format("Your Hot Streak of %d is over. ", result.lostStreak) .. body
		end
		showPanel("Level failed", body, "Retry", function()
			showPreLevel(run.levelId)
		end, "Trail", showLevelSelect)
	end
end

local POWER_NAMES = { Sprayer = "Seed Sprayer", HayBomb = "Hay Bomb", Sunflower = "Sunflower", Bumblebee = "Bumblebee" }

local offerContinue -- forward declarations
local refreshBoosters

local function buyContinue(run, count: number, step)
	if not askToSpend("Continue" .. count, step.gems) then
		ui.primary.Text = string.format("Spend %d 💎?", step.gems)
		return
	end
	local result = invoke("BuyContinue", run.token, run.moves)
	if current ~= run then
		return
	end
	if result.error then
		if result.error == "not enough Gems" then
			noteShort(step.gems, result.error)
			offerContinue(run)
		else
			ui.panelBody.Text = "Couldn't get more moves: " .. tostring(result.error)
		end
		return
	end
	setProgress(result.progress)
	local ok, phases = run.game:continue()
	if not ok then
		return
	end
	table.insert(run.moves, { "Continue" })
	Sfx.event("MoreMoves")
	hidePanel()
	run.view:setEnabled(true)
	busy = true
	task.spawn(function()
		run.view:play(phases)
		if current == run then
			run.view:sync(run.game)
			refreshHud()
			refreshBoosters()
		end
		busy = false
	end)
end

-- Out of moves: offer +5 moves for Gems, at the price on the button. A calm
-- choice with no countdown (F06 continue rules); "Give up" ends the level.
offerContinue = function(run)
	local count = run.game.continues + 1
	local step = Boosters.continueStep(count)
	local moves = Boosters.Continue.MOVES
	local body = string.format("Keep going with %d more moves?", moves)
	if streak() > 0 then
		body ..= "\nGiving up ends your Hot Streak."
	end
	if step.power then
		body ..= "\nComes with a " .. (POWER_NAMES[step.power] or step.power) .. "!"
	end
	if not canAfford(step.gems) then
		-- Tapping the greyed button checks the balance again (Gems bought meanwhile).
		showPanel("Out of moves", body .. "\n" .. notEnoughText(step.gems), "Not enough 💎", function()
			stillShort(step.gems)
			offerContinue(run)
		end, "Give up", function()
			finishRun(run)
		end)
		ui.primary.BackgroundColor3 = Colors.locked
		return
	end
	showPanel("Out of moves", body, string.format("+%d moves  %d 💎", moves, step.gems), function()
		buyContinue(run, count, step)
	end, "Give up", function()
		finishRun(run)
	end)
end

-- A level editor test: nothing goes to the server.
local function endTest(run)
	local test = run.test
	local won = run.game.status == "Won"
	showPanel(if won then "Test won!" else "Test lost", string.format("%d %s used.", run.game.movesMade, if run.game.movesMade == 1 then "move" else "moves"), "Play again", function()
		PuzzleScreen.playTest(test.level, test.onDone)
	end, "Editor", function()
		PuzzleScreen.close()
		test.onDone()
	end)
end

local function onLevelEnded()
	local run = current
	run.view:setEnabled(false)
	if run.test then
		endTest(run)
		return
	end
	local canContinue = progress and progress.canBuy and run.game.continues < Boosters.Continue.MAX_PER_RUN
	if run.game.status == "Won" then
		Sfx.event("Win") -- right away; the server's check comes after
	end
	if run.game.status == "Lost" and canContinue then
		offerContinue(run)
	else
		finishRun(run)
	end
end


refreshBoosters = function()
	local run = current
	if not run then
		return
	end
	local canBuy = progress and progress.canBuy
	for _, kind in Boosters.InLevel do
		local b = ui.boosterButtons[kind]
		local have = run.stock[kind] or 0
		b.BackgroundColor3 = if run.armed == kind then Colors.accent else Colors.panel
		local count = b:FindFirstChild("Count") :: TextLabel
		count.Text = if have > 0 then tostring(have) elseif canBuy then "+" else "0"
	end
	ui.hint.Text = run.hint or ""
	ui.hint.Visible = run.hint ~= nil
end

local function disarm(run)
	run.armed = nil
	run.hint = nil
	run.view:setCellTarget(nil)
end

-- Plays one action: a swap { x1, y1, x2, y2 } or a booster { "Trowel", x, y } etc.
local function doAction(run, action: { any })
	if busy or current ~= run or run.game.status ~= "Playing" then
		return
	end
	busy = true
	ui.pendingSpend = nil
	task.spawn(function()
		local ok, phases = run.game:apply(action)
		if ok then
			table.insert(run.moves, action)
			local kind = action[1]
			if type(kind) == "string" then
				run.stock[kind] -= 1
				disarm(run)
			end
			ui.movesCount.Text = tostring(run.game.movesLeft)
		end
		refreshBoosters()
		run.view:play(phases)
		if current == run then
			run.view:sync(run.game)
			refreshHud()
		end
		busy = false
		if current == run and run.game.status ~= "Playing" then
			disarm(run)
			refreshBoosters()
			onLevelEnded()
		end
	end)
end

local function onSwap(x1: number, y1: number, x2: number, y2: number)
	local run = current
	if not run then
		return
	end
	if run.armed == "GardenGloves" then
		doAction(run, { "GardenGloves", x1, y1, x2, y2 })
	else
		doAction(run, { x1, y1, x2, y2 })
	end
end

local function onBooster(kind: string)
	local run = current
	if busy or not run or run.game.status ~= "Playing" then
		return
	end
	local info = Boosters.Info[kind]
	if run.armed == kind then
		disarm(run) -- a second tap puts it away
		refreshBoosters()
		return
	end
	disarm(run)
	if (run.stock[kind] or 0) <= 0 then
		if not (progress and progress.canBuy) then
			run.hint = "No " .. info.name .. " left."
			refreshBoosters()
			return
		end
		if stillShort(info.gems) then
			run.hint = "No " .. info.name .. " left. " .. notEnoughText(info.gems)
			refreshBoosters()
			return
		end
		if not askToSpend(kind, info.gems) then
			run.hint = string.format("Spend %d 💎 on a %s? Tap %s again to buy.", info.gems, info.name, Glyphs[kind])
			refreshBoosters()
			return
		end
		local result = invoke("BuyBooster", kind)
		if current ~= run then
			return
		end
		if result.error then
			noteShort(info.gems, result.error)
			run.hint = if result.error == "not enough Gems" then "No " .. info.name .. " left. " .. notEnoughText(info.gems) else "Couldn't buy it: " .. tostring(result.error)
			refreshBoosters()
			return
		end
		setProgress(result)
		run.stock[kind] = (run.stock[kind] or 0) + 1
	end
	ui.pendingSpend = nil
	if kind == "ShakeUp" then
		doAction(run, { "ShakeUp" })
		return
	end
	run.armed = kind
	run.hint = BOOSTER_HINTS[kind] .. " Tap " .. Glyphs[kind] .. " again to put it away."
	if kind == "Trowel" then
		run.view:setCellTarget(function(x, y)
			doAction(run, { "Trowel", x, y })
		end)
	elseif kind == "Rake" then
		run.view:setCellTarget(function(_, y)
			doAction(run, { "Rake", y })
		end)
	end
	refreshBoosters()
end

-- Flow -------------------------------------------------------------------------

startLevel = function(levelId: number, preBoosters: { string }?)
	hidePanel()
	ui.preLevel.Visible = false
	local level = Levels.get(levelId)
	if not level then
		return
	end
	local run = invoke("StartLevel", levelId, preBoosters or {})
	if run.error then
		if run.error == "no hearts" then
			showLevelSelect("Out of hearts! One comes back every 30 minutes.")
		else
			showLevelSelect("Couldn't start: " .. tostring(run.error))
		end
		return
	end
	setProgress(run.progress)
	beginRun(level, run.seed, run.startPowerUps, {
		token = run.token,
		stock = table.clone(progress and progress.boosters or {}),
	})
end

-- Builds the board for a run. `extra` adds the run's own fields (token or test).
beginRun = function(level, seed: number, startPowerUps: { string }?, extra)
	hidePanel()
	ui.preLevel.Visible = false
	clearRun()
	local pop = CropPop.Engine.new(level, seed, { startPowerUps = startPowerUps })
	local view = BoardView.new(ui.boardHolder, onSwap)
	current = {
		levelId = level.id,
		game = pop,
		view = view,
		moves = {}, -- swaps and booster uses, in order, for the server's replay
		stock = {},
	}
	for k, v in extra do
		current[k] = v
	end
	view:load(pop)
	ui.levelName.Text = (if current.test then "Test: " else level.id .. ". ") .. level.name
	ui.difficulty.Text = if level.difficulty == "Normal" then "" else level.difficulty
	refreshHud()
	refreshBoosters()
	ui.select.Visible = false
	ui.play.Visible = true
end

showLevelSelect = function(message: string?)
	hidePanel()
	clearRun()
	ui.pendingSpend = nil
	ui.play.Visible = false
	ui.preLevel.Visible = false
	ui.select.Visible = true
	ui.status.Text = message or ""
	fetchProgress()
	renderTrail()
	startHeartsTicker()
end

local function ensureUi()
	if ui then
		return
	end
	ui = buildUi()
	applyLayout()
	ui.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
	if ui.devOneMove then
		ui.devOneMove.Activated:Connect(function()
			PuzzleScreen.debugOneMoveLeft()
		end)
		ui.devNoHearts.Activated:Connect(function()
			PuzzleScreen.debugEmptyHearts()
		end)
		ui.devEditor.Activated:Connect(function()
			if PuzzleScreen.onDevEditor then
				PuzzleScreen.onDevEditor()
			end
		end)
		ui.devLock.Activated:Connect(function()
			devLocked = not devLocked
			ui.devLock.Text = if devLocked then "Dev 🔓" else "Dev 🔒"
			renderTrail()
		end)
		-- Same thing from the keyboard: L.
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not gameProcessed and input.KeyCode == Enum.KeyCode.L and PuzzleScreen.isOpen() then
				PuzzleScreen.debugOneMoveLeft()
			elseif not gameProcessed and input.KeyCode == Enum.KeyCode.H and PuzzleScreen.isOpen() then
				PuzzleScreen.debugEmptyHearts()
			end
		end)
	end
	ui.closePlay.Activated:Connect(function()
		PuzzleScreen.leaveLevel()
	end)
	ui.closeSelect.Activated:Connect(function()
		PuzzleScreen.close()
	end)
	for kind, b in ui.preButtons do
		b.Activated:Connect(function()
			onPreBooster(kind)
		end)
	end
	ui.prePlay.Activated:Connect(function()
		local picked = {}
		for _, kind in Boosters.PreLevel do
			if ui.preSelected[kind] then
				table.insert(picked, kind)
			end
		end
		startLevel(ui.preLevelId, picked)
	end)
	ui.preBack.Activated:Connect(function()
		showLevelSelect()
	end)
	for kind, b in ui.boosterButtons do
		b.Activated:Connect(function()
			onBooster(kind)
		end)
	end
	ui.primary.Activated:Connect(function()
		if not panelReady() then
			return
		end
		local action = ui.panelActions.primary
		if action then
			action()
		end
	end)
	ui.secondary.Activated:Connect(function()
		if not panelReady() then
			return
		end
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
	Sfx.event("Open")
	if levelId then
		showPreLevel(levelId)
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
	ui.preLevel.Visible = false
	ui.gui.Enabled = false
	Sfx.event("Close")
end

-- The top bar's X: mid-level, ask first, since leaving costs the heart (and
-- any Hot Streak). After the level, or while a panel is up, just leave.
function PuzzleScreen.leaveLevel()
	local run = current
	if run and run.test then
		local onDone = run.test.onDone
		PuzzleScreen.close()
		onDone()
		return
	end
	if not run or run.game.status ~= "Playing" or busy or ui.panel.Visible then
		showLevelSelect()
		return
	end
	run.view:setEnabled(false)
	local body = if streak() > 0 then "You'll lose this heart and your Hot Streak." else "You'll lose this heart."
	showPanel("Leave this level?", body, "Keep playing", function()
		hidePanel()
		if current == run then
			run.view:setEnabled(true)
		end
	end, "Leave", showLevelSelect)
end

--[[
	Studio level editor: play `level` (not in Levels.List) offline with a
	random seed and plenty of boosters. Nothing is sent to the server, so no
	hearts, rewards or streak. `onDone` runs when the player goes back.
]]
function PuzzleScreen.playTest(level, onDone: () -> ())
	ensureUi()
	ui.gui.Enabled = true
	local stock = {}
	for _, kind in Boosters.InLevel do
		stock[kind] = 9
	end
	beginRun(level, Random.new():NextInteger(1, 2 ^ 31 - 1), nil, { test = { level = level, onDone = onDone }, stock = stock })
end

-- Studio only: set by Main to open the level editor (the editor needs this
-- module, so it can't be required from here).
PuzzleScreen.onDevEditor = nil :: (() -> ())?

function PuzzleScreen.isOpen(): boolean
	return ui ~= nil and ui.gui.Enabled
end

-- Studio only: set hearts to 0 so the refill offer shows (also the H key).
function PuzzleScreen.debugEmptyHearts()
	if not RunService:IsStudio() or current then
		return
	end
	local result = invoke("DevEmptyHearts")
	if not result.error then
		setProgress(result)
	end
	if ui.select.Visible then
		renderTrail()
	end
end

-- Studio only: leave the current level on its last move. The next swap ends
-- it like a real loss (unless that swap wins). It goes in the action list so
-- the server's replay (which accepts it in Studio only) runs out too, and a
-- continue can be bought.
function PuzzleScreen.debugOneMoveLeft()
	if not RunService:IsStudio() or not current or current.game.status ~= "Playing" or busy then
		return
	end
	if current.game:apply({ "DevOneMove" }) then
		table.insert(current.moves, { "DevOneMove" })
	end
	refreshHud()
end

-- The level being played, for debugging and tests.
function PuzzleScreen.currentRun()
	return current
end


return PuzzleScreen
