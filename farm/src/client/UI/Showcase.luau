--!strict
-- The Plot Showcase on this client (Config/Showcase, ShowcaseService): sunflower banners over
-- the gates of farms on show, the winner's ribbon over theirs (both from the workspace's
-- "Showcase" attribute), the rating card a visitor gets after a while on a farm on show, and
-- the Showcase's toasts.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Palette = require(Shared.Art.Palette)
local Showcase = require(Shared.Showcase)

local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local ShowcaseUi = {}

local folder: Folder? = nil
local rating: { owner: number, name: string }? = nil
local lastTap = 0

local function marker(parent: Instance, pos: Vector3, text: string, color: Color3)
	local p = Instance.new("Part")
	p.Name = "ShowcaseMarker"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 44)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = color
	label.BackgroundTransparency = 0.1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Palette.cocoa
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = p
	p.Parent = parent
end

local function apply(text: string)
	if folder then
		folder:Destroy()
		folder = nil
	end
	if text == "" then
		return
	end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, text)
	if not ok or type(v) ~= "table" then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "Showcase"
	for _, plot in v.plots or {} do
		if type(plot.x) == "number" then
			marker(f, Vector3.new(plot.x, plot.y + 9, plot.z), "🌻 ON SHOW: visit and rate", Palette.coins)
		end
	end
	for _, r in v.ribbons or {} do
		if type(r.x) == "number" then
			marker(f, Vector3.new(r.x, r.y + 13, r.z), "🏵️ Showcase winner", Palette.cream)
		end
	end
	f.Parent = Workspace
	folder = f
end

local function rate(stars: number)
	local r = rating
	if r == nil or time() - lastTap < 0.5 then
		return
	end
	lastTap = time()
	Remotes.fire("Showcase_Rate", r.owner, stars)
	rating = nil
	Panels.close()
end

local function render(_state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Plot Showcase"
	local r = rating
	if r == nil then
		Ui.label("Visit a farm with a 🌻 banner during the Showcase to rate it.", {
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 40),
			Parent = body,
		})
		return
	end
	Ui.label(string.format("How do you like %s's farm?", r.name), {
		Font = Ui.theme.Type.display,
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, 30),
		LayoutOrder = 1,
		Parent = body,
	})
	for stars = 3, 1, -1 do
		Ui.button(
			string.rep("🌻", stars)
				.. (if stars == 3 then "  Wonderful" elseif stars == 2 then "  Lovely" else "  Nice"),
			function()
				rate(stars)
			end,
			{
				Size = UDim2.new(1, -8, 0, 44),
				LayoutOrder = 10 - stars,
				BackgroundColor3 = Ui.colors.coins,
				Parent = body,
			}
		)
	end
	Ui.label("One rating per farm each Showcase. Kind ratings only: there's no low score.", {
		TextWrapped = true,
		TextSize = 13,
		TextColor3 = Ui.colors.muted,
		Size = UDim2.new(1, -8, 0, 36),
		LayoutOrder = 20,
		Parent = body,
	})
end

function ShowcaseUi.init()
	Panels.register("Showcase", render, { static = true })
	Workspace:GetAttributeChangedSignal("Showcase"):Connect(function()
		apply(Workspace:GetAttribute("Showcase") or "")
	end)
	apply(Workspace:GetAttribute("Showcase") or "")
	local function readPreview()
		local startsAt = Workspace:GetAttribute("ShowcasePreview")
		Showcase.setPreview(if type(startsAt) == "number" and startsAt > 0 then startsAt else nil)
	end
	Workspace:GetAttributeChangedSignal("ShowcasePreview"):Connect(readPreview)
	readPreview()
	Hud.handlers.Showcase = function(payload)
		if payload.step == "rate" and type(payload.owner) == "number" then
			-- Only while still standing on that farm
			if Players.LocalPlayer:GetAttribute("OnPlot") == payload.owner then
				rating = { owner = payload.owner, name = tostring(payload.name or "this") }
				Panels.open("Showcase")
			end
		elseif type(payload.text) == "string" then
			Hud.toast(payload.text, if payload.step == "start" then nil else "celebrate")
		end
	end
end

return ShowcaseUi
