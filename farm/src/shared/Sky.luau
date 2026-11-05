--!strict
-- Sky events' rules (Config/Sky): the fixed UTC schedule and the Prize Crop traits weather
-- gives. Pure, so the server, the client and the Lune tests agree on when the next event is.

local Config = require("./Config/Sky")
local Prize = require("./Config/Prize")
local Rng = require("./Rng")

local Sky = {}

export type Event = { kind: string, startsAt: number, endsAt: number }

-- (a * b) mod 2^32 without losing precision in doubles
local function mul32(a: number, b: number): number
	local lo, hi = a % 65536, math.floor(a / 65536)
	return (lo * b + ((hi * b) % 65536) * 65536) % 4294967296
end

-- A well-mixed seed for an hour, so neighbouring hours look unrelated
local function hourSeed(hour: number): number
	local x = hour % 4294967296
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x45d9f3b)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x45d9f3b)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	return Rng.normalize(x + 1)
end

-- UTC weekday (0 = Sunday) and hour of day
function Sky.weekday(t: number): number
	return (math.floor(t / 86400) + 4) % 7
end

function Sky.hourOfDay(t: number): number
	return math.floor((t % 86400) / 3600)
end

function Sky.isPeak(t: number): boolean
	local hour = Sky.hourOfDay(t)
	return Sky.weekday(t) == Config.peak.weekday and hour >= Config.peak.fromHour and hour < Config.peak.toHour
end

local function pickKind(roll: number): string
	local total = 0
	for _, id in Config.order do
		total += Config.kinds[id].weight
	end
	local at = roll * total
	for _, id in Config.order do
		at -= Config.kinds[id].weight
		if at < 0 then
			return id
		end
	end
	return Config.order[#Config.order]
end

-- The events in the UTC hour `hour` (hours since the epoch), in start order
function Sky.eventsInHour(hour: number): { Event }
	local base = hour * 3600
	local seed = hourSeed(hour)
	local peak = Sky.isPeak(base)
	local out = {}
	for i, slot in Config.slots do
		local chance, minute, kindRoll
		chance, seed = Rng.next(seed)
		minute, seed = Rng.int(seed, slot.from, slot.to)
		kindRoll, seed = Rng.next(seed)
		if chance < (if peak and i > 1 then 1 else slot.chance) then
			local kind = pickKind(kindRoll)
			local startsAt = base + minute * 60
			table.insert(out, { kind = kind, startsAt = startsAt, endsAt = startsAt + Config.kinds[kind].seconds })
		end
	end
	return out
end

-- The scheduled event running at `now`, if any (every event ends inside its hour)
function Sky.current(now: number): Event?
	for _, event in Sky.eventsInHour(math.floor(now / 3600)) do
		if now >= event.startsAt and now < event.endsAt then
			return event
		end
	end
	return nil
end

-- The next scheduled event starting after `now`
function Sky.nextEvent(now: number): Event?
	local hour = math.floor(now / 3600)
	for h = hour, hour + 2 do
		for _, event in Sky.eventsInHour(h) do
			if event.startsAt > now then
				return event
			end
		end
	end
	return nil
end

-- "Rain Shower expected at :31"
function Sky.forecastText(event: Event): string
	return string.format(
		"%s expected at :%02d",
		Config.kinds[event.kind].displayName,
		math.floor((event.startsAt % 3600) / 60)
	)
end

-- Is this field growing (planted and not ready) at `now`?
function Sky.isGrowing(field: { [string]: any }, now: number): boolean
	return field.crop ~= nil and field.readyAt ~= nil and field.readyAt > now
end

-- Seconds a growing field's timer drops by when `event` reaches it at `now`: it grows
-- growBoost faster for what's left of the event (or of its timer, if that ends first)
function Sky.growCut(event: Event, readyAt: number, now: number): number
	local boost = Config.kinds[event.kind].growBoost
	if boost == nil then
		return 0
	end
	local span = math.max(0, math.min(event.endsAt, readyAt) - now)
	return math.floor(span * boost)
end

-- The weather roll for a growing field (once per event per field, `roll` uniform in [0, 1)).
-- A hit sets the event's trait unless the field already has a rarer one. True on a hit.
-- None while the first-session guide runs.
function Sky.weatherRoll(data: { [string]: any }, field: { [string]: any }, event: Event, roll: number): boolean
	if data.tutorial.step ~= 0 or field.sky == event.startsAt then
		return false
	end
	field.sky = event.startsAt
	local trait = Config.kinds[event.kind].trait
	local tier = Prize.tiers[trait]
	if roll >= tier.chance then
		return false
	end
	local had = field.prize and Prize.tiers[field.prize]
	if had and had.value >= tier.value then
		return false
	end
	field.prize = trait
	return true
end

-- Coins a star gives at `level`
function Sky.starCoins(level: number): number
	return Config.starCoins + Config.starCoinsPerLevel * level
end

-- Coins a Rainbow chest gives at `level`, and the owner's thank-you for one neighbor's visit
function Sky.chestCoins(level: number): number
	return Config.rainbow.coins + Config.rainbow.coinsPerLevel * level
end

function Sky.thanksCoins(level: number): number
	return Config.rainbow.thanksCoins + Config.rainbow.thanksPerLevel * level
end

-- Stars a whole Starfall drops for one player
function Sky.starsPerShower(kind: string): number
	return math.floor(Config.kinds[kind].seconds / Config.starEvery)
end

return Sky
