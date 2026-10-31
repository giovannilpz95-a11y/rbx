--!strict
-- Moving buildings (the free-placement sandbox, decided 2026-10-31: Township lets you place and
-- move everything). Pure rules shared by the server, the client's move ghost and the tests.
--
-- A farm's moved buildings live in its save as `layout[key] = { x, z, r }`: the building's
-- plot-local position and an extra turn (0 / 90 / 180 / 270 degrees) on top of the way it
-- faces by default. Buildings without an entry stand where the farm layout puts them.
-- Keys: "field:F7", "factory:Bakery", "pen:ChickenCoop", "house:<lot>", "community:<id>",
-- "harbor:Harbor".
--
-- Footprints are in plot-local studs at the default facing: width along X, depth along Z,
-- and the footprint's centre offset from the building's position (a factory's output table
-- sticks out on its west side).

local Balance = require("./Config/Balance")
local Isles = require("./Config/Isles")
local Land = require("./Config/Land")
local TownRules = require("./TownRules")

local Layout = {}

export type Spot = { x: number, z: number, r: number }
export type Footprint = { w: number, d: number, ox: number, oz: number }

Layout.KINDS = table.freeze({
	field = table.freeze({ w = 8, d = 8, ox = 0, oz = 0 }),
	factory = table.freeze({ w = 18, d = 10, ox = -3, oz = 0 }),
	pen = table.freeze({ w = 12, d = 12, ox = 0, oz = 0 }),
	house = table.freeze({ w = 8, d = 8, ox = 0, oz = 0 }),
	community = table.freeze({ w = 12, d = 12, ox = 0, oz = 0 }),
	harbor = table.freeze({ w = 24, d = 18, ox = 0, oz = 0 }), -- Art/Harbor WIDTH x DEPTH
}) :: { [string]: Footprint }

Layout.DISPLAY = table.freeze({
	field = "Field",
	factory = "Factory",
	pen = "Pen",
	house = "House",
	community = "Community Building",
	harbor = "Harbor",
})

Layout.GRID = 2 -- positions snap to a 2-stud grid
Layout.PLOT_HALF = 144 -- the plot runs -144..144 on both axes
-- Main Street (the town strip between the start area and the gate) is the farm's own land
Layout.MAIN_STREET = table.freeze({ minX = -96, maxX = 96, minZ = 48, maxZ = 96 })

function Layout.key(kind: string, id: string | number): string
	return kind .. ":" .. tostring(id)
end

function Layout.parse(key: any): (string?, string?)
	if type(key) ~= "string" then
		return nil, nil
	end
	local kind, id = string.match(key, "^(%a+):([%w_]+)$")
	if kind == nil or Layout.KINDS[kind] == nil then
		return nil, nil
	end
	return kind, id
end

function Layout.snap(v: number): number
	return math.floor(v / Layout.GRID + 0.5) * Layout.GRID
end

function Layout.validTurn(r: any): boolean
	return r == 0 or r == 90 or r == 180 or r == 270
end

-- The footprint turned by `r` degrees: its width, depth and centre offset on plot axes
function Layout.footprint(kind: string, r: number): (number, number, number, number)
	local f = Layout.KINDS[kind]
	local turns = (r // 90) % 4
	-- Kit.yaw turns counter-clockwise seen from above: (x, z) -> (z, -x) for each quarter
	local ox, oz = f.ox, f.oz
	for _ = 1, turns do
		ox, oz = oz, -ox
	end
	if turns % 2 == 1 then
		return f.d, f.w, ox, oz
	end
	return f.w, f.d, ox, oz
end

-- Does this farm have this building (so it can be moved)?
function Layout.exists(data: { [string]: any }, kind: string, id: string): boolean
	if kind == "field" then
		return data.fields[id] ~= nil
	elseif kind == "factory" then
		return table.find(Balance.enabledFactories, id) ~= nil and data.factories[id] ~= nil
	elseif kind == "pen" then
		return table.find(Balance.enabledPens, id) ~= nil and data.pens[id] ~= nil
	elseif kind == "house" then
		local lot = tonumber(id)
		for _, house in data.town.houses do
			if house.lot == lot then
				return true
			end
		end
		return false
	elseif kind == "community" then
		return data.town.community[id] ~= nil
	elseif kind == "harbor" then
		-- The old Harbor stands on the farm from its level, repaired or not (Features/F02)
		return id == "Harbor" and data.level >= Isles.unlockLevel
	end
	return false
end

-- Is this plot-local point on land the farm owns: the start area, Main Street or cleared land?
function Layout.owned(data: { [string]: any }, x: number, z: number, now: number): boolean
	local half = Layout.PLOT_HALF
	if math.abs(x) > half or math.abs(z) > half then
		return false
	end
	local s = Land.startArea
	if math.abs(x) <= s and math.abs(z) <= s then
		return true
	end
	local m = Layout.MAIN_STREET
	if x >= m.minX and x <= m.maxX and z >= m.minZ and z <= m.maxZ then
		return true
	end
	for _, rect in Land.rects do
		if x >= rect.minX and x <= rect.maxX and z >= rect.minZ and z <= rect.maxZ then
			if TownRules.landDone(data, rect.stage, now) then
				return true
			end
		end
	end
	return false
end

-- The footprint's plot-local box for a building at (x, z) turned by r: centre and size
function Layout.box(kind: string, x: number, z: number, r: number): (number, number, number, number)
	local w, d, ox, oz = Layout.footprint(kind, r)
	return x + ox, z + oz, w, d
end

-- Is the whole footprint on owned land? Corners, edge midpoints and the centre (footprints are
-- smaller than any land rectangle, so these cover it).
function Layout.onOwnLand(data: { [string]: any }, kind: string, x: number, z: number, r: number, now: number): boolean
	local cx, cz, w, d = Layout.box(kind, x, z, r)
	for _, fx in { -0.5, 0, 0.5 } do
		for _, fz in { -0.5, 0, 0.5 } do
			if not Layout.owned(data, cx + fx * (w - 0.2), cz + fz * (d - 0.2), now) then
				return false
			end
		end
	end
	return true
end

-- Everything but the physical check against what's already standing there. Returns false and
-- a reason.
function Layout.canMove(data: { [string]: any }, key: any, x: any, z: any, r: any, now: number): (boolean, string?)
	local kind, id = Layout.parse(key)
	if kind == nil or id == nil or not Layout.exists(data, kind, id) then
		return false, "That can't be moved"
	elseif type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z or math.abs(x) == math.huge then
		return false, "That's not a spot on your farm"
	elseif x % Layout.GRID ~= 0 or z % Layout.GRID ~= 0 then
		return false, string.format("Spots snap to a %d-stud grid", Layout.GRID)
	elseif not Layout.validTurn(r) then
		return false, "Buildings turn a quarter at a time"
	elseif not Layout.onOwnLand(data, kind, x, z, r, now) then
		return false, "That's not on your land. Clear more land to build there"
	end
	return true
end

-- Is anything standing in the footprint of a `kind` building at (x, z) turned by r, on the plot
-- `plot` whose plot-local space is `origin`? The one physical check, shared by the server and the
-- client's ghost so they always agree. Skips `except` (the building being moved), locked land
-- (the land check's job) and a finished scaffold on its way out. With `buildingsOnly`, only
-- other buildings and placed decorations count (not trees, guides or props).
-- Roblox only (it queries the workspace).
function Layout.blocked(
	plot: Instance,
	origin: CFrame,
	kind: string,
	x: number,
	z: number,
	r: number,
	except: Instance?,
	buildingsOnly: boolean?
): boolean
	local cx, cz, w, d = Layout.box(kind, x, z, r)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plot }
	-- From just above flat ground (paths, floors) to head height
	local box = origin * CFrame.new(cx, 3.3, cz)
	local workspace = game:GetService("Workspace")
	for _, hit in workspace:GetPartBoundsInBox(box, Vector3.new(w - 0.4, 5.4, d - 0.4), params) do
		if except and (hit == except or hit:IsDescendantOf(except)) then
			continue
		end
		if hit:FindFirstAncestor("Land") or hit:FindFirstAncestor("ScaffoldPop") then
			continue
		end
		if buildingsOnly then
			local node: Instance? = hit
			local counts = hit:FindFirstAncestor("Placed") ~= nil
			while node and node ~= plot and not counts do
				counts = node:GetAttribute("LayoutKey") ~= nil
				node = node.Parent
			end
			if not counts then
				continue
			end
		end
		return true
	end
	return false
end

function Layout.spot(data: { [string]: any }, key: string): Spot?
	local layout = data.layout
	return layout and layout[key] or nil
end

return Layout
