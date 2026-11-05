--!strict
-- Limited-time events (Config/Events, shared/Events; Design/08, Launch/20 §4). Keeps every
-- farm's data.event in step with the running event, runs the Fair Stand (crates of goods for
-- tokens), pays the prize track and the Event Shop, and turns leftover tokens into Coins when
-- an event ends. Other services add tokens for what they pay out (EventService.bonus). While
-- an event runs its Fair Stand stands in the Town Square.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtFairStand = require(Shared.Art.FairStand)
local Config = require(Shared.Config.Events)
local Events = require(Shared.Events)
local Items = require(Shared.Items)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local NoticeService = require(script.Parent.NoticeService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)
local OpenGround = require(script.Parent.Parent.Util.OpenGround)

local EventService = {}

local ready: { [Player]: boolean } = {}
local stand: { model: Model, key: string }? = nil

-- The Fair Stand's spot: open plaza ground, after the photo spots took theirs
local STAND_ANGLES = { 90, 70, 110, 50, 130, 30, 150, 10, 170, -10, 190 }
local STAND_RADII = { 27, 24, 30 }
local STAND_CLEARANCE = Vector3.new(10, 8, 10)
local STAND_CLEARANCE_AT = CFrame.new(0, 4.5, 0)

-- Studio's preview, shared with the clients (their Events module needs the same window)
local function preview(startsAt: number)
	Events.setPreview(startsAt)
	Workspace:SetAttribute("EventPreview", startsAt)
end

local function pay(player: Player, data: { [string]: any }, reward: Config.Reward, reason: string)
	if reward.coins then
		EconomyService.add(player, "Coins", reward.coins, reason)
	end
	if reward.gems then
		EconomyService.add(player, "Gems", reward.gems, reason)
	end
	if reward.xp then
		EconomyService.add(player, "XP", reward.xp, reason)
	end
	Events.give(data, reward)
end

local function tokenText(def: Config.EventDef, n: number): string
	return string.format("%s %d %s", def.tokenIcon, n, def.tokenName)
end

-- Bring the farm up to date with the running event. True if the save changed.
local function sync(player: Player): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local now = Clock.now()
	local started, ended = Events.sync(data, now, player.UserId)
	local changed = started ~= nil or ended ~= nil
	if ended then
		if ended.coins > 0 then
			EconomyService.add(player, "Coins", ended.coins, "event_end")
		end
		for _, reward in ended.rewards do
			pay(player, data, reward, "event_prize")
		end
		NetService.popup(player, {
			kind = "Event",
			step = "ended",
			name = ended.def.displayName,
			text = if ended.tokens > 0
				then string.format(
					"The %s is over. Your %s became %d Coins.",
					ended.def.displayName,
					tokenText(ended.def, ended.tokens),
					ended.coins
				)
				else string.format("The %s is over. Thanks for taking part!", ended.def.displayName),
			prizes = #ended.rewards,
		})
	end
	local def = Events.current(data, now)
	if started and def then
		local _, _, endsAt = Events.active(now)
		NetService.popup(player, {
			kind = "Event",
			step = "started",
			text = string.format(
				"The %s is on for %d days! Fill Fair Stand crates for %s. Tap the %s button.",
				def.displayName,
				math.max(1, math.floor((endsAt - now) / 86400 + 0.5)),
				def.tokenName,
				def.tokenIcon
			),
		})
	end
	if def and Events.refreshCrates(data, def, now) then
		changed = true
	end
	if changed then
		DataService.markDirty(player, true)
	end
	return changed
end

-- Add `amount` tokens of the running event (if this farm is in it). Returns what was added.
function EventService.addTokens(player: Player, amount: number, reason: string): number
	local data = DataService.get(player)
	if data == nil or amount <= 0 then
		return 0
	end
	local def = Events.current(data, Clock.now())
	if def == nil then
		return 0
	end
	local fresh = Events.add(data, def, amount)
	TelemetryService.economy(player, "EventTokens", "Source", amount, data.event.tokens, reason)
	DataService.markDirty(player)
	if fresh > 0 then
		NetService.popup(player, {
			kind = "Event",
			step = "prize",
			text = string.format(
				"%s prize%s ready to claim! Open the %s.",
				if fresh > 1 then tostring(fresh) .. " new" else "A new",
				if fresh > 1 then "s" else "",
				def.displayName
			),
		})
	end
	return amount
end

-- Tokens for something another service paid out ("questChest", "star", "rainbow", "goose")
function EventService.bonus(player: Player, key: string): number
	local data = DataService.get(player)
	local def = data and Events.current(data, Clock.now())
	local amount = if def then (def.bonus :: any)[key] else nil
	if type(amount) ~= "number" then
		return 0
	end
	return EventService.addTokens(player, amount, "event_" .. key)
end

---------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------

local function running(player: Player): ({ [string]: any }?, Config.EventDef?)
	sync(player)
	local data = DataService.get(player)
	if data == nil then
		return nil, nil
	end
	return data, Events.current(data, Clock.now())
end

function EventService.deliver(player: Player, index: any): (boolean, string?)
	local data, def = running(player)
	if data == nil or def == nil then
		return false, "No event is running right now"
	end
	local crate, reason = Events.crate(data, def, index)
	if crate == nil then
		return false, reason
	end
	local item, qty = crate.item :: string, crate.qty :: number
	local want = { [item] = qty }
	if not InventoryService.has(player, want) then
		local have = InventoryService.count(player, item)
		return false, string.format("This crate needs %d %s (you have %d)", qty, Items[item].displayName, have)
	end
	InventoryService.remove(player, want)
	Events.emptySlot(data, def, index, Clock.now())
	local xp = math.max(1, math.floor(Items[item].xpPerUnit * qty + 0.5))
	EconomyService.add(player, "XP", xp, "fair_crate")
	EventService.addTokens(player, crate.tokens or def.fairStand.tokens, "fair_crate")
	NetService.popup(player, {
		kind = "Event",
		step = "crate",
		text = string.format("Crate delivered!  +%s  +%d XP", tokenText(def, crate.tokens or 0), xp),
	})
	return true
end

-- Swap a crate you can't fill: the slot waits like a delivered one
function EventService.swap(player: Player, index: any): (boolean, string?)
	local data, def = running(player)
	if data == nil or def == nil then
		return false
	end
	local crate = Events.crate(data, def, index)
	if crate == nil then
		return false
	end
	Events.emptySlot(data, def, index, Clock.now())
	return true
end

function EventService.claim(player: Player): (boolean, string?)
	local data, def = running(player)
	if data == nil or def == nil then
		return false
	end
	local rewards = Events.claimAll(data, def)
	if #rewards == 0 then
		return false, string.format("Earn more %s for the next prize", def.tokenName)
	end
	local texts = {}
	for _, reward in rewards do
		pay(player, data, reward, "event_prize")
		table.insert(texts, Events.describe(reward))
	end
	TelemetryService.custom(player, "EventPrize", data.event.claimed, def.id)
	NetService.popup(player, {
		kind = "Event",
		step = "claim",
		text = string.format(
			"%s prize%s: %s",
			def.displayName,
			if #rewards > 1 then "s" else "",
			table.concat(texts, "; ")
		),
	})
	return true
end

function EventService.buy(player: Player, index: any): (boolean, string?)
	local data, def = running(player)
	if data == nil or def == nil then
		return false
	end
	local item, reason = Events.canBuy(data, def, index)
	if item == nil then
		return false, reason
	end
	Events.buy(data, def, index)
	TelemetryService.economy(player, "EventTokens", "Sink", item.price, data.event.tokens, "event_shop_" .. item.id)
	NetService.popup(player, {
		kind = "Event",
		step = "bought",
		text = string.format("%s is yours! Place it from Build > Decorations.", Config.keepsakes[item.id].displayName),
	})
	return true
end

-- Studio: "tokens" adds 100, "end" ends the preview now (leftovers turn into Coins), "start"
-- starts it again
function EventService.debug(player: Player, what: any): (boolean, string?)
	if not RunService:IsStudio() then
		return false
	end
	local now = Clock.now()
	if what == "tokens" then
		if EventService.addTokens(player, 100, "debug") == 0 then
			return false, "Dev: no event for this farm (level 4+, and the preview running)"
		end
		return true
	elseif what == "end" then
		preview(now - Config.events[Config.order[1]].previewSeconds - 1)
	elseif what == "start" then
		preview(now - 60)
	else
		return false
	end
	for _, other in Players:GetPlayers() do
		if sync(other) then
			NetService.pushState(other)
		end
	end
	return true
end

---------------------------------------------------------------------------------------------
-- The Fair Stand in the Town Square
---------------------------------------------------------------------------------------------

local function updateStand(now: number)
	local def, startsAt = Events.active(now)
	local key = if def then def.id .. ":" .. startsAt else ""
	if stand and stand.key == key then
		return
	end
	if stand then
		stand.model:Destroy()
		stand = nil
	end
	if def == nil then
		return
	end
	local cf = OpenGround.find(STAND_ANGLES, STAND_RADII, STAND_CLEARANCE, STAND_CLEARANCE_AT)
	if cf == nil then
		warn("[EventService] no open ground on the plaza for the Fair Stand")
		return
	end
	local built = ArtFairStand.build(PlotService.square.model, cf, def.displayName)
	for _, p in built.model:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("Interact", "FairStand")
		end
	end
	stand = { model = built.model, key = key }
	NoticeService.post(string.format("The %s is on: fill Fair Stand crates for %s", def.displayName, def.tokenName))
end

function EventService.init()
	if RunService:IsStudio() then
		preview(Clock.now() - 60) -- Studio previews the first event
	end
	NetService.on(Net.Event_Deliver, 3, 5, EventService.deliver)
	NetService.on(Net.Event_Swap, 2, 3, EventService.swap)
	NetService.on(Net.Event_Claim, 2, 3, EventService.claim)
	NetService.on(Net.Event_Buy, 2, 3, EventService.buy)
	NetService.on(Net.Debug_Event, 1, 2, EventService.debug)

	local function watch(player: Player)
		NetService.whenReady(player, function()
			ready[player] = true
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
	end)

	task.spawn(function()
		while true do
			local now = Clock.now()
			updateStand(now)
			for player in ready do
				if player.Parent and sync(player) then
					NetService.pushState(player)
				end
			end
			task.wait(5)
		end
	end)
end

return EventService
