--[[
	Sound cues for Crop Pop. The board view hands over each animation phase from
	Engine:trySwap as it starts playing it (croppop/src/client/Sfx.luau), and the screen
	hands over a few named moments (a win, a loss, bought moves).

		CropPopCues.phase(phase, popIndex) -> { Cue }
		CropPopCues.event(name)            -> { Cue }

	popIndex counts the Pop phases within one move: 1 for the first match, 2 for the first
	cascade, and so on. Each cascade pops a little higher, so long chains sound like they
	are building up. Phase shapes: croppop/src/shared/Engine.luau.
]]

export type Cue = { sound: string, pitch: number?, delay: number? }

local CropPopCues = {}

local CASCADE_STEP = 2 -- semitones higher per cascade
local CASCADE_MAX = 12 -- an octave up at most

-- A long chain earns a little fanfare on top of the pops: at the 3rd, 5th and 7th pop of
-- one move, each a few semitones higher.
local COMBO_AT: { [number]: number } = { [3] = 0, [5] = 3, [7] = 6 }

local EFFECT_SOUNDS = {
	Spray = "PopSprayer",
	Bomb = "PopBomb",
	Bee = "PopBee",
	Sun = "PopSun",
	Everything = "PopSun",
	Trowel = "PopBooster",
	Grow = "PopWeedGrow", -- a weed spreading onto a tile
	Ooze = "PopMud", -- goo spreading
	Pumpkin = "PopGoal", -- a pumpkin reaching the bottom and being collected
}

function CropPopCues.phase(phase: { [string]: any }, popIndex: number?): { Cue }
	local cues: { Cue } = {}
	local kind = phase.kind
	if kind == "Swap" then
		table.insert(cues, { sound = if phase.ok == false then "PopBad" else "PopSwap" })
		if phase.ok ~= false and phase.combo then
			-- Two power-ups swapped into each other: a bright charge-up before they go off.
			table.insert(cues, { sound = "PopPowerMade", pitch = 5 })
		end
	elseif kind == "Pop" then
		local seen = {}
		local function once(sound: string, cue: Cue?)
			if not seen[sound] then
				seen[sound] = true
				table.insert(cues, cue or { sound = sound })
			end
		end
		for _, effect in phase.effects or {} do
			local sound = EFFECT_SOUNDS[effect.type]
			if sound then
				once(sound)
			end
		end
		-- A tile swallowed by a spreading weed isn't a match.
		local matched = false
		for _, r in phase.removed or {} do
			if r.cause ~= "weed" then
				matched = true
				break
			end
		end
		if matched then
			local step = math.max(0, (popIndex or 1) - 1)
			once("PopMatch", { sound = "PopMatch", pitch = math.min(step * CASCADE_STEP, CASCADE_MAX) })
		end
		-- Weeds come through `bales` with weed = true: hp 0 is a weed pulled, hp 1 one that
		-- just spread there (that one has its "Grow" effect above).
		for _, b in phase.bales or {} do
			if not b.weed then
				once("PopBale")
			elseif (b.hp or 0) == 0 then
				once("PopWeed")
			end
		end
		if #(phase.frost or {}) > 0 then
			once("PopFrost")
		end
		if #(phase.mud or {}) > 0 then
			once("PopMud")
		end
		for _, g in phase.goo or {} do
			if not g.on then
				once("PopMud") -- goo cleared off a cell
				break
			end
		end
		if #(phase.fences or {}) > 0 then
			once("PopBale", { sound = "PopBale", pitch = -3 }) -- a fence knocked down
		end
		if #(phase.clover or {}) > 0 then
			once("PopGoal", { sound = "PopGoal", pitch = 2 }) -- clover planted
		end
		if #(phase.statues or {}) > 0 then
			once("PopFrost", { sound = "PopFrost", pitch = -4 }) -- a statue dug up
		end
		-- The bonus round (leftover moves turned into Seed Sprayers) pays out Coins.
		if phase.bonus then
			once("CoinBig", { sound = "CoinBig", delay = 0.1 })
		elseif matched and popIndex and COMBO_AT[popIndex] then
			once("PopCombo", { sound = "PopCombo", pitch = COMBO_AT[popIndex], delay = 0.08 })
		end
		-- New power-ups land just after the pop (BoardView grows them in after POP_TIME).
		if #(phase.created or {}) > 0 or #(phase.transformed or {}) > 0 then
			once("PopPowerMade", { sound = "PopPowerMade", delay = 0.16 })
		end
	elseif kind == "Shuffle" then
		table.insert(cues, { sound = "PopShuffle" })
	end
	return cues
end

local EVENTS: { [string]: { Cue } } = {
	Win = { { sound = "PopWin" } },
	Lose = { { sound = "PopLose" } },
	MoreMoves = { { sound = "PopMoreMoves" } },
	-- Also played from the board phases; these names are for screens that fire them directly.
	FrostBreak = { { sound = "PopFrost" } },
	WeedSpread = { { sound = "PopWeedGrow" } },
}

function CropPopCues.event(name: string): { Cue }
	return EVENTS[name] or {}
end

return CropPopCues
