--[[
	A soft tap on every button press, so each tap gets feedback (Design/26 Audio Style Guide).
	Buttons stay quiet when they're invisible hit areas (like Crop Pop's board cells) or
	when they or a parent have the attribute SilentTap = true.
]]

local Players = game:GetService("Players")

local UiTaps = {}

local function isHitArea(button: GuiButton): boolean
	if button.BackgroundTransparency < 1 then
		return false
	end
	if button:IsA("TextButton") and button.Text ~= "" then
		return false
	end
	if button:IsA("ImageButton") and button.Image ~= "" then
		return false
	end
	return true
end

local function isSilent(button: GuiButton, root: Instance): boolean
	if isHitArea(button) then
		return true
	end
	local node: Instance? = button
	while node and node ~= root do
		if node:GetAttribute("SilentTap") then
			return true
		end
		node = node.Parent
	end
	return false
end

function UiTaps.start(GameAudio)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local hooked = setmetatable({}, { __mode = "k" })
	local function hook(inst: Instance)
		if inst:IsA("GuiButton") and not hooked[inst] then
			hooked[inst] = true
			inst.Activated:Connect(function()
				if not isSilent(inst, playerGui) then
					GameAudio.play("UiTap")
				end
			end)
		end
	end
	for _, d in playerGui:GetDescendants() do
		hook(d)
	end
	playerGui.DescendantAdded:Connect(hook)
end

return UiTaps
