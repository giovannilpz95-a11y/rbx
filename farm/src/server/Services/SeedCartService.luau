--!strict
-- The Seed Cart (Design/13 Roblox Success Mechanics §3.7, shared/SeedCart): a cart in the
-- Town Square that restocks every 30 minutes on the UTC clock. Its sign shows the countdown
-- for everyone on the server; each player buys from their own stock in the Seed Cart panel.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtSeedCart = require(Shared.Art.SeedCart)
local ArtTownSquare = require(Shared.Art.TownSquare)
local Config = require(Shared.Config.SeedCart)
local Crops = require(Shared.Config.Crops)
local Decor = require(Shared.Config.Decor)
local Kit = require(Shared.Art.Kit)
local Net = require(Shared.Net)
local SeedCart = require(Shared.SeedCart)
local Timer = require(Shared.Timer)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local Clock = require(script.Parent.Parent.Util.Clock)

local SeedCartService = {}

-- On the plaza's east side, across from the Puzzle Porch, facing the fountain (-X)
local SPOT = Vector3.new(-ArtTownSquare.PORCH.X, 0, ArtTownSquare.PORCH.Z)

local function slotName(slot: SeedCart.Slot): string
	if slot.kind == "Crate" then
		return string.format("%d %s", slot.qty, Crops[slot.id :: string].displayName)
	elseif slot.kind == "Decor" then
		return Decor.items[slot.id :: string].displayName
	end
	return "Heirloom Seed"
end

function SeedCartService.buy(player: Player, index: any): (boolean, string?)
	if not NetService.check.int(index, 1, 4) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local ok, reason, slot = SeedCart.canBuy(data, index, Clock.now())
	if not ok or slot == nil then
		return false, reason
	end
	if slot.kind == "Crate" and InventoryService.space(player) < slot.qty then
		return false, "Your Barn is full. Sell something from the Barn first."
	end
	if not EconomyService.spend(player, "Coins", slot.price, "cart_" .. (slot.id or slot.kind)) then
		return false, string.format("%s costs %d Coins", slotName(slot), slot.price)
	end
	if slot.kind == "Crate" then
		InventoryService.add(player, { [slot.id :: string] = slot.qty })
	elseif slot.kind == "Decor" then
		local id = slot.id :: string
		data.decorCoupons[id] = (data.decorCoupons[id] or 0) + 1
	else
		data.heirloomSeeds += 1
	end
	SeedCart.markBought(data, index)
	DataService.markDirty(player, true)
	NetService.toast(player, string.format("Bought %s", slotName(slot)))
	return true
end

function SeedCartService.init()
	-- Studio previews the cart before its update ships
	if RunService:IsStudio() then
		SeedCart.forceOn(true)
	end
	NetService.on(Net.SeedCart_Buy, 3, 5, SeedCartService.buy)
	if not (Config.enabled or RunService:IsStudio()) then
		return
	end

	local cf = PlotService.squareCFrame() * CFrame.new(SPOT) * Kit.yaw(90)
	local cart = ArtSeedCart.build(PlotService.square.model, cf)
	for _, part in cart.model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("Interact", "SeedCart")
		end
	end
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = cart.sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.fromRGB(90, 60, 40)
	text.Parent = surface
	task.spawn(function()
		while true do
			local now = Clock.now()
			text.Text = "Seed Cart · restocks in " .. Timer.format(math.max(0, SeedCart.restockAt(now) - now))
			task.wait(1)
		end
	end)
end

return SeedCartService
