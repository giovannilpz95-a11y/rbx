--!strict
-- Farmhand Party rules (Config/Party; Design/14 K1), pure so Lune tests cover them. A party
-- is one record shared by every server its members are on (PartyService keeps it in a
-- MemoryStore hash map); each function changes the record in place and returns true, or
-- false and a reason for the player.

local Config = require("./Config/Party")

local Party = {}

export type Member = { id: number, name: string, seen: number }
export type Record = {
	id: string,
	leader: number,
	members: { Member },
	invites: { [string]: { at: number, by: string } }, -- invited user id -> when and who
	gatheredAt: number,
	code: string?, -- the reserved server of the last Gather that needed one (PartyService)
	psid: string?, -- and its private server id
}

function Party.new(id: string, leaderId: number, name: string, now: number): Record
	return {
		id = id,
		leader = leaderId,
		members = { { id = leaderId, name = name, seen = now } },
		invites = {},
		gatheredAt = 0,
	}
end

function Party.find(p: Record, userId: number): number?
	for i, m in p.members do
		if m.id == userId then
			return i
		end
	end
	return nil
end

-- Drop expired invites and members gone too long. A dropped leader hands over to the next
-- member. Returns true when anything changed.
function Party.prune(p: Record, now: number): boolean
	local changed = false
	for key, inv in p.invites do
		if now - inv.at > Config.inviteSeconds then
			p.invites[key] = nil
			changed = true
		end
	end
	for i = #p.members, 1, -1 do
		if now - p.members[i].seen > Config.dropSeconds then
			table.remove(p.members, i)
			changed = true
		end
	end
	if #p.members > 0 and Party.find(p, p.leader) == nil then
		p.leader = p.members[1].id
		changed = true
	end
	return changed
end

-- A member's server saw them just now
function Party.touch(p: Record, userId: number, now: number)
	local i = Party.find(p, userId)
	if i then
		p.members[i].seen = now
	end
end

function Party.isAway(m: Member, now: number): boolean
	return now - m.seen > Config.offlineSeconds
end

function Party.invite(p: Record, fromId: number, toId: number, now: number): (boolean, string?)
	local i = Party.find(p, fromId)
	if i == nil then
		return false, nil
	end
	if Party.find(p, toId) then
		return false, "They're already in your party"
	end
	if #p.members >= Config.maxMembers then
		return false, string.format("A party has room for %d farmers", Config.maxMembers)
	end
	p.invites[tostring(toId)] = { at = now, by = p.members[i].name }
	return true, nil
end

function Party.accept(p: Record, userId: number, name: string, now: number): (boolean, string?)
	Party.prune(p, now)
	local key = tostring(userId)
	if p.invites[key] == nil then
		return false, "That invite has run out. Ask for a new one."
	end
	p.invites[key] = nil
	if Party.find(p, userId) then
		return true, nil
	end
	if #p.members >= Config.maxMembers then
		return false, "That party is full now"
	end
	table.insert(p.members, { id = userId, name = name, seen = now })
	return true, nil
end

-- Leave (or be dropped). Returns true when the party is now empty.
function Party.leave(p: Record, userId: number): boolean
	local i = Party.find(p, userId)
	if i then
		table.remove(p.members, i)
	end
	if #p.members > 0 and p.leader == userId then
		p.leader = p.members[1].id
	end
	return #p.members == 0
end

function Party.kick(p: Record, byId: number, userId: number): (boolean, string?)
	if p.leader ~= byId or byId == userId then
		return false, nil
	end
	if Party.find(p, userId) == nil then
		return false, nil
	end
	Party.leave(p, userId)
	return true, nil
end

function Party.canGather(p: Record, byId: number, now: number): (boolean, string?)
	if p.leader ~= byId then
		return false, "Only the party leader can Gather"
	end
	local here = 0
	for _, m in p.members do
		if m.id ~= byId and not Party.isAway(m, now) then
			here += 1
		end
	end
	if here == 0 then
		return false, "Invite a friend first: nobody else is in your party"
	end
	local wait = Config.gatherCooldown - (now - p.gatheredAt)
	if wait > 0 then
		return false, string.format("Gather again in %d s", math.ceil(wait))
	end
	return true, nil
end

-- Where to Gather: "here" when the leader's server has room for everyone not on it yet
function Party.destination(freeSlots: number, coming: number): "here" | "reserve"
	return if coming <= freeSlots then "here" else "reserve"
end

-- The member ids, leader first, for messages to every member's server
function Party.ids(p: Record): { number }
	local out = { p.leader }
	for _, m in p.members do
		if m.id ~= p.leader then
			table.insert(out, m.id)
		end
	end
	return out
end

return Party
