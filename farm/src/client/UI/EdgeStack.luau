--!strict
-- The edge stack (UI Reference & Gaps G12, Township's convention C10): round icons down the
-- right edge, under the Quests button, for timed things and offers. Each has a countdown and
-- a red dot. Now: the daily gift calendar (time to the next gift) and the one-time Starter
-- Pack. Later events and passes add an entry to ENTRIES.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local Daily = require(Shared.Config.Daily)
local DailyRules = require(Shared.Daily)
local Products = require(Shared.Config.Products)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local DailyGift = require(script.Parent.DailyGift)
local FarmerCard = require(script.Parent.FarmerCard)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local Kit = Ui.theme.Kit

local EdgeStack = {}

type Entry = {
	glyph: string,
	order: number,
	open: () -> (),
	-- Shown?, countdown text ("" for none), dot?
	status: (state: { [string]: any }, now: number) -> (boolean, string, boolean),
}

local seenOffer = false -- the Starter Pack dot goes once the Shop has been opened

local ENTRIES: { Entry } = {
	{
		glyph = "📅",
		order = 1,
		open = DailyGift.show,
		status = function(state, now)
			if state.level < Daily.unlockLevel then
				return false, "", false
			end
			local daily = state.daily or { lastDay = -1 }
			local claimed = daily.lastDay == DailyRules.utcDay(now)
			local nextIn = (DailyRules.utcDay(now) + 1) * 86400 - now
			return true, if claimed then Timer.format(nextIn) else "", not claimed
		end,
	},
	{
		glyph = "🎁",
		order = 2,
		open = function()
			seenOffer = true
			Panels.open("Shop")
		end,
		status = function(state)
			local bought = (state.purchases and state.purchases.bought) or {}
			for key, product in Products.products do
				if product.once and not bought[key] and state.level >= (product.fromLevel or 1) then
					return true, "Offer", not seenOffer
				end
			end
			return false, "", false
		end,
	},
	{
		glyph = "🏆",
		order = 3,
		open = FarmerCard.show,
		status = function(state)
			-- Town Records: a dot while a medal can be claimed
			return true, "", FarmerCard.readyCount(state) > 0
		end,
	},
}

function EdgeStack.init()
	local gui = Ui.new("ScreenGui", {
		Name = "FarmEdge",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local column = Ui.new("Frame", {
		Name = "EdgeStack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 148), -- under the Quests button
		Size = UDim2.fromOffset(56, 260),
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 16), -- room for each countdown under its icon
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local icons = {}
	for i, entry in ENTRIES do
		local edge = Kit.edgeIcon(entry.glyph, { LayoutOrder = entry.order, Visible = false, Parent = column })
		Kit.onTap(edge.button, entry.open)
		icons[i] = edge
	end
	local function update()
		local state = ClientStore.state
		if state == nil then
			return
		end
		local now = ClientStore.now()
		for i, entry in ENTRIES do
			local shown, timer, dot = entry.status(state, now)
			local edge = icons[i]
			edge.button.Visible = shown
			Kit.setEdgeTimer(edge, timer)
			Kit.badge(edge.button, if dot then "!" else "")
		end
	end
	ClientStore.changed.Event:Connect(update)
	task.spawn(function()
		while true do
			update()
			task.wait(1)
		end
	end)
end

return EdgeStack
