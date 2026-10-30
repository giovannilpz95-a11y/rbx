--!strict
-- What Robux buy (Design/10 Monetization, first-pass Gem amounts). The MVP sells three Gem
-- packs, the one-time Starter Pack and the Big Barn game pass. Prices are NOT here: the
-- client reads each one from Roblox at runtime (regional pricing), never hard-codes it.
--
-- IDs are 0 until the products exist on the Creator Dashboard; a 0 product shows as
-- "Coming soon" and can't be prompted.

export type Product = {
	key: string,
	displayName: string,
	productId: number,
	gems: number,
	tools: { [string]: number }?,
	once: boolean?, -- one per player, ever
	fromLevel: number?,
	order: number,
}

return table.freeze({
	products = table.freeze({
		Handful = table.freeze({
			key = "Handful",
			displayName = "Handful of Gems",
			productId = 0,
			gems = 30,
			order = 1,
		}),
		Pouch = table.freeze({ key = "Pouch", displayName = "Pouch of Gems", productId = 0, gems = 65, order = 2 }),
		Sack = table.freeze({ key = "Sack", displayName = "Sack of Gems", productId = 0, gems = 175, order = 3 }),
		StarterPack = table.freeze({
			key = "StarterPack",
			displayName = "Starter Pack",
			productId = 0,
			gems = 100,
			tools = table.freeze({ Shovel = 1, Axe = 1, Saw = 1 }),
			once = true,
			fromLevel = 5,
			order = 4,
		}),
	}) :: { [string]: Product },
	passes = table.freeze({
		BigBarn = table.freeze({
			key = "BigBarn",
			displayName = "Big Barn",
			passId = 0,
			barnBonus = 50, -- flat, on top of upgrades
			order = 1,
		}),
	}),
	keepReceipts = 200, -- processed receipt ids kept for de-duplication (09 §10)
})
