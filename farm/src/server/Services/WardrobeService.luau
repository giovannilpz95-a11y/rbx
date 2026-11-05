--!strict
-- The Wardrobe (Config/Wardrobe, shared/Wardrobe; Design/14 I1): farm fashion bought with
-- Coins or Gems or earned at the County Fair, the Plot Showcase and events, worn on top of
-- the player's own avatar. The server welds the pieces to the avatar so everyone sees them.
-- While a farm hat is on, the avatar's own hats are hidden; taking it off brings them back.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtOutfits = require(Shared.Art.Outfits)
local Config = require(Shared.Config.Wardrobe)
local Net = require(Shared.Net)
local Wardrobe = require(Shared.Wardrobe)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local TelemetryService = require(script.Parent.TelemetryService)

local WardrobeService = {}

local ready: { [Player]: boolean } = {}

local OUTFIT = "FarmOutfit"
local HIDDEN = "FarmOutfitHid" -- on a hidden hat's handle: its own transparency
local R6 = { UpperTorso = "Torso" }

-- Hide (or bring back) the avatar's own hats
local function hideHats(character: Model, hide: boolean)
	for _, accessory in character:GetChildren() do
		if not accessory:IsA("Accessory") or accessory.AccessoryType ~= Enum.AccessoryType.Hat then
			continue
		end
		for _, p in accessory:GetDescendants() do
			if p:IsA("BasePart") then
				local was = p:GetAttribute(HIDDEN)
				if hide and was == nil then
					p:SetAttribute(HIDDEN, p.Transparency)
					p.Transparency = 1
				elseif not hide and type(was) == "number" then
					p.Transparency = was
					p:SetAttribute(HIDDEN, nil)
				end
			end
		end
	end
end

-- Dress the avatar in the farm's outfit (or take it all off)
function WardrobeService.apply(player: Player)
	local character = player.Character
	local data = DataService.get(player)
	if character == nil or data == nil then
		return
	end
	local old = character:FindFirstChild(OUTFIT)
	if old then
		old:Destroy()
	end
	local outfit = Wardrobe.outfit(data)
	hideHats(character, outfit.Hat ~= nil)
	if next(outfit) == nil then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = OUTFIT
	for _, slot in Config.slots do
		local id = outfit[slot]
		local where = id and ArtOutfits.attach(id)
		local attach = where and (character:FindFirstChild(where) or character:FindFirstChild(R6[where] or ""))
		if id == nil or attach == nil or not attach:IsA("BasePart") then
			continue
		end
		local size = attach.Size
		if attach.Name == "Head" and character:FindFirstChild("Torso") then
			-- An R6 head part is 2 wide but its head mesh is about as wide as it is deep
			size = Vector3.new(size.Z * 1.2, size.Y * 1.2, size.Z * 1.2)
		end
		local built = ArtOutfits.build(id, size)
		if built == nil then
			continue
		end
		local model = built.model
		model.WorldPivot = CFrame.new() -- built around its body part's centre
		model:PivotTo(attach.CFrame)
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = attach
				weld.Part1 = p
				weld.Parent = p
			end
		end
		model.Parent = folder
	end
	folder.Parent = character
end

local function popup(player: Player, step: string, text: string)
	NetService.popup(player, { kind = "Wardrobe", step = step, text = text })
end

-- Hand over pieces the farm has earned since the last check. True if the save changed.
local function sync(player: Player): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local fresh = Wardrobe.grantEarned(data)
	if #fresh == 0 then
		return false
	end
	local names = {}
	for _, id in fresh do
		table.insert(names, Config.pieces[id].displayName)
		TelemetryService.custom(player, "WardrobeEarned", 1, id)
	end
	DataService.markDirty(player, true)
	popup(
		player,
		"unlocked",
		string.format("New in your Wardrobe: %s! Wear it from Emotes > Wardrobe.", table.concat(names, ", "))
	)
	return true
end

function WardrobeService.buy(player: Player, id: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local piece, reason = Wardrobe.canBuy(data, id)
	if piece == nil then
		return false, reason
	end
	local currency, price = Wardrobe.price(piece)
	if currency == nil or not EconomyService.spend(player, currency, price, "wardrobe_" .. piece.id) then
		return false, "Not enough " .. tostring(currency)
	end
	Wardrobe.give(data, piece.id)
	WardrobeService.apply(player)
	popup(player, "bought", string.format("The %s is yours, and you're wearing it!", piece.displayName))
	return true
end

function WardrobeService.wear(player: Player, slot: any, id: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local ok, reason = Wardrobe.wear(data, slot, id)
	if not ok then
		return false, reason
	end
	DataService.markDirty(player)
	WardrobeService.apply(player)
	return true
end

-- "On" | "Off": show the farm outfit, or go back to just the player's own avatar
local function show(player: Player, value: any): (boolean, string?)
	if value ~= "On" and value ~= "Off" then
		return false
	end
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	data.wardrobe.show = value == "On"
	DataService.markDirty(player)
	WardrobeService.apply(player)
	return true
end

-- Studio: own every piece
function WardrobeService.debug(player: Player): (boolean, string?)
	if not RunService:IsStudio() then
		return false
	end
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	for id in Config.pieces do
		data.wardrobe.owned[id] = true
	end
	DataService.markDirty(player, true)
	NetService.toast(player, "Dev: every Wardrobe piece is yours")
	return true
end

function WardrobeService.init()
	NetService.on(Net.Wardrobe_Buy, 2, 3, WardrobeService.buy)
	NetService.on(Net.Wardrobe_Wear, 4, 6, WardrobeService.wear)
	NetService.on(Net.Wardrobe_Show, 2, 3, show)
	NetService.on(Net.Debug_Wardrobe, 1, 2, WardrobeService.debug)

	local function watch(player: Player)
		-- Dress the avatar once Roblox has put its own accessories on (so the hats can hide)
		player.CharacterAppearanceLoaded:Connect(function()
			WardrobeService.apply(player)
		end)
		NetService.whenReady(player, function()
			ready[player] = true
			sync(player)
			WardrobeService.apply(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.syncSeconds)
			for player in ready do
				if player.Parent and sync(player) then
					NetService.pushState(player)
				end
			end
		end
	end)
end

return WardrobeService
