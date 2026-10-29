--!strict
-- Animal pen rules (Design/03 Animals), pure so the server, the client preview and the Lune
-- tests share them. A pen's saved data:
--   { built, constructionReadyAt?, animals = { { readyAt = n? } }, feedLeft = n }
-- An animal with no readyAt is hungry; once fed it produces until readyAt, then waits with
-- its product until collected (the tray is one product per animal, so nothing is lost).
-- feedLeft is what's left of the last opened bag (one bag feeds Animals.feedPerBag).

local Animals = require("./Config/Animals")

local Pen = {}

export type Counts = {
	hungry: number,
	producing: number,
	ready: number,
	nextReadyAt: number?, -- soonest product still on its way
}

function Pen.isOperational(pen: { [string]: any }, now: number): boolean
	return pen.built == true and (pen.constructionReadyAt == nil or now >= pen.constructionReadyAt)
end

function Pen.counts(pen: { [string]: any }, now: number): Counts
	local counts: Counts = { hungry = 0, producing = 0, ready = 0, nextReadyAt = nil }
	for _, animal in pen.animals do
		if animal.readyAt == nil then
			counts.hungry += 1
		elseif now >= animal.readyAt then
			counts.ready += 1
		else
			counts.producing += 1
			if counts.nextReadyAt == nil or animal.readyAt < counts.nextReadyAt then
				counts.nextReadyAt = animal.readyAt
			end
		end
	end
	return counts
end

-- Feed every hungry animal it can. takeBag removes one bag of the pen's feed from the Barn
-- and returns false when there is none. Returns how many animals were fed.
function Pen.feed(pen: { [string]: any }, now: number, seconds: number, takeBag: () -> boolean): number
	local fed = 0
	for _, animal in pen.animals do
		if animal.readyAt == nil then
			if (pen.feedLeft or 0) <= 0 then
				if not takeBag() then
					break
				end
				pen.feedLeft = Animals.feedPerBag
			end
			pen.feedLeft -= 1
			animal.readyAt = now + seconds
			fed += 1
		end
	end
	return fed
end

-- Take up to `space` ready products; those animals go hungry again. Returns how many.
function Pen.collect(pen: { [string]: any }, now: number, space: number): number
	local collected = 0
	for _, animal in pen.animals do
		if collected >= space then
			break
		end
		if animal.readyAt ~= nil and now >= animal.readyAt then
			animal.readyAt = nil
			collected += 1
		end
	end
	return collected
end

-- Coins for the next animal, or nil when the pen is full.
function Pen.nextAnimalCost(def: Animals.PenDef, pen: { [string]: any }): number?
	local extra = #pen.animals - def.startAnimals + 1
	if #pen.animals >= Animals.maxAnimals or extra < 1 then
		return nil
	end
	return def.extraAnimalCosts[extra]
end

return Pen
