--!strict
-- The Tinker's Guild panel (Features/F01, shared/Guild): build the Guild with Bars, then pick
-- one upgrade at a time for each factory: time, shelves, Coins or XP, each for a mix of Bars.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Guild)
local Factories = require(Shared.Config.Factories)
local Guild = require(Shared.Guild)
local Items = require(Shared.Items)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local TownRules = require(Shared.TownRules)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local GuildUi = {}

local function line(text: string, order: number, body: Instance, height: number?, muted: boolean?)
	return Ui.label(text, {
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, height or 22),
		TextSize = 14,
		TextColor3 = if muted then Ui.colors.muted else Ui.colors.text,
		LayoutOrder = order,
		Parent = body,
	})
end

-- "6 Copper Bar (4)": what it takes, and how many are in the Barn
local function barText(cost: { [string]: number }): (string, boolean)
	local parts, enough = {}, true
	for _, bar in Config.bars do
		local need = cost[bar]
		if need then
			local have = ClientStore.itemCount(bar)
			enough = enough and have >= need
			table.insert(parts, string.format("%d %s (%d)", need, Items[bar].displayName, have))
		end
	end
	return table.concat(parts, ", "), enough
end

local function statText(levels: Guild.Levels, isFeedMill: boolean): string
	local out = {
		string.format("Time -%d%%", math.round(levels.time * Config.step * 100)),
		string.format("Shelves +%d", levels.shelves),
	}
	if not isFeedMill then
		table.insert(out, string.format("Coins +%d%%", math.round(levels.coins * Config.step * 100)))
		table.insert(out, string.format("XP +%d%%", math.round(levels.xp * Config.step * 100)))
	end
	return table.concat(out, " · ")
end

local function factoryRow(state: { [string]: any }, body: Instance, id: string, order: number)
	local levels = Guild.levels(state, id)
	local level = Guild.level(levels)
	local card = Ui.card({ Size = UDim2.new(1, -8, 0, 92), LayoutOrder = order, Parent = body })
	Ui.label(string.format("%s  ★%d / %d", Factories[id].displayName, level, Guild.maxLevel(id)), {
		Font = Ui.theme.Type.display,
		TextSize = 16,
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.fromOffset(6, 4),
		Parent = card,
	})
	Ui.label(statText(levels, Guild.tableId(id) == "FeedMill"), {
		TextSize = 13,
		TextColor3 = Ui.colors.muted,
		Size = UDim2.new(1, -12, 0, 18),
		Position = UDim2.fromOffset(6, 26),
		Parent = card,
	})
	local cost = Guild.nextCost(id, level)
	if cost == nil then
		Ui.label("Fully upgraded", {
			TextSize = 14,
			Size = UDim2.new(1, -12, 0, 30),
			Position = UDim2.fromOffset(6, 50),
			Parent = card,
		})
		return
	end
	local text, enough = barText(cost)
	Ui.label("Next: " .. text, {
		TextSize = 13,
		TextWrapped = true,
		Size = UDim2.new(1, -12, 0, 18),
		Position = UDim2.fromOffset(6, 44),
		Parent = card,
	})
	local choices = Guild.choices(id, levels)
	for i, stat in choices do
		local button = Ui.button("+ " .. Guild.STAT_NAMES[stat], function()
			Remotes.fire("Guild_Upgrade", id, stat)
		end, {
			Size = UDim2.new(1 / #choices, -6, 0, 26),
			Position = UDim2.new((i - 1) / #choices, 6, 0, 62),
			Parent = card,
		})
		Ui.setEnabled(button, enough)
	end
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Tinker's Guild"
	local now = ClientStore.now()
	local guild = state.guild
	if guild == nil then
		return
	end
	if guild.readyAt == nil then
		if state.level < Config.unlockLevel then
			line(string.format("The Tinker's Guild can be built at level %d.", Config.unlockLevel), 1, body)
			return
		end
		line(
			"The Tinker's Guild upgrades your factories with Bars from the Smelters: faster making, "
				.. "more shelves, and more Coins or XP on orders.",
			1,
			body,
			54
		)
		local text, enough = barText(Config.buildBars)
		local population = TownRules.population(state, now)
		line(string.format("Build it with %s. Takes %s.", text, Timer.format(Config.buildSeconds)), 2, body, 40)
		if population < Config.population then
			line(string.format("Needs Population %d (you have %d).", Config.population, population), 3, body, nil, true)
		end
		local button = Ui.button("Build", function()
			Remotes.fire("Guild_Build")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 4, Parent = body })
		Ui.setEnabled(button, enough and population >= Config.population)
		return
	end
	if now < guild.readyAt then
		local left = guild.readyAt - now
		line("Building: " .. Timer.format(math.max(0, left)) .. " left", 1, body)
		Panels.gemButton("GuildSpeedUp", "Finish now", Speedup.building(left), function()
			Remotes.fire("Guild_SpeedUp")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = body })
		return
	end
	line("Pick one upgrade at a time. Bars come from the Smelters.", 1, body, nil, true)
	local ids = {}
	for id, factory in state.factories do
		if factory.built and Factories[id] and Guild.tableId(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Factories[a].order < Factories[b].order
	end)
	if #ids == 0 then
		line("Build a factory first.", 2, body)
	end
	for i, id in ids do
		factoryRow(state, body, id, 1 + i)
	end
end

function GuildUi.init()
	Panels.register("Guild", render)
end

return GuildUi
