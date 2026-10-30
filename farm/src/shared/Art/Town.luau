--!strict
-- The plot's own landmarks (Model List - Town & Factories): the Town Hall at the heart of the
-- start area, the signpost and the wild obstacles on land that isn't cleared yet, and the
-- Puzzle Porch where you play Crop Pop on your own farm. All original, built from Parts.
-- Fronts face local -Z.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtTown = {}

ArtTown.TOWNHALL_PARTS_MAX = 36
ArtTown.SIGNPOST_PARTS_MAX = 4
ArtTown.OBSTACLE_PARTS_MAX = 4
ArtTown.PORCH_PARTS_MAX = 10
ArtTown.TENT_PARTS_MAX = 24
ArtTown.TENT_SIZE = Vector3.new(14, 0, 14)

ArtTown.TOWNHALL_SIZE = Vector3.new(11, 0, 9) -- footprint: width (X) x depth (Z)

local QUIET = { shadow = false }
local PLINTH = 0.6
local STORY = 6

---------------------------------------------------------------------------------------------
-- Town Hall (16 Model Catalog §2.10): a two-tone oat hall with wide front steps, cream
-- columns and a pediment over a big loaf door, a bell cupola with an XL Sprout Tag on the
-- roof, the plot sign out front and a mailbox. It grows a storey with each Town Records
-- level (F07): `storeys` 1-3.
---------------------------------------------------------------------------------------------

-- Two windows across a wall face at height `y` (centre), on the face at local z `z`.
local function windowPair(b: Kit.Builder, y: number, z: number, spread: number)
	for _, x in { -spread, spread } do
		Kit.window(b, "Window", CFrame.new(x, y, z), 1.6, 2, Palette.cream, Palette.glass)
	end
end

-- Builds the Town Hall into `parent` with its bottom-centre at `cf`. Returns the hall's body
-- (the tap target) and the plot sign board, whose front (local -Z) face the caller can write
-- the owner's name on.
function ArtTown.townHall(parent: Instance, cf: CFrame, storeys: number?): (Part, Part)
	local floors = math.clamp(storeys or 1, 1, 3)
	local b = Kit.builder(parent, cf, true)
	local w, d = ArtTown.TOWNHALL_SIZE.X, ArtTown.TOWNHALL_SIZE.Z
	b.block("Plinth", Vector3.new(w + 0.5, PLINTH, d + 0.5), Vector3.new(0, PLINTH / 2, 0), Palette.stone)
	local body = b.block(
		"TownHall",
		Vector3.new(w, STORY, d),
		Vector3.new(0, PLINTH + STORY / 2, 0),
		Palette.oat,
		{ collide = true }
	)
	local t = b.into(body, true)
	local front = -d / 2
	-- Ground floor: steps, two columns and a pediment framing the door, a window either side
	t.block("Step", Vector3.new(5.6, 0.3, 1.6), Vector3.new(0, 0.15, front - 0.8), Palette.stoneLight)
	t.block("Step", Vector3.new(4.6, 0.3, 0.8), Vector3.new(0, 0.45, front - 0.4), Palette.stoneLight)
	Kit.door(t, "Door", CFrame.new(0, PLINTH, front), 2.4, 4.4, Palette.roofTeal, Palette.cream)
	for _, x in { -2, 2 } do
		t.post("Column", STORY - 0.6, 0.7, Vector3.new(x, PLINTH + (STORY - 0.6) / 2, front - 0.45), Palette.cream)
	end
	t.wedge("Pediment", Vector3.new(5.2, 1.1, 1), Vector3.new(0, PLINTH + STORY - 0.05, front - 0.5), Palette.cream)
	windowPair(t, PLINTH + 3, front, w / 2 - 1.6)
	-- Upper storeys step in a little, lighter each time
	local top = PLINTH + STORY
	local upperW, upperD = w, d
	for floor = 2, floors do
		upperW, upperD = upperW - 1.4, upperD - 1.2
		local h = if floor == 2 then 5 else 4.2
		t.block(
			"Storey",
			Vector3.new(upperW, h, upperD),
			Vector3.new(0, top + h / 2, 0),
			if floor == 2 then Palette.oat:Lerp(Palette.wheat, 0.18) else Palette.cream,
			{ collide = true }
		)
		if floor == 2 then
			windowPair(t, top + h / 2, -upperD / 2, upperW / 2 - 1.5)
		else
			Kit.window(t, "Window", CFrame.new(0, top + h / 2, -upperD / 2), 2.2, 2, Palette.cream, Palette.glass)
		end
		top += h
	end
	-- Roof, with the bell cupola on the ridge
	Kit.gableRoof(t, "Roof", Vector3.new(0, top, 0), upperW + 1.2, upperD + 1.2, 3, Palette.roofRed)
	local ridge = top + 3
	t.block("Cupola", Vector3.new(2.4, 2.2, 2.4), Vector3.new(0, ridge + 0.7, 0), Palette.cream)
	local bell = t.ball("Bell", 1.3, Vector3.new(0, ridge + 0.75, -1.25), Palette.coins, QUIET)
	-- For the level-up swing on the client: the bell hangs from the top of its opening
	bell:SetAttribute("HingeCFrame", bell.CFrame * CFrame.new(0, 0.9, 0))
	t.ball("Dome", 3, Vector3.new(0, ridge + 1.9, 0), Palette.roofTeal)
	Kit.sproutTag(t, Vector3.new(0, ridge + 3.2, 0), 4, Palette.wood, Palette.lime)
	-- The plot sign (left of the steps) and the mailbox (right)
	local signAt = Vector3.new(-w / 2 - 1.2, 0, front + 1)
	t.block("SignPost", Vector3.new(0.4, 3, 0.4), signAt + Vector3.new(0, 1.5, 0.25), Palette.woodDark)
	local sign = t.block(
		"PlotSign",
		Vector3.new(3.2, 1.8, 0.3),
		signAt + Vector3.new(0, 3, 0),
		Palette.woodLight,
		{ collide = true }
	)
	local mail = Vector3.new(w / 2 + 1.2, 0, front + 1)
	t.block("MailPost", Vector3.new(0.35, 2.4, 0.35), mail + Vector3.new(0, 1.2, 0), Palette.woodDark)
	t.block("Mailbox", Vector3.new(0.9, 0.9, 1.5), mail + Vector3.new(0, 2.7, 0), Palette.roofTeal)
	t.block("MailFlag", Vector3.new(0.12, 0.7, 0.4), mail + Vector3.new(0.5, 3.1, 0.3), Palette.roofRed, QUIET)
	return body, sign
end

---------------------------------------------------------------------------------------------
-- Locked land (Model List: Roads, land & expansions): a signpost per expansion and a scatter
-- of wild obstacles (tall grass, rocks, mounds, wild trees, stumps), so unopened land reads
-- as wild instead of just darker grass. Each obstacle stays within OBSTACLE_PARTS_MAX.
---------------------------------------------------------------------------------------------

-- A wooden signpost with a board for the expansion's name and cost (the caller writes it on
-- the board's front, local -Z) and an arrow pointing in. Returns the board. 4 parts.
function ArtTown.signpost(parent: Instance, cf: CFrame): Part
	local b = Kit.builder(parent, cf, false)
	b.block("Post", Vector3.new(0.5, 5, 0.5), Vector3.new(0, 2.5, 0.3), Palette.woodDark)
	local board = b.block("Board", Vector3.new(4, 2.2, 0.3), Vector3.new(0, 4, 0), Palette.woodLight)
	b.block("BoardCap", Vector3.new(4.3, 0.3, 0.5), Vector3.new(0, 5.2, 0), Palette.wood, QUIET)
	b.wedge(
		"Arrow",
		Vector3.new(0.3, 0.8, 1.2),
		CFrame.new(0, 2.2, -0.1) * CFrame.Angles(0, math.rad(90), math.rad(-90)),
		Palette.roofMustard,
		QUIET
	)
	return board
end

local OBSTACLES: { [string]: (Kit.Builder) -> () } = {
	TallGrass = function(b)
		for i, spot in { Vector3.new(-0.6, 0, 0.2), Vector3.new(0.5, 0, -0.3), Vector3.new(0.1, 0, 0.7) } do
			local h = 2.2 + i * 0.25
			b.block(
				"Grass",
				Vector3.new(0.9, h, 0.9),
				CFrame.new(spot + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.rad(i * 25), math.rad(i * 4 - 8)),
				if i == 2 then Palette.grassDark else Palette.leafLight,
				QUIET
			)
		end
	end,
	Rock = function(b)
		b.ball("Rock", 2.4, Vector3.new(0, 0.6, 0), Palette.stone)
		b.ball("Rock", 1.4, Vector3.new(1.1, 0.4, -0.5), Palette.stoneLight)
	end,
	Mound = function(b)
		b.post("Mound", 1, 3.2, Vector3.new(0, 0.3, 0), Palette.soil)
		b.post("Mound", 0.6, 2, Vector3.new(0.2, 0.9, 0.1), Palette.soilLight)
		b.ball("Clod", 0.6, Vector3.new(-1.1, 0.4, -0.9), Palette.soilDark, QUIET)
	end,
	WildTree = function(b)
		-- Gnarled and leaning, with a darker, shaggier canopy than the plot's trees
		local lean = CFrame.Angles(0, 0, math.rad(8))
		b.post("Trunk", 4, 1, lean * CFrame.new(0, 2, 0), Palette.trunk)
		b.ball("Canopy", 4.2, lean * CFrame.new(0.3, 4.8, 0).Position, Palette.treeTopDark)
		b.ball("Canopy", 3, lean * CFrame.new(-1.2, 4.2, 0.6).Position, Palette.grassDark)
		b.block("Root", Vector3.new(2.2, 0.5, 0.6), CFrame.new(0.4, 0.25, 0) * Kit.yaw(30), Palette.trunk, QUIET)
	end,
	Stump = function(b)
		b.post("Stump", 1.3, 1.8, Vector3.new(0, 0.65, 0), Palette.trunk)
		b.post("Rings", 0.12, 1.5, Vector3.new(0, 1.36, 0), Palette.woodLight, QUIET)
		b.block("Root", Vector3.new(2.4, 0.4, 0.5), CFrame.new(0, 0.2, 0) * Kit.yaw(-20), Palette.trunk, QUIET)
	end,
}

ArtTown.OBSTACLE_TYPES = { "TallGrass", "Rock", "Mound", "WildTree", "Stump" }

function ArtTown.obstacle(id: string, parent: Instance, cf: CFrame)
	local builder = OBSTACLES[id] or OBSTACLES.TallGrass
	builder(Kit.builder(parent, cf, false))
end

-- Where the obstacles go on a locked rectangle (plot-local min and max corners): a jittered
-- grid about every `spacing` studs, kept 3 studs in from the edges and clear of the
-- signpost at the rectangle's centre. The same rectangle always gives the same scatter.
-- Returns { position, yaw, obstacle id }.
-- `keepClear` lists rectangles ({ min, max }) where nothing may go, such as roads that run
-- through locked land.
function ArtTown.scatter(
	min: Vector3,
	max: Vector3,
	spacing: number?,
	keepClear: { { Vector3 } }?
): { { at: Vector3, yaw: number, id: string } }
	local step = spacing or 16
	local function clear(at: Vector3): boolean
		for _, r in keepClear or {} do
			if at.X > r[1].X - 3 and at.X < r[2].X + 3 and at.Z > r[1].Z - 3 and at.Z < r[2].Z + 3 then
				return false
			end
		end
		return (at - (min + max) / 2).Magnitude > 6
	end
	local out = {}
	local seed = math.floor(math.abs(min.X * 7 + min.Z * 13 + max.X * 3)) % 997
	local i = 0
	local x = min.X + 3
	while x <= max.X - 3 do
		local z = min.Z + 3
		while z <= max.Z - 3 do
			i += 1
			local h = (seed + i * 7919) % 1000
			local jx = ((h % 37) / 37 - 0.5) * step * 0.6
			local jz = (((h // 37) % 41) / 41 - 0.5) * step * 0.6
			local at =
				Vector3.new(math.clamp(x + jx, min.X + 3, max.X - 3), 0, math.clamp(z + jz, min.Z + 3, max.Z - 3))
			if clear(at) then
				table.insert(out, {
					at = at,
					yaw = (h % 360),
					id = ArtTown.OBSTACLE_TYPES[(h % #ArtTown.OBSTACLE_TYPES) + 1],
				})
			end
			z += step
		end
		x += step
	end
	return out
end

---------------------------------------------------------------------------------------------
-- The Puzzle Porch on each plot (F12 Crop Pop Puzzle): a little deck with a rocking chair and
-- a side table holding the Crop Pop game box. Tapping any of it opens Crop Pop. 9 parts.
---------------------------------------------------------------------------------------------

function ArtTown.porch(parent: Instance, cf: CFrame): Model
	local porch = Kit.model("PlotPorch", parent)
	local b = Kit.builder(porch, cf, true)
	b.block("Deck", Vector3.new(5, 0.4, 4), Vector3.new(0, 0.2, 0), Palette.woodLight)
	-- Rocking chair, facing out (local -Z), on a curved rocker
	local chair = CFrame.new(-1, 0.4, 0.4)
	b.block("Rocker", Vector3.new(1.8, 0.25, 2), chair * CFrame.new(0, 0.15, 0), Palette.woodDark)
	b.block("Seat", Vector3.new(1.8, 0.3, 1.7), chair * CFrame.new(0, 1.1, 0), Palette.wood)
	b.block(
		"Back",
		Vector3.new(1.8, 2, 0.3),
		chair * CFrame.new(0, 2.1, 0.85) * CFrame.Angles(math.rad(-10), 0, 0),
		Palette.wood
	)
	b.block("Cushion", Vector3.new(1.5, 0.25, 1.4), chair * CFrame.new(0, 1.35, -0.05), Palette.roofRed, QUIET)
	-- Side table with the game box: a little crate-shaped console with a bright screen
	local tbl = Vector3.new(1.4, 0.4, 0.3)
	b.post("TableLeg", 1.3, 0.35, tbl + Vector3.new(0, 0.65, 0), Palette.woodDark)
	b.post("Table", 0.2, 1.6, tbl + Vector3.new(0, 1.4, 0), Palette.wood)
	b.block("GameBox", Vector3.new(1.1, 0.8, 0.7), tbl + Vector3.new(0, 1.9, 0), Palette.roofMustard)
	b.block(
		"Screen",
		Vector3.new(0.8, 0.5, 0.05),
		tbl + Vector3.new(0, 1.95, -0.37),
		Palette.lime,
		{ shadow = false, material = Enum.Material.Neon }
	)
	return porch
end

---------------------------------------------------------------------------------------------
-- Event Tent (Model List §6, 20 Live Ops & Events): the hub for limited-time events. A cream
-- festival marquee under a big gable roof with a scalloped valance, a pennant pole, door
-- flaps and a sign over the door. Closed, the flaps are shut and the roof is plain; open
-- (setEventTent), the flaps tie back, the roof and valance take the event's color and a
-- string of bunting appears across the front.
---------------------------------------------------------------------------------------------

function ArtTown.eventTent(parent: Instance, cf: CFrame): (Model, Part)
	local model = Kit.model("EventTent", parent)
	local b = Kit.builder(model, cf, true)
	b.block("Wall", Vector3.new(12, 4.6, 12), Vector3.new(0, 2.3, 0), Palette.cream, { collide = true })
	b.block("Mat", Vector3.new(3.6, 0.2, 1.6), Vector3.new(0, 0.1, -6.8), Palette.roofRed, QUIET)
	Kit.gableRoof(b, "Roof", CFrame.new(0, 4.6, 0) * Kit.yaw(90), 13, 13, 4.6, Palette.cream)
	for _, d in model:GetChildren() do
		if d.Name == "Roof" then
			d:SetAttribute("Stripe", true) -- takes the event color while open
		end
	end
	for _, x in { -6.4, 6.4 } do
		for i = 1, 4 do
			local ball = b.ball("Valance", 1.3, Vector3.new(x, 4.3, -4.8 + (i - 1) * 3.2), Palette.roofTeal, QUIET)
			ball:SetAttribute("Stripe", i % 2 == 1)
		end
	end
	b.post("Pole", 3, 0.3, Vector3.new(0, 10.6, 0), Palette.cocoa)
	b.block("Pennant", Vector3.new(1.8, 1, 0.12), Vector3.new(0.9, 11.6, 0), Palette.roofRed, QUIET)
	local sign = b.block("EventSign", Vector3.new(4, 1.2, 0.3), Vector3.new(0, 6.3, -6.75), Palette.cream)
	b.block("SignTrim", Vector3.new(4.6, 1.7, 0.2), Vector3.new(0, 6.3, -6.6), Palette.wood, QUIET)
	-- Door flaps: shut across the doorway, or tied back to either side
	for _, side in { -1, 1 } do
		local shut = CFrame.new(side * 0.95, 2, -6.1)
		local open = CFrame.new(side * 2.4, 2, -6.4) * Kit.yaw(side * 35)
		local flap = b.block("Flap", Vector3.new(1.9, 4, 0.2), shut, Palette.roofTeal)
		flap:SetAttribute("ShutCFrame", cf * shut)
		flap:SetAttribute("OpenCFrame", cf * open)
	end
	-- Bunting: a string of little pennants under the front eave, shown only while open
	for i = 1, 5 do
		local color = ({ Palette.roofMustard, Palette.flowerPink, Palette.roofTeal, Palette.lime })[(i - 1) % 4 + 1]
		local at = CFrame.new(-4 + (i - 1) * 2, 5.4 - math.abs(i - 3) * -0.2 - 0.6, -6.6)
		b.block("Bunting", Vector3.new(0.9, 0.9, 0.1), at * CFrame.Angles(0, 0, math.rad(45)), color, QUIET)
	end
	ArtTown.setEventTent(model, false)
	return model, sign
end

-- Opens or closes the tent; open, the roof stripes take `color` (the event's color).
function ArtTown.setEventTent(tent: Model, open: boolean, color: Color3?)
	for _, d in tent:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		if d.Name == "Flap" then
			local cf = d:GetAttribute(if open then "OpenCFrame" else "ShutCFrame")
			if typeof(cf) == "CFrame" then
				d.CFrame = cf
			end
		elseif (d.Name == "Roof" or d.Name == "Valance") and d:GetAttribute("Stripe") then
			d.Color = if open then color or Palette.roofRed else Palette.cream
		elseif d.Name == "Valance" or d.Name == "RoofRidge" then
			d.Color = if open then Palette.cream else Palette.roofTeal
		elseif d.Name == "Bunting" then
			d.Transparency = if open then 0 else 1
			d.CanQuery = open
		end
	end
	tent:SetAttribute("Open", open)
end

return ArtTown
