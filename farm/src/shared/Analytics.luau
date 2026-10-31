--!strict
-- Pure helpers for the analytics wrapper (Launch/19 Analytics & Metrics §4): custom-field
-- values, economy SKUs and the per-player economy buffer that turns many small events into
-- one summed event per (currency, flow, SKU) every couple of minutes.

local Animals = require("./Config/Animals")
local Crops = require("./Config/Crops")
local Factories = require("./Config/Factories")
local Town = require("./Config/Town")

local Analytics = {}

local HOUR = 3600
local DAY = 86400

Analytics.flushSeconds = 120 -- economy buffer flush (rate limit is per experience)
Analytics.maxGapMinutes = 4320 -- SessionStart value cap (3 days)
Analytics.throttleSeconds = 300 -- repeatable friction events (StorageFull) per player

-- Field 1: the same level bands as Design/05 Orders & Economy
function Analytics.levelBand(level: number): string
	local bands = { { 4, "L01-04" }, { 9, "L05-09" }, { 14, "L10-14" }, { 19, "L15-19" }, { 24, "L20-24" } }
	for _, band in bands do
		if level <= band[1] then
			return band[2]
		end
	end
	return "L25-30"
end

-- Field 3: account age plus payer flag, e.g. "early_payer". Never ids or names.
function Analytics.cohort(data: { [string]: any }, now: number): string
	local created = data.meta.createdAt
	local days = if created and created > 0 then math.max(0, now - created) / DAY else 0
	local tenure = if days < 2 then "new" elseif days < 8 then "early" elseif days < 31 then "core" else "veteran"
	local payer = next(data.purchases.receipts) ~= nil or next(data.purchases.passes) ~= nil
	return tenure .. if payer then "_payer" else "_nonpayer"
end

-- SessionStart's context: how long the player was away
function Analytics.gapBucket(seconds: number): string
	if seconds < HOUR then
		return "<1h"
	elseif seconds < 4 * HOUR then
		return "1-4h"
	elseif seconds < 12 * HOUR then
		return "4-12h"
	elseif seconds < DAY then
		return "12-24h"
	elseif seconds < 3 * DAY then
		return "1-3d"
	end
	return "3d+"
end

local function buildSku(id: string): string
	if Factories[id] then
		return "BuildFactory"
	elseif Animals.pens[id] then
		return "BuildPen"
	elseif Town.community[id] then
		return "BuildCommunity"
	end
	return "BuildHouse"
end

local function skipSku(target: string): string
	if Crops[target] or target:sub(1, 4) == "all_" then
		return "SkipCrop"
	elseif Factories[target] then
		return "SkipFactory"
	elseif Animals.pens[target] then
		return "SkipAnimal"
	elseif target == "order" then
		return "SkipCooldown"
	end
	return "SkipBuild"
end

-- Plain prefixes: the reason's first word -> SKU
local PREFIX_SKU: { [string]: string } = {
	seed = "Seeds",
	harvest = "Harvest",
	collect = "Collect",
	order = "OrderBoard",
	sell = "DirectSell",
	prize = "PrizeSale",
	decor = "BuildDecor",
	expand = "Expansion",
	field = "FieldUnlock",
	animal = "BuyAnimal",
	material = "BuyMissingItem",
	slot = "GemSlot",
	daily = "DailyLogin",
	tutorial = "Tutorial",
	croppop = "CropPop",
	drop = "HarvestDrop",
	quest = "DailyQuest",
	questchest = "QuestChest",
	cart = "SeedCart",
	market = "Market", -- stall buys and sales, and the passing trader
	debug = "DevGrant", -- Studio only; never reaches live analytics
}

-- An EconomyService reason ("seed_wheat", "speedup_bakery", "robux_Pouch") -> the SKU
-- (a fixed list well under the 100-SKU limit) and the transaction type name.
function Analytics.sku(reason: string, currency: string): (string, string)
	local head, rest = reason:match("^([%a]+)_?(.*)$")
	head = (head or ""):lower()
	rest = rest or ""
	if head == "robux" then
		if rest == "revert" then
			return "IapRevert", "IAP"
		end
		return if rest == "StarterPack" then "StarterPack" else "GemPack_" .. rest, "IAP"
	elseif head == "speedup" then
		return skipSku(rest), "ContextualPurchase"
	elseif head == "build" then
		return buildSku(rest), "Gameplay"
	elseif head == "levelup" then
		return if currency == "Gems" then "LevelUpGems" else "LevelUp", "Gameplay"
	elseif head == "decor" and rest == "sell" then
		return "DecorRefund", "Gameplay"
	end
	local sku = PREFIX_SKU[head] or "Other"
	if sku == "Tutorial" then
		return sku, "Onboarding"
	elseif sku == "DailyLogin" then
		return sku, "TimedReward"
	elseif currency == "Gems" and (sku == "BuyMissingItem" or sku == "GemSlot" or sku == "CropPop") then
		return sku, "ContextualPurchase"
	end
	return sku, "Gameplay"
end

-- Gem skips get their own custom event (GemSkipUsed) with the skip kind as context
function Analytics.isSkip(sku: string): boolean
	return sku:sub(1, 4) == "Skip"
end

---------------------------------------------------------------------------------------------
-- Economy buffer: one entry per (currency, flow, sku, transaction type, field 2)
---------------------------------------------------------------------------------------------

export type EconomyEntry = {
	currency: string,
	flow: string, -- "Source" | "Sink"
	sku: string,
	transactionType: string,
	context: string?, -- custom field 2 (tool type for Tools)
	amount: number,
}

export type Buffer = { entries: { [string]: EconomyEntry }, order: { string } }

function Analytics.newBuffer(): Buffer
	return { entries = {}, order = {} }
end

function Analytics.add(
	buffer: Buffer,
	currency: string,
	flow: string,
	sku: string,
	transactionType: string,
	amount: number,
	context: string?
)
	local key = table.concat({ currency, flow, sku, transactionType, context or "" }, "|")
	local entry = buffer.entries[key]
	if entry then
		entry.amount += amount
		return
	end
	buffer.entries[key] = {
		currency = currency,
		flow = flow,
		sku = sku,
		transactionType = transactionType,
		context = context,
		amount = amount,
	}
	table.insert(buffer.order, key)
end

-- Everything buffered, oldest key first; the buffer is left empty
function Analytics.drain(buffer: Buffer): { EconomyEntry }
	local out = {}
	for _, key in buffer.order do
		table.insert(out, buffer.entries[key])
	end
	buffer.entries = {}
	buffer.order = {}
	return out
end

return Analytics
