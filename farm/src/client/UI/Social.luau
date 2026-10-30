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
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Social = require(Shared.Config.Social)
local SocialRules = require(Shared.Social)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)
local ReachController = require(script.Parent.Parent.Controllers.ReachController)

local Palette = Ui.theme.Palette
local Type = Ui.theme.Type

local SocialUi = {}

local player = Players.LocalPlayer
local MAX_FRIENDS_SHOWN = 6
local SQUARE_RADIUS = 60 -- "in the Town Square" when this close to the hub centre

local friendCache: { [number]: boolean } = {}
local thumbCache: { [number]: string } = {}
local column: Frame
local homeButton: TextButton
local visitorsLabel: TextLabel
local helpLabel: TextLabel
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

local function invite()
	pcall(function()
		SocialService:PromptGameInvite(player)
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
		Remotes.fire("Help_Harvest", owner, fieldId)
	elseif part:GetAttribute("Watered") then
		Hud.toast(
			string.format("Already watered. Ready in %s", Timer.format(Timer.remaining(readyAt, ClientStore.now())))
		)
	else
		Remotes.fire("Help_Water", owner, fieldId)
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

local function smallButton(text: string, onClick: () -> (), color: Color3?, width: number?): TextButton
	return Ui.button(text, onClick, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(width or 92, 32),
		BackgroundColor3 = color or Ui.colors.button,
	})
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
		Ui.button(option, function()
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
			Size = UDim2.new(1, -200, 0, 22),
			Parent = line,
		})
		Ui.label((if isFriend(other) then "Friend, " else "") .. whereabouts(other), {
			TextColor3 = Ui.colors.muted,
			TextSize = Type.size.small,
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -200, 0, 20),
			Parent = line,
		})
		local visitButton = smallButton("Visit", function()
			Panels.close()
			Remotes.fire("Visit_Go", other.UserId)
		end)
		visitButton.Parent = line
		if other:GetAttribute("OnPlot") == player.UserId then
			local send = smallButton("Send home", function()
				Remotes.fire("Visit_SendHome", other.UserId)
			end, Ui.colors.danger, 110)
			send.Position = UDim2.new(1, -104, 0.5, 0)
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

	local travel = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 40),
		LayoutOrder = nextOrder(),
		Parent = body,
	}, { Ui.list(8, true) })
	Ui.button("Town Square", function()
		Panels.close()
		Remotes.fire("Visit_Square")
	end, { Size = UDim2.fromOffset(140, 34), BackgroundColor3 = Ui.colors.selected, LayoutOrder = 1, Parent = travel })
	Ui.button("Go home", function()
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
		if shown >= MAX_FRIENDS_SHOWN or not isFriend(other) then
			break
		end
		shown += 1
		friendBadge(other, 10 + shown).Parent = column
	end
	homeButton.Visible = player:GetAttribute("OnPlot") ~= player.UserId
	local onPlot = player:GetAttribute("OnPlot")
	helpLabel.Visible = type(onPlot) == "number" and onPlot ~= 0 and onPlot ~= player.UserId
	helpLabel.Text = string.format("🤝 %d helps left", helpsLeft())
	local visitors = visitorsOnMyFarm()
	visitorsLabel.Visible = #visitors > 0
	visitorsLabel.Text = if #visitors == 1 then "1 visiting" else string.format("%d visiting", #visitors)
	if Panels.isOpen() then
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
	})
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
	ClientStore.changed.Event:Connect(refreshHud)
	refreshHud()

	-- Social news for this player (the HUD shows the farm's own pop-ups)
	Remotes.get("Reward_Popup").OnClientEvent:Connect(function(payload)
		if payload.kind == "Visitor" then
			Hud.toast(string.format("%s is visiting your farm!", payload.name))
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
