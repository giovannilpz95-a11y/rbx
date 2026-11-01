--!strict
-- The Duck Pond's rules (Config/DuckPond): pure, so the server, the panel and the tests agree.
--
-- Save blocks `duckPond` and `duckPond2` (Config/DuckPond ponds; every function takes the pond
-- id last, "DuckPond" when left out):
--   readyAt    set when digging starts; the pond is open from then on
--   seed       the RNG state each visit's ducks are drawn from
--   visits     how many times the pond has been fed
--   visit      the current visit, or nil: { food, ducks, drakes, readyAt }

local Config = require("./Config/DuckPond")
local Rng = require("./Rng")

local DuckPond = {}

export type Visit = { food: string, ducks: number, drakes: number, readyAt: number }

local function def(id: string?): Config.PondDef
	return Config.ponds[id or "DuckPond"]
end

-- The save block of pond `id`
function DuckPond.record(data: { [string]: any }, id: string?): { [string]: any }
	return data[def(id).save]
end

function DuckPond.def(id: string?): Config.PondDef?
	return Config.ponds[id or "DuckPond"]
end

-- Seconds a new timer runs for under the Studio time scale (as the server's Clock.duration)
local function secs(seconds: number, scale: number?): number
	return math.max(1, math.floor(seconds * (scale or 1) + 0.5))
end

function DuckPond.isOpen(data: { [string]: any }, now: number, id: string?): boolean
	local readyAt = DuckPond.record(data, id).readyAt
	return readyAt ~= nil and now >= readyAt
end

-- Can digging start now? (Coins are checked by the caller.)
function DuckPond.canDig(data: { [string]: any }, id: string?): (boolean, string?)
	local pond = def(id)
	if DuckPond.record(data, id).readyAt ~= nil then
		return false
	elseif data.level < pond.unlockLevel then
		return false, string.format("The %s can be dug out at level %d", pond.displayName, pond.unlockLevel)
	end
	return true
end

function DuckPond.dig(data: { [string]: any }, now: number, seed: number, scale: number?, id: string?)
	local pond = DuckPond.record(data, id)
	pond.readyAt = now + secs(def(id).digSeconds, scale)
	pond.seed = Rng.normalize(seed)
end

-- Finish digging early (the caller has charged the Gems)
function DuckPond.finishDig(data: { [string]: any }, now: number, id: string?): boolean
	local pond = DuckPond.record(data, id)
	if pond.readyAt == nil or now >= pond.readyAt then
		return false
	end
	pond.readyAt = now
	return true
end

-- Can the pond be fed `food` now? (The caller checks the Barn has one.)
function DuckPond.canFeed(data: { [string]: any }, food: any, now: number, id: string?): (boolean, string?)
	if type(food) ~= "string" or Config.foods[food] == nil then
		return false
	elseif not DuckPond.isOpen(data, now, id) then
		return false, "Dig out the " .. def(id).displayName .. " first"
	elseif DuckPond.record(data, id).visit ~= nil then
		return false, "The ducks are still here. Collect their feathers first."
	end
	return true
end

-- Feed the pond: draws how many ducks come and how many are drakes, from the pond's seed
function DuckPond.feed(data: { [string]: any }, food: string, now: number, scale: number?, id: string?): Visit
	local meal = Config.foods[food]
	local pond = DuckPond.record(data, id)
	local ducks, drakes
	ducks, pond.seed = Rng.int(pond.seed, meal.ducks[1], meal.ducks[2])
	drakes, pond.seed = Rng.int(pond.seed, meal.drakes[1], math.min(meal.drakes[2], ducks))
	local visit =
		{ food = food, ducks = ducks, drakes = math.min(drakes, ducks), readyAt = now + secs(meal.seconds, scale) }
	pond.visit = visit
	pond.visits = (pond.visits or 0) + 1
	return visit
end

-- What a visit leaves behind: a Down Feather per duck and a Colorful Feather per drake
function DuckPond.feathers(visit: Visit): { [string]: number }
	local out = { [Config.down] = visit.ducks }
	if visit.drakes > 0 then
		out[Config.colorful] = visit.drakes
	end
	return out
end

function DuckPond.isDone(data: { [string]: any }, now: number, id: string?): boolean
	local visit = DuckPond.record(data, id).visit
	return visit ~= nil and now >= visit.readyAt
end

-- Takes the feathers of a finished visit (nil when there's none), and empties the pond
function DuckPond.collect(data: { [string]: any }, now: number, id: string?): { [string]: number }?
	if not DuckPond.isDone(data, now, id) then
		return nil
	end
	local pond = DuckPond.record(data, id)
	local out = DuckPond.feathers(pond.visit)
	pond.visit = nil
	return out
end

-- Ends the current visit now (the caller has charged the Gems)
function DuckPond.skip(data: { [string]: any }, now: number, id: string?): boolean
	local visit = DuckPond.record(data, id).visit
	if visit == nil or now >= visit.readyAt then
		return false
	end
	visit.readyAt = now
	return true
end

-- Average feathers one food brings, for production-time estimates (Items) and the panel
function DuckPond.average(food: string): (number, number)
	local meal = Config.foods[food]
	local ducks = (meal.ducks[1] + meal.ducks[2]) / 2
	local drakes = math.min((meal.drakes[1] + meal.drakes[2]) / 2, ducks)
	return ducks, drakes
end

return DuckPond
