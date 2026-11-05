-- The Farmhand Party (src/shared/Party, Config/Party): invites, joining, leaving, the
-- leader, pruning and the Gather checks. Called from tests/run.luau.

local Config = require("../src/shared/Config/Party")
local Party = require("../src/shared/Party")

local T = 1793491200

return function(test: (string, () -> ()) -> (), eq: (any, any, string?) -> (), ok: (any, string) -> ())
	test("party: invite friends up to four, answer in time", function()
		local p = Party.new("p1", 10, "Ann", T)
		eq(#p.members, 1, "the leader")
		ok((Party.invite(p, 10, 20, T)), "invite Bea")
		eq(p.invites["20"].by, "Ann", "who invited")
		eq((Party.invite(p, 99, 30, T)), false, "only members invite")
		eq(select(2, Party.invite(p, 10, 10, T)), "They're already in your party", "not yourself")
		ok((Party.accept(p, 20, "Bea", T + 10)), "Bea joins")
		eq(#p.members, 2, "two now")
		eq(p.invites["20"], nil, "invite used up")
		eq(select(2, Party.accept(p, 30, "Cal", T + 10)), "That invite has run out. Ask for a new one.", "no invite")
		Party.invite(p, 20, 30, T + 20)
		eq(
			select(2, Party.accept(p, 30, "Cal", T + 20 + Config.inviteSeconds + 1)),
			"That invite has run out. Ask for a new one.",
			"too late"
		)
		Party.invite(p, 10, 30, T + 30)
		Party.invite(p, 10, 40, T + 30)
		Party.invite(p, 10, 50, T + 30)
		Party.accept(p, 30, "Cal", T + 40)
		Party.accept(p, 40, "Dee", T + 40)
		eq(#p.members, Config.maxMembers, "full")
		eq(select(2, Party.accept(p, 50, "Eve", T + 40)), "That party is full now", "no fifth")
		eq(select(2, Party.invite(p, 10, 60, T + 40)), "A party has room for 4 farmers", "no more invites")
		eq(table.concat(Party.ids(p), ","), "10,20,30,40", "leader first")
	end)

	test("party: leaving hands the lead on, and the last one out ends it", function()
		local p = Party.new("p1", 10, "Ann", T)
		Party.invite(p, 10, 20, T)
		Party.accept(p, 20, "Bea", T)
		eq((Party.kick(p, 20, 10)), false, "only the leader removes")
		eq((Party.kick(p, 10, 10)), false, "not yourself")
		eq(Party.leave(p, 10), false, "Bea is still in")
		eq(p.leader, 20, "Bea leads")
		eq(Party.leave(p, 20), true, "empty")
	end)

	test("party: members gone too long drop off", function()
		local p = Party.new("p1", 10, "Ann", T)
		Party.invite(p, 10, 20, T)
		Party.accept(p, 20, "Bea", T)
		Party.touch(p, 20, T + Config.dropSeconds)
		ok(Party.isAway(p.members[1], T + Config.offlineSeconds + 1), "Ann away")
		ok(not Party.isAway(p.members[2], T + Config.dropSeconds), "Bea here")
		ok(Party.prune(p, T + Config.dropSeconds + 1), "changed")
		eq(#p.members, 1, "Ann dropped")
		eq(p.leader, 20, "and Bea leads")
		eq(Party.prune(p, T + Config.dropSeconds + 2), false, "nothing more")
	end)

	test("party: Gather is the leader's, needs company, and waits its cooldown", function()
		local p = Party.new("p1", 10, "Ann", T)
		eq(select(2, Party.canGather(p, 10, T)), "Invite a friend first: nobody else is in your party", "alone")
		Party.invite(p, 10, 20, T)
		Party.accept(p, 20, "Bea", T)
		eq(select(2, Party.canGather(p, 20, T)), "Only the party leader can Gather", "leader only")
		ok((Party.canGather(p, 10, T)), "ok")
		p.gatheredAt = T
		eq(select(2, Party.canGather(p, 10, T + 10)), "Gather again in 50 s", "cooldown")
		ok((Party.canGather(p, 10, T + Config.gatherCooldown)), "after the cooldown")
		eq(
			select(2, Party.canGather(p, 10, T + Config.offlineSeconds + 100)),
			"Invite a friend first: nobody else is in your party",
			"Bea away"
		)
		eq(Party.destination(3, 3), "here", "room here")
		eq(Party.destination(2, 3), "reserve", "a fresh server")
	end)
end
