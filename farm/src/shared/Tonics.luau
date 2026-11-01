--!strict
-- The Tonic Shed's rules (Config/Tonics): pure, so the server, the panels and the tests agree.
-- This is the farm's modifier pipeline (Features/F09): every system asks Tonics.value for its
-- stat where it works out a yield, a payout or a timer, and gets 1 (or 0 for factoryTime)
-- when nothing is running.
--
-- Save block `tonics`:
--   readyAt  set when building the shed starts; it's open from then on
--   active   the tonics running: { { id, endsAt } }, at most Config.maxActive, no two alike
--   owned    tonic id -> earned tonics waiting in the shed (switched on for free)

local Config = require("./Config/Tonics")
local Factories = require("./Config/Factories")

local Tonics = {}

export type Active = { id: string, endsAt: number }

local function secs(seconds: number, scale: number?): number
	return math.max(1, math.floor(seconds * (scale or 1) + 0.5))
end

function Tonics.isTonic(id: any): boolean
	return type(id) == "string" and Config.tonics[id] ~= nil
end

function Tonics.isOpen(data: { [string]: any }, now: number): boolean
	local readyAt = data.tonics.readyAt
	return readyAt ~= nil and now >= readyAt
end

-- Can building start now? (Coins are checked by the caller; `population` is the town's.)
function Tonics.canBuild(data: { [string]: any }, population: number): (boolean, string?)
	if data.tonics.readyAt ~= nil then
		return false
	elseif data.level < Config.unlockLevel then
		return false, string.format("The Tonic Shed opens at level %d", Config.unlockLevel)
	elseif population < Config.population then
		return false, string.format("The Tonic Shed needs a Population of %d", Config.population)
	end
	return true
end

function Tonics.build(data: { [string]: any }, now: number, scale: number?)
	data.tonics.readyAt = now + secs(Config.buildSeconds, scale)
end

function Tonics.finishBuild(data: { [string]: any }, now: number): boolean
	local shed = data.tonics
	if shed.readyAt == nil or now >= shed.readyAt then
		return false
	end
	shed.readyAt = now
	return true
end

-- Drops tonics that have run out. Returns the ids that ended.
function Tonics.prune(data: { [string]: any }, now: number): { string }
	local ended = {}
	local active = data.tonics.active
	for i = #active, 1, -1 do
		if now >= active[i].endsAt then
			table.insert(ended, active[i].id)
			table.remove(active, i)
		end
	end
	return ended
end

-- The running entry for this tonic, or nil
function Tonics.running(data: { [string]: any }, id: string, now: number): Active?
	for _, entry in data.tonics.active do
		if entry.id == id and now < entry.endsAt then
			return entry
		end
	end
	return nil
end

-- How many are running now
function Tonics.activeCount(data: { [string]: any }, now: number): number
	local n = 0
	for _, entry in data.tonics.active do
		if now < entry.endsAt then
			n += 1
		end
	end
	return n
end

function Tonics.owned(data: { [string]: any }, id: string): number
	return data.tonics.owned[id] or 0
end

-- Can this tonic be switched on now? Returns how it would be paid: "owned" (an earned one) or
-- "gems" (with its Gem price, which the caller checks and takes).
function Tonics.canActivate(data: { [string]: any }, id: any, now: number): (string?, string?)
	if not Tonics.isTonic(id) then
		return nil
	end
	local def = Config.tonics[id]
	if not Tonics.isOpen(data, now) then
		return nil, "Build the Tonic Shed first"
	elseif Tonics.running(data, id, now) then
		return nil, def.displayName .. " is already running"
	elseif Tonics.activeCount(data, now) >= Config.maxActive then
		return nil, string.format("Only %d tonics can run at once. Stop one first.", Config.maxActive)
	elseif Tonics.owned(data, id) > 0 then
		return "owned"
	elseif def.gems == nil then
		return nil, def.displayName .. " can't be bought. Find it in Full Hold chests."
	end
	return "gems"
end

-- Switch it on (check canActivate first; the caller takes the Gems when it said "gems")
function Tonics.activate(data: { [string]: any }, id: string, how: string, now: number, scale: number?): Active
	local def = Config.tonics[id]
	Tonics.prune(data, now)
	if how == "owned" then
		local left = Tonics.owned(data, id) - 1
		data.tonics.owned[id] = if left > 0 then left else nil
	end
	local entry = { id = id, endsAt = now + secs(def.seconds, scale) }
	table.insert(data.tonics.active, entry)
	return entry
end

-- Stop a running tonic; its time left is lost (as in Township)
function Tonics.cancel(data: { [string]: any }, id: any, now: number): boolean
	local active = data.tonics.active
	for i, entry in active do
		if entry.id == id and now < entry.endsAt then
			table.remove(active, i)
			return true
		end
	end
	return false
end

-- An earned tonic goes into the shed's store (even before the shed is built)
function Tonics.give(data: { [string]: any }, id: string, qty: number)
	if Tonics.isTonic(id) and qty > 0 then
		data.tonics.owned[id] = Tonics.owned(data, id) + qty
	end
end

---------------------------------------------------------------------------------------------
-- The modifier pipeline
---------------------------------------------------------------------------------------------

-- The stat's value now: the running tonic's value, or 1 (0 for factoryTime) when none is
local function stat(data: { [string]: any }, name: Config.Stat, now: number): number
	local shed = data.tonics
	local value = if name == "factoryTime" then 0 else 1
	if shed == nil then
		return value
	end
	for _, entry in shed.active do
		local def = Config.tonics[entry.id]
		if def and def.stat == name and now < entry.endsAt then
			value = def.value
		end
	end
	return value
end
Tonics.value = stat

-- The Coins Good Customer adds to an order paying `rewardCoins` (0 when it isn't running).
-- The server pays this and the order card shows it, so the two always agree.
function Tonics.orderBonus(data: { [string]: any }, rewardCoins: number, now: number): number
	return math.floor(rewardCoins * (stat(data, "orderCoins", now) - 1) + 0.5)
end

function Tonics.isSmelter(factoryId: string): boolean
	local def = Factories[factoryId]
	return factoryId == "Smelter" or (def ~= nil and def.makes == "Smelter")
end

-- A factory's production time multiplier: the Tinker's Guild's time upgrades (`guildMult`) with
-- Busy Bees Oil's cut added on top, or Hot Smelter for Smelters. Never under 10%.
function Tonics.factoryMult(data: { [string]: any }, factoryId: string, guildMult: number, now: number): number
	if Tonics.isSmelter(factoryId) then
		return guildMult * stat(data, "smeltTime", now)
	end
	return math.max(0.1, guildMult - stat(data, "factoryTime", now))
end

-- Draw a Full Hold chest's tonic, if any, from two numbers in [0, 1)
function Tonics.chestDraw(roll: number, pick: number): string?
	if roll >= Config.chestChance then
		return nil
	end
	local total = 0
	for _, def in Config.list do
		total += Config.chestWeights[def.id] or 0
	end
	local target = pick * total
	for _, def in Config.list do
		target -= Config.chestWeights[def.id] or 0
		if target < 0 then
			return def.id
		end
	end
	return Config.list[#Config.list].id
end

return Tonics
