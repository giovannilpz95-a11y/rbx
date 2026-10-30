--!strict
-- "Buy what's missing" (UI Reference & Gaps G3; prices in shared/Missing): Gems pay for the
-- items a recipe, an order, a Community Building or a Barn upgrade is short of, and the
-- action goes ahead in the same step. Nothing is charged unless the action succeeds.
--
--   Missing_Buy("Recipe", factoryId, recipeId) | ("Order", slotIndex)
--             | ("Community", buildingId) | ("Barn")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local BarnRules = require(Shared.BarnRules)
local Missing = require(Shared.Missing)
local Net = require(Shared.Net)
local OrderConfig = require(Shared.Config.Orders)
local Profile = require(Shared.Profile)
local Recipes = require(Shared.Config.Recipes)
local Town = require(Shared.Config.Town)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local FactoryService = require(script.Parent.FactoryService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local OrderService = require(script.Parent.OrderService)
local TownService = require(script.Parent.TownService)

local MissingService = {}

-- What the action needs, and the action itself, for a request; nil when the request is junk.
local function resolve(
	player: Player,
	data: { [string]: any },
	context: any,
	a: any,
	b: any
): ({ [string]: number }?, (() -> (boolean, string?))?)
	if context == "Recipe" then
		if not NetService.check.id(a) or not NetService.check.id(b) then
			return nil, nil
		end
		local recipe = Recipes[b]
		if recipe == nil or recipe.factory ~= a or data.factories[a] == nil then
			return nil, nil
		end
		return recipe.inputs, function()
			return FactoryService.queue(player, a, b)
		end
	elseif context == "Order" then
		if not NetService.check.int(a, 1, OrderConfig.maxSlots) then
			return nil, nil
		end
		local slot = data.orders.board[a]
		if slot == nil or slot.order == nil then
			return nil, nil
		end
		return slot.order.wants, function()
			return OrderService.fulfill(player, a)
		end
	elseif context == "Community" then
		if not NetService.check.id(a) or Town.community[a] == nil then
			return nil, nil
		end
		return Town.community[a].materials, function()
			return TownService.buildCommunity(player, a)
		end
	elseif context == "Barn" then
		return BarnRules.upgradeCost(data.inventory.upgrades + 1),
			function()
				return InventoryService.upgrade(player)
			end
	end
	return nil, nil
end

function MissingService.buy(player: Player, context: any, a: any, b: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local needs, action = resolve(player, data, context, a, b)
	if needs == nil or action == nil then
		return false
	end
	local lines = Missing.list(needs, function(item)
		return InventoryService.count(player, item)
	end)
	local price = Missing.price(lines)
	if price == nil then
		return false
	end
	if #lines == 0 then
		return action() -- nothing missing after all (the Barn filled up meanwhile)
	end
	if data.currencies.Gems < price then
		return false, string.format("That needs %d Gems", price)
	end
	-- Put the missing items in (they're used straight away, so Barn space doesn't matter),
	-- try the action, and only charge if it worked
	local before = Profile.deepCopy(data.inventory.items)
	for _, line in lines do
		data.inventory.items[line.item] = (data.inventory.items[line.item] or 0) + line.qty
	end
	local ok, message = action()
	if not ok then
		data.inventory.items = before
		return false, message
	end
	EconomyService.spend(player, "Gems", price, "missing_" .. string.lower(context))
	return true
end

function MissingService.init()
	NetService.on(Net.Missing_Buy, 1, 3, MissingService.buy)
end

return MissingService
