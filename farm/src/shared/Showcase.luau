--!strict
-- Plot Showcase rules (Config/Showcase), pure for the server, the client and the Lune tests:
-- the hourly window, who may rate whom, the weighted sunflower count and the winner.

local Config = require("./Config/Showcase")

local Showcase = {}

local HOUR = 3600

local preview: number? = nil -- Studio: a Showcase starting at this time

function Showcase.setPreview(startsAt: number?)
	preview = startsAt
end

-- The Showcase window around `now`: this hour's (or the preview's) start and end
function Showcase.window(now: number): (number, number)
	if preview and now >= preview and now < preview + Config.seconds + Config.grace then
		return preview, preview + Config.seconds
	end
	local startsAt = (now // HOUR) * HOUR + Config.minute * 60
	return startsAt, startsAt + Config.seconds
end

function Showcase.isOn(now: number): boolean
	local startsAt, endsAt = Showcase.window(now)
	return now >= startsAt and now < endsAt
end

-- May a rating come in now (during the window or its short grace)?
function Showcase.canRate(now: number): boolean
	local startsAt, endsAt = Showcase.window(now)
	return now >= startsAt and now < endsAt + Config.grace
end

export type Vote = { voter: number, stars: number, weight: number }

-- Sunflowers a farm got: each vote's stars times its weight (friends count half)
function Showcase.total(votes: { Vote }): number
	local sum = 0
	for _, v in votes do
		sum += v.stars * v.weight
	end
	return sum
end

-- Checks a rating (the caller supplies what it knows); nil when fine, else why not
function Showcase.check(
	voterLevel: number,
	voterId: number,
	ownerId: number,
	ownerOptedIn: boolean,
	dwell: number,
	already: boolean,
	stars: any
): string?
	if type(stars) ~= "number" or stars % 1 ~= 0 or stars < 1 or stars > 3 then
		return "junk"
	elseif voterId == ownerId then
		return "Your own farm can't be rated"
	elseif voterLevel < Config.minLevel then
		return string.format("Rating farms opens at level %d", Config.minLevel)
	elseif not ownerOptedIn then
		return "That farm isn't in the Showcase"
	elseif already then
		return "You've rated this farm this Showcase"
	elseif dwell < Config.dwellSeconds then
		return string.format("Look around this farm for %d seconds first", Config.dwellSeconds)
	end
	return nil
end

-- The winning farm: the most sunflowers with at least minVotes votes; ties go to more votes,
-- then the lower user id (so every run agrees). nil when nobody qualifies.
function Showcase.winner(votes: { [number]: { Vote } }): (number?, number)
	local best, bestTotal, bestCount = nil, -1, -1
	for ownerId, list in votes do
		if #list >= Config.minVotes then
			local total = Showcase.total(list)
			if
				total > bestTotal
				or (total == bestTotal and #list > bestCount)
				or (total == bestTotal and #list == bestCount and best ~= nil and ownerId < best)
			then
				best, bestTotal, bestCount = ownerId, total, #list
			end
		end
	end
	return best, math.max(0, bestTotal)
end

return Showcase
