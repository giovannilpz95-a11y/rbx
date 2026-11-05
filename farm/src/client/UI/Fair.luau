--!strict
-- The County Fair panel (Config/Fair, shared/Fair, FairService): one card per class. While
-- entries are open, pick what to enter; after judging, each entry shows its marks and ribbon.
-- Opened from the edge stack's 🏅 icon or by tapping the fair's tent in the Town Square.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Fair)
local Events = require(Shared.Events)
local Fair = require(Shared.Fair)
local Items = require(Shared.Items)
local Recipes = require(Shared.Config.Recipes)

local ClientStore = require(script.Parent.Parent.ClientStore)
local ReachController = require(script.Parent.Parent.Controllers.ReachController)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local FairUi = {}

local lastTap = 0

local function name(item: string): string
	return if Items[item] then Items[item].displayName else item
end

local function tapButton(text: string, fire: () -> (), parent: Instance, order: number)
	local function tap()
		if time() - lastTap < 0.5 then
			return
		end
		lastTap = time()
		fire()
	end
	local button = Ui.button(text, tap, {
		Size = UDim2.new(1, -8, 0, 38),
		LayoutOrder = order,
		BackgroundColor3 = Ui.colors.accent,
		Parent = parent,
	})
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tap()
		end
	end)
end

local function label(text: string, order: number, parent: Instance, muted: boolean?): TextLabel
	return Ui.label(text, {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = if muted then 13 else nil,
		TextColor3 = if muted then Ui.colors.muted else nil,
		LayoutOrder = order,
		Parent = parent,
	})
end

-- The Prize Crop that adds the most garnish marks, or nil
local function bestGarnish(prizes: { any }): number?
	local best, bestMarks = nil, -1
	for i, p in prizes do
		local marks = Config.garnishTier[p.tier]
		if marks and marks > bestMarks then
			best, bestMarks = i, marks
		end
	end
	return best
end

local function classCard(state: { [string]: any }, class: Config.Class, order: number, body: Instance, now: number)
	local week, closes = Fair.window(now)
	local open = now < closes
	local fair = state.fair or Fair.blank(0)
	local entry = if fair.week == week then fair.entries[class.id] else nil
	local card = Ui.card({
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = body,
	})
	Ui.list(4).Parent = card
	Ui.padding(8).Parent = card
	Ui.label(
		class.displayName,
		{ Font = Ui.theme.Type.display, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = card }
	)
	if entry then
		local what = if entry.tier
			then string.format("%s %s", entry.tier, name(entry.item))
			elseif entry.garnish then string.format(
				"%s topped with %s %s",
				name(entry.item),
				entry.garnish,
				name(entry.garnishCrop or "")
			)
			else name(entry.item)
		if open then
			label("Entered: " .. what .. ". The judges score it when entries close.", 2, card)
		else
			local ribbon = Fair.ribbon(entry.marks)
			label(
				string.format(
					"%s %s for your %s: %d marks out of 100",
					ribbon.icon,
					ribbon.displayName,
					what,
					entry.marks
				),
				2,
				card
			)
		end
		return
	end
	if not open then
		label("No entry this fair. The next one opens on Friday.", 2, card, true)
		return
	end
	local prizes = state.prizes or {}
	if class.id == "Produce" then
		if #prizes == 0 then
			label(
				"Enter a Prize Crop from your Prize Basket. Rarer ones score higher. You have none yet: they turn up when you harvest.",
				2,
				card,
				true
			)
			return
		end
		label("Enter one Prize Crop from your Prize Basket. Rarer ones score higher.", 2, card, true)
		for i, p in prizes do
			if Config.produceTier[p.tier] then
				tapButton(string.format("Enter %s %s", p.tier, name(p.crop)), function()
					Remotes.fire("Fair_Enter", "Produce", i)
				end, card, 10 + i)
			end
		end
		return
	end
	-- Best Bake
	local bakes = {}
	for id, recipe in Recipes do
		if recipe.factory == Config.bakeFactory and ((state.inventory or {})[id] or 0) > 0 then
			table.insert(bakes, id)
		end
	end
	table.sort(bakes)
	if #bakes == 0 then
		label(
			"Enter one Bakery good from your Barn. Fancier bakes score higher, and a Prize Crop on top adds more.",
			2,
			card,
			true
		)
		return
	end
	label("Enter one Bakery good. Fancier bakes score higher, and a Prize Crop on top adds more.", 2, card, true)
	local garnish = bestGarnish(prizes)
	for i, id in bakes do
		tapButton("Enter " .. name(id), function()
			Remotes.fire("Fair_Enter", "Bake", id)
		end, card, 10 + i * 2)
		if garnish then
			local p = prizes[garnish]
			tapButton(string.format("Enter %s topped with %s %s", name(id), p.tier, name(p.crop)), function()
				Remotes.fire("Fair_Enter", "Bake", id, garnish)
			end, card, 11 + i * 2)
		end
	end
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "County Fair"
	if state.level < Config.minLevel then
		label(string.format("The County Fair opens at level %d.", Config.minLevel), 1, body)
		return
	end
	local now = ClientStore.now()
	local _, closes, nextOpens = Fair.window(now)
	local function status(): string?
		local t = ClientStore.now()
		if t < closes then
			return "Entries open · judging in " .. Events.timeLeft(closes - t)
		elseif t < nextOpens then
			return "Judged! · the next fair opens in " .. Events.timeLeft(nextOpens - t)
		end
		return nil
	end
	Panels.liveText(
		Ui.label(status() or "", {
			Size = UDim2.new(1, -8, 0, 22),
			Font = Ui.theme.Type.display,
			LayoutOrder = 0,
			Parent = body,
		}),
		status
	)
	for i, id in Config.order do
		classCard(state, Config.classes[id], i, body, now)
	end
	local won = {}
	for _, r in Config.ribbons do
		local n = state.fair and state.fair.ribbons[r.id] or 0
		if n > 0 then
			table.insert(won, string.format("%s %d", r.icon, n))
		end
	end
	label(
		if #won > 0
			then "Your ribbons: " .. table.concat(won, "   ")
			else "No ribbons yet. Everyone who enters wins one!",
		20,
		body
	)
	label(
		"Blue Ribbons win a cup for your plot (Build > Decorations). One entry per class each weekend, Friday 16:00 to Monday 00:00 UTC. Gems can't buy marks.",
		21,
		body,
		true
	)
end

function FairUi.init()
	Panels.register("Fair", render, { live = true })
	local function readPreview()
		local startsAt = Workspace:GetAttribute("FairPreview")
		Fair.setPreview(if type(startsAt) == "number" and startsAt > 0 then startsAt else nil)
	end
	Workspace:GetAttributeChangedSignal("FairPreview"):Connect(readPreview)
	readPreview()
	Hud.handlers.Fair = function(payload)
		if type(payload.text) == "string" then
			Hud.toast(payload.text, "celebrate")
		end
	end
	local previous = ReachController.otherTarget
	ReachController.otherTarget = function(part: BasePart)
		if part:GetAttribute("Interact") == "CountyFair" then
			return function()
				Panels.open("Fair")
			end, false
		end
		return previous(part)
	end
end

-- For the edge stack: shown from the fair's level; a dot while a class can still be entered
function FairUi.status(state: { [string]: any }, now: number): (boolean, string, boolean)
	if state.level < Config.minLevel then
		return false, "", false
	end
	local week, closes, nextOpens = Fair.window(now)
	local open = now < closes
	local fair = state.fair
	if open then
		local missing = false
		for _, id in Config.order do
			if not (fair and fair.week == week and fair.entries[id]) then
				missing = true
			end
		end
		return true, Events.timeLeft(closes - now), missing
	end
	local entered = fair and fair.week == week and next(fair.entries) ~= nil
	return entered == true, if entered then "Results" else Events.timeLeft(nextOpens - now), false
end

return FairUi
