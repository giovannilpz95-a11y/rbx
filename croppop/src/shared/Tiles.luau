--[[
	Crop Pop tile and power-up definitions (names from F12 Crop Pop Puzzle).

	Tile colours are plain numbers 1..6 inside the engine so the board stays cheap
	to copy, hash and send. Sunflower pieces have no colour (0).
]]

local Tiles = {}

Tiles.Names = { "Tomato", "Egg", "Carrot", "Corn", "Milk", "Wool" }

Tiles.ByName = {}
for id, name in Tiles.Names do
	Tiles.ByName[name] = id
end

Tiles.Count = #Tiles.Names

-- Power-up kinds as stored on a piece (`piece.power`).
Tiles.Power = table.freeze({
	SprayerRow = "SprayerRow", -- Seed Sprayer, clears its row
	SprayerColumn = "SprayerColumn", -- Seed Sprayer, clears its column
	Bumblebee = "Bumblebee", -- flies to a goal tile
	HayBomb = "HayBomb", -- clears an area
	Sunflower = "Sunflower", -- clears every tile of one colour
})

-- Player-facing names.
Tiles.PowerNames = table.freeze({
	SprayerRow = "Seed Sprayer",
	SprayerColumn = "Seed Sprayer",
	Bumblebee = "Bumblebee",
	HayBomb = "Hay Bomb",
	Sunflower = "Sunflower",
})

function Tiles.isSprayer(power: string?): boolean
	return power == "SprayerRow" or power == "SprayerColumn"
end

return table.freeze(Tiles)
