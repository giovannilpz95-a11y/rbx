--!strict
-- The Market (Design/05 Orders & Economy "Market (player stall)", 14 Multiplayer Features §5
-- safety; roadmap week 4): every farm gets a stall at its gate from level 13. Players list
-- farm and factory goods for Coins inside a price band, and anyone else on the server buys
-- them. Township has no player market, so every number here is our own first-pass tuning
-- from the design note.

local MIN = 60
local HOUR = 60 * MIN

return table.freeze({
	unlockLevel = 13,
	-- Stall slots: 4 at level 13, +1 at each of these levels (9 at level 29)
	baseSlots = 4,
	extraSlotLevels = table.freeze({ 16, 19, 22, 25, 29 }),

	maxQty = 10, -- 1-10 units of one item per slot
	-- Price band, as a share of the goods' Barn sell price x qty (the server rejects anything
	-- outside it); listings start at the default
	priceMin = 0.5,
	priceMax = 2,
	priceDefault = 1.2,
	taxRate = 0.1, -- of each sale to a player, burned (a Coin sink)

	-- A listing nobody buys in 2 hours goes to a passing trader at the Barn price (or the
	-- listing's price, if lower), so stalls never sit dead on empty servers
	botSeconds = 2 * HOUR,
	botShare = 1,

	-- Anti-abuse (14 §5): a buyer takes at most 20 listings an hour from one seller, and a farm
	-- under a day old can't buy above 150% of the Barn price
	buysPerSellerPerHour = 20,
	newFarmSeconds = 24 * HOUR,
	newFarmMaxShare = 1.5,

	-- One listing can be featured on the Town Square's Market board, changed every 5 minutes
	featureCooldown = 5 * MIN,

	-- What can be sold: crops, animal goods and factory goods with a Barn price. Never Gems,
	-- tools, materials, decorations or anything bought with Robux.
	kinds = table.freeze({ Crop = true, Animal = true, Product = true }),
})
