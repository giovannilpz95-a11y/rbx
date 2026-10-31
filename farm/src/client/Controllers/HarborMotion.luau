--!strict
-- The Harbor's water moves (Features/F02, Art/Harbor): the Driftwood Crate bobs and turns a
-- little, and the Sailboats rock at their berths. Client-only; the server only shows and hides
-- the parts, so posing them here never fights it. Only Harbors near the camera move.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HarborMotion = {}

local NEAR = 120 -- studs from the camera

type Entry = { parts: { BasePart }, base: { CFrame }, centre: Vector3, phase: number, crate: boolean }

local entries: { [Model]: Entry } = {}
local count = 0

local function track(d: Instance)
	if not d:IsA("Model") or entries[d] then
		return
	end
	local model = d :: Model
	local parent = model.Parent
	local isDrift = model.Name == "Drift"
	local isBoat = model.Name:match("^Boat%d$") ~= nil
	if not (isDrift or isBoat) or parent == nil or parent.Name ~= "Harbor" then
		return
	end
	local parts, base = {}, {}
	local sum = Vector3.zero
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			table.insert(base, p.CFrame)
			sum += p.Position
		end
	end
	if #parts == 0 then
		return
	end
	count += 1
	entries[model] = { parts = parts, base = base, centre = sum / #parts, phase = count * 1.37, crate = isDrift }
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			entries[model] = nil
		end
	end)
end

local function step()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	local t = os.clock()
	for _, e in entries do
		if (e.centre - eye).Magnitude > NEAR or e.parts[1].Transparency >= 1 then
			continue
		end
		local s = t + e.phase
		local offset
		if e.crate then
			-- Bob 0.25 studs and swing a few degrees about its own centre
			offset = CFrame.new(e.centre + Vector3.new(0, math.sin(s * 2) * 0.25, 0))
				* CFrame.Angles(math.sin(s * 1.3) * 0.08, math.sin(s * 0.7) * 0.15, math.sin(s * 1.7) * 0.06)
				* CFrame.new(-e.centre)
		else
			-- A boat rocks side to side and rises a touch on the swell
			offset = CFrame.new(e.centre + Vector3.new(0, math.sin(s * 1.1) * 0.08, 0))
				* CFrame.Angles(math.sin(s * 0.9) * 0.025, 0, math.sin(s * 1.2) * 0.05)
				* CFrame.new(-e.centre)
		end
		for i, p in e.parts do
			p.CFrame = offset * e.base[i]
		end
	end
end

function HarborMotion.init()
	local plots = Workspace:WaitForChild("Plots")
	for _, d in plots:GetDescendants() do
		track(d)
	end
	plots.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			-- Let its parts stream in first
			task.delay(0.5, track, d)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return HarborMotion
