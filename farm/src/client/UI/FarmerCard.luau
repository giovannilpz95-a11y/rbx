--!strict
-- The Farmer Card and Town Records (UI Reference & Gaps G11; F07 Museum, Albums &
-- Achievements, MVP-lite): the player's Roblox headshot, level, title and key stats, and a
-- Records tab with each record's progress, its Bronze / Silver / Gold medals and Claim.
-- Opens with P or the 🏆 edge icon; the icon gets a dot when a tier can be claimed.
-- Other players' cards (from the Neighbors panel) show their headshot, level, title, stars and
-- the same six numbers, read from the FarmerCard attribute the server keeps on each Player.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Records)
local Records = require(Shared.Records)
local TownRules = require(Shared.TownRules)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local Kit = Ui.theme.Kit
local Palette = Ui.theme.Palette

local FarmerCard = {}

local MEDAL = { Palette.hex("#C9864A"), Palette.hex("#B8C2CC"), Palette.hex("#F2C14E") }
-- Avatar pictures by UserId, each fetched once
local headshots: { [number]: string } = {}
local fetching: { [number]: boolean } = {}

local function headshotOf(userId: number): string
	local image = headshots[userId]
	if image then
		return image
	end
	if not fetching[userId] then
		fetching[userId] = true
		task.spawn(function()
			local ok, got = pcall(function()
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok then
				headshots[userId] = got
				if Panels.isShowing("FarmerCard") then
					Panels.refresh()
				end
			end
		end)
	end
	return ""
end

-- What a card shows, for us (from our state) or another player (from their attribute)
type CardInfo = {
	userId: number,
	displayName: string,
	name: string,
	level: number?,
	stars: number,
	values: { [string]: number },
	townHall: number, -- Town Hall storeys (TownRules.townHall), 1 at the start
	upgrading: boolean, -- a storey is going up
}

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

-- Another player's card from the FarmerCard attribute, or nil if they've left
function FarmerCard.otherInfo(other: Player?): CardInfo?
	if other == nil or other.Parent == nil then
		return nil
	end
	local raw = other:GetAttribute("FarmerCard")
	local card: any = {}
	if type(raw) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(decoded) == "table" then
			card = decoded
		end
	end
	local values: { [string]: number } = {}
	for _, id in Config.card do
		local v = if type(card.stats) == "table" then card.stats[id] else nil
		values[id] = if type(v) == "number" then v else 0
	end
	local level = other:GetAttribute("FarmLevel")
	return {
		userId = other.UserId,
		displayName = other.DisplayName,
		name = other.Name,
		level = if type(level) == "number" then level else nil,
		stars = if type(card.stars) == "number" then card.stars else 0,
		values = values,
		townHall = if type(card.townHall) == "number" then card.townHall else 1,
		upgrading = card.upgrading == true,
	}
end

local function ownInfo(state: { [string]: any }): CardInfo
	local player = Players.LocalPlayer
	local storeys, upgrading = 1, false
	if type(state.town) == "table" and type(state.town.community) == "table" then
		storeys, upgrading = TownRules.townHall(state, ClientStore.now())
	end
	local values: { [string]: number } = {}
	for _, id in Config.card do
		local v = viewOf(state, id)
		values[id] = if v then v.value else 0
	end
	return {
		userId = player.UserId,
		displayName = player.DisplayName,
		name = player.Name,
		level = state.level,
		stars = Records.stars(views(state)),
		values = values,
		townHall = storeys,
		upgrading = upgrading,
	}
end

local function renderCard(info: CardInfo, body: ScrollingFrame, own: boolean)
	local stars = info.stars

	local head = Ui.card({ Name = "Header", Size = UDim2.new(1, -8, 0, 116), LayoutOrder = 2, Parent = body })
	Ui.new("ImageLabel", {
		Name = "Headshot",
		BackgroundColor3 = Palette.hex("#E4F4FF"),
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(96, 96),
		Image = headshotOf(info.userId),
		Parent = head,
	}, { Ui.corner(48), Kit.stroke(Palette.edge, 3, 0) })
	Ui.label(info.displayName, {
		Position = UDim2.fromOffset(118, 10),
		Size = UDim2.new(1, -126, 0, 26),
		Font = Ui.theme.Type.display,
		TextSize = 22,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	Ui.label("@" .. info.name, {
		Position = UDim2.fromOffset(118, 36),
		Size = UDim2.new(1, -126, 0, 18),
		TextSize = 14,
		TextColor3 = Ui.colors.muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	local levelText = if info.level then string.format("Level %d  ·  ", info.level) else ""
	Ui.label(levelText .. Records.title(stars), {
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
	for i, id in Config.card do
		local def = Records.def(id)
		if def then
			local cell = Ui.card({ Name = id, LayoutOrder = i, Parent = grid })
			Ui.label(def.glyph, {
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(0, 30, 1, 0),
				TextSize = 24,
				Parent = cell,
			})
			Ui.label(Ui.short(info.values[id] or 0), {
				Position = UDim2.fromOffset(42, 6),
				Size = UDim2.new(1, -48, 0, 24),
				Font = Ui.theme.Type.display,
				TextSize = 20,
				Parent = cell,
			})
			Ui.label(def.short, {
				Position = UDim2.fromOffset(42, 30),
				Size = UDim2.new(1, -48, 0, 18),
				TextSize = 13,
				TextColor3 = Ui.colors.muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = cell,
			})
		end
	end
	-- The Town Hall's storeys, a town's size at a glance
	local hall = Ui.card({ Name = "TownHall", Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 4, Parent = body })
	Ui.label("🏛", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 30, 1, 0), TextSize = 24, Parent = hall })
	Ui.label(
		string.format(
			"Town Hall: %d %s%s",
			info.townHall,
			if info.townHall == 1 then "storey" else "storeys",
			if info.upgrading then ", another going up" else ""
		),
		{
			Position = UDim2.fromOffset(42, 0),
			Size = UDim2.new(1, -48, 1, 0),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = hall,
		}
	)
	Ui.label(if own then "Finish Town Records for stars and a new title." else "Press P for your own card.", {
		Size = UDim2.new(1, -8, 0, 20),
		TextSize = 14,
		TextColor3 = Ui.colors.muted,
		LayoutOrder = 5,
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

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel, arg: string?)
	-- Another player's card: no Records tab, just what the server shows of theirs
	local otherId = if arg then tonumber(arg) else nil
	if otherId and otherId ~= Players.LocalPlayer.UserId then
		local info = FarmerCard.otherInfo(Players:GetPlayerByUserId(otherId))
		title.Text = if info then info.displayName .. "'s Card" else "Farmer Card"
		if info then
			renderCard(info, body, false)
		else
			Ui.label("That farmer has left the server.", {
				Size = UDim2.new(1, -8, 0, 40),
				TextColor3 = Ui.colors.muted,
				LayoutOrder = 2,
				Parent = body,
			})
		end
		return
	end
	title.Text = "Farmer Card"
	local ready = FarmerCard.readyCount(state)
	local tab = Panels.tabs({ "Card", "Records" }, 1, { Records = if ready > 0 then tostring(ready) else "" })
	if tab == "Records" then
		renderRecords(state, body)
	else
		renderCard(ownInfo(state), body, true)
	end
end

function FarmerCard.show()
	Panels.open("FarmerCard")
end

-- Another player's card (the Neighbors panel's 🏆 button)
function FarmerCard.showOther(userId: number)
	Panels.open("FarmerCard", tostring(userId))
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
