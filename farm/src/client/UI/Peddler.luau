--!strict
-- The Wandering Peddler (shared/Peddler, SkyService; Design/14 H2): a rare cart in the Town
-- Square for a few minutes. This draws the cart (only on this client, from the workspace's
-- "SkyPeddler" attribute), opens the panel when you walk up to it, and lists your three
-- offers. Buying is checked by the server.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Sky)
local Decor = require(Shared.Config.Decor)
local Palette = require(Shared.Art.Palette)
local Peddler = require(Shared.Peddler)
local SeedCartConfig = require(Shared.Config.SeedCart)
local Timer = require(Shared.Timer)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local PeddlerUi = {}

local OPEN_STUDS = 10 -- walking this close opens the panel
local REARM_STUDS = 18 -- and walking this far away lets it open again

type Visit = { id: number, x: number, y: number, z: number, endsAt: number }
local visit: Visit? = nil
local cart: Model? = nil
local armed = true
local lastTap = 0

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = model
	return p
end

-- A small wooden cart with a striped canopy and a lantern
local function buildCart(pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "PeddlerCart"
	local base = CFrame.new(pos) * CFrame.Angles(0, math.rad(180), 0)
	part(model, "Bed", Vector3.new(6, 1.6, 3.4), base * CFrame.new(0, 2, 0), Palette.wood)
	part(model, "Crates", Vector3.new(2, 1.2, 2), base * CFrame.new(-1.5, 3.4, 0), Palette.woodLight)
	part(model, "Sack", Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(1.4, 3.6, 0.2), Palette.straw, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		part(
			model,
			"Wheel",
			Vector3.new(0.4, 2.4, 2.4),
			base * CFrame.new(-1.5, 1.2, side * 1.9) * CFrame.Angles(0, math.rad(90), 0),
			Palette.woodDark,
			Enum.PartType.Cylinder
		)
		part(model, "Post", Vector3.new(0.25, 3.4, 0.25), base * CFrame.new(side * 2.7, 4.4, 1.5), Palette.woodDark)
		part(model, "Post", Vector3.new(0.25, 3.4, 0.25), base * CFrame.new(side * 2.7, 4.4, -1.5), Palette.woodDark)
	end
	-- Canopy stripes
	for i = 0, 5 do
		local color = if i % 2 == 0 then Color3.fromRGB(155, 114, 230) else Palette.cream
		part(model, "Canopy", Vector3.new(1, 0.25, 3.8), base * CFrame.new(-2.5 + i, 6.2, 0), color)
	end
	local lantern =
		part(model, "Lantern", Vector3.new(0.6, 0.8, 0.6), base * CFrame.new(2.9, 5.5, 1.7), Palette.lantern)
	lantern.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = Palette.lantern
	light.Range = 10
	light.Parent = lantern
	local sign = part(model, "Sign", Vector3.new(4.4, 1, 0.2), base * CFrame.new(0, 7, 1.95), Palette.woodLight)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- faces the plaza (the cart is turned around)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = Palette.cocoa
	text.Text = "WANDERING PEDDLER"
	text.Parent = gui
	gui.Parent = sign
	return model
end

local function apply(text: string)
	local decoded: Visit? = nil
	if text ~= "" then
		local ok, v = pcall(HttpService.JSONDecode, HttpService, text)
		if ok and type(v) == "table" and type(v.x) == "number" then
			decoded = v
		end
	end
	if decoded and visit and decoded.id == visit.id then
		return
	end
	if cart then
		cart:Destroy()
		cart = nil
	end
	visit = decoded
	armed = true
	if decoded then
		local model = buildCart(Vector3.new(decoded.x, decoded.y, decoded.z))
		model.Parent = Workspace
		cart = model
	elseif Panels.isShowing("Peddler") then
		Panels.close()
	end
end

local function describe(slot: Peddler.Slot): (string, string)
	if slot.kind == "Seeds" then
		return string.format("%d Heirloom Seeds ✨", slot.qty),
			string.format("Each gives a field planted %d× the Heirloom chance", SeedCartConfig.heirloomBoost)
	end
	local def = Decor.items[slot.id :: string]
	if slot.early then
		return def.displayName,
			string.format("Before its level (%d)! Prepaid: place it from Decorations", def.unlockLevel)
	end
	return def.displayName,
		string.format("%d%% off. Prepaid: place it from Decorations", math.floor(Config.peddler.dealDiscount * 100))
end

local function buyButton(text: string, index: number, enabled: boolean, card: Instance)
	local function tap()
		if not enabled or time() - lastTap < 0.35 then
			return
		end
		lastTap = time()
		Remotes.fire("Peddler_Buy", index)
	end
	local button = Ui.button(text, tap, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(110, 34),
		BackgroundColor3 = Ui.colors.coins,
		Parent = card,
	})
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tap()
		end
	end)
	Ui.setEnabled(button, enabled, Ui.colors.coins)
end

local function render(state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Wandering Peddler"
	local v = visit
	if v == nil then
		Ui.label("The Peddler has moved on. Watch the Notice Board for the next visit.", {
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 40),
			Parent = body,
		})
		return
	end
	local saved = state.peddler or { visit = 0, bought = {} }
	local bought = if saved.visit == v.id then saved.bought else {}
	local coins = state.currencies and state.currencies.Coins or 0
	for i, slot in Peddler.stock(v.id, Players.LocalPlayer.UserId, state.level) do
		local name, note = describe(slot)
		local card = Ui.card({ Size = UDim2.new(1, -8, 0, 58), LayoutOrder = i, Parent = body })
		Ui.padding(6).Parent = card
		Ui.label(name, { Font = Ui.theme.Type.display, Size = UDim2.new(1, -120, 0, 20), Parent = card })
		Ui.label(note, {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, -120, 0, 28),
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = Ui.colors.muted,
			Parent = card,
		})
		local sold = bought[tostring(i)] == true
		buyButton(
			if sold then "Bought ✓" else string.format("%d Coins", slot.price),
			i,
			not sold and coins >= slot.price,
			card
		)
	end
	local function left(): string?
		local t = ClientStore.now()
		if t >= v.endsAt then
			return nil
		end
		return string.format(
			"These offers are yours alone. The Peddler moves on in %s.",
			Timer.format(math.max(0, v.endsAt - t))
		)
	end
	Panels.liveText(
		Ui.label(left() or "", {
			Size = UDim2.new(1, -8, 0, 36),
			TextWrapped = true,
			TextSize = 13,
			TextColor3 = Ui.colors.muted,
			LayoutOrder = 10,
			Parent = body,
		}),
		left
	)
end

local function step()
	local v = visit
	if v == nil then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local offset = root.Position - Vector3.new(v.x, v.y, v.z)
	local d = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if armed and d <= OPEN_STUDS then
		armed = false
		Panels.open("Peddler")
	elseif d >= REARM_STUDS then
		armed = true
	end
end

function PeddlerUi.init()
	Panels.register("Peddler", render, { live = true })
	Workspace:GetAttributeChangedSignal("SkyPeddler"):Connect(function()
		apply(Workspace:GetAttribute("SkyPeddler") or "")
	end)
	apply(Workspace:GetAttribute("SkyPeddler") or "")
	RunService.Heartbeat:Connect(step)
end

return PeddlerUi
