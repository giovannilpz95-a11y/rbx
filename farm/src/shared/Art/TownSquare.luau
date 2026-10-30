--!strict
-- The Town Square (Design/14 Multiplayer Features A1, Design/15 3D World & Avatar Play hub):
-- a round plaza at the centre of the hub with a fountain, a row of three boards (Notice Board,
-- Neighbors board, Market board), the Puzzle Porch (Crop Pop), benches, lamp posts, trees and
-- flower beds. The hub spawn pad stays at the plaza's centre. World space: the plaza is built
-- around `origin`, with the boards along its north side facing south (+Z), toward the spawn and
-- the fountain, and the Puzzle Porch on its west side facing east.
--
-- Pure: no services, so the Lune tests can build it and count its parts.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtTownSquare = {}

ArtTownSquare.PARTS_MAX = 180
ArtTownSquare.RADIUS = 36

-- Where the three boards stand (plaza-local, on the ground); each faces +Z
ArtTownSquare.BOARDS = table.freeze({
	Notice = Vector3.new(-18, 0, -18),
	Neighbors = Vector3.new(0, 0, -20),
	Market = Vector3.new(18, 0, -18),
})
ArtTownSquare.FOUNTAIN = Vector3.new(0, 0, 22)
ArtTownSquare.PORCH = Vector3.new(-25, 0, 4) -- the Puzzle Porch cabinet, facing the plaza (+X)

export type Square = {
	model: Model,
	-- Each board's face: a SurfaceGui on its Front shows the board's text; also the tap target
	boards: { [string]: Part },
	porch: Part, -- the Puzzle Porch cabinet's body (where an errand walks to)
	porchModel: Model, -- every part of the porch; all of it is a tap target (opens Crop Pop)
	porchSign: Part, -- its marquee; a SurfaceGui on its Front shows the name
}

-- A notice board on two posts under a little roof. The face is `w` x `h` studs. ~9 parts.
local function board(b: Kit.Builder, name: string, at: Vector3, w: number, h: number, face: Color3): Part
	-- Turn the board so its front (local -Z) looks toward +Z
	local base = CFrame.new(at) * Kit.yaw(180)
	local t = Kit.builder(b.parent, b.origin * base, true)
	local top = 2.6 + h
	for _, x in { -1, 1 } do
		t.block(
			name .. "Post",
			Vector3.new(0.8, top + 0.6, 0.8),
			Vector3.new(x * (w / 2 + 0.3), (top + 0.6) / 2, 0.2),
			Palette.woodDark,
			{ collide = true }
		)
	end
	t.block(name .. "Frame", Vector3.new(w + 0.6, h + 0.6, 0.5), Vector3.new(0, 2.6 + h / 2, 0.3), Palette.wood)
	local panel = t.block(name, Vector3.new(w, h, 0.3), Vector3.new(0, 2.6 + h / 2, 0), face, { shadow = false })
	Kit.gableRoof(t, name .. "Roof", Vector3.new(0, top + 0.6, 0.2), w + 2, 2.4, 1.2, Palette.roofTeal)
	Kit.bush(t, name .. "Bush", Vector3.new(-(w / 2 + 1.6), 0, 0.6), 1, Palette.treeTop, Palette.flowerPink)
	return panel
end

local function fountain(b: Kit.Builder, at: Vector3)
	b.post("FountainBasin", 1.6, 14, at + Vector3.new(0, 0.8, 0), Palette.stone, { collide = true })
	b.post("FountainRim", 0.4, 14.4, at + Vector3.new(0, 1.7, 0), Palette.stoneLight)
	b.post("FountainWater", 0.2, 12.6, at + Vector3.new(0, 1.65, 0), Palette.water, { shadow = false })
	b.post("FountainPillar", 3.4, 1.8, at + Vector3.new(0, 3.2, 0), Palette.stoneLight)
	b.post("FountainBowl", 0.6, 6, at + Vector3.new(0, 5, 0), Palette.stone)
	b.post("FountainBowlWater", 0.2, 5.2, at + Vector3.new(0, 5.3, 0), Palette.water, { shadow = false })
	b.ball("FountainSpout", 1.4, at + Vector3.new(0, 6.1, 0), Palette.water, { shadow = false })
end

-- The Puzzle Porch: a little wooden game cabinet under a porch roof, where Crop Pop is played
-- (Design/Features F12). Front at local -Z. ~16 parts. Returns the body, the marquee and the
-- porch's own model.
local function puzzlePorch(b: Kit.Builder, at: CFrame): (Part, Part, Model)
	local porch = Kit.model("PuzzlePorch", b.parent)
	local t = Kit.builder(porch, b.origin * at, true)
	t.block("PorchDeck", Vector3.new(9, 0.4, 7), Vector3.new(0, 0.2, 0.5), Palette.woodLight)
	local body = t.block("Cabinet", Vector3.new(4, 6, 3), Vector3.new(0, 3.4, 1), Palette.barnRed, { collide = true })
	t.block("CabinetTrim", Vector3.new(4.3, 0.4, 3.3), Vector3.new(0, 0.6, 1), Palette.woodDark)
	t.block("Screen", Vector3.new(3, 2.2, 0.2), Vector3.new(0, 4.6, -0.55), Palette.glassDeep, { shadow = false })
	t.wedge("Controls", Vector3.new(3.6, 0.8, 1.2), CFrame.new(0, 3.2, -1.05), Palette.cream)
	t.ball("ButtonRed", 0.5, Vector3.new(-0.8, 3.65, -1.0), Palette.comb, { shadow = false })
	t.ball("ButtonGold", 0.5, Vector3.new(0.8, 3.65, -1.0), Palette.coins, { shadow = false })
	local sign =
		t.block("PorchSign", Vector3.new(4.6, 1.4, 0.5), Vector3.new(0, 7.2, 0.2), Palette.cream, { shadow = false })
	t.ball("Tomato", 1.4, Vector3.new(0, 8.4, 0.2), Palette.roofRed)
	t.block("TomatoLeaf", Vector3.new(0.8, 0.2, 0.8), Vector3.new(0, 9.1, 0.2), Palette.leafLight, { shadow = false })
	for _, x in { -4, 4 } do
		t.block("PorchPost", Vector3.new(0.5, 7.6, 0.5), Vector3.new(x, 4, -2.6), Palette.woodDark)
		t.block("PorchPost", Vector3.new(0.5, 7.6, 0.5), Vector3.new(x, 4, 3.6), Palette.woodDark)
	end
	Kit.gableRoof(t, "PorchRoof", Vector3.new(0, 7.8, 0.5), 9.6, 7.6, 1.8, Palette.roofMustard)
	return body, sign, porch
end

local function bench(b: Kit.Builder, at: CFrame)
	b.block("BenchSeat", Vector3.new(5, 0.4, 1.6), at * CFrame.new(0, 1.3, 0), Palette.wood)
	b.block("BenchBack", Vector3.new(5, 1.4, 0.3), at * CFrame.new(0, 2.1, 0.7), Palette.wood)
	for _, x in { -2, 2 } do
		b.block("BenchLeg", Vector3.new(0.4, 1.1, 1.4), at * CFrame.new(x, 0.55, 0), Palette.woodDark)
	end
end

local function lamp(b: Kit.Builder, at: Vector3)
	b.post("LampPost", 7, 0.5, at + Vector3.new(0, 3.5, 0), Palette.cocoa)
	b.ball(
		"Lantern",
		1.3,
		at + Vector3.new(0, 7.3, 0),
		Palette.lantern,
		{ material = Enum.Material.Neon, shadow = false }
	)
end

-- Build the square into `parent` around `origin` (the plaza centre on the ground).
function ArtTownSquare.build(parent: Instance, origin: CFrame): Square
	local model = Kit.model("TownSquare", parent)
	local b = Kit.builder(model, origin, false)
	local r = ArtTownSquare.RADIUS

	b.post("PlazaEdge", 0.2, r * 2 + 3, Vector3.new(0, 0.2, 0), Palette.pathEdge, { shadow = false })
	b.post("Plaza", 0.2, r * 2, Vector3.new(0, 0.25, 0), Palette.path, { shadow = false })
	fountain(b, ArtTownSquare.FOUNTAIN)

	local boards = {
		Notice = board(b, "NoticeBoard", ArtTownSquare.BOARDS.Notice, 12, 7, Palette.cork),
		Neighbors = board(b, "NeighborsBoard", ArtTownSquare.BOARDS.Neighbors, 14, 8, Palette.cream),
		Market = board(b, "MarketBoard", ArtTownSquare.BOARDS.Market, 12, 7, Palette.cork),
	}

	-- Lamp posts around the plaza edge, benches facing the fountain, trees and flower beds
	-- outside the paving
	for i = 0, 7 do
		local angle = math.rad(22.5 + i * 45)
		lamp(b, Vector3.new(math.cos(angle) * (r - 2), 0, math.sin(angle) * (r - 2)))
	end
	local f = ArtTownSquare.FOUNTAIN
	for _, offset in { Vector3.new(-13, 0, 0), Vector3.new(13, 0, 0), Vector3.new(0, 0, 13) } do
		local at = f + offset
		bench(b, CFrame.lookAt(at, Vector3.new(f.X, 0, f.Z)))
	end
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local at = Vector3.new(math.cos(angle) * (r + 8), 0, math.sin(angle) * (r + 8))
		Kit.tree(b, "Tree", at, if i % 2 == 0 then 1.2 else 1, Palette.treeTop, Palette.treeTopDark, Palette.trunk)
	end
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local at = Vector3.new(math.cos(angle) * (r + 3), 0, math.sin(angle) * (r + 3))
		Kit.bush(
			b,
			"Flowers",
			at,
			1.3,
			Palette.leafLight,
			if i % 2 == 0 then Palette.flowerYellow else Palette.flowerPink
		)
	end

	local porch, porchSign, porchModel = puzzlePorch(b, CFrame.new(ArtTownSquare.PORCH) * Kit.yaw(-90))

	return { model = model, boards = boards, porch = porch, porchModel = porchModel, porchSign = porchSign }
end

return ArtTownSquare
