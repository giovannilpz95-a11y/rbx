--!strict
-- Moving parts for the factories while they work (Design/12 Art & Audio Direction, Animation
-- List: "each factory has a unique moving part"). The server marks a working factory with
-- the Busy attribute; the client's FactoryMotion controller binds a rig per factory and poses
-- it every frame. The poses are plain CFrame math so the tests can run them outside Roblox.
--
-- Every spin or bob runs along its pivot part's local X axis: that is a Kit cylinder's axis
-- (Feed Mill wheel, Textile Mill spool) or an upright post's up (Sugar Mill hub, Dairy
-- plunger), so one rule covers all of them.

local Palette = require("./Palette")

local ArtMotion = {}

export type Spec = {
	kind: "spin" | "bob" | "glow",
	pivot: string, -- part name: in the Anim folder for spin and bob, anywhere for glow
	speed: number, -- radians per second (spin) or cycles' angular speed (bob, glow)
	amplitude: number?, -- studs, for bob
	color: Color3?, -- the far colour, for glow
}

ArtMotion.SPECS = {
	Bakery = { kind = "glow", pivot = "OvenGlow", speed = 3, color = Palette.carrot },
	FeedMill = { kind = "spin", pivot = "Wheel", speed = 1.2 },
	Dairy = { kind = "bob", pivot = "Plunger", speed = 5, amplitude = 0.6 },
	SugarMill = { kind = "spin", pivot = "Hub", speed = 0.8 },
	TextileMill = { kind = "spin", pivot = "Spool", speed = 2.5 },
	SnackFactory = { kind = "bob", pivot = "Popper", speed = 7, amplitude = 0.5 },
	Diner = { kind = "glow", pivot = "NeonSign", speed = 3, color = Palette.flowerPink },
} :: { [string]: Spec }

export type Rig = {
	spec: Spec,
	parts: { BasePart },
	base: { CFrame },
	pivot: CFrame,
	color: Color3,
}

-- Builds a rig for a factory model (the one ArtFactories.build filled), or nil when this
-- factory has no motion or its parts are missing. Records the rest pose, so call it before
-- anything moves.
function ArtMotion.bind(factoryId: string, model: Instance): Rig?
	local spec = ArtMotion.SPECS[factoryId]
	if spec == nil then
		return nil
	end
	local parts: { BasePart } = {}
	local pivot: BasePart? = nil
	if spec.kind == "glow" then
		pivot = model:FindFirstChild(spec.pivot, true) :: BasePart?
		if pivot then
			table.insert(parts, pivot)
		end
	else
		local anim = model:FindFirstChild("Anim")
		if anim == nil then
			return nil
		end
		pivot = anim:FindFirstChild(spec.pivot) :: BasePart?
		if spec.kind == "bob" then
			if pivot then
				table.insert(parts, pivot)
			end
		else
			for _, d in anim:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(parts, d)
				end
			end
		end
	end
	if pivot == nil then
		return nil
	end
	local base = {}
	for i, p in parts do
		base[i] = p.CFrame
	end
	return { spec = spec, parts = parts, base = base, pivot = pivot.CFrame, color = pivot.Color }
end

-- Poses the rig at time t (seconds). t = 0 is the rest pose.
function ArtMotion.pose(rig: Rig, t: number)
	local spec = rig.spec
	if spec.kind == "spin" then
		local turn = rig.pivot * CFrame.Angles(t * spec.speed, 0, 0) * rig.pivot:Inverse()
		for i, p in rig.parts do
			p.CFrame = turn * rig.base[i]
		end
	elseif spec.kind == "bob" then
		-- Rises from rest and drops back: 0 -> amplitude -> 0
		local lift = (1 - math.cos(t * spec.speed)) / 2 * (spec.amplitude or 0.5)
		local up = rig.pivot.RightVector * lift
		for i, p in rig.parts do
			p.CFrame = rig.base[i] + up
		end
	else
		local mix = (1 - math.cos(t * spec.speed)) / 2
		for _, p in rig.parts do
			p.Color = rig.color:Lerp(spec.color or rig.color, mix)
		end
	end
end

-- Puts everything back where bind found it.
function ArtMotion.reset(rig: Rig)
	ArtMotion.pose(rig, 0)
end

---------------------------------------------------------------------------------------------
-- Animals (Design/03 Animals, 12 Animation List): an idle loop per mood. The server sets the
-- animal model's Mood attribute ("hungry", "eating" or "ready"); the client's AnimalMotion
-- poses every visible animal near the camera.
--   hungry: still, head-down droop with a slow breath
--   eating: the body's own gimmick: hens peck, cows chew with a slow sway, sheep bounce
--   ready:  a happy wiggle and a little hop
---------------------------------------------------------------------------------------------

export type AnimalRig = {
	penId: string,
	feet: CFrame, -- the animal's bottom centre, front at local -Z
	parts: { BasePart },
	base: { CFrame },
	phase: number, -- so a pen of animals doesn't move in step
	wool: { BasePart }, -- a sheep's wool puffs, which regrow (setWool)
	woolSize: { Vector3 },
}

function ArtMotion.bindAnimal(model: Instance, phase: number?): AnimalRig?
	local feet = model:GetAttribute("BaseCFrame")
	local penId = model:GetAttribute("PenId")
	if typeof(feet) ~= "CFrame" or type(penId) ~= "string" then
		return nil
	end
	local parts: { BasePart } = {}
	local base: { CFrame } = {}
	local wool: { BasePart } = {}
	local woolSize: { Vector3 } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(base, d.CFrame)
			if penId == "SheepFold" and (d.Name == "Wool" or d.Name == "Fringe") then
				table.insert(wool, d)
				table.insert(woolSize, d.Size)
			end
		end
	end
	return {
		penId = penId,
		feet = feet,
		parts = parts,
		base = base,
		phase = phase or 0,
		wool = wool,
		woolSize = woolSize,
	}
end

-- Wool regrow (Model List: Sheep): just shorn (hungry) the puffs are at 0.6 of full size,
-- they grow back over the eating timer (`progress` 0-1) and are full when the Wool is ready.
function ArtMotion.woolScale(mood: string?, progress: number): number
	if mood == "ready" then
		return 1
	elseif mood == "hungry" then
		return 0.6
	end
	return 0.6 + 0.4 * math.clamp(progress, 0, 1)
end

function ArtMotion.setWool(rig: AnimalRig, scale: number)
	for i, p in rig.wool do
		p.Size = rig.woolSize[i] * scale
	end
end

-- The body's offset from rest, in the animal's own space, at time t.
function ArtMotion.animalOffset(penId: string, mood: string?, t: number): CFrame
	if mood == "hungry" then
		local breath = math.sin(t * 1.6) * 0.03
		return CFrame.new(0, -0.08 + breath, 0) * CFrame.Angles(math.rad(-7), 0, 0)
	elseif mood == "ready" then
		local hop = math.max(0, math.sin(t * 5)) * 0.25
		return CFrame.new(0, hop, 0) * CFrame.Angles(0, math.rad(math.sin(t * 9) * 8), 0)
	end
	-- eating
	if penId == "ChickenCoop" then
		-- Quick pecks in bursts: tip forward over the front of the feet
		local peck = math.max(0, math.sin(t * 7)) ^ 3 * math.max(0, math.sin(t * 1.3))
		return CFrame.new(0, 0, -0.5) * CFrame.Angles(math.rad(-28 * peck), 0, 0) * CFrame.new(0, 0, 0.5)
	elseif penId == "SheepFold" then
		local bounce = math.max(0, math.sin(t * 3)) ^ 2 * 0.3
		return CFrame.new(0, bounce, 0)
	end
	-- Cows chew: a slow sway and a small nod
	return CFrame.Angles(math.rad(math.sin(t * 4) * 2.5), 0, math.rad(math.sin(t * 1.1) * 2))
end

function ArtMotion.poseAnimal(rig: AnimalRig, mood: string?, t: number)
	local move = rig.feet * ArtMotion.animalOffset(rig.penId, mood, t + rig.phase) * rig.feet:Inverse()
	for i, p in rig.parts do
		p.CFrame = move * rig.base[i]
	end
end

function ArtMotion.resetAnimal(rig: AnimalRig)
	for i, p in rig.parts do
		p.CFrame = rig.base[i]
	end
end

---------------------------------------------------------------------------------------------
-- Pen gates, ready crops and harvests
---------------------------------------------------------------------------------------------

-- Where a pen's Gate (Art/Animals) stands when `open` (0 shut, 1 fully open) of the way.
function ArtMotion.gateCFrame(gate: BasePart, open: number): CFrame?
	local closed = gate:GetAttribute("ClosedCFrame")
	local hinge = gate:GetAttribute("HingeCFrame")
	local swing = gate:GetAttribute("Swing")
	if typeof(closed) ~= "CFrame" or typeof(hinge) ~= "CFrame" or type(swing) ~= "number" then
		return nil
	end
	local eased = (1 - math.cos(math.clamp(open, 0, 1) * math.pi)) / 2
	return hinge * CFrame.Angles(0, math.rad(swing * eased), 0) * hinge:ToObjectSpace(closed)
end

-- A ready crop's gentle sway about its base, at time t (Model List: Ready sparkle).
function ArtMotion.cropSway(t: number): CFrame
	return CFrame.Angles(math.rad(math.sin(t * 1.7) * 3), 0, math.rad(math.sin(t * 1.3 + 1) * 3))
end

ArtMotion.HARVEST_SECONDS = 0.9

-- The harvest hop: a crop (or product) pops up from `from`, then arcs over to `to` (the Barn)
-- shrinking as it goes. `a` runs 0-1 over HARVEST_SECONDS; returns the position and scale.
function ArtMotion.harvestPath(from: Vector3, to: Vector3, a: number): (Vector3, number)
	local hop = 0.25
	if a <= hop then
		local u = a / hop
		return from + Vector3.new(0, 2.2 * math.sin(u * math.pi / 2), 0), 1 + 0.15 * u
	end
	local u = math.clamp((a - hop) / (1 - hop), 0, 1)
	local start = from + Vector3.new(0, 2.2, 0)
	local arc = math.sin(u * math.pi) * 6
	return start:Lerp(to, u * u) + Vector3.new(0, arc, 0), 1.15 - 0.9 * u
end

---------------------------------------------------------------------------------------------
-- Townsfolk, the Town Hall bell and reward pickups
---------------------------------------------------------------------------------------------

export type FolkRig = {
	role: string,
	feet: CFrame,
	parts: { BasePart },
	base: { CFrame },
	arm: number?, -- index of the right arm in `parts` (the Builder swings it)
	phase: number,
}

function ArtMotion.bindFolk(model: Instance, phase: number?): FolkRig?
	local feet = model:GetAttribute("BaseCFrame")
	local role = model:GetAttribute("Role")
	if typeof(feet) ~= "CFrame" or type(role) ~= "string" then
		return nil
	end
	local parts: { BasePart } = {}
	local base: { CFrame } = {}
	local arm: number? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(base, d.CFrame)
			if d.Name == "RightArm" then
				arm = #parts
			end
		end
	end
	return { role = role, feet = feet, parts = parts, base = base, arm = arm, phase = phase or 0 }
end

-- A peg-folk idle: a gentle bob and sway in place; the Builder bobs with each hammer blow.
function ArtMotion.folkOffset(role: string, t: number): CFrame
	if role == "Builder" then
		return CFrame.new(0, math.max(0, math.sin(t * 6)) * 0.08, 0)
	end
	return CFrame.new(0, math.abs(math.sin(t * 1.6)) * 0.12, 0) * CFrame.Angles(0, 0, math.rad(math.sin(t * 0.8) * 3))
end

-- The Builder's hammer arm: up and down about the shoulder, in degrees.
function ArtMotion.hammerAngle(t: number): number
	return -60 * math.max(0, math.sin(t * 6)) ^ 2
end

function ArtMotion.poseFolk(rig: FolkRig, t: number)
	local tt = t + rig.phase
	local move = rig.feet * ArtMotion.folkOffset(rig.role, tt) * rig.feet:Inverse()
	for i, p in rig.parts do
		local cf = rig.base[i]
		if i == rig.arm and rig.role == "Builder" then
			local shoulder = cf * CFrame.new(0, 0.55, 0)
			cf = shoulder * CFrame.Angles(math.rad(ArtMotion.hammerAngle(tt)), 0, 0) * shoulder:ToObjectSpace(cf)
		end
		p.CFrame = move * cf
	end
end

-- The Town Hall bell's swing about its hinge `a` seconds into a level-up ring (it settles by
-- BELL_SECONDS).
ArtMotion.BELL_SECONDS = 2.4

function ArtMotion.bellAngle(a: number): number
	if a <= 0 or a >= ArtMotion.BELL_SECONDS then
		return 0
	end
	local fade = 1 - a / ArtMotion.BELL_SECONDS
	return math.sin(a * 10) * 35 * fade
end

ArtMotion.PICKUP_SECONDS = 1.1

-- A reward pickup popping out at `from`: up and out along `dir` (flat, unit) in an arc, a
-- moment hanging there spinning, then up and away while it shrinks. `a` runs 0-1 over
-- PICKUP_SECONDS; returns the position, the spin (radians) and the scale.
function ArtMotion.pickupPath(from: Vector3, dir: Vector3, a: number): (Vector3, number, number)
	local u = math.clamp(a, 0, 1)
	local spin = u * math.pi * 4
	if u < 0.45 then
		local k = u / 0.45
		return from + dir * (1.6 * k) + Vector3.new(0, 3 * math.sin(k * math.pi * 0.75), 0), spin, 0.4 + 0.6 * k
	end
	local k = (u - 0.45) / 0.55
	local hang = from + dir * 1.6 + Vector3.new(0, 3 * math.sin(math.pi * 0.75), 0)
	return hang + Vector3.new(0, 7 * k * k, 0), spin, 1 - 0.8 * k
end

return ArtMotion
