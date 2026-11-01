--!strict
-- The Tool Trader (Township's Tool Exchange, Config/ToolTrader): a little corrugated workshop
-- with a big yellow gear over the door, a power drill, saw and jackhammer on show in the
-- window, a trade counter and up to three offer crates out front, one per open slot. Before
-- it's built the lot holds only a "Coming soon" sign and the timer board. Placed and moved
-- like any building (Layout kind "trader").
--
-- States (setState): "Lot" (before it's built) and "Open". setSlots shows the offer crates.
-- Faces local -Z, SIZE x SIZE studs. All original.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtToolTrader = {}

ArtToolTrader.SIZE = 12
ArtToolTrader.SLOTS = 3
ArtToolTrader.PARTS_MAX = 36

local QUIET = { shadow = false }
local WALL = Palette.metal:Lerp(Palette.sky, 0.35)

export type Parts = {
	body: BasePart, -- the trade counter: the tap target
	board: BasePart, -- the timer board (for a SurfaceGui on its front)
}

local function only(p: BasePart, state: string)
	p:SetAttribute(state, true)
end

-- Builds the trader with its bottom centre at `cf` (front at local -Z) and returns its parts.
function ArtToolTrader.build(parent: Instance, cf: CFrame): Parts
	local b = Kit.builder(parent, cf, false)
	local S = ArtToolTrader.SIZE
	local front = -S / 2
	b.block("Yard", Vector3.new(S, 0.2, S), Vector3.new(0, 0.1, 0), Palette.path, QUIET)

	-- Before it's built: a sign on the empty lot
	only(b.post("LotPost", 3, 0.3, Vector3.new(-2, 1.6, 0), Palette.woodDark, QUIET), "Lot")
	only(b.block("LotSign", Vector3.new(3, 1.6, 0.2), Vector3.new(-2, 3, -0.1), Palette.flowerYellow, QUIET), "Lot")

	-- The workshop at the back
	local open: { BasePart } = {}
	local function add(p: BasePart): BasePart
		table.insert(open, p)
		return p
	end
	add(b.block("Walls", Vector3.new(9, 5, 6), Vector3.new(0, 2.7, 2.2), WALL, { collide = true }))
	add(b.wedge("RoofFront", Vector3.new(9.6, 1.4, 3.3), CFrame.new(0, 5.9, 0.55) * Kit.yaw(180), Palette.roofTeal))
	add(b.wedge("RoofBack", Vector3.new(9.6, 1.4, 3.3), CFrame.new(0, 5.9, 3.85), Palette.roofTeal))
	add(b.block("Door", Vector3.new(2, 3.4, 0.2), Vector3.new(2.6, 1.9, -0.85), Palette.woodDark))
	add(
		b.block(
			"Window",
			Vector3.new(3.6, 2, 0.2),
			Vector3.new(-2.2, 2.9, -0.85),
			Palette.glass,
			{ transparency = 0.3, shadow = false }
		)
	)
	-- The tools on show behind the glass
	add(b.block("DrillBody", Vector3.new(0.9, 0.6, 0.3), Vector3.new(-3.3, 3.2, -0.6), Palette.flowerYellow, QUIET))
	add(b.cyl("DrillBit", 0.8, 0.15, CFrame.new(-2.65, 3.2, -0.6), Palette.stoneLight, QUIET))
	add(b.cyl("SawBlade", 0.15, 0.9, CFrame.new(-2, 2.8, -0.6), Palette.stoneLight, QUIET))
	add(b.block("SawBody", Vector3.new(0.7, 0.5, 0.3), Vector3.new(-2, 3.35, -0.6), Palette.roofRed, QUIET))
	add(b.block("HammerBody", Vector3.new(0.5, 1.2, 0.3), Vector3.new(-1.1, 3, -0.6), Palette.carrot, QUIET))
	add(b.block("HammerBar", Vector3.new(1, 0.2, 0.3), Vector3.new(-1.1, 3.7, -0.6), Palette.stoneDark, QUIET))
	-- The gear over the door: a disc and four teeth
	local gear = CFrame.new(2.6, 4.6, -0.95) * Kit.yaw(90)
	add(b.cyl("Gear", 0.3, 1.8, gear, Palette.flowerYellow, QUIET))
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		add(
			b.block(
				"Tooth",
				Vector3.new(0.5, 0.5, 0.3),
				CFrame.new(2.6 + math.cos(a) * 1, 4.6 + math.sin(a) * 1, -0.95) * CFrame.Angles(0, 0, a),
				Palette.flowerYellow,
				QUIET
			)
		)
	end

	-- The offer crates out front, one per open slot
	for i = 1, ArtToolTrader.SLOTS do
		local x = -4 + (i - 1) * 2.2
		local crate =
			b.block("Crate" .. i, Vector3.new(1.6, 1.2, 1.4), Vector3.new(x, 0.8, front + 2.2), Palette.crate, QUIET)
		crate:SetAttribute("Slot", i)
		local band = b.block(
			"CrateBand" .. i,
			Vector3.new(1.65, 0.25, 1.45),
			Vector3.new(x, 0.9, front + 2.2),
			Palette.woodDark,
			QUIET
		)
		band:SetAttribute("Slot", i)
	end

	-- The trade counter (the tap target) and the timer board
	local body = b.block(
		"Counter",
		Vector3.new(3.6, 1.6, 1.4),
		Vector3.new(2.8, 1, front + 3.4),
		Palette.wood,
		{ collide = true, query = true }
	)
	body:SetAttribute("Interact", "ToolTrader")
	add(b.block("CounterTop", Vector3.new(3.8, 0.2, 1.6), Vector3.new(2.8, 1.9, front + 3.4), Palette.woodDark, QUIET))
	b.post("BoardPost", 2.2, 0.3, Vector3.new(4.4, 1.1, front + 1.2), Palette.woodDark, QUIET)
	local board =
		b.block("Board", Vector3.new(3, 1.5, 0.25), Vector3.new(4.4, 2.4, front + 1), Palette.cream, { query = true })
	board:SetAttribute("Interact", "ToolTrader")
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
function ArtToolTrader.setState(root: Instance, state: string)
	local open = state == "Open"
	Kit.eachPart(root, function(p)
		if p:GetAttribute("Lot") then
			show(p, not open)
		elseif p:GetAttribute("Open") then
			show(p, open)
		end
	end)
	if not open then
		ArtToolTrader.setSlots(root, 0)
	end
end

-- Shows the crates of the first `slots` slots
function ArtToolTrader.setSlots(root: Instance, slots: number)
	Kit.eachPart(root, function(p)
		local slot = p:GetAttribute("Slot")
		if type(slot) == "number" then
			show(p, slot <= slots)
		end
	end)
end

return ArtToolTrader
