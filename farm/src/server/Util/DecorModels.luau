--!strict
-- Greybox looks for the decorations (Design/16 Model Catalog §2.11 describes the real ones).
-- Each build returns a Model whose invisible "Root" part covers the footprint and carries
-- Interact = "Decor"; visible parts hang under Root so a tap on them finds it.

local Decor = require(game:GetService("ReplicatedStorage"):WaitForChild("FarmShared").Config.Decor)

local DecorModels = {}

type Spec = {
	size: Vector3,
	at: Vector3, -- centre, relative to the footprint centre at ground level
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?,
	rot: Vector3?, -- degrees
}

local C = Color3.fromRGB
local WOOD, LEAF, STONE = C(196, 150, 90), C(90, 160, 70), C(165, 160, 175)

local SPECS: { [string]: { Spec } } = {
	GravelPath = {
		{
			size = Vector3.new(4, 0.2, 4),
			at = Vector3.new(0, 0.35, 0),
			color = C(214, 196, 160),
			material = Enum.Material.Pebble,
		},
	},
	BrickPath = {
		{
			size = Vector3.new(4, 0.2, 4),
			at = Vector3.new(0, 0.35, 0),
			color = C(190, 100, 80),
			material = Enum.Material.Brick,
		},
	},
	PicketFence = {
		{ size = Vector3.new(4, 0.3, 0.3), at = Vector3.new(0, 1.8, 0), color = WOOD },
		{ size = Vector3.new(0.4, 2.6, 0.4), at = Vector3.new(-1.5, 1.4, 0), color = C(240, 230, 205) },
		{ size = Vector3.new(0.4, 2.6, 0.4), at = Vector3.new(-0.5, 1.4, 0), color = C(240, 230, 205) },
		{ size = Vector3.new(0.4, 2.6, 0.4), at = Vector3.new(0.5, 1.4, 0), color = C(240, 230, 205) },
		{ size = Vector3.new(0.4, 2.6, 0.4), at = Vector3.new(1.5, 1.4, 0), color = C(240, 230, 205) },
	},
	HedgeRow = {
		{
			size = Vector3.new(4, 2.6, 1.5),
			at = Vector3.new(0, 1.5, 0),
			color = C(70, 140, 60),
			material = Enum.Material.Grass,
		},
	},
	FlowerBed = {
		{ size = Vector3.new(3.6, 0.8, 3.6), at = Vector3.new(0, 0.6, 0), color = WOOD },
		{
			size = Vector3.new(1, 1, 1),
			at = Vector3.new(-0.8, 1.4, -0.8),
			color = C(240, 120, 160),
			shape = Enum.PartType.Ball,
		},
		{
			size = Vector3.new(1, 1, 1),
			at = Vector3.new(0.8, 1.4, -0.6),
			color = C(250, 210, 80),
			shape = Enum.PartType.Ball,
		},
		{
			size = Vector3.new(1, 1, 1),
			at = Vector3.new(0, 1.4, 0.8),
			color = C(150, 120, 230),
			shape = Enum.PartType.Ball,
		},
	},
	OakTree = {
		{ size = Vector3.new(1.4, 6, 1.4), at = Vector3.new(0, 3.2, 0), color = C(150, 105, 60) },
		{
			size = Vector3.new(6, 6, 6),
			at = Vector3.new(0, 7.5, 0),
			color = LEAF,
			shape = Enum.PartType.Ball,
			material = Enum.Material.Grass,
		},
		{
			size = Vector3.new(4, 4, 4),
			at = Vector3.new(0.8, 10, 0.4),
			color = C(130, 190, 80),
			shape = Enum.PartType.Ball,
			material = Enum.Material.Grass,
		},
	},
	HayBales = {
		{
			size = Vector3.new(3, 2.6, 2.6),
			at = Vector3.new(-1.6, 1.5, 0),
			color = C(225, 195, 110),
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(3, 2.6, 2.6),
			at = Vector3.new(1.6, 1.5, 0),
			color = C(225, 195, 110),
			shape = Enum.PartType.Cylinder,
		},
		{
			size = Vector3.new(3, 2.6, 2.6),
			at = Vector3.new(0, 3.8, 0),
			color = C(235, 205, 120),
			shape = Enum.PartType.Cylinder,
		},
	},
	Pond = {
		{
			size = Vector3.new(0.4, 11.5, 11.5),
			at = Vector3.new(0, 0.45, 0),
			color = STONE,
			shape = Enum.PartType.Cylinder,
			rot = Vector3.new(0, 0, 90),
		},
		{
			size = Vector3.new(0.5, 10, 10),
			at = Vector3.new(0, 0.55, 0),
			color = C(90, 160, 220),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Glass,
			rot = Vector3.new(0, 0, 90),
		},
	},
	LampPost = {
		{ size = Vector3.new(0.5, 7, 0.5), at = Vector3.new(0, 3.75, 0), color = WOOD },
		{
			size = Vector3.new(1.4, 1.4, 1.4),
			at = Vector3.new(0, 7.8, 0),
			color = C(255, 230, 150),
			material = Enum.Material.Neon,
		},
	},
	Bench = {
		{ size = Vector3.new(6, 0.4, 1.8), at = Vector3.new(0, 1.6, 0), color = WOOD },
		{ size = Vector3.new(6, 1.4, 0.3), at = Vector3.new(0, 2.5, 0.8), color = WOOD },
		{ size = Vector3.new(0.4, 1.4, 1.8), at = Vector3.new(-2.8, 0.9, 0), color = C(150, 105, 60) },
		{ size = Vector3.new(0.4, 1.4, 1.8), at = Vector3.new(2.8, 0.9, 0), color = C(150, 105, 60) },
	},
	PicnicTable = {
		{ size = Vector3.new(6, 0.4, 3), at = Vector3.new(0, 2.6, 0), color = C(220, 90, 80) },
		{ size = Vector3.new(6, 0.3, 1), at = Vector3.new(0, 1.4, -2.4), color = WOOD },
		{ size = Vector3.new(6, 0.3, 1), at = Vector3.new(0, 1.4, 2.4), color = WOOD },
		{ size = Vector3.new(0.4, 2.3, 0.4), at = Vector3.new(-2.5, 1.4, 0), color = C(150, 105, 60) },
		{ size = Vector3.new(0.4, 2.3, 0.4), at = Vector3.new(2.5, 1.4, 0), color = C(150, 105, 60) },
	},
	StoneFountain = {
		{
			size = Vector3.new(1.2, 11, 11),
			at = Vector3.new(0, 0.85, 0),
			color = STONE,
			shape = Enum.PartType.Cylinder,
			rot = Vector3.new(0, 0, 90),
		},
		{
			size = Vector3.new(0.4, 9.6, 9.6),
			at = Vector3.new(0, 1.5, 0),
			color = C(90, 160, 220),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Glass,
			rot = Vector3.new(0, 0, 90),
		},
		{ size = Vector3.new(1.2, 4, 1.2), at = Vector3.new(0, 3.2, 0), color = STONE },
		{
			size = Vector3.new(0.8, 5, 5),
			at = Vector3.new(0, 5.4, 0),
			color = STONE,
			shape = Enum.PartType.Cylinder,
			rot = Vector3.new(0, 0, 90),
		},
		{
			size = Vector3.new(1, 1.4, 1),
			at = Vector3.new(0, 6.5, 0),
			color = C(140, 200, 240),
			material = Enum.Material.Glass,
		},
	},
}

-- origin: the footprint centre on the ground, already turned. index: the save slot.
function DecorModels.build(id: string, origin: CFrame, index: number): Model
	local def = Decor.items[id]
	local model = Instance.new("Model")
	model.Name = "Decor_" .. id
	local w, d = def.size[1] * Decor.tile, def.size[2] * Decor.tile
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root.Size = Vector3.new(w - 0.2, 3, d - 0.2)
	root.CFrame = origin * CFrame.new(0, 1.6, 0)
	root:SetAttribute("Interact", "Decor")
	root:SetAttribute("DecorIndex", index)
	root.Parent = model
	model.PrimaryPart = root
	for _, spec in SPECS[id] or {} do
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = spec.size
		p.Color = spec.color
		p.Material = spec.material or Enum.Material.SmoothPlastic
		p.Shape = spec.shape or Enum.PartType.Block
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = spec.size.Magnitude > 4
		local rot = spec.rot or Vector3.zero
		p.CFrame = origin * CFrame.new(spec.at) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		p.Parent = root
	end
	return model
end

return DecorModels
