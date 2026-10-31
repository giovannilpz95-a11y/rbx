--!strict
-- The Market stalls (shared/Market, Config/Market; roadmap week 4): every farm's stall at its
-- gate. The owner lists Barn goods inside the price band, takes them down or features one;
-- anyone else on the server walks up and buys. A sale pays the seller at once, less the stall
-- fee (a Coin sink). A listing nobody buys in 2 hours goes to a passing trader at the Barn
-- price, so stalls never sit dead on empty servers.
--
-- Safety (14 Multiplayer Features §5): goods only (never Gems, tools, materials, decorations or
-- anything bought with Robux), prices inside the band, a cap on buys from one seller per hour,
-- new farms can't overpay, and accounts whose policy doesn't allow trading paid items neither
-- buy from other farms nor sell to them (their stalls sell to the trader only).

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Items = require(Shared.Items)
local Market = require(Shared.Market)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local SocialService = require(script.Parent.SocialService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local MarketService = {}

MarketService.REACH = 24 -- studs from the stall a buyer must stand
MarketService.TICK = 15 -- seconds between passing-trader checks

local allowed: { [Player]: boolean } = {}

-- May this account trade with other players? Cached per session; allowed when the policy
-- can't be read (and always in Studio).
function MarketService.canTrade(player: Player): boolean
	if typeof(player) ~= "Instance" or RunService:IsStudio() then
		return true
	end
	local cached = allowed[player]
	if cached ~= nil then
		return cached
	end
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	local yes = not ok or type(info) ~= "table" or info.IsPaidItemTradingAllowed ~= false
	allowed[player] = yes
	if typeof(player) == "Instance" then
		player:SetAttribute("MarketTraderOnly", not yes)
	end
	return yes
end

local function plural(qty: number, item: string): string
	return string.format("%d %s", qty, Items[item].displayName)
end

function MarketService.list(player: Player, slot: any, item: any, qty: any, price: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local have = if type(item) == "string" and Items[item] then InventoryService.count(player, item) else 0
	local ok, reason = Market.canList(data, slot, item, qty, price, have)
	if not ok then
		return false, reason
	end
	if not InventoryService.remove(player, { [item] = qty }) then
		return false, "Those goods aren't in your Barn any more"
	end
	Market.list(data, slot, item, qty, price, Clock.now())
	TelemetryService.custom(player, "MarketListed", price, item)
	PlotService.refresh(player)
	return true
end

function MarketService.unlist(player: Player, slot: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local listing = Market.listing(data, slot)
	if listing == nil then
		return false
	end
	if InventoryService.space(player) < listing.qty then
		return false, "Make room in your Barn to take those goods back"
	end
	Market.remove(data, slot)
	InventoryService.add(player, { [listing.item] = listing.qty })
	PlotService.refresh(player)
	return true
end

function MarketService.feature(player: Player, slot: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason = Market.feature(data, slot, Clock.now())
	if not ok then
		return false, reason
	end
	PlotService.refresh(player)
	return true
end

-- Pay a seller for a sale (to a player or the trader) and tell them
local function paySeller(seller: Player, amount: number, reason: string, message: string)
	if amount > 0 then
		EconomyService.add(seller, "Coins", amount, reason)
	end
	DataService.markDirty(seller, true)
	NetService.pushState(seller)
	NetService.toast(seller, message)
	PlotService.refresh(seller)
end

function MarketService.buy(player: Player, sellerId: any, slot: any): (boolean, string?)
	local data = DataService.get(player) :: { [string]: any }
	local seller = SocialService.playerByUserId(sellerId)
	local sellerData = seller and DataService.get(seller)
	if seller == nil or sellerData == nil then
		return false, "That farmer has left the server"
	elseif seller == player then
		return false, "That's your own stall"
	elseif not MarketService.canTrade(player) then
		return false, "Buying from other farms isn't available on your account"
	elseif not MarketService.canTrade(seller) then
		return false, "This stall only sells to passing traders"
	end
	local at = PlotService.marketPosition(seller)
	if at == nil or not NetService.isNear(player, at, MarketService.REACH) then
		return false, "Walk up to the stall to buy"
	end
	local now = Clock.now()
	local key = tostring(seller.UserId)
	local listing, reason = Market.canBuy(data, sellerData, key, slot, now)
	if listing == nil then
		return false, reason
	end
	if InventoryService.space(player) < listing.qty then
		return false, "Your Barn is full. Make room first"
	end
	if not EconomyService.spend(player, "Coins", listing.price, "market_buy") then
		return false, string.format("That costs %d Coins", listing.price)
	end
	local sold, proceeds = Market.buy(data, sellerData, key, slot :: number, now)
	InventoryService.add(player, { [sold.item] = sold.qty })
	TelemetryService.custom(player, "MarketBought", sold.price, sold.item)
	paySeller(
		seller,
		proceeds,
		"market_sale",
		string.format(
			"%s bought your %s for %d Coins (you get %d after the stall fee)",
			player.DisplayName,
			plural(sold.qty, sold.item),
			sold.price,
			proceeds
		)
	)
	return true
end

-- The passing trader: listings that waited long enough sell at the Barn price (or theirs)
local function traderTick()
	local now = Clock.now()
	local scale = Clock.getTimeScale()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data == nil or data.market == nil or #data.market.listings == 0 then
			continue
		end
		for _, sale in Market.botTick(data, now, scale) do
			paySeller(
				player,
				sale.price,
				"market_trader",
				string.format(
					"A passing trader bought your %s for %d Coins",
					plural(sale.listing.qty, sale.listing.item),
					sale.price
				)
			)
		end
	end
end

function MarketService.init()
	NetService.on(Net.Market_List, 2, 4, MarketService.list)
	NetService.on(Net.Market_Unlist, 2, 4, MarketService.unlist)
	NetService.on(Net.Market_Feature, 1, 2, MarketService.feature)
	NetService.on(Net.Market_Buy, 2, 4, MarketService.buy)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(MarketService.canTrade, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(MarketService.canTrade, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		allowed[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(MarketService.TICK)
			local ok, err = pcall(traderTick)
			if not ok then
				warn("[MarketService] trader tick failed:", err)
			end
		end
	end)
end

return MarketService
