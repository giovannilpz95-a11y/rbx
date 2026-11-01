--!strict
-- The Harbor (Features/F02 Harbor & Far Isles): a little lagoon with a wooden pier, a
-- boathouse at its back (the tap target) with a timer board, four berths for the Sailboats and
-- a spot where the day's Driftwood Crate bobs. Each farm places its own Harbor like any other
-- building (Layout kind "harbor"), so the water comes with the model.
--
-- States (setState): "Broken" (the boathouse boarded up, the pier's deck gone and planks lying
-- about) and "Repaired". setBoats shows each berth's boat: home, away (berth empty) or back
-- (a cargo crate on its deck, tap it to unload). setDrift shows the Driftwood Crate.
-- Faces local -Z (the open water at the front), WIDTH x DEPTH studs.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtHarbor = {}

ArtHarbor.WIDTH = 24
ArtHarbor.DEPTH = 18
ArtHarbor.BERTHS = 4
ArtHarbor.BOAT_PARTS = 6 -- hull, bow, mast, sail, flag and the cargo crate
ArtHarbor.PARTS_MAX = 50

ArtHarbor.STATES = { "Broken", "Repaired" }

local QUIET = { shadow = false }
local WATER_Y = 0.35
local DECK_Y = 0.9

-- Berth positions (boat centres), two on each side of the pier
ArtHarbor.BERTH_AT = table.freeze({
	Vector3.new(-4.2, WATER_Y, -1.5),
	Vector3.new(4.2, WATER_Y, -1.5),
	Vector3.new(-4.2, WATER_Y, -6.5),
	Vector3.new(4.2, WATER_Y, -6.5),
})
ArtHarbor.DRIFT_AT = Vector3.new(9.2, WATER_Y, -6.8)

-- Sail colours, one per boat
local SAILS = { Palette.cream, Palette.roofTeal, Palette.roofMustard, Palette.flowerPink }

export type Parts = {
	body: BasePart, -- the boathouse: the tap target
	board: BasePart, -- the timer board (for a SurfaceGui on its front)
	boats: { Model },
	drift: Model,
}

local function repairedOnly(p: BasePart)
	p:SetAttribute("Repaired", true)
end
local function brokenOnly(p: BasePart)
	p:SetAttribute("Broken", true)
end

local function boat(b: Kit.Builder, parent: Instance, index: number): Model
	local m = Kit.model("Boat" .. index, parent)
	m:SetAttribute("Boat", index)
	local bb = b.into(m, true)
	local at = ArtHarbor.BERTH_AT[index]
	local base = CFrame.new(at)
	local hull = bb.block("Hull", Vector3.new(2.2, 0.8, 3.6), base * CFrame.new(0, 0.3, 0.3), Palette.wood, QUIET)
	bb.wedge(
		"Bow",
		Vector3.new(2.2, 0.8, 1.2),
		base * CFrame.new(0, 0.3, -2.1),
		Palette.wood:Lerp(Palette.woodDark, 0.3),
		QUIET
	)
	bb.post("Mast", 3.6, 0.22, base * CFrame.new(0, 2.4, 0), Palette.woodDark, QUIET)
	bb.wedge("Sail", Vector3.new(0.1, 2.8, 1.8), base * CFrame.new(0, 2.4, 1), SAILS[index], QUIET)
	bb.block("Flag", Vector3.new(0.1, 0.4, 0.6), base * CFrame.new(0, 4.1, -0.3), Palette.roofRed, QUIET)
	local crate = bb.block("Cargo", Vector3.new(1.2, 0.9, 1.2), base * CFrame.new(0, 1.15, 1.2), Palette.crate, QUIET)
	crate:SetAttribute("Interact", "HarborBoat")
	crate:SetAttribute("Boat", index)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("Interact", "HarborBoat")
			d:SetAttribute("Boat", index)
			d:SetAttribute("HandsFirst", true)
		end
	end
	m.PrimaryPart = hull
	return m
end

-- Builds the Harbor with its bottom centre at `cf` (front at local -Z) and returns its parts.
function ArtHarbor.build(parent: Instance, cf: CFrame): Parts
	local b = Kit.builder(parent, cf, false)
	local W, D = ArtHarbor.WIDTH, ArtHarbor.DEPTH
	-- The lagoon: open water across the front, stone edges
	local waterD = 12
	local waterZ = -D / 2 + waterD / 2
	b.block(
		"Water",
		Vector3.new(W - 1, 0.3, waterD),
		Vector3.new(0, WATER_Y - 0.15, waterZ),
		Palette.water,
		{ transparency = 0.15, shadow = false, material = Enum.Material.Glass }
	)
	b.block("Edge", Vector3.new(W, 0.6, 0.5), Vector3.new(0, 0.3, -D / 2 + 0.25), Palette.stone, QUIET)
	b.block("Edge", Vector3.new(0.5, 0.6, waterD), Vector3.new(-W / 2 + 0.25, 0.3, waterZ), Palette.stone, QUIET)
	b.block("Edge", Vector3.new(0.5, 0.6, waterD), Vector3.new(W / 2 - 0.25, 0.3, waterZ), Palette.stone, QUIET)
	b.block(
		"Quay",
		Vector3.new(W, 0.5, D - waterD),
		Vector3.new(0, 0.25, waterZ + waterD / 2 + (D - waterD) / 2),
		Palette.stoneLight,
		QUIET
	)

	-- The boathouse on the quay, its doors facing the water
	local houseAt = Vector3.new(-6, 0.5, D / 2 - 3)
	local body = b.block(
		"Boathouse",
		Vector3.new(7, 4.2, 4.5),
		houseAt + Vector3.new(0, 2.1, 0),
		Palette.wood,
		{ collide = true, query = true }
	)
	body:SetAttribute("Interact", "Harbor")
	body:SetAttribute("HandsFirst", true) -- a fresh press here opens the Harbor, beds or not
	b.wedge("Roof", Vector3.new(7.6, 1.6, 2.6), CFrame.new(houseAt + Vector3.new(0, 5, -1.15)), Palette.roofTeal)
	b.wedge(
		"Roof",
		Vector3.new(7.6, 1.6, 2.6),
		CFrame.new(houseAt + Vector3.new(0, 5, 1.15)) * Kit.yaw(180),
		Palette.roofTeal
	)
	b.block("Doors", Vector3.new(3, 3, 0.2), houseAt + Vector3.new(0, 1.5, -2.3), Palette.woodDark, QUIET)
	local boards = b.block(
		"Boards",
		Vector3.new(3.4, 0.4, 0.25),
		CFrame.new(houseAt + Vector3.new(0, 1.6, -2.45)) * CFrame.Angles(0, 0, math.rad(20)),
		Palette.woodLight,
		QUIET
	)
	brokenOnly(boards)

	-- The timer board on a post at the quay's right
	local boardAt = Vector3.new(6.5, 0.5, D / 2 - 2.5)
	b.post("BoardPost", 2.4, 0.3, boardAt + Vector3.new(0, 1.2, 0.2), Palette.woodDark, QUIET)
	local board =
		b.block("Board", Vector3.new(3.6, 1.8, 0.25), boardAt + Vector3.new(0, 2.6, 0), Palette.cream, { query = true })
	board:SetAttribute("Interact", "Harbor")
	board:SetAttribute("HandsFirst", true)

	-- The pier from the quay out across the water, between the berths
	local deck = b.block(
		"Deck",
		Vector3.new(2.6, 0.3, waterD - 1),
		Vector3.new(0, DECK_Y, waterZ + 0.5),
		Palette.woodLight,
		{ collide = true, shadow = false }
	)
	repairedOnly(deck)
	for _, z in { -7.5, -3 } do
		local post = b.post("Piling", 1.2, 0.4, Vector3.new(1.4, 0.5, z), Palette.woodDark, QUIET)
		repairedOnly(post)
	end
	-- Planks lying on the quay while it's broken
	for i, x in { 2, 3.6 } do
		local plank = b.block(
			"Plank",
			Vector3.new(0.6, 0.2, 3.4),
			CFrame.new(x, 0.6, D / 2 - 2.2) * Kit.yaw(i * 25),
			Palette.woodLight,
			QUIET
		)
		brokenOnly(plank)
	end

	local boats = {}
	for i = 1, ArtHarbor.BERTHS do
		boats[i] = boat(b, parent, i)
	end

	-- The Driftwood Crate, bobbing in the far corner
	local drift = Kit.model("Drift", parent)
	local db = b.into(drift, true)
	local dc = CFrame.new(ArtHarbor.DRIFT_AT) * Kit.yaw(20)
	db.block(
		"Crate",
		Vector3.new(1.4, 1, 1.4),
		dc * CFrame.new(0, 0.2, 0),
		Palette.woodLight:Lerp(Palette.stoneLight, 0.3),
		QUIET
	)
	db.block("Band", Vector3.new(1.45, 0.3, 1.45), dc * CFrame.new(0, 0.2, 0), Palette.woodDark, QUIET)
	for _, d in drift:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("Interact", "HarborDrift")
		end
	end

	return { body = body, board = board, boats = boats, drift = drift :: Model }
end

local function show(p: BasePart, on: boolean)
	local base = (p:GetAttribute("BaseTransparency") :: number?) or 0
	p.Transparency = if on then base else 1
	p.CanQuery = on and p:GetAttribute("Interact") ~= nil
	if p.Name == "Deck" then
		p.CanCollide = on
	end
end

-- "Broken" or "Repaired": the boarded-up look or the working one
function ArtHarbor.setState(root: Instance, state: string)
	local broken = state == "Broken"
	Kit.eachPart(root, function(p)
		if p:GetAttribute("Broken") then
			show(p, broken)
		elseif p:GetAttribute("Repaired") then
			show(p, not broken)
		end
	end)
	if broken then
		ArtHarbor.setBoats(root, {})
		ArtHarbor.setDrift(root, false)
	end
end

-- Each berth's boat: "home", "away" or "back" (nil = not owned yet: the berth stays empty)
function ArtHarbor.setBoats(root: Instance, states: { [number]: string? })
	for i = 1, ArtHarbor.BERTHS do
		local m = root:FindFirstChild("Boat" .. i)
		if m then
			local state = states[i]
			Kit.eachPart(m, function(p)
				if p.Name == "Cargo" then
					show(p, state == "back")
				else
					show(p, state == "home" or state == "back")
				end
			end)
		end
	end
end

function ArtHarbor.setDrift(root: Instance, on: boolean)
	local m = root:FindFirstChild("Drift")
	if m then
		Kit.eachPart(m, function(p)
			show(p, on)
		end)
	end
end

return ArtHarbor
