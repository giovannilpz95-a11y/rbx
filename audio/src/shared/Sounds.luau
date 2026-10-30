--[[
	Every sound the game plays, by name. Code asks for a name (GameAudio.play("Coin")),
	never for an asset id, so swapping a sound is a one-line change here.

	Fields:
	  group      "Ui" | "Effects" | "Music" | "Ambience" (the volume group it plays in)
	  volume     0..1, before the group's volume
	  file       our original sound in audio/sfx/ (made by tools/make_sfx.py)
	  id         its Roblox asset id once uploaded ("rbxassetid://..."); nil = not uploaded yet
	  fallback   a free licensed Roblox library sound to use until `id` is set (placeholder)
	  source     where the entry's own sound comes from: "Original" (made for this game), or
	             for library-only entries "APM" (APM Music) or "PSE" (Pro Sound Effects), the
	             licensed partners behind Roblox's free audio library
	  cooldown   seconds before the same name can play again (default 0.05)
	  voices     how many copies can overlap (default 2)
	  duck       true: the music dips while this plays (fanfares and jingles)
	  length     rough length in seconds, used for ducking and the voice limit

	Rules (vault: Design/26 Audio Style Guide): only our own sounds or sounds from Roblox's
	licensed library (APM Music, Pro Sound Effects). Nothing ripped, recorded or recreated
	from Township or any other game. Every `fallback` is a placeholder until our original
	is uploaded and has an `id`.
]]

export type Sound = {
	group: string,
	volume: number,
	file: string?,
	id: string?,
	fallback: string?,
	source: string,
	cooldown: number?,
	voices: number?,
	duck: boolean?,
	length: number?,
	looped: boolean?,
}

local function original(file: string, group: string, volume: number, extra: { [string]: any }?): Sound
	local entry: { [string]: any } = { group = group, volume = volume, file = "sfx/" .. file .. ".ogg", source = "Original" }
	for k, v in extra or {} do
		entry[k] = v
	end
	return entry :: any
end

local Sounds: { [string]: Sound } = {
	-- UI ---------------------------------------------------------------------
	UiTap = original("ui_tap", "Ui", 0.45, { cooldown = 0.04, voices = 3, length = 0.07 }),
	UiOpen = original("ui_open", "Ui", 0.45, { length = 0.17 }),
	UiClose = original("ui_close", "Ui", 0.4, { length = 0.17 }),
	UiError = original("ui_error", "Ui", 0.45, { cooldown = 0.3, length = 0.25 }),
	Notify = original("notify", "Ui", 0.5, { cooldown = 0.5, length = 0.39 }),

	-- Rewards ----------------------------------------------------------------
	Coin = original("coin", "Effects", 0.6, { cooldown = 0.08, voices = 3, length = 0.35 }),
	CoinBig = original("coin_big", "Effects", 0.65, { cooldown = 0.3, length = 0.73 }),
	Gem = original("gem", "Effects", 0.6, { cooldown = 0.2, length = 0.63 }),
	Xp = original("xp", "Effects", 0.45, { cooldown = 0.3, length = 0.35 }),
	LevelUp = original("level_up", "Effects", 0.8, {
		fallback = "rbxassetid://9038314266", -- APM "Funfair Fun (sting)", ukulele + accordion, 4 s
		cooldown = 2,
		voices = 1,
		duck = true,
		length = 1.9,
	}),
	OrderComplete = original("order_complete", "Effects", 0.7, { cooldown = 0.5, voices = 1, duck = true, length = 0.97 }),
	Unlock = original("unlock", "Effects", 0.6, { cooldown = 0.5, length = 0.85 }),
	ToolDrop = original("tool_drop", "Effects", 0.6, { cooldown = 0.5, length = 0.6 }),
	PrizeFind = original("prize_find", "Effects", 0.65, { cooldown = 0.5, voices = 1, length = 0.8 }),
	PrizeHeirloom = original("prize_heirloom", "Effects", 0.75, { cooldown = 1, voices = 1, duck = true, length = 1.5 }),
	PrizeLost = original("prize_lost", "Effects", 0.45, { cooldown = 0.5, voices = 1, length = 0.6 }),
	CrierBell = original("crier_bell", "Ui", 0.5, { cooldown = 2, voices = 1, length = 1.2 }),

	-- Farm -------------------------------------------------------------------
	Plant = original("plant", "Effects", 0.55, { cooldown = 0.05, voices = 3, length = 0.16 }),
	Harvest = original("harvest", "Effects", 0.6, { cooldown = 0.05, voices = 3, length = 0.15 }),
	Feed = original("feed", "Effects", 0.5, { cooldown = 0.08, voices = 2, length = 0.25 }),
	Ready = original("ready", "Effects", 0.35, { cooldown = 4, voices = 1, length = 0.59 }),
	BuildStart = original("build_hammer", "Effects", 0.55, { cooldown = 0.5, length = 0.38 }),
	BuildDone = original("build_done", "Effects", 0.65, { cooldown = 1, duck = true, length = 0.96 }),
	FactoryStart = original("factory_start", "Effects", 0.45, { cooldown = 0.2, length = 0.4 }),
	FactoryCollect = original("factory_collect", "Effects", 0.6, { cooldown = 0.1, length = 0.45 }),
	DecorPlace = original("decor_place", "Effects", 0.55, { cooldown = 0.1, length = 0.4 }),
	DecorRotate = original("decor_rotate", "Effects", 0.45, { cooldown = 0.08, length = 0.12 }),
	Sell = original("sell", "Effects", 0.6, { cooldown = 0.1, length = 0.41 }),

	-- Crop Pop -----------------------------------------------------------------
	PopSwap = original("pop_swap", "Effects", 0.45, { cooldown = 0.03, length = 0.11 }),
	PopBad = original("pop_bad", "Effects", 0.45, { cooldown = 0.1, length = 0.22 }),
	PopMatch = original("pop_match", "Effects", 0.6, {
		fallback = "rbxassetid://9112872239", -- PSE "Small Bubbles Water Surface Float Up Pop 5", 1.2 s
		cooldown = 0.03,
		voices = 3,
		length = 0.12,
	}),
	PopPowerMade = original("pop_power_made", "Effects", 0.6, { cooldown = 0.1, length = 0.53 }),
	PopSprayer = original("pop_sprayer", "Effects", 0.6, { cooldown = 0.06, length = 0.32 }),
	PopBomb = original("pop_bomb", "Effects", 0.65, { cooldown = 0.06, length = 0.45 }),
	PopBee = original("pop_bee", "Effects", 0.5, { cooldown = 0.06, length = 0.38 }),
	PopSun = original("pop_sun", "Effects", 0.65, { cooldown = 0.1, length = 0.8 }),
	PopBale = original("pop_bale", "Effects", 0.5, { cooldown = 0.05, length = 0.16 }),
	PopMud = original("pop_mud", "Effects", 0.5, { cooldown = 0.05, length = 0.18 }),
	PopFrost = original("pop_frost", "Effects", 0.5, { cooldown = 0.05, length = 0.25 }),
	PopWeed = original("pop_weed", "Effects", 0.5, { cooldown = 0.05, length = 0.16 }),
	PopWeedGrow = original("pop_weed_grow", "Effects", 0.45, { cooldown = 0.2, length = 0.3 }),
	PopShuffle = original("pop_shuffle", "Effects", 0.5, { cooldown = 0.5, length = 0.47 }),
	PopBooster = original("pop_booster", "Effects", 0.55, { cooldown = 0.1, length = 0.3 }),
	PopMoreMoves = original("pop_more_moves", "Effects", 0.65, { cooldown = 0.5, length = 0.53 }),
	PopGoal = original("pop_goal", "Effects", 0.45, { cooldown = 0.06, length = 0.25 }),
	PopWin = original("pop_win", "Effects", 0.8, {
		fallback = "rbxassetid://1841390412", -- APM "Bouncy Bouncy Sting 1"
		cooldown = 2,
		voices = 1,
		duck = true,
		length = 1.8,
	}),
	PopLose = original("pop_lose", "Effects", 0.7, {
		fallback = "rbxassetid://1841186475", -- APM "Goodnight Mr Uke", ukulele playoff, 3 s
		cooldown = 2,
		voices = 1,
		duck = true,
		length = 1.4,
	}),

	-- Ambience (placeholder until we record or make our own bed) ----------------
	AmbienceFarm = {
		group = "Ambience",
		volume = 0.5,
		fallback = "rbxassetid://9125515534", -- PSE "Easter Morning Exterior": birds, distant cows
		source = "PSE",
		looped = true,
		voices = 1,
	},
}

-- Music: each context plays its tracks in turn with a short gap between them.
-- All placeholders from APM Music (free in Roblox experiences) until we have our own theme
-- (vault: 12 Art & Audio Direction, Open Questions).
local Music: { [string]: { { id: string, name: string, volume: number } } } = {
	Farm = {
		{ id = "rbxassetid://1839578771", name = "Charming View Ukulele (APM)", volume = 0.8 },
		{ id = "rbxassetid://1839993539", name = "Happy Daze (b) (APM)", volume = 0.8 },
	},
	Puzzle = {
		{ id = "rbxassetid://1841083941", name = "Fun Times (APM)", volume = 0.7 },
	},
	Visit = {
		{ id = "rbxassetid://1847657718", name = "Happy Country D (APM)", volume = 0.8 },
	},
}

-- The ambience bed that goes with each music context. Crop Pop has none: the puzzle sits on
-- its own screen, so the farm's birds fade out while it's open.
local ContextAmbience: { [string]: string } = {
	Farm = "AmbienceFarm",
	Visit = "AmbienceFarm",
}

-- Default volume per group (Design/26 Audio Style Guide, "Mix"). First-pass.
local Groups: { [string]: number } = {
	Music = 0.35,
	Ambience = 0.2,
	Effects = 0.75,
	Ui = 0.6,
}

-- The asset that plays now for a sound, or nil while it has none.
local function assetFor(sound: Sound): string?
	return sound.id or sound.fallback
end

return table.freeze({
	list = table.freeze(Sounds),
	music = table.freeze(Music),
	contextAmbience = table.freeze(ContextAmbience),
	groups = table.freeze(Groups),
	assetFor = assetFor,
	MUSIC_GAP = 6, -- seconds of quiet between tracks in a context
	MUSIC_FADE = 1.5, -- crossfade when the context changes
	DUCK_TO = 0.35, -- music level under a fanfare, as a fraction
	MAX_VOICES = 12, -- 12 Art & Audio Direction: sounds playing at once
})
