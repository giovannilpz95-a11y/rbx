--!strict
-- The Farmer Card and Town Records (UI Reference & Gaps G11; F07 Museum, Albums &
-- Achievements, MVP-lite): the player's Roblox headshot, level, title and key stats, and a
-- Records tab with each record's progress, its Bronze / Silver / Gold medals and Claim.
-- Opens with P or the 🏆 edge icon; the icon gets a dot when a tier can be claimed.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Records)
local Records = require(Shared.Records)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local Kit = Ui.theme.Kit
local Palette = Ui.theme.Palette

local FarmerCard = {}

local MEDAL = { Palette.hex("#C9864A"), Palette.hex("#B8C2CC"), Palette.hex("#F2C14E") }
local CARD_STATS = { "Orders", "Harvest", "Goods", "Animals", "Population", "Helping" }

local headshot: string? = nil -- the avatar picture, fetched once

local function fetchHeadshot()
	task.spawn(function()
		local player = Players.LocalPlayer
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if ok then
			headshot = image
			if Panels.isShowing("FarmerCard") then
				Panels.refresh()
			end
		end
	end)
end

local function views(state: { [string]: any }): { Records.View }
	return state.records or {}
end

-- How many tiers can be claimed now
function FarmerCard.readyCount(state: { [string]: any }): number
	local n = 0
	for _, v in views(state) do
		if Records.viewReady(v) then
			n += 1
		end
	end
	return n
end

local function viewOf(state: { [string]: any }, id: string): Records.View?
	for _, v in views(state) do
		if v.id == id then
			return v
		end
	end
	return nil
end

-- Three dots: filled in a medal's colour once that tier is claimed
local function medals(claimed: number, props: { [string]: any }): Frame
	local row = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 16) }, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for k, v in props do
		(row :: any)[k] = v
	end
	for tier = 1, #Config.tiers do
		local got = tier <= claimed
		Ui.new("Frame", {
			Name = Config.tiers[tier],
			LayoutOrder = tier,
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = if got then MEDAL[tier] else Palette.shade(Palette.paper, 0.85),
			Parent = row,
		}, { Ui.corner(8), Kit.stroke(if got then Palette.shade(MEDAL[tier], 0.7) else Palette.edge, 1.5, 0.2) })
	end
	return row
end

local function renderCard(state: { [string]: any }, body: ScrollingFrame)
	local player = Players.LocalPlayer
	local list = views(state)
	local stars = Records.stars(list)

	local head = Ui.card({ Name = "Header", Size = UDim2.new(1, -8, 0, 116), LayoutOrder = 2, Parent = body })
	Ui.new("ImageLabel", {
		Name = "Headshot",
		BackgroundColor3 = Palette.hex("#E4F4FF"),
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(96, 96),
		Image = headshot or "",
		Parent = head,
	}, { Ui.corner(48), Kit.stroke(Palette.edge, 3, 0) })
	Ui.label(player.DisplayName, {
		Position = UDim2.fromOffset(118, 10),
		Size = UDim2.new(1, -126, 0, 26),
		Font = Ui.theme.Type.display,
		TextSize = 22,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	Ui.label("@" .. player.Name, {
		Position = UDim2.fromOffset(118, 36),
		Size = UDim2.new(1, -126, 0, 18),
		TextSize = 14,
		TextColor3 = Ui.colors.muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	Ui.label(string.format("Level %d  ·  %s", state.level, Records.title(stars)), {
		Position = UDim2.fromOffset(118, 58),
		Size = UDim2.new(1, -126, 0, 22),
		Font = Enum.Font.GothamBold,
		Parent = head,
	})
	Ui.label(string.format("★ %d of %d stars", stars, #Config.list * #Config.tiers), {
		Position = UDim2.fromOffset(118, 84),
		Size = UDim2.new(1, -126, 0, 20),
		TextSize = 15,
		TextColor3 = Palette.shade(MEDAL[3], 0.7),
		Font = Enum.Font.GothamBold,
		Parent = head,
	})

	local grid = Ui.new("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 56),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, id in CARD_STATS do
		local def = Records.def(id)
		local v = viewOf(state, id)
		if def then
			local cell = Ui.card({ Name = id, LayoutOrder = i, Parent = grid })
			Ui.label(def.glyph, {
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(0, 30, 1, 0),
				TextSize = 24,
				Parent = cell,
			})
			Ui.label(Ui.short(if v then v.value else 0), {
				Position = UDim2.fromOffset(42, 6),
				Size = UDim2.new(1, -48, 0, 24),
				Font = Ui.theme.Type.display,
				TextSize = 20,
				Parent = cell,
			})
			Ui.label(string.lower((string.gsub(def.text, "^%S+ %%s ", ""))), {
				Position = UDim2.fromOffset(42, 30),
				Size = UDim2.new(1, -48, 0, 18),
				TextSize = 13,
				TextColor3 = Ui.colors.muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = cell,
			})
		end
	end
	Ui.label("Finish Town Records for stars and a new title.", {
		Size = UDim2.new(1, -8, 0, 20),
		TextSize = 14,
		TextColor3 = Ui.colors.muted,
		LayoutOrder = 4,
		Parent = body,
	})
end

local function recordRow(def: Config.RecordDef, v: Records.View, order: number, body: ScrollingFrame)
	local done = v.claimed >= #def.goals
	local tier = math.min(v.claimed + 1, #def.goals)
	local goal = def.goals[tier]
	local ready = Records.viewReady(v)
	local card = Ui.card({ Name = def.id, Size = UDim2.new(1, -8, 0, 84), LayoutOrder = order, Parent = body })
	if ready then
		card.BackgroundColor3 = Palette.hex("#F1FBE9")
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Ui.colors.ready
			stroke.Thickness = 3
			stroke.Transparency = 0
		end
	end
	Ui.label(def.glyph, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0, 36, 1, 0),
		TextSize = 28,
		Parent = card,
	})
	Ui.label(def.name, {
		Position = UDim2.fromOffset(50, 6),
		Size = UDim2.new(1, -230, 0, 22),
		Font = Ui.theme.Type.display,
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	medals(v.claimed, { Position = UDim2.new(1, -184, 0, 10), Parent = card })
	Ui.label(if done then "All three medals won!" else string.format(def.text, Ui.short(goal)), {
		Position = UDim2.fromOffset(50, 30),
		Size = UDim2.new(1, -180, 0, 18),
		TextSize = 14,
		TextColor3 = Ui.colors.muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	local bar = Kit.bar(if ready or done then Ui.colors.ready else Ui.colors.xp, {
		Position = UDim2.fromOffset(50, 54),
		Size = UDim2.new(1, -180, 0, 16),
		Parent = card,
	})
	Kit.setBar(bar, if done then 1 else v.value / goal)
	Ui.label(string.format("%s / %s", Ui.short(math.min(v.value, goal)), Ui.short(goal)), {
		Position = UDim2.fromOffset(50, 54),
		Size = UDim2.new(1, -180, 0, 16),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = card,
	})
	local props = {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(116, 40),
		Parent = card,
	}
	if done then
		local button = Ui.button("Done", function() end, props)
		Ui.setEnabled(button, false)
	else
		local reward = string.format("+%d 💎", def.gems[tier])
		if ready then
			props.BackgroundColor3 = Ui.colors.accent
			local button = Ui.button("Claim " .. reward, function() end, props)
			Kit.onTap(button, function()
				Remotes.fire("Records_Claim", def.id)
			end)
		else
			local button = Ui.button(Config.tiers[tier] .. " " .. reward, function() end, props)
			Ui.setEnabled(button, false)
		end
	end
end

local function renderRecords(state: { [string]: any }, body: ScrollingFrame)
	-- Ready ones first, then in the list's order
	local rows = {}
	for i, def in Config.list do
		local v = viewOf(state, def.id) or { id = def.id, value = 0, claimed = 0 }
		table.insert(rows, { def = def, v = v, sort = (if Records.viewReady(v) then 0 else 100) + i })
	end
	table.sort(rows, function(a, b)
		return a.sort < b.sort
	end)
	for i, row in rows do
		recordRow(row.def, row.v, 10 + i, body)
	end
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Farmer Card"
	if headshot == nil then
		fetchHeadshot()
	end
	local ready = FarmerCard.readyCount(state)
	local tab = Panels.tabs({ "Card", "Records" }, 1, { Records = if ready > 0 then tostring(ready) else "" })
	if tab == "Records" then
		renderRecords(state, body)
	else
		renderCard(state, body)
	end
end

function FarmerCard.show()
	Panels.open("FarmerCard")
end

function FarmerCard.init()
	Panels.register("FarmerCard", render, { static = true })
	Hud.handlers.RecordClaim = function(payload)
		Hud.toast(
			string.format("%s %s medal!  +%d Gems  +%d XP", payload.name, payload.tier, payload.gems, payload.xp),
			"celebrate"
		)
	end
	-- A toast when a record's next medal is reached (checked on every state change)
	local known: { [string]: boolean }? = nil
	ClientStore.changed.Event:Connect(function(state)
		if state == nil or state.records == nil then
			return
		end
		local now: { [string]: boolean } = {}
		for _, v in state.records do
			if Records.viewReady(v) then
				now[v.id] = true
				local def = Records.def(v.id)
				if known and not known[v.id] and def then
					Hud.toast(
						string.format(
							"Town Record: %s %s! Claim it on your Farmer Card (P).",
							def.name,
							Config.tiers[v.claimed + 1]
						),
						"celebrate"
					)
				end
			end
		end
		known = now
	end)
end

return FarmerCard
