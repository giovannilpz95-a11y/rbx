--[[
	Crop Pop client entry. The Puzzle Porch cabinet in the Town Square opens the
	screen by firing ReplicatedStorage.CropPopOpen (a client-side
	BindableEvent; whichever script runs first makes it). In Studio there is
	also a "Crop Pop" button, for testing without the farm.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LevelEditor = require(script.Parent.LevelEditor)
local PuzzleScreen = require(script.Parent.PuzzleScreen)
local TileStyle = require(script.Parent.TileStyle)

local openEvent = ReplicatedStorage:FindFirstChild("CropPopOpen")
if not openEvent then
	openEvent = Instance.new("BindableEvent")
	openEvent.Name = "CropPopOpen"
	openEvent.Parent = ReplicatedStorage
end
openEvent.Event:Connect(function()
	if not PuzzleScreen.isOpen() then
		PuzzleScreen.open()
	end
end)

if RunService:IsStudio() then
	local launcher = Instance.new("ScreenGui")
	launcher.Name = "CropPopLauncher"
	launcher.ResetOnSpawn = false
	launcher.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local openButton = Instance.new("TextButton")
	openButton.Name = "Open"
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(1, -16, 0, 16) -- top right, clear of the farm HUD
	openButton.Size = UDim2.fromOffset(150, 48)
	openButton.BackgroundColor3 = TileStyle.Board.accent
	openButton.TextColor3 = Color3.new(1, 1, 1)
	openButton.Font = TileStyle.Font
	openButton.TextScaled = true
	openButton.Text = "🍅 Crop Pop"

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0.3, 0)
	buttonCorner.Parent = openButton
	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingTop = UDim.new(0.14, 0)
	buttonPadding.PaddingBottom = UDim.new(0.14, 0)
	buttonPadding.Parent = openButton
	TileStyle.Theme.Kit.skinButton(openButton, "attention")
	openButton.Parent = launcher

	openButton.Activated:Connect(function()
		if PuzzleScreen.isOpen() then
			PuzzleScreen.close()
		else
			PuzzleScreen.open()
		end
	end)

	launcher.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Studio only: the level editor, from the Trail's "Dev: Editor" button or the F6 key.
if RunService:IsStudio() then
	local function openEditor()
		PuzzleScreen.close()
		LevelEditor.open()
	end
	PuzzleScreen.onDevEditor = openEditor
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.F6 and PuzzleScreen.isOpen() then
			openEditor()
		end
	end)
end
