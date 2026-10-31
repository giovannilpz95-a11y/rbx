--!strict
-- Harbor & Far Isles rules (Features/F02, Config/Isles), pure so the server, the client and the
-- Lune tests share them. Saved under data.harbor:
--   readyAt    nil until the Harbor's repair starts; repaired once the time has passed
--   seed       the RNG state voyages and Driftwood Crates are drawn from
--   boats      one entry per Sailboat owned. An idle boat is {}; a boat out at sea is
--              { isle, departAt, returnAt, bar?, cargo, chest? }, where cargo is the crates it
--              will bring back ({ { item, qty } }, common good first) and chest a Sea Chest
--              prize. Both are rolled when it leaves, so neither a speed-up nor a rejoin can
--              change them (23 Roblox Policy Compliance §2: Gems only change when, never what).
--   isles      isle id -> { readyAt }: started unlocks (the first isle opens with the Harbor)
--   trips      isle id -> voyages unloaded from it; an isle's goods join the Order Board pool
--              after the first
--   driftDay   UTC day of the last Driftwood Crate opened
--   chests     Sea Chests found, for records

local Config = require("./Config/Isles")
local Rng = require("./Rng")
local TownRules = require("./TownRules")

local Harbor = {}

export type Crate = { item: string, qty: number }
export type Prize = { item: string, qty: number }
export type Boat = {
	isle: string?,
	departAt: number?,
	returnAt: number?,
	bar: string?,
	cargo: { Crate }?,
	chest: Prize?,
}

-- Seconds a new timer runs for under the Studio time scale (as the server's Clock.duration)
local function secs(seconds: number, scale: number?): number
	return math.max(1, math.floor(seconds * (scale or 1) + 0.5))
end

function Harbor.isRepaired(data: { [string]: any }, now: number): boolean
	local readyAt = data.harbor.readyAt
	return readyAt ~= nil and now >= readyAt
end

-- Can the Harbor's repair start now? (Coins are checked by the caller.)
function Harbor.canRepair(data: { [string]: any }): (boolean, string?)
	if data.harbor.readyAt ~= nil then
		return false
	elseif data.level < Config.unlockLevel then
		return false, string.format("The Harbor can be repaired at level %d", Config.unlockLevel)
	end
	return true
end

-- Start the Harbor's repair: the first Sailboat and the first isle come with it
function Harbor.repair(data: { [string]: any }, now: number, seed: number, scale: number?)
	local harbor = data.harbor
	harbor.readyAt = now + secs(Config.repairSeconds, scale)
	harbor.seed = Rng.normalize(seed)
	if #harbor.boats == 0 then
		table.insert(harbor.boats, {})
	end
	local first = Config.isles[1]
	harbor.isles[first.id] = { readyAt = harbor.readyAt }
end

-- Finish the repair early (the caller has charged the Gems)
function Harbor.finishRepair(data: { [string]: any }, now: number): boolean
	local harbor = data.harbor
	if harbor.readyAt == nil or now >= harbor.readyAt then
		return false
	end
	harbor.readyAt = now
	local first = harbor.isles[Config.isles[1].id]
	if first and first.readyAt and first.readyAt > now then
		first.readyAt = now
	end
	return true
end

---------------------------------------------------------------------------------------------
-- Sailboats
---------------------------------------------------------------------------------------------

-- The next Sailboat's terms, or nil when the farm has them all
function Harbor.nextBoat(data: { [string]: any }): { level: number, population: number, coins: number }?
	return Config.boats[#data.harbor.boats + 1]
end

-- Can another Sailboat be bought now? Returns its Coin price when it can (Coins are checked by
-- the caller).
function Harbor.canBuyBoat(data: { [string]: any }, now: number): (number?, string?)
	if not Harbor.isRepaired(data, now) then
		return nil, "Repair the Harbor first"
	end
	local def = Harbor.nextBoat(data)
	if def == nil then
		return nil, "Your Harbor has every Sailboat"
	elseif data.level < def.level then
		return nil, string.format("The next Sailboat comes at level %d", def.level)
	elseif TownRules.population(data, now) < def.population then
		return nil, string.format("The next Sailboat needs a Population of %d", def.population)
	end
	return def.coins
end

function Harbor.buyBoat(data: { [string]: any })
	table.insert(data.harbor.boats, {})
end

function Harbor.boat(data: { [string]: any }, index: any): Boat?
	if type(index) ~= "number" or index % 1 ~= 0 then
		return nil
	end
	return data.harbor.boats[index]
end

function Harbor.isIdle(boat: Boat): boolean
	return boat.isle == nil
end

function Harbor.isBack(boat: Boat, now: number): boolean
	return boat.returnAt ~= nil and now >= boat.returnAt
end

---------------------------------------------------------------------------------------------
-- Isles
---------------------------------------------------------------------------------------------

function Harbor.isleOpen(data: { [string]: any }, isleId: string, now: number): boolean
	local entry = data.harbor.isles[isleId]
	return entry ~= nil and entry.readyAt ~= nil and now >= entry.readyAt
end

-- "Locked" (level or the previous isle), "Ready" (can be unlocked now), "Opening" or "Open"
function Harbor.isleState(data: { [string]: any }, isleId: string, now: number): string
	local entry = data.harbor.isles[isleId]
	if entry and entry.readyAt then
		return if now >= entry.readyAt then "Open" else "Opening"
	end
	return if Harbor.canUnlockIsle(data, isleId, now) then "Ready" else "Locked"
end

-- Can this isle's unlock start now? (Coins and tools are checked by the caller.)
function Harbor.canUnlockIsle(data: { [string]: any }, isleId: any, now: number): (boolean, string?)
	local def = type(isleId) == "string" and Config.byId[isleId] or nil
	if def == nil then
		return false
	elseif not Harbor.isRepaired(data, now) then
		return false, "Repair the Harbor first"
	elseif data.harbor.isles[def.id] ~= nil then
		return false
	elseif data.level < def.unlockLevel then
		return false, string.format("%s can be reached at level %d", def.displayName, def.unlockLevel)
	end
	local before = Config.isles[def.order - 1]
	if before and not Harbor.isleOpen(data, before.id, now) then
		return false, string.format("Open %s first", before.displayName)
	end
	return true
end

function Harbor.unlockIsle(data: { [string]: any }, isleId: string, now: number, scale: number?)
	local def = Config.byId[isleId]
	data.harbor.isles[isleId] = {
		readyAt = if def.unlockSeconds > 0 then now + secs(def.unlockSeconds, scale) else now,
	}
end

-- Finish an isle's unlock early (the caller has charged the Gems)
function Harbor.finishIsle(data: { [string]: any }, isleId: any, now: number): boolean
	local entry = type(isleId) == "string" and data.harbor.isles[isleId] or nil
	if entry == nil or entry.readyAt == nil or now >= entry.readyAt then
		return false
	end
	entry.readyAt = now
	return true
end

---------------------------------------------------------------------------------------------
-- Voyages
---------------------------------------------------------------------------------------------

-- The row of an isle's odds for a Bar (1 = none), or nil for something that isn't a Bar
function Harbor.barRow(bar: any): number?
	if bar == nil then
		return 1
	end
	local index = table.find(Config.bars, bar)
	return if index then index + 1 else nil
end

-- Chances (0-1) of the uncommon good, the rare good and a Sea Chest on a trip to this isle
function Harbor.odds(isleId: string, bar: string?): (number, number, number)
	local def = Config.byId[isleId]
	local row = def.odds[Harbor.barRow(bar) or 1]
	return row[1], row[2], row[3]
end

local function pickWeighted(seed: number, entries: { any }): (any, number)
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local r
	r, seed = Rng.next(seed)
	local target = r * total
	for _, entry in entries do
		target -= entry.weight
		if target < 0 then
			return entry, seed
		end
	end
	return entries[#entries], seed
end

-- What a trip to `isleId` with `bar` brings back, drawn from `seed`: the crates (common good
-- first, x3 always; the others when their roll hits) and maybe a Sea Chest prize. Returns them
-- and the next seed.
function Harbor.roll(isleId: string, bar: string?, seed: number): ({ Crate }, Prize?, number)
	seed = Rng.normalize(seed)
	local def = Config.byId[isleId]
	local row = Harbor.barRow(bar) or 1
	local chances = def.odds[row]
	local qty = Config.qty[row]
	local cargo: { Crate } = { { item = def.goods[1], qty = Config.commonQty } }
	for tier = 2, 3 do
		local r
		r, seed = Rng.next(seed)
		if r < chances[tier - 1] then
			local range = if tier == 2 then qty.uncommon else qty.rare
			local n
			n, seed = Rng.int(seed, range[1], range[2])
			table.insert(cargo, { item = def.goods[tier], qty = n })
		end
	end
	local chest: Prize? = nil
	local r
	r, seed = Rng.next(seed)
	if r < chances[3] then
		local entry
		entry, seed = pickWeighted(seed, Config.seaChest)
		chest = { item = entry.item, qty = entry.qty }
	end
	return cargo, chest, seed
end

-- Can this boat sail to this isle now? Returns the isle's send cost in Coins when it can (Coins
-- and the Bar are checked by the caller, which holds the Barn).
function Harbor.canSend(data: { [string]: any }, index: any, isleId: any, bar: any, now: number): (number?, string?)
	if not Harbor.isRepaired(data, now) then
		return nil, "Repair the Harbor first"
	end
	local boat = Harbor.boat(data, index)
	if boat == nil then
		return nil
	elseif not Harbor.isIdle(boat) then
		return nil, "That Sailboat is out at sea"
	end
	local def = type(isleId) == "string" and Config.byId[isleId] or nil
	if def == nil then
		return nil
	elseif not Harbor.isleOpen(data, def.id, now) then
		return nil, string.format("%s isn't open yet", def.displayName)
	elseif Harbor.barRow(bar) == nil then
		return nil, "Only a metal Bar can go along as ballast"
	end
	return def.sendCoins
end

-- Send a boat (check canSend and take the Coins and Bar first): its cargo is rolled now
function Harbor.send(data: { [string]: any }, index: number, isleId: string, bar: string?, now: number, scale: number?)
	local harbor = data.harbor
	local boat = harbor.boats[index]
	local def = Config.byId[isleId]
	local cargo, chest, seed = Harbor.roll(isleId, bar, harbor.seed)
	harbor.seed = seed
	boat.isle = isleId
	boat.departAt = now
	boat.returnAt = now + secs(def.tripSeconds, scale)
	boat.bar = bar
	boat.cargo = cargo
	boat.chest = chest
end

-- Barn units a boat's cargo needs
function Harbor.cargoUnits(boat: Boat): number
	local n = 0
	for _, crate in boat.cargo or {} do
		n += crate.qty
	end
	return n
end

-- Unload a boat that's back (Barn space is checked by the caller): returns its cargo and chest
-- for the caller to hand over, and makes the boat idle again
function Harbor.unload(data: { [string]: any }, index: any, now: number): ({ Crate }?, Prize?)
	local boat = Harbor.boat(data, index)
	if boat == nil or boat.isle == nil or not Harbor.isBack(boat, now) then
		return nil, nil
	end
	local harbor = data.harbor
	local cargo, chest = boat.cargo or {}, boat.chest
	harbor.trips[boat.isle :: string] = (harbor.trips[boat.isle :: string] or 0) + 1
	if chest then
		harbor.chests = (harbor.chests or 0) + 1
	end
	table.clear(boat)
	return cargo, chest
end

-- Gems to bring a boat home now (0 once it's back or in its last free seconds)
function Harbor.skipCost(boat: Boat, now: number): number
	if boat.returnAt == nil then
		return 0
	end
	local left = boat.returnAt - now
	if left <= Config.freeSkipSeconds then
		return 0
	end
	for _, row in Config.skip do
		if left < row[1] then
			return row[2]
		end
	end
	return Config.skip[#Config.skip][2]
end

-- Bring a boat home now (the caller has charged skipCost)
function Harbor.skip(boat: Boat, now: number): boolean
	if boat.returnAt == nil or now >= boat.returnAt then
		return false
	end
	boat.returnAt = now
	return true
end

---------------------------------------------------------------------------------------------
-- The Driftwood Crate and the Order Board
---------------------------------------------------------------------------------------------

function Harbor.canOpenDrift(data: { [string]: any }, day: number, now: number): (boolean, string?)
	if not Harbor.isRepaired(data, now) then
		return false, "Repair the Harbor first"
	elseif data.harbor.driftDay == day then
		return false, "The next Driftwood Crate washes up tomorrow"
	end
	return true
end

-- Open today's Driftwood Crate (check canOpenDrift first): its prize, drawn from the farm's seed
function Harbor.openDrift(data: { [string]: any }, day: number, now: number): Prize
	local harbor = data.harbor
	local entry, seed = pickWeighted(Rng.normalize(harbor.seed), Config.drift)
	harbor.driftDay = day
	local prize: Prize
	if entry.item == "IsleGoods" then
		-- The common good of a random open isle
		local open = {}
		for _, isle in Config.isles do
			if Harbor.isleOpen(data, isle.id, now) then
				table.insert(open, isle)
			end
		end
		local pick
		pick, seed = Rng.int(seed, 1, math.max(1, #open))
		local isle = open[pick] or Config.isles[1]
		local qty
		qty, seed = Rng.int(seed, 2, entry.qty)
		prize = { item = isle.goods[1], qty = qty }
	else
		prize = { item = entry.item, qty = entry.qty }
	end
	harbor.seed = seed
	return prize
end

-- Isle goods the Order Board may ask this farm for: every good of each isle it has unloaded a
-- boat from
function Harbor.visitedGoods(data: { [string]: any }): { string }
	local out = {}
	local trips = data.harbor and data.harbor.trips or {}
	for _, isle in Config.isles do
		if (trips[isle.id] or 0) > 0 then
			for _, good in isle.goods do
				table.insert(out, good)
			end
		end
	end
	return out
end

return Harbor
