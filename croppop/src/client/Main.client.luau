--[[
	Crop Pop client entry. Adds a temporary "Crop Pop" button until the Puzzle
	Porch and the Town Square cabinet open the screen from the 3D world.
]]

local Players = game:GetService("Players")

local PuzzleScreen = require(script.Parent.PuzzleScreen)
local TileStyle = require(script.Parent.TileStyle)

local launcher = Instance.new("ScreenGui")
launcher.Name = "CropPopLauncher"
launcher.ResetOnSpawn = false

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
openButton.Parent = launcher

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0.3, 0)
buttonCorner.Parent = openButton

openButton.Activated:Connect(function()
	if PuzzleScreen.isOpen() then
		PuzzleScreen.close()
	else
		PuzzleScreen.open()
	end
end)

launcher.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
