-- Smoke test of the server script and the client screens against a mock Roblox API.

local eq, truthy = expect.eq, expect.truthy

local Mock = loadmodule(readfile(Harness.root .. "/tests/roblox_mock.luau"), "tests/roblox_mock.luau", setmetatable({}, { __index = _G }))()
local mockEnv, services = Mock.environment(game)
-- Each read of the server clock moves time on, so the start rate limit never trips.
local fakeNow = 0
mockEnv.os = setmetatable({
	clock = function()
		fakeNow += 5
		return fakeNow
	end,
}, { __index = os })
local mockRequire, runScript = Harness.makeRequire(mockEnv)

local Matcher = CropPop.Matcher

-- Server first: it creates the remotes the client waits for.
local wins = {}
runScript(game.ServerScriptService.CropPopServer.CropPopService)
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
	launcher.Open.Activated:Fire()
	truthy(PuzzleScreen.isOpen())
	local screen = playerGui.CropPop
	truthy(screen.Backdrop.LevelSelect.Visible)
	truthy(screen.Backdrop.LevelSelect.List.Level1, "level 1 button")
	truthy(screen.Backdrop.LevelSelect.List.Level5, "level 5 button")
end)

test("picking a level draws the board", function()
	playerGui.CropPop.Backdrop.LevelSelect.List.Level1.Activated:Fire()
	local run = PuzzleScreen.currentRun()
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

test("every test level can be played through the screen", function()
	for levelId = 1, 5 do
		PuzzleScreen.open(levelId)
		truthy(PuzzleScreen.currentRun(), "level " .. levelId .. " started: " .. playerGui.CropPop.Backdrop.LevelSelect.Status.Text)
		local run = playToEnd(200, levelId % 2 == 0)
		truthy(run.game.status ~= "Playing", "level " .. levelId .. " ended")
		truthy(playerGui.CropPop.Backdrop.EndPanel.Visible)
	end
	eq(mismatches, 0, "tiles out of step before sync")
	print(string.format("    %d of the screen runs were wins the server accepted", #wins))
end)

test("closing hides the screen", function()
	PuzzleScreen.close()
	eq(PuzzleScreen.isOpen(), false)
	eq(PuzzleScreen.currentRun(), nil)
end)
