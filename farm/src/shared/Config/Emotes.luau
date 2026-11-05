--!strict
-- Farm emotes and photo spots (Design/14 Multiplayer Features I1, I2; roadmap week 4: "6 farm
-- emotes + 2 photo spots"). Each emote is one of Roblox's standard R15 emote animations (the
-- same ones the default /e emotes use) with a farm prop of our own in hand or on the head for
-- a few seconds, which everyone on the server sees. The props are ours; the animations are
-- Roblox's stock ones, so nothing here needs an upload.

export type Emote = {
	id: string,
	displayName: string,
	icon: string,
	animation: string, -- a stock R15 emote animation
	prop: string, -- Art/EmoteProps
	order: number,
}

local WAVE = "rbxassetid://507770239"
local POINT = "rbxassetid://507770453"
local CHEER = "rbxassetid://507770677"
local LAUGH = "rbxassetid://507770818"
local DANCE = "rbxassetid://507771019"
local DANCE2 = "rbxassetid://507776043"

-- stylua: ignore
local emotes: { [string]: Emote } = {
	TipHat = { id = "TipHat", displayName = "Tip your hat", icon = "👒", animation = WAVE, prop = "StrawHat", order = 1 },
	CarrotThumbs = { id = "CarrotThumbs", displayName = "Carrot salute", icon = "🥕", animation = POINT, prop = "Carrot", order = 2 },
	CrateLift = { id = "CrateLift", displayName = "Lift a crate", icon = "📦", animation = CHEER, prop = "Crate", order = 3 },
	ChickenDance = { id = "ChickenDance", displayName = "Chicken dance", icon = "🐔", animation = DANCE, prop = "Chick", order = 4 },
	HarvestJig = { id = "HarvestJig", displayName = "Harvest jig", icon = "🌾", animation = DANCE2, prop = "Wheat", order = 5 },
	HayLaugh = { id = "HayLaugh", displayName = "Hay day laugh", icon = "😄", animation = LAUGH, prop = "HayPuff", order = 6 },
}

return table.freeze({
	emotes = table.freeze(emotes),
	seconds = 3.5, -- how long the prop stays (and the animation plays)
	cooldown = 4, -- seconds between emotes, per player (server-checked)

	-- Photo spots in the Town Square: stand in the frame and press Group pose; everyone in
	-- the frame cheers together and the presser's game offers a Roblox capture
	photoSpots = table.freeze({
		Pumpkin = table.freeze({ displayName = "Giant Pumpkin", order = 1 }),
		Throne = table.freeze({ displayName = "Hay-Bale Throne", order = 2 }),
	}),
	photoRadius = 14, -- studs from the spot that count as in the frame
	photoCooldown = 8,
	photoEmote = "CrateLift", -- the pose everyone strikes (cheer, with a crate overhead)
})
