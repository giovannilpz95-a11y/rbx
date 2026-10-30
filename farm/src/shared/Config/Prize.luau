--!strict
-- Prize Crops lite from Design/02 Farming (decided 2026-10-29; Township has no crop variants,
-- so every number here is first-pass). One roll per field, made when the crop is planted so a
-- Gem speed-up never buys a roll; on a hit one unit of the harvest is a Prize Crop.

return table.freeze({
	tiers = table.freeze({
		Sunkissed = table.freeze({ displayName = "Sunkissed", chance = 0.02, value = 3, order = 1 }),
		Heirloom = table.freeze({ displayName = "Heirloom", chance = 0.002, value = 15, order = 2 }),
	}),
	basketSlots = 10, -- the Prize Basket, kept apart from the Barn
})
