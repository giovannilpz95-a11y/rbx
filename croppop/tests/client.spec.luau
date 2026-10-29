-- Smoke test of the server script and the client screens against a mock Roblox API.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy

local Mock = loadmodule(readfile(Harness.root .. "/tests/roblox_mock.luau"), "tests/roblox_mock.luau", setmetatable({}, { __index = _G }))()
local mockEnv, services = Mock.environment(game)
-- Each read of the server clock moves time on, so the start rate limit never trips.
local fakeNow = 0
local fakeTime = 1_800_000_000 -- os.time(), moved on by passTime()
mockEnv.os = setmetatable({
	clock = function()
		fakeNow += 5
		return fakeNow
	end,
	time = function()
		return fakeTime
	end,
}, { __index = os })

-- Lets the Hearts timer run; 3 hours refills every heart.
local function passTime(seconds)
	fakeTime += seconds
end
local function refillHearts()
	passTime(3 * 60 * 60)
end
local mockRequire, runScript = Harness.makeRequire(mockEnv)

local Matcher = CropPop.Matcher

-- Server first: it creates the remotes the client waits for.
local wins = {}
runScript(game.ServerScriptService.CropPopServer.CropPopService)
Mock.runDelayed() -- no farm save in this test: the server falls back to a fresh state
services.ServerStorage.CropPopLevelWon.Event:Connect(function(player, levelId, rewards, firstWin)
	table.insert(wins, { player = player, levelId = levelId, rewards = rewards, firstWin = firstWin })
end)

local clientFolder = game.StarterPlayerScripts.CropPopClient
runScript(clientFolder.Main)
local PuzzleScreen = mockRequire(clientFolder.PuzzleScreen)
local BoardView = mockRequire(clientFolder.BoardView)
local playerGui = Mock.localPlayer.PlayerGui

local mouse = Mock.Enum.UserInputType.MouseButton1
local movement = Mock.Enum.UserInputType.MouseMovement

local function findHit(view, x, y)
	local want = view:_cellPosition(x, y)
	for _, button in view.hitLayer:GetChildren() do
		if button.Position == want then
			return button
		end
	end
	error("no hit button at " .. x .. "," .. y)
end

local function swipe(view, x1, y1, x2, y2)
	local start = Mock.Vector3.new(200, 200, 0)
	findHit(view, x1, y1).InputBegan:Fire({ UserInputType = mouse, Position = start })
	services.UserInputService.InputChanged:Fire({
		UserInputType = movement,
		Position = start + Mock.Vector3.new((x2 - x1) * 60, (y2 - y1) * 60, 0),
	})
end

local function tap(view, x, y)
	local input = { UserInputType = mouse, Position = Mock.Vector3.new(10, 10, 0) }
	findHit(view, x, y).InputBegan:Fire(input)
	services.UserInputService.InputEnded:Fire(input)
end

-- Checks, before sync() tidies up, that the animated tiles already match the engine.
local mismatches = 0
local originalSync = BoardView.sync
BoardView.sync = function(view, pop)
	local visible = 0
	for _ in view.tiles do
		visible += 1
	end
	local pieces = 0
	pop.board:eachCell(function(cell)
		if cell.piece then
			pieces += 1
			local tile = view.tiles[cell.piece.id]
			if not tile or tile.Position ~= view:_cellPosition(cell.x, cell.y) then
				mismatches += 1
			end
		end
	end)
	if visible ~= pieces then
		mismatches += 1
	end
	return originalSync(view, pop)
end

-- Opens a level's booster picker, picks `boosters`, and presses Play.
local function pressPlay(boosters)
	local pre = playerGui.CropPop.Backdrop.PreLevel
	truthy(pre.Visible, "the booster picker is showing")
	for _, kind in boosters or {} do
		pre[kind].Activated:Fire()
	end
	pre.Play.Activated:Fire()
	return PuzzleScreen.currentRun()
end

local function playLevel(levelId, boosters)
	refillHearts()
	PuzzleScreen.open(levelId)
	return pressPlay(boosters)
end

local function playToEnd(maxMoves, useTaps)
	local run = PuzzleScreen.currentRun()
	for i = 1, maxMoves do
		if run.game.status ~= "Playing" then
			break
		end
		local options = Matcher.listPossibleMoves(run.game.board)
		local m = options[(i * 7) % #options + 1]
		if useTaps and i % 2 == 0 then
			tap(run.view, m[1], m[2])
			tap(run.view, m[3], m[4])
		else
			swipe(run.view, m[1], m[2], m[3], m[4])
		end
	end
	return run
end

test("the launcher opens the Crop Pop Trail", function()
	local launcher = playerGui.CropPopLauncher
	refillHearts()
	launcher.Open.Activated:Fire()
	truthy(PuzzleScreen.isOpen())
	local screen = playerGui.CropPop
	truthy(screen.Backdrop.LevelSelect.Visible)
	truthy(screen.Backdrop.LevelSelect.List.Level1, "level 1 button")
	truthy(screen.Backdrop.LevelSelect.List.Level5, "level 5 button")
end)

test("picking a level opens the booster picker, then Play draws the board", function()
	playerGui.CropPop.Backdrop.LevelSelect.List.Level1.Activated:Fire()
	eq(PuzzleScreen.currentRun(), nil, "no run before Play")
	local run = pressPlay()
	truthy(run, "a run started")
	eq(run.levelId, 1)
	local tiles = 0
	for _ in run.view.tiles do
		tiles += 1
	end
	eq(tiles, 49)
	eq(playerGui.CropPop.Backdrop.Play.TopBar.Moves.Count.Text, "18")
end)

test("swipes and taps play moves, and the tiles stay in step with the engine", function()
	local run = PuzzleScreen.currentRun()
	playToEnd(3, true)
	eq(#run.moves, 3)
	eq(run.game.movesLeft, 15)
	eq(playerGui.CropPop.Backdrop.Play.TopBar.Moves.Count.Text, "15")
	eq(mismatches, 0, "tiles out of step before sync")
end)

test("a whole level plays to the end and the server checks it", function()
	local run = playToEnd(200, true)
	truthy(run.game.status ~= "Playing")
	eq(mismatches, 0, "tiles out of step before sync")
	local panel = playerGui.CropPop.Backdrop.EndPanel
	truthy(panel.Visible)
	if run.game.status == "Won" then
		eq(panel.Title.Text, "Level complete!")
		eq(#wins, 1)
		eq(wins[1].levelId, 1)
		eq(wins[1].player, Mock.localPlayer)
	else
		eq(panel.Title.Text, "Out of moves")
	end
end)

test("the Studio 1-move button leads to the out-of-moves panel and Retry", function()
	local run = playLevel(1)
	local backdrop = playerGui.CropPop.Backdrop
	backdrop.Play.TopBar.DevOneMove.Activated:Fire()
	eq(backdrop.Play.TopBar.Moves.Count.Text, "1")
	local m = Matcher.listPossibleMoves(run.game.board)[1]
	swipe(run.view, m[1], m[2], m[3], m[4])
	eq(run.game.status, "Lost")
	truthy(backdrop.EndPanel.Visible)
	eq(backdrop.EndPanel.Title.Text, "Out of moves")
	backdrop.EndPanel.Primary.Activated:Fire()
	local retry = pressPlay()
	truthy(retry and retry ~= run, "retry started a new run")
	eq(retry.levelId, 1)
	eq(backdrop.EndPanel.Visible, false)
end)

test("every test level can be played through the screen", function()
	for levelId = 1, 5 do
		playLevel(levelId)
		truthy(PuzzleScreen.currentRun(), "level " .. levelId .. " started: " .. playerGui.CropPop.Backdrop.LevelSelect.Status.Text)
		local run = playToEnd(200, levelId % 2 == 0)
		truthy(run.game.status ~= "Playing", "level " .. levelId .. " ended")
		truthy(playerGui.CropPop.Backdrop.EndPanel.Visible)
	end
	eq(mismatches, 0, "tiles out of step before sync")
	print(string.format("    %d of the screen runs were wins the server accepted", #wins))
end)

test("wide screens move the top bar to a side panel next to the board", function()
	playLevel(1)
	local screen = playerGui.CropPop
	local play = screen.Backdrop.Play
	local function resize(x, y)
		screen.AbsoluteSize = { X = x, Y = y }
		screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	end

	resize(1668, 878)
	local bar, holder = play.TopBar, play.BoardHolder
	eq(bar.Size.X.Offset, 340, "panel width is capped")
	eq(holder.Position.X.Offset, 12 + 340 + 12, "board area starts right after the panel")
	eq(holder.Position.X.Offset + holder.Size.X.Offset, 1668 - 12, "and runs to the right margin")
	eq(holder.Position.Y.Offset, bar.Position.Y.Offset, "board top lines up with the panel top")

	resize(844, 390)
	eq(bar.Size.Y.Offset, 390 - 64 - 12)
	truthy(holder.Size.Y.Offset >= 300, "landscape phone keeps the full height for the board")

	resize(390, 844)
	eq(bar.Size.X.Offset, 390 * 0.96, "portrait: bar across the top")
	eq(holder.Position.Y.Offset, 64 + 844 * 0.12 + 8, "board area starts under the bar")
	local boosters = play.Boosters
	eq(boosters.Size.Y.Offset, 64, "booster bar under the board")
	eq(holder.Position.Y.Offset + holder.Size.Y.Offset, 844 - 8 - 64 - 8)
	eq(boosters.Position.Y.Offset, 844 - 8 - 64)

	resize(1668, 878)
	truthy(boosters.Position.X.Offset < holder.Position.X.Offset, "boosters move into the side panel")
end)

test("the out-of-moves message depends on how close the player got", function()
	local run = playLevel(1)
	playerGui.CropPop.Backdrop.Play.TopBar.DevOneMove.Activated:Fire()
	local m = Matcher.listPossibleMoves(run.game.board)[1]
	swipe(run.view, m[1], m[2], m[3], m[4])
	eq(run.game.status, "Lost")
	eq(playerGui.CropPop.Backdrop.EndPanel.Body.Text, "Give it another go!")
end)

-- Hearts and boosters ------------------------------------------------------------

local remotes = services.ReplicatedStorage.CropPopRemotes
local function serverProgress()
	return remotes.GetProgress:InvokeServer()
end

local function countPowers(pop, power)
	local n = 0
	pop.board:eachCell(function(cell)
		if cell.piece and cell.piece.power == power then
			n += 1
		end
	end)
	return n
end

local function hasTile(view, x, y)
	return view.grid[y] and view.grid[y][x] ~= nil
end

test("the Trail shows hearts and the countdown after a loss", function()
	refillHearts()
	PuzzleScreen.open()
	local select = playerGui.CropPop.Backdrop.LevelSelect
	eq(select.Hearts.Text, "❤️ 5/5")
	eq(select.List:FindFirstChild("GetHearts"), nil, "no heart shop with full hearts")
	PuzzleScreen.open(1)
	local run = pressPlay()
	playerGui.CropPop.Backdrop.Play.TopBar.DevOneMove.Activated:Fire()
	local m = Matcher.listPossibleMoves(run.game.board)[1]
	swipe(run.view, m[1], m[2], m[3], m[4])
	eq(run.game.status, "Lost")
	playerGui.CropPop.Backdrop.EndPanel.Secondary.Activated:Fire() -- Trail
	truthy(select.Visible)
	-- The mock clock jumps a few seconds per read, so only the start is fixed.
	truthy(string.find(select.Hearts.Text, "❤️ 4/5   next in 29:", 1, true), select.Hearts.Text)
	truthy(select.List:FindFirstChild("GetHearts"), "heart shop when one is missing")
	truthy(select.List.GetHearts:FindFirstChild("Pack1"))
	eq(select.List.GetHearts:FindFirstChild("Pack2"), nil, "only packs that fit")
end)

test("running out of hearts sends the player back to the Trail", function()
	refillHearts()
	for _ = 1, 5 do
		PuzzleScreen.open(1)
		local run = pressPlay()
		truthy(run)
		PuzzleScreen.open() -- leaving a level keeps the heart spent
	end
	PuzzleScreen.open(1)
	eq(pressPlay(), nil)
	local select = playerGui.CropPop.Backdrop.LevelSelect
	truthy(select.Visible)
	truthy(string.find(select.Status.Text, "Out of hearts"))
	truthy(string.find(select.Hearts.Text, "❤️ 0/5   next in 2", 1, true), select.Hearts.Text)
end)

test("a pre-level booster goes on the board and is taken from stock", function()
	local before = serverProgress().boosters.BombStart
	refillHearts()
	PuzzleScreen.open(2)
	local pre = playerGui.CropPop.Backdrop.PreLevel
	truthy(string.find(pre.BombStart.Text, "x" .. before))
	pre.BombStart.Activated:Fire()
	truthy(string.find(pre.BombStart.Text, "✅"))
	pre.BombStart.Activated:Fire()
	falsy(string.find(pre.BombStart.Text, "✅"), "a second tap unpicks it")
	local run = pressPlay({ "BombStart" })
	eq(countPowers(run.game, "HayBomb"), 1)
	eq(serverProgress().boosters.BombStart, before - 1)
end)

test("in-level boosters arm, act on a tap and are recorded for the replay", function()
	local run = playLevel(1)
	local bar = playerGui.CropPop.Backdrop.Play.Boosters
	local hint = playerGui.CropPop.Backdrop.Play.BoosterHint
	local trowels = run.stock.Trowel
	eq(bar.Trowel.Count.Text, tostring(trowels))

	bar.Trowel.Activated:Fire()
	truthy(hint.Visible)
	truthy(string.find(hint.Text, "break"))
	bar.Trowel.Activated:Fire()
	falsy(hint.Visible, "a second tap puts it away")

	bar.Trowel.Activated:Fire()
	tap(run.view, 4, 4)
	eq(run.moves[#run.moves][1], "Trowel")
	eq(run.stock.Trowel, trowels - 1)
	eq(bar.Trowel.Count.Text, tostring(trowels - 1))
	eq(run.game.movesLeft, 18, "boosters don't cost moves")
	falsy(hint.Visible)

	bar.Rake.Activated:Fire()
	tap(run.view, 2, 6)
	eq(run.moves[#run.moves][1], "Rake")
	eq(run.moves[#run.moves][2], 6)

	bar.ShakeUp.Activated:Fire()
	eq(run.moves[#run.moves][1], "ShakeUp")

	-- Gloves: any neighbouring pair, even one that makes no match.
	bar.GardenGloves.Activated:Fire()
	local x1, y1, x2, y2
	for y = 1, run.game.board.height do
		for x = 1, run.game.board.width - 1 do
			if not x1 and hasTile(run.view, x, y) and hasTile(run.view, x + 1, y) and not run.game.board:get(x, y).piece.power then
				x1, y1, x2, y2 = x, y, x + 1, y
			end
		end
	end
	swipe(run.view, x1, y1, x2, y2)
	local last = run.moves[#run.moves]
	eq(last[1], "GardenGloves")
	eq(#run.moves, 4)
	eq(mismatches, 0, "tiles out of step before sync")

	-- The server replays it all and charges the boosters used.
	local stockBefore = serverProgress().boosters
	playToEnd(200, false)
	truthy(playerGui.CropPop.Backdrop.EndPanel.Visible)
	falsy(playerGui.CropPop.Backdrop.EndPanel.Title.Text == "Hmm, that didn't check out")
	local stockAfter = serverProgress().boosters
	for _, kind in { "Trowel", "Rake", "ShakeUp", "GardenGloves" } do
		eq(stockAfter[kind], stockBefore[kind] - 1, kind .. " charged by the server")
	end
end)

test("an empty booster asks before spending Gems, then buys on the second tap", function()
	local wallet = 100
	local spend = Mock.newInstance("BindableFunction", { Name = "CropPopSpendGems" })
	spend.OnInvoke = function(_, amount)
		if amount > wallet then
			return false
		end
		wallet -= amount
		return true
	end
	spend.Parent = services.ServerStorage

	local run = playLevel(1)
	run.stock.Trowel = 0 -- as if they were all used
	local bar = playerGui.CropPop.Backdrop.Play.Boosters
	local hint = playerGui.CropPop.Backdrop.Play.BoosterHint
	bar.Trowel.Activated:Fire()
	truthy(string.find(hint.Text, "Spend 25 💎"))
	eq(wallet, 100, "nothing spent on the first tap")
	bar.Trowel.Activated:Fire()
	eq(wallet, 75)
	eq(run.stock.Trowel, 1)
	truthy(string.find(hint.Text, "break"), "bought and ready to use")
	spend.Parent = nil
end)

test("closing hides the screen", function()
	PuzzleScreen.close()
	eq(PuzzleScreen.isOpen(), false)
	eq(PuzzleScreen.currentRun(), nil)
end)
