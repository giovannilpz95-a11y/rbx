--[[
	Crop Pop client entry. Adds a temporary "Crop Pop" button until the Puzzle
	Porch and the Town Square cabinet open the screen from the 3D world.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LevelEditor = require(script.Parent.LevelEditor)
local PuzzleScreen = require(script.Parent.PuzzleScreen)
local TileStyle = require(script.Parent.TileStyle)

local launcher = Instance.new("ScreenGui")
launcher.Name = "CropPopLauncher"
launcher.ResetOnSpawn = false
launcher.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local openButton = Instance.new("TextButton")
openButton.Name = "Open"
openButton.AnchorPoint = Vector2.new(0, 1)
openButton.Position = UDim2.new(0, 16, 1, -16)
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
