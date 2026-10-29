--[[
	Decides whether a sound may start now: a per-name cooldown, a per-name voice limit
	and a cap on everything playing at once. Pure (the caller passes the clock), so the
	tests can drive it.

		local mixer = Mixer.new(12)
		if mixer:tryStart("Coin", sound, now) then ... play it ... end
]]

local Mixer = {}
Mixer.__index = Mixer

local DEFAULT_COOLDOWN = 0.05
local DEFAULT_VOICES = 2
local DEFAULT_LENGTH = 0.5

export type Mixer = typeof(setmetatable(
	{} :: { maxVoices: number, lastStart: { [string]: number }, playing: { { name: string, endsAt: number } } },
	Mixer
))

function Mixer.new(maxVoices: number): Mixer
	return setmetatable({ maxVoices = maxVoices, lastStart = {}, playing = {} }, Mixer)
end

function Mixer._prune(self: Mixer, now: number)
	local playing = self.playing
	for i = #playing, 1, -1 do
		if playing[i].endsAt <= now then
			table.remove(playing, i)
		end
	end
end

function Mixer.count(self: Mixer, now: number, name: string?): number
	self:_prune(now)
	if name == nil then
		return #self.playing
	end
	local n = 0
	for _, p in self.playing do
		if p.name == name then
			n += 1
		end
	end
	return n
end

-- Looped sounds (music, ambience) don't go through the mixer.
function Mixer.tryStart(self: Mixer, name: string, sound: { [string]: any }, now: number): boolean
	local last = self.lastStart[name]
	if last and now - last < (sound.cooldown or DEFAULT_COOLDOWN) then
		return false
	end
	if self:count(now, name) >= (sound.voices or DEFAULT_VOICES) then
		return false
	end
	if #self.playing >= self.maxVoices then
		return false
	end
	self.lastStart[name] = now
	table.insert(self.playing, { name = name, endsAt = now + (sound.length or DEFAULT_LENGTH) })
	return true
end

return Mixer
