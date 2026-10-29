--!strict
-- Pure time math, used by the server for truth and by the client for display.
-- Every timer is an absolute os.time() timestamp, so offline time needs no catch-up loop.

local Timer = {}

export type Job = {
	recipe: string,
	seconds: number, -- production time locked in when the job was queued
	qty: number?, -- units the job puts on the tray (feed comes 3 to a batch); 1 when absent
	startedAt: number?,
	readyAt: number?,
}

function Timer.isReady(readyAt: number?, now: number): boolean
	return readyAt ~= nil and now >= readyAt
end

function Timer.remaining(readyAt: number, now: number): number
	return math.max(0, readyAt - now)
end

function Timer.format(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return string.format("%ds", seconds)
end

local function countOutput(output: { [string]: number }): number
	local total = 0
	for _, qty in output do
		total += qty
	end
	return total
end
Timer.countOutput = countOutput

-- Advance a factory queue to `now`. Only the head runs; when it finishes the next job starts
-- at the head's readyAt (not at "now"), so offline time is fully used. When the output tray
-- has no room for a job's output the factory pauses: the job waits unstarted until goods
-- are collected.
function Timer.advanceQueue(queue: { Job }, output: { [string]: number }, now: number, trayCapacity: number)
	local count = countOutput(output)
	while #queue > 0 do
		local head = queue[1]
		if head.startedAt == nil then
			if count + (head.qty or 1) > trayCapacity then
				return
			end
			head.startedAt = now
			head.readyAt = now + head.seconds
		end
		local readyAt = head.readyAt :: number
		if now < readyAt then
			return
		end
		local qty = head.qty or 1
		output[head.recipe] = (output[head.recipe] or 0) + qty
		count += qty
		table.remove(queue, 1)
		local nextJob = queue[1]
		if nextJob and count + (nextJob.qty or 1) <= trayCapacity then
			nextJob.startedAt = readyAt
			nextJob.readyAt = readyAt + nextJob.seconds
		end
	end
end

return Timer
