--!strict
-- Quarry rules (Features/F01 Quarry & Smelter), pure so the server, the client and the Lune
-- tests share them. Saved under data.quarry:
--   readyAt  nil until reopening starts; reopened once the time has passed
--   seed     fixes every cell's block and find, so reconnecting can't reroll a dig
--   rows     row number (string) -> bitmask of the cells dug out in that row
--   hits     "row:col" -> hits a Stone block has taken so far
--   freeDay  UTC day of the last free Pickaxes at the gate
-- Row 0 is the surface and always open; rows count down from 1 (one row = one metre). A cell
-- can be dug once a side neighbour is open. Ore goes to data.oreShed (no cap).

local Config = require("./Config/Quarry")

local Quarry = {}

export type Cell = { block: Config.Block, find: string?, coins: number? }
export type DigResult = {
	cleared: boolean, -- false: a Stone block took a hit and is still there
	find: string?, -- an ore id, or "Lunchbox"
	coins: number?, -- a pile of Coins
	pickaxes: number?, -- from a Lunchbox
	xp: number,
}

local ORE_IDS: { string } = {}
for id in Config.ores do
	table.insert(ORE_IDS, id)
end
table.sort(ORE_IDS, function(a, b)
	return Config.ores[a].order < Config.ores[b].order
end)
Quarry.ORE_IDS = table.freeze(ORE_IDS)

-- A well-mixed 31-bit hash of the seed, a cell and a salt, so every roll for a cell is fixed
local function hash(seed: number, row: number, col: number, salt: number): number
	local h = bit32.bxor(seed % 2147483647, row * 374761393 % 4294967296)
	h = bit32.bxor(h, (col + 1) * 668265263 % 4294967296)
	h = bit32.bxor(h, (salt + 1) * 2246822519 % 4294967296)
	for _ = 1, 3 do
		h = bit32.bxor(h, bit32.rshift(h, 15))
		h = (h * 2246822519) % 4294967296
		h = bit32.bxor(h, bit32.rshift(h, 13))
		h = (h * 3266489917) % 4294967296
		h = bit32.bxor(h, bit32.rshift(h, 16))
	end
	return h
end

-- A float in [0, 1) for one roll of one cell
local function roll(seed: number, row: number, col: number, salt: number): number
	return hash(seed, row, col, salt) / 4294967296
end
Quarry.roll = roll

local SALT_ROCK, SALT_STONE, SALT_FIND, SALT_COINS = 1, 2, 3, 4

local function rawBedrock(seed: number, row: number, col: number): boolean
	if row < 1 or col < 1 or col > Config.width then
		return false
	end
	return roll(seed, row, col, SALT_ROCK) < Config.bedrockChance
end

-- Bedrock only where no side neighbour also rolled it, so it never forms a wall
local function isBedrock(seed: number, row: number, col: number): boolean
	if not rawBedrock(seed, row, col) then
		return false
	end
	for _, d in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do
		if rawBedrock(seed, row + d[1], col + d[2]) then
			return false
		end
	end
	return true
end

function Quarry.stoneShare(row: number): number
	local s = Config.stoneShare
	return math.min(s.base + row * s.perRow, s.max)
end

-- What a cell holds, fixed by the seed. Bedrock holds nothing.
function Quarry.cell(seed: number, row: number, col: number): Cell
	if isBedrock(seed, row, col) then
		return { block = "Bedrock" }
	end
	local block: Config.Block = if roll(seed, row, col, SALT_STONE) < Quarry.stoneShare(row) then "Stone" else "Soil"
	local r = roll(seed, row, col, SALT_FIND)
	-- Rarest first, each band stacked on the last
	local edge = 0
	for i = #ORE_IDS, 1, -1 do
		local ore = Config.ores[ORE_IDS[i]]
		if row >= ore.fromDepth then
			edge += ore.chance
			if r < edge then
				return { block = block, find = ore.id }
			end
		end
	end
	edge += Config.lunchbox.chance
	if r < edge then
		return { block = block, find = "Lunchbox" }
	end
	edge += Config.coinPile.chance
	if r < edge then
		local pile = Config.coinPile
		local coins = pile.min + math.floor(roll(seed, row, col, SALT_COINS) * (pile.max - pile.min + 1))
		return { block = block, coins = coins }
	end
	return { block = block }
end

function Quarry.isRestored(data: { [string]: any }, now: number): boolean
	local q = data.quarry
	return q.readyAt ~= nil and now >= q.readyAt
end

function Quarry.isOpen(q: { [string]: any }, row: number, col: number): boolean
	if row <= 0 then
		return true
	end
	if col < 1 or col > Config.width then
		return false
	end
	local mask = q.rows[tostring(row)]
	return mask ~= nil and bit32.btest(mask, bit32.lshift(1, col - 1))
end

local function setOpen(q: { [string]: any }, row: number, col: number)
	local key = tostring(row)
	q.rows[key] = bit32.bor(q.rows[key] or 0, bit32.lshift(1, col - 1))
end

-- A cell is in reach (and its contents show) once a side neighbour is open
function Quarry.inReach(q: { [string]: any }, row: number, col: number): boolean
	return Quarry.isOpen(q, row - 1, col)
		or Quarry.isOpen(q, row + 1, col)
		or Quarry.isOpen(q, row, col - 1)
		or Quarry.isOpen(q, row, col + 1)
end

-- The deepest row with a cell dug out (0 before the first dig)
function Quarry.depth(q: { [string]: any }): number
	local deepest = 0
	for key in q.rows do
		deepest = math.max(deepest, tonumber(key) or 0)
	end
	return deepest
end

function Quarry.pickaxes(data: { [string]: any }): number
	return data.toolShed.items[Config.pickaxe] or 0
end

-- Can this cell be dug now? Returns false and a reason when not.
function Quarry.canDig(data: { [string]: any }, row: number, col: number, now: number): (boolean, string?)
	if not Quarry.isRestored(data, now) then
		return false, "The Quarry isn't open yet"
	end
	local q = data.quarry
	if row < 1 or col < 1 or col > Config.width or row ~= math.floor(row) or col ~= math.floor(col) then
		return false, nil
	end
	if Quarry.isOpen(q, row, col) then
		return false, nil
	end
	if not Quarry.inReach(q, row, col) then
		return false, "Dig next to an open spot"
	end
	if Quarry.cell(q.seed, row, col).block == "Bedrock" then
		return false, "Bedrock is too hard to dig"
	end
	if Quarry.pickaxes(data) < 1 then
		return false, "You need a Pickaxe"
	end
	return true, nil
end

-- Swings one Pickaxe at a cell (check canDig first). Ore goes to the Ore Shed and Pickaxes to
-- the Tool Shed here; the caller pays the Coins and XP in the result.
function Quarry.dig(data: { [string]: any }, row: number, col: number): DigResult
	local q = data.quarry
	local items = data.toolShed.items
	items[Config.pickaxe] = (items[Config.pickaxe] or 0) - 1
	local cell = Quarry.cell(q.seed, row, col)
	local key = row .. ":" .. col
	local taken = (q.hits[key] or 0) + 1
	if taken < (Config.hits[cell.block] or 1) then
		q.hits[key] = taken
		return { cleared = false, xp = 0 }
	end
	q.hits[key] = nil
	setOpen(q, row, col)
	local result: DigResult = { cleared = true, find = cell.find, coins = cell.coins, xp = 0 }
	local ore = cell.find and Config.ores[cell.find]
	if ore then
		data.oreShed[ore.id] = (data.oreShed[ore.id] or 0) + 1
		result.xp = ore.xp
	elseif cell.find == "Lunchbox" then
		result.pickaxes = Config.lunchbox.pickaxes
		items[Config.pickaxe] += Config.lunchbox.pickaxes
	end
	return result
end

-- Starts reopening the Quarry (check level and Coins first). Picks the seed and gives the
-- opening Pickaxes.
function Quarry.restore(data: { [string]: any }, now: number, seed: number)
	local q = data.quarry
	q.readyAt = now + Config.restoreSeconds
	q.seed = seed % 2147483646 + 1
	local items = data.toolShed.items
	items[Config.pickaxe] = (items[Config.pickaxe] or 0) + Config.restoreGift
end

-- The day's free Pickaxes at the gate: how many it gives now (0 when already taken today)
function Quarry.claimFree(data: { [string]: any }, day: number, now: number): number
	local q = data.quarry
	if not Quarry.isRestored(data, now) or q.freeDay == day then
		return 0
	end
	q.freeDay = day
	local items = data.toolShed.items
	items[Config.pickaxe] = (items[Config.pickaxe] or 0) + Config.dailyFree
	return Config.dailyFree
end

return Quarry
