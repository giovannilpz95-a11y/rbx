--!strict
-- The Wardrobe panel (Config/Wardrobe, shared/Wardrobe, WardrobeService): farm fashion worn
-- on top of our own avatar. One tab per slot; each piece can be worn, taken off, bought (Coins
-- from a level, or Gems with a second tap to confirm) or shows how it is earned. A switch at
-- the top shows or hides the whole outfit. Opened from the Emotes panel.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Wardrobe)
local Wardrobe = require(Shared.Wardrobe)

local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local WardrobeUi = {}

local lastTap = 0
local armed: string? = nil -- the Gem piece waiting for its confirming tap
local armedAt = 0

-- One tap, acting on press (the panel rebuilds on every state push)
local function pressButton(text: string, fire: () -> (), enabled: boolean, color: Color3, parent: Instance)
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
		Size = UDim2.fromOffset(120, 34),
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
end

local function pieceCard(state: { [string]: any }, piece: Config.Piece, body: Instance)
	local block = state.wardrobe
	local owned = Wardrobe.owns(state, piece.id)
	local wearing = block.worn[piece.slot] == piece.id
	local c = Ui.card({ Size = UDim2.new(1, -8, 0, 58), LayoutOrder = 10 + piece.order, Parent = body })
	Ui.padding(6).Parent = c
	Ui.label(piece.displayName, { Font = Ui.theme.Type.display, Size = UDim2.new(1, -130, 0, 20), Parent = c })
	local currency, price = Wardrobe.price(piece)
	local line = if wearing
		then "Wearing it now"
		elseif owned then "In your Wardrobe"
		elseif piece.earn then Wardrobe.earnText(piece)
		elseif piece.level and state.level < piece.level then string.format("For sale from level %d", piece.level)
		else "For sale"
	Ui.label(line, {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -130, 0, 28),
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Ui.colors.muted,
		Parent = c,
	})
	if wearing then
		pressButton("Take off", function()
			Remotes.fire("Wardrobe_Wear", piece.slot, "")
		end, true, Ui.colors.selected, c)
	elseif owned then
		pressButton("Wear", function()
			Remotes.fire("Wardrobe_Wear", piece.slot, piece.id)
		end, true, Ui.colors.accent, c)
	elseif currency == "Coins" then
		local open = piece.level == nil or state.level >= piece.level
		pressButton(string.format("%s Coins", Ui.short(price)), function()
			Remotes.fire("Wardrobe_Buy", piece.id)
		end, open and (state.currencies.Coins or 0) >= price, Ui.colors.coins, c)
	elseif currency == "Gems" then
		local isArmed = armed == piece.id and time() - armedAt < 4
		pressButton(
			if isArmed then string.format("Buy: %d Gems?", price) else string.format("%d Gems", price),
			function()
				if armed == piece.id and time() - armedAt < 4 then
					armed = nil
					Remotes.fire("Wardrobe_Buy", piece.id)
				else
					armed = piece.id
					armedAt = time()
					Panels.refresh()
					task.delay(4.1, Panels.refresh) -- back to normal if not confirmed
				end
			end,
			(state.currencies.Gems or 0) >= price,
			if isArmed then Ui.colors.accent else Ui.colors.gems,
			c
		)
	end
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Wardrobe"
	local block = state.wardrobe
	if block == nil then
		return
	end
	local showing = block.show ~= false
	local top = Ui.card({ Size = UDim2.new(1, -8, 0, 46), LayoutOrder = 0, Parent = body })
	Ui.padding(6).Parent = top
	Ui.label(if showing then "Farm outfit: showing" else "Farm outfit: hidden", {
		Font = Ui.theme.Type.display,
		Size = UDim2.new(1, -130, 1, 0),
		Parent = top,
	})
	pressButton(if showing then "Hide it" else "Show it", function()
		Remotes.fire("Wardrobe_Show", if showing then "Off" else "On")
	end, true, Ui.colors.selected, top)

	local names = {}
	for _, slot in Config.slots do
		table.insert(names, Config.slotIcons[slot] .. " " .. Config.slotNames[slot])
	end
	local picked = Panels.tabs(names, 1)
	local slot = Config.slots[table.find(names, picked) or 1]
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = body,
	}, { Ui.list(6) })
	for _, piece in Wardrobe.sorted(slot) do
		pieceCard(state, piece, holder)
	end
	Ui.label(
		"Farm outfits go on top of your own avatar and show only in this game. A farm hat hides your own hats while you wear it.",
		{
			Size = UDim2.new(1, -8, 0, 40),
			TextWrapped = true,
			TextSize = 13,
			TextColor3 = Ui.colors.muted,
			LayoutOrder = 100,
			Parent = holder,
		}
	)
end

function WardrobeUi.init()
	Panels.register("Wardrobe", render)
	Hud.handlers.Wardrobe = function(payload)
		if type(payload.text) == "string" then
			Hud.toast(payload.text, "celebrate")
		end
	end
end

return WardrobeUi
