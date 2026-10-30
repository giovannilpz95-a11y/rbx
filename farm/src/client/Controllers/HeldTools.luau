--!strict
-- The tool your avatar holds for a moment while it works a field: a Scythe to harvest, a Seed
-- Bag to plant and a Watering Can for a friend's field (Model List - Farm & Animals, held
-- tools). The props come from FarmShared.Art.ItemProps and are welded to the right hand on
-- this client only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("FarmShared")
local ArtItemProps = require(Shared.Art.ItemProps)

local HeldTools = {}

local HOLD_SECONDS = 1.6

local held: Model? = nil
local heldId: string? = nil
local token = 0

local function drop()
	if held then
		held:Destroy()
	end
	held, heldId = nil, nil
end

local function hand(): BasePart?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	return (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
end

-- Holds tool `id` (Tool_Scythe, Tool_SeedBag or Tool_WateringCan) for a moment; calling it
-- again while working keeps it in hand.
function HeldTools.flash(id: string)
	local grip = hand()
	if grip == nil then
		return
	end
	if heldId ~= id or held == nil or held.Parent == nil then
		drop()
		local model = ArtItemProps.held(id, grip.CFrame * CFrame.new(0, -grip.Size.Y / 2, -0.1))
		if model == nil then
			return
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, false, true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = grip
				weld.Part1 = d
				weld.Parent = d
			end
		end
		model.Parent = grip.Parent
		held, heldId = model, id
	end
	token += 1
	local mine = token
	task.delay(HOLD_SECONDS, function()
		if token == mine then
			drop()
		end
	end)
end

return HeldTools
