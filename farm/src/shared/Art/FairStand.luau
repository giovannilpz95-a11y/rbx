--!strict
-- The Fair Stand (Config/Events, EventService): an event's stall in the Town Square while the
-- event runs. A counter under a striped tent with crates and a rosette, and a sign naming the
-- event. Centred on the ground at `cf`, the counter facing local -Z. About 18 parts.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtFairStand = {}

ArtFairStand.PARTS_MAX = 20

local BLUE = Color3.fromRGB(70, 120, 210)
local QUIET = { shadow = false }

export type Stand = { model: Model, sign: Part }

function ArtFairStand.build(parent: Instance, cf: CFrame, title: string): Stand
	local model = Kit.model("FairStand", parent)
	local b = Kit.builder(model, cf, true)
	b.block("Counter", Vector3.new(7, 2.4, 2), CFrame.new(0, 1.2, 0), Palette.wood, { collide = true })
	b.block("Top", Vector3.new(7.3, 0.25, 2.3), CFrame.new(0, 2.5, 0), Palette.woodLight)
	b.block("Skirt", Vector3.new(7.1, 0.6, 0.1), CFrame.new(0, 1.9, -1.05), BLUE, QUIET)
	for _, x in { -3.4, 3.4 } do
		for _, z in { -1, 2.6 } do
			b.block("Post", Vector3.new(0.3, 5.6, 0.3), CFrame.new(x, 2.8, z), Palette.woodDark)
		end
	end
	-- The striped roof, sloping toward the front
	for i = 0, 6 do
		local color = if i % 2 == 0 then Palette.roofRed else Palette.cream
		b.block(
			"Stripe",
			Vector3.new(1.05, 0.2, 4.4),
			CFrame.new(-3.15 + i * 1.05, 5.75, 0.8) * CFrame.Angles(math.rad(-10), 0, 0),
			color,
			QUIET
		)
	end
	b.block("Crates", Vector3.new(1.8, 1.2, 1.4), CFrame.new(-2.2, 3.2, 0.3), Palette.woodLight, QUIET)
	b.ball("Produce", 1.3, CFrame.new(1.8, 3.2, 0.2), Palette.straw, QUIET)
	local sign = b.block("Sign", Vector3.new(5.4, 1.2, 0.2), CFrame.new(0, 6.7, -1.15), Palette.cream)
	b.cyl("Rosette", 0.2, 1.4, CFrame.new(3.3, 6.7, -1.25) * CFrame.Angles(0, math.rad(90), 0), BLUE, QUIET)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = Palette.cocoa
	text.Text = string.upper(title)
	text.Parent = gui
	gui.Parent = sign
	return { model = model, sign = sign }
end

return ArtFairStand
