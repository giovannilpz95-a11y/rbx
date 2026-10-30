--[[
	Crop Pop's sound hooks. Forwards board phases and a few moments to the shared
	GameAudio module (ReplicatedStorage.GameAudio, from the repo's audio/ project) when
	it's in the place, and does nothing when it isn't (the tests, or Crop Pop on its own).

		Sfx.phase(phase, popIndex)   -- BoardView, as each phase starts animating
		Sfx.event("Win")             -- Open, Close, Win, Lose, MoreMoves
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sfx = {}

local audio = nil -- the GameAudio module, false once we know it isn't there

local function get()
	if audio == nil then
		local module = ReplicatedStorage:FindFirstChild("GameAudio")
		if module == nil then
			return nil -- may still be loading; look again next time
		end
		local ok, result = pcall(require, module)
		audio = if ok then result else false
	end
	return audio or nil
end

function Sfx.phase(phase, popIndex: number)
	local a = get()
	if a then
		a.cropPopPhase(phase, popIndex)
	end
end

function Sfx.event(name: string)
	local a = get()
	if a then
		a.cropPopEvent(name)
	end
end

return Sfx
