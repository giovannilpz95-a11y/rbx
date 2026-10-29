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
	-- Pens (shared/Pen): an animal with no readyAt is hungry; fed, it gets one; collected,
	-- it's hungry again.
	local fed, gathered, newAnimals = 0, 0, 0
	for id, pen in nextState.pens or {} do
		local before = (prev.pens or {})[id]
		if before then
			if not before.built and pen.built then
				buildStarted += 1
			end
			local animalsBefore = before.animals or {}
			for i, animal in pen.animals or {} do
				local was = animalsBefore[i]
				if was == nil then
					newAnimals += 1
				elseif was.readyAt == nil and animal.readyAt ~= nil then
					fed += 1
				elseif was.readyAt ~= nil and animal.readyAt == nil then
					gathered += 1
				end
			end
		end
	end

	-- Town (shared/TownRules): a new house or community building is a build starting.
	local town, townBefore = nextState.town, prev.town
	if type(town) == "table" and type(townBefore) == "table" then
		if #(town.houses or {}) > #(townBefore.houses or {}) then
			buildStarted += 1
		end
		for id in town.community or {} do
			if (townBefore.community or {})[id] == nil then
				buildStarted += 1
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
	if fed > 0 then
		table.insert(cues, { sound = "Feed" })
	end
	chain(cues, "FactoryCollect", gathered, 2)
	if newAnimals > 0 then
		table.insert(cues, { sound = "Unlock" })
	end

	-- The tutorial moving to a new step (tutorial.step: 0 = off).
	local stepBefore = amount(prev.tutorial, "step")
	local step = amount(nextState.tutorial, "step")
	if step ~= 0 and step ~= stepBefore then
		table.insert(cues, { sound = "Notify" })
	end

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
-- and a building (factory, pen, house or community building) finishing construction.
-- Crops ripening and animals finishing stay quiet, since a whole farm of them would chime
-- constantly; the ready bubbles show them.
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
	for _, pen in state.pens or {} do
		if crossed(pen.constructionReadyAt, fromTime, toTime) then
			buildDone = true
		end
	end
	local landOpened = false
	for _, plot in state.land or {} do
		if type(plot) == "table" and crossed(plot.readyAt, fromTime, toTime) then
			landOpened = true -- an expansion finished clearing
		end
	end
	local town = state.town
	if type(town) == "table" then
		for _, house in town.houses or {} do
			if crossed(house.readyAt, fromTime, toTime) then
				buildDone = true
			end
		end
		for _, building in town.community or {} do
			if type(building) == "table" and crossed(building.readyAt, fromTime, toTime) then
				buildDone = true
			end
		end
	end
	if buildDone then
		table.insert(cues, { sound = "BuildDone" })
	end
	if jobDone then
		table.insert(cues, { sound = "Ready" })
	end
	if landOpened then
		table.insert(cues, { sound = "Unlock" })
	end
	return cues
end

-- Reward_Popup payloads from the farm server
-- ({ kind = "LevelUp" | "Order" | "Drop" | "Field" | "BarnUpgrade", ... }).
function FarmCues.popup(payload: { [string]: any }?): { Cue }
	local kind = type(payload) == "table" and payload.kind
	if kind == "LevelUp" then
		return { { sound = "LevelUp" } }
	elseif kind == "Order" then
		return { { sound = "OrderComplete" }, { sound = "Coin", delay = 0.35 } }
	elseif kind == "Drop" or kind == "Field" or kind == "BarnUpgrade" then
		return { { sound = "Unlock" } } -- a tool dropped, a new field placed, a bigger Barn
	end
	return {}
end

return FarmCues
