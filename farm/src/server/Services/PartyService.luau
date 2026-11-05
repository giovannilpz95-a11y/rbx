--!strict
-- The Farmhand Party (Config/Party, shared/Party; Design/14 K1). Friends on any server form a
-- party of up to four; the leader's Gather teleports everyone to the leader's server, or to
-- a fresh reserved server when it is too full. The party record lives in a MemoryStore hash
-- map shared by every server ("FarmParties", plus "FarmPartyOf": user id -> party id), and
-- servers tell each other about invites, changes and Gathers on a MessagingService topic per
-- player. Studio, or a server without those services, keeps parties on this server only.
-- Clients read their party from player attributes: "PartyId", "Party" (JSON) and
-- "PartyInvites" (JSON).

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Party)
local Net = require(Shared.Net)
local Party = require(Shared.Party)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local SocialService = require(script.Parent.SocialService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local PartyService = {}

type Record = Party.Record
type Message = { [string]: any }

---------------------------------------------------------------------------------------------
-- Storage: the MemoryStore hash maps, or plain tables on this server when they're missing
---------------------------------------------------------------------------------------------

local parties: MemoryStoreHashMap? = nil
local partyOf: MemoryStoreHashMap? = nil
local localParties: { [string]: Record } = {}
local localPartyOf: { [string]: string } = {}

local function openStores()
	if RunService:IsStudio() then
		return -- Studio: this server only (no cross-server party to find)
	end
	local ok, a = pcall(MemoryStoreService.GetHashMap, MemoryStoreService, "FarmParties")
	local ok2, b = pcall(MemoryStoreService.GetHashMap, MemoryStoreService, "FarmPartyOf")
	if ok and ok2 then
		parties, partyOf = a, b
	else
		warn("[PartyService] MemoryStore unavailable: parties stay on this server")
	end
end

local function getRecord(id: string): Record?
	local map = parties
	if map == nil then
		return localParties[id]
	end
	local ok, value = pcall(map.GetAsync, map, id)
	return if ok and type(value) == "table" then value :: any else nil
end

-- Change a party atomically. `change` edits the record and returns false to leave it as it
-- was; a record left with no members is removed. Returns the record as written (or nil).
local function updateRecord(id: string, change: (Record?) -> (Record?, boolean)): Record?
	local map = parties
	if map == nil then
		local p, keep = change(localParties[id])
		if keep then
			localParties[id] = if p and #p.members > 0 then p else nil
		end
		return localParties[id]
	end
	local written: Record? = nil
	local ok, err = pcall(function()
		map:UpdateAsync(id, function(old)
			local p, keep = change(if type(old) == "table" then old :: any else nil)
			if not keep then
				written = old
				return nil
			end
			written = p
			return p
		end, Config.expirySeconds)
	end)
	if not ok then
		warn("[PartyService] party update failed:", err)
		return nil
	end
	local result = written :: Record?
	if result and #result.members == 0 then
		pcall(map.RemoveAsync, map, id)
		return nil
	end
	return result
end

local function getPartyOf(userId: number): string?
	local map = partyOf
	if map == nil then
		return localPartyOf[tostring(userId)]
	end
	local ok, value = pcall(map.GetAsync, map, tostring(userId))
	return if ok and type(value) == "string" then value else nil
end

local function setPartyOf(userId: number, id: string?)
	local map = partyOf
	if map == nil then
		localPartyOf[tostring(userId)] = id
		return
	end
	if id then
		pcall(map.SetAsync, map, tostring(userId), id, Config.expirySeconds)
	else
		pcall(map.RemoveAsync, map, tostring(userId))
	end
end

---------------------------------------------------------------------------------------------
-- What each client sees
---------------------------------------------------------------------------------------------

local invites: { [Player]: { [string]: { by: string, at: number } } } = {}
local subscriptions: { [Player]: RBXScriptConnection } = {}
local current: { [Player]: string } = {} -- local players' party ids

local function showInvites(player: Player)
	local list = {}
	local now = Clock.now()
	for id, inv in invites[player] or {} do
		if now - inv.at <= Config.inviteSeconds then
			table.insert(list, { party = id, by = inv.by, at = inv.at })
		end
	end
	player:SetAttribute("PartyInvites", if #list > 0 then HttpService:JSONEncode(list) else "")
end

local function showParty(player: Player, p: Record?)
	local mine = p and Party.find(p, player.UserId) ~= nil
	if p == nil or not mine then
		current[player] = nil
		player:SetAttribute("PartyId", "")
		player:SetAttribute("Party", "")
		return
	end
	local party = p :: Record
	current[player] = party.id
	local now = Clock.now()
	local members = {}
	for _, m in party.members do
		table.insert(members, { id = m.id, name = m.name, away = Party.isAway(m, now) })
	end
	player:SetAttribute("PartyId", party.id)
	player:SetAttribute(
		"Party",
		HttpService:JSONEncode({
			leader = party.leader,
			members = members,
			gatherAt = party.gatheredAt + Config.gatherCooldown,
		})
	)
end

local function popup(player: Player, step: string, text: string)
	NetService.popup(player, { kind = "Party", step = step, text = text })
end

---------------------------------------------------------------------------------------------
-- Messages between servers: one topic per player ("FarmParty_<user id>")
---------------------------------------------------------------------------------------------

local function topic(userId: number): string
	return "FarmParty_" .. userId
end

local deliver: (player: Player, message: Message) -> ()

-- Send to one player wherever they are (straight in when they're on this server)
local function send(userId: number, message: Message)
	local here = Players:GetPlayerByUserId(userId)
	if here then
		task.spawn(deliver, here, message)
		return
	end
	if parties == nil then
		return -- this server only
	end
	task.spawn(function()
		local ok, err = pcall(MessagingService.PublishAsync, MessagingService, topic(userId), message)
		if not ok then
			warn("[PartyService] message failed:", err)
		end
	end)
end

-- Tell every member (and anyone just removed) to read the party again
local function broadcast(p: Record?, alsoIds: { number }?, id: string)
	local ids = if p then Party.ids(p) else {}
	for _, extra in alsoIds or {} do
		if table.find(ids, extra) == nil then
			table.insert(ids, extra)
		end
	end
	for _, userId in ids do
		send(userId, { type = "update", party = id })
	end
end

---------------------------------------------------------------------------------------------
-- Travel
---------------------------------------------------------------------------------------------

-- A public server by its JobId, or a reserved one by its access code (and private server id,
-- so members already on it stay put)
type Destination = { placeId: number, jobId: string?, code: string?, psid: string? }

local function isHere(dest: Destination): boolean
	if dest.code then
		return dest.psid ~= nil and dest.psid == game.PrivateServerId
	end
	return dest.jobId == game.JobId
end

local function travel(list: { Player }, dest: Destination, partyId: string)
	if #list == 0 then
		return
	end
	for _, player in list do
		DataService.saveNow(player) -- the next server waits for the lock this leaves behind
	end
	local options = Instance.new("TeleportOptions")
	if dest.code then
		options.ReservedServerAccessCode = dest.code
	elseif dest.jobId then
		options.ServerInstanceId = dest.jobId
	end
	options:SetTeleportData({ party = partyId })
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, dest.placeId, list, options)
	if not ok then
		warn("[PartyService] teleport failed:", err)
		for _, player in list do
			NetService.toast(player, "Couldn't travel to your party just now. Ask the leader to Gather again.", "error")
		end
	end
end

local function onGather(player: Player, message: Message)
	local dest = message.dest
	if type(dest) ~= "table" or type(dest.placeId) ~= "number" or current[player] ~= message.party then
		return
	end
	if isHere(dest :: any) then
		popup(player, "gather", string.format("%s gathered the party here!", tostring(message.by)))
		return
	end
	popup(player, "gather", string.format("%s is gathering the party: off you go in 5 seconds!", tostring(message.by)))
	task.delay(5, function()
		if player.Parent and current[player] == message.party then
			travel({ player }, dest :: any, message.party)
		end
	end)
end

deliver = function(player: Player, message: Message)
	if player.Parent == nil or type(message) ~= "table" or type(message.party) ~= "string" then
		return
	end
	local kind = message.type -- not "kind": that names a client popup
	if kind == "update" then
		local p = getRecord(message.party)
		if current[player] == message.party or (p and Party.find(p, player.UserId)) then
			showParty(player, p)
		end
	elseif kind == "invite" then
		local list = invites[player] or {}
		invites[player] = list
		list[message.party] = { by = tostring(message.by), at = Clock.now() }
		showInvites(player)
		popup(
			player,
			"invite",
			string.format("%s invited you to a Farmhand Party! Open Neighbors (N) to answer.", tostring(message.by))
		)
	elseif kind == "gather" then
		onGather(player, message)
	end
end

local function subscribe(player: Player)
	if parties == nil then
		return
	end
	task.spawn(function()
		local ok, conn = pcall(MessagingService.SubscribeAsync, MessagingService, topic(player.UserId), function(packet)
			deliver(player, packet.Data)
		end)
		if ok and conn then
			if player.Parent then
				subscriptions[player] = conn
			else
				conn:Disconnect()
			end
		end
	end)
end

---------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------

local function level(player: Player): number
	local data = DataService.get(player)
	return if data then data.level else 0
end

local function isFriendId(player: Player, userId: number): boolean
	local here = Players:GetPlayerByUserId(userId)
	if here then
		return SocialService.isFriend(player, here)
	end
	local ok, result = pcall(player.IsFriendsWith, player, userId)
	return ok and result == true
end

function PartyService.invite(player: Player, toId: any): (boolean, string?)
	if not NetService.check.int(toId, 1, 2 ^ 53) or toId == player.UserId then
		return false
	end
	if level(player) < Config.minLevel then
		return false, string.format("Farmhand Parties open at level %d", Config.minLevel)
	end
	if not isFriendId(player, toId) then
		return false, "You can invite friends only"
	end
	local now = Clock.now()
	local id = current[player]
	if id == nil then
		id = HttpService:GenerateGUID(false)
		local created = Party.new(id :: string, player.UserId, player.DisplayName, now)
		if updateRecord(id :: string, function()
			return created, true
		end) == nil then
			return false, "Couldn't start a party just now. Try again soon."
		end
		setPartyOf(player.UserId, id)
		TelemetryService.custom(player, "PartyStart", 1)
	end
	local partyId = id :: string
	local why: string? = nil
	local p = updateRecord(partyId, function(old)
		if old == nil then
			why = "Your party has ended"
			return nil, false
		end
		local ok, reason = Party.invite(old, player.UserId, toId, now)
		why = reason
		return old, ok
	end)
	if why or p == nil then
		return false, why
	end
	showParty(player, p)
	send(toId, { type = "invite", party = partyId, by = player.DisplayName })
	NetService.toast(player, "Invite sent! It waits two minutes for an answer.")
	return false -- nothing in the save changed
end

local function leaveCurrent(player: Player)
	local id = current[player]
	if id == nil then
		return
	end
	local p = updateRecord(id, function(old)
		if old == nil then
			return nil, false
		end
		Party.leave(old, player.UserId)
		return old, true
	end)
	setPartyOf(player.UserId, nil)
	showParty(player, nil)
	broadcast(p, { player.UserId }, id)
end

function PartyService.answer(player: Player, partyId: any, answer: any): (boolean, string?)
	if type(partyId) ~= "string" or #partyId > 64 or (answer ~= "Yes" and answer ~= "No") then
		return false
	end
	local list = invites[player]
	if list == nil or list[partyId] == nil then
		return false
	end
	list[partyId] = nil
	showInvites(player)
	if answer == "No" then
		return false
	end
	if level(player) < Config.minLevel then
		return false, string.format("Farmhand Parties open at level %d", Config.minLevel)
	end
	if current[player] == partyId then
		return false
	end
	leaveCurrent(player)
	local now = Clock.now()
	local why: string? = nil
	local p = updateRecord(partyId, function(old)
		if old == nil then
			why = "That party has ended"
			return nil, false
		end
		local ok, reason = Party.accept(old, player.UserId, player.DisplayName, now)
		why = reason
		return old, ok
	end)
	if why or p == nil then
		return false, why
	end
	setPartyOf(player.UserId, partyId)
	broadcast(p, nil, partyId)
	popup(player, "joined", "You joined the Farmhand Party! The leader can Gather everyone onto one server.")
	TelemetryService.custom(player, "PartyJoin", #(p :: Record).members)
	return false
end

function PartyService.leave(player: Player): (boolean, string?)
	if current[player] == nil then
		return false
	end
	leaveCurrent(player)
	NetService.toast(player, "You left the Farmhand Party.")
	return false
end

function PartyService.kick(player: Player, userId: any): (boolean, string?)
	local id = current[player]
	if id == nil or not NetService.check.int(userId, 1, 2 ^ 53) then
		return false
	end
	local okKick = false
	local p = updateRecord(id, function(old)
		if old == nil then
			return nil, false
		end
		okKick = Party.kick(old, player.UserId, userId)
		return old, okKick
	end)
	if not okKick then
		return false
	end
	setPartyOf(userId, nil)
	broadcast(p, { userId }, id)
	return false
end

function PartyService.gather(player: Player): (boolean, string?)
	local id = current[player]
	if id == nil then
		return false, "Start a party first: invite a friend from Neighbors"
	end
	local now = Clock.now()
	local why: string? = nil
	local coming = 0
	local p = updateRecord(id, function(old)
		if old == nil then
			why = "Your party has ended"
			return nil, false
		end
		local ok, reason = Party.canGather(old, player.UserId, now)
		if not ok then
			why = reason
			return old, false
		end
		old.gatheredAt = now
		coming = 0
		for _, m in old.members do
			if not Party.isAway(m, now) and Players:GetPlayerByUserId(m.id) == nil then
				coming += 1
			end
		end
		return old, true
	end)
	if why or p == nil then
		return false, why
	end
	local party = p :: Record
	showParty(player, party)
	TelemetryService.custom(player, "PartyGather", coming)
	if coming == 0 then
		NetService.toast(player, "Your whole party is already on this server!")
		return false
	end
	if RunService:IsStudio() then
		NetService.toast(player, "Dev: Studio can't teleport. The party would travel to this server now.")
		return false
	end
	local free = Players.MaxPlayers - #Players:GetPlayers()
	local roomHere = Party.destination(free, coming) == "here"
	local dest: Destination
	if roomHere and game.PrivateServerId == "" then
		dest = { placeId = game.PlaceId, jobId = game.JobId }
	elseif roomHere and party.code and party.psid == game.PrivateServerId then
		-- The party's own reserved server from an earlier Gather: everyone comes back here
		dest = { placeId = game.PlaceId, code = party.code, psid = party.psid }
	else
		local ok, code, psid = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
		if not ok or type(code) ~= "string" then
			return false, "Couldn't find a server for your party just now. Try again soon."
		end
		dest = { placeId = game.PlaceId, code = code, psid = if type(psid) == "string" then psid else nil }
		local keep = dest
		updateRecord(id, function(old)
			if old == nil then
				return nil, false
			end
			old.code, old.psid = keep.code, keep.psid
			return old, true
		end)
	end
	for _, userId in Party.ids(party) do
		if userId ~= player.UserId then
			send(userId, { type = "gather", party = id, dest = dest, by = player.DisplayName })
		end
	end
	if not isHere(dest) then
		popup(player, "gather", "Your server is full, so the party meets on a fresh one: off you go in 5 seconds!")
		task.delay(5, function()
			if player.Parent then
				travel({ player }, dest, id)
			end
		end)
	else
		popup(player, "gather", "Gathering your party here! They'll arrive in a moment.")
	end
	return false
end

-- Studio: a stand-in friend joins your party (to see the panel and the Gather check)
function PartyService.debug(player: Player): (boolean, string?)
	if not RunService:IsStudio() then
		return false
	end
	local now = Clock.now()
	local id = current[player] or HttpService:GenerateGUID(false)
	local p = updateRecord(id, function(old)
		local rec = old or Party.new(id, player.UserId, player.DisplayName, now)
		-- Far below Studio's own test players (-1, -2, ...)
		local fake = -1000 - #rec.members
		if #rec.members < Config.maxMembers then
			table.insert(rec.members, { id = fake, name = "Test Farmhand " .. #rec.members, seen = now })
		end
		return rec, true
	end)
	setPartyOf(player.UserId, id)
	showParty(player, p)
	NetService.toast(player, "Dev: a test farmhand joined your party")
	return false
end

---------------------------------------------------------------------------------------------

local function arrive(player: Player)
	subscribe(player)
	invites[player] = {}
	showInvites(player)
	local id = getPartyOf(player.UserId)
	local p = id and getRecord(id)
	if id and p and Party.find(p, player.UserId) then
		local now = Clock.now()
		p = updateRecord(id, function(old)
			if old == nil then
				return nil, false
			end
			Party.touch(old, player.UserId, now)
			return old, true
		end)
		showParty(player, p)
		broadcast(p, nil, id)
	else
		showParty(player, nil)
		if id then
			setPartyOf(player.UserId, nil)
		end
	end
end

-- Every server refreshes its members' "seen" times and drops what has run out
local function heartbeat()
	local byParty: { [string]: { Player } } = {}
	for player, id in current do
		if player.Parent then
			local list = byParty[id] or {}
			byParty[id] = list
			table.insert(list, player)
		end
	end
	local now = Clock.now()
	for id, list in byParty do
		local before = 0
		local p = updateRecord(id, function(old)
			if old == nil then
				return nil, false
			end
			before = #old.members
			for _, player in list do
				Party.touch(old, player.UserId, now)
			end
			Party.prune(old, now)
			return old, true
		end)
		for _, player in list do
			setPartyOf(player.UserId, id) -- keeps the link from expiring
			showParty(player, p)
		end
		if p == nil or #p.members ~= before then
			broadcast(p, nil, id)
		end
	end
	for player in invites do
		showInvites(player) -- expired invites drop off
	end
end

function PartyService.init()
	openStores()
	NetService.on(Net.Party_Invite, 2, 4, PartyService.invite)
	NetService.on(Net.Party_Answer, 2, 4, PartyService.answer)
	NetService.on(Net.Party_Leave, 1, 2, PartyService.leave)
	NetService.on(Net.Party_Kick, 2, 3, PartyService.kick)
	NetService.on(Net.Party_Gather, 1, 2, PartyService.gather)
	NetService.on(Net.Debug_Party, 1, 2, PartyService.debug)

	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		warn("[PartyService] teleport init failed:", player.Name, result, message)
		NetService.toast(player, "Couldn't travel to your party just now. Ask the leader to Gather again.", "error")
	end)
	local function watch(player: Player)
		NetService.whenReady(player, function()
			arrive(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- Leaving the server isn't leaving the party (they may be travelling to it)
		local conn = subscriptions[player]
		subscriptions[player] = nil
		if conn then
			conn:Disconnect()
		end
		invites[player] = nil
		current[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.heartbeatSeconds)
			heartbeat()
		end
	end)
end

return PartyService
