--!strict
-- Purchase rules (Design/09 Roblox Architecture §10, 10 Monetization), pure so Lune can test
-- them: who may buy what, receipt de-duplication and the Big Barn bonus. ShopService does
-- the Roblox side (ProcessReceipt, prompts, pass ownership).

local Products = require("./Config/Products")

local Shop = {}

-- Can this player buy the product now? (Shown and prompted only when true.)
function Shop.canBuy(data: { [string]: any }, key: string): (boolean, string?)
	local product = Products.products[key]
	if product == nil or product.productId == 0 then
		return false, "Coming soon"
	end
	if product.fromLevel and data.level < product.fromLevel then
		return false, string.format("From level %d", product.fromLevel)
	end
	if product.once and data.purchases.bought[key] then
		return false, "Already yours"
	end
	return true
end

function Shop.processed(data: { [string]: any }, purchaseId: string): boolean
	return data.purchases.receipts[purchaseId] ~= nil
end

-- Remember a granted receipt; keeps only the newest `keepReceipts`
function Shop.record(data: { [string]: any }, purchaseId: string, now: number)
	local receipts = data.purchases.receipts
	receipts[purchaseId] = now
	local ids = {}
	for id in receipts do
		table.insert(ids, id)
	end
	if #ids <= Products.keepReceipts then
		return
	end
	table.sort(ids, function(a, b)
		return receipts[a] > receipts[b]
	end)
	for i = Products.keepReceipts + 1, #ids do
		receipts[ids[i]] = nil
	end
end

-- Barn space including the Big Barn pass
function Shop.barnCapacity(data: { [string]: any }): number
	local bonus = if data.purchases.passes.BigBarn then Products.passes.BigBarn.barnBonus else 0
	return data.inventory.barnCapacity + bonus
end

return Shop
