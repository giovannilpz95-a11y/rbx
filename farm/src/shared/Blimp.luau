--!strict
-- Airship Freight rules (Features/F04, Config/Blimp), pure so the server, the client and the
-- Lune tests share them. Saved under data.blimp:
--   readyAt    nil until the mast's repair starts; repaired once the time has passed
--   seed       the RNG state loads are drawn from
--   load       the next flight's load while the blimp is away (the Next Flight preview), and
--              the current one while it's docked: { rows = { { Crate } }, chest = { Prize } }
--   arrivesAt  while away: when the blimp is due. It docks at the first tick at or after
--              this time, so it only lands while the player is in the game.
--   leavesAt   while docked: the end of the loading window
--   flights, fullHolds, skyMiles   counts for records and the Sky Miles board
-- A crate is { item, qty, filledBy?, flagged? }: filledBy is the user id of whoever loaded it.

local Config = require("./Config/Blimp")
local Items = require("./Items")
local OrderGen = require("./OrderGen")
local Rng = require("./Rng")

local Blimp = {}

export type Crate = { item: string, qty: number, filledBy: number?, flagged: boolean? }
export type Prize = { item: string, qty: number }
export type Load = { rows: { { Crate } }, chest: { Prize } }
export type Payout = {
	coins: number,
	miles: number,
	rows: { number }, -- the full rows that paid
	chest: { Prize }?, -- every crate loaded
}

function Blimp.isRepaired(data: { [string]: any }, now: number): boolean
	local readyAt = data.blimp.readyAt
	return readyAt ~= nil and now >= readyAt
end

function Blimp.isDocked(data: { [string]: any }): boolean
	return data.blimp.leavesAt ~= nil
end

-- Can the mast's repair start now? (Coins are checked by the caller.)
function Blimp.canRepair(data: { [string]: any }): (boolean, string?)
	if data.blimp.readyAt ~= nil then
		return false
	elseif data.level < Config.unlockLevel then
		return false, string.format("The Blimp Mast can be repaired at level %d", Config.unlockLevel)
	end
	return true
end

-- How many of `item` a crate asks for at `level`: a draw from the crate range, whose top grows
-- with level
function Blimp.qtyRange(item: string, level: number): (number, number)
	local range = Config.crates[item]
	local low, high = range[1], range[2]
	local t = math.clamp((level - Config.qtyFromLevel) / (Config.qtyFullLevel - Config.qtyFromLevel), 0, 1)
	local share = Config.qtyStartShare + (1 - Config.qtyStartShare) * t
	return low, math.max(low, low + math.floor((high - low) * share + 0.5))
end

-- Goods a blimp can ask this farm for: makeable now and on the crate list
function Blimp.pool(data: { [string]: any }): { string }
	local pool = {}
	for _, id in OrderGen.makeablePool(data) do
		local def = Items[id]
		if Config.crates[id] and def and def.unlockLevel <= data.level then
			table.insert(pool, id)
		end
	end
	return pool
end

local function weightOf(id: string): number
	return if Items[id].kind == "Product" then Config.productWeight else 1
end

local function pickWeighted(seed: number, entries: { any }, weight: (any) -> number): (any, number)
	local total = 0
	for _, entry in entries do
		total += weight(entry)
	end
	local r
	r, seed = Rng.next(seed)
	local target = r * total
	for _, entry in entries do
		target -= weight(entry)
		if target < 0 then
			return entry, seed
		end
	end
	return entries[#entries], seed
end

local function prizeWeight(entry: { [string]: any }): number
	return entry.weight
end

-- A new load drawn from `pool` (sorted for determinism). Goods don't repeat within a load
-- while the pool has fresh ones. Returns the load and the next seed.
function Blimp.generate(pool: { string }, level: number, seed: number): (Load, number)
	seed = Rng.normalize(seed)
	local sorted = table.clone(pool)
	table.sort(sorted)
	local remaining = table.clone(sorted)
	local rows = {}
	for _ = 1, Config.rows do
		local count
		count, seed = Rng.int(seed, Config.minCrates, Config.maxCrates)
		local row = {}
		for _ = 1, count do
			if #sorted == 0 then
				break
			end
			if #remaining == 0 then
				remaining = table.clone(sorted)
			end
			local item
			item, seed = pickWeighted(seed, remaining, weightOf)
			table.remove(remaining, table.find(remaining, item) :: number)
			local low, high = Blimp.qtyRange(item, level)
			local qty
			qty, seed = Rng.int(seed, low, high)
			table.insert(row, { item = item, qty = qty })
		end
		table.insert(rows, row)
	end
	local chest = {}
	for _, group in { Config.chest.bars, Config.chest.tools, Config.chest.materials } do
		local entry
		entry, seed = pickWeighted(seed, group, prizeWeight)
		table.insert(chest, { item = entry.item, qty = entry.qty })
	end
	return { rows = rows, chest = chest }, seed
end

-- Draw the next load into data.blimp from the farm's current pool
function Blimp.newLoad(data: { [string]: any })
	local blimp = data.blimp
	local load, seed = Blimp.generate(Blimp.pool(data), data.level, blimp.seed)
	blimp.load = load
	blimp.seed = seed
end

-- Start the mast's repair: the first blimp is due the moment it's done, and its load is drawn
-- now so Next Flight can show it during the repair. `seed` is a fresh random number.
function Blimp.repair(data: { [string]: any }, now: number, seed: number)
	local blimp = data.blimp
	blimp.readyAt = now + Config.repairSeconds
	blimp.arrivesAt = blimp.readyAt
	blimp.leavesAt = nil
	blimp.seed = Rng.normalize(seed)
	Blimp.newLoad(data)
end

-- Finish the repair early (the caller has charged the Gems): the first blimp is due now too
function Blimp.finishRepair(data: { [string]: any }, now: number): boolean
	local blimp = data.blimp
	if blimp.readyAt == nil or now >= blimp.readyAt then
		return false
	end
	blimp.readyAt = now
	if blimp.arrivesAt ~= nil then
		blimp.arrivesAt = math.min(blimp.arrivesAt, now)
	end
	return true
end

local function depart(data: { [string]: any }, leftAt: number)
	local blimp = data.blimp
	blimp.leavesAt = nil
	blimp.arrivesAt = leftAt + Config.gapSeconds
	blimp.flights = (blimp.flights or 0) + 1
	Blimp.newLoad(data)
end

-- Move the blimp on while the player is in the game: dock it when it's due, and send it away
-- empty-handed when its loading window has run out. Returns "docked", "expired" or nil.
function Blimp.tick(data: { [string]: any }, now: number): string?
	local blimp = data.blimp
	if not Blimp.isRepaired(data, now) then
		return nil
	end
	if blimp.leavesAt ~= nil then
		if now >= blimp.leavesAt then
			depart(data, blimp.leavesAt)
			return "expired"
		end
		return nil
	end
	if blimp.arrivesAt ~= nil and now >= blimp.arrivesAt then
		if blimp.load == nil or #blimp.load.rows == 0 then
			Blimp.newLoad(data)
		end
		blimp.arrivesAt = nil
		blimp.leavesAt = now + Config.loadSeconds
		return "docked"
	end
	return nil
end

-- The crate at row/slot of a docked blimp, if both are whole numbers in range
function Blimp.crate(data: { [string]: any }, row: any, slot: any): Crate?
	local blimp = data.blimp
	if blimp.leavesAt == nil or blimp.load == nil then
		return nil
	elseif type(row) ~= "number" or type(slot) ~= "number" or row % 1 ~= 0 or slot % 1 ~= 0 then
		return nil
	end
	local cells = blimp.load.rows[row]
	return cells and cells[slot]
end

-- Can this crate be loaded now? Returns the crate when it can. (Goods are checked by the
-- caller, which holds the Barn.)
function Blimp.canFill(data: { [string]: any }, row: any, slot: any, now: number): (Crate?, string?)
	if not Blimp.isDocked(data) then
		return nil, "The Cargo Blimp isn't here"
	elseif now >= data.blimp.leavesAt then
		return nil, "The Cargo Blimp has left"
	end
	local crate = Blimp.crate(data, row, slot)
	if crate == nil then
		return nil
	elseif crate.filledBy ~= nil then
		return nil, "That crate is already loaded"
	end
	return crate
end

function Blimp.fill(crate: Crate, userId: number)
	crate.filledBy = userId
	crate.flagged = nil
end

-- What loading a crate pays at once: Coins, XP and its Sky Miles (helpers earn the miles;
-- the owner's come with the row)
function Blimp.crateRewards(crate: Crate): (number, number, number)
	local def = Items[crate.item]
	local value = def.sellPrice * crate.qty
	local coins = math.max(1, math.floor(value * Config.crateCoinMult + 0.5))
	local xp = math.max(1, math.floor(def.xpPerUnit * crate.qty * Config.crateXpMult + 0.5))
	local miles = math.clamp(math.ceil(value / Config.milesPerValue), 1, Config.milesMax)
	return coins, xp, miles
end

local function rowFull(row: { Crate }): boolean
	for _, crate in row do
		if crate.filledBy == nil then
			return false
		end
	end
	return #row > 0
end

-- A row's bonus when it's full: Coins and Sky Miles
function Blimp.rowRewards(row: { Crate }, index: number): (number, number)
	local value, miles = 0, 0
	for _, crate in row do
		value += Items[crate.item].sellPrice * crate.qty
		local _, _, m = Blimp.crateRewards(crate)
		miles += m
	end
	local mult = Config.rowCoinMult[math.clamp(index, 1, #Config.rowCoinMult)]
	return math.max(1, math.floor(value * mult + 0.5)), miles
end

-- What sending the blimp now would pay
function Blimp.payout(load: Load): Payout
	local coins, miles, rows, all = 0, 0, {}, true
	for i, row in load.rows do
		if rowFull(row) then
			local c, m = Blimp.rowRewards(row, i)
			coins += c
			miles += m
			table.insert(rows, i)
		else
			all = false
		end
	end
	return { coins = coins, miles = miles, rows = rows, chest = if all then load.chest else nil }
end

-- Send a docked blimp: returns what it pays (the caller credits it) and starts the gap
function Blimp.send(data: { [string]: any }, now: number): Payout?
	local blimp = data.blimp
	if not Blimp.isDocked(data) or now >= blimp.leavesAt then
		return nil
	end
	local payout = Blimp.payout(blimp.load)
	blimp.skyMiles = (blimp.skyMiles or 0) + payout.miles
	if payout.chest then
		blimp.fullHolds = (blimp.fullHolds or 0) + 1
	end
	depart(data, now)
	return payout
end

-- Flag a crate for help, one per row; flagging another in the same row moves the flag.
-- Flagging a flagged crate takes the flag off.
function Blimp.flag(data: { [string]: any }, row: any, slot: any, now: number): (boolean, string?)
	local crate, reason = Blimp.canFill(data, row, slot, now)
	if crate == nil then
		return false, reason
	end
	local on = not crate.flagged
	for _, other in data.blimp.load.rows[row] do
		other.flagged = nil
	end
	crate.flagged = if on then true else nil
	return true
end

-- Gems to call the next blimp now (0 when it's due, or in its last free seconds)
function Blimp.skipCost(data: { [string]: any }, now: number): number
	local blimp = data.blimp
	if blimp.leavesAt ~= nil or blimp.arrivesAt == nil or not Blimp.isRepaired(data, now) then
		return 0
	end
	local left = blimp.arrivesAt - now
	if left <= Config.freeSkipSeconds then
		return 0
	end
	return math.max(1, math.ceil(Config.skipGemsMax * math.min(left, Config.gapSeconds) / Config.gapSeconds))
end

-- Bring the next blimp in now (the caller has charged skipCost); it docks at the next tick
function Blimp.skip(data: { [string]: any }, now: number): boolean
	local blimp = data.blimp
	if blimp.leavesAt ~= nil or blimp.arrivesAt == nil or not Blimp.isRepaired(data, now) then
		return false
	end
	blimp.arrivesAt = math.min(blimp.arrivesAt, now)
	return true
end

return Blimp
