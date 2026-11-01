--!strict
-- The Tool Trader (Township's Tool Exchange, level 60; Township baseline from the wiki's Tool
-- Exchange and Community Buildings pages). The name, the look and the text are ours.
--
-- Township: from level 60 Community Buildings also need power tools, and the only place to
-- get them is the Tool Exchange (12,000 Coins, Population 7,100, 12 h, 500 XP). It has three
-- offer slots: the first is free, the second costs 8,000 Coins and the third 15,000. Each
-- offer trades building materials for up to 4 tools, about 4 to 6 materials a tool, with no
-- Coins. Taking an offer brings a new one; dumping one brings a new one after an hour (Gems
-- skip the wait). Drills and electric saws come from level 60, jackhammers from 62. Tools sit
-- in the Barn and sell for 200 Coins; they can't be bought or dropped any other way.

local HOUR = 3600

export type ToolDef = {
	id: string,
	displayName: string,
	unlockLevel: number,
	sellPrice: number,
	order: number,
}

-- stylua: ignore
local tools: { [string]: ToolDef } = {
	PowerDrill = { id = "PowerDrill", displayName = "Power Drill", unlockLevel = 60, sellPrice = 200, order = 1 },
	PowerSaw = { id = "PowerSaw", displayName = "Power Saw", unlockLevel = 60, sellPrice = 200, order = 2 },
	Jackhammer = { id = "Jackhammer", displayName = "Jackhammer", unlockLevel = 62, sellPrice = 200, order = 3 },
}
for _, def in tools do
	table.freeze(def)
end

return table.freeze({
	unlockLevel = 60,
	buildCoins = 12000,
	population = 7100,
	buildSeconds = 12 * HOUR,
	buildXp = 500,
	slotCoins = table.freeze({ 0, 8000, 15000 }), -- the first slot comes with the building
	toolsPerOffer = table.freeze({ 2, 4 }), -- { min, max } tools in one offer (Township: up to 4)
	perTool = table.freeze({ 4, 6 }), -- { min, max } materials asked for each tool
	materials = table.freeze({ "Bricks", "Panes", "Planks" }), -- what offers ask for (Glass, Slabs)
	dumpSeconds = 1 * HOUR, -- wait for a new offer after dumping one
	tools = table.freeze(tools),
})
