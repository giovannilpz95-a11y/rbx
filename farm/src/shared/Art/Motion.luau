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

return ArtMotion
