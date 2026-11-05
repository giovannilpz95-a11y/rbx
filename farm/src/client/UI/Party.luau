--!strict
-- The Farmhand Party panel (Config/Party, PartyService; Design/14 K1), opened from Neighbors.
-- Answer invites, see who's in your party and where, invite friends playing this game on
-- any server, and (as leader) Gather everyone onto one server. Party members on our server
-- get a little 🎉 marker over their heads. The server shares our party through our player
-- attributes "Party" and "PartyInvites" (JSON) and everyone's "PartyId".

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Party)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local PartyUi = {}

local player = Players.LocalPlayer
local lastTap = 0
local friends: { { id: number, name: string } } = {}
local friendsAt = -math.huge
local loadingFriends = false

local function decode(name: string): any
	local text = player:GetAttribute(name)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, text)
	return if ok then value else nil
end

local function pressButton(text: string, fire: () -> (), enabled: boolean, color: Color3, parent: Instance, x: number?)
	local function tap()
		if not enabled or time() - lastTap < 0.35 then
			return
		end
		lastTap = time()
		fire()
	end
	local button = Ui.button(text, tap, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x or 0, 0.5, 0),
		Size = UDim2.fromOffset(96, 34),
		BackgroundColor3 = color,
		Parent = parent,
	})
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tap()
		end
	end)
	Ui.setEnabled(button, enabled, color)
end

local function card(order: number, body: Instance): Frame
	local c = Ui.card({ Size = UDim2.new(1, -8, 0, 52), LayoutOrder = order, Parent = body })
	Ui.padding(6).Parent = c
	return c
end

local function lines(c: Frame, top: string, bottom: string, inset: number)
	Ui.label(top, { Font = Ui.theme.Type.display, Size = UDim2.new(1, -inset, 0, 20), Parent = c })
	Ui.label(bottom, {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -inset, 0, 20),
		TextSize = 13,
		TextColor3 = Ui.colors.muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = c,
	})
end

local function heading(text: string, order: number, body: Instance)
	Ui.label(text, {
		Font = Ui.theme.Type.display,
		Size = UDim2.new(1, -8, 0, 24),
		LayoutOrder = order,
		Parent = body,
	})
end

-- Friends playing this game right now, on any server (Roblox's own friends list)
local function loadFriends()
	if loadingFriends or os.clock() - friendsAt < 30 then
		return
	end
	loadingFriends = true
	task.spawn(function()
		local ok, list = pcall(player.GetFriendsOnline, player, 50)
		local out = {}
		if ok and type(list) == "table" then
			for _, f in list do
				if f.PlaceId == game.PlaceId and type(f.VisitorId) == "number" then
					table.insert(out, { id = f.VisitorId, name = tostring(f.DisplayName or f.UserName) })
				end
			end
		end
		-- Friends on this server too (and in Studio every test player)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local known = false
				for _, f in out do
					known = known or f.id == other.UserId
				end
				local friend = RunService:IsStudio()
				if not known and not friend then
					local okF, result = pcall(player.IsFriendsWith, player, other.UserId)
					friend = okF and result == true
				end
				if not known and friend then
					table.insert(out, { id = other.UserId, name = other.DisplayName })
				end
			end
		end
		friends = out
		friendsAt = os.clock()
		loadingFriends = false
		if Panels.isShowing("Party") then
			Panels.refresh()
		end
	end)
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Farmhand Party"
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	if (state.level or 0) < Config.minLevel then
		Ui.label(string.format("Farmhand Parties open at level %d.", Config.minLevel), {
			Size = UDim2.new(1, -8, 0, 40),
			TextWrapped = true,
			LayoutOrder = nextOrder(),
			Parent = body,
		})
		return
	end

	local invites = decode("PartyInvites") or {}
	if #invites > 0 then
		heading("Invites", nextOrder(), body)
		for _, inv in invites do
			local c = card(nextOrder(), body)
			lines(c, string.format("%s's party", tostring(inv.by)), "Join to travel and farm together", 200)
			pressButton("Join", function()
				Remotes.fire("Party_Answer", inv.party, "Yes")
			end, true, Ui.colors.accent, c)
			pressButton("No", function()
				Remotes.fire("Party_Answer", inv.party, "No")
			end, true, Ui.colors.selected, c, -102)
		end
	end

	local party = decode("Party")
	local inParty: { [number]: boolean } = {}
	if party and type(party.members) == "table" then
		local leading = party.leader == player.UserId
		heading(string.format("Your party (%d / %d)", #party.members, Config.maxMembers), nextOrder(), body)
		for _, m in party.members do
			inParty[m.id] = true
			local here = Players:GetPlayerByUserId(m.id) ~= nil
			local c = card(nextOrder(), body)
			lines(
				c,
				string.format("%s%s", if m.id == party.leader then "👑 " else "", tostring(m.name)),
				if m.id == player.UserId
					then "You"
					elseif here then "On this server"
					elseif m.away then "Away right now"
					else "On another server",
				110
			)
			if leading and m.id ~= player.UserId then
				pressButton("Remove", function()
					Remotes.fire("Party_Kick", m.id)
				end, true, Ui.colors.danger, c)
			end
		end
		local actions = card(nextOrder(), body)
		if leading then
			local wait = (party.gatherAt or 0) - ClientStore.now()
			lines(
				actions,
				"Gather everyone",
				if wait > 0
					then string.format("Gather again in %d s", math.ceil(wait))
					else "Brings the party to this server (or a fresh one)",
				210
			)
			pressButton("Gather", function()
				Remotes.fire("Party_Gather")
			end, wait <= 0, Ui.colors.accent, actions)
		else
			lines(actions, "Waiting for the leader", "The leader's Gather brings everyone together", 210)
		end
		pressButton("Leave", function()
			Remotes.fire("Party_Leave")
		end, true, Ui.colors.selected, actions, if leading then -102 else 0)
	end

	local full = party and #party.members >= Config.maxMembers
	if not full then
		heading("Invite friends playing now", nextOrder(), body)
		loadFriends()
		local shown = 0
		for _, f in friends do
			if not inParty[f.id] then
				shown += 1
				local c = card(nextOrder(), body)
				lines(c, f.name, if Players:GetPlayerByUserId(f.id) then "On this server" else "On another server", 110)
				pressButton("Invite", function()
					Remotes.fire("Party_Invite", f.id)
				end, true, Ui.colors.accent, c)
			end
		end
		if shown == 0 then
			Ui.label(if loadingFriends then "Looking for friends..." else "No friends are playing right now.", {
				Size = UDim2.new(1, -8, 0, 30),
				TextColor3 = Ui.colors.muted,
				LayoutOrder = nextOrder(),
				Parent = body,
			})
		end
	end
	Ui.label(
		string.format(
			"Up to %d friends from any server. The leader's Gather brings everyone onto one server; you can leave any time.",
			Config.maxMembers
		),
		{
			Size = UDim2.new(1, -8, 0, 40),
			TextWrapped = true,
			TextSize = 13,
			TextColor3 = Ui.colors.muted,
			LayoutOrder = 100,
			Parent = body,
		}
	)
end

---------------------------------------------------------------------------------------------
-- The 🎉 marker over party members on our server
---------------------------------------------------------------------------------------------

local MARKER = "PartyMarker"

local function mark(other: Player)
	local character = other.Character
	local head = character and character:FindFirstChild("Head")
	local mine = player:GetAttribute("PartyId")
	local same = other ~= player and type(mine) == "string" and mine ~= "" and other:GetAttribute("PartyId") == mine
	local existing = head and head:FindFirstChild(MARKER)
	if not same or head == nil then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = MARKER
	gui.Size = UDim2.fromOffset(90, 26)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "🎉 Party"
	label.Parent = gui
	gui.Parent = head
end

local function markAll()
	for _, other in Players:GetPlayers() do
		mark(other)
	end
end

local function watch(other: Player)
	other:GetAttributeChangedSignal("PartyId"):Connect(markAll)
	other.CharacterAdded:Connect(function()
		task.wait(0.5)
		mark(other)
	end)
	mark(other)
end

function PartyUi.init()
	Panels.register("Party", render, { live = true })
	local function refresh()
		if Panels.isShowing("Party") then
			Panels.refresh()
		end
	end
	player:GetAttributeChangedSignal("Party"):Connect(refresh)
	player:GetAttributeChangedSignal("PartyInvites"):Connect(refresh)
	Players.PlayerAdded:Connect(function(other)
		watch(other)
		friendsAt = -math.huge -- someone new to invite
	end)
	Players.PlayerRemoving:Connect(function()
		friendsAt = -math.huge
		refresh()
	end)
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Hud.handlers.Party = function(payload)
		if type(payload.text) == "string" then
			Hud.toast(payload.text, if payload.step == "joined" then "celebrate" else nil)
		end
	end
end

return PartyUi
