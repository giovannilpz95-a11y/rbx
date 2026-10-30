--!strict
-- Lots for Houses and Community Buildings, in plot-local studs (+Z is south, toward the gate;
-- Design/07 Town Building). Main Street, between the gate and the Ring Road, holds the
-- level 1-14 town. North Lane, in the North Fields (land expansion 3), takes the content
-- bank's buildings once Main Street is full. Houses take the first free lot; a Community
-- Building stands on the lot of its `order`.
-- Each lot says which way its front faces (yaw 0 = local -Z) and which land expansion it
-- needs (0 = none). Plain numbers so the shared rules and tests can use them outside Roblox.

export type Lot = { x: number, z: number, yaw: number, land: number }

local Lots = {}

Lots.northLaneLand = 3 -- the North Fields
Lots.northLane = table.freeze({ z = -73, linkX = 12 }) -- the lane, and the road up to it

local houses: { Lot } = {}
local community: { Lot } = {}

-- Main Street: two back-to-back rows of 8 x 8 House lots, the street, and a row of 12 x 12
-- Community Building lots. Lots nearest the gate road come first; the truck's lane
-- (x 20..34) stays clear. The row nearest the gate faces it; the row behind faces the street.
for step = 1, 9 do
	local x = step * 10
	for _, side in { -1, 1 } do
		if side == 1 and (x == 20 or x == 30) then
			continue
		end
		table.insert(houses, table.freeze({ x = side * x, z = 54, yaw = 0, land = 0 }))
		table.insert(houses, table.freeze({ x = side * x, z = 64, yaw = 180, land = 0 }))
	end
end
for step = 1, 6 do
	local x = 13 + (step - 1) * 15
	for _, side in { -1, 1 } do
		if side == 1 and x == 28 then
			continue
		end
		table.insert(community, table.freeze({ x = side * x, z = 86, yaw = 0, land = 0 }))
	end
end
Lots.mainStreetHouses = #houses
Lots.mainStreetCommunity = #community

-- North Lane (z -73) with its link road at x 12 from the start area. House rows sit back to
-- back between the start area and the lane (the row on the lane faces it); Community lots sit
-- across the lane, facing it. Lots nearest the link road come first; the road stays clear.
local LAND = Lots.northLaneLand
for _, x in { 0, 24, -10, 34, -20, 44, -30, -40 } do
	table.insert(houses, table.freeze({ x = x, z = -64, yaw = 0, land = LAND }))
	table.insert(houses, table.freeze({ x = x, z = -54, yaw = 180, land = LAND }))
end
for _, x in { 6, 21, -9, 36, -24, -39 } do
	table.insert(community, table.freeze({ x = x, z = -86, yaw = 180, land = LAND }))
end

Lots.houses = table.freeze(houses)
Lots.community = table.freeze(community)

return table.freeze(Lots)
