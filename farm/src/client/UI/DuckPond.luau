--!strict
-- The Duck Pond panel (Config/DuckPond, shared/DuckPond): dig the pond out, then put a Bread,
-- Bagel or Banana Bread in the feeder. The panel shows how many ducks each food can bring and
-- how long they stay, then the visit's timer and the feathers to collect.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.DuckPond)
local DuckPond = require(Shared.DuckPond)
local Items = require(Shared.Items)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local DuckPondUi = {}

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

local function range(r: { number }): string
	return if r[1] == r[2] then tostring(r[1]) else string.format("%d-%d", r[1], r[2])
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Duck Pond"
	local pond = state.duckPond
	if pond == nil then
		return
	end
	local now = ClientStore.now()
	if pond.readyAt == nil then
		if state.level < Config.unlockLevel then
			line(string.format("The Duck Pond can be dug out at level %d.", Config.unlockLevel), 1, body)
			return
		end
		line(
			"Dig out the old pond and ducks will visit when there's food in the feeder. Every duck leaves "
				.. "a Down Feather, and every drake (the green heads) a Colorful Feather too.",
			1,
			body,
			56
		)
		line(
			string.format(
				"Dig it out for %d Coins. Takes %s.  +%d XP",
				Config.digCoins,
				Timer.format(Config.digSeconds),
				Config.digXp
			),
			2,
			body
		)
		local button = fullButton("Dig it out", 3, body, function()
			Remotes.fire("Pond_Dig")
		end)
		Ui.setEnabled(button, state.currencies.Coins >= Config.digCoins)
		line("Tip: Move (M) lets you walk the pond to another spot on your land.", 4, body, 38, Ui.colors.muted)
		return
	end
	if now < pond.readyAt then
		local left = pond.readyAt - now
		line("Digging: " .. Timer.format(left) .. " left.", 1, body)
		Panels.gemButton("PondSpeedUp", "Finish now", Speedup.building(left), function()
			Remotes.fire("Pond_SpeedUp")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = body })
		return
	end

	local visit = pond.visit
	if visit then
		local feathers = DuckPond.feathers(visit)
		local parts = {}
		for item, qty in feathers do
			table.insert(parts, string.format("%d %s", qty, name(item)))
		end
		table.sort(parts)
		if now >= visit.readyAt then
			line("The ducks have gone and left " .. table.concat(parts, " and ") .. ".", 1, body, 38)
			fullButton("Collect the feathers", 2, body, function()
				Remotes.fire("Pond_Collect")
			end)
		else
			local left = visit.readyAt - now
			line(
				string.format(
					"%d %s visiting (%d %s). They leave %s in %s.",
					visit.ducks,
					if visit.ducks == 1 then "duck" else "ducks",
					visit.drakes,
					if visit.drakes == 1 then "drake" else "drakes",
					table.concat(parts, " and "),
					Timer.format(left)
				),
				1,
				body,
				38
			)
			Panels.gemButton("PondSkip", "Collect now", Speedup.production(left), function()
				Remotes.fire("Pond_Skip")
			end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = body })
		end
		return
	end

	line(
		"Put one Bakery good in the feeder. Better food brings more ducks, more drakes and a shorter wait.",
		1,
		body,
		38
	)
	local foods = {}
	for id, food in Config.foods do
		table.insert(foods, { id = id, def = food })
	end
	table.sort(foods, function(a, b)
		return a.def.order < b.def.order
	end)
	local order = 2
	for _, entry in foods do
		local food = entry.def
		local have = state.inventory.items[food.item] or 0
		line(
			string.format(
				"%s (you have %d): %s ducks, %s drakes, %s",
				name(food.item),
				have,
				range(food.ducks),
				range(food.drakes),
				Timer.format(food.seconds)
			),
			order,
			body,
			nil,
			if have > 0 then Ui.colors.text else Ui.colors.muted
		)
		local button = fullButton("Feed " .. name(food.item), order + 1, body, function()
			Remotes.fire("Pond_Feed", entry.id)
		end)
		Ui.setEnabled(button, have > 0)
		order += 2
	end
	line(string.format("Visits so far: %d", pond.visits or 0), order, body, nil, Ui.colors.muted)
end

function DuckPondUi.init()
	Panels.register("DuckPond", render)
end

return DuckPondUi
