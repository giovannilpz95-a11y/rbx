--!strict
-- Presence and visiting (Design/14 Multiplayer Features A1, A2; Design/08 Social & Events):
-- who is friends with whom, block lists, plot privacy, walking (or teleporting) onto a
-- neighbor's plot, sending a visitor home, and players not colliding with each other.
--
-- Every player carries two replicated attributes the clients read: FarmLevel, and OnPlot (the
-- UserId of the plot they're standing on, 0 off-plot). Friendship in Studio counts everyone as
-- a friend, so a local 2-player server can test the friends-only rules.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Net = require(Shared.Net)
local Palette = require(Shared.Art.Palette)
local Social = require(Shared.Config.Social)
local SocialRules = require(Shared.Social)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local Clock = require(script.Parent.Parent.Util.Clock)

local SocialService = {}

local COLLISION_GROUP = "FarmAvatars"
local MAX_BLOCKED = 500

local friendCache: { [number]: { [number]: boolean } } = {}
local blockedBy: { [Player]: { [number]: boolean } } = {}
local sentHome: { [Player]: { [number]: number } } = {} -- owner -> visitor UserId -> may return at
local lastPlot: { [Player]: number } = {}
local neighborsText: TextLabel? = nil

local function cacheFriend(a: number, b: number, value: boolean)
	friendCache[a] = friendCache[a] or {}
	friendCache[b] = friendCache[b] or {}
	friendCache[a][b] = value
	friendCache[b][a] = value
end

function SocialService.isFriend(a: Player, b: Player): boolean
	if a == b then
		return true
	elseif RunService:IsStudio() then
		return true
	end
	local known = friendCache[a.UserId] and friendCache[a.UserId][b.UserId]
	if known ~= nil then
		return known
	end
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local value = ok and result == true
	if ok then
		cacheFriend(a.UserId, b.UserId, value)
	end
	return value
end

-- Has either player blocked the other on Roblox?
function SocialService.isBlocked(a: Player, b: Player): boolean
	local aBlocks = blockedBy[a]
	local bBlocks = blockedBy[b]
	return (aBlocks ~= nil and aBlocks[b.UserId] == true) or (bBlocks ~= nil and bBlocks[a.UserId] == true)
end

-- Friends of this player who are on the server right now.
function SocialService.friendsOnServer(player: Player): { Player }
	local friends = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and SocialService.isFriend(player, other) and not SocialService.isBlocked(player, other) then
			table.insert(friends, other)
		end
	end
	return friends
end

-- May `visitor` be on `owner`'s plot right now? Returns a reason when not.
function SocialService.canVisit(visitor: Player, owner: Player): (boolean, string?)
	if visitor == owner then
		return true
	end
	local data = DataService.get(owner)
	if data == nil then
		return false, "That farm isn't ready yet"
	end
	local returnAt = sentHome[owner] and sentHome[owner][visitor.UserId]
	if returnAt and Clock.now() < returnAt then
		return false,
			string.format(
				"%s asked for some quiet. You can visit again in %d min.",
				owner.DisplayName,
				math.ceil((returnAt - Clock.now()) / 60)
			)
	end
	local friend = SocialService.isFriend(visitor, owner)
	local blocked = SocialService.isBlocked(visitor, owner)
	if SocialRules.canVisit(data.social.privacy, friend, blocked) then
		return true
	elseif data.social.privacy == "Friends" and not blocked then
		return false, string.format("Only %s's friends can visit this farm", owner.DisplayName)
	end
	return false, "This farm is closed to visitors"
end

-- May `helper` help on `owner`'s plot (Helping Hands)? Returns a reason when not.
function SocialService.canHelp(helper: Player, owner: Player): (boolean, string?)
	local data = DataService.get(owner)
	if data == nil or helper == owner then
		return false
	end
	local friend = SocialService.isFriend(helper, owner)
	if SocialRules.canHelp(data.social.helpers, friend, SocialService.isBlocked(helper, owner)) then
		return true
	elseif data.social.helpers == "Friends" then
		return false, string.format("Only %s's friends can help on this farm", owner.DisplayName)
	end
	return false, string.format("%s isn't taking help right now", owner.DisplayName)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function moveTo(player: Player, target: CFrame?)
	local character = player.Character
	if character and target then
		character:PivotTo(target)
	end
end

local function playerByUserId(userId: any): Player?
	if type(userId) ~= "number" or userId ~= userId or userId % 1 ~= 0 then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

---------------------------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------------------------

local function visit(player: Player, targetUserId: any): (boolean, string?)
	local owner = playerByUserId(targetUserId)
	if owner == nil or owner == player or DataService.get(owner) == nil then
		return false, "That farmer has left the server"
	end
	local ok, reason = SocialService.canVisit(player, owner)
	if not ok then
		return false, reason
	end
	moveTo(player, PlotService.gateCFrame(owner))
	return false
end

local function goHome(player: Player): (boolean, string?)
	moveTo(player, PlotService.spawnCFrame(player))
	return false
end

local function goToSquare(player: Player): (boolean, string?)
	moveTo(player, PlotService.squareCFrame())
	return false
end

local function sendHome(player: Player, visitorUserId: any): (boolean, string?)
	local visitor = playerByUserId(visitorUserId)
	if visitor == nil or visitor == player then
		return false
	end
	sentHome[player] = sentHome[player] or {}
	sentHome[player][visitor.UserId] = Clock.now() + Social.sendHomeCooldown
	local root = rootOf(visitor)
	if root and PlotService.ownerAt(root.Position) == player then
		moveTo(visitor, PlotService.squareCFrame())
		NetService.toast(
			visitor,
			string.format("%s's farm is closed for a while. Welcome to the Town Square!", player.DisplayName)
		)
	end
	return false, string.format("%s was sent to the Town Square", visitor.DisplayName)
end

local function setOption(key: string, options: { string })
	return function(player: Player, value: any): (boolean, string?)
		if type(value) ~= "string" or table.find(options, value) == nil then
			return false
		end
		local data = DataService.get(player) :: { [string]: any }
		data.social[key] = value
		return true
	end
end

-- The client reports its own Roblox block list. Trusting it is safe: a player can only make
-- their own interactions narrower.
local function setBlocked(player: Player, list: any): (boolean, string?)
	if type(list) ~= "table" or #list > MAX_BLOCKED then
		return false
	end
	local set = {}
	for _, userId in list do
		if type(userId) == "number" and userId == userId and userId % 1 == 0 then
			set[userId] = true
		end
	end
	blockedBy[player] = set
	return false
end

---------------------------------------------------------------------------------------------
-- Presence: who is on whose plot, levels, and keeping unwelcome visitors off
---------------------------------------------------------------------------------------------

-- A board in the Town Square: a title over a block of text. Returns the text label.
local function boardText(face: BasePart, kind: string, title: string, body: string): TextLabel
	face:SetAttribute("Interact", kind)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = face
	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.fromScale(1, 0.18)
	heading.BackgroundTransparency = 1
	heading.TextScaled = true
	heading.Font = Enum.Font.GothamBold
	heading.TextColor3 = Palette.cocoa
	heading.Text = title
	heading.Parent = surface
	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromScale(0.04, 0.22)
	text.Size = UDim2.fromScale(0.92, 0.74)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Font = Enum.Font.Gotham
	text.TextColor3 = Palette.cocoa
	text.Text = body
	text.Parent = surface
	return text
end

-- The Neighbors board: every farmer on the server and their level.
local function renderNeighborsBoard()
	if neighborsText == nil then
		return
	end
	local lines = {}
	for _, player in Players:GetPlayers() do
		local level = player:GetAttribute("FarmLevel")
		table.insert(
			lines,
			string.format("%s%s", player.DisplayName, if level then "  (level " .. level .. ")" else "")
		)
	end
	table.sort(lines)
	local text = table.concat(lines, "\n") .. "\n\nTap here to visit a farm."
	if neighborsText.Text ~= text then
		neighborsText.Text = text
	end
end

local function presenceTick()
	renderNeighborsBoard()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			player:SetAttribute("FarmLevel", data.level)
		end
		local root = rootOf(player)
		local owner = if root then PlotService.ownerAt(root.Position) else nil
		local onPlot = if owner then owner.UserId else 0
		if owner and owner ~= player then
			local ok, reason = SocialService.canVisit(player, owner)
			if not ok then
				moveTo(player, PlotService.squareCFrame())
				NetService.toast(player, reason or "This farm is closed to visitors")
				onPlot = 0
			elseif lastPlot[player] ~= onPlot then
				NetService.popup(owner, { kind = "Visitor", name = player.DisplayName })
			end
		end
		lastPlot[player] = onPlot
		if player:GetAttribute("OnPlot") ~= onPlot then
			player:SetAttribute("OnPlot", onPlot)
		end
	end
end

local function setCollisionGroup(character: Model)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = COLLISION_GROUP
		end
	end
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = COLLISION_GROUP
		end
	end)
end

-- Before the plot is assigned: learn who this player's friends are, so the plot can go next
-- to theirs.
function SocialService.playerLoaded(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			SocialService.isFriend(player, other)
		end
	end
	player:SetAttribute("OnPlot", 0)
	local data = DataService.get(player)
	if data then
		player:SetAttribute("FarmLevel", data.level)
	end
end

function SocialService.init()
	-- Avatars pass through each other, so nobody can body-block a field, gate or board
	-- (14 Multiplayer Features §5)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
	local function watch(player: Player)
		player.CharacterAdded:Connect(setCollisionGroup)
		if player.Character then
			setCollisionGroup(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	local boards = PlotService.square.boards
	neighborsText = boardText(boards.Neighbors, "Neighbors", "Neighbors", "")
	boardText(
		boards.Market,
		"Market",
		"Market",
		"Farm stalls open here soon.\n\nSell your goods to your neighbors for Coins."
	)

	NetService.on(Net.Visit_Go, 1, 2, visit)
	NetService.on(Net.Visit_Home, 1, 2, goHome)
	NetService.on(Net.Visit_Square, 1, 2, goToSquare)
	NetService.on(Net.Visit_SendHome, 1, 3, sendHome)
	NetService.on(Net.Social_SetPrivacy, 2, 3, setOption("privacy", Social.privacyOptions))
	NetService.on(Net.Social_SetHelpers, 2, 3, setOption("helpers", Social.helperOptions))
	NetService.on(Net.Social_SetBlocked, 0.2, 3, setBlocked)

	Players.PlayerRemoving:Connect(function(player)
		blockedBy[player] = nil
		sentHome[player] = nil
		lastPlot[player] = nil
		friendCache[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			presenceTick()
		end
	end)
end

return SocialService
