--[[
	Turns farm state changes into sound cues, so the farm code doesn't need sound calls.
	The farm server sends the owner a whole state snapshot after every change
	(FarmRemotes.State_Snapshot); comparing two snapshots tells us what just happened.

		FarmCues.diff(prev, next, { rewardShown = true }) -> { Cue }
		FarmCues.timed(state, fromTime, toTime)          -> { Cue }  -- things that finished on a timer

	A Cue is { sound = "Harvest", pitch = semitones?, delay = seconds? }. Pure: the tests
	feed it snapshots. Snapshot shape: farm/src/server/Services/NetService.luau snapshot().
]]

export type Cue = { sound: string, pitch: number?, delay: number? }

local FarmCues = {}

local CHAIN_STEP = 0.06 -- seconds between the sounds of a multi-harvest
local CHAIN_MAX = 6 -- at most this many in a row; past that the chain just stops

-- n of the same sound in a quick rising run, like collecting a row of beds.
local function chain(cues: { Cue }, sound: string, n: number, semitoneStep: number)
	for i = 1, math.min(n, CHAIN_MAX) do
		table.insert(cues, { sound = sound, pitch = (i - 1) * semitoneStep, delay = (i - 1) * CHAIN_STEP })
	end
end

local function amount(t: any, key: string): number
	return if type(t) == "table" and type(t[key]) == "number" then t[key] else 0
end

-- `rewardShown`: a Reward_Popup (order delivered, level up) just played its own jingle,
-- so the Coins and Gems that came with it stay quiet.
function FarmCues.diff(prev: { [string]: any }?, nextState: { [string]: any }?, opts: { rewardShown: boolean? }?): { Cue }
	local cues: { Cue } = {}
	if prev == nil or nextState == nil then
		return cues
	end
	local rewardShown = opts ~= nil and opts.rewardShown == true

	-- Fields: an empty bed that now has a crop was planted; a planted one now empty was harvested.
	local planted, harvested = 0, 0
	for id, field in nextState.fields or {} do
		local before = (prev.fields or {})[id]
		if before then
			if before.crop == nil and field.crop ~= nil then
				planted += 1
			elseif before.crop ~= nil and field.crop == nil then
				harvested += 1
			end
		end
	end
	chain(cues, "Harvest", harvested, 2)
	chain(cues, "Plant", planted, 1)

	-- Factories
	local started, collected, buildStarted = 0, 0, 0
	for id, factory in nextState.factories or {} do
		local before = (prev.factories or {})[id]
		if before then
			if not before.built and factory.built then
				buildStarted += 1
			end
			if #(factory.queue or {}) > #(before.queue or {}) then
				started += 1
			end
			if amount(factory, "outputCount") < amount(before, "outputCount") then
				collected += 1
			end
		end
	end
	if buildStarted > 0 then
		table.insert(cues, { sound = "BuildStart" })
	end
	if started > 0 then
		table.insert(cues, { sound = "FactoryStart" })
	end
	chain(cues, "FactoryCollect", collected, 2)

	-- Currencies. Selling from the Barn: items went down and Coins went up.
	local coinsUp = amount(nextState.currencies, "Coins") > amount(prev.currencies, "Coins")
	local gemsUp = amount(nextState.currencies, "Gems") > amount(prev.currencies, "Gems")
	if not rewardShown then
		local itemsDown = false
		for item, qty in prev.inventory or {} do
			if amount(nextState.inventory, item) < qty then
				itemsDown = true
				break
			end
		end
		if coinsUp and itemsDown and started == 0 then
			table.insert(cues, { sound = "Sell" })
		elseif coinsUp then
			table.insert(cues, { sound = "Coin" })
		end
		if gemsUp then
			table.insert(cues, { sound = "Gem" })
		end
	end
	return cues
end

local function crossed(t: number?, fromTime: number, toTime: number): boolean
	return t ~= nil and t > fromTime and t <= toTime
end

-- Timers that ran out between fromTime and toTime (server clock): a factory job finishing
-- and a building finishing construction. Crops ripening stay quiet, since a whole farm of
-- them would chime constantly; the ready bubbles show them.
function FarmCues.timed(state: { [string]: any }?, fromTime: number, toTime: number): { Cue }
	local cues: { Cue } = {}
	if state == nil then
		return cues
	end
	local jobDone, buildDone = false, false
	for _, factory in state.factories or {} do
		if crossed(factory.constructionReadyAt, fromTime, toTime) then
			buildDone = true
		end
		-- Only the head job has a readyAt from the server; the rest follow it back to back.
		local readyAt: number? = nil
		for _, job in factory.queue or {} do
			if job.readyAt then
				readyAt = job.readyAt
			elseif readyAt and job.seconds then
				readyAt = (readyAt :: number) + job.seconds
			else
				break
			end
			if crossed(readyAt, fromTime, toTime) then
				jobDone = true
			end
		end
	end
	if buildDone then
		table.insert(cues, { sound = "BuildDone" })
	end
	if jobDone then
		table.insert(cues, { sound = "Ready" })
	end
	return cues
end

-- Reward_Popup payloads from the farm server ({ kind = "LevelUp" | "Order", ... }).
function FarmCues.popup(payload: { [string]: any }?): { Cue }
	local kind = type(payload) == "table" and payload.kind
	if kind == "LevelUp" then
		return { { sound = "LevelUp" } }
	elseif kind == "Order" then
		return { { sound = "OrderComplete" }, { sound = "Coin", delay = 0.35 } }
	end
	return {}
end

return FarmCues
