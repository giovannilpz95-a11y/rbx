--!strict
-- The Town Square Notice Board (Design/02 Farming, Prize Crops): the server's recent Prize
-- Crop finds, newest first, on a board by the hub spawn. Works without chat. Server-local and
-- not saved; the social slice can move the board when the Town Square gets its layout.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Palette = require(Shared.Art.Palette)
local Prize = require(Shared.Config.Prize)

local NoticeService = {}

local lines: { string } = {}
local text: TextLabel? = nil

local function render()
	if text then
		text.Text = if #lines == 0 then "Prize Crop finds show up here." else table.concat(lines, "\n")
	end
end

function NoticeService.post(line: string)
	table.insert(lines, 1, line)
	while #lines > Prize.noticeLines do
		table.remove(lines)
	end
	render()
end

function NoticeService.init()
	local map = Workspace:WaitForChild("FarmMap")
	local board = Instance.new("Part")
	board.Name = "NoticeBoard"
	board.Anchored = true
	board.Size = Vector3.new(12, 7, 0.5)
	-- North of the hub spawn, face toward +Z (where players land and look)
	board.CFrame = CFrame.new(0, 5, -14)
	board.Color = Palette.cork
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = map
	for _, x in { -5.5, 5.5 } do
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.Size = Vector3.new(0.6, 8.5, 0.6)
		post.CFrame = CFrame.new(x, 4.25, -14.4)
		post.Color = Palette.trunk
		post.Parent = board
	end

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back -- local +Z
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.18, 0)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Palette.cocoa
	title.Text = "Notice Board: Prize Crops"
	title.Parent = surface
	local body = Instance.new("TextLabel")
	body.Position = UDim2.fromScale(0.04, 0.2)
	body.Size = UDim2.fromScale(0.92, 0.76)
	body.BackgroundTransparency = 1
	-- One line per find at a fixed size (scaled text clipped long lines); too long ends in "..."
	body.TextSize = 22
	body.TextWrapped = false
	body.TextTruncate = Enum.TextTruncate.AtEnd
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Palette.cocoa
	body.Parent = surface
	text = body
	render()
end

return NoticeService
