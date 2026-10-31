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
local MovePlacer = require(script.Parent.Controllers.MovePlacer)
local FactoryMotion = require(script.Parent.Controllers.FactoryMotion)
local AnimalMotion = require(script.Parent.Controllers.AnimalMotion)
local CropMotion = require(script.Parent.Controllers.CropMotion)
local RewardPops = require(script.Parent.Controllers.RewardPops)
local TownMotion = require(script.Parent.Controllers.TownMotion)
local QuestsUi = require(script.Parent.UI.Quests)
local SeedCartUi = require(script.Parent.UI.SeedCart)
local QuarryUi = require(script.Parent.UI.Quarry)
local GuildUi = require(script.Parent.UI.Guild)
local BlimpUi = require(script.Parent.UI.Blimp)
local HarborUi = require(script.Parent.UI.Harbor)
local DuckPondUi = require(script.Parent.UI.DuckPond)
local ExpressUi = require(script.Parent.UI.Express)
local MarketUi = require(script.Parent.UI.Market)
local SocialUi = require(script.Parent.UI.Social)
local LevelUp = require(script.Parent.UI.LevelUp)
local SettingsUi = require(script.Parent.UI.Settings)
local DailyGift = require(script.Parent.UI.DailyGift)
local FarmerCard = require(script.Parent.UI.FarmerCard)
local PorchStatus = require(script.Parent.UI.PorchStatus)
local EdgeStack = require(script.Parent.UI.EdgeStack)
local Fx = require(script.Parent.UI.Fx)

local player = Players.LocalPlayer

Remotes.get("State_Snapshot").OnClientEvent:Connect(ClientStore.set)

Panels.init()
Hud.init(Panels.open, ReachController.setActionHeld)
WorldLabels.init()
Guide.init()
ReachController.init()
MovementController.init()
DecorPlacer.init()
MovePlacer.init()
Hud.onMove = MovePlacer.toggle
Panels.busy = function()
	return MovePlacer.isMoving() or DecorPlacer.isActive()
end
Hud.handlers.Place = function(payload) -- place a building you just started
	Panels.close()
	MovePlacer.offer(payload)
end
ReachController.tapOverride = MovePlacer.tap
task.spawn(FactoryMotion.init)
task.spawn(AnimalMotion.init)
task.spawn(CropMotion.init)
task.spawn(TownMotion.init)
RewardPops.init()
SocialUi.init()
QuestsUi.init()
SeedCartUi.init()
QuarryUi.init()
GuildUi.init()
BlimpUi.init()
HarborUi.init()
DuckPondUi.init()
ExpressUi.init() -- after the social controls (it wraps their tap handler)
MarketUi.init() -- the same: it wraps the tap handler for neighbors' stalls
LevelUp.init()
Fx.init()
SettingsUi.init()
DailyGift.init()
FarmerCard.init()
PorchStatus.init()
EdgeStack.init()

-- Keyboard shortcuts for the paperwork panels (Design/11 UI & UX bindings)
local SHORTCUTS = {
	[Enum.KeyCode.O] = "Orders",
	[Enum.KeyCode.B] = "Barn",
	[Enum.KeyCode.F] = "Buildings",
	[Enum.KeyCode.T] = "Town",
	[Enum.KeyCode.G] = "Shop",
	[Enum.KeyCode.Q] = "Quests",
	[Enum.KeyCode.K] = "Settings",
	[Enum.KeyCode.Y] = "DailyGift",
	[Enum.KeyCode.P] = "FarmerCard",
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
	{ "Quests", "Quests" },
	{ "Settings", "Settings" },
	{ "Daily gift", "DailyGift" },
	{ "Farmer Card", "FarmerCard" },
	{ "Seeds (F1)", "Seeds", "F1" },
	{ "Debug", "Debug" },
}
local tourStep = 0

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local panel = SHORTCUTS[input.KeyCode]
	if input.KeyCode == Enum.KeyCode.M then
		Panels.close()
		MovePlacer.toggle()
	elseif panel and Panels.isShowing(panel) then
		Panels.close() -- the same key again closes it (Escape also opens Roblox's menu)
	elseif panel then
		Panels.open(panel)
	elseif input.KeyCode == Enum.KeyCode.Escape then
		Panels.close()
	elseif input.KeyCode == Enum.KeyCode.Z or input.KeyCode == Enum.KeyCode.ButtonL1 then
		Panels.cycleTab(-1) -- the open panel's tabs (Barn, Build)
	elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonR1 then
		Panels.cycleTab(1)
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
	MovePlacer.setPlot(model)
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
