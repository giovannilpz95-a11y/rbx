--!strict
-- Walk-first "Reach + Errands" interaction (Design/15 3D World & Avatar Play §1, §3):
--   * tap/click anything on your plot within Reach and it happens right away;
--   * tap something farther away and the avatar auto-walks there (at sprint speed), then acts;
--   * hold the action button (E / touch button / gamepad X) to sweep: harvest ready beds in
--     front of you, or sow your last seed into empty beds you walk over;
--   * walk past the Bakery's output table to collect finished goods.
-- Objects in Reach get a soft outline. The context label on the action button stands in
-- for the auto-equipped tool (scythe / seed bag / hands).

local ContextActionService = game:GetService("ContextActionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Balance = require(Shared.Config.Balance)
local Crops = require(Shared.Config.Crops)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Parent.UI.Hud)
local Panels = require(script.Parent.Parent.UI.Panels)

local ReachController = {}

local player = Players.LocalPlayer
local plot: Model? = nil
local interactives: { BasePart } = {}
local highlights: { [BasePart]: Highlight } = {}
local pendingFields: { [string]: number } = {} -- fieldId -> os.clock() of the last intent
local lastCollectAt = 0
local walkToken = 0
local actionHeld = false
local MIN_ARRIVE = 6 -- with Reach 0 the avatar still has to stand next to the target

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Horizontal distance from a point to the nearest edge of a part's footprint.
local function distanceToPart(part: BasePart, point: Vector3): number
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local clamped =
		Vector3.new(math.clamp(localPoint.X, -half.X, half.X), localPoint.Y, math.clamp(localPoint.Z, -half.Z, half.Z))
	local offset = part.CFrame:PointToWorldSpace(clamped) - point
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

local function reach(): number
	return math.max(ClientStore.settings.reach, MIN_ARRIVE)
end

local function inReach(part: BasePart): boolean
	local root = rootPart()
	return root ~= nil and distanceToPart(part, root.Position) <= reach()
end

local function interactiveFrom(instance: Instance?): BasePart?
	while instance and instance ~= plot and instance ~= Workspace do
		if instance:IsA("BasePart") and instance:GetAttribute("Interact") ~= nil then
			return instance
		end
		instance = instance.Parent
	end
	return nil
end

local function fieldState(fieldId: string): string
	local state = ClientStore.state
	local field = state and state.fields[fieldId]
	if field == nil then
		return "unknown"
	elseif field.crop == nil then
		return "empty"
	elseif Timer.isReady(field.readyAt, ClientStore.now()) then
		return "ready"
	end
	return "growing"
end

local function recentlySent(fieldId: string): boolean
	local sentAt = pendingFields[fieldId]
	return sentAt ~= nil and os.clock() - sentAt < 1.5
end

local function sendField(remote: string, fieldId: string, ...: any)
	pendingFields[fieldId] = os.clock()
	Remotes.fire(remote, fieldId, ...)
end

local function canAffordSeed(cropId: string): boolean
	local state = ClientStore.state
	local crop = Crops[cropId]
	return state ~= nil and crop ~= nil and state.level >= crop.unlockLevel and state.currencies.Coins >= crop.seedCost
end

---------------------------------------------------------------------------------------------
-- Acting on one target (it's already in reach)
---------------------------------------------------------------------------------------------

local function act(part: BasePart)
	local kind = part:GetAttribute("Interact")
	if kind == "Field" then
		local fieldId = part:GetAttribute("FieldId") :: string
		local status = fieldState(fieldId)
		if status == "ready" then
			if not recentlySent(fieldId) then
				sendField("Farm_Harvest", fieldId)
			end
		elseif status == "empty" then
			Panels.open("Seeds", fieldId)
		elseif status == "growing" then
			local field = (ClientStore.state :: any).fields[fieldId]
			Hud.toast(
				string.format(
					"%s: %s left",
					Crops[field.crop].displayName,
					Timer.format(Timer.remaining(field.readyAt, ClientStore.now()))
				)
			)
		end
	elseif kind == "FactoryOutput" then
		Remotes.fire("Factory_Collect", part:GetAttribute("FactoryId"))
	elseif kind == "Factory" then
		Panels.open(part:GetAttribute("FactoryId") :: string)
	elseif kind == "Barn" then
		Panels.open("Barn")
	elseif kind == "OrderBoard" then
		Panels.open("Orders")
	end
end

---------------------------------------------------------------------------------------------
-- Auto-walk ("errand") to a target beyond reach
---------------------------------------------------------------------------------------------

local function playerIsSteering(): boolean
	local ok, moving = pcall(function()
		local playerModule =
			require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		return playerModule:GetControls():GetMoveVector().Magnitude > 0.1
	end)
	return ok and moving == true
end

local function cancelWalk()
	walkToken += 1
end

local function autoWalk(target: BasePart, onArrive: () -> ())
	local root, hum = rootPart(), humanoid()
	if root == nil or hum == nil then
		return
	end
	walkToken += 1
	local token = walkToken

	-- Aim for a spot just outside the target's footprint, on the side facing us.
	local localPoint = target.CFrame:PointToObjectSpace(root.Position)
	local half = target.Size / 2
	local edge = target.CFrame:PointToWorldSpace(
		Vector3.new(math.clamp(localPoint.X, -half.X, half.X), 0, math.clamp(localPoint.Z, -half.Z, half.Z))
	)
	local away = Vector3.new(root.Position.X - edge.X, 0, root.Position.Z - edge.Z)
	local goal = edge + (if away.Magnitude > 0.01 then away.Unit * 3 else Vector3.zero)

	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(function()
			path:ComputeAsync(root.Position, goal)
		end)
		local waypoints = if ok and path.Status == Enum.PathStatus.Success then path:GetWaypoints() else {}
		local points: { Vector3 } = {}
		for i, waypoint in waypoints do
			if i > 1 then
				table.insert(points, waypoint.Position)
			end
		end
		if #points == 0 then
			points = { goal }
		end

		hum.WalkSpeed = Balance.sprintSpeed
		local arrived = inReach(target)
		for _, point in points do
			if arrived or token ~= walkToken then
				break
			end
			hum:MoveTo(point)
			local started = os.clock()
			while token == walkToken and os.clock() - started < 3 do
				if inReach(target) then
					arrived = true
					break
				end
				local offset = rootPart() and (rootPart() :: BasePart).Position - point or Vector3.zero
				if Vector3.new(offset.X, 0, offset.Z).Magnitude < 2 then
					break
				end
				if os.clock() - started > 0.2 and playerIsSteering() then
					cancelWalk()
					break
				end
				task.wait(0.05)
			end
		end

		if token == walkToken then
			local current = rootPart()
			if current then
				hum:MoveTo(current.Position)
			end
			if inReach(target) then
				onArrive()
			end
		end
		ReachController.applySpeed()
	end)
end

---------------------------------------------------------------------------------------------
-- Taps and the action button
---------------------------------------------------------------------------------------------

local function handleTap(screenPosition: Vector2)
	if plot == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = result and interactiveFrom(result.Instance)
	if target == nil or not target:IsDescendantOf(plot :: Model) then
		return
	end
	Panels.close()
	if inReach(target) then
		cancelWalk()
		act(target)
	else
		autoWalk(target, function()
			act(target)
		end)
	end
end

-- One swing of the context action. Returns true if it did something.
local function sweep(firstPress: boolean): boolean
	local root = rootPart()
	if root == nil or plot == nil then
		return false
	end
	local front = root.Position + root.CFrame.LookVector * 3
	local did = false

	-- Scythe: every ready bed in the arc in front of you
	for _, part in interactives do
		if part:GetAttribute("Interact") == "Field" then
			local fieldId = part:GetAttribute("FieldId") :: string
			if
				fieldState(fieldId) == "ready"
				and not recentlySent(fieldId)
				and distanceToPart(part, front) <= Balance.harvestArcStuds
			then
				sendField("Farm_Harvest", fieldId)
				did = true
			end
		end
	end
	if did then
		return true
	end

	-- Seed bag: empty beds you're standing on or next to get your last seed
	local seed = ClientStore.state and ClientStore.state.settings.lastSeed
	if seed and canAffordSeed(seed) then
		for _, part in interactives do
			if part:GetAttribute("Interact") == "Field" then
				local fieldId = part:GetAttribute("FieldId") :: string
				if
					fieldState(fieldId) == "empty"
					and not recentlySent(fieldId)
					and distanceToPart(part, root.Position) <= Balance.plantRadiusStuds
				then
					sendField("Farm_Plant", fieldId, seed)
					did = true
				end
			end
		end
	end
	if did then
		return true
	end

	-- Hands: on a fresh press, use the nearest thing in reach (opens its panel, collects...)
	if firstPress then
		local best, bestDistance = nil, math.huge
		for _, part in interactives do
			local d = distanceToPart(part, root.Position)
			if d <= reach() and d < bestDistance and part:GetAttribute("Interact") ~= "Field" then
				best, bestDistance = part, d
			end
		end
		if best then
			act(best)
			return true
		end
	end
	return false
end

local function setActionHeld(pressed: boolean)
	if pressed == actionHeld then
		return
	end
	actionHeld = pressed
	if not pressed then
		return
	end
	cancelWalk()
	task.spawn(function()
		local first = true
		while actionHeld do
			sweep(first)
			first = false
			task.wait(Balance.sweepInterval)
		end
	end)
end
ReachController.setActionHeld = setActionHeld

---------------------------------------------------------------------------------------------
-- Per-frame-ish upkeep: outlines, the context label, walk-by collect
---------------------------------------------------------------------------------------------

local function contextLabel(root: BasePart): string
	local front = root.Position + root.CFrame.LookVector * 3
	local nearEmpty = false
	for _, part in interactives do
		if part:GetAttribute("Interact") == "Field" then
			local status = fieldState(part:GetAttribute("FieldId") :: string)
			if status == "ready" and distanceToPart(part, front) <= Balance.harvestArcStuds then
				return "Scythe"
			elseif status == "empty" and distanceToPart(part, root.Position) <= Balance.plantRadiusStuds + 4 then
				nearEmpty = true
			end
		end
	end
	return if nearEmpty then "Seeds" else "Use"
end

local function upkeep()
	local root = rootPart()
	if root == nil or plot == nil then
		return
	end
	for _, part in interactives do
		local highlight = highlights[part]
		if highlight == nil then
			highlight = Instance.new("Highlight")
			highlight.FillTransparency = 1
			highlight.OutlineColor = Color3.fromRGB(255, 240, 160)
			highlight.OutlineTransparency = 0.2
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Adornee = part
			highlight.Parent = part
			highlights[part] = highlight
		end
		highlight.Enabled = distanceToPart(part, root.Position) <= reach()
	end
	Hud.setActionLabel(contextLabel(root))

	-- Walk-by collect at the Bakery's output table
	local preview = ClientStore.factoryPreview("Bakery")
	if preview and preview.outputCount > 0 and os.clock() - lastCollectAt > 1 then
		for _, part in interactives do
			if
				part:GetAttribute("Interact") == "FactoryOutput"
				and distanceToPart(part, root.Position) <= Balance.magnetStuds
			then
				lastCollectAt = os.clock()
				Remotes.fire("Factory_Collect", part:GetAttribute("FactoryId"))
			end
		end
	end
end

local function collectInteractives()
	table.clear(interactives)
	if plot == nil then
		return
	end
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("Interact") ~= nil then
			table.insert(interactives, descendant)
		end
	end
end

function ReachController.applySpeed()
	local hum = humanoid()
	if hum then
		hum.WalkSpeed = if ClientStore.settings.sprinting then Balance.sprintSpeed else ClientStore.settings.walkSpeed
	end
end

function ReachController.setPlot(model: Model)
	plot = model
	table.clear(highlights)
	collectInteractives()
	model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and descendant:GetAttribute("Interact") ~= nil then
			table.insert(interactives, descendant)
		end
	end)
end

function ReachController.init()
	Panels.canCollect = function(factoryId: string): boolean
		local root = rootPart()
		if root == nil then
			return false
		end
		for _, part in interactives do
			if part:GetAttribute("Interact") == "FactoryOutput" and part:GetAttribute("FactoryId") == factoryId then
				return distanceToPart(part, root.Position) <= reach()
			end
		end
		return false
	end

	-- Mouse: a click (not a camera drag) on the world
	local downAt: Vector2? = nil
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			downAt = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and downAt and not processed then
			local up = Vector2.new(input.Position.X, input.Position.Y)
			if (up - downAt).Magnitude < 8 then
				handleTap(up)
			end
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			downAt = nil
		end
	end)
	-- Touch: a tap on the world (drags rotate the camera as usual)
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not processedByUI then
			handleTap(position)
		end
	end)

	-- Action: E on keyboard, X on gamepad; the touch button lives in the HUD
	ContextActionService:BindAction("FarmAction", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			setActionHeld(true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			setActionHeld(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

	task.spawn(function()
		while true do
			task.wait(0.15)
			upkeep()
		end
	end)
end

return ReachController
