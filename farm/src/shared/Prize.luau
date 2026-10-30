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

return PrizeRules
