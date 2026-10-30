--!strict
-- Item icons for the UI: each item's 3D prop (ArtItemProps) in a ViewportFrame, lit from the
-- same upper-left angle and seen from the same three-quarter view, so every icon matches
-- (Design/12 Art & Audio Direction, Item Icons). Client-side only.
--
--   local icon = ArtIcons.viewport("Bread", 48)
--   icon.Parent = someFrame

local ArtItemProps = require("./ItemProps")

local ArtIcons = {}

local VIEW = CFrame.Angles(0, math.rad(-28), 0) * CFrame.Angles(math.rad(24), 0, 0) -- three-quarter, slightly above
local FOV = 30

-- A square, transparent ViewportFrame of `size` pixels (or scale 1 when size is nil) showing
-- the prop for `id`.
function ArtIcons.viewport(id: string, size: number?): ViewportFrame
	local frame = Instance.new("ViewportFrame")
	frame.Name = id .. "Icon"
	frame.BackgroundTransparency = 1
	frame.Size = if size then UDim2.fromOffset(size, size) else UDim2.fromScale(1, 1)
	frame.Ambient = Color3.fromRGB(190, 180, 170)
	frame.LightColor = Color3.fromRGB(255, 246, 229)
	frame.LightDirection = Vector3.new(1, -1.4, 0.8) -- from the upper left, toward the back

	local prop = ArtItemProps.build(id)
	prop.Parent = frame
	local center, extents = prop:GetBoundingBox()
	local radius = extents.Magnitude / 2

	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	-- Far enough that the prop's bounding sphere just fits the view, with a little margin
	local distance = radius / math.sin(math.rad(FOV / 2)) * 1.05
	camera.CFrame = CFrame.new(center.Position) * VIEW * CFrame.new(0, 0, -distance) * CFrame.Angles(0, math.pi, 0)
	camera.Parent = frame
	frame.CurrentCamera = camera
	return frame
end

return ArtIcons
