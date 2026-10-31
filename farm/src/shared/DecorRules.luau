--!strict
-- Decoration placement rules (Design/07 Town Building), pure for the server, the client's
-- placement ghost and the Lune tests. Saved as data.decor = { { id, x, z, r } }: the
-- plot-local centre in studs and quarter turns (0-3). Decorations snap to the 4-stud grid,
-- stay inside the start area or cleared land, and never overlap each other. (Buildings and
-- fields are checked against the real parts on the server, so model sizes can change.)

local Decor = require("./Config/Decor")
local Land = require("./Config/Land")
local Trophies = require("./Config/Trophies")
local TownRules = require("./TownRules")

local DecorRules = {}

export type Placed = { id: string, x: number, z: number, r: number }

-- Gold Town Record trophies (Config/Trophies) place like decorations but are never bought:
-- they cost nothing, give no XP and go back into storage instead of being sold.
local trophyDefs: { [string]: any } = {}
for _, trophy in Trophies.byRecord do
	trophyDefs[trophy.id] = table.freeze({
		id = trophy.id,
		displayName = trophy.displayName,
		size = trophy.size,
		category = "Trophy",
		coinCost = 0,
		xp = 0,
		unlockLevel = 0,
		trophy = true,
	})
end

-- A shop decoration's def, or a trophy's in the same shape; nil for anything else
function DecorRules.def(id: string): any
	return Decor.items[id] or trophyDefs[id]
end

function DecorRules.isTrophy(id: string): boolean
	return trophyDefs[id] ~= nil
end

-- Footprint in tiles after rotation.
function DecorRules.footprint(id: string, r: number): (number, number)
	local size = DecorRules.def(id).size
	if r % 2 == 1 then
		return size[2], size[1]
	end
	return size[1], size[2]
end

-- Snap a wanted centre to the grid for this footprint.
function DecorRules.snap(id: string, r: number, x: number, z: number): (number, number)
	local w, d = DecorRules.footprint(id, r)
	local t = Decor.tile
	local minX = math.floor((x - w * t / 2) / t + 0.5) * t
	local minZ = math.floor((z - d * t / 2) / t + 0.5) * t
	return minX + w * t / 2, minZ + d * t / 2
end

local function bounds(p: Placed): (number, number, number, number)
	local w, d = DecorRules.footprint(p.id, p.r)
	local hw, hd = w * Decor.tile / 2, d * Decor.tile / 2
	return p.x - hw, p.z - hd, p.x + hw, p.z + hd
end

-- Is the whole footprint on land the farm owns (start area or cleared expansions)?
function DecorRules.onOwnLand(data: { [string]: any }, p: Placed, now: number): boolean
	local minX, minZ, maxX, maxZ = bounds(p)
	local half = Land.startArea
	if minX >= -half and maxX <= half and minZ >= -half and maxZ <= half then
		return true
	end
	-- Spanning the start area and cleared land counts too: every corner must be owned
	local function owned(x: number, z: number): boolean
		if math.abs(x) <= half and math.abs(z) <= half then
			return true
		end
		for _, rect in Land.rects do
			if
				TownRules.landDone(data, rect.stage, now)
				and x >= rect.minX
				and x <= rect.maxX
				and z >= rect.minZ
				and z <= rect.maxZ
			then
				return true
			end
		end
		return false
	end
	-- Footprints are at most 3 tiles, so corners plus the centre cover the area
	return owned(minX, minZ) and owned(maxX, minZ) and owned(minX, maxZ) and owned(maxX, maxZ) and owned(p.x, p.z)
end

-- Does p overlap another placed decoration (ignoring index `skip`)?
function DecorRules.overlaps(placed: { Placed }, p: Placed, skip: number?): boolean
	local aMinX, aMinZ, aMaxX, aMaxZ = bounds(p)
	for i, other in placed do
		if i ~= skip then
			local bMinX, bMinZ, bMaxX, bMaxZ = bounds(other)
			if aMinX < bMaxX and bMinX < aMaxX and aMinZ < bMaxZ and bMinZ < aMaxZ then
				return true
			end
		end
	end
	return false
end

-- Everything but the physical check against buildings. Returns false and a reason.
function DecorRules.canPlace(data: { [string]: any }, p: Placed, now: number, skip: number?): (boolean, string?)
	local def = DecorRules.def(p.id)
	if def == nil then
		return false, nil
	end
	if not DecorRules.onOwnLand(data, p, now) then
		return false, "Place it on your own land"
	end
	if DecorRules.overlaps(data.decor, p, skip) then
		return false, "Something is already there"
	end
	return true, nil
end

-- Big pieces (2 x 2 tiles and up) have their own, smaller cap
function DecorRules.isBig(id: string): boolean
	local size = DecorRules.def(id).size
	return size[1] * size[2] >= Decor.bigTiles
end

-- Room on the plot for one more of this decoration?
function DecorRules.hasRoom(data: { [string]: any }, id: string): (boolean, string?)
	if #data.decor >= Decor.maxPlaced then
		return false, string.format("Your plot holds up to %d decorations. Sell one to make room.", Decor.maxPlaced)
	end
	if DecorRules.isBig(id) then
		local big = 0
		for _, p in data.decor do
			if DecorRules.isBig(p.id) then
				big += 1
			end
		end
		if big >= Decor.maxBig then
			return false,
				string.format("Your plot holds up to %d big decorations. Sell one to make room.", Decor.maxBig)
		end
	end
	return true
end

function DecorRules.refund(id: string): number
	return math.floor(DecorRules.def(id).coinCost * Decor.sellRefund)
end

return DecorRules
