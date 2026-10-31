--!strict
-- The daily gift calendar strip (UI Reference & Gaps G9): instead of a toast, the first login
-- of a UTC day opens a strip of the seven days (claimed ones ticked, today's highlighted with
-- its gift) and one button. The server has already given today's gift (ReturnService), so the
-- button just closes. Opens again from the 📅 edge icon or Y. Waits for the "While you were
-- away" summary to close first, since both use the panel window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local ArtIcons = require(Shared.Art.Icons)
local Daily = require(Shared.Config.Daily)
local DailyRules = require(Shared.Daily)
local Items = require(Shared.Items)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local Kit = Ui.theme.Kit
local Palette = Ui.theme.Palette

local DailyGift = {}

local justClaimed: number? = nil -- the day the server just gave, for the "Today" highlight

local function dayCard(parent: Instance, day: number, level: number, claimedThrough: number, today: number?)
	local reward = DailyRules.rewardFor(day, level)
	local isToday = today == day
	local claimed = day <= claimedThrough
	local card = Ui.card({ Name = "Day" .. day, LayoutOrder = day, Parent = parent })
	if isToday then
		card.BackgroundColor3 = Palette.hex("#E4F4FF")
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Ui.colors.selected
			stroke.Thickness = 3
			stroke.Transparency = 0
		end
	end
	Ui.label(if isToday then "Today" else "Day " .. day, {
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if isToday then Ui.colors.selected else Ui.colors.text,
		Parent = card,
	})
	-- The gift's picture: Gems or Coins icon, or the item
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(38, 38),
		Parent = card,
	})
	local amount
	if reward.gems then
		Kit.icon("Gems", 38).Parent = holder
		amount = tostring(reward.gems)
	elseif reward.item and not reward.coins then
		local ok, icon = pcall(ArtIcons.viewport, reward.item, 38)
		if ok then
			icon.Parent = holder
		end
		local def = Items[reward.item]
		amount = if def then def.displayName else reward.item
	else
		Kit.icon("Coins", 38).Parent = holder
		amount = Ui.short(reward.coins or 0) .. if reward.item then " +1" else ""
	end
	local label = Ui.label(amount, {
		Position = UDim2.new(0, 2, 1, -22),
		Size = UDim2.new(1, -4, 0, 18),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	label.TextScaled = true
	Ui.new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 9 }).Parent = label
	if claimed then
		Ui.new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Ui.colors.ready,
			Position = UDim2.new(1, 2, 0, 16),
			Size = UDim2.fromOffset(20, 20),
			Font = Ui.theme.Type.display,
			TextSize = 14,
			TextColor3 = Palette.textOnColor,
			Text = "✓",
			ZIndex = 3,
			Parent = card,
		}, { Ui.corner(10) })
	end
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Daily gift"
	local daily = state.daily or { day = 0, lastDay = -1 }
	if state.level < Daily.unlockLevel then
		Ui.label(string.format("Daily gifts start at level %d.", Daily.unlockLevel), {
			TextColor3 = Ui.colors.muted,
			Parent = body,
		})
		return
	end
	local claimedToday = daily.lastDay == DailyRules.utcDay(ClientStore.now())
	local today = if claimedToday then daily.day else nil
	Ui.label(
		if justClaimed and claimedToday
			then "Here's today's gift! It's already in your Barn and wallet."
			else "Log in each day for a bigger gift. Missing a day starts the week again.",
		{ Size = UDim2.new(1, -8, 0, 36), TextWrapped = true, LayoutOrder = 1, Parent = body }
	)
	local strip = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(58, 86),
			CellPadding = UDim2.fromOffset(4, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for day = 1, #Daily.days do
		dayCard(strip, day, state.level, daily.day, today)
	end
	-- Time to the next gift (UTC midnight)
	local now = ClientStore.now()
	local nextIn = (DailyRules.utcDay(now) + 1) * 86400 - now
	Ui.label(
		string.format(
			"Next gift (day %d) in %s.",
			if claimedToday then daily.day % #Daily.days + 1 else 1,
			Timer.format(nextIn)
		),
		{ TextColor3 = Ui.colors.muted, TextSize = 14, LayoutOrder = 3, Parent = body }
	)
	Ui.button("Great!", function()
		justClaimed = nil
		Panels.close()
	end, { Size = UDim2.fromOffset(140, 40), LayoutOrder = 4, Parent = body })
end

function DailyGift.show()
	Panels.open("DailyGift")
end

function DailyGift.init()
	Panels.register("DailyGift", render)
	Hud.handlers.Daily = function(payload)
		justClaimed = payload.day
		-- The away summary arrives first and shares the window: wait for it to close
		task.spawn(function()
			local waited = 0
			-- ...and for a building or decoration being placed (its Place bar sits under the window)
			while (Panels.isOpen() or Panels.busy()) and waited < 600 do
				task.wait(0.5)
				waited += 0.5
			end
			if not Panels.isOpen() and not Panels.busy() then
				Panels.open("DailyGift")
			end
		end)
	end
end

return DailyGift
