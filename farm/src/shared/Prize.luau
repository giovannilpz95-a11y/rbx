--!strict
-- Prize Crops (Design/02 Farming): the roll, the Prize Basket and Prize Stand prices. Pure,
-- so Lune can test it. The basket is a list of { crop, tier }.

local Crops = require("./Config/Crops")
local Prize = require("./Config/Prize")

local PrizeRules = {}

-- `roll` is uniform in [0, 1). Rarest tier first. None while the first-session guide runs.
function PrizeRules.roll(data: { [string]: any }, roll: number): string?
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
		roll -= Prize.tiers[id].chance
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
