--!strict
-- The Town Express panel (Design/14 Multiplayer Features C1, shared/Express): opened by tapping
-- the hub station north of the Town Square or the train. While the train is in, it lists the
-- crates to load from your Barn, the reward tiers the whole server is filling toward and how
-- many crates you've loaded; otherwise it says when the next train comes.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Express)
local Express = require(Shared.Express)
local Items = require(Shared.Items)
local Timer = require(Shared.Timer)
local Tools = require(Shared.Config.Tools)

local ClientStore = require(script.Parent.Parent.ClientStore)
local ReachController = require(script.Parent.Parent.Controllers.ReachController)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local ExpressUi = {}

local CRATE_HEIGHT = 56

type Shown = {
	arrivedAt: number,
	leavesAt: number,
	crates: { { item: string, qty: number, filled: boolean } },
	prizes: { Express.Prize },
	loaded: { [string]: number },
	npc: boolean,
}

local function station(): Instance?
	local map = Workspace:FindFirstChild("FarmMap")
	return map and map:FindFirstChild("ExpressStation")
end

-- The train the server publishes on the station, or nil when none is in
function ExpressUi.train(): Shown?
	local model = station()
	local raw = model and model:GetAttribute("Train")
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded :: Shown else nil
end

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

local function prizeText(prize: Express.Prize): string
	local parts = { string.format("+%d Coins", prize.coins) }
	if prize.item and prize.qty then
		local tool = Tools.tools[prize.item]
		local name = if tool
			then (if prize.qty == 1 then tool.displayName else tool.plural)
			elseif Items[prize.item] then Items[prize.item].displayName
			else prize.item
		table.insert(parts, string.format("+%d %s", prize.qty, name))
	end
	return table.concat(parts, ", ")
end

local function crateCard(
	index: number,
	crate: { item: string, qty: number, filled: boolean },
	body: Instance,
	order: number
)
	local card = Ui.card({ Size = UDim2.new(1, -8, 0, CRATE_HEIGHT), LayoutOrder = order, Parent = body })
	local def = Items[crate.item]
	local have = ClientStore.itemCount(crate.item)
	Ui.label(string.format("%d %s", crate.qty, def.displayName), {
		Font = Ui.theme.Type.display,
		TextSize = 15,
		Size = UDim2.new(1, -120, 0, 22),
		Position = UDim2.fromOffset(8, 4),
		Parent = card,
	})
	local xp = Express.crateXp({ item = crate.item, qty = crate.qty })
	Ui.label(if crate.filled then "Loaded" else string.format("You have %d   ·   +%d XP", have, xp), {
		TextSize = 13,
		TextColor3 = if crate.filled
			then Ui.colors.ready
			elseif have >= crate.qty then Ui.colors.muted
			else Ui.colors.danger,
		Size = UDim2.new(1, -120, 0, 18),
		Position = UDim2.fromOffset(8, 28),
		Parent = card,
	})
	if crate.filled then
		return
	end
	local button = Ui.button("Load", function()
		Remotes.fire("Express_Load", index)
	end, { Size = UDim2.fromOffset(100, 36), Position = UDim2.new(1, -106, 0, 10), Parent = card })
	Ui.setEnabled(button, have >= crate.qty)
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Town Express"
	local now = ClientStore.now()
	local train = ExpressUi.train()
	if train == nil or now >= train.leavesAt then
		line(
			string.format("The next Town Express pulls in in %s.", Timer.format(Express.nextArrival(now) - now)),
			1,
			body,
			nil,
			Ui.colors.warn
		)
		line(
			string.format(
				"A giant train stops here every %d hours, on the even hour, for %d minutes. Everyone on the "
					.. "server loads its crates from their own Barns. Each crate pays XP, and every reward "
					.. "tier the server reaches (25, 50, 75 and 100%%) pays everyone who loaded a crate.",
				Config.periodSeconds // 3600,
				Config.windowSeconds // 60
			),
			2,
			body,
			92,
			Ui.colors.muted
		)
		return
	end
	local total = #train.crates
	local filled = 0
	for _, crate in train.crates do
		if crate.filled then
			filled += 1
		end
	end
	local mine = train.loaded[tostring(Players.LocalPlayer.UserId)] or 0
	line(
		string.format(
			"Leaves in %s   ·   %d of %d crates loaded",
			Timer.format(math.max(0, train.leavesAt - now)),
			filled,
			total
		),
		1,
		body,
		nil,
		Ui.colors.warn
	)
	line(
		if mine > 0
			then string.format(
				"You've loaded %d %s: every tier the server reaches pays you.",
				mine,
				if mine == 1 then "crate" else "crates"
			)
			else "Load at least one crate to share in every tier the server reaches.",
		2,
		body,
		38,
		if mine > 0 then Ui.colors.ready else Ui.colors.text
	)
	if train.npc then
		line("Neighbors from the next town help load a crate every few minutes.", 3, body, 38, Ui.colors.muted)
	end
	heading("Reward tiers", 4, body)
	local share = if total > 0 then filled / total else 0
	for tier, at in Config.tiers do
		local prize = train.prizes[tier]
		local reached = share >= at - 1e-9
		line(
			string.format(
				"%s %d%% (%d crates): %s",
				if reached then "✓" else "·",
				math.floor(at * 100 + 0.5),
				math.ceil(at * total - 1e-9),
				if prize then prizeText(prize) else ""
			),
			4 + tier,
			body,
			nil,
			if reached then Ui.colors.ready else Ui.colors.text
		)
	end
	heading("Crates", 10, body)
	local order = 11
	-- Crates still to load first, then the loaded ones
	for pass = 1, 2 do
		for i, crate in train.crates do
			if crate.filled == (pass == 2) then
				crateCard(i, crate, body, order)
				order += 1
			end
		end
	end
end

function ExpressUi.init()
	Panels.register("Express", render)
	-- The station and the train stand off our plot: the reach controller asks what a tap does
	local previous = ReachController.otherTarget
	ReachController.otherTarget = function(part: BasePart)
		if part:GetAttribute("Interact") == "Express" then
			return function()
				Panels.open("Express")
			end, false
		end
		return previous(part)
	end
end

return ExpressUi
