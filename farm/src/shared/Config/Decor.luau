--!strict
-- The MVP decoration set (~12) plus the level 13+ set from Design/07 Town Building (categories, cost and level
-- ranges, 1-20 XP) and 16 Model Catalog §2.11 (names, footprints). Exact prices and levels
-- are first-pass within 07's ranges. A tile is 4 x 4 studs; size is in tiles before rotation.

export type DecorDef = {
	id: string,
	displayName: string,
	category: string,
	unlockLevel: number,
	coinCost: number,
	xp: number, -- once, when bought and placed
	size: { number }, -- { width (x), depth (z) } in tiles
	order: number,
}

-- stylua: ignore
local Decor: { [string]: DecorDef } = {
	GravelPath = { id = "GravelPath", displayName = "Gravel Path", category = "Paths & fences", unlockLevel = 2, coinCost = 5, xp = 1, size = { 1, 1 }, order = 1 },
	BrickPath = { id = "BrickPath", displayName = "Brick Path", category = "Paths & fences", unlockLevel = 3, coinCost = 15, xp = 1, size = { 1, 1 }, order = 2 },
	PicketFence = { id = "PicketFence", displayName = "Picket Fence", category = "Paths & fences", unlockLevel = 2, coinCost = 20, xp = 2, size = { 1, 1 }, order = 3 },
	HedgeRow = { id = "HedgeRow", displayName = "Hedge Row", category = "Paths & fences", unlockLevel = 4, coinCost = 40, xp = 2, size = { 1, 1 }, order = 4 },
	FlowerBed = { id = "FlowerBed", displayName = "Flower Bed", category = "Nature", unlockLevel = 2, coinCost = 50, xp = 3, size = { 1, 1 }, order = 5 },
	OakTree = { id = "OakTree", displayName = "Oak Tree", category = "Nature", unlockLevel = 3, coinCost = 120, xp = 5, size = { 2, 2 }, order = 6 },
	HayBales = { id = "HayBales", displayName = "Hay Bales", category = "Nature", unlockLevel = 4, coinCost = 150, xp = 5, size = { 2, 1 }, order = 7 },
	Pond = { id = "Pond", displayName = "Pond", category = "Nature", unlockLevel = 8, coinCost = 600, xp = 10, size = { 3, 3 }, order = 8 },
	LampPost = { id = "LampPost", displayName = "Lamp Post", category = "Lights & furniture", unlockLevel = 5, coinCost = 80, xp = 3, size = { 1, 1 }, order = 9 },
	Bench = { id = "Bench", displayName = "Bench", category = "Lights & furniture", unlockLevel = 5, coinCost = 150, xp = 4, size = { 2, 1 }, order = 10 },
	PicnicTable = { id = "PicnicTable", displayName = "Picnic Table", category = "Lights & furniture", unlockLevel = 7, coinCost = 400, xp = 8, size = { 2, 2 }, order = 11 },
	StoneFountain = { id = "StoneFountain", displayName = "Stone Fountain", category = "Landmarks", unlockLevel = 10, coinCost = 2000, xp = 20, size = { 3, 3 }, order = 12 },
	-- Level 13+ set (Model List - Town & Factories §7, P1); prices first-pass within 07's ranges
	SteppingStones = { id = "SteppingStones", displayName = "Stepping Stones", category = "Paths & fences", unlockLevel = 13, coinCost = 10, xp = 1, size = { 1, 1 }, order = 13 },
	PottedFlowers = { id = "PottedFlowers", displayName = "Potted Flowers", category = "Nature", unlockLevel = 13, coinCost = 90, xp = 3, size = { 1, 1 }, order = 14 },
	RailFence = { id = "RailFence", displayName = "Post-and-Rail Fence", category = "Paths & fences", unlockLevel = 13, coinCost = 30, xp = 2, size = { 1, 1 }, order = 15 },
	RoundPine = { id = "RoundPine", displayName = "Round Pine", category = "Nature", unlockLevel = 14, coinCost = 250, xp = 6, size = { 2, 2 }, order = 16 },
	SunflowerPatch = { id = "SunflowerPatch", displayName = "Sunflower Patch", category = "Nature", unlockLevel = 15, coinCost = 120, xp = 4, size = { 1, 1 }, order = 17 },
	FarmLane = { id = "FarmLane", displayName = "Farm Lane", category = "Paths & fences", unlockLevel = 15, coinCost = 12, xp = 1, size = { 1, 1 }, order = 18 },
	StoneWall = { id = "StoneWall", displayName = "Stone Wall", category = "Paths & fences", unlockLevel = 16, coinCost = 60, xp = 3, size = { 1, 1 }, order = 19 },
	Scarecrow = { id = "Scarecrow", displayName = "Scarecrow", category = "Nature", unlockLevel = 16, coinCost = 300, xp = 6, size = { 1, 1 }, order = 20 },
	BlossomTree = { id = "BlossomTree", displayName = "Blossom Tree", category = "Nature", unlockLevel = 17, coinCost = 500, xp = 8, size = { 2, 2 }, order = 21 },
	Topiary = { id = "Topiary", displayName = "Topiary", category = "Nature", unlockLevel = 18, coinCost = 350, xp = 6, size = { 1, 1 }, order = 22 },
	Birdbath = { id = "Birdbath", displayName = "Birdbath", category = "Lights & furniture", unlockLevel = 19, coinCost = 450, xp = 7, size = { 1, 1 }, order = 23 },
	GardenSwing = { id = "GardenSwing", displayName = "Garden Swing", category = "Lights & furniture", unlockLevel = 20, coinCost = 900, xp = 10, size = { 2, 1 }, order = 24 },
	-- Level 21-28 set: Township's level and Coin price for each slot (wiki Decoration Table), our
	-- own pieces and names
	DaffodilBed = { id = "DaffodilBed", displayName = "Daffodil Bed", category = "Nature", unlockLevel = 21, coinCost = 550, xp = 6, size = { 1, 1 }, order = 25 },
	PalmPair = { id = "PalmPair", displayName = "Palm Pair", category = "Nature", unlockLevel = 21, coinCost = 400, xp = 5, size = { 1, 1 }, order = 26 },
	FishingJetty = { id = "FishingJetty", displayName = "Fishing Jetty", category = "Landmarks", unlockLevel = 22, coinCost = 650, xp = 7, size = { 1, 2 }, order = 27 },
	GardenObelisk = { id = "GardenObelisk", displayName = "Garden Obelisk", category = "Landmarks", unlockLevel = 22, coinCost = 560, xp = 6, size = { 1, 1 }, order = 28 },
	DeckChairs = { id = "DeckChairs", displayName = "Deck Chairs", category = "Lights & furniture", unlockLevel = 23, coinCost = 550, xp = 6, size = { 1, 1 }, order = 29 },
	PumpkinCart = { id = "PumpkinCart", displayName = "Pumpkin Cart", category = "Nature", unlockLevel = 24, coinCost = 200, xp = 4, size = { 1, 1 }, order = 30 },
	RoseBed = { id = "RoseBed", displayName = "Rose Bed", category = "Nature", unlockLevel = 24, coinCost = 400, xp = 5, size = { 1, 1 }, order = 31 },
	IrisBed = { id = "IrisBed", displayName = "Iris Bed", category = "Nature", unlockLevel = 25, coinCost = 750, xp = 8, size = { 1, 1 }, order = 32 },
	Rowboat = { id = "Rowboat", displayName = "Rowboat", category = "Landmarks", unlockLevel = 26, coinCost = 400, xp = 5, size = { 1, 1 }, order = 33 },
	Treehouse = { id = "Treehouse", displayName = "Treehouse", category = "Landmarks", unlockLevel = 26, coinCost = 2300, xp = 15, size = { 1, 1 }, order = 34 },
	TieredFountain = { id = "TieredFountain", displayName = "Tiered Fountain", category = "Lights & furniture", unlockLevel = 27, coinCost = 400, xp = 5, size = { 1, 1 }, order = 35 },
	WeepingWillow = { id = "WeepingWillow", displayName = "Weeping Willow", category = "Nature", unlockLevel = 28, coinCost = 2700, xp = 16, size = { 1, 1 }, order = 36 },
}

for _, def in Decor do
	table.freeze(def.size)
	table.freeze(def)
end

return table.freeze({
	items = table.freeze(Decor),
	sellRefund = 0.5, -- selling a decoration refunds 50% of its Coin cost (Township)
	-- Caps keep a full plot inside the 2,500-part budget (a level-12 plot is ~1,800 before
	-- decorations): paths are ~3 parts, the big pieces (2 x 2 tiles and up) up to ~12 (first-pass)
	maxPlaced = 60,
	maxBig = 12,
	bigTiles = 4,
	tile = 4,
})
