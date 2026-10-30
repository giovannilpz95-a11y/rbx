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
}

function ArtMotion.bindAnimal(model: Instance, phase: number?): AnimalRig?
	local feet = model:GetAttribute("BaseCFrame")
	local penId = model:GetAttribute("PenId")
	if typeof(feet) ~= "CFrame" or type(penId) ~= "string" then
		return nil
	end
	local parts: { BasePart } = {}
	local base: { CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(base, d.CFrame)
		end
	end
	return { penId = penId, feet = feet, parts = parts, base = base, phase = phase or 0 }
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

return ArtMotion
