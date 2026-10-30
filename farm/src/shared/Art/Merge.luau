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
	name: string?, -- the union's name (default: the primary part's)
}

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
-- primary) and those that stay separate (`keep`). Anything inside a "Scaffold" is skipped.
function Merge.split(container: Instance, primary: BasePart): ({ BasePart }, { BasePart })
	local merge, keep = {}, {}
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and d ~= primary and d:FindFirstAncestor("Scaffold") == nil then
			if Merge.keepsSeparate(d) then
				table.insert(keep, d)
			else
				table.insert(merge, d)
			end
		end
	end
	return merge, keep
end

-- How many parts `container` comes to once merged around `primary`: the union plus the parts
-- that stay separate. Used by the plot-estimate test.
function Merge.count(container: Instance, primary: BasePart): number
	local _, keep = Merge.split(container, primary)
	return 1 + #keep
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
	local merge, keep = Merge.split(container, primary)
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
	union.CanQuery = true
	union.CastShadow = true
	if union:IsA("PartOperation") then
		(union :: PartOperation).UsePartColor = false
	end
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
	-- Separate parts hanging under a part that's about to go move to the union
	local going: { [Instance]: boolean } = { [primary] = true }
	for _, p in merge do
		going[p] = true
	end
	for _, p in keep do
		local up = p.Parent
		while up and up ~= container do
			if going[up] then
				p.Parent = union
				break
			end
			up = up.Parent
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

return Merge
