--!strict
-- Order Board generation (pure, seeded). Rules from Design/05 Orders & Economy:
-- item pool = unlocked items (recent unlocks weighted up), line count and target production
-- time by level band, a soft guarantee that one card can be filled from crops alone,
-- no two cards sharing a top item where avoidable, and the first-pass reward formula.

local Animals = require("./Config/Animals")
local Balance = require("./Config/Balance")
local Harbor = require("./Harbor")
local Items = require("./Items")
local OrderConfig = require("./Config/Orders")
local Recipes = require("./Config/Recipes")
local Rng = require("./Rng")

local OrderGen = {}

export type Order = {
	id: string,
	wants: { [string]: number },
	top: string, -- highest-value line, used to avoid duplicate cards
	rewardCoins: number,
	rewardXP: number,
}

export type Context = {
	level: number,
	seed: number,
	pool: { string }, -- item ids the player can make right now
	existing: { Order }, -- other active cards on the board
	now: number,
}

local function bandFor(level: number)
	local chosen = OrderConfig.bands[1]
	for _, band in OrderConfig.bands do
		if level >= band.minLevel then
			chosen = band
		end
	end
	return chosen
end

function OrderGen.slotsFor(level: number): number
	local slots = 0
	for _, row in OrderConfig.slotsByLevel do
		if level >= row.level then
			slots = row.slots
		end
	end
	return math.min(slots, OrderConfig.maxSlots)
end

-- Items a farm can make right now: its crops, the products of its pens (when it can get their
-- feed), and the recipes of its built factories whose inputs it can make too. Feed never goes
-- on an order card.
function OrderGen.makeablePool(data: { [string]: any }): { string }
	local can: { [string]: boolean } = {}
	for _, id in Balance.enabledCrops do
		can[id] = true
	end
	-- Far Isle goods, once a Sailboat has brought some back from their isle
	for _, id in Harbor.visitedGoods(data) do
		can[id] = true
	end
	local function addRecipes()
		local changed = true
		while changed do
			changed = false
			for id, recipe in Recipes do
				local factory = data.factories[recipe.factory]
				if not can[id] and factory and factory.built then
					local all = true
					for input in recipe.inputs do
						if not can[input] then
							all = false
							break
						end
					end
					if all then
						can[id] = true
						changed = true
					end
				end
			end
		end
	end
	-- Feed first (crops only), then animal products, then everything made from them.
	addRecipes()
	for id, pen in data.pens or {} do
		local def = Animals.pens[id]
		if def and pen.built and (can[def.feed] or (data.inventory.items[def.feed] or 0) > 0) then
			can[def.product] = true
		end
	end
	addRecipes()

	local pool = {}
	for id in can do
		local item = Items[id]
		if item and not item.isFeed then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	return pool
end

function OrderGen.isCropsOnly(order: Order): boolean
	for item in order.wants do
		local def = Items[item]
		if def == nil or def.kind ~= "Crop" then
			return false
		end
	end
	return true
end

function OrderGen.rewards(wants: { [string]: number }, level: number): (number, number)
	local value, xp, lines = 0, 0, 0
	for item, qty in wants do
		local def = Items[item]
		value += def.sellPrice * qty
		xp += def.xpPerUnit * qty
		lines += 1
	end
	local bonus = OrderConfig.lineBonus[math.clamp(lines, 1, #OrderConfig.lineBonus)]
	local coinMult = OrderConfig.coinMultBase + OrderConfig.coinMultPerLevel * level
	local coins = math.max(1, math.floor(value * coinMult * bonus + 0.5))
	local rewardXP = math.max(1, math.floor(xp * OrderConfig.xpMult + 0.5))
	return coins, rewardXP
end

local function weightedPick(seed: number, candidates: { string }, level: number): (string, number)
	local weights = {}
	local total = 0
	for i, id in candidates do
		local w = 1
		if level - Items[id].unlockLevel < OrderConfig.newItemLevels and Items[id].unlockLevel > 1 then
			w += OrderConfig.newItemWeightBonus
		end
		weights[i] = w
		total += w
	end
	local r
	r, seed = Rng.next(seed)
	local target = r * total
	for i, id in candidates do
		target -= weights[i]
		if target < 0 then
			return id, seed
		end
	end
	return candidates[#candidates], seed
end

function OrderGen.generate(ctx: Context): (Order?, number)
	local seed = Rng.normalize(ctx.seed)
	local level = ctx.level

	-- Soft guarantee: if no other card is crops-only, this one must be.
	local needCropsOnly = true
	local existingTops: { [string]: boolean } = {}
	for _, order in ctx.existing do
		existingTops[order.top] = true
		if OrderGen.isCropsOnly(order) then
			needCropsOnly = false
		end
	end

	local pool: { string } = {}
	for _, id in ctx.pool do
		local def = Items[id]
		if def and def.unlockLevel <= level and (not needCropsOnly or def.kind == "Crop") then
			table.insert(pool, id)
		end
	end
	table.sort(pool) -- deterministic order regardless of caller
	if #pool == 0 then
		return nil, seed
	end

	local band = bandFor(level)
	local lineCount
	lineCount, seed = Rng.int(seed, band.minLines, math.min(band.maxLines, #pool))
	local targetSeconds
	targetSeconds, seed = Rng.int(seed, band.minSeconds, band.maxSeconds)

	-- Prefer a first line whose item is not already another card's top item.
	local fresh: { string } = {}
	for _, id in pool do
		if not existingTops[id] then
			table.insert(fresh, id)
		end
	end

	local wants: { [string]: number } = {}
	local remaining = table.clone(pool)
	for line = 1, lineCount do
		local candidates = if line == 1 and #fresh > 0 then fresh else remaining
		local id
		id, seed = weightedPick(seed, candidates, level)
		local idx = table.find(remaining, id)
		if idx then
			table.remove(remaining, idx)
		end

		local def = Items[id]
		local maxQty = if def.kind == "Crop" then OrderConfig.maxCropQty else OrderConfig.maxProductQty
		local qty = math.clamp(math.floor(targetSeconds / lineCount / def.unitSeconds + 0.5), 1, maxQty)
		wants[id] = qty
	end

	local top, topValue = "", -1
	for id, qty in wants do
		local value = Items[id].sellPrice * qty
		if value > topValue or (value == topValue and id < top) then
			top, topValue = id, value
		end
	end

	local coins, xp = OrderGen.rewards(wants, level)
	local order: Order = {
		id = string.format("ob_%d_%d", ctx.now, seed % 100000),
		wants = wants,
		top = top,
		rewardCoins = coins,
		rewardXP = xp,
	}
	return order, seed
end

return OrderGen
