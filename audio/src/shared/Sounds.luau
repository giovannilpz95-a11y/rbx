--[[
	Every sound the game plays, by name. Code asks for a name (GameAudio.play("Coin")),
	never for an asset id, so swapping a sound is a one-line change here.

	Fields:
	  group      "Ui" | "Effects" | "Music" | "Ambience" (the volume group it plays in)
	  volume     0..1, before the group's volume
	  file       our original sound in audio/sfx/ (made by tools/make_sfx.py)
	  id         its Roblox asset id once uploaded ("rbxassetid://...", from UPLOADED below);
	             nil = not uploaded yet
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
	from Township or any other game. A `fallback` only plays while our original has no `id`.
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

-- Our originals as uploaded to Roblox (Asset Manager Bulk Import, 2026-10-30), by file name.
-- A new original stays silent until its id is added here.
local UPLOADED: { [string]: string } = {
	build_done = "rbxassetid://135822915243709",
	build_hammer = "rbxassetid://98011388214547",
	coin = "rbxassetid://92034233006281",
	coin_big = "rbxassetid://132465275142332",
	crier_bell = "rbxassetid://97009903628185",
	decor_place = "rbxassetid://135327369323464",
	decor_rotate = "rbxassetid://124689663009385",
	factory_collect = "rbxassetid://98052300409599",
	factory_start = "rbxassetid://83041237646576",
	feed = "rbxassetid://134539954450096",
	gem = "rbxassetid://74885315231683",
	harvest = "rbxassetid://122476685681586",
	level_up = "rbxassetid://70509023514051",
	notify = "rbxassetid://82327772327854",
	order_complete = "rbxassetid://88991050102302",
	plant = "rbxassetid://94602308937521",
	pop_bad = "rbxassetid://138039957903949",
	pop_bale = "rbxassetid://110143010930119",
	pop_bee = "rbxassetid://115052258350165",
	pop_bomb = "rbxassetid://74289545366489",
	pop_booster = "rbxassetid://94007754345040",
	pop_frost = "rbxassetid://97888903898587",
	pop_goal = "rbxassetid://86387809153747",
	pop_lose = "rbxassetid://83594292076093",
	pop_match = "rbxassetid://78976345803082",
	pop_more_moves = "rbxassetid://78606861739292",
	pop_mud = "rbxassetid://85252451777094",
	pop_power_made = "rbxassetid://71514177489665",
	pop_shuffle = "rbxassetid://96890358034380",
	pop_sprayer = "rbxassetid://90586269910845",
	pop_sun = "rbxassetid://74092670320353",
	pop_swap = "rbxassetid://115660242019004",
	pop_weed = "rbxassetid://110664100483647",
	pop_weed_grow = "rbxassetid://120777560707717",
	pop_win = "rbxassetid://127886858679552",
	prize_find = "rbxassetid://110651573973982",
	prize_heirloom = "rbxassetid://138042146263086",
	prize_lost = "rbxassetid://115010677705248",
	purchase = "rbxassetid://129766764512149",
	ready = "rbxassetid://138980162763729",
	sell = "rbxassetid://111589037585970",
	tool_drop = "rbxassetid://98141118111168",
	ui_close = "rbxassetid://84831596649210",
	ui_error = "rbxassetid://120097545551630",
	ui_open = "rbxassetid://115558235640896",
	ui_tap = "rbxassetid://110910186206329",
	unlock = "rbxassetid://84936563668471",
	xp = "rbxassetid://99729766738768",
}

local function original(file: string, group: string, volume: number, extra: { [string]: any }?): Sound
	local entry: { [string]: any } =
		{ group = group, volume = volume, file = "sfx/" .. file .. ".ogg", id = UPLOADED[file], source = "Original" }
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
	Purchase = original("purchase", "Effects", 0.7, { cooldown = 1, voices = 1, duck = true, length = 0.95 }),
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
	Dig = original("quarry_dig", "Effects", 0.6, { cooldown = 0.08, voices = 2, length = 0.32 }),
	AirshipHorn = original("airship_horn", "Effects", 0.55, { cooldown = 3, voices = 1, duck = true, length = 1.2 }),
	-- A busy factory's work loop, played from the building itself (client/FactoryHum), so it
	-- fades with distance; GameAudio.attachLoop starts and stops it.
	FactoryHum = original("factory_loop", "Effects", 0.22, { looped = true, voices = 1, length = 2 }),

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
	PopCombo = original("pop_combo", "Effects", 0.6, { cooldown = 0.25, voices = 1, length = 0.68 }),
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
