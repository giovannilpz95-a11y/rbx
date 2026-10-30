--!strict
-- The Quarry (Features/F01 Quarry & Smelter; Township's mine on the Township baseline, Wiki Data
-- - Side Systems §6, names ours). A dig site at the back of the plot, reopened once with Coins
-- and a wait. Inside is a shaft `width` cells wide that the player tunnels down with Pickaxes.
-- Ore goes to the Ore Shed (no cap, never the Barn). Drop rates by depth aren't on the wiki
-- (its Gaps list): the bands below are first-pass, to tune in playtests.

local HOUR = 3600

export type Block = "Soil" | "Stone" | "Bedrock"
export type OreDef = {
	id: string,
	displayName: string,
	fromDepth: number, -- first row (metres) it can turn up in
	chance: number, -- per dug cell once deep enough
	sellPrice: number,
	xp: number, -- for digging one up
	order: number,
}

-- stylua: ignore
local ores: { [string]: OreDef } = {
	-- Township's own four ores (copper, silver, gold, platinum), kept as they are for continuity.
	-- Copper's 8 Coins and every XP value are the wiki's; the other prices are first-pass.
	CopperOre = { id = "CopperOre", displayName = "Copper Ore", fromDepth = 1, chance = 0.12, sellPrice = 8, xp = 3, order = 1 },
	SilverOre = { id = "SilverOre", displayName = "Silver Ore", fromDepth = 25, chance = 0.06, sellPrice = 12, xp = 4, order = 2 },
	GoldOre = { id = "GoldOre", displayName = "Gold Ore", fromDepth = 75, chance = 0.04, sellPrice = 17, xp = 5, order = 3 },
	PlatinumOre = { id = "PlatinumOre", displayName = "Platinum Ore", fromDepth = 150, chance = 0.025, sellPrice = 25, xp = 6, order = 4 },
}
for _, ore in ores do
	table.freeze(ore)
end

return table.freeze({
	-- Reopening it (Township's Mine: level 21, 3,000 Coins, 1 d 6 h, 128 XP)
	unlockLevel = 21,
	restoreCost = 3000,
	restoreSeconds = 30 * HOUR,
	restoreXp = 128,
	land = 2, -- its hill stands at the East Meadow's north-east end, which must be cleared first

	width = 12, -- cells across the shaft (F01: "about 12 blocks wide")
	-- Hits each block takes with a Pickaxe; Bedrock can't be dug (Township's dirt, stone, rock)
	hits = table.freeze({ Soil = 1, Stone = 2 }),
	-- Stone's share of the blocks grows with depth; Bedrock is rare and never touches another
	-- Bedrock side by side, so it can't wall off the shaft
	stoneShare = table.freeze({ base = 0.15, perRow = 0.002, max = 0.5 }),
	bedrockChance = 0.06,

	ores = table.freeze(ores),
	-- Other finds per dug cell (first-pass): a pile of Coins (Township's 50-350) and a Lost
	-- Lunchbox (a small prize: Pickaxes)
	coinPile = table.freeze({ chance = 0.03, min = 50, max = 350 }),
	lunchbox = table.freeze({ chance = 0.006, pickaxes = 3 }),

	-- Pickaxes: a gift when the Quarry reopens, and a few free at the gate each day (F01; both
	-- first-pass). They live in the Tool Shed with the expansion tools.
	pickaxe = "Pickaxe",
	restoreGift = 30,
	dailyFree = 5,

	digCooldown = 0.15, -- seconds between digs one player can make (server rate limit)
})
