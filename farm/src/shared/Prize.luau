--!strict
-- Prize Crops (Design/02 Farming): the roll, the Prize Basket and Prize Stand prices. Pure,
-- so Lune can test it. The basket is a list of { crop, tier }.

local Crops = require("./Config/Crops")
local Prize = require("./Config/Prize")

local PrizeRules = {}

-- `roll` is uniform in [0, 1). Rarest tier first. None while the first-session guide runs.
-- `boost` multiplies a tier's chance (an Heirloom Seed from the Seed Cart: { Heirloom = 10 }).
function PrizeRules.roll(data: { [string]: any }, roll: number, boost: { [string]: number }?): string?
	if data.tutorial.step ~= 0 then
		return nil
	end
	local ids = {}
	for id in Prize.tiers do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Prize.tiers[a].chance < Prize.tiers[b].chance
	end)
	for _, id in ids do
		roll -= Prize.tiers[id].chance * (if boost and boost[id] then boost[id] else 1)
		if roll < 0 then
			return id
		end
	end
	return nil
end

-- Coins at the Prize Stand: the crop's sell price times the tier's multiplier
function PrizeRules.value(crop: string, tier: string): number
	return Crops[crop].sellPrice * Prize.tiers[tier].value
end

function PrizeRules.hasRoom(data: { [string]: any }): boolean
	return #data.prizes < Prize.basketSlots
end

-- A Prize Crop counts as a normal unit of its crop for orders and factories (02 Farming).
-- Basket units only: the shelf is on show.
function PrizeRules.basketCount(data: { [string]: any }, crop: string): number
	local n = 0
	for _, entry in data.prizes do
		if entry.crop == crop then
			n += 1
		end
	end
	return n
end

-- Use up `n` basket units of a crop, the least valuable tier first. Returns how many it took.
function PrizeRules.take(data: { [string]: any }, crop: string, n: number): number
	local taken = 0
	while taken < n do
		local best, bestValue = nil, math.huge
		for i, entry in data.prizes do
			if entry.crop == crop and Prize.tiers[entry.tier].value < bestValue then
				best, bestValue = i, Prize.tiers[entry.tier].value
			end
		end
		if best == nil then
			break
		end
		table.remove(data.prizes, best)
		taken += 1
	end
	return taken
end

-- Basket -> Prize Shelf (shown on the plot)
function PrizeRules.shelve(data: { [string]: any }, index: number): (boolean, string?)
	if data.prizes[index] == nil then
		return false
	end
	if #data.prizeShelf >= Prize.shelfSlots then
		return false, string.format("Your Prize Shelf holds %d. Take one down first.", Prize.shelfSlots)
	end
	table.insert(data.prizeShelf, table.remove(data.prizes, index))
	return true
end

-- Prize Shelf -> basket
function PrizeRules.unshelve(data: { [string]: any }, slot: number): (boolean, string?)
	if data.prizeShelf[slot] == nil then
		return false
	end
	if not PrizeRules.hasRoom(data) then
		return false, "Your Prize Basket is full. Sell one first."
	end
	table.insert(data.prizes, table.remove(data.prizeShelf, slot))
	return true
end

return PrizeRules
