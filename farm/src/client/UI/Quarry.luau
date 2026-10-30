--!strict
-- The Quarry panel (Features/F01 Quarry & Smelter, shared/Quarry): tap the Quarry's hill to
-- reopen it, then dig its shaft here, like Township's mine. The shaft is drawn from the seed in
-- the save; only cells beside an open spot show what they hold. Tap one to swing a Pickaxe.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Quarry)
local Land = require(Shared.Config.Land)
local Quarry = require(Shared.Quarry)
local Speedup = require(Shared.Speedup)
local Timer = require(Shared.Timer)
local TownRules = require(Shared.TownRules)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local QuarryUi = {}

local ROWS_SHOWN = 9
local CELL_HEIGHT = 30
local lastTap = 0
local top: number? = nil -- the first row shown; nil follows the digging

local BLOCK_COLORS = {
	Soil = Color3.fromRGB(150, 105, 70),
	Stone = Color3.fromRGB(150, 145, 160),
	Bedrock = Color3.fromRGB(70, 62, 75),
}
local OPEN_COLOR = Color3.fromRGB(55, 40, 32)
local HIDDEN_COLOR = Color3.fromRGB(95, 80, 70)
local SKY_COLOR = Color3.fromRGB(150, 205, 120)
local ORE_COLORS = {
	CopperOre = Color3.fromRGB(215, 120, 60),
	IronOre = Color3.fromRGB(120, 130, 150),
	SilverOre = Color3.fromRGB(225, 230, 240),
	GoldOre = Color3.fromRGB(250, 205, 60),
}

-- Acts on press: the panel re-renders every second, which can swap a cell out between press
-- and release. Press and Activated can both arrive; the first one wins.
local function onTap(button: GuiButton, fire: () -> ())
	local function tap()
		if time() - lastTap < Config.digCooldown then
			return
		end
		lastTap = time()
		fire()
	end
	button.Activated:Connect(tap)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tap()
		end
	end)
end

local function line(text: string, order: number, body: Instance, props: { [string]: any }?)
	local label = Ui.label(text, {
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, 22),
		TextSize = 14,
		LayoutOrder = order,
		Parent = body,
	})
	for k, v in props or {} do
		(label :: any)[k] = v
	end
	return label
end

local function findMark(cell: Quarry.Cell): (string?, Color3?)
	if cell.find and Config.ores[cell.find] then
		return "●", ORE_COLORS[cell.find]
	elseif cell.find == "Lunchbox" then
		return "🎁", nil
	elseif cell.coins then
		return "$", Ui.colors.coins
	end
	return nil, nil
end

local function shaft(state: { [string]: any }, body: Instance, order: number)
	local q = state.quarry
	local depth = Quarry.depth(q)
	local first = top or math.max(0, depth - 3)
	local grid = Ui.new("Frame", {
		Size = UDim2.new(1, -8, 0, ROWS_SHOWN * CELL_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = body,
	})
	for i = 0, ROWS_SHOWN - 1 do
		local row = first + i
		Ui.label(if row == 0 then "0 m" else row .. " m", {
			Size = UDim2.new(0, 40, 0, CELL_HEIGHT),
			Position = UDim2.fromOffset(0, i * CELL_HEIGHT),
			TextSize = 12,
			TextColor3 = Ui.colors.muted,
			Parent = grid,
		})
		for col = 1, Config.width do
			local x = UDim2.new((col - 1) / Config.width, 42 - 42 * (col - 1) / Config.width, 0, i * CELL_HEIGHT)
			local size = UDim2.new(1 / Config.width, -2 - 42 / Config.width, 0, CELL_HEIGHT - 2)
			local open = Quarry.isOpen(q, row, col)
			local color, text, textColor = HIDDEN_COLOR, "", Ui.colors.buttonText
			local diggable = false
			if row == 0 then
				color = SKY_COLOR
			elseif open then
				color = OPEN_COLOR
			elseif Quarry.inReach(q, row, col) then
				local cell = Quarry.cell(q.seed, row, col)
				color = BLOCK_COLORS[cell.block]
				local mark, markColor = findMark(cell)
				if mark then
					text, textColor = mark, markColor or textColor
				end
				if cell.block == "Stone" and (q.hits[row .. ":" .. col] or 0) > 0 then
					text = text .. "✕"
				end
				diggable = cell.block ~= "Bedrock"
			end
			local cellButton = Ui.new("TextButton", {
				Text = text,
				TextColor3 = textColor,
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				AutoButtonColor = diggable,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Position = x,
				Size = size,
				Parent = grid,
			})
			Ui.corner(4).Parent = cellButton
			if diggable then
				onTap(cellButton, function()
					Remotes.fire("Quarry_Dig", row, col)
				end)
			end
		end
	end
	-- Look up and down the shaft; "Follow" goes back to the digging
	local nav = Ui.new("Frame", {
		Size = UDim2.new(1, -8, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = order + 1,
		Parent = body,
	})
	local function navButton(text: string, x: number, fire: () -> ())
		Ui.button(text, function()
			fire()
			Panels.refresh()
		end, {
			Position = UDim2.new(x, 0, 0, 0),
			Size = UDim2.new(1 / 3, -4, 1, 0),
			Parent = nav,
		})
	end
	navButton("▲ Up", 0, function()
		top = math.max(0, first - ROWS_SHOWN + 2)
	end)
	navButton("Follow", 1 / 3, function()
		top = nil
	end)
	navButton("▼ Down", 2 / 3, function()
		top = math.min(math.max(depth - 1, 0), first + ROWS_SHOWN - 2)
	end)
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Quarry"
	local now = ClientStore.now()
	local q = state.quarry
	if q == nil then
		return
	end
	if q.readyAt == nil then
		if state.level < Config.unlockLevel then
			line(string.format("An old quarry, boarded up. It can reopen at level %d.", Config.unlockLevel), 1, body)
			return
		end
		if not TownRules.landDone({ land = state.land }, Config.land, now) then
			line(
				string.format(
					"The Quarry stands in the %s. Clear that land first.",
					Land.expansions[Config.land].displayName
				),
				1,
				body
			)
			return
		end
		line(
			string.format(
				"Reopen the old Quarry to dig for ore. It takes %s and gives %d Pickaxes to start.",
				Timer.format(Config.restoreSeconds),
				Config.restoreGift
			),
			1,
			body,
			{ Size = UDim2.new(1, -8, 0, 40) }
		)
		local coins = state.currencies and state.currencies.Coins or 0
		local button = Ui.button(string.format("Reopen  %d Coins", Config.restoreCost), function()
			Remotes.fire("Quarry_Restore")
		end, {
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundColor3 = Ui.colors.coins,
			LayoutOrder = 2,
			Parent = body,
		})
		Ui.setEnabled(button, coins >= Config.restoreCost, Ui.colors.coins)
		return
	end
	if now < q.readyAt then
		local left = q.readyAt - now
		line("Reopening: " .. Timer.format(math.max(0, left)) .. " left", 1, body)
		Panels.gemButton("QuarrySpeedUp", "Finish now", Speedup.building(left), function()
			Remotes.fire("Quarry_SpeedUp")
		end, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 2, Parent = body })
		return
	end

	local tools = state.tools or {}
	line(
		string.format("⛏ Pickaxes: %d     Deepest: %d m", tools[Config.pickaxe] or 0, Quarry.depth(q)),
		1,
		body,
		{ Font = Ui.theme.Type.display, TextSize = 16 }
	)
	if q.freeDay ~= now // 86400 then
		Ui.button(string.format("Take today's %d free Pickaxes", Config.dailyFree), function()
			Remotes.fire("Quarry_Free")
		end, {
			Size = UDim2.new(1, -8, 0, 36),
			BackgroundColor3 = Ui.colors.ready,
			LayoutOrder = 2,
			Parent = body,
		})
	end
	shaft(state, body, 3)
	-- The Ore Shed
	local shed = {}
	for _, id in Quarry.ORE_IDS do
		table.insert(shed, string.format("%s %d", Config.ores[id].displayName, (state.oreShed or {})[id] or 0))
	end
	line("Ore Shed: " .. table.concat(shed, " · "), 10, body, {
		TextColor3 = Ui.colors.muted,
		Size = UDim2.new(1, -8, 0, 36),
	})
	line("Tap a block beside an open spot to dig it. Stone takes two swings; Bedrock can't be dug.", 11, body, {
		TextColor3 = Ui.colors.muted,
		TextSize = 12,
		Size = UDim2.new(1, -8, 0, 32),
	})
end

function QuarryUi.init()
	Panels.register("Quarry", render)
end

return QuarryUi
