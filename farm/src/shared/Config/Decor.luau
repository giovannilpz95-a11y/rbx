--!strict
-- The MVP decoration set (~12) from Design/07 Town Building (categories, cost and level
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
}

for _, def in Decor do
	table.freeze(def.size)
	table.freeze(def)
end

return table.freeze({
	items = table.freeze(Decor),
	sellRefund = 0.25, -- 07: selling a decoration refunds 25% of its Coin cost
	-- Caps keep a full plot inside the 2,500-part budget (a level-12 plot is ~1,800 before
	-- decorations): paths are ~3 parts, the big pieces (2 x 2 tiles and up) up to ~12 (first-pass)
	maxPlaced = 60,
	maxBig = 12,
	bigTiles = 4,
	tile = 4,
})
