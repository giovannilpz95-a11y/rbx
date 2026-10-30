--!strict
-- Seed Cart rules (Config/SeedCart), pure for the server, the client and the Lune tests.
-- The stock depends only on the restock window and the player's level, so everyone at a
-- level sees the same cart until the next restock. Saved as
-- data.seedCart = { period = restock window number, bought = { [slot] = true } },
-- data.heirloomSeeds = n (planted automatically with the next crop) and
-- data.decorCoupons = { [decorId] = n } (prepaid decorations, placed for free).

local Config = require("./Config/SeedCart")
local Crops = require("./Config/Crops")
local Decor = require("./Config/Decor")
local Rng = require("./Rng")

export type Slot = {
	kind: string, -- "Crate" | "Decor" | "Heirloom"
	id: string?, -- the crop (Crate) or the decoration (Decor)
	qty: number,
	price: number, -- Coins
}

local SeedCart = {}

-- Studio turns the cart on before its update ships (server/Services/SeedCartService)
local forcedOn = false
function SeedCart.forceOn(on: boolean)
	forcedOn = on
end

function SeedCart.isOpen(data: { [string]: any }): boolean
	return (Config.enabled or forcedOn) and data.level >= Config.unlockLevel
end

function SeedCart.period(now: number): number
	return math.floor(now / Config.restockSeconds)
end

function SeedCart.restockAt(now: number): number
	return (SeedCart.period(now) + 1) * Config.restockSeconds
end

local function unlocked(list: { [string]: any }, level: number, field: string): { string }
	local out = {}
	for id, def in list do
		if def[field] <= level then
			table.insert(out, id)
		end
	end
	table.sort(out, function(a, b)
		return list[a].order < list[b].order
	end)
	return out
end

local function crate(crop: string): Slot
	local def = Crops[crop]
	return {
		kind = "Crate",
		id = crop,
		qty = Config.crateQty,
		price = math.ceil(def.sellPrice * Config.cratePriceMult) * Config.crateQty,
	}
end

-- The four slots for a restock window at a level
function SeedCart.stock(period: number, level: number): { Slot }
	local seed = Rng.normalize(period * 7919 + 17)
	local crops = unlocked(Crops, level, "unlockLevel")
	local decor = unlocked(Decor.items, level, "unlockLevel")
	local slots: { Slot } = {}
	local pick: number
	-- Two different crops when there are two to choose from
	pick, seed = Rng.int(seed, 1, #crops)
	table.insert(slots, crate(crops[pick]))
	if #crops > 1 then
		local second
		second, seed = Rng.int(seed, 1, #crops - 1)
		if second >= pick then
			second += 1
		end
		table.insert(slots, crate(crops[second]))
	else
		table.insert(slots, crate(crops[pick]))
	end
	if #decor > 0 then
		pick, seed = Rng.int(seed, 1, #decor)
		local def = Decor.items[decor[pick]]
		table.insert(slots, {
			kind = "Decor",
			id = def.id,
			qty = 1,
			price = math.max(1, math.floor(def.coinCost * (1 - Config.decorDiscount))),
		})
	else
		table.insert(slots, crate(crops[1]))
	end
	local roll
	roll, seed = Rng.next(seed)
	if roll < Config.heirloomChance then
		table.insert(slots, { kind = "Heirloom", qty = 1, price = Config.heirloomPrice })
	else
		pick, seed = Rng.int(seed, 1, #crops)
		table.insert(slots, crate(crops[pick]))
	end
	return slots
end

-- Bring the saved purchases up to this restock window
function SeedCart.refresh(data: { [string]: any }, now: number)
	local period = SeedCart.period(now)
	if data.seedCart.period ~= period then
		data.seedCart.period = period
		data.seedCart.bought = {}
	end
end

-- Whether slot `index` can be bought now. Coins and Barn room are the caller's checks.
function SeedCart.canBuy(data: { [string]: any }, index: number, now: number): (boolean, string?, Slot?)
	if not SeedCart.isOpen(data) then
		return false, string.format("The Seed Cart opens at level %d", Config.unlockLevel), nil
	end
	SeedCart.refresh(data, now)
	local slot = SeedCart.stock(data.seedCart.period, data.level)[index]
	if slot == nil then
		return false, nil, nil
	end
	if data.seedCart.bought[tostring(index)] then
		return false, "Sold out until the next restock", nil
	end
	return true, nil, slot
end

function SeedCart.markBought(data: { [string]: any }, index: number)
	data.seedCart.bought[tostring(index)] = true
end

-- The next planting uses an Heirloom Seed if the player has one. Returns the Heirloom
-- chance multiplier for that field (1 without a seed).
function SeedCart.useHeirloomSeed(data: { [string]: any }): number
	if (data.heirloomSeeds or 0) > 0 and data.tutorial.step == 0 then
		data.heirloomSeeds -= 1
		return Config.heirloomBoost
	end
	return 1
end

-- A prepaid decoration from the cart is placed for free. Returns true if one was used.
function SeedCart.useCoupon(data: { [string]: any }, decorId: string): boolean
	local n = data.decorCoupons[decorId] or 0
	if n <= 0 then
		return false
	end
	data.decorCoupons[decorId] = if n == 1 then nil else n - 1
	return true
end

return SeedCart
