--!strict
-- The Tool Trader's rules (Config/ToolTrader): pure, so the server, the panel and the tests
-- agree.
--
-- Save block `toolTrader`:
--   readyAt    set when building starts; the trader is open from then on
--   seed       the RNG state each offer is drawn from
--   slots      how many offer slots are open (1 to 3)
--   trades     how many offers have been taken
--   offers     slot index (as a string) -> { tools = { id -> qty }, cost = { material -> qty } }
--              or { waitUntil } after a dump

local Config = require("./Config/ToolTrader")
local Rng = require("./Rng")

local ToolTrader = {}

export type Offer = { tools: { [string]: number }?, cost: { [string]: number }?, waitUntil: number? }

local function secs(seconds: number, scale: number?): number
	return math.max(1, math.floor(seconds * (scale or 1) + 0.5))
end

local function key(slot: number): string
	return tostring(slot)
end

function ToolTrader.isOpen(data: { [string]: any }, now: number): boolean
	local readyAt = data.toolTrader.readyAt
	return readyAt ~= nil and now >= readyAt
end

-- The tools offers can hold at this level, in order
function ToolTrader.toolsAt(level: number): { string }
	local out = {}
	for id, def in Config.tools do
		if level >= def.unlockLevel then
			table.insert(out, id)
		end
	end
	table.sort(out, function(a, b)
		return Config.tools[a].order < Config.tools[b].order
	end)
	return out
end

-- Can building start now? (Coins are checked by the caller; `population` is the town's.)
function ToolTrader.canBuild(data: { [string]: any }, population: number): (boolean, string?)
	if data.toolTrader.readyAt ~= nil then
		return false
	elseif data.level < Config.unlockLevel then
		return false, string.format("The Tool Trader opens at level %d", Config.unlockLevel)
	elseif population < Config.population then
		return false, string.format("The Tool Trader needs a Population of %d", Config.population)
	end
	return true
end

function ToolTrader.build(data: { [string]: any }, now: number, seed: number, scale: number?)
	local trader = data.toolTrader
	trader.readyAt = now + secs(Config.buildSeconds, scale)
	trader.seed = seed
end

function ToolTrader.finishBuild(data: { [string]: any }, now: number): boolean
	local trader = data.toolTrader
	if trader.readyAt == nil or now >= trader.readyAt then
		return false
	end
	trader.readyAt = now
	return true
end

-- Draws a new offer from the trader's seed: 2-4 tools of the kinds open at this level, for
-- 4-6 materials each, asked as one material or split over two
function ToolTrader.draw(data: { [string]: any }): Offer
	local trader = data.toolTrader
	local seed = trader.seed
	local kinds = ToolTrader.toolsAt(data.level)
	local n, pick, total = 0, 0, 0
	n, seed = Rng.int(seed, Config.toolsPerOffer[1], Config.toolsPerOffer[2])
	local tools = {}
	for _ = 1, n do
		pick, seed = Rng.int(seed, 1, #kinds)
		tools[kinds[pick]] = (tools[kinds[pick]] or 0) + 1
		local each
		each, seed = Rng.int(seed, Config.perTool[1], Config.perTool[2])
		total += each
	end
	local mats = Config.materials
	local first, split = 0, 0
	first, seed = Rng.int(seed, 1, #mats)
	split, seed = Rng.int(seed, 0, 1)
	local cost = {}
	if split == 0 then
		cost[mats[first]] = total
	else
		local offset, part = 0, 0
		offset, seed = Rng.int(seed, 1, #mats - 1)
		local second = ((first - 1 + offset) % #mats) + 1
		part, seed = Rng.int(seed, math.ceil(total * 0.35), math.floor(total * 0.65))
		cost[mats[first]] = part
		cost[mats[second]] = total - part
	end
	trader.seed = seed
	return { tools = tools, cost = cost }
end

-- Fills open slots that are empty or whose wait is over. Returns true when something changed.
function ToolTrader.settle(data: { [string]: any }, now: number): boolean
	if data.toolTrader == nil or not ToolTrader.isOpen(data, now) then
		return false
	end
	local trader = data.toolTrader
	local changed = false
	for i = 1, trader.slots or 1 do
		local offer = trader.offers[key(i)]
		if offer == nil or (offer.waitUntil ~= nil and now >= offer.waitUntil) then
			trader.offers[key(i)] = ToolTrader.draw(data)
			changed = true
		end
	end
	return changed
end

function ToolTrader.offer(data: { [string]: any }, slot: number): Offer?
	return data.toolTrader.offers[key(slot)]
end

local function validSlot(data: { [string]: any }, slot: any): boolean
	return type(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= (data.toolTrader.slots or 1)
end

-- Can the offer in `slot` be taken now? (The caller checks the Barn holds the cost.)
function ToolTrader.canTrade(data: { [string]: any }, slot: any, now: number): (boolean, string?)
	if not validSlot(data, slot) then
		return false
	elseif not ToolTrader.isOpen(data, now) then
		return false, "Build the Tool Trader first"
	end
	local offer = ToolTrader.offer(data, slot)
	if offer == nil or offer.tools == nil then
		return false, "A new offer is on its way"
	end
	return true
end

-- Takes the offer in `slot` and draws the next one there. Returns what was traded.
function ToolTrader.trade(data: { [string]: any }, slot: number): Offer
	local trader = data.toolTrader
	local offer = trader.offers[key(slot)]
	trader.offers[key(slot)] = ToolTrader.draw(data)
	trader.trades = (trader.trades or 0) + 1
	return offer
end

function ToolTrader.canDump(data: { [string]: any }, slot: any, now: number): boolean
	return ToolTrader.canTrade(data, slot, now)
end

-- Throws away the offer in `slot`; a new one comes after Config.dumpSeconds
function ToolTrader.dump(data: { [string]: any }, slot: number, now: number, scale: number?)
	data.toolTrader.offers[key(slot)] = { waitUntil = now + secs(Config.dumpSeconds, scale) }
end

-- Brings the next offer now (the caller has charged the Gems)
function ToolTrader.skip(data: { [string]: any }, slot: number, now: number): boolean
	local offer = ToolTrader.offer(data, slot)
	if offer == nil or offer.waitUntil == nil or now >= offer.waitUntil then
		return false
	end
	data.toolTrader.offers[key(slot)] = ToolTrader.draw(data)
	return true
end

-- The Coins the next slot costs, or nil when all three are open
function ToolTrader.nextSlotCoins(data: { [string]: any }): number?
	return Config.slotCoins[(data.toolTrader.slots or 1) + 1]
end

function ToolTrader.canBuySlot(data: { [string]: any }, now: number): (boolean, string?)
	if not ToolTrader.isOpen(data, now) then
		return false, "Build the Tool Trader first"
	elseif ToolTrader.nextSlotCoins(data) == nil then
		return false, "All three slots are open"
	end
	return true
end

function ToolTrader.buySlot(data: { [string]: any }, now: number)
	local trader = data.toolTrader
	trader.slots = math.min((trader.slots or 1) + 1, #Config.slotCoins)
	ToolTrader.settle(data, now)
end

-- "2 Power Drill, 1 Power Saw" style text for a { id -> qty } map, using `name` for ids
function ToolTrader.describe(map: { [string]: number }, name: (string) -> string): string
	local ids = {}
	for id in map do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts = {}
	for _, id in ids do
		table.insert(parts, string.format("%d %s", map[id], name(id)))
	end
	return table.concat(parts, ", ")
end

return ToolTrader
