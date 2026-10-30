--!strict
-- The Seed Cart panel (shared/SeedCart): tap the cart in the Town Square to see this
-- restock's four slots, buy with Coins, and see when it restocks.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.SeedCart)
local Crops = require(Shared.Config.Crops)
local Decor = require(Shared.Config.Decor)
local SeedCart = require(Shared.SeedCart)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local ReachController = require(script.Parent.Parent.Controllers.ReachController)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local SeedCartUi = {}

local lastTap = 0

-- One tap, acting on press: the panel re-renders every second, which can swap a button out
-- between press and release. Press and Activated can both arrive; the first one wins.
local function pressButton(text: string, fire: () -> (), props: { [string]: any }, enabled: boolean): TextButton
	local function tap()
		if not enabled or time() - lastTap < 0.35 then
			return
		end
		lastTap = time()
		fire()
	end
	local button = Ui.button(text, tap, props)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tap()
		end
	end)
	Ui.setEnabled(button, enabled, props.BackgroundColor3)
	return button
end

local function describe(slot: SeedCart.Slot): (string, string)
	if slot.kind == "Crate" then
		local crop = Crops[slot.id :: string]
		return string.format("Crate of %d %s", slot.qty, crop.displayName), "Straight into your Barn"
	elseif slot.kind == "Decor" then
		local def = Decor.items[slot.id :: string]
		return def.displayName,
			string.format("%d%% off. Prepaid: place it from Decorations for free", Config.decorDiscount * 100)
	end
	return "Heirloom Seed ✨",
		string.format("Your next field planted has %d× the Heirloom chance", Config.heirloomBoost)
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Seed Cart"
	local now = ClientStore.now()
	if not SeedCart.isOpen({ level = state.level }) then
		Ui.label(string.format("The Seed Cart opens at level %d.", Config.unlockLevel), {
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 40),
			Parent = body,
		})
		return
	end
	local period = SeedCart.period(now)
	local cart = state.seedCart or { period = -1, bought = {} }
	local bought = if cart.period == period then cart.bought else {}
	for i, slot in SeedCart.stock(period, state.level) do
		local name, note = describe(slot)
		local card = Ui.card({ Size = UDim2.new(1, -8, 0, 54), LayoutOrder = i, Parent = body })
		Ui.padding(6).Parent = card
		Ui.label(name, {
			Font = Ui.theme.Type.display,
			Size = UDim2.new(1, -120, 0, 20),
			Parent = card,
		})
		Ui.label(note, {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -120, 0, 18),
			TextSize = 14,
			TextColor3 = Ui.colors.muted,
			Parent = card,
		})
		local sold = bought[tostring(i)] == true
		local coins = state.currencies and state.currencies.Coins or 0
		pressButton(if sold then "Sold out" else string.format("%d Coins", slot.price), function()
			Remotes.fire("SeedCart_Buy", i)
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(110, 34),
			BackgroundColor3 = Ui.colors.coins,
			Parent = card,
		}, not sold and coins >= slot.price)
	end

	local extras = {}
	if (state.heirloomSeeds or 0) > 0 then
		table.insert(extras, string.format("Heirloom Seeds ready: %d", state.heirloomSeeds))
	end
	for id, n in state.decorCoupons or {} do
		if Decor.items[id] then
			table.insert(extras, string.format("Prepaid %s ×%d", Decor.items[id].displayName, n))
		end
	end
	table.insert(
		extras,
		string.format(
			"Restocks in %s (every 30 minutes, the same time on every server).",
			Timer.format(math.max(0, SeedCart.restockAt(now) - now))
		)
	)
	Ui.label(table.concat(extras, "\n"), {
		Size = UDim2.new(1, -8, 0, 18 * #extras + 4),
		TextWrapped = true,
		TextSize = 13,
		TextColor3 = Ui.colors.muted,
		LayoutOrder = 10,
		Parent = body,
	})
end

function SeedCartUi.init()
	if RunService:IsStudio() then
		SeedCart.forceOn(true) -- as the server does: Studio previews it before its update
	end
	Panels.register("SeedCart", function(state, body, title)
		render(state, body, title)
	end)
	-- The cart stands in the Town Square, off our plot: the reach controller asks the social
	-- controls (and us) what a tap there does
	local previous = ReachController.otherTarget
	ReachController.otherTarget = function(part: BasePart)
		if part:GetAttribute("Interact") == "SeedCart" then
			return function()
				Panels.open("SeedCart")
			end, false
		end
		return previous(part)
	end
end

return SeedCartUi
