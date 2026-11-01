--!strict
-- The Tool Trader panel (Config/ToolTrader, shared/ToolTrader): build it, open up to two more
-- slots, then take or dump each slot's offer of power tools for building materials. Shows
-- what the Barn holds of each material and tool, so the player can see what's affordable.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.ToolTrader)
local Items = require(Shared.Items)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local ToolTrader = require(Shared.ToolTrader)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local ToolTraderUi = {}

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

local function fullButton(text: string, order: number, body: Instance, fn: () -> ()): TextButton
	return Ui.button(text, fn, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order, Parent = body })
end

local function name(item: string): string
	local def = Items[item]
	return if def then def.displayName else item
end

local function have(state: { [string]: any }, item: string): number
	return state.inventory[item] or 0
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Tool Trader"
	local trader = state.toolTrader
	if trader == nil then
		return
	end
	local now = ClientStore.now()
	if trader.readyAt == nil then
		if state.level < Config.unlockLevel then
			line(string.format("The Tool Trader opens at level %d.", Config.unlockLevel), 1, body)
			return
		end
		line(
			"From level 60 Community Buildings also need power tools, and the Tool Trader is the only "
				.. "place to get them. It trades Bricks, Panes and Planks for Power Drills, Power Saws and "
				.. "(from level 62) Jackhammers.",
			1,
			body,
			74
		)
		line(
			string.format(
				"Build it for %d Coins (Population %d). Takes %s.  +%d XP",
				Config.buildCoins,
				Config.population,
				Timer.format(Config.buildSeconds),
				Config.buildXp
			),
			2,
			body,
			38
		)
		local button = fullButton("Build the Tool Trader", 3, body, function()
			Remotes.fire("Trader_Build")
		end)
		Ui.setEnabled(button, state.currencies.Coins >= Config.buildCoins)
		-- The Place bar, the same one a new building offers (Main's Place handler closes this
		-- panel and picks the building up)
		Ui.button("Choose its spot", function()
			Hud.popup({ kind = "Place", key = "trader:ToolTrader" })
		end, { Size = UDim2.new(1, -8, 0, 36), LayoutOrder = 4, Parent = body })
		line("Or press Move (M) any time to walk it somewhere else.", 5, body, 22, Ui.colors.muted)
		return
	end
	if now < trader.readyAt then
		local left = trader.readyAt - now
		line("Building: " .. Timer.format(left) .. " left.", 1, body)
		Panels.gemButton("TraderSpeedUp", "Finish now", Speedup.building(left), function()
			Remotes.fire("Trader_SpeedUp")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = body })
		return
	end

	-- What the Barn holds
	local stock = {}
	for _, id in Config.materials do
		table.insert(stock, string.format("%s %d", name(id), have(state, id)))
	end
	for _, id in ToolTrader.toolsAt(state.level) do
		table.insert(stock, string.format("%s %d", name(id), have(state, id)))
	end
	line("In the Barn: " .. table.concat(stock, ", "), 1, body, 38, Ui.colors.muted)

	local order = 2
	for i = 1, trader.slots or 1 do
		local offer = trader.offers[tostring(i)]
		if offer and offer.tools and offer.cost then
			local enough = true
			for id, qty in offer.cost do
				enough = enough and have(state, id) >= qty
			end
			line(
				string.format(
					"Offer %d: %s for %s",
					i,
					ToolTrader.describe(offer.tools, name),
					ToolTrader.describe(offer.cost, name)
				),
				order,
				body,
				38,
				if enough then Ui.colors.text else Ui.colors.danger
			)
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, -8, 0, 40)
			row.LayoutOrder = order + 1
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Padding = UDim.new(0, 6)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = row
			local trade = Ui.button("Trade", function()
				Remotes.fire("Trader_Trade", i)
			end, { Size = UDim2.new(0.6, -6, 1, 0), LayoutOrder = 1, Parent = row })
			Ui.setEnabled(trade, enough)
			Ui.button("Dump (new offer in 1 h)", function()
				Remotes.fire("Trader_Dump", i)
			end, { Size = UDim2.new(0.4, 0, 1, 0), LayoutOrder = 2, Parent = row })
			row.Parent = body
		elseif offer and offer.waitUntil and now < offer.waitUntil then
			local left = offer.waitUntil - now
			line(string.format("Offer %d: a new one comes in %s.", i, Timer.format(left)), order, body)
			Panels.gemButton("TraderSkip" .. i, "Bring it now", Speedup.production(left), function()
				Remotes.fire("Trader_Skip", i)
			end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order + 1, Parent = body })
		else
			line(string.format("Offer %d: on its way.", i), order, body, nil, Ui.colors.muted)
		end
		order += 2
	end

	local coins = Config.slotCoins[(trader.slots or 1) + 1]
	if coins then
		local button = fullButton(string.format("Another offer slot: %d Coins", coins), order, body, function()
			Remotes.fire("Trader_BuySlot")
		end)
		Ui.setEnabled(button, state.currencies.Coins >= coins)
		order += 1
	end
	line(string.format("Trades so far: %d", trader.trades or 0), order, body, nil, Ui.colors.muted)
end

function ToolTraderUi.init()
	Panels.register("ToolTrader", render)
end

return ToolTraderUi
