--!strict
-- The Otter Pond's rules (Config/OtterPond): pure, so the server, the panel and the tests
-- agree.
--
-- Save block `otterPond`:
--   readyAt    set when building starts; the pond is open from then on
--   seed       the RNG state each catch is drawn from
--   otters     how many otters live there (1 to 3)
--   trips      how many times an otter has been fed
--   away       otter index (as a string) -> { food, readyAt, catch = { good -> qty } }

local Config = require("./Config/OtterPond")
local Rng = require("./Rng")

local OtterPond = {}

export type Trip = { food: string, readyAt: number, catch: { [string]: number } }

local function secs(seconds: number, scale: number?): number
	return math.max(1, math.floor(seconds * (scale or 1) + 0.5))
end

function OtterPond.isOpen(data: { [string]: any }, now: number): boolean
	local readyAt = data.otterPond.readyAt
	return readyAt ~= nil and now >= readyAt
end

-- Can building start now? (Coins are checked by the caller.)
function OtterPond.canBuild(data: { [string]: any }): (boolean, string?)
	if data.otterPond.readyAt ~= nil then
		return false
	elseif data.level < Config.unlockLevel then
		return false, string.format("The Otter Pond opens at level %d", Config.unlockLevel)
	end
	return true
end

function OtterPond.build(data: { [string]: any }, now: number, seed: number, scale: number?)
	local pond = data.otterPond
	pond.readyAt = now + secs(Config.buildSeconds, scale)
	pond.seed = Rng.normalize(seed)
	pond.otters = math.max(pond.otters or 1, 1)
end

-- Finish building early (the caller has charged the Gems)
function OtterPond.finishBuild(data: { [string]: any }, now: number): boolean
	local pond = data.otterPond
	if pond.readyAt == nil or now >= pond.readyAt then
		return false
	end
	pond.readyAt = now
	return true
end

-- The Coins the next otter costs, or nil when all three live there
function OtterPond.nextOtterCoins(data: { [string]: any }): number?
	return Config.otterCoins[(data.otterPond.otters or 1) + 1]
end

function OtterPond.canBuyOtter(data: { [string]: any }, now: number): (boolean, string?)
	if not OtterPond.isOpen(data, now) then
		return false, "Build the Otter Pond first"
	elseif OtterPond.nextOtterCoins(data) == nil then
		return false, "Three otters already live here"
	end
	return true
end

function OtterPond.buyOtter(data: { [string]: any })
	data.otterPond.otters = math.min((data.otterPond.otters or 1) + 1, #Config.otterCoins)
end

local function key(otter: number): string
	return tostring(otter)
end

function OtterPond.trip(data: { [string]: any }, otter: number): Trip?
	return data.otterPond.away[key(otter)]
end

-- Can otter `otter` be fed `food` now? (The caller checks the Barn has one.)
function OtterPond.canFeed(data: { [string]: any }, otter: any, food: any, now: number): (boolean, string?)
	if type(food) ~= "string" or Config.foods[food] == nil then
		return false
	elseif type(otter) ~= "number" or otter % 1 ~= 0 or otter < 1 or otter > (data.otterPond.otters or 1) then
		return false
	elseif not OtterPond.isOpen(data, now) then
		return false, "Build the Otter Pond first"
	elseif OtterPond.trip(data, otter) ~= nil then
		return false, "That otter is still out fishing"
	end
	return true
end

-- Feed an otter: draws what it brings back from the pond's seed, so Gems never change it
function OtterPond.feed(data: { [string]: any }, otter: number, food: string, now: number, scale: number?): Trip
	local def = Config.foods[food]
	local pond = data.otterPond
	local ids = {}
	for id in def.catch do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.goods[a].order < Config.goods[b].order
	end)
	local catch = {}
	for _, id in ids do
		local range = def.catch[id]
		local qty
		qty, pond.seed = Rng.int(pond.seed, range[1], range[2])
		if qty > 0 then
			catch[id] = qty
		end
	end
	local trip = { food = food, readyAt = now + secs(def.seconds, scale), catch = catch }
	pond.away[key(otter)] = trip
	pond.trips = (pond.trips or 0) + 1
	return trip
end

function OtterPond.isDone(data: { [string]: any }, otter: number, now: number): boolean
	local trip = OtterPond.trip(data, otter)
	return trip ~= nil and now >= trip.readyAt
end

-- Takes a finished trip's catch (nil when there's none)
function OtterPond.collect(data: { [string]: any }, otter: number, now: number): { [string]: number }?
	if not OtterPond.isDone(data, otter, now) then
		return nil
	end
	local trip = OtterPond.trip(data, otter) :: Trip
	data.otterPond.away[key(otter)] = nil
	return trip.catch
end

-- Brings an otter home now (the caller has charged the Gems)
function OtterPond.skip(data: { [string]: any }, otter: number, now: number): boolean
	local trip = OtterPond.trip(data, otter)
	if trip == nil or now >= trip.readyAt then
		return false
	end
	trip.readyAt = now
	return true
end

-- The first otter whose catch is waiting, if any
function OtterPond.firstDone(data: { [string]: any }, now: number): number?
	for i = 1, data.otterPond.otters or 1 do
		if OtterPond.isDone(data, i, now) then
			return i
		end
	end
	return nil
end

-- Average of `good` one `food` brings, for production-time estimates
function OtterPond.average(food: string, good: string): number
	local range = Config.foods[food].catch[good]
	return if range then (range[1] + range[2]) / 2 else 0
end

return OtterPond
