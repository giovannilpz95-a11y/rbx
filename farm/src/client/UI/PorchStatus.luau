--!strict
-- Over every Puzzle Porch (UI Reference & Gaps G14, G16): the next Crop Pop level and the
-- player's Hearts with the refill countdown, so a walk-up shows where you are before the
-- tap, which opens straight to that level (Social's Porch tap fires CropPopOpen "next").
-- Crop Pop's client keeps the numbers as attributes on ReplicatedStorage.CropPopOpen.
-- Drawn locally, one bubble per porch, because the numbers are this player's own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ui = require(script.Parent.Ui)

local Palette = Ui.theme.Palette

local PorchStatus = {}

local bubbles: { [Model]: TextLabel } = {}

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- "Level 4  ·  ❤️ 3/5  12:04", or "" before Crop Pop has said anything
function PorchStatus.text(attrs: { [string]: any }, now: number): string
	local level, hearts, max = attrs.NextLevel, attrs.Hearts, attrs.HeartsMax
	if type(level) ~= "number" or type(hearts) ~= "number" or type(max) ~= "number" then
		return ""
	end
	local heartText
	if type(attrs.UnlimitedUntil) == "number" and attrs.UnlimitedUntil > now then
		heartText = "❤️ ∞ " .. clock(attrs.UnlimitedUntil - now)
	else
		heartText = string.format("❤️ %d/%d", hearts, max)
		if hearts < max and type(attrs.NextHeartAt) == "number" then
			heartText ..= "  " .. clock(attrs.NextHeartAt - now)
		end
	end
	return string.format("Level %d  ·  %s", level, heartText)
end

-- Every porch model on the map: the Model holding parts tagged Interact = PuzzlePorch
local function porches(): { Model }
	local out: { Model } = {}
	local seen: { [Model]: boolean } = {}
	local map = Workspace:FindFirstChild("FarmMap")
	if map == nil then
		return out
	end
	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Interact") == "PuzzlePorch" then
			local model = part:FindFirstAncestorOfClass("Model")
			if model and not seen[model] then
				seen[model] = true
				table.insert(out, model)
			end
		end
	end
	return out
end

local function bubbleFor(model: Model, gui: Folder): TextLabel
	local label = bubbles[model]
	if label and label.Parent then
		return label
	end
	local board = Ui.new("BillboardGui", {
		Name = "PorchStatus",
		Adornee = model,
		Size = UDim2.fromOffset(190, 30),
		ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0), -- just over the porch's top
		StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0),
		MaxDistance = 60,
		Parent = gui,
	})
	local created = Ui.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.timer,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Palette.textOnColor,
		Text = "",
		Parent = board,
	}, { Ui.corner(15), Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
	bubbles[model] = created
	return created
end

function PorchStatus.init()
	local gui = Ui.new("Folder", { Name = "FarmPorchStatus" })
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	task.spawn(function()
		local list: { Model } = {}
		local tick = 0
		while true do
			if tick % 5 == 0 then
				list = porches() -- plots come and go as players join and leave
			end
			tick += 1
			local event = ReplicatedStorage:FindFirstChild("CropPopOpen")
			local text = if event then PorchStatus.text(event:GetAttributes(), os.time()) else ""
			for _, model in list do
				if model.Parent then
					local label = bubbleFor(model, gui)
					label.Text = text
					label.Visible = text ~= ""
				end
			end
			for model, label in bubbles do
				if model.Parent == nil then
					(label.Parent :: Instance):Destroy()
					bubbles[model] = nil
				end
			end
			task.wait(1)
		end
	end)
end

return PorchStatus
