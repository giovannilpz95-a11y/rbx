--!strict
-- Gold Town Record trophies: one decoration per Town Record (Config/Records), awarded with its
-- Gold medal on the Farmer Card and never sold in the shop. A gold statue for the record on a
-- stone plinth, built by Art/Decor ("Trophy" .. record). Township gives a golden statue for
-- each finished achievement; the statues and names here are ours.

export type TrophyDef = {
	id: string, -- the decoration id (Art/Decor builder)
	record: string, -- Config/Records id
	displayName: string,
	size: { number }, -- tiles, like Config/Decor
}

local list: { [string]: TrophyDef } = {}
for record, name in
	{
		Orders = "Golden Clipboard",
		Harvest = "Golden Sheaf",
		Goods = "Golden Cog",
		Animals = "Golden Churn",
		Coins = "Golden Coin Stack",
		Population = "Golden Townsfolk",
		Houses = "Golden Cottage",
		Factories = "Golden Mill",
		Decor = "Golden Tulip",
		Helping = "Golden Heart",
	}
do
	list[record] = table.freeze({
		id = "Trophy" .. record,
		record = record,
		displayName = name,
		size = table.freeze({ 1, 1 }),
	})
end

return table.freeze({
	byRecord = table.freeze(list), -- record id -> trophy
})
