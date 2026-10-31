--!strict
-- The Market stall panel (shared/Market, server/MarketService). Tapping your own stall at the
-- gate runs it: list Barn goods in its slots (pick the goods, how many, and a price inside the
-- band), take listings down, feature one. Tapping a neighbor's stall shows what's on it to buy;
-- the server publishes each stall's listings on the stall model ("Stall" attribute, JSON).
-- The Town Square's Market board lists every farm's featured listing ("Board" attribute,
-- JSON) with a Visit to each stall.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtMarket = require(Shared.Art.Market)
local Config = require(Shared.Config.Market)
local Items = require(Shared.Items)
local Market = require(Shared.Market)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local ReachController = require(script.Parent.Parent.Controllers.ReachController)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local MarketUi = {}

type Published = { slot: number, item: string, qty: number, price: number, botAt: number }
type StallView = { listings: { Published }, featured: number, open: boolean, traderOnly: boolean }

local player = Players.LocalPlayer
local stall: Instance? = nil -- the neighbor's stall being looked at
local board: Instance? = nil -- the Town Square's Market board, once tapped
-- Listing editor state (your own stall)
local pickSlot: number? = nil
local pickItem: string? = nil
local pickQty = 1
local pickPrice = 0

local function line(text: string, order: number, body: Instance, height: number?, color: Color3?)
	return Ui.label(text, {
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, height or 22),
		TextSize = 14,
		TextColor3 = color or Ui.colors.text,
		LayoutOrder = order,
		Parent = body,
	})
end

local function card(order: number, body: Instance, height: number?): Frame
	return Ui.card({ Size = UDim2.new(1, -8, 0, height or 56), LayoutOrder = order, Parent = body })
end

local function cardText(parent: Instance, top: string, bottom: string, bottomColor: Color3?, width: number?)
	Ui.label(top, {
		Font = Ui.theme.Type.display,
		TextSize = 15,
		Size = UDim2.new(1, -(width or 120), 0, 22),
		Position = UDim2.fromOffset(8, 4),
		Parent = parent,
	})
	Ui.label(bottom, {
		TextSize = 13,
		TextColor3 = bottomColor or Ui.colors.muted,
		Size = UDim2.new(1, -(width or 120), 0, 18),
		Position = UDim2.fromOffset(8, 28),
		Parent = parent,
	})
end

local function goods(qty: number, item: string): string
	local def = Items[item]
	return string.format("%d %s", qty, if def then def.displayName else item)
end

local function resetEditor()
	pickSlot, pickItem, pickQty, pickPrice = nil, nil, 1, 0
end

local function setQty(qty: number)
	local item = pickItem :: string
	local have = ClientStore.itemCount(item)
	pickQty = math.clamp(qty, 1, math.max(1, math.min(Config.maxQty, have)))
	local _, _, default = Market.priceRange(item, pickQty)
	pickPrice = default
end

local function stepper(parent: Instance, y: number, text: string, minus: () -> (), plus: () -> ())
	Ui.label(text, {
		TextSize = 15,
		Size = UDim2.new(1, -150, 0, 30),
		Position = UDim2.fromOffset(8, y),
		Parent = parent,
	})
	Ui.button("−", minus, { Size = UDim2.fromOffset(60, 30), Position = UDim2.new(1, -136, 0, y), Parent = parent })
	Ui.button("+", plus, { Size = UDim2.fromOffset(60, 30), Position = UDim2.new(1, -70, 0, y), Parent = parent })
end

-- Choosing goods for an empty slot, then how many and the price
local function renderEditor(state: { [string]: any }, body: Instance)
	local slot = pickSlot :: number
	if pickItem == nil then
		line(string.format("Slot %d: pick goods from your Barn", slot), 1, body, nil, Ui.colors.warn)
		local ids = {}
		for id, qty in state.inventory do
			if qty > 0 and Market.tradeable(id) then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a, b)
			return Items[a].displayName < Items[b].displayName
		end)
		if #ids == 0 then
			line(
				"Nothing in your Barn can go on the stall yet. Crops, animal goods and factory goods can.",
				2,
				body,
				38
			)
		end
		for i, id in ids do
			local c = card(2 + i, body, 48)
			cardText(c, Items[id].displayName, string.format("You have %d", state.inventory[id]))
			Ui.button("Choose", function()
				pickItem = id
				setQty(math.min(Config.maxQty, state.inventory[id]))
				Panels.refresh()
			end, { Size = UDim2.fromOffset(100, 34), Position = UDim2.new(1, -106, 0, 7), Parent = c })
		end
		Ui.button("Back", function()
			resetEditor()
			Panels.refresh()
		end, { Size = UDim2.fromOffset(100, 34), LayoutOrder = 1000, Parent = body })
		return
	end
	local item = pickItem :: string
	local low, high = Market.priceRange(item, pickQty)
	local base = Market.basePrice(item, pickQty)
	local proceeds = Market.proceeds(pickPrice)
	line(string.format("Slot %d: %s", slot, goods(pickQty, item)), 1, body, nil, Ui.colors.warn)
	local c = card(2, body, 84)
	local step = math.max(1, math.floor((high - low) / 10 + 0.5))
	stepper(c, 6, string.format("How many: %d (you have %d)", pickQty, ClientStore.itemCount(item)), function()
		setQty(pickQty - 1)
		Panels.refresh()
	end, function()
		setQty(pickQty + 1)
		Panels.refresh()
	end)
	stepper(c, 44, string.format("Price: %d Coins", pickPrice), function()
		pickPrice = math.clamp(pickPrice - step, low, high)
		Panels.refresh()
	end, function()
		pickPrice = math.clamp(pickPrice + step, low, high)
		Panels.refresh()
	end)
	line(
		string.format(
			"Barn value %d. Prices from %d to %d. You get %d after the %d%% stall fee. If nobody buys it in %s, a passing trader pays %d.",
			base,
			low,
			high,
			proceeds,
			math.floor(Config.taxRate * 100 + 0.5),
			Timer.format(Config.botSeconds * (state.timeScale or 1)),
			math.min(pickPrice, base)
		),
		3,
		body,
		56,
		Ui.colors.muted
	)
	Ui.button(string.format("List for %d Coins", pickPrice), function()
		Remotes.fire("Market_List", slot, item, pickQty, pickPrice)
		resetEditor()
	end, { Size = UDim2.fromOffset(200, 40), LayoutOrder = 4, BackgroundColor3 = Ui.colors.accent, Parent = body })
	Ui.button("Back", function()
		pickItem = nil
		Panels.refresh()
	end, { Size = UDim2.fromOffset(100, 34), LayoutOrder = 5, Parent = body })
end

local function renderOwn(state: { [string]: any }, body: Instance, title: TextLabel)
	title.Text = "Your Market Stall"
	local slots = Market.slotCount(state.level)
	if slots == 0 then
		line(
			string.format(
				"Your stall opens at level %d. Then you can sell your goods to other farmers for Coins.",
				Config.unlockLevel
			),
			1,
			body,
			38,
			Ui.colors.warn
		)
		return
	end
	if pickSlot ~= nil and pickSlot <= slots then
		renderEditor(state, body)
		return
	end
	local m = state.market or { listings = {}, featured = 0 }
	local now = ClientStore.now()
	line(
		string.format(
			"Sell goods to other farmers: each sale pays you at once, less a %d%% stall fee. Anything left for %s goes to a passing trader at the Barn price.",
			math.floor(Config.taxRate * 100 + 0.5),
			Timer.format(Config.botSeconds * (state.timeScale or 1))
		),
		1,
		body,
		38,
		Ui.colors.muted
	)
	if player:GetAttribute("MarketTraderOnly") then
		line("Your account can't trade with other players, so your stall sells to traders only.", 2, body, 38)
	end
	for slot = 1, slots do
		local listing = nil
		for _, l in m.listings do
			if l.slot == slot then
				listing = l
			end
		end
		local c = card(10 + slot, body)
		if listing == nil then
			cardText(c, string.format("Slot %d", slot), "Empty")
			Ui.button("List goods", function()
				pickSlot = slot
				pickItem = nil
				Panels.refresh()
			end, { Size = UDim2.fromOffset(110, 36), Position = UDim2.new(1, -116, 0, 10), Parent = c })
			continue
		end
		local left = Market.botAt(listing, state.timeScale) - now
		cardText(
			c,
			string.format(
				"%s · %d Coins%s",
				goods(listing.qty, listing.item),
				listing.price,
				if m.featured == slot then " ★" else ""
			),
			string.format("A trader buys it in %s", Timer.format(math.max(0, left))),
			nil,
			230
		)
		local feature = Ui.button("Feature", function()
			Remotes.fire("Market_Feature", slot)
		end, {
			Size = UDim2.fromOffset(100, 36),
			Position = UDim2.new(1, -216, 0, 10),
			BackgroundColor3 = Ui.colors.selected,
			Parent = c,
		})
		Ui.setEnabled(feature, m.featured ~= slot)
		Ui.button("Take down", function()
			Remotes.fire("Market_Unlist", slot)
		end, {
			Size = UDim2.fromOffset(104, 36),
			Position = UDim2.new(1, -110, 0, 10),
			BackgroundColor3 = Ui.colors.danger,
			Parent = c,
		})
	end
	colorRow(m, body)
end

-- The awning color picker under the slots
local function colorRow(m: { [string]: any }, body: Instance)
	local c = card(100, body, 56)
	cardText(c, "Awning color", "Free to change any time", nil, 4 * 46 + 12)
	local current = m.color or Config.defaultColor
	for i, name in Config.colors do
		local swatch = Ui.button(if name == current then "✓" else "", function()
			Remotes.fire("Market_Color", name)
		end, {
			Size = UDim2.fromOffset(40, 36),
			Position = UDim2.new(1, -(5 - i) * 46 - 4, 0, 10),
			BackgroundColor3 = ArtMarket.COLORS[name],
			Parent = c,
		})
		swatch:SetAttribute("Color", name)
	end
end

local function view(model: Instance?): StallView?
	local raw = model and model:GetAttribute("Stall")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded :: StallView else nil
end

local function renderShop(state: { [string]: any }, body: Instance, title: TextLabel, ownerId: number)
	local owner = Players:GetPlayerByUserId(ownerId)
	title.Text = string.format("%s's Stall", if owner then owner.DisplayName else "A Neighbor")
	local shown = view(stall)
	if shown == nil then
		line("This stall is packed away.", 1, body)
		return
	elseif not shown.open then
		line(string.format("This stall opens when its farm reaches level %d.", Config.unlockLevel), 1, body)
		return
	elseif Market.slotCount(state.level) == 0 then
		line(
			string.format("You can buy at the Market from level %d.", Config.unlockLevel),
			1,
			body,
			nil,
			Ui.colors.warn
		)
		return
	elseif shown.traderOnly or player:GetAttribute("MarketTraderOnly") then
		line("This stall only sells to passing traders.", 1, body, nil, Ui.colors.warn)
		return
	end
	if #shown.listings == 0 then
		line("Nothing for sale right now. Come back later!", 1, body)
		return
	end
	line("Buy goods straight into your Barn. Stand by the stall to buy.", 1, body, nil, Ui.colors.muted)
	for i, listing in shown.listings do
		local c = card(1 + i, body)
		local base = Market.basePrice(listing.item, listing.qty)
		cardText(
			c,
			string.format(
				"%s · %d Coins%s",
				goods(listing.qty, listing.item),
				listing.price,
				if shown.featured == listing.slot then " ★" else ""
			),
			string.format("Barn value %d · you have %d", base, ClientStore.itemCount(listing.item))
		)
		local buy = Ui.button("Buy", function()
			Remotes.fire("Market_Buy", ownerId, listing.slot)
		end, { Size = UDim2.fromOffset(100, 36), Position = UDim2.new(1, -106, 0, 10), Parent = c })
		Ui.setEnabled(buy, state.currencies.Coins >= listing.price)
	end
end

type BoardEntry = { userId: number, name: string, slot: number, item: string, qty: number, price: number }

local function boardEntries(): { BoardEntry }
	local raw = board and board:GetAttribute("Board")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded :: { BoardEntry } else {}
end

-- The Town Square's Market board: each farm's featured listing and a Visit to its stall
local function renderBoard(state: { [string]: any }, body: Instance, title: TextLabel)
	title.Text = "Market Board"
	line(
		"Featured goods from the farms on this server. Visit a stall to buy, or feature your own listing at your stall.",
		1,
		body,
		38,
		Ui.colors.muted
	)
	local entries = boardEntries()
	if #entries == 0 then
		line("Nothing featured right now. Check back soon!", 2, body)
	end
	for i, entry in entries do
		local c = card(2 + i, body)
		local def = Items[entry.item]
		cardText(
			c,
			string.format("%s · %d Coins", goods(entry.qty, entry.item), entry.price),
			string.format(
				"%s's stall%s",
				entry.name,
				if def then string.format(" · Barn value %d", Market.basePrice(entry.item, entry.qty)) else ""
			)
		)
		if entry.userId == player.UserId then
			Ui.button("My stall", function()
				MarketUi.openOwn()
			end, { Size = UDim2.fromOffset(100, 36), Position = UDim2.new(1, -106, 0, 10), Parent = c })
		else
			Ui.button("Visit", function()
				Panels.close()
				Remotes.fire("Visit_Go", entry.userId)
			end, {
				Size = UDim2.fromOffset(100, 36),
				Position = UDim2.new(1, -106, 0, 10),
				BackgroundColor3 = Ui.colors.accent,
				Parent = c,
			})
		end
	end
	if Market.slotCount(state.level) == 0 then
		line(string.format("Your own stall opens at level %d.", Config.unlockLevel), 100, body, nil, Ui.colors.warn)
	end
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel, arg: string?)
	local ownerId = tonumber(arg or "")
	if ownerId == nil or ownerId == player.UserId then
		renderOwn(state, body, title)
	else
		renderShop(state, body, title, ownerId)
	end
end

-- Your own stall's tap (ReachController's act on the plot)
function MarketUi.openOwn()
	resetEditor()
	Panels.open("Market")
end

function MarketUi.init()
	Panels.register("Market", render)
	Panels.register("MarketBoard", function(state, body, title)
		renderBoard(state, body, title)
	end)
	ReachController.openMarket = MarketUi.openOwn
	-- A neighbor's stall is off our plot: open its goods once the avatar has walked up
	local previous = ReachController.otherTarget
	ReachController.otherTarget = function(part: BasePart)
		if part:GetAttribute("Interact") == "MarketBoard" then
			return function()
				if board ~= part then
					board = part
					part:GetAttributeChangedSignal("Board"):Connect(function()
						if Panels.isShowing("MarketBoard") then
							Panels.refresh()
						end
					end)
				end
				Panels.open("MarketBoard")
			end,
				false
		end
		if part:GetAttribute("Interact") == "Market" then
			local model = part:FindFirstAncestor("MarketStall")
			local ownerId = model and model:GetAttribute("Owner")
			if type(ownerId) == "number" then
				return function()
					stall = model
					Panels.open("Market", tostring(ownerId))
				end, true
			end
		end
		return previous(part)
	end
end

return MarketUi
