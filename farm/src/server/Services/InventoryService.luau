--!strict
-- The Barn: one shared store for crops and goods with a capacity limit.
-- Selling from the Barn is the worst rate on purpose (Design/05 Orders & Economy).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Items = require(Shared.Items)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)

local InventoryService = {}

function InventoryService.used(data: { [string]: any }): number
	local total = 0
	for _, qty in data.inventory.items do
		total += qty
	end
	return total
end

function InventoryService.space(player: Player): number
	local data = DataService.get(player)
	if data == nil then
		return 0
	end
	return math.max(0, data.inventory.barnCapacity - InventoryService.used(data))
end

function InventoryService.count(player: Player, item: string): number
	local data = DataService.get(player)
	return if data then data.inventory.items[item] or 0 else 0
end

function InventoryService.has(player: Player, wants: { [string]: number }): boolean
	for item, qty in wants do
		if InventoryService.count(player, item) < qty then
			return false
		end
	end
	return true
end

-- Adds all or nothing. Returns false when the Barn lacks room.
function InventoryService.add(player: Player, items: { [string]: number }): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local total = 0
	for _, qty in items do
		total += qty
	end
	if total > InventoryService.space(player) then
		return false
	end
	for item, qty in items do
		data.inventory.items[item] = (data.inventory.items[item] or 0) + qty
	end
	DataService.markDirty(player)
	return true
end

-- Removes all or nothing. Returns false when something is missing.
function InventoryService.remove(player: Player, items: { [string]: number }): boolean
	local data = DataService.get(player)
	if data == nil or not InventoryService.has(player, items) then
		return false
	end
	for item, qty in items do
		local left = data.inventory.items[item] - qty
		data.inventory.items[item] = if left > 0 then left else nil
	end
	DataService.markDirty(player)
	return true
end

function InventoryService.sell(player: Player, itemId: any, qty: any): (boolean, string?)
	if not NetService.check.id(itemId) or not NetService.check.int(qty, 1, 9999) then
		return false
	end
	local item = Items[itemId]
	if item == nil or item.sellPrice <= 0 then
		return false
	end
	if not InventoryService.remove(player, { [itemId] = qty }) then
		return false, "You don't have that many"
	end
	EconomyService.add(player, "Coins", item.sellPrice * qty, "sell_" .. itemId)
	return true
end

function InventoryService.init()
	NetService.on(Net.Barn_Sell, 4, 6, InventoryService.sell)
end

return InventoryService
