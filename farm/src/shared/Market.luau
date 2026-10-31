--!strict
-- Market stall rules (Config/Market), pure so the server, the client and the Lune tests share
-- them. A farm's stall lives in its save:
--   market.listings   { { slot, item, qty, price, listedAt } }, at most one per slot
--   market.featured   the slot shown on the Town Square's Market board (0 = none)
--   market.featuredAt when the featured slot last changed
--   market.buys       seller UserId (string) -> { at, n }: this farm's buys from that seller
--                     in the hour that started at `at`
-- Goods leave the Barn when listed and come back when a listing is taken down. A sale pays the
-- seller at once (sellers are always on the server: a stall only exists while its farm does).

local Config = require("./Config/Market")
local Items = require("./Items")

local Market = {}

export type Listing = { slot: number, item: string, qty: number, price: number, listedAt: number }

local HOUR = 3600

function Market.slotCount(level: number): number
	if level < Config.unlockLevel then
		return 0
	end
	local n = Config.baseSlots
	for _, at in Config.extraSlotLevels do
		if level >= at then
			n += 1
		end
	end
	return n
end

function Market.tradeable(item: any): boolean
	local def = type(item) == "string" and Items[item] or nil
	return def ~= nil and Config.kinds[def.kind] == true and def.sellPrice > 0
end

-- The goods' Barn value, the reference for the price band
function Market.basePrice(item: string, qty: number): number
	return Items[item].sellPrice * qty
end

-- The lowest, highest and default price for `qty` of `item`
function Market.priceRange(item: string, qty: number): (number, number, number)
	local base = Market.basePrice(item, qty)
	local low = math.max(1, math.ceil(base * Config.priceMin - 1e-9))
	local high = math.max(low, math.floor(base * Config.priceMax + 1e-9))
	local default = math.clamp(math.floor(base * Config.priceDefault + 0.5), low, high)
	return low, high, default
end

local function market(data: { [string]: any }): { [string]: any }
	return data.market
end

function Market.listing(data: { [string]: any }, slot: any): (Listing?, number?)
	for i, listing in market(data).listings do
		if listing.slot == slot then
			return listing, i
		end
	end
	return nil, nil
end

local function whole(n: any, low: number, high: number): boolean
	return type(n) == "number" and n == n and n % 1 == 0 and n >= low and n <= high
end

-- Can this farm list `qty` of `item` at `price` in `slot`? `have` is how many it holds.
function Market.canList(
	data: { [string]: any },
	slot: any,
	item: any,
	qty: any,
	price: any,
	have: number
): (boolean, string?)
	local slots = Market.slotCount(data.level)
	if slots == 0 then
		return false, string.format("Your Market stall opens at level %d", Config.unlockLevel)
	elseif not whole(slot, 1, slots) then
		return false
	elseif Market.listing(data, slot) then
		return false, "That slot is already in use"
	elseif not Market.tradeable(item) then
		return false, "That can't be sold at the Market"
	elseif not whole(qty, 1, Config.maxQty) then
		return false, string.format("A slot holds 1 to %d of one item", Config.maxQty)
	end
	local low, high = Market.priceRange(item, qty)
	if not whole(price, low, high) then
		return false, string.format("Pick a price from %d to %d Coins", low, high)
	elseif have < qty then
		return false, string.format("You have only %d %s", have, Items[item].displayName)
	end
	return true
end

function Market.list(
	data: { [string]: any },
	slot: number,
	item: string,
	qty: number,
	price: number,
	now: number
): Listing
	local listing: Listing = { slot = slot, item = item, qty = qty, price = price, listedAt = now }
	table.insert(market(data).listings, listing)
	return listing
end

-- Take a listing off the stall (the caller returns its goods). Returns it, or nil.
function Market.remove(data: { [string]: any }, slot: any): Listing?
	local listing, index = Market.listing(data, slot)
	if listing == nil or index == nil then
		return nil
	end
	table.remove(market(data).listings, index)
	if market(data).featured == slot then
		market(data).featured = 0
	end
	return listing
end

-- How many listings `buyer` took from the seller keyed `sellerKey` this hour
function Market.buysThisHour(buyer: { [string]: any }, sellerKey: string, now: number): number
	local entry = market(buyer).buys[sellerKey]
	if entry == nil or now - entry.at >= HOUR then
		return 0
	end
	return entry.n
end

-- Can `buyer` take the listing in `slot` of `seller`'s stall now? Barn room is the caller's
-- check. Returns the listing when it can.
function Market.canBuy(
	buyer: { [string]: any },
	seller: { [string]: any },
	sellerKey: string,
	slot: any,
	now: number
): (Listing?, string?)
	if buyer == seller then
		return nil, "That's your own stall"
	elseif Market.slotCount(buyer.level) == 0 then
		return nil, string.format("The Market opens at level %d", Config.unlockLevel)
	end
	local listing = Market.listing(seller, slot)
	if listing == nil then
		return nil, "That's already sold"
	elseif buyer.currencies.Coins < listing.price then
		return nil, string.format("That costs %d Coins", listing.price)
	elseif Market.buysThisHour(buyer, sellerKey, now) >= Config.buysPerSellerPerHour then
		return nil, "You've bought a lot from this stall this hour. Try another one, or come back later"
	end
	local created = buyer.meta and buyer.meta.createdAt or 0
	local young = created > 0 and now - created < Config.newFarmSeconds
	if young and listing.price > Market.basePrice(listing.item, listing.qty) * Config.newFarmMaxShare + 1e-9 then
		return nil, "New farms can't buy at that price yet. Look for a cheaper stall"
	end
	return listing
end

-- What a sale at `price` pays the seller and burns
function Market.proceeds(price: number): (number, number)
	local tax = math.floor(price * Config.taxRate + 0.5)
	return price - tax, tax
end

-- Move the listing from `seller`'s stall to `buyer` (the caller moves Coins and goods).
-- Returns the listing, the seller's proceeds and the tax.
function Market.buy(
	buyer: { [string]: any },
	seller: { [string]: any },
	sellerKey: string,
	slot: number,
	now: number
): (Listing, number, number)
	local listing = Market.remove(seller, slot) :: Listing
	local buys = market(buyer).buys
	local entry = buys[sellerKey]
	if entry == nil or now - entry.at >= HOUR then
		entry = { at = now, n = 0 }
		buys[sellerKey] = entry
	end
	entry.n += 1
	-- forget sellers from earlier hours so the save doesn't grow
	for key, old in buys do
		if now - old.at >= HOUR then
			buys[key] = nil
		end
	end
	local proceeds, tax = Market.proceeds(listing.price)
	return listing, proceeds, tax
end

-- What the passing trader pays for a listing: the Barn price, or the listing's if lower
function Market.botPrice(listing: Listing): number
	return math.min(listing.price, math.floor(Market.basePrice(listing.item, listing.qty) * Config.botShare + 0.5))
end

-- When the trader takes a listing (`scale`: the Studio time scale)
function Market.botAt(listing: Listing, scale: number?): number
	return listing.listedAt + math.max(1, math.floor(Config.botSeconds * (scale or 1) + 0.5))
end

-- The trader takes every listing that's waited long enough. Returns { listing, price } for
-- each, already off the stall (the caller pays the seller).
function Market.botTick(data: { [string]: any }, now: number, scale: number?): { { listing: Listing, price: number } }
	local sold = {}
	for _, listing in table.clone(market(data).listings) do
		if now >= Market.botAt(listing, scale) then
			Market.remove(data, listing.slot)
			table.insert(sold, { listing = listing, price = Market.botPrice(listing) })
		end
	end
	return sold
end

-- Feature a slot's listing on the Town Square's Market board (once every 5 minutes)
function Market.feature(data: { [string]: any }, slot: any, now: number): (boolean, string?)
	if Market.listing(data, slot) == nil then
		return false, "List something in that slot first"
	end
	local m = market(data)
	if m.featured == slot then
		return false
	end
	local wait = m.featuredAt + Config.featureCooldown - now
	if m.featured ~= 0 and wait > 0 then
		return false, string.format("You can change your featured listing in %d:%02d", wait // 60, wait % 60)
	end
	m.featured = slot
	m.featuredAt = now
	return true
end

return Market
