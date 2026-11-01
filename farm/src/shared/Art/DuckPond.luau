--!strict
-- The Duck Pond (Township's Duck Feeder, Config/DuckPond): a round pond in a ring of stones
-- with reeds and a lily pad, a wooden feeder box on a post at the back (the tap target) with
-- a timer board, and up to four ducks on the water. Placed and moved like any building
-- (Layout kind "pond"), so the water comes with the model.
--
-- States (setState): "Overgrown" (a muddy hollow full of reeds and a fallen branch) and
-- "Open". setDucks shows how many ducks are visiting and which are drakes (a green head), and
-- whether their feathers are waiting (a feather on the bank, tap to collect).
-- Faces local -Z, SIZE x SIZE studs. All original.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtDuckPond = {}

ArtDuckPond.SIZE = 14
ArtDuckPond.DUCKS = 4
ArtDuckPond.DUCK_PARTS = 5 -- body, head, beak, tail and wing
ArtDuckPond.PARTS_MAX = 44

local QUIET = { shadow = false }
local WATER_Y = 0.3
local UP = CFrame.Angles(0, 0, math.rad(90)) -- a Kit cylinder standing upright

-- Where each duck floats
ArtDuckPond.DUCK_AT = table.freeze({
	Vector3.new(-2.4, WATER_Y, -1.6),
	Vector3.new(1.8, WATER_Y, -2.6),
	Vector3.new(-0.6, WATER_Y, 1.2),
	Vector3.new(2.8, WATER_Y, 0.8),
})

export type Parts = {
	body: BasePart, -- the feeder box: the tap target
	board: BasePart, -- the timer board (for a SurfaceGui on its front)
}

local function openOnly(p: BasePart)
	p:SetAttribute("Open", true)
end
local function overgrownOnly(p: BasePart)
	p:SetAttribute("Overgrown", true)
end

local function duck(b: Kit.Builder, parent: Instance, index: number)
	local m = Kit.model("Duck" .. index, parent)
	m:SetAttribute("Duck", index)
	local db = b.into(m, true)
	local at = CFrame.new(ArtDuckPond.DUCK_AT[index]) * Kit.yaw(index * 70)
	db.ball("Body", 1.2, at * CFrame.new(0, 0.35, 0.1), Palette.cream, QUIET)
	local head = db.ball("Head", 0.7, at * CFrame.new(0, 0.95, -0.45), Palette.cream, QUIET)
	head:SetAttribute("DuckHead", true)
	db.block("Beak", Vector3.new(0.3, 0.15, 0.35), at * CFrame.new(0, 0.9, -0.85), Palette.carrot, QUIET)
	db.wedge("Tail", Vector3.new(0.5, 0.35, 0.4), at * CFrame.new(0, 0.6, 0.75), Palette.cream, QUIET)
	local wing =
		db.block("Wing", Vector3.new(1.25, 0.3, 0.6), at * CFrame.new(0, 0.55, 0.15), Palette.stoneLight, QUIET)
	wing:SetAttribute("DuckWing", true)
end

-- Builds the pond with its bottom centre at `cf` (front at local -Z) and returns its parts.
function ArtDuckPond.build(parent: Instance, cf: CFrame): Parts
	local b = Kit.builder(parent, cf, false)
	local S = ArtDuckPond.SIZE
	b.block("Bank", Vector3.new(S, 0.2, S), Vector3.new(0, 0.1, 0), Palette.grassLight, QUIET)
	local water = b.cyl(
		"Water",
		0.3,
		S - 3,
		CFrame.new(0, WATER_Y - 0.1, -0.5) * UP,
		Palette.water,
		{ transparency = 0.15, shadow = false, material = Enum.Material.Glass }
	)
	openOnly(water)
	local mud = b.cyl("Mud", 0.25, S - 3, CFrame.new(0, 0.15, -0.5) * UP, Palette.soil, QUIET)
	overgrownOnly(mud)
	-- A ring of stones round the water
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.3
		b.ball("Stone", 1.3, Vector3.new(math.cos(a) * 5.6, 0.35, -0.5 + math.sin(a) * 5.6), Palette.stone, QUIET)
	end
	-- Reeds at the edges (a thicket of them while it's overgrown) and a lily pad
	for i, at in { Vector3.new(-4.6, 0, 2.4), Vector3.new(4.4, 0, -3.6) } do
		b.post("Reeds", 2.4, 0.9, at + Vector3.new(0, 1.2, 0), Palette.leaf:Lerp(Palette.treeTopDark, i * 0.3), QUIET)
	end
	for _, at in { Vector3.new(-1, 0, -1.5), Vector3.new(1.6, 0, 0.6), Vector3.new(-2.6, 0, 1) } do
		local thicket = b.post("Thicket", 2, 1.4, at + Vector3.new(0, 1, 0), Palette.treeTopDark, QUIET)
		overgrownOnly(thicket)
	end
	local branch =
		b.block("Branch", Vector3.new(4.5, 0.5, 0.5), CFrame.new(1, 0.5, -3) * Kit.yaw(25), Palette.trunk, QUIET)
	overgrownOnly(branch)
	local lily = b.cyl("LilyPad", 0.1, 1.4, CFrame.new(3.2, WATER_Y + 0.1, -4) * UP, Palette.leaf, QUIET)
	openOnly(lily)

	-- The feeder box on its post at the back, its little roof and a bag of crumbs
	local feederAt = Vector3.new(-3.4, 0, S / 2 - 1.6)
	b.post("FeederPost", 2, 0.4, feederAt + Vector3.new(0, 1, 0), Palette.woodDark, QUIET)
	local body = b.block(
		"Feeder",
		Vector3.new(2.4, 1.2, 1.6),
		feederAt + Vector3.new(0, 2.6, 0),
		Palette.wood,
		{ collide = true, query = true }
	)
	body:SetAttribute("Interact", "DuckPond")
	b.wedge("FeederRoof", Vector3.new(2.8, 0.8, 1), CFrame.new(feederAt + Vector3.new(0, 3.6, -0.45)), Palette.roofTeal)
	b.wedge(
		"FeederRoof",
		Vector3.new(2.8, 0.8, 1),
		CFrame.new(feederAt + Vector3.new(0, 3.6, 0.45)) * Kit.yaw(180),
		Palette.roofTeal
	)
	-- The timer board on a post at the right
	local boardAt = Vector3.new(3.6, 0, S / 2 - 1.4)
	b.post("BoardPost", 2.2, 0.3, boardAt + Vector3.new(0, 1.1, 0.2), Palette.woodDark, QUIET)
	local board =
		b.block("Board", Vector3.new(3.2, 1.6, 0.25), boardAt + Vector3.new(0, 2.4, 0), Palette.cream, { query = true })
	board:SetAttribute("Interact", "DuckPond")

	-- The feathers waiting on the bank once a visit is over
	local feather = b.wedge(
		"Feather",
		Vector3.new(0.2, 0.5, 1.4),
		CFrame.new(0, 0.5, S / 2 - 2.6) * Kit.yaw(60),
		Palette.cream,
		{ shadow = false, query = true }
	)
	feather:SetAttribute("Interact", "DuckPond")
	feather:SetAttribute("Feathers", true)

	for i = 1, ArtDuckPond.DUCKS do
		duck(b, parent, i)
	end
	return { body = body, board = board }
end

local function show(p: BasePart, on: boolean)
	local base = (p:GetAttribute("BaseTransparency") :: number?) or 0
	p.Transparency = if on then base else 1
	p.CanQuery = on and p:GetAttribute("Interact") ~= nil
end

-- "Overgrown" or "Open"
function ArtDuckPond.setState(root: Instance, state: string)
	local open = state == "Open"
	Kit.eachPart(root, function(p)
		if p:GetAttribute("Overgrown") then
			show(p, not open)
		elseif p:GetAttribute("Open") then
			show(p, open)
		end
	end)
	if not open then
		ArtDuckPond.setDucks(root, 0, 0, false)
	end
end

-- `ducks` on the water, the first `drakes` of them with green heads and grey-brown wings,
-- and the feathers on the bank when `done`
function ArtDuckPond.setDucks(root: Instance, ducks: number, drakes: number, done: boolean)
	for i = 1, ArtDuckPond.DUCKS do
		local m = root:FindFirstChild("Duck" .. i)
		if m then
			local drake = i <= drakes
			Kit.eachPart(m, function(p)
				show(p, i <= ducks)
				if p:GetAttribute("DuckHead") then
					p.Color = if drake then Palette.leaf:Lerp(Palette.treeTopDark, 0.6) else Palette.cream
				elseif p:GetAttribute("DuckWing") then
					p.Color = if drake then Palette.trunk else Palette.stoneLight
				end
			end)
		end
	end
	local feather = root:FindFirstChild("Feather", true)
	if feather and feather:IsA("BasePart") then
		show(feather, done)
	end
end

return ArtDuckPond
