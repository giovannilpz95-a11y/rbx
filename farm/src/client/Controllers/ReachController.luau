--!strict
-- Walk-first "Reach + Errands" interaction (Design/15 3D World & Avatar Play §1, §3):
--   * tap/click anything on your plot within Reach and it happens right away;
--   * tap something farther away and the avatar auto-walks there (at sprint speed), then acts;
--   * hold the action button (E / touch button / gamepad X) to sweep: harvest ready beds in
--     front of you, or sow your last seed into empty beds you walk over;
--   * walk past a factory's output table to collect finished goods;
--   * tap a pen (or use the action button next to it) to collect products, then feed.
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
local Animals = require(Shared.Config.Animals)
local Crops = require(Shared.Config.Crops)
local Pen = require(Shared.Pen)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local HeldTools = require(script.Parent.HeldTools)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Parent.UI.Hud)
local Panels = require(script.Parent.Parent.UI.Panels)

local ReachController = {}

local player = Players.LocalPlayer
local plot: Model? = nil
local interactives: { BasePart } = {}
local highlights: { [BasePart]: Highlight } = {}
local pendingFields: { [string]: number } = {} -- fieldId or "pen:<id>" -> os.clock() of the last intent
local lastCollectAt = 0
local walkToken = 0
local actionHeld = false
local MIN_ARRIVE = 6 -- with Reach 0 the avatar still has to stand next to the target

-- Set by the social controls: what a tap on something off our plot does (nil: nothing), and
-- whether the avatar must walk into reach first.
ReachController.otherTarget = function(_part: BasePart): ((() -> ())?, boolean)
	return nil, false
end

-- Crop Pop, at the next level's pre-level window (UI Reference & Gaps G14): the Puzzle Porch
-- on our plot and in the Town Square. Crop Pop's client listens on this BindableEvent.
-- Set by Move mode (MovePlacer): returns true when it used a tap
ReachController.tapOverride = function(_hit: Instance?): boolean
	return false
end

-- Set by the Market panel (UI/Market): a tap on our own stall
ReachController.openMarket = function() end

function ReachController.openCropPop()
	local event = ReplicatedStorage:FindFirstChild("CropPopOpen")
	if event == nil then
		local created = Instance.new("BindableEvent")
		created.Name = "CropPopOpen"
		created.Parent = ReplicatedStorage
		event = created
	end
	(event :: BindableEvent):Fire("next")
end

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

-- What the avatar holds while doing it (HeldTools)
local HELD_FOR = { Farm_Harvest = "Tool_Scythe", Farm_Plant = "Tool_SeedBag" } :: { [string]: string }

local function sendField(remote: string, key: string, ...: any)
	pendingFields[key] = os.clock()
	local tool = HELD_FOR[remote]
	if tool then
		HeldTools.flash(tool)
	end
	if key:sub(1, 4) == "pen:" then
		Remotes.fire(remote, key:sub(5), ...)
	else
		Remotes.fire(remote, key, ...)
	end
end

-- What a tap on a pen does now: "collect", "feed", or "panel" (nothing to do by hand).
local function penAction(penId: string): string
	local state = ClientStore.state
	local pen = state and state.pens[penId]
	local def = Animals.pens[penId]
	if pen == nil or def == nil or not Pen.isOperational(pen, ClientStore.now()) then
		return "panel"
	end
	local counts = Pen.counts(pen, ClientStore.now())
	if counts.ready > 0 then
		return "collect"
	elseif counts.hungry > 0 and ((pen.feedLeft or 0) > 0 or ClientStore.itemCount(def.feed) > 0) then
		return "feed"
	end
	return "panel"
end

local function usePen(penId: string, openPanel: boolean): boolean
	local key = "pen:" .. penId
	local action = penAction(penId)
	if action == "panel" then
		if openPanel then
			Panels.open("Pen", penId)
		end
		return openPanel
	end
	if recentlySent(key) then
		return true
	end
	sendField(if action == "collect" then "Pen_Collect" else "Pen_Feed", key)
	return true
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
			Panels.open("Field", fieldId) -- time left, and a Gem speed-up
		end
	elseif kind == "Pen" then
		usePen(part:GetAttribute("PenId") :: string, true)
	elseif kind == "FactoryOutput" then
		Remotes.fire("Factory_Collect", part:GetAttribute("FactoryId"))
	elseif kind == "Factory" then
		Panels.open(part:GetAttribute("FactoryId") :: string)
	elseif kind == "Barn" or kind == "PrizeShelf" then
		Panels.open("Barn")
	elseif kind == "Town" then
		Panels.open("Town")
	elseif kind == "Decor" then
		Panels.open("Decor", tostring(part:GetAttribute("DecorIndex")))
	elseif kind == "OrderBoard" then
		Panels.open("Orders")
	elseif kind == "PuzzlePorch" then
		ReachController.openCropPop()
	elseif kind == "Quarry" then
		Panels.open("Quarry")
	elseif kind == "Market" then
		ReachController.openMarket()
	elseif kind == "Guild" then
		Panels.open("Guild")
	elseif kind == "Harbor" then
		Panels.open("Harbor")
	elseif kind == "HarborDrift" then
		Remotes.fire("Harbor_Drift")
	elseif kind == "HarborBoat" then
		-- A boat that's back unloads straight away; otherwise the panel
		local index = part:GetAttribute("Boat")
		local harbor = ClientStore.state and ClientStore.state.harbor
		local boat = harbor and harbor.boats[index]
		if boat and boat.returnAt and ClientStore.now() >= boat.returnAt then
			Remotes.fire("Harbor_Unload", index)
		else
			Panels.open("Harbor")
		end
	elseif kind == "Blimp" then
		Panels.open("Blimp")
	elseif kind == "BlimpCrate" then
		-- Load it straight from the Barn when there's enough; otherwise show the panel
		local row, slot = part:GetAttribute("Row"), part:GetAttribute("Slot")
		local load = ClientStore.state and ClientStore.state.blimp and ClientStore.state.blimp.load
		local cells = load and load.rows[row]
		local crate = cells and cells[slot]
		if crate and crate.filledBy == nil and ClientStore.itemCount(crate.item) >= crate.qty then
			Remotes.fire("Blimp_Fill", row, slot)
		else
			Panels.open("Blimp")
		end
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
	-- Move mode takes the tap first (it picks up whole buildings, not just their tap targets)
	if ReachController.tapOverride(if result then result.Instance else nil) then
		return
	end
	local target = result and interactiveFrom(result.Instance)
	if target == nil then
		return
	end
	-- Anything off our own plot (the Town Square boards, a neighbor's fields) belongs to the
	-- social controls, which say what a tap does and whether it needs the avatar close by.
	local action: () -> () = function()
		act(target)
	end
	if not target:IsDescendantOf(plot :: Model) then
		local other, handsOn = ReachController.otherTarget(target)
		if other == nil then
			return
		elseif not handsOn then
			cancelWalk()
			other()
			return
		end
		action = other
	end
	Panels.close()
	if inReach(target) then
		cancelWalk()
		action()
	else
		autoWalk(target, action)
	end
end

-- The nearest non-field thing on our plot in reach (a building, a pen, a crate), and how far
local function nearestHands(root: BasePart): (BasePart?, number)
	local best, bestDistance = nil, math.huge
	for _, part in interactives do
		local d = distanceToPart(part, root.Position)
		if d <= reach() and d < bestDistance and part:GetAttribute("Interact") ~= "Field" then
			best, bestDistance = part, d
		end
	end
	return best, bestDistance
end

-- How far the nearest bed a swing would work on is (ready in the arc, or empty and sowable)
local function nearestBedWork(root: BasePart): number
	local front = root.Position + root.CFrame.LookVector * 3
	local seed = ClientStore.state and ClientStore.state.settings.lastSeed
	local sow = seed ~= nil and canAffordSeed(seed)
	local nearest = math.huge
	for _, part in interactives do
		if part:GetAttribute("Interact") == "Field" then
			local status = fieldState(part:GetAttribute("FieldId") :: string)
			local works = (status == "ready" and distanceToPart(part, front) <= Balance.harvestArcStuds)
				or (sow and status == "empty" and distanceToPart(part, root.Position) <= Balance.plantRadiusStuds)
			if works then
				nearest = math.min(nearest, distanceToPart(part, root.Position))
			end
		end
	end
	return nearest
end

-- Standing right at a building (a door, an office, a crate) with beds a few studs off: a fresh
-- press uses the building, not the beds (holding on still sweeps the beds). The building wins
-- within HANDS_FIRST_STUDS unless a bed is nearer by more than HANDS_BONUS_STUDS, so the
-- strip between a door and the bed row in front of it counts as the door.
local HANDS_FIRST_STUDS = 6
local HANDS_BONUS_STUDS = 3.5

local function handsFirst(root: BasePart): BasePart?
	local hands, handsDistance = nearestHands(root)
	if hands and handsDistance <= HANDS_FIRST_STUDS and handsDistance - HANDS_BONUS_STUDS < nearestBedWork(root) then
		return hands
	end
	return nil
end

-- One swing of the context action. Returns true if it did something.
local function sweep(firstPress: boolean): boolean
	local root = rootPart()
	if root == nil or plot == nil then
		return false
	end
	local front = root.Position + root.CFrame.LookVector * 3
	local did = false

	if firstPress then
		local hands = handsFirst(root)
		if hands then
			act(hands)
			return true
		end
	end

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

	-- Basket / feed bucket: a pen you're standing next to
	for _, part in interactives do
		if
			part:GetAttribute("Interact") == "Pen"
			and distanceToPart(part, root.Position) <= Balance.plantRadiusStuds
		then
			if usePen(part:GetAttribute("PenId") :: string, false) then
				return true
			end
		end
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
		local best, bestDistance = nearestHands(root)
		if best then
			act(best)
			return true
		end
		-- Off our plot (the Town Square, a neighbour's farm): the nearest thing in reach that
		-- the social controls handle, the same as tapping it
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { plot :: Model, player.Character :: Instance }
		for _, part in Workspace:GetPartBoundsInRadius(root.Position, reach() + 4, params) do
			local d = distanceToPart(part, root.Position)
			if part:GetAttribute("Interact") ~= nil and d <= reach() and d < bestDistance then
				best, bestDistance = part, d
			end
		end
		if best then
			local other = ReachController.otherTarget(best)
			if other then
				other()
				return true
			end
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
	if handsFirst(root) then
		return "Use"
	end
	local front = root.Position + root.CFrame.LookVector * 3
	local nearEmpty = false
	for _, part in interactives do
		if
			part:GetAttribute("Interact") == "Pen"
			and distanceToPart(part, root.Position) <= Balance.plantRadiusStuds
		then
			local action = penAction(part:GetAttribute("PenId") :: string)
			if action == "collect" then
				return "Basket"
			elseif action == "feed" then
				return "Feed"
			end
		end
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

	-- Walk-by collect at any output table with goods on it
	if os.clock() - lastCollectAt > 1 then
		for _, part in interactives do
			if
				part:GetAttribute("Interact") == "FactoryOutput"
				and distanceToPart(part, root.Position) <= Balance.magnetStuds
			then
				local factoryId = part:GetAttribute("FactoryId") :: string
				local preview = ClientStore.factoryPreview(factoryId)
				if preview and preview.outputCount > 0 then
					lastCollectAt = os.clock()
					Remotes.fire("Factory_Collect", factoryId)
				end
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
	-- Rebuilt models (crates under the Cargo Blimp, a finished building) leave their old parts
	-- behind: drop them, or a press could pick one that isn't there any more
	model.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			local index = table.find(interactives, descendant)
			if index then
				table.remove(interactives, index)
			end
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
	Panels.nearPen = function(penId: string): boolean
		local root = rootPart()
		if root == nil then
			return false
		end
		for _, part in interactives do
			if part:GetAttribute("Interact") == "Pen" and part:GetAttribute("PenId") == penId then
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
