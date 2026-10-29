--!strict
-- The Order Board (Design/05 Orders & Economy). Delivering is paperwork, so it works from
-- anywhere on your plot; the truck at the dock drives out as the cosmetic payoff.
-- Each board slot is { order = Order } or { refreshAt = n } while it waits for a new card.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Net = require(Shared.Net)
local OrderConfig = require(Shared.Config.Orders)
local OrderGen = require(Shared.OrderGen)
local Speedup = require(Shared.Speedup)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TownService = require(script.Parent.TownService)
local Clock = require(script.Parent.Parent.Util.Clock)

local OrderService = {}

-- Grow the board to the level's slot count and fill slots whose wait is over.
-- Returns true when anything changed.
function OrderService.refreshBoard(player: Player): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local orders = data.orders
	local board = orders.board
	local changed = false
	local now = Clock.now()

	local wanted = OrderGen.slotsFor(data.level)
	while #board < wanted do
		table.insert(board, { refreshAt = 0 })
		changed = true
	end

	if orders.seed == 0 then
		orders.seed = (player.UserId % 100000) * 7919 + now % 100000 + 1
	end

	for _, slot in board do
		if slot.order == nil and (slot.refreshAt or 0) <= now then
			local existing = {}
			for _, other in board do
				if other.order then
					table.insert(existing, other.order)
				end
			end
			local order, seed = OrderGen.generate({
				level = data.level,
				seed = orders.seed,
				pool = OrderGen.makeablePool(data),
				existing = existing,
				now = now,
			})
			orders.seed = seed
			if order then
				slot.order = order
				slot.refreshAt = nil
				changed = true
			end
		end
	end
	return changed
end

local function slotFor(player: Player, slotIndex: any): { [string]: any }?
	local data = DataService.get(player)
	if data == nil or not NetService.check.int(slotIndex, 1, OrderConfig.maxSlots) then
		return nil
	end
	return data.orders.board[slotIndex]
end

function OrderService.fulfill(player: Player, slotIndex: any): (boolean, string?)
	local slot = slotFor(player, slotIndex)
	if slot == nil or slot.order == nil then
		return false
	end
	local order = slot.order
	if not InventoryService.remove(player, order.wants) then
		return false, "You don't have everything for that order yet"
	end
	local data = DataService.get(player) :: { [string]: any }
	data.orders.delivered += 1
	slot.order = nil
	slot.refreshAt = Clock.now() + Clock.duration(OrderConfig.truckReturnSeconds)
	EconomyService.add(player, "Coins", order.rewardCoins, "order")
	EconomyService.add(player, "XP", order.rewardXP, "order")
	NetService.popup(player, { kind = "Order", coins = order.rewardCoins, xp = order.rewardXP })
	PlotService.driveTruck(player, Clock.duration(OrderConfig.truckReturnSeconds))
	TownService.onOrderDelivered(player)
	return true
end

function OrderService.discard(player: Player, slotIndex: any): (boolean, string?)
	local slot = slotFor(player, slotIndex)
	if slot == nil or slot.order == nil then
		return false
	end
	slot.order = nil
	slot.refreshAt = Clock.now() + Clock.duration(OrderConfig.discardRefreshSeconds)
	return true
end

-- Gems bring a new card now instead of waiting out the refresh.
function OrderService.skipWait(player: Player, slotIndex: any): (boolean, string?)
	local slot = slotFor(player, slotIndex)
	local now = Clock.now()
	if slot == nil or slot.order ~= nil or (slot.refreshAt or 0) <= now then
		return false
	end
	if not EconomyService.spend(player, "Gems", Speedup.orderWait(slot.refreshAt - now), "speedup_order") then
		return false, "Not enough Gems"
	end
	slot.refreshAt = now
	OrderService.refreshBoard(player)
	return true
end

function OrderService.init()
	NetService.on(Net.Order_Fulfill, 2, 3, OrderService.fulfill)
	NetService.on(Net.Order_Discard, 1, 2, OrderService.discard)
	NetService.on(Net.Order_SkipWait, 1, 2, OrderService.skipWait)

	-- Refill cards whose wait ended, and add slots after a level up.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if OrderService.refreshBoard(player) then
					DataService.markDirty(player)
					NetService.pushState(player)
				end
			end
		end
	end)
end

return OrderService
