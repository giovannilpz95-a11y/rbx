--!strict
-- Places a decoration (its look comes from FarmShared.Art.Decor). Each build returns a Model
-- whose invisible "Root" part covers the footprint and carries Interact = "Decor"; visible
-- parts hang under Root so a tap on them finds it.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtDecor = require(Shared.Art.Decor)
local ArtMerge = require(Shared.Art.Merge)
local Decor = require(Shared.Config.Decor)
local DecorRules = require(Shared.DecorRules)

local DecorModels = {}

-- origin: the footprint centre on the ground, already turned. index: the save slot.
function DecorModels.build(id: string, origin: CFrame, index: number): Model
	local def = DecorRules.def(id) -- a shop decoration or a Gold trophy
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
	ArtDecor.build(id, root, origin)
	return model
end

-- Once `model` is in the world, union its look into one part in the background (Art/Merge).
function DecorModels.merge(model: Model)
	local root = model.PrimaryPart
	if root then
		task.spawn(ArtMerge.mergeUnder, root)
	end
end

return DecorModels
