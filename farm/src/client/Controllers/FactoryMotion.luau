--!strict
-- Turns each factory's moving part while it works: the Feed Mill's paddle wheel, the Sugar
-- Mill's screw press, the Textile Mill's spool, the Dairy's churn plunger and the Bakery's
-- oven glow (FarmShared.Art.Motion). Runs for every plot, so visitors see busy farms too,
-- but only near the camera. The moves are local to this client; the server never sees them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local ArtMotion = require(Shared.Art.Motion)

local FactoryMotion = {}

local NEAR = 220 -- studs from the camera; a plot is about 100 across

type Entry = { rig: ArtMotion.Rig, model: Model, started: number, moving: boolean }

local entries: { [Model]: Entry } = {}

local function track(model: Instance)
	if
		not model:IsA("Model")
		or entries[model]
		or ArtMotion.SPECS[model.Name] == nil
		or not model:IsDescendantOf(Workspace)
	then
		return
	end
	local rig = ArtMotion.bind(model.Name, model)
	if rig == nil then
		return
	end
	entries[model] = { rig = rig, model = model, started = 0, moving = false }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			entries[model] = nil
		end
	end)
end

local function watchPlot(plot: Instance)
	for _, child in plot:GetChildren() do
		track(child)
	end
	-- With streaming a factory can arrive later; wait a frame so it's whole when bound
	plot.ChildAdded:Connect(function(child)
		task.defer(track, child)
	end)
end

local function step()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	for model, e in entries do
		local busy = model:GetAttribute("Busy") == true
		local near = (e.rig.pivot.Position - eye).Magnitude < NEAR
		if busy and near then
			if not e.moving then
				e.moving = true
				e.started = now
			end
			ArtMotion.pose(e.rig, now - e.started)
		elseif e.moving then
			e.moving = false
			ArtMotion.reset(e.rig)
		end
	end
end

function FactoryMotion.init()
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		watchPlot(plot)
	end
	plots.ChildAdded:Connect(watchPlot)
	RunService.RenderStepped:Connect(step)
end

return FactoryMotion
