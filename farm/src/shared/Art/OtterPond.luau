--!strict
-- The Otter Pond (Township's Otter Pond, Config/OtterPond): a stone-rimmed pool with a little
-- wooden dock at the front (the tap target) and a timer board, and three otter huts along the
-- back bank. Placed and moved like any building (Layout kind "otters"), so the water comes
-- with the model.
--
-- States (setState): "Dry" (an empty stony hollow, before it's built) and "Open". setOtters
-- shows each otter: "none" (not bought yet: no hut, no otter), "home" (sitting up on its
-- hut's step), "away" (swimming in the pool while it fishes) or "back" (floating on its back
-- with its catch waiting on the bank, tap to collect).
-- Faces local -Z, WIDTH x DEPTH studs. All original.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtOtterPond = {}

ArtOtterPond.WIDTH = 16
ArtOtterPond.DEPTH = 14
ArtOtterPond.OTTERS = 3
ArtOtterPond.PARTS_MAX = 40

local QUIET = { shadow = false }
local WATER_Y = 0.3
local UP = CFrame.Angles(0, 0, math.rad(90)) -- a Kit cylinder standing upright
local FUR = Palette.trunk:Lerp(Palette.wood, 0.3)

local function hutAt(i: number): Vector3
	return Vector3.new(-5 + (i - 1) * 5, 0, 4.4)
end

-- Where otter `i` is for each pose, in pond space
local function pose(i: number, state: string): CFrame
	local hut = hutAt(i)
	if state == "home" then
		-- Sitting up on the step in front of its hut, head high
		return CFrame.new(hut + Vector3.new(0, 1.4, -1.9)) * CFrame.Angles(math.rad(70), 0, 0)
	elseif state == "back" then
		-- Floating belly-up near the front of the pool
		return CFrame.new(-4 + (i - 1) * 4, WATER_Y + 0.45, -2.2) * Kit.yaw(80) * CFrame.Angles(0, 0, math.pi)
	end
	-- Swimming across the middle of the pool
	return CFrame.new(-3.6 + (i - 1) * 3.6, WATER_Y - 0.15, 0.2 - (i % 2)) * Kit.yaw(-60 + i * 40)
end

export type Parts = {
	body: BasePart, -- the dock: the tap target
	board: BasePart, -- the timer board (for a SurfaceGui on its front)
}

local function only(p: BasePart, state: string)
	p:SetAttribute(state, true)
end

-- An otter lying along local Z, belly down, head at -Z. 4 parts, each remembering its place
-- on the otter so setOtters can pose it.
local function otter(parent: Instance, origin: CFrame, i: number)
	local m = Kit.model("Otter" .. i, parent)
	m:SetAttribute("Otter", i)
	local b = Kit.builder(m, origin * pose(i, "home"), false)
	local function remember(p: BasePart, at: CFrame)
		p:SetAttribute("Local", at)
	end
	local at = CFrame.new(0, 0.35, 0)
	remember(b.block("Body", Vector3.new(0.9, 0.7, 1.8), at, FUR, QUIET), at)
	at = CFrame.new(0, 0.5, -1.15)
	remember(b.ball("Head", 0.8, at, FUR, QUIET), at)
	at = CFrame.new(0, 0.25, 1.4)
	remember(b.block("Tail", Vector3.new(0.4, 0.25, 1.2), at, FUR, QUIET), at)
	at = CFrame.new(0, 0.02, -0.1)
	remember(b.block("Belly", Vector3.new(0.7, 0.1, 1.3), at, Palette.cream:Lerp(Palette.wood, 0.3), QUIET), at)
end

-- Builds the pond with its bottom centre at `cf` (front at local -Z) and returns its parts.
function ArtOtterPond.build(parent: Instance, cf: CFrame): Parts
	parent:SetAttribute("PondCFrame", cf)
	local b = Kit.builder(parent, cf, false)
	local W, D = ArtOtterPond.WIDTH, ArtOtterPond.DEPTH
	b.block("Bank", Vector3.new(W, 0.2, D), Vector3.new(0, 0.1, 0), Palette.grassLight, QUIET)
	local water = b.cyl(
		"Water",
		0.3,
		10,
		CFrame.new(0, WATER_Y - 0.1, -1) * UP,
		Palette.water,
		{ transparency = 0.15, shadow = false, material = Enum.Material.Glass }
	)
	only(water, "Open")
	only(b.cyl("Dry", 0.25, 10, CFrame.new(0, 0.15, -1) * UP, Palette.stone, QUIET), "Dry")
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		b.ball("Stone", 1.4, Vector3.new(math.cos(a) * 5.2, 0.4, -1 + math.sin(a) * 5.2), Palette.stoneLight, QUIET)
	end
	b.post("Reeds", 2.2, 0.9, Vector3.new(6.6, 1.1, -4.6), Palette.leaf, QUIET)

	-- The huts along the back bank, each with its catch spot beside it
	for i = 1, ArtOtterPond.OTTERS do
		local hut = hutAt(i)
		local wall =
			b.block("Hut" .. i, Vector3.new(2.6, 1.8, 2), hut + Vector3.new(0, 1.1, 0.6), Palette.woodLight, QUIET)
		wall:SetAttribute("Hut", i)
		local roof = b.wedge(
			"HutRoof" .. i,
			Vector3.new(2.9, 0.8, 2.3),
			CFrame.new(hut + Vector3.new(0, 2.4, 0.6)),
			Palette.roofTeal,
			QUIET
		)
		roof:SetAttribute("Hut", i)
		local catch = b.block(
			"Catch" .. i,
			Vector3.new(1.6, 0.9, 1.6), -- a generous tap target: the shells on their rock
			hut + Vector3.new(1.6, 0.6, -1.4),
			Palette.treeTopDark,
			{ shadow = false, query = true }
		)
		catch:SetAttribute("Interact", "OtterCatch")
		catch:SetAttribute("Otter", i)
		otter(parent, cf, i)
	end

	-- The dock at the front (the tap target) and the timer board beside it
	local body = b.block(
		"Dock",
		Vector3.new(3, 0.4, 2.6),
		Vector3.new(-4.6, 0.5, -D / 2 + 1.6),
		Palette.wood,
		{ collide = true, query = true }
	)
	body:SetAttribute("Interact", "OtterPond")
	b.post("BoardPost", 2.2, 0.3, Vector3.new(4.6, 1.1, -D / 2 + 1.4), Palette.woodDark, QUIET)
	local board = b.block(
		"Board",
		Vector3.new(3.2, 1.6, 0.25),
		Vector3.new(4.6, 2.4, -D / 2 + 1.2),
		Palette.cream,
		{ query = true }
	)
	board:SetAttribute("Interact", "OtterPond")
	return { body = body, board = board }
end

local function show(p: BasePart, on: boolean)
	local base = (p:GetAttribute("BaseTransparency") :: number?) or 0
	p.Transparency = if on then base else 1
	p.CanQuery = on and p:GetAttribute("Interact") ~= nil
end

-- "Dry" or "Open"
function ArtOtterPond.setState(root: Instance, state: string)
	local open = state == "Open"
	Kit.eachPart(root, function(p)
		if p:GetAttribute("Dry") then
			show(p, not open)
		elseif p:GetAttribute("Open") then
			show(p, open)
		end
	end)
	if not open then
		ArtOtterPond.setOtters(root, { "none", "none", "none" })
	end
end

-- Each otter's state: "none", "home", "away" or "back" (see the top)
function ArtOtterPond.setOtters(root: Instance, states: { string })
	local origin = root:GetAttribute("PondCFrame")
	if typeof(origin) ~= "CFrame" then
		return
	end
	for i = 1, ArtOtterPond.OTTERS do
		local state = states[i] or "none"
		Kit.eachPart(root, function(p)
			if p:GetAttribute("Hut") == i then
				show(p, state ~= "none")
			elseif p:GetAttribute("Interact") == "OtterCatch" and p:GetAttribute("Otter") == i then
				show(p, state == "back")
			end
		end)
		local m = root:FindFirstChild("Otter" .. i)
		if m then
			local at = origin * pose(i, if state == "none" then "home" else state)
			Kit.eachPart(m, function(p)
				local here = p:GetAttribute("Local")
				if typeof(here) == "CFrame" then
					p.CFrame = at * here
				end
				show(p, state ~= "none")
			end)
		end
	end
end

return ArtOtterPond
