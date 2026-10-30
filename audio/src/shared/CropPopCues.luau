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

local EFFECT_SOUNDS = {
	Spray = "PopSprayer",
	Bomb = "PopBomb",
	Bee = "PopBee",
	Sun = "PopSun",
	Everything = "PopSun",
	Trowel = "PopBooster",
}

function CropPopCues.phase(phase: { [string]: any }, popIndex: number?): { Cue }
	local cues: { Cue } = {}
	local kind = phase.kind
	if kind == "Swap" then
		table.insert(cues, { sound = if phase.ok == false then "PopBad" else "PopSwap" })
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
		if #(phase.removed or {}) > 0 then
			local step = math.max(0, (popIndex or 1) - 1)
			once("PopMatch", { sound = "PopMatch", pitch = math.min(step * CASCADE_STEP, CASCADE_MAX) })
		end
		local balesHit = false
		for _ in phase.bales or {} do
			balesHit = true
			break
		end
		if balesHit then
			once("PopBale")
		end
		if #(phase.mud or {}) > 0 then
			once("PopMud")
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
}

function CropPopCues.event(name: string): { Cue }
	return EVENTS[name] or {}
end

return CropPopCues
