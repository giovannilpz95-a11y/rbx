--!strict
-- Prize Crops lite from Design/02 Farming (decided 2026-10-29; Township has no crop variants,
-- so every number here is first-pass). One roll per field, made when the crop is planted so a
-- Gem speed-up never buys a roll; on a hit one unit of the harvest is a Prize Crop.

return table.freeze({
	tiers = table.freeze({
		Sunkissed = table.freeze({ displayName = "Sunkissed", chance = 0.02, value = 3, order = 1 }),
		-- Weather traits (13 §3.1-3.2): only fields growing during a sky event roll them (shared/Sky)
		Dewkissed = table.freeze({ displayName = "Dewkissed", chance = 0.1, value = 4, order = 2, weather = true }),
		Starlit = table.freeze({ displayName = "Starlit", chance = 0.05, value = 6, order = 3, weather = true }),
		Heirloom = table.freeze({ displayName = "Heirloom", chance = 0.002, value = 15, order = 4 }),
	}),
	basketSlots = 10, -- the Prize Basket, kept apart from the Barn
	shelfSlots = 3, -- the Prize Shelf on the plot (more from Town Records later)
	noticeLines = 8, -- recent finds on the Town Square Notice Board
})
