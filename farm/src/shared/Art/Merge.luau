--!strict
-- Runtime part merging (the part-cut pass, so levels 20-30 fit the 2,500-part plot budget). A
-- finished town building or a placed decoration never moves, so the server unions its parts
-- into one PartOperation with GeometryService:UnionAsync. Each part keeps its own color
-- (UsePartColor off). Parts that need something a union can't keep stay separate: see-through
-- or non-plastic parts (glass, Neon lamps), parts that swing (HingeCFrame), hidden roots, and
-- parts carrying children (smoke, sparkles, SurfaceGui signs). Nothing is uploaded: the union
-- is made fresh each time the model is built, and if it fails the parts simply stay.

local Merge = {}

export type Geometry = {
	UnionAsync: (self: any, part: BasePart, parts: { BasePart }, options: { [string]: any }?) -> { BasePart },
}

export type Options = {
	collide: boolean?, -- the union's CanCollide (default: the primary part's)
	query: boolean?, -- the union's CanQuery (default true: taps and the camera see it)
	name: string?, -- the union's name (default: the primary part's)
	skip: { [string]: boolean }?, -- names (of a part or anything it sits under) left out
}

-- Whatever sits in these is never merged: scaffolds come and go, and the pop sinks away
local ALWAYS_SKIP = { Scaffold = true, ScaffoldPop = true }

local function skipped(d: Instance, container: Instance, skip: { [string]: boolean }?): boolean
	local at: Instance? = d
	while at and at ~= container do
		if ALWAYS_SKIP[at.Name] or (skip and skip[at.Name]) then
			return true
		end
		at = at.Parent
	end
	return false
end

-- Whether `p` has to stay a part of its own rather than join a union.
function Merge.keepsSeparate(p: BasePart): boolean
	if p.Transparency > 0 or p.Material ~= Enum.Material.SmoothPlastic then
		return true
	end
	if p:GetAttribute("HingeCFrame") ~= nil or p:GetAttribute("Hidden") ~= nil then
		return true
	end
	if not (p:IsA("Part") or p:IsA("WedgePart")) then
		return true -- unions take plain parts and wedges only
	end
	-- Parts and models hanging under a part (a builder's tree) don't hold it back; anything
	-- else does (smoke, sparkles, a SurfaceGui sign)
	for _, child in p:GetChildren() do
		if not (child:IsA("BasePart") or child:IsA("Model")) then
			return true
		end
	end
	return false
end

-- The parts under `container` that would join `primary` in a union (`merge`, never including
-- primary) and those that stay separate (`keep`). Anything inside a scaffold, or named in
-- `skip` (or inside something that is), is left out of both.
function Merge.split(container: Instance, primary: BasePart, skip: { [string]: boolean }?): ({ BasePart }, { BasePart })
	local merge, keep = {}, {}
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and d ~= primary and not skipped(d, container, skip) then
			if Merge.keepsSeparate(d) then
				table.insert(keep, d)
			else
				table.insert(merge, d)
			end
		end
	end
	return merge, keep
end

-- How many parts are under `container`.
function Merge.parts(container: Instance): number
	local total = 0
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			total += 1
		end
	end
	return total
end

-- How many parts `container` comes to once merged around `primary`: everything but the parts
-- that join the union (which takes primary's place). Used by the plot-estimate test.
function Merge.count(container: Instance, primary: BasePart, skip: { [string]: boolean }?): number
	local merge = Merge.split(container, primary, skip)
	return Merge.parts(container) - #merge
end

local function geometryService(): Geometry?
	local ok, service = pcall(function()
		return (game :: any):GetService("GeometryService")
	end)
	return if ok then service else nil
end

-- Unions every mergeable part under `container` into `primary`'s place and returns the union,
-- or `primary` unchanged when there's nothing to merge or the union fails. Yields while the
-- union is made; if `container` was taken out of the world meanwhile (rebuilt), the result is
-- thrown away. The union takes over `primary`'s name and attributes (Interact), and any
-- BillboardGui on `primary` (its label) stays where it was through a "BodyAnchor" attachment.
function Merge.merge(container: Instance, primary: BasePart, options: Options?, geometry: Geometry?): BasePart
	for _, child in primary:GetChildren() do
		if not (child:IsA("BillboardGui") or child:IsA("BasePart") or child:IsA("Model")) then
			return primary -- something we can't carry over: leave it as it is
		end
	end
	if primary.Transparency > 0 or primary.Material ~= Enum.Material.SmoothPlastic then
		return primary
	end
	local merge = Merge.split(container, primary, options and options.skip)
	if #merge == 0 then
		return primary
	end
	local service = geometry or geometryService()
	if service == nil then
		return primary
	end
	local ok, result = pcall(function()
		return service:UnionAsync(primary, merge, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
			SplitApart = false,
		})
	end)
	local union = if ok and type(result) == "table" then result[1] else nil
	if union == nil then
		return primary
	end
	if container.Parent == nil or primary.Parent == nil then
		for _, p in result :: { BasePart } do
			p:Destroy()
		end
		return primary
	end
	union.Name = if options and options.name then options.name else primary.Name
	union.Anchored = true
	union.CanCollide = if options and options.collide ~= nil then options.collide else primary.CanCollide
	union.CanTouch = false
	union.CanQuery = if options and options.query ~= nil then options.query else true
	union.CastShadow = true
	if union:IsA("PartOperation") then
		(union :: PartOperation).UsePartColor = false
	end
	-- The CollisionFidelity option doesn't always take (Studio showed Hull), so ask again; where
	-- the property can't be written from a game script the union simply keeps Hull
	pcall(function()
		(union :: any).CollisionFidelity = Enum.CollisionFidelity.Box
	end)
	for name, value in primary:GetAttributes() do
		union:SetAttribute(name, value)
	end
	union:SetAttribute("Merged", #merge + 1)
	local anchor: Attachment? = nil
	for _, gui in primary:GetChildren() do
		if gui:IsA("BillboardGui") then
			if anchor == nil then
				local a = Instance.new("Attachment")
				a.Name = "BodyAnchor"
				a.CFrame = union.CFrame:ToObjectSpace(primary.CFrame)
				a.Parent = union
				anchor = a
			end
			gui.Adornee = anchor
			gui.Parent = union
		end
	end
	local home = primary.Parent :: Instance
	if home ~= container and home:IsA("BasePart") then
		home = container -- never under a part that's about to go
	end
	union.Parent = home
	-- Whatever hangs under a part that's about to go (separate parts, skipped ones and their
	-- models) moves to the union
	local going: { [Instance]: boolean } = { [primary] = true }
	for _, p in merge do
		going[p] = true
	end
	for p in going do
		for _, child in p:GetChildren() do
			if not going[child] then
				child.Parent = union
			end
		end
	end
	for _, p in merge do
		p:Destroy()
	end
	primary:Destroy()
	return union
end

-- Merges the look of a decoration whose visible parts hang under an invisible tap `root`
-- (Util/DecorModels): the biggest mergeable part leads, and the union collides if any of its
-- parts did. The union ("Look") stays under `root`, so a tap on it still finds the root.
function Merge.mergeUnder(root: BasePart, geometry: Geometry?): BasePart?
	local primary: BasePart? = nil
	local volume = 0
	local collide = false
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and not Merge.keepsSeparate(d) then
			collide = collide or d.CanCollide
			local size = d.Size
			if size.X * size.Y * size.Z > volume then
				primary, volume = d, size.X * size.Y * size.Z
			end
		end
	end
	if primary == nil then
		return nil
	end
	return Merge.merge(root, primary, { collide = collide, name = "Look" }, geometry)
end

-- The biggest part under `container` that could lead a merge, leaving out `skip` and, unless
-- `colliding`, parts that collide (so a walk-through shell keeps its solid parts as they are).
function Merge.leader(container: Instance, skip: { [string]: boolean }?, colliding: boolean?): BasePart?
	local best: BasePart? = nil
	local volume = 0
	for _, d in container:GetDescendants() do
		if
			d:IsA("BasePart")
			and not Merge.keepsSeparate(d)
			and (colliding or not d.CanCollide)
			and not skipped(d, container, skip)
		then
			local size = d.Size
			if size.X * size.Y * size.Z > volume then
				best, volume = d, size.X * size.Y * size.Z
			end
		end
	end
	return best
end

local function shellSkip(pen: Instance, skip: { [string]: boolean }): { [string]: boolean }
	local all = table.clone(skip)
	-- Colliding parts stay as they are: a union of them would collide as one hull
	for _, d in pen:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			all[d.Name] = true
		end
	end
	return all
end

-- Merges the fences and buildings of an animal pen (Art/Animals) into one walk-through,
-- tap-through "Shell", leaving out `skip` (the tap floor, the animals and products, the feed
-- and crate lid that change) and every part that collides (the Floor, the coop's house).
function Merge.mergeShell(pen: Instance, skip: { [string]: boolean }, geometry: Geometry?): BasePart?
	local all = shellSkip(pen, skip)
	local primary = Merge.leader(pen, all)
	if primary == nil then
		return nil
	end
	return Merge.merge(pen, primary, { collide = false, query = false, name = "Shell", skip = all }, geometry)
end

-- How many parts a pen comes to once its shell is merged (for the plot-estimate test).
function Merge.countShell(pen: Instance, skip: { [string]: boolean }): number
	local all = shellSkip(pen, skip)
	local primary = Merge.leader(pen, all)
	if primary == nil then
		return Merge.parts(pen)
	end
	return Merge.count(pen, primary, all)
end

return Merge
