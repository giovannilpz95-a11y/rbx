--!strict
-- Client boot: HUD, panels, in-world labels, then the walk-first controllers once our plot
-- exists. All game state comes from the server; the client only sends intents.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientStore = require(script.Parent.ClientStore)
local Remotes = require(script.Parent.Remotes)
local Guide = require(script.Parent.UI.Guide)
local Hud = require(script.Parent.UI.Hud)
local Panels = require(script.Parent.UI.Panels)
local WorldLabels = require(script.Parent.UI.WorldLabels)
local ReachController = require(script.Parent.Controllers.ReachController)
local MovementController = require(script.Parent.Controllers.MovementController)
local DecorPlacer = require(script.Parent.Controllers.DecorPlacer)
local FactoryMotion = require(script.Parent.Controllers.FactoryMotion)
local SocialUi = require(script.Parent.UI.Social)

local player = Players.LocalPlayer

Remotes.get("State_Snapshot").OnClientEvent:Connect(ClientStore.set)

Panels.init()
Hud.init(Panels.open, ReachController.setActionHeld)
WorldLabels.init()
Guide.init()
ReachController.init()
MovementController.init()
DecorPlacer.init()
task.spawn(FactoryMotion.init)
SocialUi.init()

-- Keyboard shortcuts for the paperwork panels (Design/11 UI & UX bindings)
local SHORTCUTS = {
	[Enum.KeyCode.O] = "Orders",
	[Enum.KeyCode.B] = "Barn",
	[Enum.KeyCode.F] = "Buildings",
	[Enum.KeyCode.T] = "Town",
	[Enum.KeyCode.G] = "Shop",
	[Enum.KeyCode.Backquote] = "Debug",
}
-- Studio only: ] steps through every screen, for phone screenshots in the device emulator
-- (11 UI & UX mobile check). Each step prints its name to Output.
local TOUR = {
	{ "HUD only" },
	{ "Barn", "Barn" },
	{ "Orders", "Orders" },
	{ "Shop", "Shop" },
	{ "Buildings", "Buildings" },
	{ "Town", "Town" },
	{ "Seeds (F1)", "Seeds", "F1" },
	{ "Debug", "Debug" },
}
local tourStep = 0

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local panel = SHORTCUTS[input.KeyCode]
	if panel then
		Panels.open(panel)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		Panels.close()
	elseif input.KeyCode == Enum.KeyCode.RightBracket and RunService:IsStudio() then
		tourStep = tourStep % #TOUR + 1
		local step = TOUR[tourStep]
		Panels.close()
		if step[2] then
			Panels.open(step[2], step[3])
		end
		local viewport = Workspace.CurrentCamera.ViewportSize
		print(string.format("[Tour] %d/%d %s at %dx%d", tourStep, #TOUR, step[1], viewport.X, viewport.Y))
	end
end)

Remotes.fire("Client_Ready")

-- Find our plot once the server has built it
local plots = Workspace:WaitForChild("Plots")
local function isMine(model: Instance): boolean
	return model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId
end
local function usePlot(model: Model)
	ReachController.setPlot(model)
	WorldLabels.setPlot(model)
	Guide.setPlot(model)
	DecorPlacer.setPlot(model)
end
for _, child in plots:GetChildren() do
	if isMine(child) then
		usePlot(child :: Model)
	end
end
plots.ChildAdded:Connect(function(child)
	-- Attributes are set before the model is parented, so this check is safe.
	if isMine(child) then
		usePlot(child :: Model)
	end
end)
