--!strict
-- The Farmhand Party (Design/14 K1): up to four friends from any server form a party, and
-- the leader can Gather it: everyone travels to one server, the leader's if it has room or a
-- fresh reserved one. Numbers are first-pass (Township has no cross-server parties).

return table.freeze({
	maxMembers = 4,
	inviteSeconds = 120, -- an invite waits this long for an answer
	gatherCooldown = 60, -- seconds between Gathers (no teleport loops)
	heartbeatSeconds = 30, -- each server refreshes its members this often
	offlineSeconds = 120, -- a member not refreshed for this long shows as away
	dropSeconds = 600, -- and is dropped after this long (teleports take well under it)
	expirySeconds = 2 * 3600, -- the stored party and member links expire after this
	minLevel = 2, -- to start or join a party (past the first-session guide)
})
