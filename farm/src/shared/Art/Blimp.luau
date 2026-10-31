--!strict
-- The Blimp Mast and its Cargo Blimp (Features/F04 Airship Freight; Model List - Town &
-- Factories, Blimp Mast and Cargo Blimp). On the plot: a lattice mooring tower with a beacon
-- and a windsock, and a little freight office at its foot (the tap target) with a timer board.
-- The blimp is its own model: a cream envelope with teal bands, a red nose cone, tail fins, a
-- gondola with a propeller, and a cargo net under it where three rows of crates hang.
--
-- States (setState): "Broken" (the mast before its repair: no cup, beacon or windsock, a
-- fallen sock and planks at its foot), "Repaired" and "Away" (mast working, no blimp) and
-- "Docked" (the blimp moored nose-in to the mast, crates within reach). Faces local -Z, with
-- the mast at the back left and the office at the front right. WIDTH x DEPTH studs (4 x 3
-- tiles); the docked blimp hangs over the plot and a little past its right edge.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtBlimp = {}

ArtBlimp.WIDTH = 16
ArtBlimp.DEPTH = 12
ArtBlimp.MAST_PARTS_MAX = 30 -- the mast and office, with the broken-state pieces
ArtBlimp.BLIMP_PARTS_MAX = 22 -- the blimp without its crates
ArtBlimp.CARGO_PARTS_MAX = 24 -- 9 crates, each banded when filled, and 3 help flags
ArtBlimp.PARTS_MAX = ArtBlimp.MAST_PARTS_MAX + ArtBlimp.BLIMP_PARTS_MAX + ArtBlimp.CARGO_PARTS_MAX
ArtBlimp.ROWS = 3
ArtBlimp.PER_ROW = 3

ArtBlimp.STATES = { "Broken", "Repaired", "Docked", "Away" }

local QUIET = { shadow = false }
local MAST_X, MAST_Z = -4.5, 2.5 -- the tower's foot, back left
local MAST_H = 10.5 -- top of the mooring cup
local ENVELOPE = 14 -- length of the envelope's straight middle
local RADIUS = 3.5
local CARGO_DROP = 6.6 -- envelope centre to the crate tops

-- Where the blimp's pivot (its envelope centre) sits when docked, from the plot's origin: the
-- nose cone touches the cup, the body runs off to the right (+X) at cup height.
ArtBlimp.DOCK = CFrame.new(MAST_X + 1.4 + ENVELOPE / 2 + RADIUS - 0.6, MAST_H - 0.3, MAST_Z)

export type Parts = {
	body: BasePart, -- the freight office: the tap target
	board: BasePart, -- the timer board by the office door (for a SurfaceGui)
	beacon: BasePart,
	blimp: Model, -- PrimaryPart is its hidden root at the envelope centre
}

-- Parts only a repaired mast shows, and parts only a broken one shows
local function repairedOnly(p: BasePart)
	p:SetAttribute("Repaired", true)
end
local function brokenOnly(p: BasePart)
	p:SetAttribute("Broken", true)
end

local function mast(b: Kit.Builder): BasePart
	local foot = Vector3.new(MAST_X, 0, MAST_Z)
	b.block("Pad", Vector3.new(5.4, 0.4, 5.4), foot + Vector3.new(0, 0.2, 0), Palette.stoneLight, QUIET)
	-- Four legs leaning in from the pad's corners to the top, so the tower tapers
	local spread, top = 1.9, 0.55
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local low = foot + Vector3.new(sx * spread, 0.4, sz * spread)
			local high = foot + Vector3.new(sx * top, MAST_H - 1, sz * top)
			local mid = (low + high) / 2
			b.block(
				"Leg",
				Vector3.new(0.45, (high - low).Magnitude, 0.45),
				CFrame.lookAt(mid, high) * CFrame.Angles(math.rad(-90), 0, 0),
				Palette.roofRed,
				{ collide = true }
			)
		end
	end
	-- Cross braces on the front face and a deck below the cup
	for _, tilt in { 32, -32 } do
		b.block(
			"Brace",
			Vector3.new(0.25, 6.4, 0.25),
			CFrame.new(foot + Vector3.new(0, 3.6, -1.3)) * CFrame.Angles(0, 0, math.rad(tilt)),
			Palette.cream,
			QUIET
		)
	end
	b.block("Deck", Vector3.new(2.6, 0.3, 2.6), foot + Vector3.new(0, MAST_H - 1.1, 0), Palette.woodLight)
	b.block(
		"Ladder",
		Vector3.new(0.8, MAST_H - 1.6, 0.15),
		CFrame.new(foot + Vector3.new(0.4, (MAST_H - 1.2) / 2, -1.7)) * CFrame.Angles(math.rad(-9), 0, 0),
		Palette.woodDark,
		QUIET
	)
	-- The mooring cup the nose sits in, its arm, the beacon and the windsock (repaired only)
	local cup = b.post("Cup", 1, 1.6, foot + Vector3.new(0, MAST_H - 0.45, 0), Palette.metal)
	repairedOnly(cup)
	local arm = b.block("Arm", Vector3.new(1.4, 0.5, 0.5), foot + Vector3.new(1, MAST_H - 0.2, 0), Palette.metal, QUIET)
	repairedOnly(arm)
	local beacon = b.ball("Beacon", 0.8, foot + Vector3.new(0, MAST_H + 0.4, 0), Palette.lantern, QUIET)
	repairedOnly(beacon)
	local pole = b.post("SockPole", 2.4, 0.15, foot + Vector3.new(-1, MAST_H + 0.1, 0.9), Palette.metal, QUIET)
	repairedOnly(pole)
	local sock = b.cyl(
		"Sock",
		1.8,
		0.6,
		CFrame.new(foot + Vector3.new(-0.15, MAST_H + 1, 0.9)) * CFrame.Angles(0, 0, math.rad(-12)),
		Palette.roofRed,
		QUIET
	)
	repairedOnly(sock)
	-- Before the repair: the sock lies at the foot with a couple of loose planks
	brokenOnly(
		b.cyl(
			"FallenSock",
			1.8,
			0.6,
			CFrame.new(foot + Vector3.new(1.6, 0.7, -3.1)) * Kit.yaw(30),
			Palette.roofRed:Lerp(Palette.cream, 0.35),
			QUIET
		)
	)
	for i, tilt in { 8, -14 } do
		brokenOnly(
			b.block(
				"Plank",
				Vector3.new(3.2, 0.2, 0.6),
				CFrame.new(foot + Vector3.new(-1.2 + i * 0.6, 0.5 + i * 0.2, -3.2 + i * 0.7)) * Kit.yaw(tilt * 3),
				Palette.wood,
				QUIET
			)
		)
	end
	return beacon
end

-- The freight office at the front right: a little teal-roofed hut with a round door, and the
-- timer board on a post beside it. Returns the office (tap target) and the board.
local function office(b: Kit.Builder): (BasePart, BasePart)
	local at = Vector3.new(3.6, 0, -2.6)
	local body = b.block("Body", Vector3.new(5, 3.6, 4), at + Vector3.new(0, 1.8, 0), Palette.oat, { collide = true })
	local h = b.into(body, true)
	Kit.gableRoof(h, "Roof", at + Vector3.new(0, 3.6, 0), 5.8, 4.8, 1.8, Palette.roofTeal)
	Kit.door(h, "Door", CFrame.new(at + Vector3.new(-1, 0, -2)), 1.4, 2.6, Palette.roofMustard, Palette.cream)
	h.block("Window", Vector3.new(1.3, 1, 0.15), at + Vector3.new(1.2, 2.2, -2.05), Palette.glass, QUIET)
	h.post("BoardPost", 2.6, 0.3, at + Vector3.new(-3.6, 1.3, -1.2), Palette.woodDark, QUIET)
	local board =
		h.block("TimerBoard", Vector3.new(3, 1.6, 0.25), at + Vector3.new(-3.6, 3, -1.2), Palette.cream, QUIET)
	Kit.sproutTag(h, at + Vector3.new(1.6, 4.9, 0), 1.2, Palette.wood, Palette.lime)
	return body, board
end

-- The Cargo Blimp, nose toward local -X, pivoting at its envelope centre.
local function blimp(parent: Model, cf: CFrame): Model
	local m = Kit.model("Blimp", parent)
	local root = Instance.new("Part")
	root.Name = "BlimpRoot"
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = cf
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	Kit.hide(root)
	root.Parent = m
	m.PrimaryPart = root
	local b = Kit.builder(m, cf, true)
	local half = ENVELOPE / 2
	b.cyl("Envelope", ENVELOPE, RADIUS * 2, Vector3.zero, Palette.cream)
	b.ball("Envelope", RADIUS * 2, Vector3.new(-half, 0, 0), Palette.cream)
	b.ball("Envelope", RADIUS * 2, Vector3.new(half, 0, 0), Palette.cream)
	b.ball("Nose", 2.6, Vector3.new(-half - RADIUS + 0.6, 0, 0), Palette.roofRed)
	for _, x in { -3, 2.4 } do
		b.cyl("Band", 1.1, RADIUS * 2 + 0.15, Vector3.new(x, 0, 0), Palette.roofTeal, QUIET)
	end
	-- Tail fins: up, down and out to each side
	local tail = half + 1.6
	b.block("Fin", Vector3.new(3, 2.4, 0.3), Vector3.new(tail, RADIUS + 0.4, 0), Palette.roofTeal)
	b.block("Fin", Vector3.new(3, 2.4, 0.3), Vector3.new(tail, -RADIUS - 0.4, 0), Palette.roofTeal)
	b.block("Fin", Vector3.new(3, 0.3, 2.4), Vector3.new(tail, 0, RADIUS + 0.4), Palette.roofTeal)
	b.block("Fin", Vector3.new(3, 0.3, 2.4), Vector3.new(tail, 0, -RADIUS - 0.4), Palette.roofTeal)
	-- The gondola slung under the middle, with its windows and a propeller at the back
	local g = -RADIUS - 0.9
	b.block("Gondola", Vector3.new(5.6, 1.5, 2.2), Vector3.new(0, g, 0), Palette.roofMustard)
	b.block("Windows", Vector3.new(4.2, 0.6, 2.3), Vector3.new(-0.3, g + 0.2, 0), Palette.glass, QUIET)
	b.cyl("PropHub", 0.6, 0.5, Vector3.new(3.1, g, 0), Palette.metal, QUIET)
	local prop = b.block("Prop", Vector3.new(0.15, 2.2, 0.4), Vector3.new(3.45, g, 0), Palette.woodDark, QUIET)
	prop:SetAttribute("SpinAxis", "X") -- the client spins it about the blimp's length
	-- The cargo net the crates hang from, on two lines
	local net = -CARGO_DROP + 1.6
	for _, x in { -2.6, 2.6 } do
		b.block("Line", Vector3.new(0.12, g - net, 0.12), Vector3.new(x, (g + net) / 2, 0), Palette.sack, QUIET)
	end
	b.block("Net", Vector3.new(8.4, 0.2, 6), Vector3.new(0, net, 0), Palette.sack, QUIET)
	return m
end

function ArtBlimp.build(model: Model, cf: CFrame): Parts
	model:SetAttribute("BlimpOrigin", cf)
	local b = Kit.builder(model, cf, true)
	local beacon = mast(b)
	local body, board = office(b)
	local sky = blimp(model, cf * ArtBlimp.DOCK)
	return { body = body, board = board, beacon = beacon, blimp = sky }
end

-- Where the crate in `row` (1-3) and `slot` (1-3) hangs, relative to the blimp's pivot. Rows
-- run along the blimp; slots go across it.
function ArtBlimp.crateOffset(row: number, slot: number): CFrame
	return CFrame.new((row - 2) * 2.6, -CARGO_DROP, (slot - 2) * 1.9)
end

export type Crate = { filled: boolean?, flagged: boolean? }

-- Hangs the crates under the blimp's net from `rows` (up to ROWS rows of up to PER_ROW
-- crates). An empty crate is a pale open box, a filled one a full crate with a band, and a
-- crate flagged for help carries a tall red flag. Each crate part has Row and Slot attributes.
-- Rebuilt each call into a "Cargo" model inside the blimp.
function ArtBlimp.setCargo(model: Instance, rows: { { Crate } })
	local sky = model:FindFirstChild("Blimp") :: Model?
	local root = sky and sky.PrimaryPart
	if sky == nil or root == nil then
		return
	end
	local old = sky:FindFirstChild("Cargo")
	if old then
		old:Destroy()
	end
	local cargo = Kit.model("Cargo", sky)
	local b = Kit.builder(cargo, root.CFrame, true)
	for r = 1, math.min(#rows, ArtBlimp.ROWS) do
		for s = 1, math.min(#rows[r], ArtBlimp.PER_ROW) do
			local crate = rows[r][s]
			local at = ArtBlimp.crateOffset(r, s) * CFrame.new(0, -0.8, 0)
			local box = b.block(
				"Crate",
				Vector3.new(1.6, 1.6, 1.6),
				at,
				if crate.filled then Palette.crate else Palette.crate:Lerp(Palette.cream, 0.45)
			)
			box:SetAttribute("Row", r)
			box:SetAttribute("Slot", s)
			if crate.filled then
				b.block("CrateBand", Vector3.new(1.7, 0.3, 1.7), at, Palette.woodDark, QUIET)
			end
			if crate.flagged and not crate.filled then
				b.block(
					"FlagPole",
					Vector3.new(0.12, 2.6, 0.12),
					at * CFrame.new(0.6, 0.5, -0.6),
					Palette.woodDark,
					QUIET
				)
				b.block("Flag", Vector3.new(0.1, 0.8, 1.1), at * CFrame.new(0.6, 1.4, -0.05), Palette.roofRed, QUIET)
			end
		end
	end
end

-- Moves the blimp (and its crates) so its pivot sits at `cf`, for arrivals and departures:
-- step it along a path each frame, or tween a CFrameValue and call this on Changed.
function ArtBlimp.moveBlimp(model: Instance, cf: CFrame)
	local sky = model:FindFirstChild("Blimp") :: Model?
	local root = sky and sky.PrimaryPart
	if sky == nil or root == nil then
		return
	end
	local delta = cf * root.CFrame:Inverse()
	for _, d in sky:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end

-- Shows the mast in `state` ("Broken", "Repaired", "Docked" or "Away"). The blimp shows only
-- while Docked, moored at DOCK; move it with moveBlimp for arrivals and departures.
function ArtBlimp.setState(model: Instance, state: string)
	local broken = state == "Broken"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:FindFirstAncestor("Blimp") == nil then
			if d:GetAttribute("Repaired") then
				d.Transparency = if broken then 1 else 0
				d.CanQuery = not broken
			elseif d:GetAttribute("Broken") then
				d.Transparency = if broken then 0 else 1
				d.CanQuery = broken
			end
		end
	end
	local beacon = model:FindFirstChild("Beacon", true) :: BasePart?
	if beacon then
		beacon.Material = if broken then Enum.Material.SmoothPlastic else Enum.Material.Neon
	end
	local sky = model:FindFirstChild("Blimp") :: Model?
	if sky then
		local docked = state == "Docked"
		local origin = model:GetAttribute("BlimpOrigin")
		if docked and typeof(origin) == "CFrame" then
			ArtBlimp.moveBlimp(model, origin * ArtBlimp.DOCK)
		end
		Kit.fade(sky, if docked then 0 else 1)
		for _, d in sky:GetDescendants() do
			if d:IsA("BasePart") and d ~= sky.PrimaryPart then
				d.CanQuery = docked
			end
		end
	end
end

return ArtBlimp
