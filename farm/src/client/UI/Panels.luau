--!strict
-- One panel open at a time: Orders, Barn, Buildings (every factory and pen), one factory,
-- one pen, one growing field, the Town (Houses, Community Buildings, materials), the seed
-- picker and (Studio only) Debug.
-- Anything that spends Gems takes two taps: the first asks, the second spends.
-- Panels re-render on every state change and once a second for countdowns.

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Animals = require(Shared.Config.Animals)
local ArtIcons = require(Shared.Art.Icons)
local Balance = require(Shared.Config.Balance)
local Barn = require(Shared.Config.Barn)
local BarnRules = require(Shared.BarnRules)
local Crops = require(Shared.Config.Crops)
local Factories = require(Shared.Config.Factories)
local Items = require(Shared.Items)
local Pen = require(Shared.Pen)
local Recipes = require(Shared.Config.Recipes)
local Land = require(Shared.Config.Land)
local Missing = require(Shared.Missing)
local Settings = require(Shared.Settings)
local Speedup = require(Shared.Speedup)
local Prize = require(Shared.Config.Prize)
local Products = require(Shared.Config.Products)
local PrizeRules = require(Shared.Prize)
local Tools = require(Shared.Config.Tools)
local Town = require(Shared.Config.Town)
local TownRules = require(Shared.TownRules)
local Tutorial = require(Shared.Tutorial)
local Decor = require(Shared.Config.Decor)
local DecorRules = require(Shared.DecorRules)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Townsfolk = require(script.Parent.Townsfolk)
local Ui = require(script.Parent.Ui)
local DecorPlacer = require(script.Parent.Parent.Controllers.DecorPlacer)

local Panels = {}

local gui: ScreenGui
local frame: Frame
local titleLabel: TextLabel
local body: ScrollingFrame
local current: string? = nil
local currentArg: string? = nil -- the field for Seeds, the pen for Pen

-- Set by the reach controller: is the avatar close enough to a factory's output table, or to
-- a pen, for the hands-on buttons?
Panels.canCollect = function(_factoryId: string): boolean
	return false
end
Panels.nearPen = function(_penId: string): boolean
	return false
end

-- Gem buttons waiting for their second tap: key -> time() of the first tap. (time() is wall
-- time since the game started; os.clock() is CPU time on Roblox and can run fast.)
local armed: { [string]: number } = {}
local ARM_SECONDS = 4
local lastGemTap = 0
local lastDevTap = 0 -- Debug panel buttons (renderDebug)

local function isArmed(key: string): boolean
	return armed[key] ~= nil and time() - armed[key] < ARM_SECONDS
end

-- While a Gem button waits for its second tap, the once-a-second refresh leaves the panel
-- alone so the armed button stays the same button under the player's finger.
local function anyArmed(): boolean
	for key in armed do
		if isArmed(key) then
			return true
		end
		armed[key] = nil
	end
	return false
end

local function gems(n: number): string
	if n == 0 then
		return "free"
	end
	return string.format("%d Gem%s", n, if n == 1 then "" else "s")
end

-- A button that acts on a confirming second tap (the first arms it and shows `armedText`).
-- `once`: act on the first tap (nothing to confirm). Acts on the press itself, so a panel
-- refresh between press and release can't swallow the tap.
local function confirmButton(
	key: string,
	text: string,
	armedText: string,
	fire: () -> (),
	props: { [string]: any },
	enabled: boolean,
	color: Color3,
	once: boolean?
): TextButton
	local armedNow = isArmed(key)
	local button: TextButton
	local function tap()
		-- Press and Activated can both arrive for one tap; take the first
		if time() - lastGemTap < 0.35 or not button.Active then
			return
		end
		lastGemTap = time()
		if once or isArmed(key) then
			armed[key] = nil
			fire()
		else
			table.clear(armed) -- one armed button at a time
			armed[key] = time()
			Panels.refresh()
			task.delay(ARM_SECONDS + 0.1, Panels.refresh) -- back to normal if not confirmed
		end
	end
	button = Ui.button(if armedNow then armedText else text, tap, props)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tap()
		end
	end)
	Ui.setEnabled(button, enabled, if armedNow then Ui.colors.accent else color)
	return button
end

-- A button that spends Gems after a confirming second tap (or one tap, when the Gem confirm
-- setting says this price doesn't need asking).
-- `free`: a price of 0 is a gift (one tap, always on) rather than "nothing to speed up"
local function gemButton(
	key: string,
	text: string,
	price: number,
	fire: () -> (),
	props: { [string]: any },
	free: boolean?
)
	local state = ClientStore.state
	return confirmButton(
		key,
		string.format("%s  %s", text, gems(price)),
		string.format("Spend %s?", gems(price)),
		fire,
		props,
		free == true or (price > 0 and state ~= nil and state.currencies.Gems >= price),
		Ui.colors.gems,
		free or (state ~= nil and not Settings.confirmGems(state.settings, price))
	)
end

-- "Buy what's missing" (G3, shared/Missing): when `needs` is short only of items, a Gem button
-- pays for just those and does the action in one step. Returns the button and a line naming
-- what's missing, or nil when nothing is missing or it can't be bought.
local function missingButton(
	key: string,
	needs: { [string]: number },
	props: { [string]: any },
	context: string,
	a: any?,
	b: any?
): (TextButton?, string?)
	local lines = Missing.list(needs, ClientStore.itemCount)
	local price = Missing.price(lines)
	if #lines == 0 or price == nil then
		return nil, nil
	end
	local button = gemButton("missing:" .. key, "Buy missing", price, function()
		Remotes.fire("Missing_Buy", context, a, b)
	end, props)
	return button, "Missing: " .. Missing.describe(lines)
end

-- A small red line under a row's text, naming what's missing
local function missingLine(parent: Instance, text: string, y: number, rightInset: number)
	Ui.label(text, {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, -rightInset, 0, 16),
		TextColor3 = Ui.colors.danger,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = parent,
	})
end

-- Every key of a config table, in its `order`.
local function sortedKeys(defs: { [string]: { order: number } }): { string }
	local ids = {}
	for id in defs do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return defs[a].order < defs[b].order
	end)
	return ids
end

local function sortedIds(defs: { [string]: { order: number } }, enabled: { string }): { string }
	local ids = table.clone(enabled)
	table.sort(ids, function(a, b)
		return defs[a].order < defs[b].order
	end)
	return ids
end

local function itemName(id: string): string
	local item = Items[id]
	return if item then item.displayName else id
end

-- Item icons are ViewportFrames holding the item's 3D prop, too costly to rebuild on every
-- one-second refresh, so they are kept between renders and handed out again per item.
local iconPool: { [string]: { ViewportFrame } } = {}
local iconsUsed: { [string]: number } = {}

local function itemIcon(id: string, parent: Instance, size: number, position: UDim2?): ViewportFrame
	local n = (iconsUsed[id] or 0) + 1
	iconsUsed[id] = n
	local list = iconPool[id] or {}
	iconPool[id] = list
	local icon = list[n]
	if icon == nil then
		icon = ArtIcons.viewport(id, size)
		list[n] = icon
	end
	icon.Size = UDim2.fromOffset(size, size)
	icon.Position = position or UDim2.new()
	icon.Parent = parent
	return icon
end

-- Takes the icons out of the panel before it is cleared, so they survive for the next render.
local function releaseIcons()
	for _, list in iconPool do
		for _, icon in list do
			icon.Parent = nil
		end
	end
	table.clear(iconsUsed)
end

local function row(height: number, order: number): Frame
	local card = Ui.card({
		Size = UDim2.new(1, -8, 0, height),
		LayoutOrder = order,
		Parent = body,
	})
	Ui.padding(6).Parent = card
	return card
end

---------------------------------------------------------------------------------------------
-- Panel renderers
---------------------------------------------------------------------------------------------

local ORDER_CARD = 104

local function renderOrders(state: { [string]: any })
	titleLabel.Text = "Order Board"
	local now = ClientStore.now()
	local Kit = Ui.theme.Kit
	for i, slot in state.board do
		local card = row(if slot.order then ORDER_CARD else 44, i)
		if slot.order then
			local order = slot.order
			-- The customer (C14): one of the townsfolk, the same while the order is up
			local person = Townsfolk.forOrder(i, order.wants)
			Kit.portrait(person.look, 60, person.name, { Parent = card })

			-- What they want: have / need chips (C5)
			local strip = Ui.new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(72, 0),
				Size = UDim2.new(1, -110, 0, 36),
				Parent = card,
			}, { Ui.list(6, true) })
			local ids = {}
			for id in order.wants do
				table.insert(ids, id)
			end
			table.sort(ids)
			local complete = true
			for n, id in ids do
				local chip = Kit.needChip(ClientStore.itemCount(id), order.wants[id], {
					Name = id,
					Size = UDim2.fromOffset(78, 36),
					LayoutOrder = n,
					Parent = strip,
				})
				itemIcon(id, chip.iconSlot, 34)
				complete = complete and chip.met
			end
			local reward = Ui.label(string.format("+%d Coins   +%d XP", order.rewardCoins, order.rewardXP), {
				Position = UDim2.fromOffset(72, 40),
				Size = UDim2.new(1, -72, 0, 20),
				Font = Enum.Font.GothamBold,
				TextColor3 = Ui.colors.muted,
				TextSize = 15,
				Parent = card,
			})
			Ui.button("X", function()
				Remotes.fire("Order_Discard", i)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(32, 32),
				BackgroundColor3 = Ui.colors.danger,
				Parent = card,
			})

			-- Deliver is the biggest button on the card; a short order offers Buy missing (G3)
			local buy, what = nil, nil
			if not complete then
				buy, what = missingButton("order:" .. i, order.wants, {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, 0, 1, 0),
					Size = UDim2.fromOffset(180, 36),
				}, "Order", i)
			end
			if buy and what then
				buy.Parent = card
				reward.Size = UDim2.new(1, -72, 0, 20)
				Ui.label(what, {
					Position = UDim2.fromOffset(72, 60),
					Size = UDim2.new(1, -260, 0, 30),
					TextColor3 = Ui.colors.danger,
					TextSize = 13,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					Parent = card,
				})
			else
				local deliver = Ui.button("Deliver", function()
					Remotes.fire("Order_Fulfill", i)
				end, {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, 0, 1, 0),
					Size = UDim2.fromOffset(130, 40),
					TextSize = 20,
					Parent = card,
				})
				Ui.setEnabled(deliver, complete)
			end
			-- A finished card glows green
			if complete then
				local stroke = card:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = Ui.colors.ready
					stroke.Thickness = 3
					stroke.Transparency = 0
				end
				card.BackgroundColor3 = Ui.theme.Palette.hex("#F1FBE9")
			end
		else
			local waitLeft = Timer.remaining(slot.refreshAt or 0, now)
			Ui.label(
				if waitLeft > 0 then "New order in " .. Timer.format(waitLeft) else "A new order is on its way...",
				{ Size = UDim2.new(1, -150, 0, 22), TextColor3 = Ui.colors.muted, Parent = card }
			)
			if waitLeft > 0 then
				gemButton("order:" .. i, "Now", Speedup.orderWait(waitLeft), function()
					Remotes.fire("Order_SkipWait", i)
				end, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.fromOffset(140, 30),
					Parent = card,
				})
			end
		end
	end
end

-- Tabs (C13): the picked tab per panel, and the names on screen for the Z / X keys
local tabPicked: { [string]: string } = {}
local tabNames: { string } = {}

local function tabRow(panel: string, names: { string }, order: number, badges: { [string]: string }?): string
	local picked = tabPicked[panel]
	if picked == nil or table.find(names, picked) == nil then
		picked = names[1]
		tabPicked[panel] = picked
	end
	tabNames = names
	Ui.theme.Kit.tabs(names, picked, function(name)
		tabPicked[panel] = name
		Panels.refresh()
	end, { Size = UDim2.new(1, -8, 0, 44), LayoutOrder = order, Parent = body }, badges)
	return picked
end

-- Z / X (or a gamepad's shoulder buttons via Main.client) step through the open panel's tabs
function Panels.cycleTab(step: number)
	if current == nil or #tabNames == 0 then
		return
	end
	local at = table.find(tabNames, tabPicked[current] or tabNames[1]) or 1
	tabPicked[current] = tabNames[(at - 1 + step) % #tabNames + 1]
	Panels.refresh()
end

-- A grid of cards that grows with its contents (vertical scrolling only: mobile checklist)
local function grid(order: number, cell: Vector2): Frame
	return Ui.new("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- Building pictures are bigger than item icons: one kept per building, reused every render
local picturePool: { [string]: ViewportFrame } = {}

local function buildingPicture(kind: string, id: string, parent: Instance, size: number): ViewportFrame?
	local key = kind .. ":" .. id
	local picture = picturePool[key]
	if picture == nil then
		local ok, built = pcall(ArtIcons.building, kind, id, size)
		if not ok then
			return nil
		end
		picture = built
		picturePool[key] = built
	end
	picture.Size = UDim2.fromOffset(size, size)
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 2)
	picture.Parent = parent
	return picture
end

local function releasePictures()
	for _, picture in picturePool do
		picture.Parent = nil
	end
end

-- Text that shrinks to fit its box, down to `min`
local function fitText(text: string, props: { [string]: any }, max: number, min: number?): TextLabel
	local label = Ui.label(text, props)
	label.TextScaled = true
	Ui.new("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = min or 10 }).Parent = label
	return label
end

---------------------------------------------------------------------------------------------
-- Barn (G5): tabs, a grid of item tiles, and a sell drawer with a quantity picker
---------------------------------------------------------------------------------------------

local BARN_TABS = { "All", "Crops", "Goods", "Materials", "Prizes", "Tools" }
local barnPick: string? = nil -- the tile whose sell drawer is open
local sellQty = 1

local function barnTabOf(id: string): string
	local item = Items[id]
	if item == nil then
		return "Goods"
	elseif item.kind == "Crop" then
		return "Crops"
	elseif item.kind == "Material" then
		return "Materials"
	end
	return "Goods"
end

local function barnTile(parent: Instance, id: string, qty: number, order: number)
	local picked = barnPick == id
	local tile = Ui.card({ Name = id, LayoutOrder = order, Parent = parent })
	if picked then
		local stroke = tile:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Ui.colors.selected
			stroke.Thickness = 3
			stroke.Transparency = 0
		end
	end
	itemIcon(id, tile, 48, UDim2.new(0.5, -24, 0, 4))
	fitText("x" .. qty, {
		Position = UDim2.new(0, 4, 1, -24),
		Size = UDim2.new(1, -8, 0, 20),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = tile,
	}, 16)
	-- The whole tile is the button
	local hit = Ui.new("TextButton", {
		Name = "Pick",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 5,
		Parent = tile,
	})
	Ui.theme.Kit.onTap(hit, function()
		if barnPick == id then
			barnPick = nil
		else
			barnPick = id
			sellQty = 1
		end
		Panels.refresh()
	end)
end

-- The sell drawer for the picked item: − qty +, "Sell N for X", and Sell all (two taps)
local function sellDrawer(state: { [string]: any }, order: number)
	local id = barnPick
	local have = if id then state.inventory[id] or 0 else 0
	if id == nil or have <= 0 then
		barnPick = nil
		return
	end
	local item = Items[id]
	local line = row(if item and item.sellPrice > 0 then 96 else 52, order)
	itemIcon(id, line, 40)
	local sellable = item ~= nil and item.sellPrice > 0
	Ui.label(string.format("%s  x%d", itemName(id), have), {
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -90, 0, 22),
		Font = Enum.Font.GothamBold,
		Parent = line,
	})
	Ui.label(
		if sellable
			then string.format("Sells for %d Coins each", item.sellPrice)
			elseif Barn.materials[id] then "For Barn upgrades. Can't be sold."
			else "For building. Can't be sold.",
		{
			Position = UDim2.fromOffset(46, 20),
			Size = UDim2.new(1, -90, 0, 18),
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			Parent = line,
		}
	)
	Ui.button("✕", function()
		barnPick = nil
		Panels.refresh()
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(36, 32),
		TextColor3 = Ui.colors.text,
		BackgroundColor3 = Ui.theme.Palette.button.neutral.face,
		Parent = line,
	})
	if not sellable or item == nil then
		return
	end
	sellQty = math.clamp(sellQty, 1, have)
	Ui.theme.Kit.stepper(sellQty, 1, have, function(v)
		sellQty = v
		Panels.refresh()
	end, { Position = UDim2.fromOffset(0, 44), Size = UDim2.fromOffset(140, 40), Parent = line })
	Ui.button(string.format("Sell %d for %d", sellQty, sellQty * item.sellPrice), function()
		Remotes.fire("Barn_Sell", id, sellQty)
	end, {
		Position = UDim2.fromOffset(148, 46),
		Size = UDim2.new(1, -264, 0, 36),
		BackgroundColor3 = Ui.colors.coins,
		TextScaled = true,
		Parent = line,
	})
	confirmButton("sellall:" .. id, "Sell all", string.format("Sure? +%d", have * item.sellPrice), function()
		Remotes.fire("Barn_Sell", id, have)
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 46),
		Size = UDim2.fromOffset(108, 36),
		TextScaled = true,
	}, true, Ui.colors.danger).Parent =
		line
end

-- The next Barn upgrade: n of each Barn material (Buy missing when short)
local function barnUpgradeRow(state: { [string]: any }, order: number, withMaterials: boolean): number
	local n = (state.barnUpgrades or 0) + 1
	local cost = BarnRules.upgradeCost(n)
	local canUpgrade = true
	for material, qty in cost do
		canUpgrade = canUpgrade and ClientStore.itemCount(material) >= qty
	end
	local upgradeRow = row(if withMaterials then 84 else 46, order)
	order += 1
	local buyUpgrade = if canUpgrade
		then nil
		else missingButton("barn", cost, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(170, 32),
		}, "Barn")
	Ui.label(string.format("Upgrade %d: room for %d (now %d)", n, BarnRules.capacity(n), state.barnCapacity), {
		Size = UDim2.new(1, if buyUpgrade then -180 else -110, 0, 32),
		Font = Enum.Font.GothamBold,
		TextWrapped = true,
		Parent = upgradeRow,
	})
	if buyUpgrade then
		buyUpgrade.Parent = upgradeRow
	else
		local upgrade = Ui.button("Upgrade", function()
			Remotes.fire("Barn_Upgrade")
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(100, 32),
			Parent = upgradeRow,
		})
		Ui.setEnabled(upgrade, canUpgrade)
	end
	if withMaterials then
		-- Have / need for each material (C5)
		local strip = Ui.new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 0, 36),
			Parent = upgradeRow,
		}, { Ui.list(10, true) })
		for i, material in sortedKeys(Barn.materials) do
			local chip = Ui.theme.Kit.needChip(
				ClientStore.itemCount(material),
				cost[material],
				{ LayoutOrder = i, Parent = strip }
			)
			itemIcon(material, chip.iconSlot, 34)
		end
	end
	return order
end

local function renderBarn(state: { [string]: any })
	titleLabel.Text = string.format("Barn  %d / %d", state.barnUsed, state.barnCapacity)
	-- "Full" once a typical harvest (2) no longer fits, so the banner shows when it bites
	local full = state.barnCapacity - state.barnUsed < 2
	local order = 1
	if full then
		Ui.label("Your Barn is full. Sell what you have most of, or upgrade it.", {
			TextColor3 = Ui.colors.danger,
			Font = Enum.Font.GothamBold,
			TextWrapped = true,
			LayoutOrder = order,
			Parent = body,
		})
		order += 1
	end
	local prizes = state.prizes or {}
	local tab = tabRow("Barn", BARN_TABS, order, { Prizes = if #prizes > 0 then tostring(#prizes) else "" })
	order += 1

	if tab == "All" or tab == "Materials" then
		order = barnUpgradeRow(state, order, tab == "Materials")
	end

	if tab == "Prizes" then
		barnPick = nil
		-- Prize Basket: Prize Crops sell at the Prize Stand for a multiple of the crop's price
		local prizes = state.prizes or {}
		Ui.label(
			string.format("Prize Basket  %d / %d", #prizes, Prize.basketSlots),
			{ Font = Enum.Font.GothamBold, LayoutOrder = order, Parent = body }
		)
		order += 1
		if #prizes == 0 then
			Ui.label("Now and then a harvest turns up a Sunkissed or Heirloom crop. They land here.", {
				TextColor3 = Ui.colors.muted,
				TextSize = 13,
				TextWrapped = true,
				LayoutOrder = order,
				Parent = body,
			})
			order += 1
		end
		for i, entry in prizes do
			local line = row(42, order)
			order += 1
			local value = PrizeRules.value(entry.crop, entry.tier)
			Ui.label(string.format("%s %s", Prize.tiers[entry.tier].displayName, itemName(entry.crop)), {
				Size = UDim2.new(1, -230, 1, 0),
				TextColor3 = Ui.colors.accent,
				Parent = line,
			})
			Ui.button("Show", function()
				Remotes.fire("Prize_Shelve", i)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -150, 0, 0),
				Size = UDim2.fromOffset(72, 30),
				Parent = line,
			})
			confirmButton(
				"prize:" .. i,
				string.format("Sell for %d Coins", value),
				string.format("Sure? Sell for %d", value),
				function()
					Remotes.fire("Prize_Sell", i)
				end,
				{
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.fromOffset(140, 30),
					Parent = line,
				},
				true,
				Ui.colors.coins
			)
		end

		-- Prize Shelf: on show on the plot by the Barn
		local shelf = state.prizeShelf or {}
		Ui.label(
			string.format("Prize Shelf  %d / %d", #shelf, Prize.shelfSlots),
			{ Font = Enum.Font.GothamBold, LayoutOrder = order, Parent = body }
		)
		order += 1
		if #shelf == 0 then
			Ui.label("Tap Show on a Prize Crop to put it on the shelf by your Barn for visitors to see.", {
				TextColor3 = Ui.colors.muted,
				TextSize = 13,
				TextWrapped = true,
				LayoutOrder = order,
				Parent = body,
			})
			order += 1
		end
		for i, entry in shelf do
			local line = row(42, order)
			order += 1
			Ui.label(string.format("%s %s", Prize.tiers[entry.tier].displayName, itemName(entry.crop)), {
				Size = UDim2.new(1, -150, 1, 0),
				TextColor3 = Ui.colors.accent,
				Parent = line,
			})
			Ui.button("Take down", function()
				Remotes.fire("Prize_Unshelve", i)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(120, 30),
				Parent = line,
			})
		end

		return
	end

	if tab == "Tools" then
		barnPick = nil
		local tools = state.tools or {}
		local shelf = grid(order, Vector2.new(96, 96))
		order += 1
		for i, id in sortedKeys(Tools.tools) do
			local def = Tools.tools[id]
			local tile = Ui.card({ Name = id, LayoutOrder = i, Parent = shelf })
			itemIcon(id, tile, 52, UDim2.new(0.5, -26, 0, 4))
			fitText(string.format("%s x%d", def.plural, tools[id] or 0), {
				Position = UDim2.new(0, 4, 1, -30),
				Size = UDim2.new(1, -8, 0, 24),
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if (tools[id] or 0) > 0 then Ui.colors.text else Ui.colors.muted,
				Parent = tile,
			}, 15)
		end
		Ui.label(
			if state.level >= Tools.fromLevel
				then "Tools drop from harvests and orders and don't use Barn space. Bigger land clearings will need them."
				else string.format(
					"Shovels, Axes and Saws start dropping at level %d. Bigger land clearings will need them.",
					Tools.fromLevel
				),
			{
				Size = UDim2.new(1, -8, 0, 36),
				TextColor3 = Ui.colors.muted,
				TextSize = 13,
				TextWrapped = true,
				LayoutOrder = order,
				Parent = body,
			}
		)
		return
	end

	-- Item tiles: the picked tab's items, most-stocked first
	local ids = {}
	for id in state.inventory do
		if tab == "All" or barnTabOf(id) == tab then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		if state.inventory[a] ~= state.inventory[b] then
			return state.inventory[a] > state.inventory[b]
		end
		return a < b
	end)
	if barnPick and table.find(ids, barnPick) == nil then
		barnPick = nil
	end
	sellDrawer(state, order)
	order += 1
	if #ids == 0 then
		Ui.label(if tab == "All" then "Empty. Harvest a field to fill it." else "Nothing here yet.", {
			TextColor3 = Ui.colors.muted,
			LayoutOrder = order,
			Parent = body,
		})
	else
		Ui.label("Tap an item to sell some.", {
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			LayoutOrder = order,
			Parent = body,
		})
	end
	order += 1
	local tiles = grid(order, Vector2.new(80, 80))
	order += 1
	for i, id in ids do
		barnTile(tiles, id, state.inventory[id], i)
	end
	if tab == "Materials" then
		Ui.label("Nails, Hinges and Paint drop from harvests and orders (level 5+), or buy one:", {
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 32),
			LayoutOrder = order,
			Parent = body,
		})
		order += 1
		for _, material in sortedKeys(Barn.materials) do
			local line = row(42, order)
			order += 1
			itemIcon(material, line, 30)
			Ui.label(string.format("%s   x%d", Barn.materials[material].displayName, ClientStore.itemCount(material)), {
				Position = UDim2.fromOffset(36, 0),
				Size = UDim2.new(1, -206, 1, 0),
				Parent = line,
			})
			gemButton("barn:" .. material, "Buy 1", Barn.materialGemPrice, function()
				Remotes.fire("Town_BuyMaterial", material)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(160, 30),
				Parent = line,
			})
		end
	end
end

local function renderFactory(state: { [string]: any }, factoryId: string)
	local def = Factories[factoryId]
	local preview = ClientStore.factoryPreview(factoryId)
	titleLabel.Text = def.displayName
	if preview == nil then
		return
	end
	local now = ClientStore.now()

	if not preview.built then
		local line = row(80, 1)
		if state.level < def.unlockLevel then
			Ui.label(string.format("Unlocks at level %d.", def.unlockLevel), { Parent = line })
		else
			local population = TownRules.population(state, now)
			Ui.label(
				string.format(
					"Build it for %d Coins (+%d XP). Needs Population %d (you have %d).",
					def.buildCost,
					def.xp,
					def.population,
					population
				),
				{ TextWrapped = true, Size = UDim2.new(1, 0, 0, 26), TextSize = 14, Parent = line }
			)
			local build = Ui.button("Build", function()
				Remotes.fire("Factory_Build", factoryId)
			end, { Position = UDim2.fromOffset(0, 30), Parent = line })
			Ui.setEnabled(build, state.currencies.Coins >= def.buildCost and population >= def.population)
		end
		return
	end
	if preview.underConstruction then
		local left = Timer.remaining(preview.constructionReadyAt, now)
		local line = row(42, 1)
		Ui.label("Building... " .. Timer.format(left) .. " left", { Size = UDim2.new(1, -170, 1, 0), Parent = line })
		local free = Tutorial.freeFinish(state, factoryId)
		gemButton("build:" .. factoryId, "Finish", if free then 0 else Speedup.building(left), function()
			Remotes.fire("Factory_SpeedUp", factoryId)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(160, 30),
			Parent = line,
		}, free)
		return
	end

	-- Recipes (paperwork: queue from anywhere)
	local order = 1
	local recipeIds = {}
	local makes = def.makes or factoryId -- a second copy makes its original's recipes
	for id, recipe in Recipes do
		if recipe.factory == makes then
			table.insert(recipeIds, id)
		end
	end
	table.sort(recipeIds, function(a, b)
		local ra, rb = Recipes[a], Recipes[b]
		if ra.unlockLevel ~= rb.unlockLevel then
			return ra.unlockLevel < rb.unlockLevel
		end
		return a < b
	end)
	for _, id in recipeIds do
		local recipe = Recipes[id]
		local line = row(46, order)
		order += 1
		local inputs = {}
		local enough = true
		for input, qty in recipe.inputs do
			table.insert(inputs, string.format("%d %s", qty, itemName(input)))
			if ClientStore.itemCount(input) < qty then
				enough = false
			end
		end
		local locked = state.level < recipe.unlockLevel
		local text = string.format(
			"%s  <-  %s   (%s)",
			if recipe.outputQty > 1
				then string.format("%d %s", recipe.outputQty, recipe.displayName)
				else recipe.displayName,
			table.concat(inputs, ", "),
			Timer.format(recipe.seconds * (state.timeScale or 1))
		)
		if locked then
			text ..= string.format("   Lv %d", recipe.unlockLevel)
		end
		local hasRoom = #preview.queue < preview.slots
		local buy, what = nil, nil
		if not enough and not locked and hasRoom then
			buy, what = missingButton("recipe:" .. id, recipe.inputs, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(150, 30),
			}, "Recipe", factoryId, id)
		end
		Ui.label(text, {
			Size = UDim2.new(1, if buy then -160 else -80, 0, 34),
			TextWrapped = true,
			TextSize = 15,
			Parent = line,
		})
		if buy and what then
			buy.Parent = line
			line.Size = UDim2.new(1, -8, 0, 60)
			missingLine(line, what, 34, 0)
		else
			local make = Ui.button("Make", function()
				Remotes.fire("Factory_Queue", factoryId, id)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(70, 30),
				Parent = line,
			})
			Ui.setEnabled(make, enough and not locked and hasRoom)
		end
	end

	-- Queue
	local queueLine = row(42, order)
	order += 1
	Ui.label(
		string.format("Queue  %d / %d", #preview.queue, preview.slots),
		{ Size = UDim2.new(1, -170, 1, 0), Font = Enum.Font.GothamBold, Parent = queueLine }
	)
	local slotCost = Speedup.nextSlotCost(def.queueSlots, preview.slots)
	if slotCost then
		gemButton("slot:" .. factoryId, "+1 slot", slotCost, function()
			Remotes.fire("Factory_BuySlot", factoryId)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(160, 30),
			Parent = queueLine,
		})
	end
	for i, job in preview.queue do
		local running = job.readyAt ~= nil and job.readyAt > now
		local status = if running then Timer.format(Timer.remaining(job.readyAt, now)) .. " left" else "waiting"
		local line = Ui.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 30),
			LayoutOrder = order,
			Parent = body,
		})
		Ui.label(
			string.format("%d. %s  %s", i, itemName(job.recipe), status),
			{ Size = UDim2.new(1, -170, 1, 0), TextColor3 = Ui.colors.muted, Parent = line }
		)
		if i == 1 and running then
			gemButton("job:" .. factoryId, "Finish", Speedup.production(job.readyAt - now), function()
				Remotes.fire("Factory_SpeedUp", factoryId)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(160, 28),
				Parent = line,
			})
		end
		order += 1
	end

	-- Output tray (hands-on: walk past the table, or tap Collect when in reach)
	local tray = row(46, order)
	Ui.label(
		string.format("Ready on the table: %d / %d", preview.outputCount, def.trayCapacity),
		{ Size = UDim2.new(1, -100, 1, 0), Parent = tray }
	)
	local collect = Ui.button("Collect", function()
		Remotes.fire("Factory_Collect", factoryId)
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(84, 30),
		Parent = tray,
	})
	local near = Panels.canCollect(factoryId)
	Ui.setEnabled(collect, preview.outputCount > 0 and near)
	if preview.outputCount > 0 and not near then
		Ui.label(
			"Walk to the output table to collect.",
			{ LayoutOrder = order + 1, TextColor3 = Ui.colors.muted, TextSize = 14, Parent = body }
		)
	end
end

-- One line of status for a factory, shared by the Buildings list.
local function factoryStatus(state: { [string]: any }, factoryId: string): string
	local def = Factories[factoryId]
	local preview = ClientStore.factoryPreview(factoryId)
	local now = ClientStore.now()
	if preview == nil then
		return ""
	elseif not preview.built then
		return if state.level < def.unlockLevel
			then string.format("unlocks at level %d", def.unlockLevel)
			elseif TownRules.population(state, now) < def.population then string.format(
				"needs Population %d",
				def.population
			)
			else string.format("build for %d Coins", def.buildCost)
	elseif preview.underConstruction then
		return "building, " .. Timer.format(Timer.remaining(preview.constructionReadyAt, now)) .. " left"
	elseif preview.outputCount > 0 then
		return string.format("%d ready on the table", preview.outputCount)
	elseif #preview.queue > 0 and preview.queue[1].readyAt then
		local job = preview.queue[1]
		return string.format(
			"making %s, %s left",
			itemName(job.recipe),
			Timer.format(Timer.remaining(job.readyAt, now))
		)
	end
	return "idle"
end

local function penStatus(state: { [string]: any }, penId: string): string
	local def = Animals.pens[penId]
	local pen = state.pens[penId]
	local now = ClientStore.now()
	if pen == nil then
		return ""
	elseif not pen.built then
		return if state.level < def.unlockLevel
			then string.format("unlocks at level %d", def.unlockLevel)
			else string.format("build for %d Coins", def.buildCost)
	elseif not Pen.isOperational(pen, now) then
		return "building, " .. Timer.format(Timer.remaining(pen.constructionReadyAt, now)) .. " left"
	end
	local counts = Pen.counts(pen, now)
	if counts.ready > 0 then
		return string.format("%d %s ready", counts.ready, def.productName)
	elseif counts.hungry > 0 then
		return string.format("%d hungry", counts.hungry)
	end
	return string.format("%s in %s", def.productName, Timer.format(Timer.remaining(counts.nextReadyAt or now, now)))
end

---------------------------------------------------------------------------------------------
-- Build menu (G4): tabs and picture cards for every building and decoration
---------------------------------------------------------------------------------------------

local BUILD_TABS = { "Factories", "Animals", "Houses", "Town", "Decor" }
local CARD = Vector2.new(140, 178)

-- One picture card: the building, its name, two short lines, and a button (or none).
-- `locked` greys the picture and shows the unlock level on it.
local function buildCard(
	parent: Instance,
	order: number,
	picture: { kind: string, id: string },
	name: string,
	line1: string,
	line2: string,
	line2Color: Color3?,
	locked: number?
): Frame
	local card = Ui.card({ Name = picture.id, LayoutOrder = order, Parent = parent })
	local pic = buildingPicture(picture.kind, picture.id, card, 84)
	if pic then
		pic.ImageTransparency = if locked then 0.55 else 0
	end
	if locked then
		Ui.new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Ui.theme.Palette.locked,
			Position = UDim2.new(0.5, 0, 0, 30),
			Size = UDim2.fromOffset(80, 24),
			Font = Ui.theme.Type.display,
			TextSize = 15,
			TextColor3 = Ui.colors.text,
			Text = "🔒 Level " .. locked,
			ZIndex = 3,
			Parent = card,
		}, { Ui.corner(12) })
	end
	fitText(name, {
		Position = UDim2.fromOffset(6, 88),
		Size = UDim2.new(1, -12, 0, 20),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	}, 16)
	fitText(line1, {
		Position = UDim2.fromOffset(6, 108),
		Size = UDim2.new(1, -12, 0, 16),
		TextColor3 = Ui.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	}, 13)
	fitText(line2, {
		Position = UDim2.fromOffset(6, 124),
		Size = UDim2.new(1, -12, 0, 16),
		TextColor3 = line2Color or Ui.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	}, 13)
	return card
end

-- The card's bottom button
local function cardButton(card: Frame, text: string, enabled: boolean, onClick: () -> ()): TextButton
	local button = Ui.button(text, onClick, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 32),
		TextScaled = true,
		Parent = card,
	})
	Ui.setEnabled(button, enabled)
	return button
end

local function cardProps(): { [string]: any }
	return {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 32),
		TextScaled = true,
	}
end

local function coinsText(n: number): string
	return string.format("%s Coin%s", Ui.short(n), if n == 1 then "" else "s")
end

local function renderBuildings(state: { [string]: any })
	titleLabel.Text = "Build"
	local now = ClientStore.now()
	local tab = tabRow("Buildings", BUILD_TABS, 1)
	local cards = grid(2, CARD)
	local scale = state.timeScale or 1
	local danger = Ui.colors.danger

	if tab == "Factories" then
		for i, id in sortedIds(Factories, Balance.enabledFactories) do
			local def = Factories[id]
			local preview = ClientStore.factoryPreview(id)
			local built = preview ~= nil and preview.built
			local locked = state.level < def.unlockLevel
			local card = buildCard(
				cards,
				i,
				{ kind = "Factory", id = id },
				def.displayName,
				if built
					then string.format("Queue %d / %d", #preview.queue, preview.slots)
					else string.format(
						"%s · %s",
						coinsText(def.buildCost),
						Timer.format(def.buildSeconds * scale)
					),
				factoryStatus(state, id),
				if not built and not locked and TownRules.population(state, now) < def.population then danger else nil,
				if locked and not built then def.unlockLevel else nil
			)
			if not locked or built then
				cardButton(card, if built then "Open" else "Build", true, function()
					Panels.open(id)
				end)
			end
		end
	elseif tab == "Animals" then
		for i, id in sortedIds(Animals.pens, Balance.enabledPens) do
			local def = Animals.pens[id]
			local pen = state.pens[id]
			local built = pen ~= nil and pen.built
			local locked = state.level < def.unlockLevel
			local card = buildCard(
				cards,
				i,
				{ kind = "Pen", id = id },
				def.displayName,
				if built
					then string.format("%d %s", #pen.animals, def.animalPlural)
					else string.format(
						"%s · %s",
						coinsText(def.buildCost),
						Timer.format(def.buildSeconds * scale)
					),
				penStatus(state, id),
				nil,
				if locked and not built then def.unlockLevel else nil
			)
			if not locked or built then
				cardButton(card, if built then "Open" else "Build", true, function()
					Panels.open("Pen", id)
				end)
			end
		end
	elseif tab == "Houses" then
		for i, id in sortedKeys(Town.houses) do
			local def = Town.houses[id]
			local built = TownRules.copiesBuilt(state, id)
			local allowed = TownRules.copiesAllowed(id, state.level)
			local nextLevel = TownRules.nextCopyLevel(state, id)
			local ok, reason = TownRules.canBuildHouse(state, id, now)
			local locked = if allowed == 0 then def.copyLevels[1] else nil
			local card = buildCard(
				cards,
				i,
				{ kind = "House", id = id },
				def.displayName,
				string.format(
					"+%d people · %s · %s",
					def.population,
					coinsText(def.coinCost),
					Timer.format(def.buildSeconds * scale)
				),
				if ok
					then string.format("%d built, %d more allowed", built, allowed - built)
					elseif built >= #def.copyLevels then string.format("All %d built", built)
					elseif built >= allowed and nextLevel then string.format(
						"%d built · next at level %d",
						built,
						nextLevel
					)
					else reason or "",
				if ok then nil else danger,
				locked
			)
			if locked == nil then
				cardButton(card, "Build", ok and state.currencies.Coins >= def.coinCost, function()
					Remotes.fire("Town_BuildHouse", id)
				end)
			end
		end
	elseif tab == "Town" then
		for i, id in sortedKeys(Town.community) do
			local def = Town.community[id]
			local entry = state.town.community[id]
			local locked = state.level < def.unlockLevel
			local parts, enough = {}, true
			for _, material in sortedKeys(Town.materials) do
				local need = def.materials[material]
				if need then
					local have = ClientStore.itemCount(material)
					enough = enough and have >= need
					table.insert(
						parts,
						string.format("%s %d/%d", Town.materials[material].displayName, math.min(have, need), need)
					)
				end
			end
			local status = if entry == nil
				then table.concat(parts, "  ")
				elseif TownRules.isDone(entry, now) then "Built"
				else "Building " .. Timer.format(Timer.remaining(entry.readyAt, now))
			local card = buildCard(
				cards,
				i,
				{ kind = "Community", id = id },
				def.displayName,
				string.format(
					"Cap +%d · %s · %s",
					def.capBonus,
					coinsText(def.coinCost),
					Timer.format(def.buildSeconds * scale)
				),
				status,
				if entry == nil and not enough then danger else nil,
				if locked and entry == nil then def.unlockLevel else nil
			)
			if entry == nil and not locked then
				local canPay = state.currencies.Coins >= def.coinCost
				local buy = if not enough and canPay
					then missingButton("community:" .. id, def.materials, cardProps(), "Community", id)
					else nil
				if buy then
					buy.Parent = card
				else
					cardButton(card, "Build", enough and canPay, function()
						Remotes.fire("Town_BuildCommunity", id)
					end)
				end
			end
		end
	elseif tab == "Decor" then
		local coupons = state.decorCoupons or {}
		for i, id in sortedKeys(Decor.items) do
			local def = Decor.items[id]
			local unlocked = state.level >= def.unlockLevel
			local room, full = DecorRules.hasRoom(state, id)
			local prepaid = coupons[id] or 0
			local card = buildCard(
				cards,
				i,
				{ kind = "Decor", id = id },
				def.displayName,
				if prepaid > 0
					then string.format("Prepaid x%d · +%d XP", prepaid, def.xp)
					else string.format("%s · +%d XP", coinsText(def.coinCost), def.xp),
				if not room
					then full :: string
					else string.format("%s, %d x %d tiles", def.category, def.size[1], def.size[2]),
				if room then nil else danger,
				if unlocked then nil else def.unlockLevel
			)
			if unlocked then
				cardButton(
					card,
					if prepaid > 0 then "Place free" else "Place",
					room and (prepaid > 0 or state.currencies.Coins >= def.coinCost),
					function()
						Panels.close()
						DecorPlacer.start(id)
					end
				)
			end
		end
		Ui.label("Decorations go down in front of you: walk to move, Turn to rotate, Place to put down.", {
			Size = UDim2.new(1, -8, 0, 36),
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			TextWrapped = true,
			LayoutOrder = 3,
			Parent = body,
		})
	end
end

local function renderPen(state: { [string]: any }, penId: string)
	local def = Animals.pens[penId]
	local pen = state.pens[penId]
	titleLabel.Text = def.displayName
	if pen == nil then
		return
	end
	local now = ClientStore.now()

	if not pen.built then
		local line = row(80, 1)
		if state.level < def.unlockLevel then
			Ui.label(string.format("Unlocks at level %d.", def.unlockLevel), { Parent = line })
		else
			Ui.label(
				string.format(
					"Build it for %d Coins (+%d XP). It comes with %d %s.",
					def.buildCost,
					def.xp,
					def.startAnimals,
					def.animalPlural
				),
				{ TextWrapped = true, Size = UDim2.new(1, 0, 0, 26), Parent = line }
			)
			local build = Ui.button("Build", function()
				Remotes.fire("Pen_Build", penId)
			end, { Position = UDim2.fromOffset(0, 30), Parent = line })
			Ui.setEnabled(build, state.currencies.Coins >= def.buildCost)
		end
		return
	end
	if not Pen.isOperational(pen, now) then
		local left = Timer.remaining(pen.constructionReadyAt, now)
		local line = row(42, 1)
		Ui.label("Building... " .. Timer.format(left) .. " left", { Size = UDim2.new(1, -170, 1, 0), Parent = line })
		gemButton("build:" .. penId, "Finish", Speedup.building(left), function()
			Remotes.fire("Pen_SpeedUp", penId)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(160, 30),
			Parent = line,
		})
		return
	end

	local counts = Pen.counts(pen, now)
	local near = Panels.nearPen(penId)
	local feedName = itemName(def.feed)
	local bags = ClientStore.itemCount(def.feed)
	local scoops = pen.feedLeft or 0

	local status = row(64, 1)
	Ui.label(
		string.format(
			"Animals %d / %d    Ready %d    Eating %d    Hungry %d",
			#pen.animals,
			Animals.maxAnimals,
			counts.ready,
			counts.producing,
			counts.hungry
		),
		{ Size = UDim2.new(1, 0, 0, 24), TextSize = 15, Parent = status }
	)
	local next_ = if counts.nextReadyAt
		then string.format("Next %s in %s.  ", def.productName, Timer.format(Timer.remaining(counts.nextReadyAt, now)))
		else ""
	Ui.label(
		string.format(
			"%s%s in the Barn: %d bag%s (1 bag feeds %d)%s",
			next_,
			feedName,
			bags,
			if bags == 1 then "" else "s",
			Animals.feedPerBag,
			if scoops > 0 then string.format(", %d left in the trough", scoops) else ""
		),
		{
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 26),
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			TextWrapped = true,
			Parent = status,
		}
	)

	local actions = row(42, 2)
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = actions,
	}, { Ui.list(6, true) })
	local collect = Ui.button("Collect", function()
		Remotes.fire("Pen_Collect", penId)
	end, { Size = UDim2.fromOffset(90, 30), LayoutOrder = 1, Parent = holder })
	Ui.setEnabled(collect, near and counts.ready > 0)
	local feed = Ui.button("Feed all", function()
		Remotes.fire("Pen_Feed", penId)
	end, { Size = UDim2.fromOffset(90, 30), LayoutOrder = 2, Parent = holder })
	Ui.setEnabled(feed, near and counts.hungry > 0 and (bags > 0 or scoops > 0))
	local cost = Pen.nextAnimalCost(def, pen)
	local buy = Ui.button(
		if cost then string.format("Buy a %s (%d)", def.animalName, cost) else "Pen is full",
		function()
			Remotes.fire("Pen_BuyAnimal", penId)
		end,
		{ Size = UDim2.fromOffset(150, 30), LayoutOrder = 3, Parent = holder }
	)
	Ui.setEnabled(buy, cost ~= nil and state.currencies.Coins >= cost)
	if counts.producing > 0 then
		gemButton("animals:" .. penId, "Finish all", Speedup.pen(pen, now), function()
			Remotes.fire("Pen_SpeedUp", penId)
		end, { Size = UDim2.fromOffset(180, 30), LayoutOrder = 3, Parent = row(42, 3) })
	end

	if not near then
		Ui.label("Walk to the pen to feed and collect.", {
			LayoutOrder = 4,
			TextColor3 = Ui.colors.muted,
			TextSize = 14,
			Parent = body,
		})
	elseif counts.hungry > 0 and bags == 0 and scoops == 0 then
		Ui.label(string.format("Make %s at the Feed Mill.", feedName), {
			LayoutOrder = 4,
			TextColor3 = Ui.colors.muted,
			TextSize = 14,
			Parent = body,
		})
	end
end

local function renderTown(state: { [string]: any })
	local now = ClientStore.now()
	local population = TownRules.population(state, now)
	local pending = TownRules.pending(state, now)
	local cap = TownRules.cap(state, now)
	titleLabel.Text = string.format("Town   Population %d / %d", population, cap)
	local order = 1
	local function heading(text: string)
		Ui.label(text, { Font = Enum.Font.GothamBold, LayoutOrder = order, Parent = body })
		order += 1
	end
	local function line(text: string, sub: string?): Frame
		local card = row(if sub then 46 else 36, order)
		order += 1
		Ui.label(text, { Size = UDim2.new(1, -170, 0, 22), TextSize = 15, Parent = card })
		if sub then
			Ui.label(sub, {
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.new(1, -170, 0, 18),
				TextColor3 = Ui.colors.muted,
				TextSize = 13,
				Parent = card,
			})
		end
		return card
	end
	local function rightButton(card: Frame, text: string, enabled: boolean, onClick: () -> ())
		local button = Ui.button(text, onClick, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(80, 30),
			Parent = card,
		})
		Ui.setEnabled(button, enabled)
	end
	if pending > 0 then
		Ui.label(string.format("+%d more when the Houses being built are done.", pending), {
			TextColor3 = Ui.colors.muted,
			TextSize = 14,
			LayoutOrder = order,
			Parent = body,
		})
		order += 1
	end

	-- Under construction (with a Gem finish)
	local building = {}
	for _, house in state.town.houses do
		if not TownRules.isDone(house, now) then
			table.insert(
				building,
				{ name = Town.houses[house.type].displayName, readyAt = house.readyAt, kind = "House", key = house.lot }
			)
		end
	end
	for stage, entry in state.land do
		if not TownRules.isDone(entry, now) then
			table.insert(
				building,
				{ name = Land.expansions[stage].displayName, readyAt = entry.readyAt, kind = "Land", key = stage }
			)
		end
	end
	for id, entry in state.town.community do
		if not TownRules.isDone(entry, now) then
			table.insert(
				building,
				{ name = Town.community[id].displayName, readyAt = entry.readyAt, kind = "Community", key = id }
			)
		end
	end
	if #building > 0 then
		heading("Building now")
		for _, item in building do
			local left = Timer.remaining(item.readyAt, now)
			local card = line(item.name .. "   " .. Timer.format(left) .. " left")
			gemButton("town:" .. item.kind .. tostring(item.key), "Finish", Speedup.building(left), function()
				Remotes.fire("Town_SpeedUp", item.kind, item.key)
			end, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(160, 30),
				Parent = card,
			})
		end
	end

	-- Houses
	heading("Houses (raise Population)")
	for _, id in sortedKeys(Town.houses) do
		local def = Town.houses[id]
		local built = TownRules.copiesBuilt(state, id)
		local allowed = TownRules.copiesAllowed(id, state.level)
		local nextLevel = TownRules.nextCopyLevel(state, id)
		if built == 0 and allowed == 0 and nextLevel and nextLevel > state.level + 2 then
			continue -- keep the list short: only what's close
		end
		local ok, reason = TownRules.canBuildHouse(state, id, now)
		local card = line(
			string.format(
				"%s   +%d   %d Coins   %s",
				def.displayName,
				def.population,
				def.coinCost,
				Timer.format(def.buildSeconds * (state.timeScale or 1))
			),
			string.format("%d built%s", built, if ok then "" elseif reason then "  ·  " .. reason else "")
		)
		rightButton(card, "Build", ok and state.currencies.Coins >= def.coinCost, function()
			Remotes.fire("Town_BuildHouse", id)
		end)
	end

	-- Materials first: Community Buildings need them (and the panel is long)
	heading("Building materials")
	for _, material in sortedKeys(Town.materials) do
		local card = line(
			string.format("%s   x%d", Town.materials[material].displayName, ClientStore.itemCount(material)),
			"From harvests and orders (level 5+)"
		)
		gemButton("material:" .. material, "Buy 1", Town.materialGemPrice, function()
			Remotes.fire("Town_BuyMaterial", material)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(160, 30),
			Parent = card,
		})
	end

	-- Community Buildings
	heading("Community Buildings (raise the Cap)")
	for _, id in sortedKeys(Town.community) do
		local def = Town.community[id]
		local entry = state.town.community[id]
		if entry == nil and def.unlockLevel > state.level + 2 then
			continue
		end
		local parts = {}
		local enough = true
		for _, material in sortedKeys(Town.materials) do
			local need = def.materials[material]
			if need then
				local have = ClientStore.itemCount(material)
				enough = enough and have >= need
				table.insert(
					parts,
					string.format("%s %d/%d", Town.materials[material].displayName, math.min(have, need), need)
				)
			end
		end
		local status = if entry == nil
			then (if state.level < def.unlockLevel then string.format("Lv %d   ", def.unlockLevel) else "") .. table.concat(
				parts,
				"  "
			)
			elseif TownRules.isDone(entry, now) then "Built"
			else "Building"
		local card = line(
			string.format(
				"%s   Cap +%d   %d Coins   %s",
				def.displayName,
				def.capBonus,
				def.coinCost,
				Timer.format(def.buildSeconds * (state.timeScale or 1))
			),
			status
		)
		local buy = nil
		if
			entry == nil
			and not enough
			and state.level >= def.unlockLevel
			and state.currencies.Coins >= def.coinCost
		then
			buy = missingButton("community:" .. id, def.materials, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(160, 30),
			}, "Community", id)
		end
		if buy then
			buy.Parent = card
		elseif entry == nil then
			rightButton(
				card,
				"Build",
				state.level >= def.unlockLevel and enough and state.currencies.Coins >= def.coinCost,
				function()
					Remotes.fire("Town_BuildCommunity", id)
				end
			)
		end
	end

	-- Building materials
	-- Land expansion and the fields Population has earned
	heading("Land")
	local waiting = TownRules.fieldsWaiting(state, now)
	if waiting > 0 then
		Ui.label(
			string.format(
				"%d new field%s waiting for land: clear the %s.",
				waiting,
				if waiting == 1 then "" else "s",
				Land.expansions[Land.extraFieldsStage].displayName
			),
			{ TextColor3 = Ui.colors.danger, TextSize = 14, LayoutOrder = order, Parent = body }
		)
		order += 1
	end
	local nextField = nil
	for _, unlock in Land.fields do
		if state.fields["F" .. unlock.field] == nil and population < unlock.population then
			nextField = unlock
			break
		end
	end
	if nextField then
		Ui.label(
			string.format("Next free field at Population %d.", nextField.population),
			{ TextColor3 = Ui.colors.muted, TextSize = 14, LayoutOrder = order, Parent = body }
		)
		order += 1
	end
	local expansion = TownRules.nextExpansion(state)
	if expansion then
		local can, why = TownRules.canExpand(state, now)
		local card = line(
			string.format(
				"%s   %d Coins   %s",
				expansion.displayName,
				expansion.coinCost,
				Timer.format(expansion.buildSeconds * (state.timeScale or 1))
			),
			if can then string.format("Expansion %d of %d", expansion.stage, #Land.expansions) else why
		)
		rightButton(card, "Clear", can and state.currencies.Coins >= expansion.coinCost, function()
			Remotes.fire("Town_Expand")
		end)
	else
		Ui.label("All land for now is cleared.", { TextColor3 = Ui.colors.muted, LayoutOrder = order, Parent = body })
		order += 1
	end

	heading("Decorations (placed in front of you)")
	for _, id in sortedKeys(Decor.items) do
		local def = Decor.items[id]
		if def.unlockLevel > state.level + 2 then
			continue
		end
		local unlocked = state.level >= def.unlockLevel
		local room, full = DecorRules.hasRoom(state, id)
		local prepaid = (state.decorCoupons or {})[id] or 0
		local card = line(
			if prepaid > 0
				then string.format("%s   Prepaid x%d   +%d XP", def.displayName, prepaid, def.xp)
				else string.format("%s   %d Coins   +%d XP", def.displayName, def.coinCost, def.xp),
			if not unlocked
				then string.format("Unlocks at level %d", def.unlockLevel)
				elseif not room then full :: string
				else string.format("%s, %d x %d tiles", def.category, def.size[1], def.size[2])
		)
		rightButton(
			card,
			if prepaid > 0 then "Free" else "Place",
			unlocked and room and (prepaid > 0 or state.currencies.Coins >= def.coinCost),
			function()
				Panels.close()
				DecorPlacer.start(id)
			end
		)
	end
end

-- A placed decoration: turn it or sell it back
local function renderDecor(state: { [string]: any }, index: number)
	local placed = state.decor[index]
	if placed == nil then
		Panels.close()
		return
	end
	local def = Decor.items[placed.id]
	titleLabel.Text = def.displayName
	local line = row(42, 1)
	Ui.button("Turn", function()
		Remotes.fire("Decor_Rotate", index)
	end, { Size = UDim2.fromOffset(100, 30), Parent = line })
	-- Two taps: the first arms it ("Sure?"), the second sells
	local refund = DecorRules.refund(placed.id)
	confirmButton(
		"sell:" .. index,
		string.format("Sell for %d Coins", refund),
		string.format("Sure? Sell for %d", refund),
		function()
			Remotes.fire("Decor_Sell", index)
			Panels.close()
		end,
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(180, 30),
			Parent = line,
		},
		true,
		Ui.colors.danger
	)
end

local function renderField(state: { [string]: any }, fieldId: string)
	local field = state.fields[fieldId]
	local now = ClientStore.now()
	if field == nil or field.crop == nil or Timer.isReady(field.readyAt, now) then
		Panels.close()
		return
	end
	local crop = Crops[field.crop]
	titleLabel.Text = crop.displayName
	local left = Timer.remaining(field.readyAt, now)
	local line = row(42, 1)
	Ui.label("Ready in " .. Timer.format(left), { Size = UDim2.new(1, -170, 1, 0), Parent = line })
	gemButton("field:" .. fieldId, "Finish", Speedup.production(left), function()
		Remotes.fire("Farm_SpeedUp", fieldId)
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(160, 30),
		Parent = line,
	})
	-- Speed Up All: every growing field of this crop
	local total, count = Speedup.allFields(state.fields, field.crop, now)
	-- The short Field frame holds one row; grow it by one row for Finish all
	frame.Size = UDim2.new(0.9, 0, 0, if count >= 2 then 124 + 48 else 124)
	if count >= 2 then
		local allLine = row(42, 2)
		Ui.label(
			string.format("All %d growing %s fields", count, crop.displayName),
			{ Size = UDim2.new(1, -170, 1, 0), Parent = allLine }
		)
		gemButton("fields:" .. field.crop, "Finish all", total, function()
			Remotes.fire("Farm_SpeedUpAll", field.crop)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(160, 30),
			Parent = allLine,
		})
	end
end

local function renderSeeds(state: { [string]: any })
	titleLabel.Text = "Plant a crop"
	for i, id in Balance.enabledCrops do
		local crop = Crops[id]
		local locked = state.level < crop.unlockLevel
		local cost = if crop.seedCost == 0
			then "free"
			else string.format("%d Coin%s", crop.seedCost, if crop.seedCost == 1 then "" else "s")
		local text = string.format(
			"%s   %s   %s",
			crop.displayName,
			cost,
			Timer.format(crop.growSeconds * (state.timeScale or 1))
		)
		if locked then
			text ..= string.format("   (level %d)", crop.unlockLevel)
		end
		local button = Ui.button(text, function()
			if currentArg then
				Remotes.fire("Farm_Plant", currentArg, id)
			end
			Panels.close()
		end, {
			Size = UDim2.new(1, -4, 0, 40),
			LayoutOrder = if id == state.settings.lastSeed then 0 else i,
			Parent = body,
		})
		Ui.setEnabled(button, not locked and state.currencies.Coins >= crop.seedCost)
	end
	Ui.label("Tip: hold the action button (E) and walk over empty beds to sow the same crop.", {
		TextColor3 = Ui.colors.muted,
		TextSize = 13,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 99,
		Parent = body,
	})
end

local function choiceRow(
	labelText: string,
	options: { any },
	isCurrent: (any) -> boolean,
	choose: (any) -> (),
	order: number
)
	local line = row(42, order)
	Ui.label(labelText, { Size = UDim2.new(0, 110, 1, 0), Parent = line })
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(110, 0),
		Size = UDim2.new(1, -110, 1, 0),
		Parent = line,
	}, { Ui.list(4, true) })
	for i, option in options do
		local button = Ui.button(tostring(option), function()
			choose(option)
		end, { Size = UDim2.fromOffset(52, 28), LayoutOrder = i, Parent = holder })
		if isCurrent(option) then
			button.BackgroundColor3 = Ui.colors.selected
		end
	end
end

-- Robux prices come from Roblox at runtime (regional pricing), cached per id; never hard-coded
local robuxPrices: { [string]: number | false } = {}
local function robuxPrice(id: number, infoType: Enum.InfoType): string
	local cacheKey = infoType.Name .. id
	local price = robuxPrices[cacheKey]
	if price == nil then
		robuxPrices[cacheKey] = false
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
			if ok and info and info.PriceInRobux then
				robuxPrices[cacheKey] = info.PriceInRobux
				Panels.refresh()
			end
		end)
	end
	return if price then string.format("R$ %d", price) else "R$ ..."
end

-- The Shop: Gem packs, the one-time Starter Pack and the Big Barn pass (10 Monetization).
-- The server checks every buy and shows the Roblox prompt.
local function renderShop(state: { [string]: any })
	titleLabel.Text = "Shop"
	local order = 1
	local function item(text: string, sub: string, button: string, enabled: boolean, onClick: () -> ())
		local card = row(48, order)
		order += 1
		Ui.label(text, { Size = UDim2.new(1, -130, 0, 22), Font = Enum.Font.GothamBold, Parent = card })
		Ui.label(sub, {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -130, 0, 18),
			TextColor3 = Ui.colors.muted,
			TextSize = 13,
			Parent = card,
		})
		local b = Ui.button(button, onClick, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 6),
			Size = UDim2.fromOffset(120, 32),
			Parent = card,
		})
		Ui.setEnabled(b, enabled, Ui.colors.gems)
	end
	local purchases = state.purchases or { bought = {}, passes = {} }
	for _, key in sortedKeys(Products.products) do
		local product = Products.products[key]
		local soon = product.productId == 0
		local sub = string.format("%d Gems", product.gems)
		if product.tools then
			sub ..= " + a Shovel, an Axe and a Saw. Once per farm"
		end
		local hidden = product.fromLevel ~= nil and state.level < product.fromLevel
		if hidden then
			continue
		end
		local owned = product.once and purchases.bought[key]
		item(
			product.displayName,
			sub,
			if soon
				then "Coming soon"
				elseif owned then "Bought"
				else robuxPrice(product.productId, Enum.InfoType.Product),
			not soon and not owned,
			function()
				Remotes.fire("Shop_Prompt", key)
			end
		)
	end
	for _, key in sortedKeys(Products.passes) do
		local pass = Products.passes[key]
		local soon = pass.passId == 0
		local owned = purchases.passes[key]
		item(
			pass.displayName,
			string.format("+%d Barn space, for good", pass.barnBonus),
			if soon then "Coming soon" elseif owned then "Owned" else robuxPrice(pass.passId, Enum.InfoType.GamePass),
			not soon and not owned,
			function()
				Remotes.fire("Shop_PromptPass", key)
			end
		)
	end
	Ui.label("Gems speed things up. Everything in the game can also be earned by playing.", {
		Size = UDim2.new(1, 0, 0, 36), -- two lines on a phone
		TextColor3 = Ui.colors.muted,
		TextSize = 13,
		TextWrapped = true,
		LayoutOrder = order,
		Parent = body,
	})
end

local function renderAway()
	titleLabel.Text = "While you were away"
	for i, text in ClientStore.away do
		Ui.label("• " .. text, { TextWrapped = true, LayoutOrder = i, Parent = body })
	end
	Ui.button("OK", function()
		Panels.close()
	end, { Size = UDim2.fromOffset(100, 34), LayoutOrder = #ClientStore.away + 1, Parent = body })
end

local function renderDebug(state: { [string]: any })
	titleLabel.Text = "Greybox tuning (Studio)"
	local settings = ClientStore.settings
	choiceRow("Reach", Balance.reachOptions, function(v)
		return settings.reach == v
	end, function(v)
		ClientStore.setSetting("reach", v)
	end, 1)
	choiceRow("Walk speed", Balance.walkSpeedOptions, function(v)
		return settings.walkSpeed == v
	end, function(v)
		ClientStore.setSetting("walkSpeed", v)
	end, 2)
	choiceRow("Timer length", Balance.timeScaleOptions, function(v)
		return (state.timeScale or 1) == v
	end, function(v)
		Remotes.fire("Debug_SetTimeScale", v)
	end, 3)
	Ui.label(
		"Timer length only changes timers you start after picking it; crops and Bread already growing keep their time.",
		{
			TextColor3 = Ui.colors.muted,
			TextSize = 14,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 4,
			Parent = body,
		}
	)
	-- One tap, acting on press: the panel re-renders on every state push, which can swap a
	-- button out between press and release and lose a plain click. Press and Activated can
	-- both arrive for one tap, so the first one wins.
	local function devButton(text: string, remote: string, width: number, order: number)
		local function fire()
			if time() - lastDevTap < 0.35 then
				return
			end
			lastDevTap = time()
			print("[Dev] " .. remote)
			Remotes.fire(remote)
		end
		local button = Ui.button(text, fire, { Size = UDim2.fromOffset(width, 34), LayoutOrder = order, Parent = body })
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				fire()
			end
		end)
	end
	devButton("Replay the first-session guide", "Debug_RestartTutorial", 260, 5)
	devButton("Pretend I was away (summary + daily gift)", "Debug_Away", 320, 6)
	devButton("Build everything (ignores level and Population)", "Debug_BuildAll", 360, 7)
	devButton("+500 Gems, +5,000 Coins, +5 of each tool", "Debug_Grant", 340, 8)
	devButton("Fuzz every remote with junk (farm restored after)", "Debug_Fuzz", 380, 9)
	devButton("+1 level (opens the content bank past the cap)", "Debug_LevelUp", 380, 10)
end

---------------------------------------------------------------------------------------------

-- Panels that live in their own files (UI/Social): name -> renderer into the shared window
local extraPanels: { [string]: (state: { [string]: any }, body: ScrollingFrame, title: TextLabel, arg: string?) -> () } =
	{}
-- Panels with nothing counting down skip the once-a-second refresh
local staticPanels: { [string]: boolean } = { Seeds = true, Debug = true }

-- opts.static: the panel has no countdowns, so it only re-renders when something changes
function Panels.register(
	name: string,
	renderer: (state: { [string]: any }, body: ScrollingFrame, title: TextLabel, arg: string?) -> (),
	opts: { static: boolean? }?
)
	extraPanels[name] = renderer
	staticPanels[name] = opts ~= nil and opts.static == true
end

-- Keyboard and gamepad UI navigation (\ on a keyboard) selects a button; every render
-- rebuilds the panel, so find the same spot in the new tree and select it again.
local function selectionPath(): { number }?
	local selected = GuiService.SelectedObject
	if selected == nil or not selected:IsDescendantOf(body) then
		return nil
	end
	local path = {}
	local node: Instance = selected
	while node ~= body do
		local parent = node.Parent :: Instance
		table.insert(path, 1, table.find(parent:GetChildren(), node) or 1)
		node = parent
	end
	return path
end

local function reselect(path: { number }?)
	if path == nil then
		return
	end
	local node: Instance? = body
	for _, index in path do
		node = node and node:GetChildren()[index]
	end
	if node and node:IsA("GuiObject") and node.Selectable then
		GuiService.SelectedObject = node
	end
end

local function render()
	local state = ClientStore.state
	if current == nil or state == nil then
		return
	end
	local selected = selectionPath()
	releaseIcons()
	releasePictures()
	tabNames = {}
	Ui.clear(body)
	if current == "Orders" then
		renderOrders(state)
	elseif current == "Barn" then
		renderBarn(state)
	elseif current == "Buildings" then
		renderBuildings(state)
	elseif current == "Pen" and currentArg then
		renderPen(state, currentArg)
	elseif Factories[current] then
		renderFactory(state, current)
	elseif current == "Town" then
		renderTown(state)
	elseif current == "Field" and currentArg then
		renderField(state, currentArg)
	elseif current == "Seeds" then
		renderSeeds(state)
	elseif current == "Decor" and currentArg then
		renderDecor(state, tonumber(currentArg) :: number)
	elseif current == "Shop" then
		renderShop(state)
	elseif current == "Away" then
		renderAway()
	elseif current == "Debug" then
		renderDebug(state)
	elseif extraPanels[current] then
		extraPanels[current](state, body, titleLabel, currentArg)
	end
	reselect(selected)
end

Panels.refresh = render

local FULL_SIZE = UDim2.fromScale(0.9, 0.62)
local COMPACT: { [string]: number } = { Field = 124 }
-- Phones in landscape (11 UI & UX, mobile-first) are only ~390 px tall: a centred panel at
-- 62% showed one row. Below this height the panel fills the space under the HUD's top row,
-- down to the bottom edge (over the HUD's bottom row: one panel at a time).
local SHORT_SCREEN = 560

local function layout()
	local camera = Workspace.CurrentCamera
	local short = camera ~= nil and camera.ViewportSize.Y < SHORT_SCREEN
	local compact = if current then COMPACT[current] else nil
	if short then
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Position = UDim2.new(0.5, 0, 1, -6)
		frame.Size = if compact then UDim2.new(0.9, 0, 0, compact) else UDim2.new(0.9, 0, 1, -70)
	else
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.55)
		frame.Size = if compact then UDim2.new(0.9, 0, 0, compact) else FULL_SIZE
	end
end

function Panels.open(name: string, arg: string?)
	if name == "Debug" and not RunService:IsStudio() then
		return
	end
	if current == name and currentArg == arg and name ~= "Seeds" then
		Panels.close()
		return
	end
	current = name
	currentArg = arg
	if name == "Shop" then
		Remotes.fire("Shop_Opened") -- analytics: Shop funnel step 1
	end
	-- One-row panels get a short frame instead of the full-size one
	layout()
	if not frame.Visible then
		Ui.theme.Motion.popIn(frame)
	end
	frame.Visible = true
	render()
end

function Panels.close()
	current = nil
	currentArg = nil
	frame.Visible = false
end

function Panels.isOpen(): boolean
	return current ~= nil
end

function Panels.isShowing(name: string): boolean
	return current == name
end

function Panels.init()
	gui = Ui.new("ScreenGui", {
		Name = "FarmPanels",
		ResetOnSpawn = false,
		-- The themed window layers its parts by ZIndex among siblings; Global would draw
		-- the card over every label built at the default ZIndex.
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- The window look (ribbon title, round close button, paper inset) comes from the theme
	local window = Ui.theme.Kit.panel(Panels.close)
	frame = window.root
	layout()
	frame.Visible = false
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(480, 420) }).Parent = frame
	frame.Parent = gui
	titleLabel = window.title
	body = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.colors.panelEdge,
		Parent = window.body,
	}, { Ui.list(6), Ui.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }) })

	ClientStore.changed.Event:Connect(render)
	ClientStore.settingsChanged.Event:Connect(render)
	task.spawn(function()
		while true do
			task.wait(1)
			if current ~= nil and not staticPanels[current] and not anyArmed() then
				render()
			end
		end
	end)
	-- Rotating a phone or resizing the window re-lays the panel out
	local function watch(camera: Camera?)
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
	end
	watch(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watch(Workspace.CurrentCamera)
	end)
end

return Panels
