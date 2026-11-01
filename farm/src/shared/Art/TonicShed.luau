--!strict
-- The Tonic Shed (Township's Laboratory, Config/Tonics): a little greenhouse-workshop with a
-- brick skirt, glass walls over a bed of seedlings, a mixing bench out front and a shelf of
-- three jars, one per running tonic, filled with that tonic's colour. Before it's built the
-- lot holds only a "Coming soon" sign and the timer board. Placed and moved like any building
-- (Layout kind "tonics").
--
-- States (setState): "Lot" (before it's built) and "Open". setJars fills the shelf.
-- Faces local -Z, SIZE x SIZE studs. All original.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtTonicShed = {}

ArtTonicShed.SIZE = 12
ArtTonicShed.JARS = 3 -- Config/Tonics maxActive
ArtTonicShed.PARTS_MAX = 28

local QUIET = { shadow = false }

export type Parts = {
	body: BasePart, -- the mixing bench: the tap target
	board: BasePart, -- the timer board (for a SurfaceGui on its front)
}

local function only(p: BasePart, state: string)
	p:SetAttribute(state, true)
end

-- Builds the shed with its bottom centre at `cf` (front at local -Z) and returns its parts.
function ArtTonicShed.build(parent: Instance, cf: CFrame): Parts
	local b = Kit.builder(parent, cf, false)
	local S = ArtTonicShed.SIZE
	local front = -S / 2
	b.block("Yard", Vector3.new(S, 0.2, S), Vector3.new(0, 0.1, 0), Palette.path, QUIET)

	-- Before it's built: a sign on the empty lot
	only(b.post("LotPost", 3, 0.3, Vector3.new(-2, 1.6, 0), Palette.woodDark, QUIET), "Lot")
	only(b.block("LotSign", Vector3.new(3, 1.6, 0.2), Vector3.new(-2, 3, -0.1), Palette.flowerYellow, QUIET), "Lot")

	local open: { BasePart } = {}
	local function add(p: BasePart): BasePart
		table.insert(open, p)
		return p
	end
	-- The greenhouse at the back: a brick skirt, glass walls and a glass roof
	add(b.block("Skirt", Vector3.new(9.2, 1, 6.2), Vector3.new(0, 0.7, 2.2), Palette.brick))
	add(
		b.block(
			"Walls",
			Vector3.new(9, 3.6, 6),
			Vector3.new(0, 3, 2.2),
			Palette.glass,
			{ transparency = 0.35, collide = true }
		)
	)
	add(
		b.wedge(
			"RoofFront",
			Vector3.new(9.6, 1.4, 3.3),
			CFrame.new(0, 5.5, 0.55) * Kit.yaw(180),
			Palette.glassDeep,
			{ transparency = 0.25 }
		)
	)
	add(
		b.wedge(
			"RoofBack",
			Vector3.new(9.6, 1.4, 3.3),
			CFrame.new(0, 5.5, 3.85),
			Palette.glassDeep,
			{ transparency = 0.25 }
		)
	)
	add(b.block("Ridge", Vector3.new(9.8, 0.3, 0.3), Vector3.new(0, 6.3, 2.2), Palette.roofTeal, QUIET))
	add(b.block("Door", Vector3.new(2, 3.4, 0.2), Vector3.new(2.6, 1.9, -0.85), Palette.woodDark))
	-- Seedlings inside, seen through the glass
	add(b.block("Planter", Vector3.new(7, 0.8, 1.2), Vector3.new(0, 1.6, 3.8), Palette.woodDark, QUIET))
	add(b.block("Seedlings", Vector3.new(6.6, 1, 1), Vector3.new(0, 2.5, 3.8), Palette.leaf, QUIET))

	-- The jar shelf out front
	add(b.block("Shelf", Vector3.new(5, 0.3, 1.2), Vector3.new(-2.5, 2, front + 2.4), Palette.wood, QUIET))
	add(b.post("ShelfLegL", 1.9, 0.3, Vector3.new(-4.7, 1, front + 2.4), Palette.woodDark, QUIET))
	add(b.post("ShelfLegR", 1.9, 0.3, Vector3.new(-0.3, 1, front + 2.4), Palette.woodDark, QUIET))
	for i = 1, ArtTonicShed.JARS do
		local x = -4 + (i - 1) * 1.5
		local jar = b.post(
			"Jar" .. i,
			1.1,
			0.8,
			Vector3.new(x, 2.7, front + 2.4),
			Palette.glass,
			{ transparency = 0.15, shadow = false }
		)
		jar:SetAttribute("Jar", i)
		local lid = b.post("Lid" .. i, 0.25, 0.9, Vector3.new(x, 3.38, front + 2.4), Palette.cork, QUIET)
		lid:SetAttribute("Jar", i)
	end

	-- The mixing bench (the tap target) and the timer board
	local body = b.block(
		"Bench",
		Vector3.new(3.2, 1.6, 1.4),
		Vector3.new(2.6, 1, front + 3),
		Palette.wood,
		{ collide = true, query = true }
	)
	body:SetAttribute("Interact", "TonicShed")
	add(b.block("BenchTop", Vector3.new(3.4, 0.2, 1.6), Vector3.new(2.6, 1.9, front + 3), Palette.woodDark, QUIET))
	add(b.post("Flask", 0.8, 0.5, Vector3.new(2, 2.4, front + 3), Palette.gems, { transparency = 0.2, shadow = false }))
	b.post("BoardPost", 2.2, 0.3, Vector3.new(4.4, 1.1, front + 1.2), Palette.woodDark, QUIET)
	local board =
		b.block("Board", Vector3.new(3, 1.5, 0.25), Vector3.new(4.4, 2.4, front + 1), Palette.cream, { query = true })
	board:SetAttribute("Interact", "TonicShed")
	for _, p in open do
		only(p, "Open")
	end
	return { body = body, board = board }
end

local function show(p: BasePart, on: boolean)
	local base = (p:GetAttribute("BaseTransparency") :: number?) or 0
	p.Transparency = if on then base else 1
	p.CanCollide = on and p.Name == "Walls"
end

-- "Lot" or "Open"
function ArtTonicShed.setState(root: Instance, state: string)
	local open = state == "Open"
	Kit.eachPart(root, function(p)
		if p:GetAttribute("Lot") then
			show(p, not open)
		elseif p:GetAttribute("Open") then
			show(p, open)
		end
	end)
	ArtTonicShed.setJars(root, {})
end

-- Fills jar i with colors[i] (a running tonic's colour); jars past the list are hidden
function ArtTonicShed.setJars(root: Instance, colors: { Color3 })
	Kit.eachPart(root, function(p)
		local jar = p:GetAttribute("Jar")
		if type(jar) == "number" then
			local color = colors[jar]
			show(p, color ~= nil)
			if color and p.Name:sub(1, 3) == "Jar" then
				p.Color = color
			end
		end
	end)
end

return ArtTonicShed
