--!strict
-- Robux purchases (Design/09 Roblox Architecture §10, 10 Monetization). Sets ProcessReceipt
-- exactly once. Fails closed: a grant counts only once it's saved, otherwise it's rolled back
-- and Roblox retries the receipt later. The client sends a product key, never an id, and
-- only the server prompts.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Net = require(Shared.Net)
local Products = require(Shared.Config.Products)
local Shop = require(Shared.Shop)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local TelemetryService = require(script.Parent.TelemetryService)

local ShopService = {}

local byProductId: { [number]: Products.Product } = {}
for _, product in Products.products do
	if product.productId ~= 0 then
		byProductId[product.productId] = product
	end
end

local function grant(player: Player, data: { [string]: any }, product: Products.Product)
	EconomyService.add(player, "Gems", product.gems, "robux_" .. product.key, "IAP")
	for tool, qty in product.tools or {} do
		data.toolShed.items[tool] = (data.toolShed.items[tool] or 0) + qty
		local balance = data.toolShed.items[tool]
		TelemetryService.economy(player, "Tools", "Source", qty, balance, "robux_" .. product.key, "IAP", tool .. "s")
	end
	if product.once then
		data.purchases.bought[product.key] = true
	end
end

local function revert(player: Player, data: { [string]: any }, product: Products.Product)
	EconomyService.spend(player, "Gems", math.min(product.gems, data.currencies.Gems), "robux_revert")
	for tool, qty in product.tools or {} do
		data.toolShed.items[tool] = math.max(0, (data.toolShed.items[tool] or 0) - qty)
	end
	if product.once then
		data.purchases.bought[product.key] = nil
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.get(player)
	if player == nil or data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retried on their next join
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if Shop.processed(data, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = byProductId[receipt.ProductId]
	if product == nil then
		warn("[Shop] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- A once-only product bought twice (two prompts racing): still paid, so grant the Gems
	local ok = pcall(grant, player, data, product)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Shop.record(data, purchaseId, os.time())
	if not DataService.saveNow(player) then
		data.purchases.receipts[purchaseId] = nil
		pcall(revert, player, data, product)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	NetService.popup(player, { kind = "Purchase", key = product.key, name = product.displayName, gems = product.gems })
	TelemetryService.shopGranted(player)
	NetService.pushState(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Client asks to buy a product by key; the server checks and shows the Roblox prompt
function ShopService.prompt(player: Player, key: any): (boolean, string?)
	if not NetService.check.id(key) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason = Shop.canBuy(data, key)
	if not ok then
		return false, reason
	end
	MarketplaceService:PromptProductPurchase(player, Products.products[key].productId)
	TelemetryService.shopPrompted(player)
	return true
end

function ShopService.promptPass(player: Player, key: any): (boolean, string?)
	if not NetService.check.id(key) then
		return false
	end
	local pass = Products.passes[key]
	if pass == nil or pass.passId == 0 then
		return false, "Coming soon"
	end
	local data = DataService.get(player) :: { [string]: any }
	if data.purchases.passes[key] then
		return false, "Already yours"
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.passId)
	TelemetryService.shopPrompted(player)
	return true
end

-- Game passes: ask Roblox on join (a refund or a purchase elsewhere shows up here)
-- (in the background, so a slow Roblox call never holds up the plot)
function ShopService.playerLoaded(player: Player)
	task.spawn(function()
		for key, pass in Products.passes do
			if pass.passId ~= 0 then
				local ok, owns =
					pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.passId)
				local data = DataService.get(player)
				if ok and data then
					data.purchases.passes[key] = if owns then true else nil
					DataService.markDirty(player)
					NetService.pushState(player)
				end
			end
		end
	end)
end

function ShopService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local data = DataService.get(player)
		for key, pass in Products.passes do
			if data and pass.passId == passId then
				data.purchases.passes[key] = true
				DataService.markDirty(player, true)
				NetService.popup(player, { kind = "Purchase", key = key, name = pass.displayName })
				NetService.pushState(player)
			end
		end
	end)
	NetService.on(Net.Shop_Prompt, 1, 3, ShopService.prompt)
	NetService.on(Net.Shop_PromptPass, 1, 3, ShopService.promptPass)
end

return ShopService
