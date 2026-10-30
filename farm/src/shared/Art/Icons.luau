--!strict
-- Item icons for the UI: each item's 3D prop (ArtItemProps) in a ViewportFrame, lit from the
-- same upper-left angle and seen from the same three-quarter view, so every icon matches
-- (Design/12 Art & Audio Direction, Item Icons). Client-side only.
--
--   local icon = ArtIcons.viewport("Bread", 48)
--   icon.Parent = someFrame

local ArtAnimals = require("./Animals")
local ArtCommunity = require("./Community")
local ArtDecor = require("./Decor")
local ArtFactories = require("./Factories")
local ArtHouses = require("./Houses")
local ArtItemProps = require("./ItemProps")

local ArtIcons = {}

local VIEW = CFrame.Angles(0, math.rad(-28), 0) * CFrame.Angles(math.rad(24), 0, 0) -- three-quarter, slightly above
local FOV = 30

local function newFrame(name: string, size: number?): ViewportFrame
	local frame = Instance.new("ViewportFrame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = if size then UDim2.fromOffset(size, size) else UDim2.fromScale(1, 1)
	frame.Ambient = Color3.fromRGB(190, 180, 170)
	frame.LightColor = Color3.fromRGB(255, 246, 229)
	frame.LightDirection = Vector3.new(1, -1.4, 0.8) -- from the upper left, toward the back
	return frame
end

-- Put `model` in `frame` with a camera that just fits it, from the shared three-quarter view.
local function fit(frame: ViewportFrame, model: Model)
	model.Parent = frame
	local center, extents = model:GetBoundingBox()
	local radius = extents.Magnitude / 2

	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	-- Far enough that the prop's bounding sphere just fits the view, with a little margin
	local distance = radius / math.sin(math.rad(FOV / 2)) * 1.05
	camera.CFrame = CFrame.new(center.Position) * VIEW * CFrame.new(0, 0, -distance) * CFrame.Angles(0, math.pi, 0)
	camera.Parent = frame
	frame.CurrentCamera = camera
end

-- A square, transparent ViewportFrame of `size` pixels (or scale 1 when size is nil) showing
-- the prop for `id`.
function ArtIcons.viewport(id: string, size: number?): ViewportFrame
	local frame = newFrame(id .. "Icon", size)
	fit(frame, ArtItemProps.build(id))
	return frame
end

-- A picture of a building for the build menu (UI Reference & Gaps G4), from the same models
-- the plot uses: kind "Factory", "House", "Community" or "Decor", or "Pen" (one of its
-- animals). These are bigger than item props (up to ~80 parts), so callers keep them.
function ArtIcons.building(kind: string, id: string, size: number?): ViewportFrame
	local frame = newFrame(id .. "Picture", size)
	local model = Instance.new("Model")
	model.Name = id
	if kind == "Factory" then
		ArtFactories.build(id, model, CFrame.new())
	elseif kind == "House" then
		ArtHouses.build(id, model, CFrame.new())
	elseif kind == "Community" then
		ArtCommunity.build(id, model, CFrame.new())
	elseif kind == "Decor" then
		ArtDecor.build(id, model, CFrame.new())
	elseif kind == "Pen" then
		model = ArtAnimals.animal(id, CFrame.new())
	end
	fit(frame, model)
	return frame
end

return ArtIcons
