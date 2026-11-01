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
	materials: { [string]: number }, -- Bricks / Planks / Panes, and from level 60 power tools (Config/ToolTrader)
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
	SkyGardenTower = { id = "SkyGardenTower", displayName = "Sky Garden Tower", population = 110, coinCost = 3850, buildSeconds = 24 * HOUR, xp = 110, copyLevels = { 39, 40, 41, 48, 62, 106 }, order = 20, color = { 200, 215, 225 } },
	SkylineFlats = { id = "SkylineFlats", displayName = "Skyline Flats", population = 120, coinCost = 4800, buildSeconds = 26 * HOUR, xp = 120, copyLevels = { 42, 43, 45, 49, 50, 52, 54, 56, 59 }, order = 21, color = { 210, 200, 190 } },
	AtticTower = { id = "AtticTower", displayName = "Attic Tower", population = 140, coinCost = 6300, buildSeconds = 28 * HOUR, xp = 140, copyLevels = { 44, 46, 47, 48, 49, 51, 53, 55, 57, 60 }, order = 22, color = { 190, 205, 220 } },
	SunburstFlats = { id = "SunburstFlats", displayName = "Sunburst Flats", population = 150, coinCost = 7500, buildSeconds = 30 * HOUR, xp = 150, copyLevels = { 50, 51, 64, 84, 110, 136 }, order = 23, color = { 250, 215, 120 } },
	TiledTower = { id = "TiledTower", displayName = "Tiled Tower", population = 190, coinCost = 9500, buildSeconds = 32 * HOUR, xp = 190, copyLevels = { 52, 53, 66, 68, 86, 100, 104 }, order = 24, color = { 180, 120, 100 } },
	CourtyardBlock = { id = "CourtyardBlock", displayName = "Courtyard Block", population = 230, coinCost = 11500, buildSeconds = 33 * HOUR, xp = 230, copyLevels = { 54, 55, 70, 72, 106, 130, 132 }, order = 25, color = { 200, 190, 170 } },
	GlassTower = { id = "GlassTower", displayName = "Glass Tower", population = 270, coinCost = 13500, buildSeconds = 34 * HOUR, xp = 270, copyLevels = { 56, 57, 74, 88, 96, 120, 130 }, order = 26, color = { 150, 200, 230 } },
	HeritageRow = { id = "HeritageRow", displayName = "Heritage Row", population = 330, coinCost = 16500, buildSeconds = 35 * HOUR, xp = 330, copyLevels = { 58, 59, 60, 76, 78, 100, 114, 126 }, order = 27, color = { 170, 90, 70 } },
	TimberedManor = { id = "TimberedManor", displayName = "Timbered Manor", population = 380, coinCost = 19000, buildSeconds = 36 * HOUR, xp = 380, copyLevels = { 62, 64, 66, 80, 88, 114, 130, 134, 138 }, order = 28, color = { 235, 225, 200 } },
	TurretHouse = { id = "TurretHouse", displayName = "Turret House", population = 420, coinCost = 21000, buildSeconds = 38 * HOUR, xp = 420, copyLevels = { 68, 70, 84, 86, 108, 118, 130, 134, 138 }, order = 29, color = { 225, 210, 235 } },
	GardenFlats = { id = "GardenFlats", displayName = "Garden Flats", population = 460, coinCost = 27600, buildSeconds = 40 * HOUR, xp = 460, copyLevels = { 72, 74, 76, 82, 108, 112, 120, 128, 138 }, order = 30, color = { 230, 200, 160 } },
	GlassHouse = { id = "GlassHouse", displayName = "Glass House", population = 520, coinCost = 36400, buildSeconds = 42 * HOUR, xp = 520, copyLevels = { 78, 80, 82, 84, 102, 114, 116, 130, 136 }, order = 31, color = { 200, 220, 230 } },
	CityApartments = { id = "CityApartments", displayName = "City Apartments", population = 580, coinCost = 46400, buildSeconds = 42 * HOUR, xp = 580, copyLevels = { 86, 90, 98, 104, 106, 110, 116, 122, 126, 134 }, order = 32, color = { 200, 190, 180 } },
	BalconyTower = { id = "BalconyTower", displayName = "Balcony Tower", population = 640, coinCost = 51200, buildSeconds = 44 * HOUR, xp = 640, copyLevels = { 88, 98, 104, 106, 108, 112, 120, 124, 128 }, order = 33, color = { 235, 235, 225 } },
	PenthouseTower = { id = "PenthouseTower", displayName = "Penthouse Tower", population = 700, coinCost = 56000, buildSeconds = 44 * HOUR, xp = 700, copyLevels = { 90, 96, 98, 100, 102, 112, 114, 134, 136 }, order = 34, color = { 210, 195, 170 } },
	SkylineTower = { id = "SkylineTower", displayName = "Skyline Tower", population = 760, coinCost = 61000, buildSeconds = 45 * HOUR, xp = 760, copyLevels = { 92, 94, 104, 106, 108, 110, 126, 128 }, order = 35, color = { 170, 190, 210 } },
	PoolsideTower = { id = "PoolsideTower", displayName = "Poolside Tower", population = 820, coinCost = 66000, buildSeconds = 46 * HOUR, xp = 820, copyLevels = { 92, 94, 96, 100, 102, 110, 118, 122, 132 }, order = 36, color = { 240, 240, 235 } },
	GreenRoofTower = { id = "GreenRoofTower", displayName = "Green Roof Tower", population = 900, coinCost = 76000, buildSeconds = 48 * HOUR, xp = 900, copyLevels = { 112, 114, 116, 118, 120, 124, 128, 132, 136 }, order = 37, color = { 225, 230, 215 } },
	WavyHouse = { id = "WavyHouse", displayName = "Wavy House", population = 960, coinCost = 86400, buildSeconds = 48 * HOUR, xp = 960, copyLevels = { 116, 118, 120, 122, 124, 126, 136, 138 }, order = 38, color = { 235, 225, 205 } },
	SpiralTower = { id = "SpiralTower", displayName = "Spiral Tower", population = 1020, coinCost = 91800, buildSeconds = 48 * HOUR, xp = 1020, copyLevels = { 122, 124, 126, 128, 130, 132, 134 }, order = 39, color = { 240, 240, 240 } },
	CourtyardHouse = { id = "CourtyardHouse", displayName = "Courtyard House", population = 1080, coinCost = 97200, buildSeconds = 48 * HOUR, xp = 1080, copyLevels = { 130, 132, 134, 136, 138 }, order = 40, color = { 230, 190, 140 } },
	StoneVilla = { id = "StoneVilla", displayName = "Stone Villa", population = 1140, coinCost = 102600, buildSeconds = 48 * HOUR, xp = 1140, copyLevels = { 138 }, order = 41, color = { 200, 190, 170 } },
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
	WeatherStation = { id = "WeatherStation", displayName = "Weather Station", unlockLevel = 39, capBonus = 190, coinCost = 8600, materials = { Bricks = 16, Planks = 22, Panes = 15 }, buildSeconds = 25 * HOUR, xp = 380, order = 36, color = { 150, 190, 230 } },
	SkydivingSchool = { id = "SkydivingSchool", displayName = "Skydiving School", unlockLevel = 40, capBonus = 195, coinCost = 9300, materials = { Bricks = 19, Planks = 18, Panes = 18 }, buildSeconds = 26 * HOUR, xp = 390, order = 37, color = { 120, 170, 230 } },
	ComicShop = { id = "ComicShop", displayName = "Comic Shop", unlockLevel = 41, capBonus = 200, coinCost = 10000, materials = { Bricks = 20, Planks = 15, Panes = 22 }, buildSeconds = 27 * HOUR, xp = 400, order = 38, color = { 250, 210, 80 } },
	LifeboatStation = { id = "LifeboatStation", displayName = "Lifeboat Station", unlockLevel = 42, capBonus = 205, coinCost = 10700, materials = { Bricks = 17, Planks = 20, Panes = 22 }, buildSeconds = 28 * HOUR, xp = 410, order = 39, color = { 230, 90, 70 } },
	GroceryStore = { id = "GroceryStore", displayName = "Grocery Store", unlockLevel = 43, capBonus = 210, coinCost = 11500, materials = { Bricks = 23, Planks = 19, Panes = 19 }, buildSeconds = 29 * HOUR, xp = 420, order = 40, color = { 120, 190, 120 } },
	Glasshouse = { id = "Glasshouse", displayName = "Glasshouse", unlockLevel = 44, capBonus = 215, coinCost = 12500, materials = { Bricks = 23, Planks = 15, Panes = 25 }, buildSeconds = 30 * HOUR, xp = 430, order = 41, color = { 150, 210, 170 } },
	SplashPark = { id = "SplashPark", displayName = "Splash Park", unlockLevel = 45, capBonus = 220, coinCost = 13500, materials = { Bricks = 24, Planks = 18, Panes = 23 }, buildSeconds = 31 * HOUR, xp = 440, order = 42, color = { 90, 180, 230 } },
	CarShow = { id = "CarShow", displayName = "Car Show", unlockLevel = 46, capBonus = 230, coinCost = 14500, materials = { Bricks = 18, Planks = 27, Panes = 22 }, buildSeconds = 32 * HOUR, xp = 460, order = 43, color = { 220, 60, 60 } },
	HydroDam = { id = "HydroDam", displayName = "Hydro Dam", unlockLevel = 47, capBonus = 240, coinCost = 15500, materials = { Bricks = 21, Planks = 24, Panes = 24 }, buildSeconds = 33 * HOUR, xp = 480, order = 44, color = { 140, 170, 200 } },
	FashionStudio = { id = "FashionStudio", displayName = "Fashion Studio", unlockLevel = 48, capBonus = 250, coinCost = 16500, materials = { Bricks = 25, Planks = 26, Panes = 20 }, buildSeconds = 34 * HOUR, xp = 500, order = 45, color = { 230, 140, 200 } },
	FilmStudio = { id = "FilmStudio", displayName = "Film Studio", unlockLevel = 49, capBonus = 260, coinCost = 17500, materials = { Bricks = 20, Planks = 25, Panes = 28 }, buildSeconds = 35 * HOUR, xp = 520, order = 46, color = { 60, 60, 80 } },
	Courthouse = { id = "Courthouse", displayName = "Courthouse", unlockLevel = 50, capBonus = 270, coinCost = 18500, materials = { Bricks = 29, Planks = 18, Panes = 28 }, buildSeconds = 36 * HOUR, xp = 540, order = 47, color = { 230, 225, 210 } },
	KartTrack = { id = "KartTrack", displayName = "Kart Track", unlockLevel = 51, capBonus = 290, coinCost = 19500, materials = { Bricks = 27, Planks = 23, Panes = 27 }, buildSeconds = 37 * HOUR, xp = 580, order = 48, color = { 230, 70, 60 } },
	FitnessClub = { id = "FitnessClub", displayName = "Fitness Club", unlockLevel = 52, capBonus = 310, coinCost = 20500, materials = { Bricks = 23, Planks = 18, Panes = 38 }, buildSeconds = 38 * HOUR, xp = 620, order = 49, color = { 90, 160, 230 } },
	DaySpa = { id = "DaySpa", displayName = "Day Spa", unlockLevel = 53, capBonus = 330, coinCost = 21500, materials = { Bricks = 25, Planks = 33, Panes = 23 }, buildSeconds = 39 * HOUR, xp = 660, order = 50, color = { 170, 220, 200 } },
	GolfClub = { id = "GolfClub", displayName = "Golf Club", unlockLevel = 54, capBonus = 350, coinCost = 22500, materials = { Bricks = 27, Planks = 32, Panes = 24 }, buildSeconds = 40 * HOUR, xp = 700, order = 51, color = { 110, 190, 90 } },
	OrganHall = { id = "OrganHall", displayName = "Organ Hall", unlockLevel = 55, capBonus = 370, coinCost = 23500, materials = { Bricks = 24, Planks = 25, Panes = 36 }, buildSeconds = 41 * HOUR, xp = 740, order = 52, color = { 200, 160, 110 } },
	DonutCafe = { id = "DonutCafe", displayName = "Donut Café", unlockLevel = 56, capBonus = 390, coinCost = 25000, materials = { Bricks = 25, Planks = 28, Panes = 34 }, buildSeconds = 42 * HOUR, xp = 780, order = 53, color = { 240, 150, 190 } },
	Speedway = { id = "Speedway", displayName = "Speedway", unlockLevel = 57, capBonus = 410, coinCost = 26500, materials = { Bricks = 24, Planks = 31, Panes = 34 }, buildSeconds = 43 * HOUR, xp = 820, order = 54, color = { 60, 60, 70 } },
	ClimbingWall = { id = "ClimbingWall", displayName = "Climbing Wall", unlockLevel = 58, capBonus = 430, coinCost = 28000, materials = { Bricks = 31, Planks = 28, Panes = 32 }, buildSeconds = 44 * HOUR, xp = 860, order = 55, color = { 230, 140, 60 } },
	AutoWorkshop = { id = "AutoWorkshop", displayName = "Auto Workshop", unlockLevel = 59, capBonus = 450, coinCost = 29500, materials = { Bricks = 34, Planks = 35, Panes = 24 }, buildSeconds = 45 * HOUR, xp = 900, order = 56, color = { 90, 120, 160 } },
	Planetarium = { id = "Planetarium", displayName = "Planetarium", unlockLevel = 60, capBonus = 470, coinCost = 31000, materials = { Bricks = 30, PowerDrill = 8, PowerSaw = 5 }, buildSeconds = 46 * HOUR, xp = 940, order = 57, color = { 70, 80, 140 } },
	BlossomBoutique = { id = "BlossomBoutique", displayName = "Blossom Boutique", unlockLevel = 62, capBonus = 490, coinCost = 50500, materials = { Panes = 35, PowerDrill = 12, Jackhammer = 8 }, buildSeconds = 47 * HOUR, xp = 980, order = 58, color = { 240, 170, 200 } },
	PonyRacecourse = { id = "PonyRacecourse", displayName = "Pony Racecourse", unlockLevel = 64, capBonus = 530, coinCost = 63000, materials = { Bricks = 41, PowerSaw = 14, Jackhammer = 10 }, buildSeconds = 48 * HOUR, xp = 1060, order = 59, color = { 150, 200, 110 } },
	ConcertHall = { id = "ConcertHall", displayName = "Concert Hall", unlockLevel = 66, capBonus = 570, coinCost = 75500, materials = { Planks = 46, PowerDrill = 15, Jackhammer = 13 }, buildSeconds = 49 * HOUR, xp = 1140, order = 60, color = { 130, 60, 90 } },
	CarWash = { id = "CarWash", displayName = "Car Wash", unlockLevel = 68, capBonus = 610, coinCost = 87000, materials = { Bricks = 51, PowerSaw = 17, Jackhammer = 15 }, buildSeconds = 50 * HOUR, xp = 1220, order = 61, color = { 90, 170, 220 } },
	DolphinLagoon = { id = "DolphinLagoon", displayName = "Dolphin Lagoon", unlockLevel = 70, capBonus = 650, coinCost = 99500, materials = { Panes = 57, PowerDrill = 19, PowerSaw = 17 }, buildSeconds = 51 * HOUR, xp = 1300, order = 62, color = { 60, 160, 210 } },
	Lighthouse = { id = "Lighthouse", displayName = "Lighthouse", unlockLevel = 72, capBonus = 690, coinCost = 111000, materials = { Planks = 67, PowerSaw = 20, Jackhammer = 19 }, buildSeconds = 52 * HOUR, xp = 1380, order = 63, color = { 230, 230, 235 } },
	SkyTower = { id = "SkyTower", displayName = "Sky Tower", unlockLevel = 74, capBonus = 730, coinCost = 125000, materials = { Bricks = 73, PowerDrill = 23, Jackhammer = 21 }, buildSeconds = 53 * HOUR, xp = 1460, order = 64, color = { 120, 170, 210 } },
	BikeRental = { id = "BikeRental", displayName = "Bike Rental", unlockLevel = 76, capBonus = 790, coinCost = 133000, materials = { Panes = 78, PowerDrill = 25, PowerSaw = 22 }, buildSeconds = 54 * HOUR, xp = 1580, order = 65, color = { 120, 200, 120 } },
	Kindergarten = { id = "Kindergarten", displayName = "Kindergarten", unlockLevel = 78, capBonus = 850, coinCost = 148000, materials = { Planks = 83, PowerSaw = 24, Jackhammer = 27 }, buildSeconds = 55 * HOUR, xp = 1700, order = 66, color = { 250, 200, 90 } },
	DogPark = { id = "DogPark", displayName = "Dog Park", unlockLevel = 80, capBonus = 900, coinCost = 167000, materials = { Bricks = 90, PowerDrill = 30, Jackhammer = 25 }, buildSeconds = 56 * HOUR, xp = 1800, order = 67, color = { 130, 190, 100 } },
	SavingsBank = { id = "SavingsBank", displayName = "Savings Bank", unlockLevel = 82, capBonus = 980, coinCost = 180000, materials = { Panes = 95, PowerDrill = 32, PowerSaw = 27 }, buildSeconds = 57 * HOUR, xp = 1960, order = 68, color = { 210, 200, 170 } },
	VetClinic = { id = "VetClinic", displayName = "Vet Clinic", unlockLevel = 84, capBonus = 1090, coinCost = 201000, materials = { Planks = 101, PowerSaw = 32, Jackhammer = 31 }, buildSeconds = 58 * HOUR, xp = 2180, order = 69, color = { 230, 240, 245 } },
	Boatyard = { id = "Boatyard", displayName = "Boatyard", unlockLevel = 86, capBonus = 1190, coinCost = 222000, materials = { Bricks = 107, PowerDrill = 34, Jackhammer = 33 }, buildSeconds = 59 * HOUR, xp = 2320, order = 70, color = { 110, 150, 190 } },
	GadgetShop = { id = "GadgetShop", displayName = "Gadget Shop", unlockLevel = 88, capBonus = 1290, coinCost = 231000, materials = { Panes = 113, PowerDrill = 35, PowerSaw = 36 }, buildSeconds = 60 * HOUR, xp = 2580, order = 71, color = { 80, 110, 160 } },
	CueClub = { id = "CueClub", displayName = "Cue Club", unlockLevel = 90, capBonus = 1360, coinCost = 252000, materials = { Planks = 119, PowerSaw = 36, Jackhammer = 39 }, buildSeconds = 61 * HOUR, xp = 2720, order = 72, color = { 40, 110, 70 } },
	GameArena = { id = "GameArena", displayName = "Game Arena", unlockLevel = 92, capBonus = 1580, coinCost = 285000, materials = { Bricks = 125, PowerDrill = 41, Jackhammer = 38 }, buildSeconds = 62 * HOUR, xp = 3160, order = 73, color = { 110, 60, 160 } },
	DiveShop = { id = "DiveShop", displayName = "Dive Shop", unlockLevel = 94, capBonus = 1580, coinCost = 300000, materials = { Panes = 130, PowerDrill = 42, PowerSaw = 42 }, buildSeconds = 66 * HOUR, xp = 3160, order = 74, color = { 60, 150, 200 } },
	RadioDish = { id = "RadioDish", displayName = "Radio Dish", unlockLevel = 96, capBonus = 1790, coinCost = 327000, materials = { Planks = 136, PowerSaw = 42, Jackhammer = 46 }, buildSeconds = 65 * HOUR, xp = 3580, order = 75, color = { 230, 230, 235 } },
	TrailCamp = { id = "TrailCamp", displayName = "Trail Camp", unlockLevel = 98, capBonus = 1920, coinCost = 356000, materials = { Bricks = 142, PowerDrill = 46, Jackhammer = 46 }, buildSeconds = 65 * HOUR, xp = 3780, order = 76, color = { 120, 140, 80 } },
	RecyclingCenter = { id = "RecyclingCenter", displayName = "Recycling Center", unlockLevel = 100, capBonus = 2040, coinCost = 387000, materials = { Bricks = 148, PowerDrill = 46, Jackhammer = 50 }, buildSeconds = 67 * HOUR, xp = 4080, order = 77, color = { 90, 160, 90 } },
	SouvenirShop = { id = "SouvenirShop", displayName = "Souvenir Shop", unlockLevel = 102, capBonus = 2040, coinCost = 390000, materials = { Bricks = 160, PowerDrill = 48, Jackhammer = 46 }, buildSeconds = 68 * HOUR, xp = 4080, order = 78, color = { 240, 120, 150 } },
	SkateBowl = { id = "SkateBowl", displayName = "Skate Bowl", unlockLevel = 104, capBonus = 2190, coinCost = 455500, materials = { Panes = 160, PowerSaw = 54, Jackhammer = 50 }, buildSeconds = 69 * HOUR, xp = 4380, order = 79, color = { 200, 200, 205 } },
	TravelBureau = { id = "TravelBureau", displayName = "Travel Bureau", unlockLevel = 106, capBonus = 2320, coinCost = 492000, materials = { Planks = 160, PowerDrill = 58, Jackhammer = 56 }, buildSeconds = 70 * HOUR, xp = 4640, order = 80, color = { 90, 180, 210 } },
	WeddingBoutique = { id = "WeddingBoutique", displayName = "Wedding Boutique", unlockLevel = 108, capBonus = 2440, coinCost = 531000, materials = { Bricks = 162, PowerDrill = 62, PowerSaw = 60 }, buildSeconds = 72 * HOUR, xp = 4880, order = 81, color = { 245, 235, 240 } },
	SnipSalon = { id = "SnipSalon", displayName = "Snip Salon", unlockLevel = 110, capBonus = 2570, coinCost = 572000, materials = { Panes = 168, PowerSaw = 64, Jackhammer = 62 }, buildSeconds = 72 * HOUR, xp = 5140, order = 82, color = { 220, 60, 60 } },
	PowerHub = { id = "PowerHub", displayName = "Power Hub", unlockLevel = 112, capBonus = 2700, coinCost = 615000, materials = { Planks = 174, PowerDrill = 66, Jackhammer = 64 }, buildSeconds = 73 * HOUR, xp = 5400, order = 83, color = { 70, 160, 120 } },
	PetLodge = { id = "PetLodge", displayName = "Pet Lodge", unlockLevel = 114, capBonus = 2830, coinCost = 660000, materials = { Bricks = 180, PowerDrill = 68, PowerSaw = 66 }, buildSeconds = 74 * HOUR, xp = 5660, order = 84, color = { 240, 190, 120 } },
	RollerDisco = { id = "RollerDisco", displayName = "Roller Disco", unlockLevel = 116, capBonus = 2960, coinCost = 585000, materials = { Panes = 186, Jackhammer = 68, PowerSaw = 70 }, buildSeconds = 43 * HOUR, xp = 5920, order = 85, color = { 200, 90, 200 } },
	SurfLagoon = { id = "SurfLagoon", displayName = "Surf Lagoon", unlockLevel = 118, capBonus = 3100, coinCost = 558000, materials = { Planks = 190, Jackhammer = 72, PowerDrill = 72 }, buildSeconds = 48 * HOUR, xp = 6200, order = 86, color = { 60, 170, 220 } },
	BookNook = { id = "BookNook", displayName = "Book Nook", unlockLevel = 120, capBonus = 3230, coinCost = 579000, materials = { Bricks = 194, PowerDrill = 76, PowerSaw = 74 }, buildSeconds = 48 * HOUR, xp = 6460, order = 87, color = { 150, 60, 50 } },
	ZenStudio = { id = "ZenStudio", displayName = "Zen Studio", unlockLevel = 122, capBonus = 3380, coinCost = 600000, materials = { Panes = 200, PowerSaw = 78, Jackhammer = 76 }, buildSeconds = 48 * HOUR, xp = 6760, order = 88, color = { 200, 220, 190 } },
	IceRink = { id = "IceRink", displayName = "Ice Rink", unlockLevel = 124, capBonus = 3520, coinCost = 621000, materials = { Planks = 204, Jackhammer = 80, PowerDrill = 80 }, buildSeconds = 48 * HOUR, xp = 7020, order = 89, color = { 200, 230, 245 } },
	DanceAcademy = { id = "DanceAcademy", displayName = "Dance Academy", unlockLevel = 126, capBonus = 3650, coinCost = 642000, materials = { Bricks = 208, PowerDrill = 84, PowerSaw = 82 }, buildSeconds = 48 * HOUR, xp = 7300, order = 90, color = { 245, 200, 215 } },
	DiscoveryMuseum = { id = "DiscoveryMuseum", displayName = "Discovery Museum", unlockLevel = 128, capBonus = 3780, coinCost = 663000, materials = { Panes = 214, PowerSaw = 86, Jackhammer = 84 }, buildSeconds = 48 * HOUR, xp = 7560, order = 91, color = { 210, 215, 225 } },
	BluesLounge = { id = "BluesLounge", displayName = "Blues Lounge", unlockLevel = 130, capBonus = 3920, coinCost = 684000, materials = { Planks = 218, Jackhammer = 88, PowerDrill = 88 }, buildSeconds = 48 * HOUR, xp = 7560, order = 92, color = { 40, 50, 100 } },
	Auditorium = { id = "Auditorium", displayName = "Grand Auditorium", unlockLevel = 132, capBonus = 4050, coinCost = 705000, materials = { Bricks = 222, PowerDrill = 92, PowerSaw = 90 }, buildSeconds = 48 * HOUR, xp = 8100, order = 93, color = { 230, 220, 200 } },
	ClayStudio = { id = "ClayStudio", displayName = "Clay Studio", unlockLevel = 134, capBonus = 4180, coinCost = 726000, materials = { Panes = 228, PowerSaw = 94, Jackhammer = 92 }, buildSeconds = 48 * HOUR, xp = 8360, order = 94, color = { 200, 120, 80 } },
	ArcheryField = { id = "ArcheryField", displayName = "Archery Field", unlockLevel = 136, capBonus = 4310, coinCost = 747000, materials = { Planks = 236, Jackhammer = 94, PowerDrill = 94 }, buildSeconds = 48 * HOUR, xp = 8620, order = 95, color = { 120, 150, 80 } },
	SharedOffice = { id = "SharedOffice", displayName = "Shared Office", unlockLevel = 138, capBonus = 4440, coinCost = 768000, materials = { Bricks = 236, PowerDrill = 100, PowerSaw = 98 }, buildSeconds = 48 * HOUR, xp = 8880, order = 96, color = { 180, 190, 200 } },
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
