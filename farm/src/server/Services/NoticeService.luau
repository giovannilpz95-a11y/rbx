--!strict
-- The Town Square Notice Board (Design/02 Farming, Prize Crops): the server's recent Prize
-- Crop finds, newest first (repeats grouped), on the board in the Town Square. Works without
-- chat. Server-local and not saved. Tapping the board opens the Neighbors panel, which lists
-- the same lines with a Visit button for each farm they're about (Design/02 "tap-to-visit").

local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Palette = require(Shared.Art.Palette)
local Prize = require(Shared.Config.Prize)

local PlotService = require(script.Parent.PlotService)

local NoticeService = {}

type Entry = { text: string, count: number, visit: number? }

local entries: { Entry } = {} -- newest first; repeats grouped
local board: BasePart? = nil
local text: TextLabel? = nil

local function shownText(entry: Entry): string
	return if entry.count > 1 then string.format("%s  x%d", entry.text, entry.count) else entry.text
end

local function render()
	local shown = {}
	for _, entry in entries do
		table.insert(shown, { text = shownText(entry), visit = entry.visit })
	end
	if text then
		local lines = {}
		for _, line in shown do
			table.insert(lines, line.text)
		end
		text.Text = if #lines == 0 then "Prize Crop finds show up here." else table.concat(lines, "\n")
	end
	-- The client's Neighbors panel lists the same lines, with Visit buttons
	if board then
		board:SetAttribute("Entries", HttpService:JSONEncode(shown))
	end
end

-- Post a line, newest first. `visitUserId`: whose farm the news is about, for tap-to-visit.
function NoticeService.post(line: string, visitUserId: number?)
	local first = entries[1]
	if first and first.text == line and first.visit == visitUserId then
		first.count += 1
		render()
		return
	end
	table.insert(entries, 1, { text = line, count = 1, visit = visitUserId })
	while #entries > Prize.noticeLines do
		table.remove(entries)
	end
	render()
end

function NoticeService.init()
	-- The board stands in the Town Square (shared/Art/TownSquare); this adds its text.
	local face = PlotService.square.boards.Notice
	face:SetAttribute("Interact", "Notice")
	board = face

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = face
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
