--!strict
-- The townsfolk bob in place and the Builder swings a hammer at each scaffold
-- (FarmShared.Art.Folk), and your Town Hall's bell rings when you level up. Client-only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local ArtMotion = require(Shared.Art.Motion)
local ClientStore = require(script.Parent.Parent.ClientStore)

local TownMotion = {}

local NEAR = 120 -- studs from the camera

type Entry = { rig: ArtMotion.FolkRig, moving: boolean }

local folk: { [Model]: Entry } = {}
local count = 0
local ringStarted: number? = nil
local lastLevel: number? = nil

local function track(d: Instance)
	if not d:IsA("Model") or folk[d] or d.Name:sub(1, 5) ~= "Folk_" then
		return
	end
	local model = d :: Model
	count += 1
	local rig = ArtMotion.bindFolk(model, count * 0.91)
	if rig == nil then
		return
	end
	folk[model] = { rig = rig, moving = false }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			folk[model] = nil
		end
	end)
end

local function watchPlot(plot: Instance)
	for _, d in plot:GetDescendants() do
		track(d)
	end
	plot.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.defer(track, d)
		end
	end)
end

-- This player's own Town Hall bell
local function ownBell(): BasePart?
	local plots = Workspace:FindFirstChild("Plots")
	if plots == nil then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return plot:FindFirstChild("Bell", true) :: BasePart?
		end
	end
	return nil
end

local function stepBell()
	if ringStarted == nil then
		return
	end
	local bell = ownBell()
	local hinge = bell and bell:GetAttribute("HingeCFrame")
	local rest = bell and bell:GetAttribute("RestCFrame")
	if bell == nil or typeof(hinge) ~= "CFrame" then
		ringStarted = nil
		return
	end
	if typeof(rest) ~= "CFrame" then
		rest = bell.CFrame
		bell:SetAttribute("RestCFrame", rest)
	end
	local a = os.clock() - ringStarted
	local angle = ArtMotion.bellAngle(a)
	bell.CFrame = hinge * CFrame.Angles(math.rad(angle), 0, 0) * hinge:ToObjectSpace(rest :: CFrame)
	if a >= ArtMotion.BELL_SECONDS then
		bell.CFrame = rest :: CFrame
		ringStarted = nil
	end
end

local function step()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	for _, e in folk do
		local first = e.rig.parts[1]
		local shown = first ~= nil and first.Transparency < 0.9
		if shown and (e.rig.feet.Position - eye).Magnitude < NEAR then
			e.moving = true
			ArtMotion.poseFolk(e.rig, now)
		elseif e.moving then
			e.moving = false
			for i, p in e.rig.parts do
				p.CFrame = e.rig.base[i]
			end
		end
	end
	stepBell()
end

function TownMotion.init()
	lastLevel = ClientStore.state and ClientStore.state.level
	ClientStore.changed.Event:Connect(function(state)
		local level = state and state.level
		if type(level) == "number" then
			if lastLevel ~= nil and level > lastLevel then
				ringStarted = os.clock()
			end
			lastLevel = level
		end
	end)
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		watchPlot(plot)
	end
	plots.ChildAdded:Connect(watchPlot)
	RunService.RenderStepped:Connect(step)
end

return TownMotion
