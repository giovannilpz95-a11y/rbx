--!strict
-- Limited-time events (Design/08 Social & Events "Limited-Time Events"; Launch/20 Live Ops &
-- Events §4, §9.3; roadmap week 8 "first seasonal event"). One main event at a time, each with
-- its own token (one data currency, shown under the event's name and icon), a 15-prize track
-- climbed by tokens earned, and an Event Shop of decorations you can only get there. Unspent
-- tokens turn into Coins when the event ends, so nothing is lost.
--
-- Data-driven, as 20 §9.3 asks: an event is switched on by its startsAt/endsAt (UTC) here, so
-- a new event needs config and art, not code. Live Experience Configs come later; until then
-- a schedule change is a publish.
--
-- Decided defaults (tell Giovanni, easy to change):
--   * The first event is the Harvest Fair (08's v1 event; 20 §2 has it rerun every September
--     and run as a soft-launch event). It is not scheduled yet (startsAt 0) because the launch
--     date isn't set; Studio always previews it.
--   * Its loop is the Fair Stand: three crates of goods you can make, each refilled 20 minutes
--     after it's delivered, 16 Ribbons a crate. Daily quest chests, Starfall stars, rainbow
--     chests and Golden Eggs add a few more. About 200 Ribbons a day for an active player
--     (two 25-minute sessions), so the 1,500-Ribbon track finishes in 7-8 days of a 10-day
--     event; a casual player (one 12-minute session) reaches about prize 8 from crates alone.
--   * The last 4 prizes are decorations only (casual players miss looks, not power).
--   * 1 Ribbon = 2 Coins at the end (20 §4.3).

local MIN = 60
local DAY = 86400

export type Reward = {
	coins: number?,
	gems: number?,
	xp: number?,
	heirloomSeeds: number?,
	items: { [string]: number }?, -- Barn items, materials, or tools (to the Tool Shed)
	keepsake: string?, -- an event decoration (keepsakes below), into storage
}

export type Keepsake = {
	id: string, -- the decoration id (Art/EventDecor)
	displayName: string,
	size: { number }, -- tiles, like Config/Decor
	event: string,
}

export type ShopItem = { id: string, price: number, stock: number }

export type EventDef = {
	id: string,
	displayName: string,
	tokenName: string,
	tokenIcon: string,
	startsAt: number, -- unix seconds UTC; 0 = not scheduled
	endsAt: number,
	minLevel: number,
	-- The Fair Stand (format "FairStand"): crates of goods for tokens
	fairStand: {
		slots: number,
		refillSeconds: number, -- after a crate is delivered (or swapped), a new one in this long
		tokens: number, -- per crate
		qtyShare: number, -- a crate asks for this share of the low end of the good's Cargo Blimp range
		minQty: number,
	},
	-- Tokens from other things you do while the event runs
	bonus: { questChest: number, star: number, rainbow: number, goose: number },
	milestones: { { tokens: number, reward: Reward } },
	shop: { ShopItem },
	tokenToCoins: number,
	previewSeconds: number, -- Studio: how long the preview runs from server start
}

local function freezeDeep(t: any): any
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			freezeDeep(v)
		end
	end
	return table.freeze(t)
end

local keepsakes: { [string]: Keepsake } = {
	-- From the Harvest Fair's prize track (the last four prizes)
	RibbonBunting = { id = "RibbonBunting", displayName = "Ribbon Bunting", size = { 1, 1 }, event = "HarvestFair" },
	PrizePieTable = { id = "PrizePieTable", displayName = "Prize Pie Table", size = { 1, 1 }, event = "HarvestFair" },
	PrizePumpkin = { id = "PrizePumpkin", displayName = "Prize Pumpkin", size = { 1, 1 }, event = "HarvestFair" },
	BlueRibbonArch = { id = "BlueRibbonArch", displayName = "Blue Ribbon Arch", size = { 2, 1 }, event = "HarvestFair" },
	-- From its Event Shop
	FairPennant = { id = "FairPennant", displayName = "Fair Pennant Post", size = { 1, 1 }, event = "HarvestFair" },
	JamStall = { id = "JamStall", displayName = "Jam Jar Stall", size = { 1, 1 }, event = "HarvestFair" },
	RibbonScarecrow = {
		id = "RibbonScarecrow",
		displayName = "Ribbon Scarecrow",
		size = { 1, 1 },
		event = "HarvestFair",
	},
	HayWagon = { id = "HayWagon", displayName = "Hay Ride Wagon", size = { 2, 1 }, event = "HarvestFair" },
}

local events: { [string]: EventDef } = {
	HarvestFair = {
		id = "HarvestFair",
		displayName = "Harvest Fair",
		tokenName = "Ribbons",
		tokenIcon = "🎀",
		startsAt = 0,
		endsAt = 0,
		minLevel = 4,
		fairStand = { slots = 3, refillSeconds = 20 * MIN, tokens = 16, qtyShare = 1 / 3, minQty = 2 },
		bonus = { questChest = 20, star = 1, rainbow = 5, goose = 10 },
		-- 15 prizes, 1,500 Ribbons in all (20 §4.4)
		milestones = {
			{ tokens = 50, reward = { coins = 150 } },
			{ tokens = 100, reward = { items = { Shovel = 1 } } },
			{ tokens = 175, reward = { coins = 300 } },
			{ tokens = 250, reward = { heirloomSeeds = 1 } },
			{ tokens = 350, reward = { gems = 5 } },
			{ tokens = 450, reward = { items = { Hinges = 2 } } },
			{ tokens = 550, reward = { coins = 600 } },
			{ tokens = 675, reward = { items = { Axe = 1, Saw = 1 } } },
			{ tokens = 800, reward = { gems = 10 } },
			{ tokens = 925, reward = { heirloomSeeds = 2, xp = 30 } },
			{ tokens = 1050, reward = { coins = 1000, items = { Bricks = 2, Planks = 2 } } },
			{ tokens = 1175, reward = { keepsake = "RibbonBunting" } },
			{ tokens = 1300, reward = { keepsake = "PrizePieTable" } },
			{ tokens = 1400, reward = { keepsake = "PrizePumpkin" } },
			{ tokens = 1500, reward = { keepsake = "BlueRibbonArch" } },
		},
		shop = {
			{ id = "FairPennant", price = 100, stock = 3 },
			{ id = "RibbonBunting", price = 80, stock = 6 },
			{ id = "JamStall", price = 250, stock = 1 },
			{ id = "RibbonScarecrow", price = 300, stock = 1 },
			{ id = "HayWagon", price = 450, stock = 1 },
		},
		tokenToCoins = 2,
		previewSeconds = 10 * DAY,
	},
}

return freezeDeep({
	events = events,
	order = { "HarvestFair" }, -- checked in this order; the first running one is the event
	keepsakes = keepsakes,
	defaultDuration = 10 * DAY,
})
