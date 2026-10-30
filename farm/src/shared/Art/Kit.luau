--!strict
-- The model kit: a small part builder plus the shared pieces (roofs, windows, doors, fences,
-- trees, the Sprout Tag) every model is assembled from. Design/16 Model Catalog §1 and §3.2.
--
-- Everything here is built from Studio Parts in code, so it needs no uploaded assets. The
-- builders take a CFrame for the model's bottom-centre. Inside a model, local -Z is the front
-- (the side that faces the path, like a Roblox CFrame's look direction) and +Y is up.
--
-- Pure: no services, so the Lune tests can build every model and count its parts.

local Palette = require("./Palette")

local Kit = {}

export type PartOpts = {
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?, -- default false: decoration never blocks the avatar
	query: boolean?, -- default: the builder's setting
	shadow: boolean?, -- default: only parts 2 studs or larger cast shadows
}

export type Builder = {
	parent: Instance,
	origin: CFrame,
	query: boolean,
	block: (name: string, size: Vector3, at: CFrame | Vector3, color: Color3, opts: PartOpts?) -> Part,
	ball: (name: string, diameter: number, at: CFrame | Vector3, color: Color3, opts: PartOpts?) -> Part,
	-- A cylinder whose axis runs along the local X axis of `at` (Roblox's convention).
	cyl: (name: string, length: number, diameter: number, at: CFrame | Vector3, color: Color3, opts: PartOpts?) -> Part,
	-- A cylinder standing upright (axis along Y).
	post: (
		name: string,
		height: number,
		diameter: number,
		at: CFrame | Vector3,
		color: Color3,
		opts: PartOpts?
	) -> Part,
	-- A wedge: the slope faces local -Z and up, the tall face is at local +Z.
	wedge: (name: string, size: Vector3, at: CFrame | Vector3, color: Color3, opts: PartOpts?) -> WedgePart,
	-- A new builder for a child container, sharing this one's origin.
	into: (parent: Instance, query: boolean?) -> Builder,
}

local function toCFrame(at: CFrame | Vector3): CFrame
	if typeof(at) == "Vector3" then
		return CFrame.new(at :: Vector3)
	end
	return at :: CFrame
end

local function finish(p: BasePart, b: Builder, name: string, color: Color3, opts: PartOpts?)
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = if opts and opts.material then opts.material else Enum.Material.SmoothPlastic
	p.Color = color
	local transparency = if opts and opts.transparency then opts.transparency else 0
	p.Transparency = transparency
	if transparency > 0 then
		-- Kit.fade keeps see-through parts (glass) see-through
		p:SetAttribute("BaseTransparency", transparency)
	end
	p.CanCollide = if opts and opts.collide ~= nil then opts.collide else false
	p.CanTouch = false
	p.CanQuery = if opts and opts.query ~= nil then opts.query else b.query
	local size = p.Size
	local big = math.max(size.X, size.Y, size.Z) >= 2
	p.CastShadow = if opts and opts.shadow ~= nil then opts.shadow else big
	p.Parent = b.parent
end

function Kit.builder(parent: Instance, origin: CFrame, query: boolean?): Builder
	local b = {} :: Builder
	b.parent = parent
	b.origin = origin
	b.query = query == true

	function b.block(name, size, at, color, opts)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = origin * toCFrame(at)
		finish(p, b, name, color, opts)
		return p
	end

	function b.ball(name, diameter, at, color, opts)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(diameter, diameter, diameter)
		p.CFrame = origin * toCFrame(at)
		finish(p, b, name, color, opts)
		return p
	end

	function b.cyl(name, length, diameter, at, color, opts)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(length, diameter, diameter)
		p.CFrame = origin * toCFrame(at)
		finish(p, b, name, color, opts)
		return p
	end

	function b.post(name, height, diameter, at, color, opts)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(height, diameter, diameter)
		p.CFrame = origin * toCFrame(at) * CFrame.Angles(0, 0, math.rad(90))
		finish(p, b, name, color, opts)
		return p
	end

	function b.wedge(name, size, at, color, opts)
		local p = Instance.new("WedgePart")
		p.Size = size
		p.CFrame = origin * toCFrame(at)
		finish(p, b, name, color, opts)
		return p
	end

	function b.into(child: Instance, childQuery: boolean?): Builder
		return Kit.builder(child, origin, if childQuery == nil then b.query else childQuery)
	end

	return b
end

function Kit.yaw(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

function Kit.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

---------------------------------------------------------------------------------------------
-- Shared pieces
---------------------------------------------------------------------------------------------

-- A gable roof whose ridge runs along the local X of `base`, the centre of the roof's bottom.
-- Two wedges and a ridge cap: 3 parts, plus 2 eave boards when `eave` is given (5 parts).
function Kit.gableRoof(
	b: Builder,
	name: string,
	base: CFrame | Vector3,
	width: number,
	depth: number,
	rise: number,
	color: Color3,
	eave: Color3?
)
	local at = toCFrame(base)
	local half = depth / 2
	b.wedge(name, Vector3.new(width, rise, half), at * CFrame.new(0, rise / 2, -half / 2), color)
	b.wedge(name, Vector3.new(width, rise, half), at * CFrame.new(0, rise / 2, half / 2) * Kit.yaw(180), color)
	b.block(
		name .. "Ridge",
		Vector3.new(width + 0.4, 0.6, 0.9),
		at * CFrame.new(0, rise + 0.05, 0),
		color:Lerp(Color3.new(0, 0, 0), 0.15)
	)
	if eave then
		for _, side in { -1, 1 } do
			b.block(
				name .. "Eave",
				Vector3.new(width + 0.2, 0.5, 0.6),
				at * CFrame.new(0, -0.1, side * (half - 0.3)),
				eave
			)
		end
	end
end

-- A faceted barrel ("half-loaf") roof spanning the local X of `base`, running along its local
-- Z. `base` is the centre of the roof's bottom (where the arch meets the walls). One block per
-- segment.
function Kit.archRoof(
	b: Builder,
	name: string,
	base: CFrame | Vector3,
	span: number,
	length: number,
	rise: number,
	segments: number,
	thickness: number,
	color: Color3
)
	-- Circle through (-span/2, 0), (span/2, 0) and (0, rise)
	local at = toCFrame(base)
	local halfSpan = span / 2
	local radius = (halfSpan * halfSpan + rise * rise) / (2 * rise)
	local centerY = rise - radius
	local startAngle = math.atan2(-centerY, -halfSpan) -- left foot
	local endAngle = math.atan2(-centerY, halfSpan) -- right foot
	-- atan2(y, x) with y = -centerY > 0: left foot is near pi, right foot near 0
	for i = 0, segments - 1 do
		local a0 = startAngle + (endAngle - startAngle) * (i / segments)
		local a1 = startAngle + (endAngle - startAngle) * ((i + 1) / segments)
		local p0 = Vector3.new(radius * math.cos(a0), centerY + radius * math.sin(a0), 0)
		local p1 = Vector3.new(radius * math.cos(a1), centerY + radius * math.sin(a1), 0)
		local mid = (p0 + p1) / 2
		local along = p1 - p0
		local chord = along.Magnitude
		local tilt = math.atan2(along.Y, along.X)
		-- push the slab outward by half its thickness so the inner face follows the arch
		local outward = Vector3.new(mid.X, mid.Y - centerY, 0).Unit * (thickness / 2)
		b.block(
			name,
			Vector3.new(chord + 0.15, thickness, length),
			at * CFrame.new(mid + outward) * CFrame.Angles(0, 0, tilt),
			color
		)
	end
end

-- A window on a wall. `at` is the centre of the opening on the wall's outer face, with its -Z
-- pointing out of the wall. A cream frame and a sky-blue pane, plus a loaf-arch top when
-- `arch` is set (16 §1.2). 2 parts, or 4 with the arch.
function Kit.window(
	b: Builder,
	name: string,
	at: CFrame,
	w: number,
	h: number,
	frame: Color3,
	pane: Color3,
	arch: boolean?
)
	b.block(name .. "Frame", Vector3.new(w + 0.6, h + 0.6, 0.3), at * CFrame.new(0, 0, -0.15), frame)
	b.block(name, Vector3.new(w, h, 0.3), at * CFrame.new(0, 0, -0.25), pane)
	if arch then
		local turn = CFrame.Angles(0, math.rad(90), 0)
		b.cyl(name .. "Frame", 0.3, w + 0.6, at * CFrame.new(0, h / 2, -0.15) * turn, frame)
		b.cyl(name, 0.3, w, at * CFrame.new(0, h / 2, -0.25) * turn, pane)
	end
end

-- A loaf-arch door: the door and its round top in the frame color, like a fanlight. 2 parts.
function Kit.door(b: Builder, name: string, at: CFrame, w: number, h: number, color: Color3, frame: Color3)
	local turn = CFrame.Angles(0, math.rad(90), 0)
	local straight = h - w / 2
	b.block(name, Vector3.new(w, straight, 0.3), at * CFrame.new(0, straight / 2, -0.25), color)
	b.cyl(name .. "Top", 0.3, w, at * CFrame.new(0, straight, -0.25) * turn, frame)
end

-- A post-and-rail fence from `a` to `b2` on the ground (local positions, Y ignored).
-- 2 rails plus `posts` posts (at least 2, at the ends).
function Kit.fence(b: Builder, name: string, a: Vector3, b2: Vector3, height: number, posts: number, color: Color3)
	local flatA = Vector3.new(a.X, 0, a.Z)
	local flatB = Vector3.new(b2.X, 0, b2.Z)
	local run = flatB - flatA
	local length = run.Magnitude
	local facing = CFrame.lookAt(flatA:Lerp(flatB, 0.5), flatB) * Kit.yaw(90)
	for _, frac in { 0.45, 0.85 } do
		b.block(name, Vector3.new(length, 0.35, 0.25), facing * CFrame.new(0, height * frac, 0), color)
	end
	local count = math.max(posts, 2)
	for i = 0, count - 1 do
		local p = flatA:Lerp(flatB, i / (count - 1))
		b.block(
			name .. "Post",
			Vector3.new(0.5, height + 0.2, 0.5),
			CFrame.new(p + Vector3.new(0, (height + 0.2) / 2, 0)),
			color:Lerp(Color3.new(0, 0, 0), 0.12)
		)
	end
end

-- A round, puffy tree: a trunk and two canopy balls. 3 parts.
function Kit.tree(b: Builder, name: string, at: Vector3, scale: number, top: Color3, topDark: Color3, trunk: Color3)
	b.post(name .. "Trunk", 3 * scale, 0.9 * scale, at + Vector3.new(0, 1.5 * scale, 0), trunk)
	b.ball(name, 4.6 * scale, at + Vector3.new(0, 4.6 * scale, 0), top)
	b.ball(name, 3.2 * scale, at + Vector3.new(0.9 * scale, 6.2 * scale, 0.5 * scale), topDark:Lerp(top, 0.4))
	return nil
end

-- A round bush, optionally dotted with a flower. 1 or 2 parts.
function Kit.bush(b: Builder, name: string, at: Vector3, scale: number, color: Color3, flower: Color3?)
	b.ball(name, 2.2 * scale, at + Vector3.new(0, 0.7 * scale, 0), color)
	if flower then
		b.ball(name .. "Flower", 0.7 * scale, at + Vector3.new(0.45 * scale, 1.6 * scale, -0.6 * scale), flower)
	end
end

-- The Sprout Tag (16 §1.7): two lime leaves sprouting from the roof, decoration only.
-- `height` follows the S/M/L/XL sizes (0.6 / 1.2 / 2.5 / 4). 2 parts in a "SproutTag" model.
-- (It lost its stem to the part budget; `_stem` stays so callers don't change.)
function Kit.sproutTag(b: Builder, at: Vector3, height: number, _stem: Color3, leafColor: Color3): Model
	local tag = Kit.model("SproutTag", b.parent)
	local t = b.into(tag, false)
	local leaf = Vector3.new(height * 0.5, height * 0.16, height * 0.3)
	local base = height * 0.12
	t.block(
		"Leaf",
		leaf,
		CFrame.new(at + Vector3.new(-height * 0.2, base + height * 0.1, 0)) * CFrame.Angles(0, 0, math.rad(-28)),
		leafColor,
		{ shadow = false }
	)
	t.block(
		"Leaf",
		leaf,
		CFrame.new(at + Vector3.new(height * 0.2, base + height * 0.18, 0)) * CFrame.Angles(0, 0, math.rad(32)),
		leafColor,
		{ shadow = false }
	)
	return tag
end

-- Construction scaffold (16 §2.4): four honey-wood poles, two planks and the closed seed on
-- top that pops open into the Sprout Tag when the building is done. `w` x `d` x `h` studs,
-- centred on `cf` at ground level. A "Scaffold" model of 7 parts.
function Kit.scaffold(parent: Instance, cf: CFrame, w: number, d: number, h: number): Model
	local m = Kit.model("Scaffold", parent)
	local b = Kit.builder(m, cf, false)
	local hw, hd = w / 2 + 0.4, d / 2 + 0.4
	for _, x in { -hw, hw } do
		for _, z in { -hd, hd } do
			b.block("Pole", Vector3.new(0.4, h, 0.4), Vector3.new(x, h / 2, z), Palette.wood)
		end
	end
	b.block("Plank", Vector3.new(w + 1.4, 0.3, 0.9), Vector3.new(0, h * 0.5, -hd), Palette.woodLight)
	b.block("Plank", Vector3.new(w + 1.4, 0.3, 0.9), Vector3.new(0, h * 0.85, -hd), Palette.woodLight)
	b.ball("Seed", 1.2, Vector3.new(0, h + 0.6, 0), Palette.wood)
	return m
end

---------------------------------------------------------------------------------------------
-- Helpers for scripts that drive models
---------------------------------------------------------------------------------------------

local function eachPart(root: Instance, fn: (BasePart) -> ())
	if root:IsA("BasePart") then
		fn(root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			fn(d)
		end
	end
end
Kit.eachPart = eachPart

-- Fade a model (or part tree) between shown (0) and hidden (1). Glass keeps its own
-- see-through amount, and parts marked Hidden (invisible roots) stay hidden.
function Kit.fade(root: Instance, amount: number, skip: ((BasePart) -> boolean)?)
	eachPart(root, function(p)
		if p:GetAttribute("Hidden") or (skip and skip(p)) then
			return
		end
		local base = (p:GetAttribute("BaseTransparency") :: number?) or 0
		p.Transparency = base + (1 - base) * amount
	end)
end

-- Mark a part as an invisible root (footprint or tap target that the eye shouldn't see).
function Kit.hide(p: BasePart)
	p.Transparency = 1
	p:SetAttribute("Hidden", true)
end

-- Weld every other part under `root` to it and unanchor them, so tweening the root's CFrame
-- moves the whole model (the delivery truck).
function Kit.weld(root: BasePart)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
			d.Anchored = false
			d.Massless = true
		end
	end
end

function Kit.countParts(root: Instance): number
	local n = 0
	eachPart(root, function()
		n += 1
	end)
	return n
end

return Kit
