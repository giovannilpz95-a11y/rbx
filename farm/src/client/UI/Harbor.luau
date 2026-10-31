--!strict
-- The Harbor panel (Features/F02 Harbor & Far Isles, shared/Harbor): repair the Harbor, then
-- send Sailboats to the Far Isles, with a Ballast Bar for better odds, unload them when they're
-- back, open the next isle, buy more boats and open the day's Driftwood Crate. Every chance is
-- shown before a boat leaves.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Isles)
local Harbor = require(Shared.Harbor)
local DailyRules = require(Shared.Daily)
local Items = require(Shared.Items)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local Tools = require(Shared.Config.Tools)
local TownRules = require(Shared.TownRules)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local HarborUi = {}

local chosenBar: string? = nil -- the Ballast Bar the next boat takes along (nil = none)

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

local function fullButton(text: string, order: number, body: Instance, fn: () -> ()): TextButton
	return Ui.button(text, fn, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order, Parent = body })
end

local function pct(p: number): string
	return string.format("%d%%", math.floor(p * 100 + 0.5))
end

local function name(item: string): string
	local def = Items[item]
	return if def then def.displayName else item
end

-- "Peaches x3 · Watermelons 80% · Plums 53% · Sea Chest 10%"
local function oddsText(isle: Config.IsleDef, bar: string?): string
	local u, r, c = Harbor.odds(isle.id, bar)
	local parts = {
		string.format("%s x%d", name(isle.goods[1]), Config.commonQty),
		string.format("%s %s", name(isle.goods[2]), pct(u)),
		string.format("%s %s", name(isle.goods[3]), pct(r)),
	}
	if c > 0 then
		table.insert(parts, "Sea Chest " .. pct(c))
	end
	return table.concat(parts, "  ·  ")
end

local function barPicker(order: number, body: Instance)
	heading("Ballast Bar", order, body)
	line(
		"Send one Bar along and the rarer goods come back more often, with a chance of a Sea Chest.",
		order + 1,
		body,
		38,
		Ui.colors.muted
	)
	local row = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 36),
		LayoutOrder = order + 2,
		Parent = body,
	}, { Ui.list(4, true) })
	local options: { string | false } = { false }
	for _, bar in Config.bars do
		table.insert(options, bar)
	end
	if chosenBar and ClientStore.itemCount(chosenBar) < 1 then
		chosenBar = nil
	end
	for _, option in options do
		local bar = if option == false then nil else option :: string
		local have = if bar then ClientStore.itemCount(bar) else 0
		local label = if bar then string.format("%s (%d)", (name(bar):gsub(" Bar", "")), have) else "None"
		local button = Ui.button(label, function()
			chosenBar = bar
			Panels.refresh()
		end, { Size = UDim2.new(0.2, -4, 1, 0), Parent = row })
		-- Shrink the text to fit rather than clip it ("Platinum (22)" on a phone)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = button.TextSize
		limit.MinTextSize = 9
		limit.Parent = button
		button.TextScaled = true
		local picked = chosenBar == bar
		Ui.setEnabled(button, bar == nil or have > 0, if picked then Ui.colors.selected else nil)
	end
end

local function boatCard(state: { [string]: any }, index: number, boat: { [string]: any }, order: number, body: Instance)
	local now = ClientStore.now()
	local card = Ui.card({
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = body,
	})
	Ui.padding(6).Parent = card
	Ui.list(4).Parent = card
	local function text(t: string, o: number, color: Color3?, height: number?)
		Ui.label(t, {
			TextWrapped = true,
			TextSize = 14,
			TextColor3 = color or Ui.colors.text,
			Size = UDim2.new(1, 0, 0, height or 20),
			LayoutOrder = o,
			Parent = card,
		})
	end
	local props = function(o: number): { [string]: any }
		return { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = o, Parent = card }
	end
	if boat.isle == nil then
		text(string.format("Sailboat %d: in port", index), 1)
		local o = 2
		for _, isle in Config.isles do
			if Harbor.isleOpen(state, isle.id, now) then
				local button = Ui.button(
					string.format(
						"Sail to %s: %d Coins, %s%s",
						isle.displayName,
						isle.sendCoins,
						Timer.format(isle.tripSeconds),
						if chosenBar then " + " .. name(chosenBar) else ""
					),
					function()
						Remotes.fire("Harbor_Send", index, isle.id, chosenBar or false)
					end,
					props(o)
				)
				Ui.setEnabled(button, state.currencies.Coins >= isle.sendCoins)
				o += 1
			end
		end
		return
	end
	local isle = Config.byId[boat.isle]
	if Harbor.isBack(boat :: any, now) then
		local parts = {}
		for _, crate in boat.cargo or {} do
			table.insert(parts, string.format("%d %s", crate.qty, name(crate.item)))
		end
		text(string.format("Sailboat %d is back from %s!", index, isle.displayName), 1, Ui.colors.ready)
		text(table.concat(parts, ", ") .. (if boat.chest then ", and a Sea Chest" else ""), 2, nil, 38)
		local units = Harbor.cargoUnits(boat :: any)
		local room = state.barnCapacity - state.barnUsed
		local button = Ui.button(if room >= units then "Unload" else "Barn full: make room", function()
			Remotes.fire("Harbor_Unload", index)
		end, props(3))
		Ui.setEnabled(button, room >= units)
		return
	end
	local left = boat.returnAt - now
	text(
		string.format(
			"Sailboat %d: sailing to %s%s, back in %s",
			index,
			isle.displayName,
			if boat.bar then " with a " .. name(boat.bar) else "",
			Timer.format(left)
		),
		1,
		nil,
		38
	)
	local cost = Harbor.skipCost(boat :: any, now)
	Panels.gemButton(
		"HarborSkip" .. index,
		if cost > 0 then "Bring it home" else "Bring it home (free)",
		cost,
		function()
			Remotes.fire("Harbor_Skip", index)
		end,
		props(2),
		cost == 0
	)
end

local function isleCard(state: { [string]: any }, isle: Config.IsleDef, order: number, body: Instance)
	local now = ClientStore.now()
	local card = Ui.card({
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = body,
	})
	Ui.padding(6).Parent = card
	Ui.list(3).Parent = card
	local function text(t: string, o: number, color: Color3?, height: number?)
		Ui.label(t, {
			TextWrapped = true,
			TextSize = 14,
			TextColor3 = color or Ui.colors.text,
			Size = UDim2.new(1, 0, 0, height or 20),
			LayoutOrder = o,
			Parent = card,
		})
	end
	local status = Harbor.isleState(state, isle.id, now)
	local trips = state.harbor.trips[isle.id] or 0
	text(
		string.format(
			"%s  (%s)",
			isle.displayName,
			if status == "Open" then string.format("trips: %d", trips) else status
		),
		1,
		if status == "Open" then Ui.colors.ready else nil
	)
	text(
		isle.theme .. string.format(". %d Coins a trip, %s.", isle.sendCoins, Timer.format(isle.tripSeconds)),
		2,
		Ui.colors.muted,
		38
	)
	text(oddsText(isle, chosenBar), 3, nil, 38)
	if status == "Opening" then
		local left = state.harbor.isles[isle.id].readyAt - now
		text("Opening: " .. Timer.format(left) .. " left", 4)
		Panels.gemButton("HarborIsle" .. isle.id, "Finish now", Speedup.building(left), function()
			Remotes.fire("Harbor_FinishIsle", isle.id)
		end, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 5, Parent = card })
	elseif status == "Ready" or status == "Locked" then
		local tools = {}
		local toolsOk = true
		for id, tool in Tools.tools do
			local have = state.tools[id] or 0
			toolsOk = toolsOk and have >= isle.unlockTools
			table.insert(tools, string.format("%d/%d %s", have, isle.unlockTools, tool.plural))
		end
		table.sort(tools)
		text(
			string.format(
				"Reach it for %d Coins%s. Takes %s.  +%d XP",
				isle.unlockCoins,
				if isle.unlockTools > 0 then ", " .. table.concat(tools, ", ") else "",
				Timer.format(isle.unlockSeconds),
				isle.unlockXp
			),
			4,
			nil,
			38
		)
		local ok, reason = Harbor.canUnlockIsle(state, isle.id, now)
		if not ok and reason then
			text(reason, 5, Ui.colors.danger)
		end
		local button = Ui.button("Set sail for " .. isle.displayName, function()
			Remotes.fire("Harbor_UnlockIsle", isle.id)
		end, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 6, Parent = card })
		Ui.setEnabled(button, ok and toolsOk and state.currencies.Coins >= isle.unlockCoins)
	end
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Harbor"
	local harbor = state.harbor
	if harbor == nil then
		return
	end
	local now = ClientStore.now()
	if harbor.readyAt == nil then
		if state.level < Config.unlockLevel then
			line(string.format("The Harbor can be repaired at level %d.", Config.unlockLevel), 1, body)
			return
		end
		line(
			"Repair the old Harbor and your Sailboat can sail to the Far Isles, where fruit grows that "
				.. "your farm can't. Your first isle, Blossom Cay, opens with it.",
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
		local button = fullButton("Repair", 3, body, function()
			Remotes.fire("Harbor_Repair")
		end)
		Ui.setEnabled(button, state.currencies.Coins >= Config.repairCoins)
		line("Tip: Move (M) lets you walk the Harbor to another spot on your land.", 4, body, 38, Ui.colors.muted)
		return
	end
	if now < harbor.readyAt then
		local left = harbor.readyAt - now
		line("Repairing: " .. Timer.format(left) .. " left. Your Sailboat sails when it's done.", 1, body, 38)
		Panels.gemButton("HarborSpeedUp", "Finish now", Speedup.building(left), function()
			Remotes.fire("Harbor_SpeedUp")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = body })
		return
	end

	local order = 1
	-- The Driftwood Crate
	if harbor.driftDay ~= DailyRules.utcDay(now) then
		fullButton("Open today's Driftwood Crate", order, body, function()
			Remotes.fire("Harbor_Drift")
		end)
	else
		line("A new Driftwood Crate washes up tomorrow.", order, body, nil, Ui.colors.muted)
	end
	order += 1

	barPicker(order, body)
	order += 3

	heading("Sailboats", order, body)
	order += 1
	for i, boat in harbor.boats do
		boatCard(state, i, boat, order, body)
		order += 1
	end
	local nextBoat = Harbor.nextBoat(state)
	if nextBoat then
		local price, reason = Harbor.canBuyBoat(state, now)
		local pop = TownRules.population(state, now)
		line(
			string.format(
				"Sailboat %d: level %d, Population %d (you have %d), %d Coins",
				#harbor.boats + 1,
				nextBoat.level,
				nextBoat.population,
				pop,
				nextBoat.coins
			),
			order,
			body,
			38,
			Ui.colors.muted
		)
		local button = fullButton("Buy another Sailboat", order + 1, body, function()
			Remotes.fire("Harbor_BuyBoat")
		end)
		Ui.setEnabled(button, price ~= nil and state.currencies.Coins >= price)
		if reason then
			line(reason, order + 2, body, nil, Ui.colors.danger)
		end
		order += 3
	end

	heading("Far Isles", order, body)
	order += 1
	for _, isle in Config.isles do
		-- Show the open isles, the next one to open and one more beyond it
		isleCard(state, isle, order, body)
		order += 1
		if not Harbor.isleOpen(state, isle.id, now) and state.level < isle.unlockLevel then
			break
		end
	end
	line(
		string.format(
			"Trips home: %d   ·   Sea Chests found: %d",
			(function()
				local n = 0
				for _, count in harbor.trips do
					n += count
				end
				return n
			end)(),
			harbor.chests or 0
		),
		order,
		body,
		nil,
		Ui.colors.muted
	)
end

function HarborUi.init()
	Panels.register("Harbor", render)
end

return HarborUi
