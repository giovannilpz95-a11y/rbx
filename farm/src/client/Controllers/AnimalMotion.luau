--!strict
-- Keeps the farm animals alive: hungry ones droop, fed ones peck, chew or bounce, and ready
-- ones wiggle (FarmShared.Art.Motion). The server sets each animal's Mood attribute; this
-- only moves parts on this client. Runs for every plot near the camera, so visitors see it too.
-- Also regrows sheep wool over the eating timer (with a puff of wool when it's collected) and
-- swings pen gates open when anyone walks up to them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local ArtMotion = require(Shared.Art.Motion)
local Palette = require(Shared.Art.Palette)

local AnimalMotion = {}

local NEAR = 160 -- studs from the camera
local GATE_REACH = 8 -- studs from a gate that swings it open
local GATE_SPEED = 2.5 -- of the full swing per second

type Entry = { rig: ArtMotion.AnimalRig, model: Model, moving: boolean, mood: string?, wool: number }
type Gate = { part: BasePart, open: number }

local entries: { [Model]: Entry } = {}
local gates: { [BasePart]: Gate } = {}
local count = 0

local function forget(instance: Instance, drop: () -> ())
	instance.AncestryChanged:Connect(function()
		if not instance:IsDescendantOf(Workspace) then
			drop()
		end
	end)
end

local function track(d: Instance)
	if d:IsA("BasePart") and d.Name == "Gate" and d:GetAttribute("HingeCFrame") ~= nil then
		if gates[d] == nil then
			gates[d] = { part = d, open = 0 }
			forget(d, function()
				gates[d] = nil
			end)
		end
		return
	end
	if not d:IsA("Model") or entries[d] or d.Name:sub(1, 7) ~= "Animal_" then
		return
	end
	local model = d :: Model
	count += 1
	local rig = ArtMotion.bindAnimal(model, count * 0.73)
	if rig == nil then
		return
	end
	entries[model] = { rig = rig, model = model, moving = false, mood = nil, wool = 1 }
	forget(model, function()
		entries[model] = nil
	end)
end

local function watchPlot(plot: Instance)
	for _, d in plot:GetDescendants() do
		track(d)
	end
	plot.DescendantAdded:Connect(track)
end

-- A puff of wool flying off a sheep that was just shorn (client-only parts).
local function woolPuff(at: Vector3)
	local puffs = {}
	for i = 1, 5 do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 0.6
		p.Color = Palette.wool
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		local angle = i * math.pi * 2 / 5
		puffs[i] = { part = p, dir = Vector3.new(math.cos(angle), 1.2, math.sin(angle)).Unit }
		p.Position = at
		p.Parent = Workspace
	end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - start) / 0.6
		for _, puff in puffs do
			puff.part.Position = at + puff.dir * (a * 3)
			puff.part.Transparency = a
		end
		if a >= 1 then
			conn:Disconnect()
			for _, puff in puffs do
				puff.part:Destroy()
			end
		end
	end)
end

local function stepWool(e: Entry, mood: string?)
	if #e.rig.wool == 0 then
		return
	end
	if e.mood == "ready" and mood == "hungry" then
		woolPuff(e.rig.feet.Position + Vector3.new(0, 1.6, 0))
	end
	local progress = 0
	local readyAt = e.model:GetAttribute("ReadyAt")
	local span = e.model:GetAttribute("Span")
	if type(readyAt) == "number" and type(span) == "number" and span > 0 then
		progress = 1 - (readyAt - Workspace:GetServerTimeNow()) / span
	end
	local scale = ArtMotion.woolScale(mood, progress)
	if math.abs(scale - e.wool) > 0.01 then
		e.wool = scale
		ArtMotion.setWool(e.rig, scale)
	end
end

local function stepGates(dt: number)
	local walkers = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(walkers, root.Position)
		end
	end
	for _, g in gates do
		local closed = g.part:GetAttribute("ClosedCFrame") :: CFrame
		local target = 0
		if g.part.Transparency < 0.9 then
			for _, pos in walkers do
				if (pos - closed.Position).Magnitude < GATE_REACH then
					target = 1
					break
				end
			end
		end
		if g.open ~= target then
			g.open = if target > g.open
				then math.min(target, g.open + dt * GATE_SPEED)
				else math.max(target, g.open - dt * GATE_SPEED)
			local cf = ArtMotion.gateCFrame(g.part, g.open)
			if cf then
				g.part.CFrame = cf
			end
		end
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	for model, e in entries do
		local mood = model:GetAttribute("Mood") :: string?
		stepWool(e, mood)
		e.mood = mood
		local first = e.rig.parts[1]
		local shown = first ~= nil and first.Transparency < 0.9
		local near = (e.rig.feet.Position - eye).Magnitude < NEAR
		if shown and near then
			e.moving = true
			ArtMotion.poseAnimal(e.rig, mood, now)
		elseif e.moving then
			e.moving = false
			ArtMotion.resetAnimal(e.rig)
		end
	end
	stepGates(dt)
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
