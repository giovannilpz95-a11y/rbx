--!strict
-- Limited-time event rules (Config/Events), pure for the server, the client and the Lune tests:
-- which event is running, a farm's progress on it (data.event), the Fair Stand's crates, the
-- prize track, the Event Shop, and turning leftover tokens into Coins when it ends.
--
-- data.event = { id, run, tokens, earned, claimed, bought, crates, seed }: `run` is the
-- event's startsAt (an event can run again next year), `earned` climbs the prize track and is
-- never spent, `tokens` is what's left to spend in the Event Shop.

local Blimp = require("./Blimp")
local Config = require("./Config/Events")
local Items = require("./Items")
local Rng = require("./Rng")
local Tools = require("./Config/Tools")

local Events = {}

export type Crate = { item: string?, qty: number?, tokens: number?, waitUntil: number? }

-- Studio previews the first event from a start time (EventService sets it at boot)
local preview: { startsAt: number, id: string }? = nil

function Events.setPreview(startsAt: number?, id: string?)
	if startsAt == nil then
		preview = nil
	else
		preview = { startsAt = startsAt, id = id or Config.order[1] }
	end
end

-- An event's window: its schedule, or the Studio preview's
function Events.window(def: Config.EventDef): (number, number)
	if preview and preview.id == def.id then
		return preview.startsAt, preview.startsAt + def.previewSeconds
	end
	return def.startsAt, def.endsAt
end

-- The event running at `now` (nil between events), with its window
function Events.active(now: number): (Config.EventDef?, number, number)
	for _, id in Config.order do
		local def = Config.events[id]
		local startsAt, endsAt = Events.window(def)
		if startsAt > 0 and now >= startsAt and now < endsAt then
			return def, startsAt, endsAt
		end
	end
	return nil, 0, 0
end

function Events.blank(): { [string]: any }
	return { id = "", run = 0, tokens = 0, earned = 0, claimed = 0, bought = {}, crates = {}, seed = 0 }
end

-- The event this farm is taking part in now: running, and the farm is at its level
function Events.current(data: { [string]: any }, now: number): Config.EventDef?
	local def, startsAt = Events.active(now)
	if def == nil or data.level < def.minLevel then
		return nil
	end
	local block = data.event
	if block.id ~= def.id or block.run ~= startsAt then
		return nil
	end
	return def
end

export type Ended = { def: Config.EventDef, tokens: number, coins: number, rewards: { Config.Reward } }

-- Bring data.event up to date. Returns "started" when the farm joined the running event, or
-- an Ended summary when the event it was in is over (or a new one replaced it): its leftover
-- tokens become Coins and any prize reached but not claimed is handed over. The caller pays
-- Ended's coins and rewards.
function Events.sync(data: { [string]: any }, now: number, userId: number): (string?, Ended?)
	local block = data.event
	local def, startsAt = Events.active(now)
	local ended: Ended? = nil
	if block.id ~= "" and (def == nil or block.id ~= def.id or block.run ~= startsAt) then
		local old = Config.events[block.id]
		if old then
			local rewards = {}
			for i = block.claimed + 1, Events.reached(old, block.earned) do
				table.insert(rewards, old.milestones[i].reward)
			end
			ended = {
				def = old,
				tokens = block.tokens,
				coins = block.tokens * old.tokenToCoins,
				rewards = rewards,
			}
		end
		data.event = Events.blank()
		block = data.event
	end
	if def and block.id == "" and data.level >= def.minLevel then
		block.id = def.id
		block.run = startsAt
		block.seed = Rng.normalize(startsAt + userId % 1000003)
		return "started", ended
	end
	return nil, ended
end

-- "6d 4h" for days, else the usual countdown
function Events.timeLeft(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 86400 then
		return string.format("%dd %dh", seconds // 86400, (seconds % 86400) // 3600)
	end
	local h, m = seconds // 3600, (seconds % 3600) // 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm %02ds", m, seconds % 60)
end

---------------------------------------------------------------------------------------------
-- The prize track
---------------------------------------------------------------------------------------------

-- How many prizes `earned` tokens have reached
function Events.reached(def: Config.EventDef, earned: number): number
	local n = 0
	for i, m in def.milestones do
		if earned >= m.tokens then
			n = i
		end
	end
	return n
end

-- Add earned tokens. Returns how many new prizes that reached.
function Events.add(data: { [string]: any }, def: Config.EventDef, amount: number): number
	local block = data.event
	local before = Events.reached(def, block.earned)
	block.tokens += amount
	block.earned += amount
	return Events.reached(def, block.earned) - before
end

-- Every prize reached and not claimed yet, claimed now. The caller pays them.
function Events.claimAll(data: { [string]: any }, def: Config.EventDef): { Config.Reward }
	local block = data.event
	local out = {}
	local reached = Events.reached(def, block.earned)
	for i = block.claimed + 1, reached do
		table.insert(out, def.milestones[i].reward)
	end
	block.claimed = math.max(block.claimed, reached)
	return out
end

-- The parts of a reward that live in the save (items, tools, Heirloom Seeds, keepsakes).
-- Coins, Gems and XP go through the economy so level-ups and analytics see them.
function Events.give(data: { [string]: any }, reward: Config.Reward)
	for item, qty in reward.items or {} do
		if Tools.tools[item] then
			data.toolShed.items[item] = (data.toolShed.items[item] or 0) + qty
		else
			data.inventory.items[item] = (data.inventory.items[item] or 0) + qty
		end
	end
	if reward.heirloomSeeds then
		data.heirloomSeeds += reward.heirloomSeeds
	end
	if reward.keepsake then
		data.trophies[reward.keepsake] = (data.trophies[reward.keepsake] or 0) + 1
	end
end

-- A reward in words, for the panel and toasts
function Events.describe(reward: Config.Reward): string
	local parts = {}
	if reward.coins then
		table.insert(parts, string.format("%d Coins", reward.coins))
	end
	if reward.gems then
		table.insert(parts, string.format("%d Gems", reward.gems))
	end
	if reward.xp then
		table.insert(parts, string.format("%d XP", reward.xp))
	end
	if reward.heirloomSeeds then
		table.insert(
			parts,
			string.format("%d Heirloom Seed%s", reward.heirloomSeeds, if reward.heirloomSeeds > 1 then "s" else "")
		)
	end
	local items = {}
	for item, qty in reward.items or {} do
		local tool = Tools.tools[item]
		local name = if tool
			then (if qty > 1 then tool.plural else tool.displayName)
			elseif Items[item] then Items[item].displayName
			else item
		table.insert(items, string.format("%d %s", qty, name))
	end
	table.sort(items)
	for _, text in items do
		table.insert(parts, text)
	end
	if reward.keepsake then
		local k = Config.keepsakes[reward.keepsake]
		table.insert(parts, if k then k.displayName else reward.keepsake)
	end
	return table.concat(parts, ", ")
end

---------------------------------------------------------------------------------------------
-- The Fair Stand
---------------------------------------------------------------------------------------------

function Events.crateQty(def: Config.EventDef, item: string, level: number): number
	local low = Blimp.qtyRange(item, level)
	return math.max(def.fairStand.minQty, math.ceil(low * def.fairStand.qtyShare))
end

-- Fill empty slots and slots whose wait is over with new crates of goods this farm can make
-- (the Cargo Blimp's list). Returns true if anything changed.
function Events.refreshCrates(data: { [string]: any }, def: Config.EventDef, now: number): boolean
	local block = data.event
	local pool = Blimp.pool(data)
	if #pool == 0 then
		return false
	end
	local changed = false
	for i = 1, def.fairStand.slots do
		local key = tostring(i)
		local crate = block.crates[key]
		if crate == nil or (crate.waitUntil ~= nil and now >= crate.waitUntil) then
			-- Prefer a good no other crate is asking for
			local taken = {}
			for k, other in block.crates do
				if k ~= key and other.item then
					taken[other.item] = true
				end
			end
			local choices = {}
			for _, id in pool do
				if not taken[id] then
					table.insert(choices, id)
				end
			end
			if #choices == 0 then
				choices = pool
			end
			local pick
			pick, block.seed = Rng.int(block.seed, 1, #choices)
			local item = choices[pick]
			block.crates[key] =
				{ item = item, qty = Events.crateQty(def, item, data.level), tokens = def.fairStand.tokens }
			changed = true
		end
	end
	return changed
end

-- The crate in slot `index`, ready to deliver, or why not
function Events.crate(data: { [string]: any }, def: Config.EventDef, index: any): (Crate?, string?)
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > def.fairStand.slots then
		return nil
	end
	local crate = data.event.crates[tostring(index)]
	if crate == nil or crate.item == nil then
		return nil, "A new crate is on its way"
	end
	return crate
end

-- Mark slot `index` delivered (or swapped): a new crate after the wait
function Events.emptySlot(data: { [string]: any }, def: Config.EventDef, index: number, now: number)
	data.event.crates[tostring(index)] = { waitUntil = now + def.fairStand.refillSeconds }
end

---------------------------------------------------------------------------------------------
-- The Event Shop
---------------------------------------------------------------------------------------------

function Events.left(data: { [string]: any }, def: Config.EventDef, index: number): number
	local item = def.shop[index]
	return item.stock - (data.event.bought[tostring(index)] or 0)
end

function Events.canBuy(data: { [string]: any }, def: Config.EventDef, index: any): (Config.ShopItem?, string?)
	if type(index) ~= "number" or index % 1 ~= 0 or def.shop[index] == nil then
		return nil
	end
	local item = def.shop[index]
	if Events.left(data, def, index) <= 0 then
		return nil, "Sold out for this event"
	end
	if data.event.tokens < item.price then
		return nil, string.format("%s costs %d %s", Config.keepsakes[item.id].displayName, item.price, def.tokenName)
	end
	return item
end

function Events.buy(data: { [string]: any }, def: Config.EventDef, index: number)
	local item = def.shop[index]
	local block = data.event
	block.tokens -= item.price
	block.bought[tostring(index)] = (block.bought[tostring(index)] or 0) + 1
	data.trophies[item.id] = (data.trophies[item.id] or 0) + 1
end

return Events
