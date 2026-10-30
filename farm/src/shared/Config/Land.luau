--!strict
-- More fields as Population grows, and land expansion, from Design/02 Farming,
-- 07 Town Building and Township Baseline Numbers §2 and §7 (Township baseline).
-- Only what a level-12 farm can reach (Population Cap 390) is listed.

export type Rect = { stage: number, minX: number, minZ: number, maxX: number, maxZ: number }

export type FieldUnlock = { field: number, population: number, xp: number }

export type ExpansionDef = {
	stage: number,
	displayName: string,
	population: number, -- Population needed to start it
	coinCost: number,
	buildSeconds: number,
	xp: number,
}

local MIN = 60

local function fieldRows(list: { { number } }): { FieldUnlock }
	local out = {}
	for _, row in list do
		table.insert(out, table.freeze({ field = row[1], population = row[2], xp = row[3] }))
	end
	return table.freeze(out)
end

local function expansionRows(list: { { any } }): { ExpansionDef }
	local out = {}
	for i, row in list do
		table.insert(
			out,
			table.freeze({
				stage = i,
				displayName = row[1],
				population = row[2],
				coinCost = row[3],
				buildSeconds = row[4],
				xp = row[5],
			})
		)
	end
	return table.freeze(out)
end

return table.freeze({
	-- Fields 7+ are free; each arrives when Population reaches its threshold. XP on placing.
	fields = fieldRows({
		{ 7, 65, 2 },
		{ 8, 70, 3 },
		{ 9, 75, 4 },
		{ 10, 85, 5 },
		{ 11, 95, 6 },
		{ 12, 110, 7 },
		{ 13, 125, 8 },
		{ 14, 145, 10 },
		{ 15, 165, 11 },
		{ 16, 185, 12 },
		{ 17, 210, 13 },
		{ 18, 235, 14 },
		{ 19, 265, 15 },
		{ 20, 295, 16 },
		{ 21, 325, 18 },
		{ 22, 360, 18 },
	}),
	-- Expansions 1-4 (no tools needed until #20 on the Township baseline). The land each one
	-- clears is a greybox choice: West, East, North, then the two north corners.
	expansions = expansionRows({
		{ "West Meadow", 60, 25, 20 * MIN, 4 },
		{ "East Meadow", 75, 30, 25 * MIN, 6 },
		{ "North Fields", 90, 40, 30 * MIN, 8 },
		{ "Far Corners", 105, 50, 35 * MIN, 11 },
	}),
	-- The plot-local rectangles (min, max corner, in studs) each expansion clears: West, East,
	-- North, then both north corners for stage 4. The start area is -48..48 on both axes.
	rects = table.freeze({ -- { Rect }
		table.freeze({ stage = 1, minX = -96, minZ = -48, maxX = -48, maxZ = 48 }),
		table.freeze({ stage = 2, minX = 48, minZ = -48, maxX = 96, maxZ = 48 }),
		table.freeze({ stage = 3, minX = -48, minZ = -96, maxX = 48, maxZ = -48 }),
		table.freeze({ stage = 4, minX = -96, minZ = -96, maxX = -48, maxZ = -48 }),
		table.freeze({ stage = 4, minX = 48, minZ = -96, maxX = 96, maxZ = -48 }),
	}),
	startArea = 48, -- half-size of the start area in studs
	-- Fields up to this number fit in the start area; later ones need this expansion
	startAreaFields = 10,
	extraFieldsStage = 1,
})
