--!strict
-- The Seed Cart (Design/13 Roblox Success Mechanics §3.7, Launch/20 Live Ops & Events §5.4):
-- a cart in the Town Square that restocks every 30 minutes, at :00 and :30 UTC, so every
-- server matches. Four slots: two crop crates, one prepaid decoration and a rare Heirloom
-- Seed (otherwise a third crate). Stock is per player, Coins only, so it stays outside the
-- paid random item rules. Prices and odds are first-pass.
-- Ships in roadmap week 3: `enabled` stays false until then (always on in Studio).

return table.freeze({
	enabled = false,
	unlockLevel = 3, -- first-pass: once Corn opens, so the crates have a choice of crops
	restockSeconds = 1800,
	crateQty = 5, -- crop units in a crate
	cratePriceMult = 1.5, -- Coins per unit = the crop's sell price x this (rounded up)
	decorDiscount = 0.25, -- off the decoration's Coin cost; prepaid, placed later for free
	heirloomChance = 0.25, -- per restock, the 4th slot is the Heirloom Seed
	heirloomPrice = 60, -- Coins
	heirloomBoost = 10, -- the next field planted has this times the Heirloom chance
})
