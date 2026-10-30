--!strict
-- The Quarry on the plot (Features/F01 Quarry & Smelter, 16 Model Catalog): a rocky hill with
-- a timber mine door, rails running out of it to an ore cart, and a lantern by the door. While
-- it's closed the door is boarded up; reopened, the boards come down and the lantern glows.
-- Faces local -Z. About 12 x 14 studs. 30 parts or fewer.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtQuarry = {}

ArtQuarry.PARTS_MAX = 30
ArtQuarry.WIDTH = 12
ArtQuarry.DEPTH = 14

export type Parts = {
	body: BasePart, -- the tap target
	boards: Folder, -- the boards across the door, shown while closed
	lantern: BasePart,
}

function ArtQuarry.build(model: Model, cf: CFrame): Parts
	local b = Kit.builder(model, cf, true)
	local body = b.block("Body", Vector3.new(12, 6.5, 8), Vector3.new(0, 3.25, 2.5), Palette.stone, { collide = true })
	local h = b.into(body, true)
	-- The hill: a slope down to the front, a higher crag at the back, boulders and grass on top
	h.wedge("Slope", Vector3.new(12, 6.5, 3), Vector3.new(0, 3.25, -3), Palette.stone)
	h.block("Crag", Vector3.new(7, 3, 5), Vector3.new(-1.5, 8, 3.5), Palette.stoneDark)
	h.ball("Boulder", 3.4, Vector3.new(3.6, 7.2, 4), Palette.stoneLight)
	h.ball("Boulder", 2.4, Vector3.new(-4.6, 6.8, 0.8), Palette.stoneLight)
	h.block("Grass", Vector3.new(4, 0.5, 3), Vector3.new(-1.5, 9.7, 3.5), Palette.grassDark, { shadow = false })
	-- The mine door: a dark opening in a timber frame, set into the slope
	local doorZ = -4.4
	h.block("Opening", Vector3.new(3.6, 4.4, 1.6), Vector3.new(0, 2.2, doorZ + 0.6), Palette.cocoa)
	for _, x in { -2.1, 2.1 } do
		h.block("DoorPost", Vector3.new(0.6, 5, 0.6), Vector3.new(x, 2.5, doorZ), Palette.woodDark)
	end
	h.block("Lintel", Vector3.new(5, 0.7, 0.7), Vector3.new(0, 5.2, doorZ), Palette.woodDark)
	-- The boards across it while it's closed
	local boards = Instance.new("Folder")
	boards.Name = "Boards"
	boards.Parent = body
	local bd = b.into(boards, true)
	for i, tilt in { 12, -10, 4 } do
		bd.block(
			"Board",
			Vector3.new(4.2, 0.6, 0.2),
			CFrame.new(0, 1.2 + i * 1.1, doorZ - 0.45) * CFrame.Angles(0, 0, math.rad(tilt)),
			Palette.wood,
			{ shadow = false }
		)
	end
	-- Rails out of the door, and an ore cart on them
	for _, x in { -0.9, 0.9 } do
		h.block("Rail", Vector3.new(0.25, 0.2, 5), Vector3.new(x, 0.1, doorZ - 2.6), Palette.metal, { shadow = false })
	end
	h.block("Cart", Vector3.new(2.4, 1.4, 1.8), Vector3.new(0, 1.1, doorZ - 3.6), Palette.woodDark)
	h.ball("Ore", 1, Vector3.new(-0.4, 1.9, doorZ - 3.6), Palette.bread, { shadow = false })
	h.ball("Ore", 0.8, Vector3.new(0.5, 1.95, doorZ - 3.4), Palette.stoneLight, { shadow = false })
	for _, x in { -0.8, 0.8 } do
		h.cyl("Wheel", 2, 0.7, CFrame.new(x, 0.35, doorZ - 3.6) * CFrame.Angles(0, math.rad(90), 0), Palette.tire, {
			shadow = false,
		})
	end
	-- The lantern on a post by the door
	h.post("LanternPost", 3.4, 0.3, Vector3.new(3.2, 1.7, doorZ - 0.4), Palette.woodDark)
	local lantern =
		h.block("Lantern", Vector3.new(0.7, 0.9, 0.7), Vector3.new(3.2, 3.8, doorZ - 0.4), Palette.lantern, {
			shadow = false,
		})
	Kit.sproutTag(h, Vector3.new(4.4, 6.6, 1), 2.5, Palette.wood, Palette.lime)
	return { body = body, boards = boards, lantern = lantern }
end

-- Closed: boarded up and dark. Open: the boards gone and the lantern lit.
function ArtQuarry.setOpen(model: Instance, open: boolean)
	local boards = model:FindFirstChild("Boards", true)
	if boards then
		for _, board in boards:GetChildren() do
			if board:IsA("BasePart") then
				board.Transparency = if open then 1 else 0
				board.CanQuery = not open
			end
		end
	end
	local lantern = model:FindFirstChild("Lantern", true) :: BasePart?
	if lantern then
		lantern.Material = if open then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

return ArtQuarry
