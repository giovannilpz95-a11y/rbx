--!strict
-- Houses, Community Buildings and building materials from Design/07 Town Building and
-- Township Baseline Numbers §7-8 (Township baseline; names are ours). The rows up to level 12,
-- plus the content bank's (Config/Levels.built); later rows arrive with their updates.
-- Houses raise Population; Community Buildings raise the Population Cap.

export type HouseDef = {
	id: string,
	displayName: string,
	population: number,
	coinCost: number,
	buildSeconds: number,
	xp: number,
	copyLevels: { number }, -- the level at which the 1st, 2nd, ... copy unlocks
	order: number,
	color: { number }, -- greybox RGB
}

export type CommunityDef = {
	id: string,
	displayName: string,
	unlockLevel: number,
	capBonus: number,
	coinCost: number,
	materials: { [string]: number }, -- Bricks / Planks / Panes
	buildSeconds: number,
	xp: number,
	order: number, -- also its lot on Main Street
	color: { number },
}

local MIN = 60
local HOUR = 3600

-- stylua: ignore
local Houses: { [string]: HouseDef } = {
	LeanTo = { id = "LeanTo", displayName = "Lean-to Cabin", population = 5, coinCost = 5, buildSeconds = 1 * MIN, xp = 5, copyLevels = { 4, 4, 4, 5 }, order = 1, color = { 190, 150, 110 } },
	Cottage = { id = "Cottage", displayName = "Cottage", population = 10, coinCost = 10, buildSeconds = 10 * MIN, xp = 10, copyLevels = { 1, 5, 6, 7, 8 }, order = 2, color = { 240, 220, 170 } },
	Bungalow = { id = "Bungalow", displayName = "Bungalow", population = 15, coinCost = 15, buildSeconds = 20 * MIN, xp = 15, copyLevels = { 1, 1, 5, 6, 9, 10 }, order = 3, color = { 170, 200, 230 } },
	RowHouse = { id = "RowHouse", displayName = "Row House", population = 20, coinCost = 20, buildSeconds = 30 * MIN, xp = 20, copyLevels = { 1, 7, 11, 12 }, order = 4, color = { 200, 120, 100 } },
	Farmhouse = { id = "Farmhouse", displayName = "Farmhouse", population = 25, coinCost = 25, buildSeconds = 1 * HOUR, xp = 25, copyLevels = { 8, 9, 13, 14 }, order = 5, color = { 230, 230, 220 } },
	Duplex = { id = "Duplex", displayName = "Duplex", population = 30, coinCost = 60, buildSeconds = 1 * HOUR + 30 * MIN, xp = 30, copyLevels = { 10, 11, 15 }, order = 6, color = { 180, 210, 160 } },
	Townhouse = { id = "Townhouse", displayName = "Brick Townhouse", population = 35, coinCost = 105, buildSeconds = 2 * HOUR, xp = 35, copyLevels = { 12, 13, 16, 17 }, order = 7, color = { 170, 90, 70 } },
	-- content bank (level 13+)
	GardenVilla = { id = "GardenVilla", displayName = "Garden Villa", population = 40, coinCost = 160, buildSeconds = 3 * HOUR, xp = 40, copyLevels = { 14, 15, 16, 18 }, order = 8, color = { 215, 210, 195 } },
}

-- stylua: ignore
local Community: { [string]: CommunityDef } = {
	VillageWell = { id = "VillageWell", displayName = "Village Well", unlockLevel = 5, capBonus = 10, coinCost = 25, materials = { Bricks = 1 }, buildSeconds = 2 * MIN, xp = 20, order = 1, color = { 150, 150, 160 } },
	PicnicPavilion = { id = "PicnicPavilion", displayName = "Picnic Pavilion", unlockLevel = 5, capBonus = 20, coinCost = 30, materials = { Bricks = 1, Panes = 1 }, buildSeconds = 10 * MIN, xp = 40, order = 2, color = { 210, 170, 120 } },
	Schoolhouse = { id = "Schoolhouse", displayName = "Schoolhouse", unlockLevel = 6, capBonus = 25, coinCost = 40, materials = { Bricks = 1, Planks = 1, Panes = 1 }, buildSeconds = 20 * MIN, xp = 50, order = 3, color = { 200, 80, 70 } },
	Clinic = { id = "Clinic", displayName = "Clinic", unlockLevel = 7, capBonus = 30, coinCost = 50, materials = { Bricks = 1, Planks = 1, Panes = 2 }, buildSeconds = 30 * MIN, xp = 60, order = 4, color = { 235, 240, 245 } },
	FireHall = { id = "FireHall", displayName = "Fire Hall", unlockLevel = 8, capBonus = 35, coinCost = 75, materials = { Bricks = 2, Planks = 1, Panes = 2 }, buildSeconds = 1 * HOUR, xp = 70, order = 5, color = { 220, 60, 50 } },
	PostOffice = { id = "PostOffice", displayName = "Post Office", unlockLevel = 9, capBonus = 40, coinCost = 100, materials = { Bricks = 1, Planks = 3, Panes = 2 }, buildSeconds = 1 * HOUR + 30 * MIN, xp = 80, order = 6, color = { 90, 120, 200 } },
	TeaRoom = { id = "TeaRoom", displayName = "Tea Room", unlockLevel = 10, capBonus = 45, coinCost = 125, materials = { Bricks = 2, Planks = 2, Panes = 3 }, buildSeconds = 2 * HOUR, xp = 90, order = 7, color = { 230, 180, 200 } },
	Library = { id = "Library", displayName = "Library", unlockLevel = 11, capBonus = 50, coinCost = 150, materials = { Bricks = 3, Planks = 3, Panes = 2 }, buildSeconds = 2 * HOUR + 30 * MIN, xp = 100, order = 8, color = { 140, 100, 70 } },
	Bandstand = { id = "Bandstand", displayName = "Bandstand", unlockLevel = 12, capBonus = 55, coinCost = 175, materials = { Bricks = 4, Planks = 3, Panes = 2 }, buildSeconds = 3 * HOUR, xp = 110, order = 9, color = { 245, 245, 235 } },
	-- content bank (level 13+); from level 15 they stand on North Lane (Shared/Lots)
	ClockTower = { id = "ClockTower", displayName = "Clock Tower", unlockLevel = 13, capBonus = 60, coinCost = 200, materials = { Bricks = 2, Planks = 4, Panes = 4 }, buildSeconds = 3 * HOUR + 30 * MIN, xp = 120, order = 10, color = { 175, 175, 180 } },
	Greenhouse = { id = "Greenhouse", displayName = "Greenhouse", unlockLevel = 14, capBonus = 65, coinCost = 250, materials = { Bricks = 1, Planks = 6, Panes = 4 }, buildSeconds = 4 * HOUR, xp = 130, order = 11, color = { 180, 220, 210 } },
	Bathhouse = { id = "Bathhouse", displayName = "Bathhouse", unlockLevel = 15, capBonus = 70, coinCost = 300, materials = { Bricks = 5, Planks = 5, Panes = 2 }, buildSeconds = 4 * HOUR + 30 * MIN, xp = 140, order = 12, color = { 170, 210, 230 } },
	ArtStudio = { id = "ArtStudio", displayName = "Art Studio", unlockLevel = 16, capBonus = 75, coinCost = 350, materials = { Bricks = 2, Planks = 7, Panes = 4 }, buildSeconds = 5 * HOUR, xp = 150, order = 13, color = { 235, 225, 205 } },
}

for _, def in Houses do
	table.freeze(def.copyLevels)
	table.freeze(def.color)
	table.freeze(def)
end
for _, def in Community do
	table.freeze(def.materials)
	table.freeze(def.color)
	table.freeze(def)
end

return table.freeze({
	houses = table.freeze(Houses),
	community = table.freeze(Community),

	baseCap = 75, -- Township (Wiki Data - Farming & Animals §8.11: Houses always fill the Cap exactly)
	-- Every farm starts with these, already built: Population 60 (Township baseline)
	starterHouses = table.freeze({ "Cottage", "Bungalow", "Bungalow", "RowHouse" }),

	-- Building materials for Community Buildings (Township's three, our names)
	materials = table.freeze({
		Bricks = table.freeze({ displayName = "Bricks", order = 1 }),
		Planks = table.freeze({ displayName = "Planks", order = 2 }),
		Panes = table.freeze({ displayName = "Panes", order = 3 }),
	}),
	materialGemPrice = 8, -- Township baseline
	materialsFromLevel = 5, -- Township baseline
	-- Drops while the Train Station is post-MVP (first-pass, 02 Farming / 07 Town Building)
	harvestDropChance = 0.02, -- per field harvested, times (1 + grow hours * 0.25), at most x3
	orderDropChance = 0.25, -- per Order Board delivery
})
