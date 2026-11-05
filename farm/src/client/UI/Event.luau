--!strict
-- The limited-time event's panel (Config/Events, shared/Events, EventService): three tabs.
-- Fair Stand: three crates of goods to deliver for tokens, each refilling after a wait.
-- Prizes: the 15-prize track, climbed by every token earned, with one Claim button.
-- Shop: keepsake decorations for tokens, placed later from Build > Decorations.
-- Opened from the edge stack's event icon or by tapping the Fair Stand in the Town Square.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Events)
local Events = require(Shared.Events)
local Items = require(Shared.Items)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local ReachController = require(script.Parent.Parent.Controllers.ReachController)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local EventUi = {}

local lastTap = 0

-- One tap, acting on press (the panel rebuilds when a countdown ends)
local function pressButton(text: string, fire: () -> (), enabled: boolean, color: Color3, parent: Instance): TextButton
	local function tap()
		if not enabled or time() - lastTap < 0.35 then
			return
		end
		lastTap = time()
		fire()
	end
	local button = Ui.button(text, tap, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(110, 34),
		BackgroundColor3 = color,
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
	Ui.setEnabled(button, enabled, color)
	return button
end

local function note(text: string, order: number, body: Instance): TextLabel
	return Ui.label(text, {
		Size = UDim2.new(1, -8, 0, 36),
		TextWrapped = true,
		TextSize = 13,
		TextColor3 = Ui.colors.muted,
		LayoutOrder = order,
		Parent = body,
	})
end

local function card(order: number, body: Instance, height: number?): Frame
	local c = Ui.card({ Size = UDim2.new(1, -8, 0, height or 58), LayoutOrder = order, Parent = body })
	Ui.padding(6).Parent = c
	return c
end

local function lines(c: Frame, top: string, bottom: string): TextLabel
	Ui.label(top, { Font = Ui.theme.Type.display, Size = UDim2.new(1, -120, 0, 20), Parent = c })
	return Ui.label(bottom, {
		Name = "Line2",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -120, 0, 28),
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Ui.colors.muted,
		Parent = c,
	})
end

local function renderStand(state: { [string]: any }, def: Config.EventDef, body: Instance)
	local block = state.event
	local items = state.inventory or {}
	for i = 1, def.fairStand.slots do
		local crate = block.crates[tostring(i)]
		local c = card(10 + i, body)
		if crate == nil or crate.item == nil then
			local waitUntil = if crate then crate.waitUntil or 0 else 0
			local function left(): string?
				local t = ClientStore.now()
				if t >= waitUntil then
					return nil
				end
				return "A new crate in " .. Timer.format(waitUntil - t)
			end
			lines(c, "Crate on its way", left() or "Any moment now")
			Panels.liveText(c:FindFirstChild("Line2") :: TextLabel, left)
		else
			local item = Items[crate.item]
			local have = items[crate.item] or 0
			local enough = have >= crate.qty
			lines(
				c,
				string.format("%d %s", crate.qty, if item then item.displayName else crate.item),
				string.format("You have %d.  Pays %s %d %s", have, def.tokenIcon, crate.tokens or 0, def.tokenName)
			)
			pressButton(if enough then "Deliver" else "Swap", function()
				Remotes.fire(if enough then "Event_Deliver" else "Event_Swap", i)
			end, true, if enough then Ui.colors.accent else Ui.colors.selected, c)
		end
	end
	note(
		string.format(
			"Deliver a crate for %s %s. Can't fill one? Swap it for a new crate after the wait. Quest chests, stars, rainbows and Golden Eggs add a few %s too.",
			def.tokenIcon,
			def.tokenName,
			def.tokenName
		),
		20,
		body
	)
end

local function renderPrizes(state: { [string]: any }, def: Config.EventDef, body: Instance)
	local block = state.event
	local reached = Events.reached(def, block.earned)
	local ready = reached - block.claimed
	local top = card(1, body)
	lines(
		top,
		string.format("%s %d earned", def.tokenIcon, block.earned),
		if reached >= #def.milestones
			then "Every prize reached!"
			else string.format("Next prize at %d %s", def.milestones[reached + 1].tokens, def.tokenName)
	)
	pressButton(if ready > 0 then string.format("Claim %d", ready) else "Claim", function()
		Remotes.fire("Event_Claim")
	end, ready > 0, Ui.colors.coins, top)
	for i, m in def.milestones do
		local mark = if i <= block.claimed then "✓ " elseif i <= reached then "🎉 " else ""
		local c = card(10 + i, body, 40)
		Ui.label(string.format("%s%d.  %s", mark, i, Events.describe(m.reward)), {
			Size = UDim2.new(1, -80, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = c,
		})
		Ui.label(string.format("%s %d", def.tokenIcon, m.tokens), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 76, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if i <= reached then Ui.colors.text else Ui.colors.muted,
			Parent = c,
		})
	end
	note("The last four prizes are keepsake decorations: place them from Build > Decorations.", 40, body)
end

local function renderShop(state: { [string]: any }, def: Config.EventDef, body: Instance)
	local block = state.event
	note(
		string.format(
			"You have %s %d %s to spend. Prizes count every %s you earn, so spending never sets you back.",
			def.tokenIcon,
			block.tokens,
			def.tokenName,
			string.sub(def.tokenName, 1, -2)
		),
		1,
		body
	)
	for i, item in def.shop do
		local keepsake = Config.keepsakes[item.id]
		local left = item.stock - (block.bought[tostring(i)] or 0)
		local c = card(10 + i, body)
		lines(
			c,
			keepsake.displayName,
			string.format(
				"%d x %d tile%s keepsake.  %s",
				keepsake.size[1],
				keepsake.size[2],
				if keepsake.size[1] * keepsake.size[2] > 1 then "s" else "",
				if left > 0 then string.format("%d left", left) else "Sold out"
			)
		)
		pressButton(if left > 0 then string.format("%s %d", def.tokenIcon, item.price) else "Sold out", function()
			Remotes.fire("Event_Buy", i)
		end, left > 0 and block.tokens >= item.price, Ui.colors.coins, c)
	end
	note(
		string.format(
			"When the event ends, every %s left turns into %d Coins.",
			string.sub(def.tokenName, 1, -2),
			def.tokenToCoins
		),
		40,
		body
	)
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	local now = ClientStore.now()
	local def, _, endsAt = Events.active(now)
	local block = state.event
	if def == nil or block == nil or block.id ~= def.id then
		title.Text = "Events"
		Ui.label(
			if def and state.level < def.minLevel
				then string.format("The %s opens at level %d.", def.displayName, def.minLevel)
				else "No event is running right now. Watch the Notice Board for the next one.",
			{ TextWrapped = true, Size = UDim2.new(1, -8, 0, 40), Parent = body }
		)
		return
	end
	title.Text = def.displayName
	local function ends(): string?
		local t = ClientStore.now()
		if t >= endsAt then
			return nil
		end
		return string.format("%s %d   ·   ends in %s", def.tokenIcon, block.tokens, Events.timeLeft(endsAt - t))
	end
	Panels.liveText(
		Ui.label(ends() or "", {
			Size = UDim2.new(1, -8, 0, 22),
			Font = Ui.theme.Type.display,
			LayoutOrder = 0,
			Parent = body,
		}),
		ends
	)
	local ready = Events.reached(def, block.earned) - block.claimed
	local tab = Panels.tabs(
		{ "Fair Stand", "Prizes", "Shop" },
		1,
		{ Prizes = if ready > 0 then tostring(ready) else "" }
	)
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = body,
	}, { Ui.list(6) })
	if tab == "Prizes" then
		renderPrizes(state, def, holder)
	elseif tab == "Shop" then
		renderShop(state, def, holder)
	else
		renderStand(state, def, holder)
	end
end

function EventUi.init()
	Panels.register("Event", render, { live = true })
	-- Studio previews the first event: the server says from when
	local function readPreview()
		local startsAt = Workspace:GetAttribute("EventPreview")
		Events.setPreview(if type(startsAt) == "number" and startsAt > 0 then startsAt else nil)
	end
	Workspace:GetAttributeChangedSignal("EventPreview"):Connect(readPreview)
	readPreview()
	Hud.handlers.Event = function(payload)
		if type(payload.text) ~= "string" then
			return
		end
		local good = payload.step == "crate" or payload.step == "claim" or payload.step == "bought"
		Hud.toast(payload.text, if good then "celebrate" else nil)
	end
	-- The Fair Stand stands in the Town Square, off our plot: a tap opens the panel
	local previous = ReachController.otherTarget
	ReachController.otherTarget = function(part: BasePart)
		if part:GetAttribute("Interact") == "FairStand" then
			return function()
				Panels.open("Event")
			end, false
		end
		return previous(part)
	end
end

return EventUi
