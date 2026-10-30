--!strict
-- Keeps the farm animals alive: hungry ones droop, fed ones peck, chew or bounce, and ready
-- ones wiggle (FarmShared.Art.Motion). The server sets each animal's Mood attribute; this
-- only moves parts on this client. Runs for every plot near the camera, so visitors see it too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local ArtMotion = require(Shared.Art.Motion)

local AnimalMotion = {}

local NEAR = 160 -- studs from the camera

type Entry = { rig: ArtMotion.AnimalRig, model: Model, moving: boolean }

local entries: { [Model]: Entry } = {}
local count = 0

local function track(model: Instance)
	if not model:IsA("Model") or entries[model] or model.Name:sub(1, 7) ~= "Animal_" then
		return
	end
	count += 1
	local rig = ArtMotion.bindAnimal(model, count * 0.73)
	if rig == nil then
		return
	end
	entries[model] = { rig = rig, model = model, moving = false }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			entries[model] = nil
		end
	end)
end

local function watchPlot(plot: Instance)
	for _, d in plot:GetDescendants() do
		track(d)
	end
	plot.DescendantAdded:Connect(track)
end

local function step()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	for model, e in entries do
		local first = e.rig.parts[1]
		local shown = first ~= nil and first.Transparency < 0.9
		local near = (e.rig.feet.Position - eye).Magnitude < NEAR
		if shown and near then
			e.moving = true
			ArtMotion.poseAnimal(e.rig, model:GetAttribute("Mood") :: string?, now)
		elseif e.moving then
			e.moving = false
			ArtMotion.resetAnimal(e.rig)
		end
	end
end

function AnimalMotion.init()
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		watchPlot(plot)
	end
	plots.ChildAdded:Connect(watchPlot)
	RunService.RenderStepped:Connect(step)
end

return AnimalMotion
