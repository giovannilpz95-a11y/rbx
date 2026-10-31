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
	order: number, -- unlock order; also picks its lot (TownRules.communityLot)
	color: { number },
	townHallStorey: number?, -- a Town Hall upgrade: no lot, it gives the Town Hall this storey
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
	ThatchedLonghouse = { id = "ThatchedLonghouse", displayName = "Thatched Longhouse", population = 45, coinCost = 225, buildSeconds = 4 * HOUR, xp = 45, copyLevels = { 17, 18, 19, 19, 20 }, order = 9, color = { 205, 180, 130 } },
	CornerFlats = { id = "CornerFlats", displayName = "Corner Flats", population = 50, coinCost = 300, buildSeconds = 6 * HOUR, xp = 50, copyLevels = { 20, 21, 21, 22 }, order = 10, color = { 225, 170, 120 } },
	LakesideManor = { id = "LakesideManor", displayName = "Lakeside Manor", population = 55, coinCost = 385, buildSeconds = 7 * HOUR, xp = 55, copyLevels = { 22, 23, 23, 24 }, order = 11, color = { 200, 220, 235 } },
	HearthHouse = { id = "HearthHouse", displayName = "Hearth House", population = 60, coinCost = 540, buildSeconds = 8 * HOUR, xp = 60, copyLevels = { 24, 25, 25, 26 }, order = 12, color = { 235, 225, 200 } },
	TwinGables = { id = "TwinGables", displayName = "Twin Gables", population = 65, coinCost = 715, buildSeconds = 9 * HOUR, xp = 65, copyLevels = { 26, 27, 27, 28, 29 }, order = 13, color = { 240, 215, 150 } },
	GardenCoop = { id = "GardenCoop", displayName = "Garden Co-op", population = 100, coinCost = 3000, buildSeconds = 22 * HOUR, xp = 100, copyLevels = { 37, 38, 45, 47, 58 }, order = 19, color = { 170, 200, 150 } },
	CourtyardFlats = { id = "CourtyardFlats", displayName = "Courtyard Flats", population = 90, coinCost = 2250, buildSeconds = 20 * HOUR, xp = 90, copyLevels = { 34, 35, 36, 41, 43, 46 }, order = 18, color = { 215, 185, 150 } },
	Condos = { id = "Condos", displayName = "Terrace Condos", population = 85, coinCost = 1700, buildSeconds = 18 * HOUR, xp = 85, copyLevels = { 32, 33, 36, 38, 40, 42 }, order = 17, color = { 150, 175, 200 } },
	IvyApartments = { id = "IvyApartments", displayName = "Ivy Apartments", population = 80, coinCost = 1440, buildSeconds = 16 * HOUR, xp = 80, copyLevels = { 31, 35, 37, 39, 90 }, order = 16, color = { 200, 175, 140 } },
	BrickTownhouse = { id = "BrickTownhouse", displayName = "Brick Townhouse", population = 75, coinCost = 1200, buildSeconds = 12 * HOUR, xp = 75, copyLevels = { 29, 30, 33, 34, 44 }, order = 15, color = { 160, 70, 60 } },
	CanalHouse = { id = "CanalHouse", displayName = "Canal House", population = 70, coinCost = 910, buildSeconds = 10 * HOUR, xp = 70, copyLevels = { 28, 30, 31, 32 }, order = 14, color = { 175, 95, 75 } },
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
	MusicHall = { id = "MusicHall", displayName = "Music Hall", unlockLevel = 17, capBonus = 80, coinCost = 400, materials = { Bricks = 5, Planks = 4, Panes = 5 }, buildSeconds = 5 * HOUR + 30 * MIN, xp = 160, order = 14, color = { 120, 70, 110 } },
	StargazingTower = { id = "StargazingTower", displayName = "Stargazing Tower", unlockLevel = 18, capBonus = 85, coinCost = 450, materials = { Bricks = 4, Planks = 7, Panes = 7 }, buildSeconds = 6 * HOUR, xp = 170, order = 15, color = { 70, 80, 140 } },
	RoseGarden = { id = "RoseGarden", displayName = "Rose Garden", unlockLevel = 19, capBonus = 90, coinCost = 500, materials = { Bricks = 5, Planks = 7, Panes = 4 }, buildSeconds = 6 * HOUR + 30 * MIN, xp = 180, order = 16, color = { 230, 120, 140 } },
	TownHallUpgrade = { id = "TownHallUpgrade", displayName = "Town Hall Upgrade", unlockLevel = 20, capBonus = 95, coinCost = 650, materials = { Bricks = 6, Planks = 6, Panes = 5 }, buildSeconds = 7 * HOUR, xp = 190, order = 17, color = { 235, 220, 190 }, townHallStorey = 2 },
	SeedExchange = { id = "SeedExchange", displayName = "Seed Exchange", unlockLevel = 21, capBonus = 100, coinCost = 800, materials = { Bricks = 5, Planks = 7, Panes = 6 }, buildSeconds = 7 * HOUR + 30 * MIN, xp = 200, order = 18, color = { 160, 200, 110 } },
	PuppetTheatre = { id = "PuppetTheatre", displayName = "Puppet Theatre", unlockLevel = 22, capBonus = 105, coinCost = 950, materials = { Bricks = 5, Planks = 6, Panes = 8 }, buildSeconds = 8 * HOUR, xp = 210, order = 19, color = { 180, 50, 60 } },
	BotanicalArch = { id = "BotanicalArch", displayName = "Botanical Arch", unlockLevel = 23, capBonus = 110, coinCost = 1100, materials = { Bricks = 5, Planks = 10, Panes = 6 }, buildSeconds = 9 * HOUR, xp = 220, order = 20, color = { 120, 180, 120 } },
	Amphitheatre = { id = "Amphitheatre", displayName = "Amphitheatre", unlockLevel = 24, capBonus = 115, coinCost = 1350, materials = { Bricks = 6, Planks = 7, Panes = 10 }, buildSeconds = 10 * HOUR, xp = 230, order = 21, color = { 215, 200, 175 } },
	SculpturePark = { id = "SculpturePark", displayName = "Sculpture Park", unlockLevel = 25, capBonus = 120, coinCost = 1600, materials = { Bricks = 7, Planks = 10, Panes = 8 }, buildSeconds = 11 * HOUR, xp = 240, order = 22, color = { 190, 210, 170 } },
	BigTop = { id = "BigTop", displayName = "Big Top", unlockLevel = 26, capBonus = 125, coinCost = 1900, materials = { Bricks = 8, Planks = 7, Panes = 12 }, buildSeconds = 12 * HOUR, xp = 250, order = 23, color = { 220, 70, 70 } },
	BusDepot = { id = "BusDepot", displayName = "Bus Depot", unlockLevel = 27, capBonus = 130, coinCost = 2200, materials = { Bricks = 6, Planks = 9, Panes = 14 }, buildSeconds = 13 * HOUR, xp = 260, order = 24, color = { 240, 200, 80 } },
	PetParlor = { id = "PetParlor", displayName = "Pet Parlor", unlockLevel = 38, capBonus = 185, coinCost = 7900, materials = { Bricks = 14, Planks = 18, Panes = 19 }, buildSeconds = 24 * HOUR, xp = 370, order = 35, color = { 240, 170, 190 } },
	SportsArena = { id = "SportsArena", displayName = "Sports Arena", unlockLevel = 37, capBonus = 180, coinCost = 7200, materials = { Bricks = 11, Planks = 20, Panes = 18 }, buildSeconds = 23 * HOUR, xp = 360, order = 34, color = { 120, 180, 110 } },
	LoopCoaster = { id = "LoopCoaster", displayName = "Loop Coaster", unlockLevel = 36, capBonus = 175, coinCost = 6500, materials = { Bricks = 10, Planks = 24, Panes = 13 }, buildSeconds = 22 * HOUR, xp = 350, order = 33, color = { 90, 170, 230 } },
	SkyWheel = { id = "SkyWheel", displayName = "Sky Wheel", unlockLevel = 35, capBonus = 170, coinCost = 5900, materials = { Bricks = 18, Planks = 16, Panes = 11 }, buildSeconds = 21 * HOUR, xp = 340, order = 32, color = { 240, 120, 160 } },
	SignalTower = { id = "SignalTower", displayName = "Signal Tower", unlockLevel = 34, capBonus = 165, coinCost = 5300, materials = { Bricks = 13, Planks = 14, Panes = 16 }, buildSeconds = 20 * HOUR, xp = 330, order = 31, color = { 210, 80, 70 } },
	BroadcastStudio = { id = "BroadcastStudio", displayName = "Broadcast Studio", unlockLevel = 33, capBonus = 160, coinCost = 4800, materials = { Bricks = 10, Planks = 14, Panes = 17 }, buildSeconds = 19 * HOUR, xp = 320, order = 30, color = { 90, 110, 150 } },
	GrandHotel = { id = "GrandHotel", displayName = "Grand Hotel", unlockLevel = 32, capBonus = 155, coinCost = 4300, materials = { Bricks = 13, Planks = 15, Panes = 11 }, buildSeconds = 18 * HOUR, xp = 310, order = 29, color = { 200, 60, 70 } },
	OfficeBlock = { id = "OfficeBlock", displayName = "Office Block", unlockLevel = 31, capBonus = 150, coinCost = 3800, materials = { Bricks = 12, Planks = 13, Panes = 12 }, buildSeconds = 17 * HOUR, xp = 300, order = 28, color = { 130, 160, 190 } },
	OpenAirCinema = { id = "OpenAirCinema", displayName = "Open-Air Cinema", unlockLevel = 30, capBonus = 145, coinCost = 3300, materials = { Bricks = 16, Planks = 9, Panes = 10 }, buildSeconds = 16 * HOUR, xp = 290, order = 27, color = { 70, 80, 120 } },
	CabStand = { id = "CabStand", displayName = "Cab Stand", unlockLevel = 29, capBonus = 140, coinCost = 2900, materials = { Bricks = 11, Planks = 9, Panes = 13 }, buildSeconds = 15 * HOUR, xp = 280, order = 26, color = { 245, 200, 50 } },
	FillingStation = { id = "FillingStation", displayName = "Filling Station", unlockLevel = 28, capBonus = 135, coinCost = 2500, materials = { Bricks = 12, Planks = 10, Panes = 9 }, buildSeconds = 14 * HOUR, xp = 270, order = 25, color = { 230, 90, 70 } },
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
