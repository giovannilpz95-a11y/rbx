--!strict
-- Gem prices for speed-ups (pure, shared by the server's charge and the client's buttons).

local Speedups = require("./Config/Speedups")

local Speedup = {}

export type Table = { { under: number, gems: number } }

-- Price to finish a timer with `secondsLeft` to go; 0 when it's already done.
function Speedup.price(tableRows: Table, secondsLeft: number): number
	if secondsLeft <= 0 then
		return 0
	end
	for _, row in tableRows do
		if secondsLeft < row.under then
			return row.gems
		end
	end
	return tableRows[#tableRows].gems
end

function Speedup.production(secondsLeft: number): number
	-- Speed Up All (02 Farming): every growing field of one crop, each priced on its own.
	-- Returns the summed Gem price and how many fields it covers.
	function Speedup.allFields(fields: { [string]: any }, crop: string, now: number): (number, number)
		local total, count = 0, 0
		for _, field in fields do
			if field.crop == crop and field.readyAt ~= nil and field.readyAt > now then
				total += Speedup.production(field.readyAt - now)
				count += 1
			end
		end
		return total, count
	end

	return Speedup.price(Speedups.production, secondsLeft)
end

function Speedup.building(secondsLeft: number): number
	return Speedup.price(Speedups.building, secondsLeft)
end

function Speedup.orderWait(secondsLeft: number): number
	return Speedup.price(Speedups.orderWait, secondsLeft)
end

-- Gems for the next queue slot of a factory that started with `startSlots`, or nil at max.
function Speedup.nextSlotCost(startSlots: number, slots: number): number?
	if slots >= Speedups.maxQueueSlots then
		return nil
	end
	return Speedups.queueSlotCosts[slots - startSlots + 1]
end

-- One pen's price: each producing animal is finished separately.
function Speedup.pen(pen: { [string]: any }, now: number): number
	local total = 0
	for _, animal in pen.animals do
		if animal.readyAt ~= nil and animal.readyAt > now then
			total += Speedup.production(animal.readyAt - now)
		end
	end
	return total
end

return Speedup
