--!strict
-- Farm emotes and the Town Square photo spots (Config/Emotes; Design/14 I1, I2). The client
-- plays the emote's animation on its own avatar (Roblox replicates it); the server checks the
-- cooldown and welds the emote's prop to the avatar for everyone to see, then takes it off.
-- A photo spot's group pose sends everyone standing in its frame the same pose at once.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local ArtEmoteProps = require(Shared.Art.EmoteProps)
local Config = require(Shared.Config.Emotes)
local Net = require(Shared.Net)

local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)

local EmoteService = {}

local lastEmote: { [Player]: number } = {}
local worn: { [Player]: { model: Model, token: number } } = {}
local nextToken = 0

type Spot = { kind: string, cf: CFrame, last: number }
local spots: { [string]: Spot } = {}

-- R6 avatars have no hands or upper torso: the nearest part they do have
local R6 = { RightHand = "Right Arm", UpperTorso = "Torso" }

local function takeOff(player: Player)
	local current = worn[player]
	worn[player] = nil
	if current and current.model.Parent then
		current.model:Destroy()
	end
end

-- Weld the emote's prop to the avatar for Config.seconds (a newer emote replaces it)
local function wear(player: Player, emoteId: string): boolean
	local def = Config.emotes[emoteId]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if def == nil or character == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local prop = ArtEmoteProps.build(def.prop)
	if prop == nil then
		return false
	end
	local attach = character:FindFirstChild(prop.attach) or character:FindFirstChild(R6[prop.attach] or "")
	if attach == nil or not attach:IsA("BasePart") then
		prop.model:Destroy()
		return false
	end
	takeOff(player)
	local model = prop.model
	model.WorldPivot = CFrame.new() -- the prop is built around its attach point
	model:PivotTo(attach.CFrame * prop.offset)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = attach
			weld.Part1 = p
			weld.Parent = p
		end
	end
	model.Parent = character
	nextToken += 1
	local token = nextToken
	worn[player] = { model = model, token = token }
	task.delay(Config.seconds, function()
		local current = worn[player]
		if current and current.token == token then
			takeOff(player)
		end
	end)
	return true
end

function EmoteService.play(player: Player, emoteId: any): (boolean, string?)
	if type(emoteId) ~= "string" or Config.emotes[emoteId] == nil then
		return false
	end
	local now = os.clock()
	if now - (lastEmote[player] or -math.huge) < Config.cooldown then
		return false -- the client waits out the same cooldown; a fast repeat is just dropped
	end
	lastEmote[player] = now
	wear(player, emoteId)
	return false -- nothing in the save changed: no state to push
end

---------------------------------------------------------------------------------------------
-- Photo spots
---------------------------------------------------------------------------------------------

-- Where the spots may stand on the plaza (plaza-local degrees around the fountain's centre
-- line, and studs out), tried in order: the two south corners first, clear of the boards
-- (north), the Puzzle Porch (west) and the Seed Cart (east). Each one faces the middle.
local ANGLES = { 45, 135, 60, 120, 30, 150, 75, 105, 15, 165, -15, 195 }
local RADII = { 25, 22, 28 }
-- The spot's footprint: its frame and prop behind, and room to stand in front
local CLEARANCE = Vector3.new(14, 10, 13)
local CLEARANCE_AT = CFrame.new(0, 5.5, 1)

local function findSpot(skip: { Instance }): CFrame?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = skip
	for _, radius in RADII do
		for _, degrees in ANGLES do
			local a = math.rad(degrees)
			local x, z = math.cos(a) * radius, math.sin(a) * radius
			local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), params)
			if hit and hit.Position.Y < 2 and hit.Normal.Y > 0.9 then
				-- Face the middle of the plaza: local -Z looks at it, the prop stands behind
				local cf = CFrame.lookAt(hit.Position, Vector3.new(0, hit.Position.Y, 0))
				local blocked = false
				for _, p in Workspace:GetPartBoundsInBox(cf * CLEARANCE_AT, CLEARANCE, overlap) do
					if p.Transparency < 1 or p.CanCollide then -- not an invisible zone
						blocked = true
						break
					end
				end
				if not blocked then
					return cf
				end
			end
		end
	end
	return nil
end

local function buildSpots()
	local parent = PlotService.square.model
	local skip: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	local kinds = {}
	for kind in Config.photoSpots do
		table.insert(kinds, kind)
	end
	table.sort(kinds, function(a, b)
		return Config.photoSpots[a].order < Config.photoSpots[b].order
	end)
	for _, kind in kinds do
		local cf = findSpot(skip)
		if cf == nil then
			warn("[EmoteService] no open ground on the plaza for the photo spot", kind)
			continue
		end
		local model = ArtEmoteProps.photoSpot(kind, parent, cf)
		model:SetAttribute("PhotoSpot", kind)
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p:SetAttribute("Interact", "PhotoSpot")
				p:SetAttribute("PhotoSpot", kind)
			end
		end
		spots[kind] = { kind = kind, cf = cf, last = -math.huge }
	end
end

-- Everyone standing in the frame strikes the same pose together
function EmoteService.pose(player: Player, kind: any): (boolean, string?)
	if type(kind) ~= "string" then
		return false
	end
	local spot = spots[kind]
	if spot == nil then
		return false
	end
	local where = spot.cf.Position
	if not NetService.isNear(player, where, Config.photoRadius) then
		return false, "Stand in the photo spot's frame for a group pose"
	end
	local now = os.clock()
	if now - spot.last < Config.photoCooldown then
		return false -- someone just posed here: that pose covers everyone in the frame
	end
	spot.last = now
	local posers = {}
	for _, other in Players:GetPlayers() do
		if NetService.isNear(other, where, Config.photoRadius) then
			table.insert(posers, other)
		end
	end
	local name = Config.photoSpots[kind].displayName
	for _, other in posers do
		lastEmote[other] = now
		wear(other, Config.photoEmote)
		NetService.popup(other, {
			kind = "GroupPose",
			spot = name,
			count = #posers,
			by = player.DisplayName,
			presser = other == player,
		})
	end
	return false
end

function EmoteService.init()
	NetService.on(Net.Emote_Play, 2, 3, EmoteService.play)
	NetService.on(Net.Emote_Pose, 1, 2, EmoteService.pose)
	Players.PlayerRemoving:Connect(function(player)
		lastEmote[player] = nil
		worn[player] = nil
	end)
	buildSpots()
end

-- Tests and Studio: where the spots ended up
function EmoteService.spots(): { [string]: CFrame }
	local out = {}
	for kind, spot in spots do
		out[kind] = spot.cf
	end
	return out
end

return EmoteService
