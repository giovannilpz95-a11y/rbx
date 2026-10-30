--!strict
-- Pure rules for the social slice (Design/14 Multiplayer Features), kept apart from the
-- services so the Lune tests can cover them. `data.social` is the save block (shared/Profile);
-- user ids are stored as strings so the save stays a plain JSON object.

local Social = require("./Config/Social")

local Rules = {}

local DAY = 86400

function Rules.utcDay(now: number): number
	return now // DAY
end

-- May this player walk onto the plot? Blocked players never may, whatever the setting.
function Rules.canVisit(privacy: string, isFriend: boolean, blocked: boolean): boolean
	if blocked then
		return false
	elseif privacy == "Open" then
		return true
	elseif privacy == "Friends" then
		return isFriend
	end
	return false
end

-- May this player help on the plot (Helping Hands)?
function Rules.canHelp(helpers: string, isFriend: boolean, blocked: boolean): boolean
	if blocked then
		return false
	elseif helpers == "Anyone" then
		return true
	elseif helpers == "Friends" then
		return isFriend
	end
	return false
end

-- Start a new day's help budget when the UTC day has changed.
local function helpToday(social: { [string]: any }, day: number): { [string]: any }
	local help = social.help
	if help.day ~= day then
		help.day = day
		help.used = 0
		help.owners = {}
	end
	return help
end

-- Helping actions left today: in total, and on this owner's plot.
function Rules.helpLeft(social: { [string]: any }, ownerUserId: number, day: number): (number, number)
	local help = helpToday(social, day)
	local onOwner = help.owners[tostring(ownerUserId)] or 0
	return math.max(0, Social.helpPerDay - help.used), math.max(0, Social.helpPerOwnerPerDay - onOwner)
end

-- Use one helping action. Returns false (and changes nothing) when either budget is spent.
function Rules.spendHelp(social: { [string]: any }, ownerUserId: number, day: number): boolean
	local total, onOwner = Rules.helpLeft(social, ownerUserId, day)
	if total <= 0 or onOwner <= 0 then
		return false
	end
	local help = social.help
	local key = tostring(ownerUserId)
	help.used += 1
	help.owners[key] = (help.owners[key] or 0) + 1
	return true
end

-- Watering takes a share off the time left (whole seconds), once per crop.
function Rules.wateredReadyAt(readyAt: number, now: number): number
	local left = math.max(0, readyAt - now)
	return readyAt - math.floor(left * Social.waterCut)
end

-- The Coins the game pays a helper for harvesting a field: a share of its sell value, at least 1.
function Rules.helperCoins(sellPrice: number, yield: number): number
	return math.max(1, math.floor(sellPrice * yield * Social.helperCoinShare + 0.5))
end

-- Good Neighbors: the extra share of order Coins for this many qualifying friends.
function Rules.neighborBonus(friends: number): number
	return math.min(friends * Social.neighborBonusPerFriend, Social.neighborBonusMax)
end

-- The extra Coins a bonus share adds to a payout (at least 1 when there's any bonus).
function Rules.bonusCoins(coins: number, bonus: number): number
	if bonus <= 0 or coins <= 0 then
		return 0
	end
	return math.max(1, math.floor(coins * bonus + 0.5))
end

function Rules.boostActive(social: { [string]: any }, now: number): boolean
	return (social.boostUntil or 0) > now
end

-- Grow time for a crop planted now: shorter during a Welcome Boost.
function Rules.growSeconds(seconds: number, boosted: boolean): number
	if not boosted then
		return seconds
	end
	return math.max(1, math.floor(seconds * (1 - Social.welcomeGrowCut) + 0.5))
end

-- Start (or extend) a Welcome Boost for being here with this friend. Once per friend per
-- UTC day; returns false when this pair already had today's.
function Rules.grantBoost(social: { [string]: any }, friendUserId: number, now: number): boolean
	local day = Rules.utcDay(now)
	if social.boostDay ~= day then
		social.boostDay = day
		social.boostPairs = {}
	end
	local key = tostring(friendUserId)
	if social.boostPairs[key] then
		return false
	end
	social.boostPairs[key] = true
	social.boostUntil = math.max(social.boostUntil or 0, now) + Social.welcomeSeconds
	return true
end

return Rules
