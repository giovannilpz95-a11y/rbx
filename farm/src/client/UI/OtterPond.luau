--!strict
-- The Otter Pond panel (Config/OtterPond, shared/OtterPond): build the pond, buy up to two more
-- otters, then give each otter an Egg, Bacon or Fish to send it fishing. The panel shows what
-- each food can bring back and how long it takes, then each otter's timer and its catch.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.OtterPond)
local Items = require(Shared.Items)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local OtterPondUi = {}

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

local function sortedGoods(map: { [string]: any }): { string }
	local ids = {}
	for id in map do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.goods[a].order < Config.goods[b].order
	end)
	return ids
end

local function catchText(catch: { [string]: number }): string
	local parts = {}
	for _, id in sortedGoods(catch) do
		if catch[id] > 0 then
			table.insert(parts, string.format("%d %s", catch[id], name(id)))
		end
	end
	return if #parts == 0 then "nothing this time" else table.concat(parts, ", ")
end

local function sortedFoods(): { { id: string, def: any } }
	local foods = {}
	for id, food in Config.foods do
		table.insert(foods, { id = id, def = food })
	end
	table.sort(foods, function(a, b)
		return a.def.order < b.def.order
	end)
	return foods
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Otter Pond"
	local pond = state.otterPond
	if pond == nil then
		return
	end
	local now = ClientStore.now()
	if pond.readyAt == nil then
		if state.level < Config.unlockLevel then
			line(string.format("The Otter Pond can be built at level %d.", Config.unlockLevel), 1, body)
			return
		end
		line(
			"Build the pond and an otter moves in. Give it an Egg, Bacon or Fish and it goes fishing, "
				.. "coming back with Seaweed, Scallops and sometimes Pearls.",
			1,
			body,
			56
		)
		line(
			string.format(
				"Build it for %d Coins. Takes %s.  +%d XP",
				Config.buildCoins,
				Timer.format(Config.buildSeconds),
				Config.buildXp
			),
			2,
			body
		)
		local button = fullButton("Build the Otter Pond", 3, body, function()
			Remotes.fire("Otter_Build")
		end)
		Ui.setEnabled(button, state.currencies.Coins >= Config.buildCoins)
		-- The Place bar, the same one a new building offers (Main's Place handler closes this
		-- panel and picks the building up)
		Ui.button("Choose its spot", function()
			Hud.popup({ kind = "Place", key = "otters:OtterPond" })
		end, { Size = UDim2.new(1, -8, 0, 36), LayoutOrder = 4, Parent = body })
		line("Or press Move (M) any time to walk it somewhere else.", 5, body, 22, Ui.colors.muted)
		return
	end
	if now < pond.readyAt then
		local left = pond.readyAt - now
		line("Building: " .. Timer.format(left) .. " left.", 1, body)
		Panels.gemButton("OtterSpeedUp", "Finish now", Speedup.building(left), function()
			Remotes.fire("Otter_SpeedUp")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = body })
		return
	end

	local foods = sortedFoods()
	local order = 1
	line("Each food sends an otter out for:", order, body, nil, Ui.colors.muted)
	order += 1
	for _, entry in foods do
		local food = entry.def
		local parts = {}
		for _, id in sortedGoods(food.catch) do
			table.insert(parts, range(food.catch[id]) .. " " .. name(id))
		end
		line(
			string.format(
				"%s (you have %d): %s, %s",
				name(food.item),
				state.inventory[food.item] or 0,
				table.concat(parts, ", "),
				Timer.format(food.seconds)
			),
			order,
			body,
			38
		)
		order += 1
	end

	for i = 1, pond.otters or 1 do
		local trip = pond.away[tostring(i)]
		if trip and now >= trip.readyAt then
			line(string.format("Otter %d is back with %s.", i, catchText(trip.catch)), order, body, 38)
			fullButton("Collect", order + 1, body, function()
				Remotes.fire("Otter_Collect", i)
			end)
		elseif trip then
			local left = trip.readyAt - now
			line(string.format("Otter %d is fishing: %s left.", i, Timer.format(left)), order, body)
			Panels.gemButton("OtterSkip" .. i, "Bring it back now", Speedup.production(left), function()
				Remotes.fire("Otter_Skip", i)
			end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = order + 1, Parent = body })
		else
			line(string.format("Otter %d is home. Give it:", i), order, body)
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, -8, 0, 40)
			row.LayoutOrder = order + 1
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.Padding = UDim.new(0, 6)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = row
			for k, entry in foods do
				local item = entry.def.item
				local have = state.inventory[item] or 0
				local button = Ui.button(name(item), function()
					Remotes.fire("Otter_Feed", i, entry.id)
				end, { Size = UDim2.new(1 / #foods, -6, 1, 0), LayoutOrder = k, Parent = row })
				Ui.setEnabled(button, have > 0)
			end
			row.Parent = body
		end
		order += 2
	end

	local coins = Config.otterCoins[(pond.otters or 1) + 1]
	if coins then
		local button = fullButton(string.format("Another otter: %d Coins", coins), order, body, function()
			Remotes.fire("Otter_Buy")
		end)
		Ui.setEnabled(button, state.currencies.Coins >= coins)
		order += 1
	end
	line(string.format("Fishing trips so far: %d", pond.trips or 0), order, body, nil, Ui.colors.muted)
end

function OtterPondUi.init()
	Panels.register("OtterPond", render)
end

return OtterPondUi
