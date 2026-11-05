--!strict
-- County Fair rules (Config/Fair), pure for the server, the client and the Lune tests: the
-- weekly window, entering, the judges' marks, ribbons, and paying out after judging.
--
-- data.fair = { week, entries, ribbons, paid }: `week` is the window's start (unix seconds),
-- entries[class] = { item, tier?, garnish?, marks }, ribbons[color] = ribbons won in all,
-- `paid` = the week whose results were handed over.

local Config = require("./Config/Fair")
local Crops = require("./Config/Crops")
local Items = require("./Items")
local Recipes = require("./Config/Recipes")
local Rng = require("./Rng")

local Fair = {}

local DAY = 86400

local preview: number? = nil -- Studio: a fair starting at this time instead of the calendar

function Fair.setPreview(startsAt: number?)
	preview = startsAt
end

-- This week's window: when entries opened (the week's id), when they close (judging), and
-- when the next one opens
function Fair.window(now: number): (number, number, number)
	if preview and now >= preview and now < preview + Config.previewSeconds then
		return preview, preview + Config.openSeconds, preview + Config.previewSeconds
	end
	local t = now - Config.opensHour * 3600
	local d = t // DAY
	local weekday = (d + 4) % 7 -- 1970-01-01 was a Thursday; 0 = Sunday
	local since = (weekday - Config.opensWeekday) % 7
	local opens = (d - since) * DAY + Config.opensHour * 3600
	return opens, opens + Config.openSeconds, opens + 7 * DAY
end

function Fair.isOpen(now: number): boolean
	local _, closes = Fair.window(now)
	return now < closes
end

function Fair.blank(week: number): { [string]: any }
	return { week = week, entries = {}, ribbons = {}, paid = 0 }
end

-- The ribbon for `marks`
function Fair.ribbon(marks: number): { id: string, displayName: string, icon: string, marks: number }
	for _, r in Config.ribbons do
		if marks >= r.marks then
			return r
		end
	end
	return Config.ribbons[#Config.ribbons]
end

-- The judges' mood for this farm's entry: 0-luckMax, fixed per week, farm and class. The
-- Park-Miller generator is warmed up first, so nearby seeds don't give nearby rolls.
local function luck(week: number, userId: number, class: string): number
	local seed =
		Rng.normalize((week // 3600) * 7919 + (userId % 1000003) * 104729 + (if class == "Bake" then 17 else 5))
	for _ = 1, 3 do
		_, seed = Rng.next(seed)
	end
	local n = Rng.int(seed, 0, Config.luckMax)
	return n
end

function Fair.produceMarks(crop: string, tier: string, week: number, userId: number): number
	local def = Crops[crop]
	local bonus = if def then math.min(Config.cropMax, def.unlockLevel // Config.cropLevelsPerMark) else 0
	return math.min(100, (Config.produceTier[tier] or 0) + bonus + luck(week, userId, "Produce"))
end

function Fair.bakeMarks(item: string, garnishTier: string?, week: number, userId: number): number
	local def = Items[item]
	local seconds = if def then def.unitSeconds else 0
	local marks = Config.bakeBase
		+ math.min(Config.bakeMax, math.floor(seconds / Config.bakeSecondsPerMark))
		+ (if garnishTier then Config.garnishTier[garnishTier] or 0 else 0)
		+ luck(week, userId, "Bake")
	return math.min(100, marks)
end

-- Bakery goods this farm has in its Barn, for the Best Bake picker
function Fair.bakes(data: { [string]: any }): { string }
	local out = {}
	for id, recipe in Recipes do
		if recipe.factory == Config.bakeFactory and (data.inventory.items[id] or 0) > 0 then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

local function prizeAt(data: { [string]: any }, index: any): { crop: string, tier: string }?
	if type(index) ~= "number" or index % 1 ~= 0 then
		return nil
	end
	local p = data.prizes[index]
	if type(p) ~= "table" or Config.produceTier[p.tier] == nil then
		return nil
	end
	return p
end

-- Can this farm enter `class` now? For Produce `a` is a Prize Basket index; for Bake `a` is
-- the Bakery good and `b` an optional Prize Basket index for the garnish.
function Fair.canEnter(data: { [string]: any }, now: number, class: any, a: any, b: any): (boolean, string?)
	if type(class) ~= "string" or Config.classes[class] == nil then
		return false
	end
	if data.level < Config.minLevel then
		return false, string.format("The County Fair opens at level %d", Config.minLevel)
	end
	if not Fair.isOpen(now) then
		return false, "Entries are closed: the judges are at work. Results are in the Fair panel."
	end
	local week = Fair.window(now)
	if data.fair.week == week and data.fair.entries[class] then
		return false, "You've entered this class already this fair"
	end
	if class == "Produce" then
		if prizeAt(data, a) == nil then
			return false, "Pick a Prize Crop from your Prize Basket"
		end
		return true
	end
	if type(a) ~= "string" or Recipes[a] == nil or Recipes[a].factory ~= Config.bakeFactory then
		return false, "Pick a Bakery good"
	end
	if (data.inventory.items[a] or 0) < 1 then
		return false, string.format("You need 1 %s in your Barn", Recipes[a].displayName)
	end
	if b ~= nil and prizeAt(data, b) == nil then
		return false, "That Prize Crop isn't in your Prize Basket"
	end
	return true
end

-- Enter (after canEnter): takes the Prize Crop / Bakery good and records the marks
function Fair.enter(data: { [string]: any }, now: number, userId: number, class: string, a: any, b: any)
	local week = Fair.window(now)
	if data.fair.week ~= week then
		data.fair.week = week
		data.fair.entries = {}
	end
	local entry
	if class == "Produce" then
		local p = table.remove(data.prizes, a) :: any
		entry = { item = p.crop, tier = p.tier, marks = Fair.produceMarks(p.crop, p.tier, week, userId) }
	else
		data.inventory.items[a] -= 1
		if data.inventory.items[a] <= 0 then
			data.inventory.items[a] = nil
		end
		local garnish = nil
		if b ~= nil then
			local p = table.remove(data.prizes, b) :: any
			garnish = p.tier
			entry = { item = a, garnish = garnish, garnishCrop = p.crop }
		else
			entry = { item = a }
		end
		entry.marks = Fair.bakeMarks(a, garnish, week, userId)
	end
	data.fair.entries[class] = entry
end

export type Result = { class: string, marks: number, ribbon: string, cup: string? }

-- After judging: hand over the week's ribbons and Blue Ribbon cups (once), and start a fresh
-- block for the current week. Returns the results paid now (empty if nothing to pay).
function Fair.sync(data: { [string]: any }, now: number): { Result }
	local block = data.fair
	local week, closes = Fair.window(now)
	local results: { Result } = {}
	local judged = block.week ~= 0 and (block.week ~= week or now >= closes)
	if judged and block.paid ~= block.week then
		for _, class in Config.order do
			local entry = block.entries[class]
			if entry then
				local ribbon = Fair.ribbon(entry.marks)
				block.ribbons[ribbon.id] = (block.ribbons[ribbon.id] or 0) + 1
				local cup = nil
				if ribbon.id == "Blue" then
					cup = Config.classes[class].cup
					data.trophies[cup] = (data.trophies[cup] or 0) + 1
				end
				table.insert(results, { class = class, marks = entry.marks, ribbon = ribbon.id, cup = cup })
			end
		end
		block.paid = block.week
	end
	if block.week ~= week then
		block.week = week
		block.entries = {}
	end
	return results
end

return Fair
