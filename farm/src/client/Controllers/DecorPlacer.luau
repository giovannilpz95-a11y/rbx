--!strict
-- Placing a decoration (Design/07 Town Building, walk-first): a ghost of its footprint
-- sits on the grid just in front of your avatar and follows you; green where it fits, red
-- where it doesn't. Place / Turn / Cancel buttons at the bottom. The server checks again.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Decor = require(Shared.Config.Decor)
local DecorRules = require(Shared.DecorRules)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Ui = require(script.Parent.Parent.UI.Ui)

local DecorPlacer = {}

local player = Players.LocalPlayer
local plot: Model? = nil
local gui: ScreenGui
local bar: Frame
local ghost: Part
local active: string? = nil
local turns = 0
local spot = { x = 0, z = 0, ok = false }
local AHEAD = 8 -- studs in front of the avatar

local function blockedHere(origin: CFrame, w: number, d: number): boolean
	if plot == nil then
		return true
	end
	local include = {}
	for _, child in plot:GetChildren() do
		if child.Name ~= "Placed" then
			table.insert(include, child)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	return #Workspace:GetPartBoundsInBox(
			origin * CFrame.new(0, 3.05, 0),
			Vector3.new(w - 0.4, 5.4, d - 0.4),
			params
		) > 0
end

local function update()
	local id = active
	local state = ClientStore.state
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = plot and plot:GetAttribute("PlotOrigin") :: CFrame?
	if id == nil or root == nil or origin == nil or state == nil then
		ghost.Parent = nil
		return
	end
	local wanted = origin:PointToObjectSpace(root.Position + root.CFrame.LookVector * AHEAD)
	local x, z = DecorRules.snap(id, turns, wanted.X, wanted.Z)
	local w, d = DecorRules.footprint(id, turns)
	local p = { id = id, x = x, z = z, r = turns }
	local at = origin * CFrame.new(x, 0.25, z)
	local fits = DecorRules.canPlace(state, p, ClientStore.now())
		and not blockedHere(at, w * Decor.tile, d * Decor.tile)
	spot.x, spot.z, spot.ok = x, z, fits
	ghost.Size = Vector3.new(w * Decor.tile - 0.2, 0.3, d * Decor.tile - 0.2)
	ghost.CFrame = at * CFrame.new(0, 0.2, 0)
	ghost.Color = if fits then Ui.colors.ready else Ui.colors.danger
	ghost.Parent = Workspace
end

function DecorPlacer.isActive(): boolean
	return active ~= nil
end

function DecorPlacer.stop()
	active = nil
	bar.Visible = false
	ghost.Parent = nil
end

function DecorPlacer.start(id: string)
	active = id
	turns = 0
	bar.Visible = true
	update()
end

function DecorPlacer.setPlot(model: Model)
	plot = model
end

function DecorPlacer.init()
	gui = Ui.new("ScreenGui", {
		Name = "FarmDecorPlacer",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	bar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(330, 44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { Ui.list(8, true) })
	Ui.button("Place", function()
		if active and spot.ok then
			Remotes.fire("Decor_Place", active, spot.x, spot.z, turns)
			DecorPlacer.stop()
		end
	end, { Size = UDim2.fromOffset(100, 40), LayoutOrder = 1, Parent = bar })
	Ui.button("Turn", function()
		turns = (turns + 1) % 4
	end, { Size = UDim2.fromOffset(100, 40), LayoutOrder = 2, BackgroundColor3 = Ui.colors.selected, Parent = bar })
	Ui.button("Cancel", DecorPlacer.stop, {
		Size = UDim2.fromOffset(100, 40),
		LayoutOrder = 3,
		BackgroundColor3 = Ui.colors.danger,
		Parent = bar,
	})

	ghost = Instance.new("Part")
	ghost.Name = "DecorGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.Transparency = 0.45
	ghost.Material = Enum.Material.Neon

	RunService.RenderStepped:Connect(function()
		if active then
			update()
		end
	end)
end

return DecorPlacer
