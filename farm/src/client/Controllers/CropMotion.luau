--!strict
-- Ready crops sway gently (the server adds their sparkle), and a harvested crop hops out of
-- its field and flies off to the Barn; collected animal products do the same from the pen.
-- Client-only, for every plot, so visitors see it too (Model List - Farm & Animals: Ready
-- sparkle, Harvest hop, Collect).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local ArtMotion = require(Shared.Art.Motion)

local CropMotion = {}

local NEAR = 120 -- studs from the camera for the sway

type Ready = { crop: Model, bed: BasePart, parts: { BasePart }, base: { CFrame }, copy: Model, phase: number }

local ready: { [Model]: Ready } = {}
local count = 0

local function plotOf(instance: Instance): Instance?
	local plots = Workspace:FindFirstChild("Plots")
	local node: Instance? = instance
	while node and node.Parent ~= plots do
		node = node.Parent
	end
	return node
end

-- A copy of `source` (already detached from the world) that hops up from where it stood and
-- arcs into the plot's Barn, shrinking as it goes.
local function flyToBarn(copy: Model, plot: Instance?)
	local barn = plot and plot:FindFirstChild("Barn") :: BasePart?
	if barn == nil then
		copy:Destroy()
		return
	end
	-- Pivot on the middle of what's flying, so it spins and shrinks about its own centre
	local start = copy:GetBoundingBox()
	copy.WorldPivot = start
	local to = barn.Position + Vector3.new(0, 2, 0)
	copy.Parent = Workspace
	local began = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.min(1, (os.clock() - began) / ArtMotion.HARVEST_SECONDS)
		local pos, scale = ArtMotion.harvestPath(start.Position, to, a)
		copy:PivotTo(start.Rotation * CFrame.Angles(0, a * 5, 0) + pos)
		copy:ScaleTo(math.max(0.05, scale))
		if a >= 1 then
			conn:Disconnect()
			copy:Destroy()
		end
	end)
end

local function detachedCopy(model: Model): Model
	local copy = model:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			local base = d:GetAttribute("BaseTransparency")
			d.Transparency = if type(base) == "number" then base else 0
		end
	end
	return copy
end

local function trackCrop(crop: Model)
	local bed = crop.Parent
	if crop:GetAttribute("Stage") ~= 4 or ready[crop] or bed == nil or not bed:IsA("BasePart") then
		return
	end
	local parts: { BasePart } = {}
	local base: { CFrame } = {}
	for _, d in crop:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(base, d.CFrame)
		end
	end
	count += 1
	local entry =
		{ crop = crop, bed = bed, parts = parts, base = base, copy = detachedCopy(crop), phase = count * 1.37 }
	ready[crop] = entry
	crop.AncestryChanged:Connect(function()
		if crop:IsDescendantOf(Workspace) or ready[crop] == nil then
			return
		end
		ready[crop] = nil
		-- Harvested (the field is empty now), not just a plot being taken down
		task.defer(function()
			if bed:IsDescendantOf(Workspace) and bed:GetAttribute("Crop") == nil then
				flyToBarn(entry.copy, plotOf(bed))
			else
				entry.copy:Destroy()
			end
		end)
	end)
end

local function trackProduct(product: Model)
	local first = product:FindFirstChildWhichIsA("BasePart")
	if first == nil then
		return
	end
	local shown = first.Transparency < 0.5
	first:GetPropertyChangedSignal("Transparency"):Connect(function()
		local now = first.Transparency < 0.5
		if shown and not now and product:IsDescendantOf(Workspace) then
			-- Collected: the product goes to the Barn
			local copy = detachedCopy(product)
			flyToBarn(copy, plotOf(product))
		end
		shown = now
	end)
end

local function track(d: Instance)
	if not d:IsA("Model") then
		return
	end
	if d.Name == "Crop" then
		trackCrop(d)
	elseif d.Name:sub(1, 8) == "Product_" then
		trackProduct(d)
	end
end

local function watchPlot(plot: Instance)
	for _, d in plot:GetDescendants() do
		track(d)
	end
	-- A crop model arrives before its parts; wait a frame so it's whole when bound
	plot.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.defer(track, d)
		end
	end)
end

local function step()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local moveParts: { BasePart } = {}
	local moveTo: { CFrame } = {}
	for _, e in ready do
		local root = e.bed.CFrame * CFrame.new(0, e.bed.Size.Y / 2, 0)
		if (root.Position - eye).Magnitude > NEAR then
			continue
		end
		local sway = root * ArtMotion.cropSway(now + e.phase) * root:Inverse()
		for i, p in e.parts do
			table.insert(moveParts, p)
			table.insert(moveTo, sway * e.base[i])
		end
	end
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveTo, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function CropMotion.init()
	local plots = Workspace:WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		watchPlot(plot)
	end
	plots.ChildAdded:Connect(watchPlot)
	RunService.RenderStepped:Connect(step)
end

return CropMotion
