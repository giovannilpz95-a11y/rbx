--!strict
-- The Blimp Mast panel (Features/F04 Airship Freight, shared/Blimp): repair the mast, then
-- load the Cargo Blimp's crates from the Barn while it's docked and send it off. Each crate
-- pays Coins and XP at once; full rows pay a bonus when it leaves, and loading every crate
-- adds the Full Hold chest shown here up front. While it's away, Next Flight shows the goods
-- the next blimp will ask for.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Blimp = require(Shared.Blimp)
local Config = require(Shared.Config.Blimp)
local Items = require(Shared.Items)
local Land = require(Shared.Config.Land)
local QuarryConfig = require(Shared.Config.Quarry)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local Tools = require(Shared.Config.Tools)
local TownRules = require(Shared.TownRules)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local BlimpUi = {}

local CRATE_HEIGHT = 88
local BUTTON_WIDTH = 176 -- fits "Buy missing  70 Gems"
local ARM_SECONDS = 10
local sendArmedAt = 0 -- a send that leaves a row unpaid takes a second tap within ARM_SECONDS

-- Shrink a button's text to fit it rather than clip it (big prices, larger text settings)
local function fit(button: TextButton?)
	if button == nil then
		return
	end
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = button.TextSize
	limit.MinTextSize = 9
	limit.Parent = button
	button.TextScaled = true
end

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

local function heading(text: string, order: number, body: Instance)
	return Ui.label(text, {
		Font = Ui.theme.Type.display,
		TextSize = 16,
		Size = UDim2.new(1, -8, 0, 24),
		LayoutOrder = order,
		Parent = body,
	})
end

local function prizeText(prize: { item: string, qty: number }): string
	local tool = Tools.tools[prize.item]
	local name = if tool
		then (if prize.qty == 1 then tool.displayName else tool.plural)
		elseif prize.item == QuarryConfig.pickaxe then (if prize.qty == 1 then "Pickaxe" else "Pickaxes")
		elseif Items[prize.item] then Items[prize.item].displayName
		else prize.item
	return string.format("%d %s", prize.qty, name)
end

local function chestText(chest: { { item: string, qty: number } }): string
	local names = {}
	for _, prize in chest do
		table.insert(names, prizeText(prize))
	end
	return "Full Hold chest: " .. table.concat(names, ", ")
end

-- The goods a load asks for, without the amounts (Township's preview shows only the goods)
local function nextFlight(load: Blimp.Load?, order: number, body: Instance): number
	if load == nil or #load.rows == 0 then
		return order
	end
	heading("Next Flight", order, body)
	local goods, seen = {}, {}
	for _, row in load.rows do
		for _, crate in row do
			if not seen[crate.item] then
				seen[crate.item] = true
				table.insert(goods, crate.item)
			end
		end
	end
	local parts = {}
	for _, item in goods do
		table.insert(parts, string.format("%s (%d)", Items[item].displayName, ClientStore.itemCount(item)))
	end
	line("Goods it will ask for (in your Barn): " .. table.concat(parts, ", "), order + 1, body, 54)
	line(chestText(load.chest), order + 2, body, 38, Ui.colors.muted)
	return order + 3
end

local function crateCard(row: number, slot: number, crate: Blimp.Crate, body: Instance, order: number)
	local card = Ui.card({ Size = UDim2.new(1, -8, 0, CRATE_HEIGHT), LayoutOrder = order, Parent = body })
	local def = Items[crate.item]
	local have = ClientStore.itemCount(crate.item)
	local coins, xp = Blimp.crateRewards(crate)
	Ui.label(string.format("%d %s", crate.qty, def.displayName), {
		Font = Ui.theme.Type.display,
		TextSize = 15,
		Size = UDim2.new(1, -(BUTTON_WIDTH + 16), 0, 22),
		Position = UDim2.fromOffset(8, 4),
		Parent = card,
	})
	local done = crate.filledBy ~= nil
	local loadedText = if crate.filledBy == Players.LocalPlayer.UserId
		then "Loaded"
		else "Loaded by a neighbor. Thank you!"
	Ui.label(if done then loadedText else string.format("You have %d   ·   +%d Coins  +%d XP", have, coins, xp), {
		TextSize = 13,
		TextColor3 = if done then Ui.colors.ready elseif have >= crate.qty then Ui.colors.muted else Ui.colors.danger,
		Size = UDim2.new(1, -(BUTTON_WIDTH + 16), 0, 18),
		Position = UDim2.fromOffset(8, 28),
		Parent = card,
	})
	if done then
		return
	end
	local props = {
		Size = UDim2.fromOffset(BUTTON_WIDTH, 36),
		Position = UDim2.new(1, -(BUTTON_WIDTH + 6), 0, 6),
		Parent = card,
	}
	-- Help flag: neighbors on this server can load a flagged crate from their own Barn (one a row)
	local flag = Ui.button(if crate.flagged then "Help asked ✓" else "Ask for help", function()
		Remotes.fire("Blimp_Flag", row, slot)
	end, {
		Size = UDim2.fromOffset(BUTTON_WIDTH, 34),
		Position = UDim2.new(1, -(BUTTON_WIDTH + 6), 0, 48),
		Parent = card,
	})
	fit(flag)
	if crate.flagged then
		Ui.setEnabled(flag, true, Ui.colors.selected)
	end
	if have >= crate.qty then
		fit(Ui.button("Load", function()
			Remotes.fire("Blimp_Fill", row, slot)
		end, props))
	else
		local button = Panels.missingButton(
			string.format("blimp:%d:%d", row, slot),
			{ [crate.item] = crate.qty },
			props,
			"Blimp",
			row,
			slot
		)
		fit(button)
		if button == nil then
			Ui.setEnabled(Ui.button("Load", function() end, props), false)
		end
	end
end

local function docked(state: { [string]: any }, body: ScrollingFrame, now: number)
	local blimp = state.blimp
	local load = blimp.load :: Blimp.Load
	line(
		string.format("The Cargo Blimp leaves in %s.", Timer.format(math.max(0, blimp.leavesAt - now))),
		1,
		body,
		nil,
		Ui.colors.warn
	)
	line(
		"Load its crates from your Barn. Each full row pays a bonus when it leaves; if time runs "
			.. "out, it leaves with no row bonus. Ask for help with one crate a row and neighbors on "
			.. "this server can load it from their own Barns.",
		2,
		body,
		72,
		Ui.colors.muted
	)
	local order = 3
	for r, row in load.rows do
		local full = true
		for _, crate in row do
			full = full and crate.filledBy ~= nil
		end
		local coins, miles = Blimp.rowRewards(row, r)
		line(
			string.format("Row %d%s: +%d Coins, +%d Sky Miles", r, if full then " (full)" else "", coins, miles),
			order,
			body,
			nil,
			if full then Ui.colors.ready else Ui.colors.text
		)
		order += 1
		for c, crate in row do
			crateCard(r, c, crate, body, order)
			order += 1
		end
	end
	line(chestText(load.chest) .. " (every crate loaded)", order, body, 38, Ui.colors.muted)
	order += 1

	local payout = Blimp.payout(load)
	local armed = os.clock() - sendArmedAt < ARM_SECONDS
	local text
	if armed then
		text = "Tap again to send (rows not full get no bonus)"
	elseif #payout.rows == 0 then
		text = "Send off (no full rows: no bonus)"
	else
		text = string.format(
			"Send off: +%d Coins, +%d Sky Miles%s",
			payout.coins,
			payout.miles,
			if payout.chest then " + chest" else ""
		)
	end
	local send = Ui.button(text, function()
		-- `armed` is what the button shows, so a tap on "Tap again" always sends, however long
		-- the panel sat before it went back to the plain text
		if #payout.rows < #load.rows and not armed then
			local at = os.clock()
			sendArmedAt = at
			Panels.refresh()
			task.delay(ARM_SECONDS, function()
				if sendArmedAt == at then
					Panels.refresh()
				end
			end)
			return
		end
		sendArmedAt = 0
		Remotes.fire("Blimp_Send")
	end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order, Parent = body })
	if armed then
		Ui.setEnabled(send, true, Ui.colors.accent)
	end
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Blimp Mast"
	local blimp = state.blimp
	if blimp == nil then
		return
	end
	local now = ClientStore.now()
	if blimp.readyAt == nil then
		if state.level < Config.unlockLevel then
			line(string.format("The Blimp Mast can be repaired at level %d.", Config.unlockLevel), 1, body)
			return
		end
		line(
			"Repair the Blimp Mast and a Cargo Blimp will dock here with crates of goods to load. "
				.. "Each crate pays Coins and XP, each full row a bonus, and a full hold a chest.",
			1,
			body,
			56
		)
		line(
			string.format(
				"Repair it for %d Coins. Takes %s.  +%d XP",
				Config.repairCoins,
				Timer.format(Config.repairSeconds),
				Config.repairXp
			),
			2,
			body
		)
		local landOk = TownRules.landDone(state, Config.land, now)
		if not landOk then
			line(
				string.format("It stands in the %s. Clear that land first.", Land.expansions[Config.land].displayName),
				3,
				body,
				nil,
				Ui.colors.danger
			)
		end
		local button = Ui.button("Repair", function()
			Remotes.fire("Blimp_Repair")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 4, Parent = body })
		Ui.setEnabled(button, landOk and state.currencies.Coins >= Config.repairCoins)
		return
	end
	if now < blimp.readyAt then
		local left = blimp.readyAt - now
		line("Repairing: " .. Timer.format(left) .. " left. The first Cargo Blimp docks when it's done.", 1, body, 38)
		Panels.gemButton("BlimpSpeedUp", "Finish now", Speedup.building(left), function()
			Remotes.fire("Blimp_SpeedUp")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = body })
		nextFlight(blimp.load, 3, body)
		return
	end
	if blimp.leavesAt ~= nil and blimp.load then
		docked(state, body, now)
		return
	end
	-- Away: waiting for the next blimp
	local order = 1
	if blimp.arrivesAt and now < blimp.arrivesAt then
		line("The next Cargo Blimp docks in " .. Timer.format(blimp.arrivesAt - now) .. ".", order, body)
		local cost = Blimp.skipCost(state, now)
		Panels.gemButton("BlimpSkip", if cost > 0 then "Call it now" else "Call it now (free)", cost, function()
			Remotes.fire("Blimp_Skip")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order + 1, Parent = body }, cost == 0)
		order += 2
	else
		line("The next Cargo Blimp is due now.", order, body)
		order += 1
	end
	order = nextFlight(blimp.load, order, body)
	line(
		string.format(
			"Sky Miles %d   ·   Flights %d   ·   Full holds %d",
			blimp.skyMiles or 0,
			blimp.flights or 0,
			blimp.fullHolds or 0
		),
		order,
		body,
		nil,
		Ui.colors.muted
	)
end

function BlimpUi.init()
	Panels.register("Blimp", render)
end

return BlimpUi
