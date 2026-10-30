--!strict
-- The Tinker's Guild's rules (Config/Guild): building it, what each factory's next upgrade
-- costs and offers, and what the upgrades do. A factory's upgrades live in
-- data.buildingLevels[factoryId] as counts per stat; its level is 1 + their sum.

local Config = require("./Config/Guild")
local Factories = require("./Config/Factories")
local Items = require("./Items")
local Recipes = require("./Config/Recipes")
local TownRules = require("./TownRules")

local Guild = {}

export type Stat = "time" | "shelves" | "coins" | "xp"
export type Levels = { time: number, shelves: number, coins: number, xp: number }

Guild.STATS = table.freeze({ "time", "shelves", "coins", "xp" }) :: { Stat }
Guild.STAT_NAMES = table.freeze({ time = "Time", shelves = "Shelves", coins = "Coins", xp = "XP" })

-- The cost table a factory upgrades on, or nil when the Guild can't upgrade it
function Guild.tableId(factoryId: string): string?
	local id = Config.tableOf[factoryId] or factoryId
	return if Config.costs[id] then id else nil
end

function Guild.levels(data: { [string]: any }, factoryId: string): Levels
	local entry = (data.buildingLevels or {})[factoryId]
	if type(entry) ~= "table" then
		entry = {}
	end
	return {
		time = entry.time or 0,
		shelves = entry.shelves or 0,
		coins = entry.coins or 0,
		xp = entry.xp or 0,
	}
end

function Guild.level(levels: Levels): number
	return 1 + levels.time + levels.shelves + levels.coins + levels.xp
end

function Guild.maxLevel(factoryId: string): number
	local id = Guild.tableId(factoryId)
	return if id then #Config.costs[id] + 1 else 1
end

-- Bars for the next upgrade, or nil at the top level
function Guild.nextCost(factoryId: string, level: number): { [string]: number }?
	local id = Guild.tableId(factoryId)
	local row = id and Config.costs[id][level]
	if row == nil then
		return nil
	end
	local cost = {}
	for i, bar in Config.bars do
		if row[i] > 0 then
			cost[bar] = row[i]
		end
	end
	return cost
end

-- The stats the next upgrade can raise (pick one): time and shelves on their fixed levels, else
-- Coins or XP. A Feed Mill has no Coins or XP, so its other levels are all time.
function Guild.choices(factoryId: string, levels: Levels): { Stat }
	local id = Guild.tableId(factoryId)
	local level = Guild.level(levels)
	if id == nil or level >= Guild.maxLevel(factoryId) then
		return {}
	end
	local target = level + 1
	if table.find(Config.shelfLevels, target) then
		return { "shelves" }
	elseif id == "FeedMill" or table.find(Config.timeLevels, target) then
		return { "time" }
	end
	local out: { Stat } = {}
	local cap = math.round(Config.maxBonus / Config.step)
	if levels.coins < cap then
		table.insert(out, "coins")
	end
	if levels.xp < cap then
		table.insert(out, "xp")
	end
	return out
end

-- The Guild stands once its build timer has run out
function Guild.isBuilt(data: { [string]: any }, now: number): boolean
	local readyAt = data.guild and data.guild.readyAt
	return readyAt ~= nil and now >= readyAt
end

-- Can the Guild be built now? (Bars are checked by the caller, which holds the Barn)
function Guild.canBuild(data: { [string]: any }, now: number): (boolean, string?)
	if data.guild.readyAt ~= nil then
		return false
	elseif data.level < Config.unlockLevel then
		return false, string.format("The Tinker's Guild opens at level %d", Config.unlockLevel)
	elseif not TownRules.landDone(data, Config.land, now) then
		return false, "The Tinker's Guild stands in the East Meadow. Clear that land first."
	end
	local population = TownRules.population(data, now)
	if population < Config.population then
		return false,
			string.format(
				"The Tinker's Guild needs Population %d (you have %d). Build Houses.",
				Config.population,
				population
			)
	end
	return true
end

-- Can `factoryId` take an upgrade to `stat` now? Returns its Bar cost when it can.
function Guild.canUpgrade(
	data: { [string]: any },
	factoryId: string,
	stat: string,
	now: number
): ({ [string]: number }?, string?)
	local factory = data.factories[factoryId]
	if Guild.tableId(factoryId) == nil or factory == nil then
		return nil
	elseif not Guild.isBuilt(data, now) then
		return nil, "Build the Tinker's Guild first"
	elseif not factory.built or (factory.constructionReadyAt ~= nil and now < factory.constructionReadyAt) then
		return nil, "Build the " .. Factories[factoryId].displayName .. " first"
	end
	local levels = Guild.levels(data, factoryId)
	if not table.find(Guild.choices(factoryId, levels), stat :: Stat) then
		return nil, if Guild.level(levels) >= Guild.maxLevel(factoryId) then "Already at the top level" else nil
	end
	return Guild.nextCost(factoryId, Guild.level(levels))
end

-- Raises `stat` by one (check canUpgrade and take the Bars first)
function Guild.upgrade(data: { [string]: any }, factoryId: string, stat: Stat)
	local levels = Guild.levels(data, factoryId)
	levels[stat] += 1
	data.buildingLevels[factoryId] = levels
end

-- Production time multiplier (time upgrades cut 5% each)
function Guild.timeMult(data: { [string]: any }, factoryId: string): number
	return math.max(0, 1 - Config.step * Guild.levels(data, factoryId).time)
end

function Guild.trayCapacity(data: { [string]: any }, factoryId: string): number
	return Factories[factoryId].trayCapacity + Guild.levels(data, factoryId).shelves
end

-- The Coins and XP an order's goods earn on top of its reward from their factories' upgrades.
-- Each line gets its share of the reward (by sell value for Coins, by XP for XP).
function Guild.orderBonus(
	data: { [string]: any },
	wants: { [string]: number },
	rewardCoins: number,
	rewardXP: number
): (number, number)
	local value, xp = 0, 0
	for item, qty in wants do
		local def = Items[item]
		if def then
			value += def.sellPrice * qty
			xp += def.xpPerUnit * qty
		end
	end
	local coins, bonusXp = 0, 0
	for item, qty in wants do
		local recipe, def = Recipes[item], Items[item]
		if recipe and def then
			local levels = Guild.levels(data, recipe.factory)
			if value > 0 then
				coins += rewardCoins * (def.sellPrice * qty / value) * Config.step * levels.coins
			end
			if xp > 0 then
				bonusXp += rewardXP * (def.xpPerUnit * qty / xp) * Config.step * levels.xp
			end
		end
	end
	return math.floor(coins + 0.5), math.floor(bonusXp + 0.5)
end

return Guild
