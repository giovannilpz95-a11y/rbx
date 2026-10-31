--!strict
-- Town Express rules (Config/Express; Design/14 Multiplayer Features C1), pure so the server,
-- the client and the Lune tests share them. The train is server state, never saved:
--   arrivedAt, leavesAt      the loading window
--   crates                   { { item, qty, by? } }: by is the loader's UserId (0 = an NPC neighbor)
--   cars                     how many cars the train pulls
--   prizes                   per tier: { coins, item?, qty? }, drawn at arrival
--   npc                      NPC neighbors help (fewer than 3 players at arrival)
--   npcAt                    when an NPC last loaded a crate
--   loaded                   UserId (string) -> crates that player loaded
--   paid                     UserId (string) -> tiers already paid to that player
-- A player who loads at least one crate is paid every tier reached, including tiers reached
-- before they joined in; tiers reached later are paid to every contributor still here.

local Blimp = require("./Blimp")
local BlimpConfig = require("./Config/Blimp")
local Config = require("./Config/Express")
local Items = require("./Items")
local Rng = require("./Rng")

local Express = {}

export type Crate = { item: string, qty: number, by: number? }
export type Prize = { coins: number, item: string?, qty: number? }
export type Train = {
	arrivedAt: number,
	leavesAt: number,
	crates: { Crate },
	cars: number,
	prizes: { Prize },
	npc: boolean,
	npcAt: number,
	loaded: { [string]: number },
	paid: { [string]: number },
}

-- The arrival at or before `now` (on the fixed clock) and whether its window is still open
function Express.window(now: number): (number, boolean)
	local arrivedAt = now - now % Config.periodSeconds
	return arrivedAt, now < arrivedAt + Config.windowSeconds
end

-- When the next train arrives, after `now`
function Express.nextArrival(now: number): number
	return now - now % Config.periodSeconds + Config.periodSeconds
end

function Express.crateCount(players: number): number
	return math.clamp(math.max(Config.minCrates, Config.cratesPerPlayer * players), 1, Config.maxCrates)
end

local function median(levels: { number }): number
	if #levels == 0 then
		return 1
	end
	local sorted = table.clone(levels)
	table.sort(sorted)
	return sorted[math.ceil(#sorted / 2)]
end

-- Raw goods the median player on the server has unlocked, with a Cargo Blimp crate range
function Express.pool(level: number, enabledCrops: { string }): { string }
	local pool = {}
	local crops = {}
	for _, id in enabledCrops do
		crops[id] = true
	end
	for id, def in Items do
		local raw = Config.goodKinds[def.kind] == true and (def.kind ~= "Crop" or crops[id] == true)
		if raw and def.unlockLevel <= level and BlimpConfig.crates[id] ~= nil then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	return pool
end

-- How many of `item` a crate asks for: the low half of its Cargo Blimp range at `level`
function Express.qtyRange(item: string, level: number): (number, number)
	local low, high = Blimp.qtyRange(item, level)
	return low, math.max(low, math.floor((low + high) / 2))
end

-- A new train for the window starting at `arrivedAt`. `levels` are the levels of the players
-- on the server at arrival; `pool` the goods it may ask for (Express.pool). Returns the train
-- and the next seed.
function Express.generate(arrivedAt: number, levels: { number }, pool: { string }, seed: number): (Train, number)
	seed = Rng.normalize(seed)
	local level = median(levels)
	local count = Express.crateCount(#levels)
	local crates = {}
	local remaining = {}
	for i = 1, count do
		if #pool == 0 then
			break
		end
		if #remaining == 0 then
			remaining = table.clone(pool)
		end
		local index
		index, seed = Rng.int(seed, 1, #remaining)
		local item = table.remove(remaining, index) :: string
		local low, high = Express.qtyRange(item, level)
		local qty
		qty, seed = Rng.int(seed, low, high)
		crates[i] = { item = item, qty = qty }
	end
	local prizes = {}
	for tier, coins in Config.tierCoins do
		local prize: Prize = { coins = coins }
		local spec = Config.tierPrizes[tier]
		if spec then
			local list = if spec.kind == "tool" then Config.tools else Config.materials
			local index
			index, seed = Rng.int(seed, 1, #list)
			prize.item = list[index]
			prize.qty = spec.qty
		end
		prizes[tier] = prize
	end
	local train: Train = {
		arrivedAt = arrivedAt,
		leavesAt = arrivedAt + Config.windowSeconds,
		crates = crates,
		cars = math.max(1, math.ceil(#crates / Config.cratesPerCar)),
		prizes = prizes,
		npc = #levels < Config.npcBelowPlayers,
		npcAt = arrivedAt,
		loaded = {},
		paid = {},
	}
	return train, seed
end

function Express.filled(train: Train): number
	local n = 0
	for _, crate in train.crates do
		if crate.by ~= nil then
			n += 1
		end
	end
	return n
end

-- How many tiers the loaded crates reach
function Express.tiersReached(train: Train): number
	local total = #train.crates
	if total == 0 then
		return 0
	end
	local share = Express.filled(train) / total
	local reached = 0
	for i, tier in Config.tiers do
		if share >= tier - 1e-9 then
			reached = i
		end
	end
	return reached
end

function Express.isOpen(train: Train, now: number): boolean
	return now >= train.arrivedAt and now < train.leavesAt
end

-- Can this crate be loaded now? Returns it when it can. (Goods are checked by the caller.)
function Express.canLoad(train: Train?, index: any, now: number): (Crate?, string?)
	if train == nil or not Express.isOpen(train, now) then
		return nil, "The Town Express isn't in the station"
	elseif type(index) ~= "number" or index % 1 ~= 0 then
		return nil
	end
	local crate = train.crates[index]
	if crate == nil then
		return nil
	elseif crate.by ~= nil then
		return nil, "That crate is already loaded"
	end
	return crate
end

-- Mark a crate loaded by `userId` (0 for an NPC neighbor)
function Express.load(train: Train, crate: Crate, userId: number)
	crate.by = userId
	if userId ~= 0 then
		local key = tostring(userId)
		train.loaded[key] = (train.loaded[key] or 0) + 1
	end
end

-- XP a loaded crate pays at once
function Express.crateXp(crate: Crate): number
	return math.max(1, math.floor(Items[crate.item].xpPerUnit * crate.qty * Config.crateXpMult + 0.5))
end

-- The tiers a player is owed now (reached, not yet paid, and they loaded at least one crate).
-- Marks them paid; the caller credits each tier's prize.
function Express.collect(train: Train, userId: number): { number }
	local key = tostring(userId)
	if (train.loaded[key] or 0) < 1 then
		return {}
	end
	local owed = {}
	local reached = Express.tiersReached(train)
	for tier = (train.paid[key] or 0) + 1, reached do
		table.insert(owed, tier)
	end
	train.paid[key] = math.max(train.paid[key] or 0, reached)
	return owed
end

-- An NPC neighbor loads one crate when one is due. Returns the crate's index, or nil.
function Express.npcTick(train: Train, now: number, seed: number): (number?, number)
	if not train.npc or not Express.isOpen(train, now) or now - train.npcAt < Config.npcSeconds then
		return nil, seed
	end
	local open = {}
	for i, crate in train.crates do
		if crate.by == nil then
			table.insert(open, i)
		end
	end
	train.npcAt += Config.npcSeconds
	if #open == 0 then
		return nil, seed
	end
	local pick
	pick, seed = Rng.int(seed, 1, #open)
	Express.load(train, train.crates[open[pick]], 0)
	return open[pick], seed
end

return Express
