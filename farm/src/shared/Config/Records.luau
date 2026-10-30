--!strict
-- Town Records (F07 Museum, Albums & Achievements, MVP-lite; UI Reference & Gaps G11): ten
-- long-term goals with Bronze, Silver and Gold tiers, claimed from the Farmer Card for Gems
-- and XP. Goals and rewards follow Township's achievement tiers I-III (Wiki Data -
-- Decorations & Achievements §2, old T-cash scale, 1 T-cash = 1 Gem); names are ours.
--
-- `stat` is either a counter the farm services add to (shared/Records.add) or one read from
-- the save as it stands (orders, population, factories, houses), so old saves get credit.

export type RecordDef = {
	id: string,
	name: string,
	text: string, -- "%s" is the tier's goal
	short: string, -- the Farmer Card's stat label
	stat: string,
	goals: { number }, -- Bronze, Silver, Gold
	gems: { number },
	xp: { number },
	glyph: string,
}

return table.freeze({
	tiers = table.freeze({ "Bronze", "Silver", "Gold" }),
	list = table.freeze({
		table.freeze({
			id = "Orders",
			short = "orders delivered",
			name = "Order Runner",
			text = "Deliver %s orders",
			stat = "orders",
			goals = { 100, 500, 2000 },
			gems = { 1, 2, 5 },
			xp = { 300, 1200, 2500 },
			glyph = "📋",
		}),
		table.freeze({
			id = "Harvest",
			short = "crops harvested",
			name = "Green Thumb",
			text = "Harvest %s crops",
			stat = "harvest",
			goals = { 500, 5000, 25000 },
			gems = { 1, 3, 5 },
			xp = { 50, 500, 1500 },
			glyph = "🌾",
		}),
		table.freeze({
			id = "Goods",
			short = "goods made",
			name = "Busy Workshop",
			text = "Make %s factory goods",
			stat = "goods",
			goals = { 50, 2000, 15000 },
			gems = { 1, 3, 5 },
			xp = { 50, 400, 1100 },
			glyph = "🏭",
		}),
		table.freeze({
			id = "Animals",
			short = "animal goods",
			name = "Barnyard Pal",
			text = "Collect %s animal goods",
			stat = "animal",
			goals = { 30, 1000, 6000 },
			gems = { 1, 3, 5 },
			xp = { 40, 600, 1200 },
			glyph = "🐄",
		}),
		table.freeze({
			id = "Coins",
			short = "Coins earned",
			name = "Coin Jar",
			text = "Earn %s Coins",
			stat = "coins",
			goals = { 1000, 100000, 1000000 },
			gems = { 1, 2, 5 },
			xp = { 40, 700, 2500 },
			glyph = "💰",
		}),
		table.freeze({
			id = "Population",
			short = "Population",
			name = "Growing Town",
			text = "Reach a Population of %s",
			stat = "population",
			goals = { 150, 1500, 5000 },
			gems = { 1, 3, 8 },
			xp = { 30, 1000, 2000 },
			glyph = "👪",
		}),
		table.freeze({
			id = "Houses",
			short = "houses",
			name = "Home Builder",
			text = "Have %s houses in town",
			stat = "houses",
			goals = { 20, 40, 80 },
			gems = { 2, 4, 8 },
			xp = { 60, 600, 1500 },
			glyph = "🏠",
		}),
		table.freeze({
			id = "Factories",
			short = "factories",
			name = "Factory Row",
			text = "Build %s factories",
			stat = "factories",
			goals = { 3, 7, 12 },
			gems = { 1, 3, 5 },
			xp = { 60, 500, 2000 },
			glyph = "⚙",
		}),
		table.freeze({
			id = "Decor",
			short = "Coins on decor",
			name = "Pretty Plot",
			text = "Spend %s Coins on decorations",
			stat = "decor",
			goals = { 500, 5000, 80000 },
			gems = { 1, 3, 8 },
			xp = { 50, 400, 1600 },
			glyph = "🌷",
		}),
		table.freeze({
			id = "Helping",
			short = "neighbours helped",
			name = "Helping Hand",
			text = "Help neighbours %s times",
			stat = "help",
			goals = { 10, 50, 300 },
			gems = { 2, 4, 10 },
			xp = { 200, 700, 1600 },
			glyph = "🤝",
		}),
	}) :: { RecordDef },
	-- Farmer Card titles by stars (tiers claimed), highest first
	titles = table.freeze({
		{ stars = 24, title = "Valley Legend" },
		{ stars = 16, title = "Master Farmer" },
		{ stars = 10, title = "Town Founder" },
		{ stars = 5, title = "Grower" },
		{ stars = 2, title = "Farmhand" },
		{ stars = 0, title = "New Farmer" },
	}),
})
