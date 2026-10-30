--!strict
-- The social HUD and the Neighbors panel (Design/14 Multiplayer Features A1, A2; Design/08
-- Social & Events "Visiting Plots"):
--   * Friends Nearby: a column of your friends on this server down the left edge; tap one to
--     visit their farm. An Invite button sits under it where Roblox allows game invites.
--   * Neighbors (N, or the Neighbors board in the Town Square): everyone on the server with
--     their level and where they are, Visit buttons, Send home for visitors on your farm, your
--     farm's visitor and helper settings, and the Notice Board's news with Visit buttons.
--   * A Home button whenever you're off your own farm, and a count of who's visiting it.
-- The server checks every visit; this only sends intents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Social = require(Shared.Config.Social)
local SocialRules = require(Shared.Social)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)
local HeldTools = require(script.Parent.Parent.Controllers.HeldTools)
local ReachController = require(script.Parent.Parent.Controllers.ReachController)

local Palette = Ui.theme.Palette
local Type = Ui.theme.Type

local SocialUi = {}

local player = Players.LocalPlayer
local MAX_FRIENDS_SHOWN = 6
local MAX_FRIENDS_SHOWN_SHORT = 2 -- phones in landscape (under SHORT_SCREEN px tall)
local SHORT_SCREEN = 560 -- same cut-off the panels use to fill the space under the pills
local SQUARE_RADIUS = 60 -- "in the Town Square" when this close to the hub centre

local friendCache: { [number]: boolean } = {}
local thumbCache: { [number]: string } = {}
local column: Frame
local homeButton: TextButton
local visitorsLabel: TextLabel
local helpLabel: TextLabel
local boostLabel: TextLabel
local neighborsChip: TextLabel
local inviteButton: TextButton? = nil

local function isFriend(other: Player): boolean
	-- Studio counts everyone as a friend, like the server does, so a local test can try the
	-- friends-only rules
	if RunService:IsStudio() then
		return true
	end
	local known = friendCache[other.UserId]
	if known == nil then
		local ok, result = pcall(function()
			return player:IsFriendsWith(other.UserId)
		end)
		known = ok and result == true
		friendCache[other.UserId] = known
	end
	return known :: boolean
end

local function thumbnail(userId: number): string
	local cached = thumbCache[userId]
	if cached then
		return cached
	end
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end)
	local value = if ok and type(image) == "string" then image else ""
	thumbCache[userId] = value
	return value
end

local function otherPlayers(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		local fa, fb = isFriend(a), isFriend(b)
		if fa ~= fb then
			return fa
		end
		return a.DisplayName < b.DisplayName
	end)
	return list
end

-- Where someone is, in a few words.
local function whereabouts(other: Player): string
	local onPlot = other:GetAttribute("OnPlot")
	if onPlot == other.UserId then
		return "on their farm"
	elseif onPlot == player.UserId then
		return "visiting your farm"
	elseif type(onPlot) == "number" and onPlot ~= 0 then
		local owner = Players:GetPlayerByUserId(onPlot)
		return if owner then "visiting " .. owner.DisplayName else "visiting a farm"
	end
	local character = other.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude <= SQUARE_RADIUS then
		return "in the Town Square"
	end
	return "out and about"
end

local function visitorsOnMyFarm(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("OnPlot") == player.UserId then
			table.insert(list, other)
		end
	end
	return list
end

-- Roblox's own invite prompt. LaunchData names us, so the friend who joins from it and we
-- both get the Welcome Boost (14 G3).
local function invite()
	pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.LaunchData = tostring(player.UserId)
		SocialService:PromptGameInvite(player, options)
	end)
end

local function noticeEntries(): { { text: string, visit: number? } }
	local map = Workspace:FindFirstChild("FarmMap")
	local square = map and map:FindFirstChild("TownSquare")
	local board = square and square:FindFirstChild("NoticeBoard")
	local raw = board and board:GetAttribute("Entries")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(decoded) == "table" then decoded else {}
end

-- Helping actions left today (14 B1), from our own save.
local function helpsLeft(): number
	local state = ClientStore.state
	local help = state and state.social and state.social.help
	local used = if help and help.day == SocialRules.utcDay(ClientStore.now()) then help.used else 0
	return math.max(0, Social.helpPerDay - used)
end

-- The farm (plot model) a part belongs to, and its owner's UserId.
local function plotOwner(part: Instance): number?
	local node: Instance? = part
	while node and node ~= Workspace do
		local owner = node:GetAttribute("OwnerUserId")
		if type(owner) == "number" then
			return owner
		end
		node = node.Parent
	end
	return nil
end

-- A tap on a field of someone else's farm: harvest it if ready, else water it (Helping Hands).
local function helpAt(part: BasePart, owner: number)
	local crop = part:GetAttribute("Crop")
	local fieldId = part:GetAttribute("FieldId")
	if crop == nil then
		Hud.toast("Nothing is growing there")
		return
	end
	local readyAt = part:GetAttribute("ReadyAt")
	if type(readyAt) ~= "number" or Timer.isReady(readyAt, ClientStore.now()) then
		HeldTools.flash("Tool_Scythe")
		Remotes.fire("Help_Harvest", owner, fieldId)
	elseif part:GetAttribute("Watered") then
		Hud.toast(
			string.format("Already watered. Ready in %s", Timer.format(Timer.remaining(readyAt, ClientStore.now())))
		)
	else
		HeldTools.flash("Tool_WateringCan")
		Remotes.fire("Help_Water", owner, fieldId)
	end
end

-- Status bubbles over the fields of the farm we're visiting, so a helper can see what's ripe
-- and what still wants water (our own farm's bubbles come from WorldLabels).
local helpBubbles: { [BasePart]: TextLabel } = {}
local visitedPlot: Model? = nil

local function helpBubble(bed: BasePart): TextLabel
	local gui = Ui.new("BillboardGui", {
		Name = "HelpStatus",
		Adornee = bed,
		Size = UDim2.fromOffset(120, 34),
		StudsOffset = Vector3.new(0, 4, 0),
		MaxDistance = 90,
		AlwaysOnTop = true,
		Parent = bed,
	})
	local label = Ui.label("", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Parent = gui,
	})
	Ui.padding(4).Parent = label
	Ui.theme.Kit.skinBubble(label)
	return label
end

local function clearHelpBubbles()
	for _, label in helpBubbles do
		local gui = label.Parent
		if gui then
			gui:Destroy()
		end
	end
	table.clear(helpBubbles)
end

local function renderHelpBubbles()
	local onPlot = player:GetAttribute("OnPlot")
	local target: Model? = nil
	if type(onPlot) == "number" and onPlot ~= 0 and onPlot ~= player.UserId then
		local plots = Workspace:FindFirstChild("Plots")
		for _, model in if plots then plots:GetChildren() else {} do
			if model:IsA("Model") and model:GetAttribute("OwnerUserId") == onPlot then
				target = model
			end
		end
	end
	if target ~= visitedPlot then
		clearHelpBubbles()
		visitedPlot = target
	end
	local fields = target and target:FindFirstChild("Fields")
	if fields == nil then
		return
	end
	local now = ClientStore.now()
	for _, bed in fields:GetChildren() do
		if not bed:IsA("BasePart") or bed:GetAttribute("FieldId") == nil then
			continue
		end
		local label = helpBubbles[bed] or helpBubble(bed)
		helpBubbles[bed] = label
		local gui = label.Parent :: BillboardGui
		local crop = bed:GetAttribute("Crop")
		local readyAt = bed:GetAttribute("ReadyAt")
		if crop == nil or type(readyAt) ~= "number" then
			gui.Enabled = false
		elseif Timer.isReady(readyAt, now) then
			gui.Enabled = true
			label.Text = "Ready! Tap to harvest"
			label.BackgroundColor3 = Ui.colors.ready
		else
			gui.Enabled = true
			local left = Timer.format(Timer.remaining(readyAt, now))
			label.Text = if bed:GetAttribute("Watered") then left else "💧 Water  " .. left
			label.BackgroundColor3 = if bed:GetAttribute("Watered") then Ui.colors.bar else Ui.colors.selected
		end
	end
end

local function helpToast(payload: { [string]: any })
	if payload.kind == "Helped" then
		local reward = if payload.coins > 0
			then string.format(
				"  +%d Coins  +%d XP%s",
				payload.coins,
				payload.xp,
				if payload.teamwork then " (Teamwork!)" else ""
			)
			else ""
		Hud.toast(
			string.format(
				"You %s %s's %s.%s  %d helps left today",
				payload.action,
				payload.owner,
				payload.crop,
				reward,
				payload.left
			)
		)
	elseif payload.kind == "HelpedYou" then
		Hud.toast(string.format("%s %s your %s!", payload.name, payload.action, payload.crop), "celebrate")
	end
end

---------------------------------------------------------------------------------------------
-- The Neighbors panel
---------------------------------------------------------------------------------------------

local function heading(body: ScrollingFrame, text: string, order: number)
	Ui.label(text, {
		Font = Enum.Font.GothamBold,
		TextSize = Type.size.heading,
		Size = UDim2.new(1, -8, 0, 28),
		LayoutOrder = order,
		Parent = body,
	})
end

local function card(body: ScrollingFrame, height: number, order: number): Frame
	return Ui.card({ Size = UDim2.new(1, -8, 0, height), LayoutOrder = order, Parent = body })
end

-- A panel button that acts on the press itself, like the Gem buttons, so a panel refresh
-- between press and release can't swallow the tap. A greyed-out button (Active false) does
-- nothing.
local function pressButton(text: string, onClick: () -> (), props: { [string]: any }): TextButton
	local button: TextButton
	local lastTap = -math.huge
	local function tap()
		if not button.Active or time() - lastTap < 0.4 then
			return
		end
		lastTap = time()
		onClick()
	end
	button = Ui.button(text, tap, props)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tap()
		end
	end)
	return button
end

local function smallButton(text: string, onClick: () -> (), color: Color3?, width: number?): TextButton
	return pressButton(text, onClick, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(width or 92, 32),
		BackgroundColor3 = color or Ui.colors.button,
	})
end

-- Friends we've already sent a Crop Pop heart today, and whether any are left to send.
local function heartSent(userId: number): boolean
	if player:GetAttribute("HeartsLeft") == 0 then
		return true
	end
	local raw = player:GetAttribute("HeartsSentTo")
	if type(raw) ~= "string" then
		return false
	end
	local ok, sentTo = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return ok and type(sentTo) == "table" and table.find(sentTo, userId) ~= nil
end

-- A label and a row of options; the current one is highlighted.
local function optionRow(
	body: ScrollingFrame,
	caption: string,
	options: { string },
	current: string,
	remote: string,
	order: number
)
	local line = card(body, 44, order)
	Ui.label(caption, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 90, 1, 0), Parent = line })
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(100, 6),
		Size = UDim2.new(1, -106, 0, 32),
		Parent = line,
	}, { Ui.list(6, true) })
	for i, option in options do
		local picked = option == current
		pressButton(option, function()
			Remotes.fire(remote, option)
		end, {
			Size = UDim2.fromOffset(84, 30),
			LayoutOrder = i,
			BackgroundColor3 = if picked then Ui.colors.selected else Palette.button.neutral.face,
			TextColor3 = if picked then Palette.textOnColor else Palette.text,
			Parent = holder,
		})
	end
end

local function renderNeighbors(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Neighbors"
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	heading(body, "On this server", nextOrder())
	local others = otherPlayers()
	if #others == 0 then
		local line = card(body, 48, nextOrder())
		Ui.label("Nobody else is here yet. Invite a friend to farm with you!", {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -120, 1, 0),
			TextWrapped = true,
			TextSize = Type.size.small,
			Parent = line,
		})
		if inviteButton then
			smallButton("Invite", invite, Ui.colors.selected).Parent = line
		end
	end
	for _, other in others do
		local line = card(body, 52, nextOrder())
		local level = other:GetAttribute("FarmLevel")
		Ui.label(string.format("%s%s", other.DisplayName, if type(level) == "number" then "   Lv " .. level else ""), {
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -270, 0, 22),
			Parent = line,
		})
		Ui.label((if isFriend(other) then "Friend, " else "") .. whereabouts(other), {
			TextColor3 = Ui.colors.muted,
			TextSize = Type.size.small,
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -270, 0, 20),
			Parent = line,
		})
		local visitButton = smallButton("Visit", function()
			Panels.close()
			Remotes.fire("Visit_Go", other.UserId)
		end)
		visitButton.Parent = line
		local right = -104 -- left edge of the next button, right of the Visit button
		if isFriend(other) then
			local heart = smallButton("❤", function()
				Remotes.fire("Social_GiftHeart", other.UserId)
			end, Palette.button.danger.face, 44)
			Ui.setEnabled(heart, not heartSent(other.UserId), Palette.button.danger.face)
			heart.Position = UDim2.new(1, right, 0.5, 0)
			heart.Parent = line
			right -= 50
		end
		if other:GetAttribute("OnPlot") == player.UserId then
			local send = smallButton("Send home", function()
				Remotes.fire("Visit_SendHome", other.UserId)
			end, Ui.colors.danger, 110)
			send.Position = UDim2.new(1, right, 0.5, 0)
			send.Parent = line
		end
	end

	heading(body, "Your farm", nextOrder())
	local social = state.social or {}
	optionRow(
		body,
		"Visitors",
		Social.privacyOptions,
		social.privacy or Social.defaultPrivacy,
		"Social_SetPrivacy",
		nextOrder()
	)
	optionRow(
		body,
		"Helpers",
		Social.helperOptions,
		social.helpers or Social.defaultHelpers,
		"Social_SetHelpers",
		nextOrder()
	)
	Ui.label("Helpers are rewarded by the town, never by you. Blocked players can't visit or help.", {
		TextColor3 = Ui.colors.muted,
		TextSize = Type.size.small,
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, 36),
		LayoutOrder = nextOrder(),
		Parent = body,
	})

	local entries = noticeEntries()
	if #entries > 0 then
		heading(body, "Town news", nextOrder())
		for _, entry in entries do
			local line = card(body, 40, nextOrder())
			Ui.label(entry.text, {
				TextSize = Type.size.small,
				TextWrapped = true,
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -110, 1, 0),
				Parent = line,
			})
			local owner = if type(entry.visit) == "number" then Players:GetPlayerByUserId(entry.visit) else nil
			if owner and owner ~= player then
				smallButton("Visit", function()
					Panels.close()
					Remotes.fire("Visit_Go", (owner :: Player).UserId)
				end).Parent =
					line
			end
		end
	end

	if RunService:IsStudio() then
		heading(body, "Studio test", nextOrder())
		local line = card(body, 48, nextOrder())
		Ui.label("A test neighbor's farm next to yours, to try visiting and Helping Hands alone.", {
			TextSize = Type.size.small,
			TextWrapped = true,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -150, 1, 0),
			Parent = line,
		})
		smallButton("Test neighbor", function()
			Panels.close()
			Remotes.fire("Debug_TestNeighbor")
		end, Ui.colors.selected, 136).Parent =
			line
	end

	local travel = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 40),
		LayoutOrder = nextOrder(),
		Parent = body,
	}, { Ui.list(8, true) })
	pressButton("Town Square", function()
		Panels.close()
		Remotes.fire("Visit_Square")
	end, { Size = UDim2.fromOffset(140, 34), BackgroundColor3 = Ui.colors.selected, LayoutOrder = 1, Parent = travel })
	pressButton("Go home", function()
		Panels.close()
		Remotes.fire("Visit_Home")
	end, { Size = UDim2.fromOffset(120, 34), LayoutOrder = 2, Parent = travel })
end

---------------------------------------------------------------------------------------------
-- The HUD column: Neighbors, Home, Friends Nearby, Invite, and who's visiting
---------------------------------------------------------------------------------------------

local function friendBadge(friend: Player, order: number): TextButton
	local button = Ui.new("TextButton", {
		Name = "Friend",
		BackgroundColor3 = Palette.cream,
		Size = UDim2.fromOffset(52, 52),
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = order,
	}, { Ui.new("UICorner", { CornerRadius = UDim.new(1, 0) }), Ui.theme.Kit.stroke(Palette.cocoa, 2, 0.1, true) })
	local image = thumbnail(friend.UserId)
	if image ~= "" then
		Ui.new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = image,
			Parent = button,
		}, { Ui.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	else
		Ui.new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Type.display,
			TextSize = 22,
			TextColor3 = Palette.text,
			Text = friend.DisplayName:sub(1, 1):upper(),
			Parent = button,
		})
	end
	local name = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(70, 16),
		Font = Type.display,
		TextSize = Type.size.small,
		TextColor3 = Palette.textOnColor,
		Text = friend.DisplayName,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = button,
	})
	Ui.theme.Kit.textOutline(name, Palette.cocoa)
	button.Activated:Connect(function()
		Remotes.fire("Visit_Go", friend.UserId)
	end)
	return button
end

-- The labels that follow our own state: Home, helps left, Good Neighbors, visitors.
local function refreshStatus()
	local onPlot = player:GetAttribute("OnPlot")
	homeButton.Visible = onPlot ~= player.UserId
	helpLabel.Visible = type(onPlot) == "number" and onPlot ~= 0 and onPlot ~= player.UserId
	helpLabel.Text = string.format("🤝 %d helps left", helpsLeft())
	local neighbors = player:GetAttribute("GoodNeighbors")
	neighborsChip.Visible = type(neighbors) == "number" and neighbors > 0
	if neighborsChip.Visible then
		neighborsChip.Text =
			string.format("🏡 Good Neighbors +%d%%", math.floor(SocialRules.neighborBonus(neighbors) * 100 + 0.5))
	end
	local visitors = visitorsOnMyFarm()
	visitorsLabel.Visible = #visitors > 0
	visitorsLabel.Text = if #visitors == 1 then "1 visiting" else string.format("%d visiting", #visitors)
end

local function isShortScreen(): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y < SHORT_SCREEN
end

-- Someone joined, left or moved: rebuild the Friends Nearby column and the Neighbors panel.
local function refreshHud()
	if column == nil then
		return
	end
	for _, child in column:GetChildren() do
		if child.Name == "Friend" then
			child:Destroy()
		end
	end
	local shown = 0
	for _, other in otherPlayers() do
		if shown >= (if isShortScreen() then MAX_FRIENDS_SHOWN_SHORT else MAX_FRIENDS_SHOWN) or not isFriend(other) then
			break
		end
		shown += 1
		friendBadge(other, 10 + shown).Parent = column
	end
	refreshStatus()
	if Panels.isShowing("Neighbors") then
		Panels.refresh()
	end
end

local function sendBlockList()
	local ok, ids = pcall(function()
		return StarterGui:GetCore("GetBlockedUserIds")
	end)
	if ok and type(ids) == "table" then
		Remotes.fire("Social_SetBlocked", ids)
	end
end

local function watchPlayer(other: Player)
	other:GetAttributeChangedSignal("OnPlot"):Connect(refreshHud)
	other:GetAttributeChangedSignal("FarmLevel"):Connect(refreshHud)
	if other == player then
		other:GetAttributeChangedSignal("GoodNeighbors"):Connect(refreshStatus)
		for _, name in { "HeartsSentTo", "HeartsLeft" } do
			other:GetAttributeChangedSignal(name):Connect(function()
				if Panels.isShowing("Neighbors") then
					Panels.refresh()
				end
			end)
		end
	end
end

function SocialUi.init()
	Panels.register("Neighbors", function(state, body, title)
		renderNeighbors(state, body, title)
	end)

	-- Taps on the Town Square boards (the reach controller only handles our own plot)
	local previous = ReachController.otherTarget
	ReachController.otherTarget = function(part: BasePart)
		local kind = part:GetAttribute("Interact")
		if kind == "Notice" or kind == "Neighbors" then
			return function()
				Panels.open("Neighbors")
			end, false
		elseif kind == "Field" then
			local owner = plotOwner(part)
			if owner and owner ~= player.UserId then
				return function()
					helpAt(part, owner)
				end, true
			end
		elseif kind == "PuzzlePorch" then
			return ReachController.openCropPop, true
		elseif kind == "Market" then
			return function()
				Hud.toast("Market stalls open in a later update. Check back soon!")
			end, false
		end
		return previous(part)
	end

	local gui = Ui.new("ScreenGui", {
		Name = "FarmSocial",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	column = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.fromOffset(84, 520),
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 22),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.new("UIScale", {}),
	})
	-- Short screens (phones in landscape) get a smaller, tighter column with fewer friends, and
	-- the column steps aside while a panel is open so it never covers the panel's left edge.
	local layout = column:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local scale = column:FindFirstChildOfClass("UIScale") :: UIScale
	local wasShort: boolean? = nil
	local function fit()
		local short = isShortScreen()
		if short == wasShort then
			return
		end
		wasShort = short
		scale.Scale = if short then 0.8 else 1
		layout.Padding = UDim.new(0, if short then 8 else 22)
		refreshHud()
	end
	RunService.Heartbeat:Connect(function()
		local hidden = Panels.isOpen()
		if column.Visible == hidden then
			column.Visible = not hidden
		end
		fit()
	end)
	local neighbors = Ui.button('👋\n<font size="13">Neighbors</font>', function()
		Panels.open("Neighbors")
	end, {
		Size = UDim2.fromOffset(78, 58),
		RichText = true,
		TextSize = 22,
		LineHeight = 0.9,
		TextColor3 = Palette.text,
		BackgroundColor3 = Palette.button.neutral.face,
		LayoutOrder = 1,
		Parent = column,
	})
	visitorsLabel = Ui.new("TextLabel", {
		BackgroundColor3 = Palette.cocoa,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(78, 18),
		Font = Type.display,
		TextSize = Type.size.small,
		TextColor3 = Palette.textOnColor,
		Visible = false,
		ZIndex = 6,
		Parent = neighbors,
	}, { Ui.corner(9) })
	homeButton = Ui.button("🏡 Home", function()
		Remotes.fire("Visit_Home")
	end, {
		Size = UDim2.fromOffset(78, 36),
		BackgroundColor3 = Ui.colors.selected,
		LayoutOrder = 2,
		Visible = false,
		Parent = column,
	})

	helpLabel = Ui.new("TextLabel", {
		BackgroundColor3 = Palette.cream,
		Size = UDim2.fromOffset(84, 26),
		Font = Type.display,
		TextSize = Type.size.small,
		TextColor3 = Palette.text,
		TextWrapped = true,
		LayoutOrder = 3,
		Visible = false,
		Parent = column,
	}, { Ui.corner(8), Ui.theme.Kit.stroke(Palette.cocoa, 2, 0.1, true) })

	local function chip(order: number): TextLabel
		return Ui.new("TextLabel", {
			BackgroundColor3 = Ui.colors.ready,
			Size = UDim2.fromOffset(84, 40),
			Font = Type.display,
			TextSize = Type.size.small,
			TextColor3 = Palette.textOnColor,
			TextWrapped = true,
			LayoutOrder = order,
			Visible = false,
			Parent = column,
		}, { Ui.corner(8), Ui.theme.Kit.stroke(Palette.cocoa, 2, 0.1, true) })
	end
	neighborsChip = chip(4)
	Ui.theme.Kit.textOutline(neighborsChip, Palette.cocoa)
	boostLabel = chip(5)
	Ui.theme.Kit.textOutline(boostLabel, Palette.cocoa)
	-- The Welcome Boost countdown
	task.spawn(function()
		while true do
			local state = ClientStore.state
			local ends = state and state.social and state.social.boostUntil or 0
			local left = ends - ClientStore.now()
			boostLabel.Visible = left > 0
			if left > 0 then
				boostLabel.Text = "🌱 Welcome Boost " .. Timer.format(left)
			end
			task.wait(1)
		end
	end)

	-- Invite friends, where Roblox allows it for this player (14 G3: invites go through
	-- Roblox's own flow only)
	task.spawn(function()
		local ok, allowed = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and allowed then
			inviteButton = Ui.button("➕ Invite", invite, {
				Size = UDim2.fromOffset(78, 36),
				LayoutOrder = 100,
				Parent = column,
			})
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.N then
			Panels.open("Neighbors")
		end
	end)

	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(function(other)
		watchPlayer(other)
		refreshHud()
	end)
	Players.PlayerRemoving:Connect(function(other)
		friendCache[other.UserId] = nil
		task.defer(refreshHud)
	end)
	ClientStore.changed.Event:Connect(refreshStatus)
	refreshHud()

	task.spawn(function()
		while true do
			renderHelpBubbles()
			task.wait(0.5)
		end
	end)

	-- Social news for this player (the HUD shows the farm's own pop-ups)
	Remotes.get("Reward_Popup").OnClientEvent:Connect(function(payload)
		if payload.kind == "Visitor" then
			Hud.toast(string.format("%s is visiting your farm!", payload.name))
		elseif payload.kind == "WelcomeBoost" then
			Hud.toast(
				string.format(
					"Welcome Boost! You're farming with %s: crops you plant grow %d%% faster for %d minutes.",
					payload.name,
					math.floor(Social.welcomeGrowCut * 100 + 0.5),
					Social.welcomeSeconds // 60
				),
				"celebrate"
			)
		elseif payload.kind == "Order" and (payload.neighbors or 0) > 0 then
			Hud.toast(string.format("Good Neighbors: +%d Coins for farming with friends", payload.neighbors))
		else
			helpToast(payload)
		end
	end)

	-- Our Roblox block list, so blocked players can't visit or help (14 §5)
	sendBlockList()
	for _, event in { "PlayerBlockedEvent", "PlayerUnblockedEvent" } do
		pcall(function()
			(StarterGui:GetCore(event) :: BindableEvent).Event:Connect(sendBlockList)
		end)
	end
end

return SocialUi
