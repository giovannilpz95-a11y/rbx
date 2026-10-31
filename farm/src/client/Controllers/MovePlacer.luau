--!strict
-- Move mode (the free-placement sandbox, shared/Layout): the HUD's Move button (or M) turns it
-- on, then tapping one of your buildings picks it up. Its footprint ghost sits on the grid in
-- front of your avatar and follows you, green where it fits and red where it doesn't, while
-- the building itself fades. Place / Turn / Cancel at the bottom; the server checks again.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Layout = require(Shared.Layout)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Parent.UI.Hud)
local Ui = require(script.Parent.Parent.UI.Ui)

local MovePlacer = {}

local player = Players.LocalPlayer
local plot: Model? = nil
local gui: ScreenGui
local banner: Frame
local bar: Frame
local ghost: Part
local editing = false -- Move mode is on: a tap picks a building up
local active: string? = nil -- the key of the building being moved
local moving: Instance? = nil -- its model, faded while it's picked up
local turns = 0
local spot: { x: number, z: number, ok: boolean, reason: string? } = { x = 0, z = 0, ok = false, reason = nil }

local function fade(model: Instance?, amount: number)
	if model == nil then
		return
	end
	local parts = if model:IsA("BasePart") then { model } else {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in parts do
		(p :: BasePart).LocalTransparencyModifier = amount
	end
end

-- Is anything of ours in the footprint, other than the building being moved?
local function blockedHere(origin: CFrame, kind: string, x: number, z: number, r: number): boolean
	if plot == nil then
		return true
	end
	local cx, cz, w, d = Layout.box(kind, x, z, r)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plot :: Model }
	local hits =
		Workspace:GetPartBoundsInBox(origin * CFrame.new(cx, 3.3, cz), Vector3.new(w - 0.4, 5.4, d - 0.4), params)
	for _, hit in hits do
		local mine = moving ~= nil and (hit == moving or hit:IsDescendantOf(moving :: Instance))
		if not mine and hit:FindFirstAncestor("Land") == nil and hit:FindFirstAncestor("ScaffoldPop") == nil then
			return true
		end
	end
	return false
end

local function update()
	local key = active
	local state = ClientStore.state
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = plot and plot:GetAttribute("PlotOrigin") :: CFrame?
	local kind = Layout.parse(key)
	if key == nil or kind == nil or root == nil or origin == nil or state == nil then
		ghost.Parent = nil
		return
	end
	local r = turns * 90
	local w, d, ox, oz = Layout.footprint(kind, r)
	-- The footprint's near edge sits a few studs in front of the avatar
	local ahead = math.max(w, d) / 2 + 4
	local wanted = origin:PointToObjectSpace(root.Position + root.CFrame.LookVector * ahead)
	local x, z = Layout.snap(wanted.X - ox), Layout.snap(wanted.Z - oz)
	local fits, reason = Layout.canMove(state, key, x, z, r, ClientStore.now())
	if fits and blockedHere(origin, kind, x, z, r) then
		fits, reason = false, "Something is already there"
	end
	spot.x, spot.z, spot.ok, spot.reason = x, z, fits, reason
	ghost.Size = Vector3.new(w - 0.2, 0.3, d - 0.2)
	ghost.CFrame = origin * CFrame.new(x + ox, 0.45, z + oz)
	ghost.Color = if fits then Ui.colors.ready else Ui.colors.danger
	ghost.Parent = Workspace
end

local function stopMoving()
	fade(moving, 0)
	active = nil
	moving = nil
	bar.Visible = false
	ghost.Parent = nil
	banner.Visible = editing
end

function MovePlacer.isEditing(): boolean
	return editing
end

function MovePlacer.setEditing(on: boolean)
	editing = on
	if not on then
		stopMoving()
	end
	banner.Visible = on and active == nil
end

function MovePlacer.toggle()
	MovePlacer.setEditing(not editing)
end

-- The building a tapped part belongs to (one of ours with a LayoutKey), and its model
local function buildingAt(instance: Instance?): (string?, Instance?)
	local node = instance
	while node and node ~= plot and node ~= Workspace do
		local key = node:GetAttribute("LayoutKey")
		if type(key) == "string" then
			return key, node
		end
		node = node.Parent
	end
	return nil, nil
end

-- Called with whatever a tap hit while Move mode is on. Returns true when it used the tap.
function MovePlacer.tap(instance: Instance?): boolean
	if not editing then
		return false
	end
	if active ~= nil then
		return true -- one at a time: Place or Cancel first
	end
	local key, model = buildingAt(instance)
	if key == nil or plot == nil or not (model :: Instance):IsDescendantOf(plot :: Model) then
		Hud.toast("Tap one of your buildings to move it")
		return true
	end
	active = key
	moving = model
	turns = 0
	local state = ClientStore.state
	local saved = state and state.layout and state.layout[key]
	if saved then
		turns = (saved.r // 90) % 4
	end
	fade(model, 0.6)
	banner.Visible = false
	bar.Visible = true
	update()
	return true
end

function MovePlacer.setPlot(model: Model)
	plot = model
end

function MovePlacer.init()
	gui = Ui.new("ScreenGui", {
		Name = "FarmMovePlacer",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	banner = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(420, 44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { Ui.list(8, true) })
	Ui.label("Move mode: tap a building to pick it up", {
		Size = UDim2.fromOffset(300, 40),
		TextSize = 15,
		TextWrapped = true,
		BackgroundTransparency = 0.15,
		BackgroundColor3 = Ui.colors.panel,
		LayoutOrder = 1,
		Parent = banner,
	})
	Ui.button("Done", function()
		MovePlacer.setEditing(false)
	end, { Size = UDim2.fromOffset(100, 40), LayoutOrder = 2, Parent = banner })

	-- Above the HUD button row and the guide card, like the decoration placer's bar
	bar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -176),
		Size = UDim2.fromOffset(330, 44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { Ui.list(8, true) })
	Ui.button("Place", function()
		local key = active
		if key and spot.ok then
			Remotes.fire("Layout_Move", key, spot.x, spot.z, turns * 90)
			stopMoving()
		elseif key then
			Hud.toast(string.format("Can't place here. %s.", spot.reason or "Walk to an open spot on your land"))
		end
	end, { Size = UDim2.fromOffset(100, 40), LayoutOrder = 1, Parent = bar })
	Ui.button("Turn", function()
		turns = (turns + 1) % 4
	end, { Size = UDim2.fromOffset(100, 40), LayoutOrder = 2, BackgroundColor3 = Ui.colors.selected, Parent = bar })
	Ui.button("Cancel", stopMoving, {
		Size = UDim2.fromOffset(100, 40),
		LayoutOrder = 3,
		BackgroundColor3 = Ui.colors.danger,
		Parent = bar,
	})

	ghost = Instance.new("Part")
	ghost.Name = "MoveGhost"
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

return MovePlacer
