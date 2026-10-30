--!strict
-- The Barn, the Order Board with its loading dock, the delivery truck and the plot gate.
-- Design/16 Model Catalog §2.5, §2.6 and §2.19.
--
-- Each builder dresses a tap-target part the plot already made (the Barn block, the Order
-- Board panel, the truck root), parenting the decoration under it so taps on any piece reach
-- the target. Fronts face local -Z unless noted.

local Kit = require("./Kit")
local Palette = require("./Palette")

local ArtBuildings = {}

ArtBuildings.BARN_PARTS_MAX = 40
ArtBuildings.BOARD_PARTS_MAX = 20
ArtBuildings.TRUCK_PARTS_MAX = 20

local TURN = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis from X to Z

-- Storage Barn, look 1 (Barn L1-3): red walls with cream corner trim, a tall half-loaf roof, a
-- big sliding door with a cream X brace and a round hayloft window. `cf` is the bottom-centre
-- with the door at local -Z; the footprint is `width` (X) x `depth` (Z). Returns the body
-- block, which the caller makes the "Barn" tap target. About 25 parts.
function ArtBuildings.barn(parent: Instance, cf: CFrame, width: number, depth: number): Part
	local b = Kit.builder(parent, cf, true)
	local plinth = 0.75
	local wall = 7
	local top = plinth + wall
	b.block("Plinth", Vector3.new(width + 0.5, plinth, depth + 0.5), Vector3.new(0, plinth / 2, 0), Palette.stone)
	local body = b.block(
		"Barn",
		Vector3.new(width, wall, depth),
		Vector3.new(0, plinth + wall / 2, 0),
		Palette.barnRed,
		{ collide = true }
	)
	-- Everything else hangs off the body so a tap anywhere on the Barn reaches it
	local d = b.into(body, true)
	local radius = width / 2 + 0.5
	d.cyl("Roof", depth - 0.1, radius * 2, CFrame.new(0, top, 0) * TURN, Palette.roofRed)
	d.block(
		"RoofBand",
		Vector3.new(width + 1.1, 0.5, depth - 0.3),
		Vector3.new(0, top + 0.1, 0),
		Palette.cream,
		{ shadow = false }
	)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			d.block(
				"Trim",
				Vector3.new(0.6, wall, 0.6),
				Vector3.new(x * (width / 2), plinth + wall / 2, z * (depth / 2)),
				Palette.cream,
				{ shadow = false }
			)
		end
	end
	-- Sliding door on its rail
	local front = -depth / 2
	d.block("DoorFrame", Vector3.new(7, 6.3, 0.25), Vector3.new(0, plinth + 3.15, front - 0.12), Palette.cream)
	d.block(
		"Door",
		Vector3.new(6.2, 5.8, 0.3),
		Vector3.new(0, plinth + 2.9, front - 0.3),
		Palette.barnRed:Lerp(Palette.cocoa, 0.2)
	)
	for _, sign in { -1, 1 } do
		d.block(
			"DoorBrace",
			Vector3.new(0.5, 8.2, 0.2),
			CFrame.new(0, plinth + 2.9, front - 0.5) * CFrame.Angles(0, 0, sign * math.atan2(6.2, 5.8)),
			Palette.cream,
			{ shadow = false }
		)
	end
	d.block(
		"DoorRail",
		Vector3.new(9, 0.4, 0.4),
		Vector3.new(0, plinth + 6.5, front - 0.35),
		Palette.cocoa,
		{ shadow = false }
	)
	-- Round hayloft window with crates inside, in the front of the roof
	d.cyl("Loft", 0.3, 3.6, CFrame.new(0, top + 2.6, front + 0.05) * TURN, Palette.cream)
	d.cyl("LoftDark", 0.3, 2.8, CFrame.new(0, top + 2.6, front - 0.05) * TURN, Palette.cocoa)
	d.block(
		"LoftCrate",
		Vector3.new(1.4, 1.2, 0.3),
		Vector3.new(-0.4, top + 2.2, front - 0.15),
		Palette.crate,
		{ shadow = false }
	)
	-- Side windows
	for _, x in { -1, 1 } do
		local side = CFrame.new(x * (width / 2), plinth + 4.2, 1.5) * Kit.yaw(x * -90)
		Kit.window(d, "Window", side, 2, 2.4, Palette.cream, Palette.glass)
	end
	-- Hay bales by the door
	d.block("HayBale", Vector3.new(2.2, 1.4, 1.5), Vector3.new(width / 2 - 1.2, 0.7, front - 1.6), Palette.straw)
	d.block(
		"HayBale",
		Vector3.new(2, 1.3, 1.4),
		CFrame.new(width / 2 - 1.4, 2.05, front - 1.6) * Kit.yaw(12),
		Palette.straw
	)
	Kit.sproutTag(d, Vector3.new(0, top + radius - 0.2, 0), 2.5, Palette.wood, Palette.lime)
	return body
end

-- Order Board: a corkboard under a little teal gable roof on two chunky posts, with a brass
-- delivery bell and a mailbox flag. `board` is the existing 0.5 x 7 x 10 panel whose Left face
-- (-X) shows the order cards and whose centre is `height` studs above the ground; the
-- decoration is built around it. 19 parts with the board.
function ArtBuildings.orderBoard(board: BasePart, height: number)
	board.Color = Palette.cork
	board.Material = Enum.Material.SmoothPlastic
	local size = board.Size
	local halfH, halfW = size.Y / 2, size.Z / 2
	-- Local frame: the board's centre, with the card face toward local -X
	local b = Kit.builder(board, board.CFrame, true)
	local groundY = -height
	local postH = halfH + 3.5 - groundY
	for _, z in { -1, 1 } do
		b.block(
			"Post",
			Vector3.new(1, postH, 1),
			Vector3.new(0.1, groundY + postH / 2, z * (halfW + 0.5)),
			Palette.woodDark
		)
	end
	b.block("FrameTop", Vector3.new(0.8, 0.6, size.Z + 0.6), Vector3.new(0, halfH + 0.3, 0), Palette.cream)
	b.block("FrameBottom", Vector3.new(0.8, 0.6, size.Z + 0.6), Vector3.new(0, -halfH - 0.3, 0), Palette.cream)
	for _, z in { -1, 1 } do
		b.block(
			"FrameSide",
			Vector3.new(0.8, size.Y, 0.4),
			Vector3.new(0, 0, z * (halfW + 0.05)),
			Palette.cream,
			{ shadow = false }
		)
	end
	Kit.gableRoof(
		b,
		"Roof",
		CFrame.new(0.1, halfH + 0.9, 0) * Kit.yaw(90),
		size.Z + 3,
		3.2,
		1.6,
		Palette.roofTeal,
		Palette.cream
	)
	-- Delivery bell on a bracket at the north end
	b.block(
		"BellArm",
		Vector3.new(1.2, 0.25, 0.25),
		Vector3.new(-0.7, halfH - 0.6, -(halfW + 0.5)),
		Palette.cocoa,
		{ shadow = false }
	)
	b.ball(
		"Bell",
		0.9,
		Vector3.new(-1.2, halfH - 1.2, -(halfW + 0.5)),
		Palette.coins:Lerp(Palette.wood, 0.3),
		{ shadow = false }
	)
	-- Mailbox-style flag that pops up when a new order arrives
	b.block(
		"FlagPole",
		Vector3.new(0.2, 2.2, 0.2),
		Vector3.new(-0.3, halfH + 1.1, halfW + 0.5),
		Palette.cocoa,
		{ shadow = false }
	)
	b.block(
		"Flag",
		Vector3.new(0.15, 0.9, 1.3),
		Vector3.new(-0.3, halfH + 1.75, halfW - 0.2),
		Palette.roofRed,
		{ shadow = false }
	)
end

-- Loading dock where the truck waits: a flat plank pad and a stack of crates. 4 parts.
function ArtBuildings.dock(parent: Instance, cf: CFrame)
	local b = Kit.builder(parent, cf, false)
	b.block("Dock", Vector3.new(8, 0.2, 14), Vector3.new(0, 0.3, 0), Palette.woodLight, { shadow = false })
	b.block("Crate", Vector3.new(1.6, 1.6, 1.6), Vector3.new(-4.8, 0.8, -4), Palette.crate)
	b.block("Crate", Vector3.new(1.6, 1.6, 1.6), Vector3.new(-4.8, 0.8, -2.2), Palette.crate)
	b.block("Crate", Vector3.new(1.6, 1.6, 1.6), CFrame.new(-4.8, 2.4, -3.1) * Kit.yaw(15), Palette.crate)
end

-- Delivery Truck: a stubby cab-over pickup with a round bubble cab, mustard body, teal fenders,
-- big round headlights and a slatted flatbed. Built around `root`, the truck's invisible
-- 6 x 3 x 10 tween target, with the cab toward +Z (the way it drives out). The parts are welded
-- to the root so tweening the root moves the truck. 17 parts with the root.
function ArtBuildings.truck(root: BasePart)
	Kit.hide(root)
	root.CanCollide = false
	local b = Kit.builder(root, root.CFrame, false)
	local ground = -root.Size.Y / 2 - 1 -- the root floats 1 stud above the road in the greybox
	local axle = ground + 1.1
	b.block("Chassis", Vector3.new(5.4, 0.8, 11.6), Vector3.new(0, axle + 0.6, 0.6), Palette.cocoa)
	b.block("Bed", Vector3.new(5.8, 0.5, 6.6), Vector3.new(0, axle + 1.25, -1.6), Palette.woodLight)
	for _, x in { -2.7, 2.7 } do
		b.block("BedSide", Vector3.new(0.4, 1.3, 6.6), Vector3.new(x, axle + 2.1, -1.6), Palette.roofMustard)
	end
	b.block("Tailgate", Vector3.new(5.8, 1.3, 0.4), Vector3.new(0, axle + 2.1, -4.7), Palette.roofMustard)
	b.block("Cab", Vector3.new(5.6, 3, 4.2), Vector3.new(0, axle + 2.5, 3.9), Palette.roofMustard)
	b.cyl("CabTop", 5.6, 4.2, Vector3.new(0, axle + 4, 3.9), Palette.roofMustard)
	b.block("Windshield", Vector3.new(4.6, 1.5, 0.3), Vector3.new(0, axle + 4.2, 6.0), Palette.glass)
	b.block("Grille", Vector3.new(4.2, 1, 0.3), Vector3.new(0, axle + 2.1, 6.05), Palette.cream, { shadow = false })
	for _, z in { -2.6, 3.9 } do
		b.block("Fender", Vector3.new(6.3, 0.7, 2.9), Vector3.new(0, axle + 1.3, z), Palette.roofTeal)
		b.cyl("Wheels", 6, 2.2, Vector3.new(0, axle, z), Palette.tire)
	end
	for _, x in { -1.9, 1.9 } do
		b.ball("Headlight", 0.9, Vector3.new(x, axle + 2.9, 6.05), Palette.lantern, { shadow = false })
	end
	b.block(
		"Antenna",
		Vector3.new(0.15, 1.6, 0.15),
		Vector3.new(2.3, axle + 6.6, 3.2),
		Palette.cocoa,
		{ shadow = false }
	)
	b.ball("AntennaTip", 0.5, Vector3.new(2.3, axle + 7.5, 3.2), Palette.lime, { shadow = false })
	Kit.weld(root)
end

-- Plot gate: two stone-footed wooden posts, a beam with a little red gable roof over the name
-- sign, flower boxes and a Sprout Tag on top. `cf` is the gate's centre on the ground with the
-- road at local -Z. Returns the cream sign part (14 x 3 x 0.4) for the owner's name.
function ArtBuildings.gate(parent: Instance, cf: CFrame): Part
	local b = Kit.builder(parent, cf, false)
	for _, x in { -6, 6 } do
		b.block("GateFoot", Vector3.new(2.4, 1.6, 2.4), Vector3.new(x, 0.8, 0), Palette.stone, { collide = true })
		b.block(
			"GatePost",
			Vector3.new(1.5, 9.4, 1.5),
			Vector3.new(x, 1.6 + 4.7, 0),
			Palette.woodDark,
			{ collide = true }
		)
		Kit.bush(
			b,
			"FlowerBox",
			Vector3.new(x + (if x < 0 then -2.2 else 2.2), 0, -0.6),
			0.9,
			Palette.treeTop,
			Palette.flowerPink
		)
	end
	b.block("GateArch", Vector3.new(14.6, 1.4, 1.6), Vector3.new(0, 10.6, 0), Palette.woodDark)
	local sign = b.block("GateSign", Vector3.new(14, 3, 0.4), Vector3.new(0, 12.75, 0), Palette.cream)
	b.block("SignTrim", Vector3.new(14.6, 3.5, 0.3), Vector3.new(0, 12.75, 0), Palette.wood, { shadow = false })
	Kit.gableRoof(b, "GateRoof", Vector3.new(0, 14.6, 0), 15.4, 2.6, 1.3, Palette.roofRed)
	Kit.sproutTag(b, Vector3.new(0, 15.9, 0), 2.5, Palette.wood, Palette.lime)
	return sign
end

return ArtBuildings
