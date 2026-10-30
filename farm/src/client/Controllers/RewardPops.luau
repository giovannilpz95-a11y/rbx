--!strict
-- When you earn Coins, Gems or XP, a few spinning pickups pop out beside your avatar and float
-- off toward the HUD (FarmShared.Art.Pickups). Client-only and purely for show: the HUD's own
-- counters stay the source of truth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local ArtMotion = require(Shared.Art.Motion)
local ArtPickups = require(Shared.Art.Pickups)
local ClientStore = require(script.Parent.Parent.ClientStore)

local RewardPops = {}

local MAX_PER_KIND = 3 -- tokens per reward, whatever its size
local last: { [string]: number } = {}

local function pop(kind: string, count: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local from = root.Position + Vector3.new(0, 1, 0)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.6
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local model = ArtPickups.build(kind)
		model.Parent = Workspace
		local began = os.clock() + (i - 1) * 0.08
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = (os.clock() - began) / ArtMotion.PICKUP_SECONDS
			if a < 0 then
				return
			end
			local pos, spin, scale = ArtMotion.pickupPath(from, dir, a)
			model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, spin, 0))
			model:ScaleTo(math.max(0.05, scale))
			if a >= 1 then
				conn:Disconnect()
				model:Destroy()
			end
		end)
	end
end

function RewardPops.init()
	local current = ClientStore.state
	if current and type(current.currencies) == "table" then
		for _, kind in ArtPickups.KINDS do
			last[kind] = current.currencies[kind]
		end
	end
	ClientStore.changed.Event:Connect(function(state)
		local currencies = state and state.currencies
		if type(currencies) ~= "table" then
			return
		end
		for _, kind in ArtPickups.KINDS do
			local value = currencies[kind]
			if type(value) ~= "number" then
				continue
			end
			local before = last[kind]
			last[kind] = value
			if before ~= nil and value > before then
				pop(kind, math.min(MAX_PER_KIND, math.max(1, math.ceil((value - before) / 10))))
			end
		end
	end)
end

return RewardPops
