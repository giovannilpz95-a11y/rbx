--!strict
-- The Plot Showcase (Design/14 Multiplayer Features F3; roadmap week 10 with the County Fair):
-- a short tour of the server's best-kept farms. During it every farm that opted in shows a
-- sunflower banner over its gate; a visitor who spends a little while on one rates it 1-3
-- sunflowers. The farm with the most sunflowers on the server gets a ribbon on its gate for a
-- week, and every voter gets a little XP.
--
-- Decided defaults (tell Giovanni, easy to change):
--   * Every hour at :40-:45 UTC (clear of the Town Express at :00-:20 and the sky slots), only
--     on servers with at least one farm on show. Showing your farm is off until you switch it
--     on in Settings (opt-in, so nobody is put on display).
--   * Votes from friends count half; level 5+ to vote; one vote per farm per Showcase; never
--     your own farm. A win needs at least 2 votes.

return table.freeze({
	minute = 40, -- minutes past the hour (UTC) it starts
	seconds = 5 * 60,
	grace = 30, -- seconds after it ends that a rating still counts (the card was open)
	dwellSeconds = 20, -- time on a farm before you can rate it
	minLevel = 5, -- to vote
	friendWeight = 0.5,
	minVotes = 2, -- votes a farm needs to win
	xpPerVote = 5,
	xpVotesMax = 5, -- votes per Showcase that pay XP
	ribbonDays = 7,
})
