--!strict
-- The "While you were away" summary (Design/01 Core Loop, Offline Progress): what finished
-- while the player was gone, shown once on join. Pure for the server and the Lune tests.

local Animals = require("./Config/Animals")
local Factories = require("./Config/Factories")
local Land = require("./Config/Land")
local Pen = require("./Pen")
local Town = require("./Config/Town")

local Away = {}

Away.minSeconds = 5 * 60 -- shorter breaks get no summary (first-pass)

local function plural(n: number, one: string, many: string): string
	return string.format("%d %s", n, if n == 1 then one else many)
end

-- Lines to show, or an empty list. `since` is when the player was last seen.
function Away.summary(data: { [string]: any }, since: number, now: number): { string }
	local lines = {}
	if since <= 0 or now - since < Away.minSeconds then
		return lines
	end
	local function finished(readyAt: number?): boolean
		return readyAt ~= nil and readyAt > since and readyAt <= now
	end

	local ready = 0
	for _, field in data.fields do
		if field.crop ~= nil and (field.readyAt or 0) <= now then
			ready += 1
		end
	end
	if ready > 0 then
		table.insert(lines, plural(ready, "field is", "fields are") .. " ready to harvest")
	end

	local goods = 0
	for id, factory in data.factories do
		if finished(factory.constructionReadyAt) then
			table.insert(lines, Factories[id].displayName .. " finished building")
		end
		for _, qty in factory.output do
			goods += qty
		end
	end
	if goods > 0 then
		table.insert(lines, plural(goods, "good is", "goods are") .. " waiting at your factories")
	end

	for id, pen in data.pens do
		local def = Animals.pens[id]
		if finished(pen.constructionReadyAt) then
			table.insert(lines, def.displayName .. " finished building")
		end
		local products = Pen.counts(pen, now).ready
		if products > 0 then
			table.insert(lines, string.format("%d %s ready at the %s", products, def.productName, def.displayName))
		end
	end

	for _, house in data.town.houses do
		if finished(house.readyAt) then
			table.insert(lines, "Your " .. Town.houses[house.type].displayName .. " is built")
		end
	end
	for id, entry in data.town.community do
		if finished(entry.readyAt) then
			table.insert(lines, "The " .. Town.community[id].displayName .. " is built")
		end
	end
	for stage, entry in data.land do
		if finished(entry.readyAt) then
			table.insert(lines, "The " .. Land.expansions[stage].displayName .. " is cleared")
		end
	end

	local cards = 0
	for _, slot in data.orders.board do
		if slot.order then
			cards += 1
		end
	end
	if cards > 0 then
		table.insert(lines, plural(cards, "order is", "orders are") .. " on the board")
	end
	return lines
end

return Away
