--!strict
-- Presence and visiting (Design/14 Multiplayer Features A1, A2; Design/08 Social & Events):
-- who is friends with whom, block lists, plot privacy, walking (or teleporting) onto a
-- neighbor's plot, sending a visitor home, and players not colliding with each other.
--
-- Every player carries two replicated attributes the clients read: FarmLevel, and OnPlot (the
-- UserId of the plot they're standing on, 0 off-plot). Friendship in Studio counts everyone as
-- a friend, so a local 2-player server can test the friends-only rules.

local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Market = require(Shared.Market)
local MarketConfig = require(Shared.Config.Market)
local Net = require(Shared.Net)
local Palette = require(Shared.Art.Palette)
local Social = require(Shared.Config.Social)
local SocialRules = require(Shared.Social)
local Profile = require(Shared.Profile)
local Records = require(Shared.Records)

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

-- Good Neighbors (14 G1): friends on the server who count toward the bonus: level 5+ (Studio
-- skips the level) and active in the last 5 minutes, so idle alts don't.
function SocialService.goodNeighbors(player: Player): number
	local count = 0
	for _, friend in SocialService.friendsOnServer(player) do
		local data = DataService.get(friend)
		if
			data
			and (data.level >= Social.neighborMinLevel or RunService:IsStudio())
			and NetService.idleSeconds(friend) <= Social.neighborActiveSeconds
		then
			count += 1
		end
	end
	return count
end

-- The extra Coins Good Neighbors adds to an order payout.
function SocialService.neighborBonusCoins(player: Player, coins: number): number
	return SocialRules.bonusCoins(coins, SocialRules.neighborBonus(SocialService.goodNeighbors(player)))
end

-- Who this player came to play with: the friend they followed into the game, or whose
-- invite they accepted (Roblox Friend Referral: ReferredByPlayerId, or our invite's
-- LaunchData). Studio has neither, so there it's anyone already on the server.
local function joinedWith(player: Player): Player?
	local candidates = { player.FollowUserId }
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if ok and type(joinData) == "table" then
		table.insert(candidates, tonumber(joinData.ReferredByPlayerId) or 0)
		table.insert(candidates, tonumber(joinData.LaunchData) or 0)
	end
	for _, userId in candidates do
		local other = if userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
		if other and other ~= player then
			return other
		end
	end
	if RunService:IsStudio() then
		for _, other in Players:GetPlayers() do
			if other ~= player and DataService.get(other) then
				return other
			end
		end
	end
	return nil
end

local function giveBoost(player: Player, friend: Player): boolean
	local data = DataService.get(player)
	if data == nil or not SocialRules.grantBoost(data.social, friend.UserId, Clock.now()) then
		return false
	end
	DataService.markDirty(player, true)
	NetService.pushState(player)
	NetService.whenReady(player, function()
		NetService.popup(player, { kind = "WelcomeBoost", name = friend.DisplayName })
	end)
	return true
end

-- The friend-join Welcome Boost (14 G3): playing together, not sending invites, is what's
-- rewarded. The joiner always gets it; the friend they joined gets it too when the joiner is
-- level 5+ (alts). Once per friend pair per UTC day.
function SocialService.welcome(player: Player)
	local friend = joinedWith(player)
	if friend == nil or not SocialService.isFriend(player, friend) or SocialService.isBlocked(player, friend) then
		return
	end
	local data = DataService.get(player)
	if data == nil or DataService.get(friend) == nil then
		return
	end
	giveBoost(player, friend)
	if data.level >= Social.welcomeMinLevel or RunService:IsStudio() then
		giveBoost(friend, player)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function moveTo(player: Player, target: CFrame?)
	local character = player.Character
	if character and target then
		-- With streaming on, load the ground there first so the avatar doesn't land in nothing
		if typeof(player) == "Instance" then
			pcall(function()
				player:RequestStreamAroundAsync(target.Position, 3)
			end)
		end
		character:PivotTo(target)
	end
end

-- Studio only: a farm with nobody behind it, so one player can try visiting and Helping Hands
-- (Debug_TestNeighbor). A stand-in with the few Player fields the services read.
local TEST_NEIGHBOR_ID = -4242
local testNeighbor: any = nil

-- The player with this UserId on the server (or the Studio test neighbor).
function SocialService.playerByUserId(userId: any): Player?
	if type(userId) ~= "number" or userId ~= userId or userId % 1 ~= 0 then
		return nil
	elseif testNeighbor and userId == TEST_NEIGHBOR_ID then
		return testNeighbor
	end
	return Players:GetPlayerByUserId(userId)
end
local playerByUserId = SocialService.playerByUserId

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

-- Studio: make the test neighbor's farm next to yours (3 ripe Wheat fields, 3 growing Corn),
-- or go back to it.
local function testNeighborFarm(player: Player): (boolean, string?)
	if not RunService:IsStudio() then
		return false
	end
	if testNeighbor == nil then
		local stand = {
			UserId = TEST_NEIGHBOR_ID,
			Name = "TestNeighbor",
			DisplayName = "Test Neighbor",
		}
		function stand.GetAttribute(_self: any, _name: string): any
			return nil
		end
		local data = Profile.template()
		local now = Clock.now()
		Profile.welcome(data, now)
		for i, id in Profile.fieldIds() do
			local ripe = i <= 3
			data.fields[id] = {
				crop = if ripe then "Wheat" else "Corn",
				plantedAt = now - (if ripe then 600 else 0),
				readyAt = if ripe then now - 1 else now + Clock.duration(300),
			}
		end
		-- A stocked Market stall, for trying a purchase
		data.level = math.max(data.level, MarketConfig.unlockLevel)
		for slot, entry in { { "Wheat", 10 }, { "Corn", 6 }, { "Milk", 4 } } do
			local _, _, price = Market.priceRange(entry[1], entry[2])
			Market.list(data, slot, entry[1], entry[2], price, now)
		end
		DataService.addDummy(stand, data)
		if PlotService.assign(stand :: any, { player }) == nil then
			return false, "No free plot for a test neighbor"
		end
		testNeighbor = stand
	end
	moveTo(player, PlotService.gateCFrame(testNeighbor))
	return false, "Test Neighbor's farm: 3 ripe Wheat fields to harvest and 3 Corn fields to water"
end

-- Send a friend a Crop Pop heart. Crop Pop owns hearts, the daily limit and the pending gift
-- (ServerStorage.CropPopGiftHeart: (fromPlayer, toUserId) -> (ok, message?)); this checks
-- the pair are friends and neither has blocked the other.
-- Who this player has already sent a heart today, and how many they have left, as player
-- attributes the Neighbors panel greys the ❤ buttons out by (ServerStorage.
-- CropPopHeartGiftStatus: (player) -> { sentTo = { userId }, left, perDay }).
local function refreshHeartStatus(player: Player)
	local hook = ServerStorage:FindFirstChild("CropPopHeartGiftStatus")
	if hook == nil or not hook:IsA("BindableFunction") then
		return
	end
	local ok, status = pcall(function()
		return (hook :: BindableFunction):Invoke(player)
	end)
	if not ok or type(status) ~= "table" then
		return
	end
	local sentTo = {}
	if type(status.sentTo) == "table" then
		for _, userId in status.sentTo do
			if type(userId) == "number" then
				table.insert(sentTo, userId)
			end
		end
	end
	local encoded = HttpService:JSONEncode(sentTo)
	if player:GetAttribute("HeartsSentTo") ~= encoded then
		player:SetAttribute("HeartsSentTo", encoded)
	end
	local left = if type(status.left) == "number" then status.left else nil
	if player:GetAttribute("HeartsLeft") ~= left then
		player:SetAttribute("HeartsLeft", left)
	end
end

local function giftHeart(player: Player, toUserId: any): (boolean, string?)
	local friend = playerByUserId(toUserId)
	if friend == nil or friend == player or typeof(friend) ~= "Instance" then
		return false, "That farmer has left the server"
	elseif not SocialService.isFriend(player, friend) or SocialService.isBlocked(player, friend) then
		return false, "You can send hearts to your friends"
	end
	local hook = ServerStorage:FindFirstChild("CropPopGiftHeart")
	if hook == nil or not hook:IsA("BindableFunction") then
		return false, "Heart gifts open soon"
	end
	local ok, sent, message = pcall(function()
		return (hook :: BindableFunction):Invoke(player, friend.UserId)
	end)
	if not ok then
		warn("[SocialService] CropPopGiftHeart failed:", sent)
		return false, "Couldn't send the heart. Try again later."
	elseif sent ~= true then
		return false, if type(message) == "string" then message else "You can't send another heart today"
	end
	refreshHeartStatus(player)
	NetService.toast(friend, string.format("%s sent you a ❤ for Crop Pop!", player.DisplayName))
	return false, if type(message) == "string" then message else string.format("Sent %s a ❤!", friend.DisplayName)
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

local cardTicks = 0

local function presenceTick()
	renderNeighborsBoard()
	cardTicks += 1
	local cardTick = cardTicks % 5 == 1 -- Farmer Cards change slowly: every 5 s is plenty
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			player:SetAttribute("FarmLevel", data.level)
			-- Other players' Farmer Cards read this (client UI/FarmerCard)
			if cardTick or player:GetAttribute("FarmerCard") == nil then
				local card = HttpService:JSONEncode(Records.publicCard(data, Clock.now()))
				if player:GetAttribute("FarmerCard") ~= card then
					player:SetAttribute("FarmerCard", card)
				end
			end
			local neighbors = math.min(SocialService.goodNeighbors(player), 2)
			if player:GetAttribute("GoodNeighbors") ~= neighbors then
				player:SetAttribute("GoodNeighbors", neighbors)
			end
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
	task.spawn(refreshHeartStatus, player)
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

	-- The Puzzle Porch opens Crop Pop (the client does the opening). Every part of it takes
	-- taps: the screen, buttons and roof cover most of the cabinet's body.
	for _, part in PlotService.square.porchModel:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("Interact", "PuzzlePorch")
		end
	end
	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Front
	sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sign.PixelsPerStud = 40
	sign.Parent = PlotService.square.porchSign
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.TextScaled = true
	signText.Font = Enum.Font.FredokaOne
	signText.TextColor3 = Palette.barnRed
	signText.Text = "Crop Pop"
	signText.Parent = sign

	NetService.on(Net.Social_GiftHeart, 1, 2, giftHeart)
	NetService.on(Net.Debug_TestNeighbor, 1, 2, testNeighborFarm)
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
		local ticks = 0
		while true do
			task.wait(1)
			presenceTick()
			ticks += 1
			if ticks % 30 == 0 then -- hearts reset at the UTC day; Crop Pop may send some too
				for _, player in Players:GetPlayers() do
					task.spawn(refreshHeartStatus, player)
				end
			end
		end
	end)
end

return SocialService
