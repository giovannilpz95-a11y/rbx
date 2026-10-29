--!strict
-- Every saved timestamp goes through here, so tests and the DEV time scale have one hook.

local Clock = {}

local timeScale = 1

function Clock.now(): number
	return os.time()
end

-- Seconds a new timer should run for, after the DEV time scale.
function Clock.duration(seconds: number): number
	return math.max(1, math.floor(seconds * timeScale + 0.5))
end

function Clock.setTimeScale(scale: number)
	timeScale = scale
end

function Clock.getTimeScale(): number
	return timeScale
end

return Clock
