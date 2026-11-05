--!strict
-- The Wandering Peddler's rules (Config/Sky peddler; Design/14 H2). Pure, so the server, the
-- panel and the tests agree. The stock depends only on the visit, the player and their level,
-- so it is the player's own and the client can show it without asking. Saved as
-- data.peddler = { visit = the visit id the purchases are for, bought = { [slot] = true } }.

local Config = require("./Config/Sky")
local Decor = require("./Config/Decor")
local Rng = require("./Rng")

local Peddler = {}

export type Slot = {
	kind: string, -- "Decor" | "Seeds"
	id: string?, -- the decoration
	qty: number,
	price: number, -- Coins
	early: boolean?, -- a decoration from above the player's level
}

local function decorBetween(low: number, high: number): { string }
	local out = {}
	for id, def in Decor.items do
		if not (def :: any).trophy and def.unlockLevel >= low and def.unlockLevel <= high then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- The three offers for one player on one visit
function Peddler.stock(visit: number, userId: number, level: number): { Slot }
	local p = Config.peddler
	local seed = Rng.normalize(visit * 104729 + (userId % 2147483) * 7919 + level)
	local slots: { Slot } = {}
	local early = decorBetween(level + 1, level + p.earlyLevels)
	local now = decorBetween(1, level)
	local pick: number
	if #early > 0 then
		pick, seed = Rng.int(seed, 1, #early)
		local def = Decor.items[early[pick]]
		table.insert(slots, {
			kind = "Decor",
			id = def.id,
			qty = 1,
			price = math.ceil(def.coinCost * p.earlyMult),
			early = true,
		})
	end
	if #now > 0 then
		-- A deal at your level, or two when nothing is ahead
		local want = if #early > 0 then 1 else math.min(2, #now)
		local first = nil
		for _ = 1, want do
			pick, seed = Rng.int(seed, 1, #now)
			if first and now[pick] == first and #now > 1 then
				pick = pick % #now + 1
			end
			first = now[pick]
			local def = Decor.items[now[pick]]
			table.insert(slots, {
				kind = "Decor",
				id = def.id,
				qty = 1,
				price = math.max(1, math.floor(def.coinCost * (1 - p.dealDiscount))),
			})
		end
	end
	table.insert(slots, { kind = "Seeds", qty = p.seeds, price = p.seeds * p.seedPrice })
	return slots
end

-- Bring the saved purchases up to this visit
function Peddler.refresh(data: { [string]: any }, visit: number)
	if data.peddler.visit ~= visit then
		data.peddler.visit = visit
		data.peddler.bought = {}
	end
end

-- Whether slot `index` can be bought on `visit`. Coins and reach are the caller's checks.
function Peddler.canBuy(data: { [string]: any }, visit: number, userId: number, index: any): (boolean, string?, Slot?)
	if type(index) ~= "number" or index % 1 ~= 0 then
		return false
	end
	Peddler.refresh(data, visit)
	local slot = Peddler.stock(visit, userId, data.level)[index]
	if slot == nil then
		return false
	end
	if data.peddler.bought[tostring(index)] then
		return false, "You've bought that one already"
	end
	return true, nil, slot
end

-- Hand over what a slot sells
function Peddler.give(data: { [string]: any }, slot: Slot)
	if slot.kind == "Seeds" then
		data.heirloomSeeds = (data.heirloomSeeds or 0) + slot.qty
	elseif slot.id then
		data.decorCoupons[slot.id] = (data.decorCoupons[slot.id] or 0) + slot.qty
	end
end

function Peddler.markBought(data: { [string]: any }, index: number)
	data.peddler.bought[tostring(index)] = true
end

return Peddler
