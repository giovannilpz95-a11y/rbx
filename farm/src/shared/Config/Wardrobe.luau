--!strict
-- The Wardrobe: farm fashion worn on top of the player's own avatar (Design/14 I1). Pieces go
-- in four slots. Some are bought with Coins (from a level) or Gems, and some can only be
-- earned: a County Fair Blue Ribbon, a Plot Showcase win, or the running event's prize track.
-- Every piece is ours and shows only in this game; nothing replaces the player's avatar, and
-- taking the outfit off brings back exactly what they had. Prices are first-pass (Township has
-- no outfits).

export type Slot = "Hat" | "Neck" | "Body" | "Back"

-- How a piece is earned instead of bought
export type Earn = {
	kind: "fairBlue" | "showcaseWin" | "event",
	event: string?, -- kind "event": the event's id (Config/Events)
	earned: number?, -- kind "event": tokens earned in that event
}

export type Piece = {
	id: string,
	displayName: string,
	slot: Slot,
	order: number,
	coins: number?,
	gems: number?,
	level: number?, -- bought with Coins from this level
	earn: Earn?,
	free: boolean?, -- every farm has it from the start
}

local SLOTS: { Slot } = { "Hat", "Neck", "Body", "Back" }

local pieces: { [string]: Piece } = {
	-- Hats
	StrawHat = { id = "StrawHat", displayName = "Straw Hat", slot = "Hat", order = 1, free = true },
	FarmerCap = { id = "FarmerCap", displayName = "Farmer's Cap", slot = "Hat", order = 2, coins = 1200, level = 3 },
	Sunbonnet = { id = "Sunbonnet", displayName = "Sunbonnet", slot = "Hat", order = 3, coins = 2500, level = 6 },
	RanchHat = { id = "RanchHat", displayName = "Ranch Hat", slot = "Hat", order = 4, gems = 25 },
	BeekeeperVeil = { id = "BeekeeperVeil", displayName = "Beekeeper's Veil", slot = "Hat", order = 5, gems = 35 },
	SunflowerHat = {
		id = "SunflowerHat",
		displayName = "Sunflower Hat",
		slot = "Hat",
		order = 6,
		earn = { kind = "showcaseWin" },
	},
	PumpkinCap = {
		id = "PumpkinCap",
		displayName = "Pumpkin Cap",
		slot = "Hat",
		order = 7,
		earn = { kind = "event", event = "HarvestFair", earned = 600 },
	},

	-- Neck
	RedBandana = { id = "RedBandana", displayName = "Red Bandana", slot = "Neck", order = 1, coins = 600, level = 2 },
	GinghamScarf = {
		id = "GinghamScarf",
		displayName = "Gingham Scarf",
		slot = "Neck",
		order = 2,
		coins = 1800,
		level = 5,
	},
	BlueRosette = {
		id = "BlueRosette",
		displayName = "Blue Ribbon Rosette",
		slot = "Neck",
		order = 3,
		earn = { kind = "fairBlue" },
	},

	-- Body
	DenimOveralls = {
		id = "DenimOveralls",
		displayName = "Denim Overalls",
		slot = "Body",
		order = 1,
		coins = 3500,
		level = 7,
	},
	GinghamApron = { id = "GinghamApron", displayName = "Gingham Apron", slot = "Body", order = 2, gems = 30 },
	RibbonSash = {
		id = "RibbonSash",
		displayName = "Fair Ribbon Sash",
		slot = "Body",
		order = 3,
		earn = { kind = "event", event = "HarvestFair", earned = 1200 },
	},

	-- Back
	WillowBasket = {
		id = "WillowBasket",
		displayName = "Willow Basket",
		slot = "Back",
		order = 1,
		coins = 2000,
		level = 4,
	},
	WateringCan = { id = "WateringCan", displayName = "Watering Can", slot = "Back", order = 2, gems = 20 },
	HayPack = { id = "HayPack", displayName = "Hay Bale Pack", slot = "Back", order = 3, gems = 30 },
}

for _, piece in pieces do
	table.freeze(piece)
	if piece.earn then
		table.freeze(piece.earn)
	end
end

return table.freeze({
	slots = table.freeze(SLOTS),
	pieces = table.freeze(pieces),
	slotNames = table.freeze({ Hat = "Hats", Neck = "Neck", Body = "Outfits", Back = "Back" }),
	slotIcons = table.freeze({ Hat = "👒", Neck = "🧣", Body = "👖", Back = "🧺" }),
	syncSeconds = 10, -- how often earned pieces are checked
})
