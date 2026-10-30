--[[
	Crop Pop Hearts (lives): starting a level holds a heart, a win gives it back,
	and empty hearts refill one at a time on a timer that keeps running offline.

	Pure maths on a small state table so the client can show the same countdown
	the server enforces. Times are os.time() seconds.
]]

local Hearts = {}

Hearts.MAX = 5 -- Township baseline
Hearts.REFILL_SECONDS = 30 * 60 -- Township baseline: one heart back every 30 minutes (Playrix help centre)

-- Gem packs. Township baseline (township.fandom.com Match-3 page): a full
-- refill of 5 lives for 900 T-cash, only when none are left. 900 / 25 for the
-- 2025 T-cash rescale = 36 Gems. A pack is only sold when it fits.
Hearts.Packs = {
	{ count = 5, gems = 36 },
}

-- Heart gifts between neighbors. Township lets co-op members send lives on
-- request (township.fandom.com Match-3 page) but gives no numbers, so these
-- are first-pass. A gift only fills an empty heart; the rest wait in the box.
Hearts.Gifts = {
	SEND_PER_DAY = 10, -- hearts a player can send each day, one per neighbor
	CLAIM_PER_DAY = 5, -- hearts a player can take from their gift box each day
	BOX_MAX = 20, -- gifts waiting in a box; more are refused until some are claimed
	KEEP_DAYS = 7, -- unclaimed gifts expire after this
}

export type State = {
	count: number,
	updatedAt: number, -- when the current refill countdown started
	unlimitedUntil: number, -- Unlimited Hearts bonus end time (0 = none)
}

function Hearts.new(now: number): State
	return { count = Hearts.MAX, updatedAt = now, unlimitedUntil = 0 }
end

-- Applies any refills earned since updatedAt.
function Hearts.refresh(state: State, now: number)
	if state.count >= Hearts.MAX or now < state.updatedAt then
		-- Full (nothing counting down) or the clock went backwards: restart the countdown.
		state.updatedAt = now
		return
	end
	local gained = (now - state.updatedAt) // Hearts.REFILL_SECONDS
	if gained > 0 then
		state.count = math.min(Hearts.MAX, state.count + gained)
		state.updatedAt = if state.count >= Hearts.MAX then now else state.updatedAt + gained * Hearts.REFILL_SECONDS
	end
end

function Hearts.isUnlimited(state: State, now: number): boolean
	return (state.unlimitedUntil or 0) > now
end

-- Spends a heart to start a level. Returns false if there are none.
-- `taken` is false during Unlimited Hearts (nothing to give back on a win).
function Hearts.take(state: State, now: number): (boolean, boolean)
	Hearts.refresh(state, now)
	if Hearts.isUnlimited(state, now) then
		return true, false
	end
	if state.count <= 0 then
		return false, false
	end
	state.count -= 1
	return true, true
end

function Hearts.give(state: State, amount: number, now: number)
	Hearts.refresh(state, now)
	state.count = math.min(Hearts.MAX, state.count + amount)
	if state.count >= Hearts.MAX then
		state.updatedAt = now
	end
end

-- Seconds until the next heart comes back, or nil when full.
function Hearts.secondsToNext(state: State, now: number): number?
	Hearts.refresh(state, now)
	if state.count >= Hearts.MAX then
		return nil
	end
	return math.max(0, Hearts.REFILL_SECONDS - (now - state.updatedAt))
end

-- Rebuilds a state from saved data, falling back to full hearts if it's malformed.
function Hearts.fromSave(raw: any, now: number): State
	if type(raw) ~= "table" then
		return Hearts.new(now)
	end
	local count, updatedAt, unlimitedUntil = raw.count, raw.updatedAt, raw.unlimitedUntil
	if type(count) ~= "number" or count ~= count or type(updatedAt) ~= "number" then
		return Hearts.new(now)
	end
	return {
		count = math.clamp(math.floor(count), 0, Hearts.MAX),
		updatedAt = math.min(updatedAt, now),
		unlimitedUntil = if type(unlimitedUntil) == "number" then unlimitedUntil else 0,
	}
end

return Hearts
