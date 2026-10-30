--!strict
-- Town Records rules (goals in Config/Records): counting, reading progress, and claiming the
-- next tier. Pure, so the server's claim, the Farmer Card and the tests agree.

local Config = require("./Config/Records")
local TownRules = require("./TownRules")

export type View = { id: string, value: number, claimed: number }

local Records = {}

local byId: { [string]: Config.RecordDef } = {}
for _, def in Config.list do
	byId[def.id] = def
end

function Records.def(id: string): Config.RecordDef?
	return byId[id]
end

-- The farm services count what isn't kept elsewhere in the save
function Records.add(data: { [string]: any }, stat: string, amount: number)
	if amount <= 0 then
		return
	end
	local stats = data.records.stats
	stats[stat] = (stats[stat] or 0) + amount
end

function Records.value(data: { [string]: any }, stat: string, now: number): number
	if stat == "orders" then
		return data.orders.delivered
	elseif stat == "population" then
		return TownRules.population(data, now)
	elseif stat == "houses" then
		local n = 0
		for _, house in data.town.houses do
			if TownRules.isDone(house, now) then
				n += 1
			end
		end
		return n
	elseif stat == "factories" then
		local n = 0
		for _, factory in data.factories do
			if factory.built and (factory.constructionReadyAt == nil or now >= factory.constructionReadyAt) then
				n += 1
			end
		end
		return n
	end
	return data.records.stats[stat] or 0
end

-- Tiers claimed (0-3)
function Records.claimed(data: { [string]: any }, id: string): number
	return data.records.claimed[id] or 0
end

-- The tier that can be claimed now (1-3), or nil
function Records.ready(data: { [string]: any }, id: string, now: number): number?
	local def = byId[id]
	if def == nil then
		return nil
	end
	local nextTier = Records.claimed(data, id) + 1
	local goal = def.goals[nextTier]
	if goal and Records.value(data, def.stat, now) >= goal then
		return nextTier
	end
	return nil
end

-- Claims the next tier. Returns the tier and its def, or nil and a reason.
function Records.claim(data: { [string]: any }, id: any, now: number): (number?, Config.RecordDef | string)
	local def = if type(id) == "string" then byId[id] else nil
	if def == nil then
		return nil, "No such record"
	end
	local tier = Records.ready(data, def.id, now)
	if tier == nil then
		return nil, "Not there yet"
	end
	data.records.claimed[def.id] = tier
	return tier, def
end

-- For the Farmer Card: every record's progress and tiers claimed
function Records.view(data: { [string]: any }, now: number): { View }
	local out: { View } = {}
	for _, def in Config.list do
		table.insert(
			out,
			{ id = def.id, value = Records.value(data, def.stat, now), claimed = Records.claimed(data, def.id) }
		)
	end
	return out
end

-- Stars (tiers claimed) across every record, from a view or the save
function Records.stars(views: { View }): number
	local n = 0
	for _, v in views do
		n += v.claimed
	end
	return n
end

-- Ready to claim in a view (the next goal reached)
function Records.viewReady(v: View): boolean
	local def = byId[v.id]
	local goal = def and def.goals[v.claimed + 1]
	return goal ~= nil and v.value >= goal
end

function Records.title(stars: number): string
	for _, t in Config.titles do
		if stars >= t.stars then
			return t.title
		end
	end
	return Config.titles[#Config.titles].title
end

return Records
