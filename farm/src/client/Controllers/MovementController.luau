--!strict
-- Walk 20 / sprint 28 studs per second (Design/15 §2, first-pass). Shift or the left stick
-- click holds sprint; the HUD Sprint button toggles it on touch. No stamina bar.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local ClientStore = require(script.Parent.Parent.ClientStore)
local ReachController = require(script.Parent.ReachController)

local MovementController = {}

function MovementController.init()
	local player = Players.LocalPlayer

	ContextActionService:BindAction("FarmSprint", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			ClientStore.setSetting("sprinting", true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			ClientStore.setSetting("sprinting", false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	ClientStore.settingsChanged.Event:Connect(function(key)
		if key == "sprinting" or key == "walkSpeed" then
			ReachController.applySpeed()
		end
	end)

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		ReachController.applySpeed()
	end)
	if player.Character then
		ReachController.applySpeed()
	end
end

return MovementController
