--[[
	Tracks each player's Crop Pop state on the server: progress, Hearts,
	boosters and the level being played.

	start() takes a heart and any pre-level boosters and hands out a seed;
	finish() replays the client's actions with that seed, charges the in-level
	boosters the replay used, and only reports a win the replay agrees with.
	A win gives the heart back. buyContinue() sells +5 moves for the open run
	once a replay of it so far shows it's out of moves.

	Pure Luau with injectable clocks and Gem spending so it can be tested
	outside Roblox. Saving is done by the farm through exportSave/importSave
	(the `puzzle` block, see 21 Security & Saving).

	Heart gifts: sendHeart() puts a heart in a neighbor's gift box (see
	GiftInbox), and claimGifts() moves gifts from a player's own box into
	their empty hearts. Daily counts live in the puzzle save block.

	Score tracks (see ScoreTracks): a verified win adds its points to the
	running track and pays every step it reaches. Coins and Gems from steps go
	out in the win's rewards (`trackCoins`, `gems`) for the farm to pay; the
	rest (boosters, unlimited hearts, x2 points, free start boosters) lands in
	the save here.

	Harvest Cup (see Cup, CupBoard): a verified win during a cup enters the
	player into a group and adds cups by difficulty. When the cup is over,
	refreshCup() looks up their final place and claimCup() pays the prize.

	Tractor Race (see Race): on race weekends a win puts the player in a
	4-player race (shared through a CupBoard with groups of 4) and counts
	towards its 15 wins; the win that finishes pays the place's prize.
]]

local CropPop = require(game:GetService("ReplicatedStorage"):WaitForChild("CropPop"))

local Boosters = CropPop.Boosters
local Hearts = CropPop.Hearts
local Gifts = Hearts.Gifts
local ScoreTracks = CropPop.ScoreTracks
local GiftInbox = require(script.Parent.GiftInbox)
local CupBoard = require(script.Parent.CupBoard)
local Cup = CropPop.Cup
local Race = CropPop.Race

local RunStore = {}
RunStore.__index = RunStore

local MIN_START_GAP = 1 -- seconds between level starts per player
local MAX_RUN_SECONDS = 2 * 60 * 60
local SAVE_VERSION = 1
local GIFT_CHECK_SECONDS = 30 -- how often a player's gift box is read again
local CUP_CHECK_SECONDS = 30 -- how often the cup standings are read again
local CUP_SHOWN = 10 -- standings rows sent to the client
local DAY = 24 * 60 * 60

export type Config = {
	clock: () -> number, -- monotonic seconds, for rate limits
	now: (() -> number)?, -- wall-clock seconds (os.time), for Hearts; defaults to clock
	newSeed: () -> number,
	-- Charges Gems; returns true only if they were taken. Without it, nothing can be bought.
	spendGems: ((userId: number, amount: number, reason: string) -> boolean)?,
	-- The player's Gem balance, if the farm can tell us; shown so buttons can say "Not enough".
	getGems: ((userId: number) -> number?)?,
	levels: any?, -- defaults to CropPop.Levels
	unlockAll: boolean?, -- Studio testing: skip the "beat the previous level" rule
	devActions: boolean?, -- Studio testing: accept the "Dev: 1 move" action in replays
	-- false: players can't start until importSave/markLoaded (the live server waits for the farm save)
	autoLoad: boolean?,
	-- Where heart gifts wait (see GiftInbox); defaults to an in-memory store.
	giftInbox: any?,
	scoreTracks: boolean?, -- false turns the score tracks off (on by default)
	-- Where Harvest Cup groups and scores live (see CupBoard); defaults to in-memory.
	cupBoard: any?,
	cups: boolean?, -- false turns the Harvest Cup off (on by default)
	raceBoard: any?, -- where Tractor Races live (a CupBoard with groups of 4); defaults to in-memory
	races: boolean?, -- false turns the Tractor Race off (on by default)
	raceEveryDay: boolean?, -- Studio testing: a one-day race weekend every day
}

function RunStore.new(config: Config)
	return setmetatable({
		clock = config.clock,
		now = config.now or config.clock,
		newSeed = config.newSeed,
		spendGems = config.spendGems,
		getGems = config.getGems,
		levels = config.levels or CropPop.Levels,
		unlockAll = config.unlockAll == true,
		devActions = config.devActions == true,
		autoLoad = config.autoLoad ~= false,
		giftInbox = config.giftInbox or GiftInbox.memory(),
		scoreTracks = config.scoreTracks ~= false,
		cupBoard = config.cupBoard or CupBoard.memory(),
		cups = config.cups ~= false,
		raceBoard = config.raceBoard or CupBoard.memory(Race.SIZE),
		races = config.races ~= false,
		raceEveryDay = config.raceEveryDay == true,
		players = {},
	}, RunStore)
end

function RunStore._fresh(self)
	return {
		highestBeaten = 0,
		streak = 0, -- Hot Streak: levels won in a row
		hearts = Hearts.new(self.now()),
		boosters = Boosters.newStock(),
		-- Today's heart gifts: who this player sent to, and how many they claimed.
		gifts = { day = 0, sentTo = {}, claimed = 0 },
		-- The running score track: which one (id + key), its points and the steps paid.
		track = { id = "", key = -1, points = 0, paid = 0 },
		doubleUntil = 0, -- x2 track points until then (wall clock)
		freeStarts = {}, -- pre-level booster kind -> free on every level until then
		-- This cup: group -1 until the first win enters it.
		cup = { key = -1, group = -1, cups = 0, goalPaid = false },
		-- A finished cup the player was in, until its prize is claimed. `place`
		-- and `players` are filled in once the final standings are read.
		pendingCup = nil,
		-- This weekend's race: group -1 until a win enters one. finishedAt and
		-- place are set by the win that finishes it; `over` once others have.
		race = { key = -1, group = -1, wins = 0 },
	}
end

function RunStore._player(self, userId: number)
	local record = self.players[userId]
	if not record then
		record = {
			run = nil,
			lastStart = -math.huge,
			nextToken = 1,
			loaded = self.autoLoad,
			state = self:_fresh(),
			giftsWaiting = 0, -- gifts in this player's box, as last read
			giftsReadAt = -math.huge,
			standings = nil, -- this cup's group standings, as last read
			standingsAt = -math.huge,
			raceStandings = nil, -- the current race, as last read
			raceStandingsAt = -math.huge,
		}
		self.players[userId] = record
	end
	return record
end

-- Saving ---------------------------------------------------------------------

-- The `puzzle` save block.
function RunStore.exportSave(self, userId: number)
	local record = self.players[userId]
	if not record or not record.loaded then
		return nil
	end
	local state = record.state
	return {
		v = SAVE_VERSION,
		highestBeaten = state.highestBeaten,
		-- A level left open (the player quit or dropped mid-level) ends the streak.
		streak = if record.run then 0 else state.streak,
		hearts = table.clone(state.hearts),
		boosters = table.clone(state.boosters),
		gifts = { day = state.gifts.day, sentTo = table.clone(state.gifts.sentTo), claimed = state.gifts.claimed },
		track = table.clone(state.track),
		doubleUntil = state.doubleUntil,
		freeStarts = table.clone(state.freeStarts),
		cup = table.clone(state.cup),
		pendingCup = state.pendingCup and table.clone(state.pendingCup),
		race = table.clone(state.race),
	}
end

local function count(value: any, max: number): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value), 0, max)
end

-- Loads a saved block (nil for a new player). A late load replaces whatever
-- state the player had, including the fresh one from markLoaded.
function RunStore.importSave(self, userId: number, block: any)
	local record = self:_player(userId)
	local state = self:_fresh()
	if type(block) == "table" then
		local highest = block.highestBeaten
		if type(highest) == "number" and highest == highest then
			state.highestBeaten = math.max(0, math.floor(highest))
		end
		local streak = block.streak
		if type(streak) == "number" and streak == streak then
			state.streak = math.clamp(math.floor(streak), 0, 9999)
		end
		state.hearts = Hearts.fromSave(block.hearts, self.now())
		state.boosters = Boosters.fromSave(block.boosters)
		local gifts = block.gifts
		if type(gifts) == "table" and type(gifts.day) == "number" and type(gifts.sentTo) == "table" then
			local sentTo = {}
			for _, id in gifts.sentTo do
				if type(id) == "number" and #sentTo < Gifts.SEND_PER_DAY then
					table.insert(sentTo, id)
				end
			end
			local claimed = if type(gifts.claimed) == "number" and gifts.claimed == gifts.claimed then gifts.claimed else 0
			state.gifts = { day = gifts.day, sentTo = sentTo, claimed = math.clamp(math.floor(claimed), 0, Gifts.CLAIM_PER_DAY) }
		end
		local track = block.track
		if type(track) == "table" and ScoreTracks.Tracks[track.id] and count(track.key, 2 ^ 31) then
			local steps = #ScoreTracks.Tracks[track.id].steps
			state.track = {
				id = track.id,
				key = count(track.key, 2 ^ 31) :: number,
				points = count(track.points, 10 ^ 7) or 0,
				paid = count(track.paid, steps) or 0,
			}
		end
		state.doubleUntil = count(block.doubleUntil, 2 ^ 40) or 0
		if type(block.freeStarts) == "table" then
			for _, kind in Boosters.PreLevel do
				state.freeStarts[kind] = count(block.freeStarts[kind], 2 ^ 40)
			end
		end
		local function cleanCup(raw)
			if type(raw) ~= "table" or not count(raw.key, 2 ^ 31) or type(raw.group) ~= "number" or raw.group ~= raw.group then
				return nil
			end
			return {
				key = count(raw.key, 2 ^ 31) :: number,
				group = math.max(-1, math.floor(raw.group)),
				cups = count(raw.cups, 10 ^ 6) or 0,
				goalPaid = raw.goalPaid == true,
				place = count(raw.place, 10 ^ 6),
				players = count(raw.players, 10 ^ 6),
			}
		end
		state.cup = cleanCup(block.cup) or state.cup
		state.cup.place, state.cup.players = nil, nil
		local pending = cleanCup(block.pendingCup)
		state.pendingCup = if pending and pending.group >= 0 then pending else nil
		local race = block.race
		if type(race) == "table" and count(race.key, 2 ^ 31) and type(race.group) == "number" and race.group == race.group then
			state.race = {
				key = count(race.key, 2 ^ 31) :: number,
				group = math.max(-1, math.floor(race.group)),
				wins = count(race.wins, Race.WINS) or 0,
				finishedAt = count(race.finishedAt, 2 ^ 40),
				place = count(race.place, Race.SIZE),
				racers = count(race.racers, Race.SIZE),
				over = race.over == true,
			}
		end
	end
	record.state = state
	record.run = nil -- a run from before the load belongs to the old state
	record.loaded = true
end

-- Fallback when no save arrives (Studio without the farm): play with a fresh state.
function RunStore.markLoaded(self, userId: number)
	self:_player(userId).loaded = true
end

-- Progress -------------------------------------------------------------------

function RunStore.getProgress(self, userId: number)
	local record = self:_player(userId)
	local state = record.state
	local now = self.now()
	local hearts = state.hearts
	Hearts.refresh(hearts, now)
	return {
		loaded = record.loaded,
		highestBeaten = state.highestBeaten,
		streak = state.streak,
		hotStreakPowers = Boosters.hotStreakPowers(state.streak),
		hearts = {
			count = hearts.count,
			max = Hearts.MAX,
			secondsToNext = Hearts.secondsToNext(hearts, now),
			unlimitedSeconds = math.max(0, (hearts.unlimitedUntil or 0) - now),
		},
		boosters = table.clone(state.boosters),
		canBuy = self.spendGems ~= nil,
		gems = self.getGems and self.getGems(userId) or nil,
		gifts = self:_giftProgress(record),
		track = self:_trackProgress(state, now),
		freeStarts = self:_freeStartsLeft(state, now),
		cup = self:_cupProgress(record, now),
		race = self:_raceProgress(record, now),
	}
end

-- Tractor Race -------------------------------------------------------------------

-- The race weekend running now, if any (every day is one in Studio).
function RunStore._raceWeekend(self, now: number)
	local running = Race.at(now)
	if not running and self.raceEveryDay then
		local today = now // DAY
		running = { key = today, startsAt = today * DAY, endsAt = (today + 1) * DAY }
	end
	return running
end

-- The weekend and this player's race in it, starting over on a new weekend.
function RunStore._race(self, state, now: number)
	local running = self:_raceWeekend(now)
	local key = if running then running.key else -1
	if state.race.key ~= key then
		state.race = { key = key, group = -1, wins = 0 }
	end
	return running, state.race
end

function RunStore._raceProgress(self, record, now: number)
	if not self.races then
		return nil
	end
	local running, race = self:_race(record.state, now)
	if not running then
		return { running = false, secondsToNext = Race.secondsToNext(now) }
	end
	local standings = record.raceStandings
	local current = standings and standings.key == race.key and standings.group == race.group
	return {
		running = true,
		secondsLeft = running.endsAt - now,
		entered = race.group >= 0,
		wins = race.wins,
		target = Race.WINS,
		finished = race.finishedAt ~= nil,
		place = race.place,
		racers = race.racers,
		prize = race.place and Race.prizeFor(race.place, race.racers or 0) or nil,
		over = race.over == true,
		standings = if current then standings.rows else nil,
	}
end

-- Rows of a race board as { userId, wins, finished }, best first.
local function raceRows(list)
	local rows = {}
	for _, row in list do
		local score = if type(row.cups) == "number" then row.cups else 0
		table.insert(rows, { userId = row.userId, wins = Race.winsOf(score), finished = Race.finished(score) })
	end
	return rows
end

--[[
	Counts a win in the player's race, joining a new race first when they
	have none or theirs is done. The win that reaches Race.WINS pays the
	place's prize. May yield (the board). Returns { wins, target, finished,
	place?, racers?, prize? } or nil outside race weekends.
]]
function RunStore._addRaceWin(self, userId: number, state)
	local now = self.now()
	local running, race = self:_race(state, now)
	if not running then
		return nil
	end
	if race.group < 0 or race.finishedAt or race.over then
		local ok, group = self.raceBoard.join(running.key)
		if not ok or type(group) ~= "number" then
			return nil -- try again on the next win
		end
		race = { key = running.key, group = group, wins = 0 }
		state.race = race
	end
	race.wins += 1
	if race.wins >= Race.WINS then
		race.finishedAt = now
	end
	self.raceBoard.setScore(race.key, race.group, userId, Race.score(race.wins, race.finishedAt, running.startsAt))
	self.players[userId].raceStandingsAt = -math.huge
	local out = { wins = race.wins, target = Race.WINS, finished = race.finishedAt ~= nil }
	if race.finishedAt then
		local ok, list, racers = self.raceBoard.top(race.key, race.group, Race.SIZE)
		if ok and type(list) == "table" then
			local place = 0
			for _, row in raceRows(list) do
				if row.finished then
					place += 1
				end
				if row.userId == userId then
					break
				end
			end
			race.place = place
			race.racers = racers or #list
			local prize = Race.prizeFor(place, race.racers)
			if prize then
				self:_payStep(state, prize, {}, now)
			end
			out.place, out.racers, out.prize = place, race.racers, prize
		end
	end
	return out
end

-- Reads the player's race standings (every CUP_CHECK_SECONDS unless forced),
-- and marks the race over once enough others have finished. May yield.
function RunStore.refreshRace(self, userId: number, force: boolean?)
	if not self.races then
		return
	end
	local record = self:_player(userId)
	local running, race = self:_race(record.state, self.now())
	if not running or race.group < 0 then
		return
	end
	local clockNow = self.clock()
	if not force and clockNow - record.raceStandingsAt < CUP_CHECK_SECONDS then
		return
	end
	local ok, list = self.raceBoard.top(race.key, race.group, Race.SIZE)
	if not ok or type(list) ~= "table" then
		return
	end
	local rows = raceRows(list)
	record.raceStandings = { key = race.key, group = race.group, rows = rows }
	record.raceStandingsAt = clockNow
	local finishers = 0
	for _, row in rows do
		if row.finished then
			finishers += 1
		end
	end
	if not race.finishedAt and finishers >= Race.FINISHERS then
		race.over = true
	end
end

-- Harvest Cup ------------------------------------------------------------------

-- The running cup's state; a cup the player was in that has ended waits in pendingCup.
function RunStore._cup(self, state, now: number)
	local running = Cup.at(now)
	if state.cup.key ~= running.key then
		if state.cup.group >= 0 and state.cup.key < running.key then
			state.pendingCup = { key = state.cup.key, group = state.cup.group, cups = state.cup.cups, goalPaid = state.cup.goalPaid }
		end
		state.cup = { key = running.key, group = -1, cups = 0, goalPaid = false }
	end
	return running, state.cup
end

function RunStore._cupProgress(self, record, now: number)
	if not self.cups then
		return nil
	end
	local running, cup = self:_cup(record.state, now)
	local pending = record.state.pendingCup
	local standings = record.standings
	return {
		cups = cup.cups,
		entered = cup.group >= 0,
		goal = Cup.PERSONAL_GOAL,
		goalPaid = cup.goalPaid,
		secondsLeft = running.endsAt - now,
		standings = if standings and standings.key == cup.key then standings else nil,
		-- A finished cup: its place once known, and the prize to claim.
		ended = pending and {
			cups = pending.cups,
			place = pending.place,
			players = pending.players,
			prize = pending.place and Cup.prizeFor(pending.place, pending.players or 0) or nil,
		},
	}
end

-- Adds a win's cups, entering the cup on the first one. May yield (the board).
function RunStore._addCups(self, userId: number, state, difficulty: string?)
	local now = self.now()
	local running, cup = self:_cup(state, now)
	if cup.group < 0 then
		local ok, group = self.cupBoard.join(running.key)
		if not ok or type(group) ~= "number" then
			return nil -- try again on the next win
		end
		cup.group = group
	end
	local gained = Cup.cupsFor(difficulty)
	cup.cups += gained
	self.cupBoard.setScore(running.key, cup.group, userId, cup.cups)
	local goalReached = false
	if not cup.goalPaid and cup.cups >= Cup.PERSONAL_GOAL then
		cup.goalPaid = true
		goalReached = true
		self:_payStep(state, Cup.PersonalPrize, {}, now)
	end
	self.players[userId].standingsAt = -math.huge -- show the new score next time
	return { gained = gained, cups = cup.cups, goalReached = goalReached }
end

-- Reads the cup standings: this cup's group (every CUP_CHECK_SECONDS unless
-- forced), and the final place in a finished cup. May yield.
function RunStore.refreshCup(self, userId: number, force: boolean?)
	if not self.cups then
		return
	end
	local record = self:_player(userId)
	local state = record.state
	local _, cup = self:_cup(state, self.now())
	local pending = state.pendingCup
	if pending and not pending.place then
		local ok, list, players = self.cupBoard.top(pending.key, pending.group, Cup.GROUP_SIZE)
		if ok and type(list) == "table" then
			local place = 0 -- not in the top list
			for i, row in list do
				if row.userId == userId then
					place = i
				end
			end
			pending.place = place
			pending.players = players or #list
		end
	end
	local clockNow = self.clock()
	if cup.group >= 0 and (force or clockNow - record.standingsAt >= CUP_CHECK_SECONDS) then
		local ok, list, players = self.cupBoard.top(cup.key, cup.group, CUP_SHOWN)
		if ok and type(list) == "table" then
			local mine = nil
			for i, row in list do
				if row.userId == userId then
					mine = i
				end
			end
			record.standings = { key = cup.key, rows = list, players = players or #list, place = mine }
			record.standingsAt = clockNow
		end
	end
end

-- Pays a finished cup's prize (if it placed) and clears it. Returns
-- { place, players, prize?, progress } or nil and a reason.
function RunStore.claimCup(self, userId: number)
	local record = self:_player(userId)
	if not record.loaded then
		return nil, "loading"
	end
	local state = record.state
	local pending = state.pendingCup
	if not pending then
		return nil, "no cup to claim"
	end
	if not pending.place then
		return nil, "still counting"
	end
	local prize = Cup.prizeFor(pending.place, pending.players or 0)
	if prize then
		self:_payStep(state, prize, {}, self.now())
	end
	state.pendingCup = nil
	return { place = pending.place, players = pending.players, prize = prize, progress = self:getProgress(userId) }
end

-- Score tracks ---------------------------------------------------------------

-- The running track's state, starting it over when a new track has begun.
function RunStore._track(self, state, now: number)
	local running = ScoreTracks.at(now)
	if state.track.id ~= running.id or state.track.key ~= running.key then
		state.track = { id = running.id, key = running.key, points = 0, paid = 0 }
	end
	return running, state.track
end

function RunStore._trackProgress(self, state, now: number)
	if not self.scoreTracks then
		return nil
	end
	local running, track = self:_track(state, now)
	return {
		id = track.id,
		points = track.points,
		paid = track.paid,
		secondsLeft = running.endsAt - now,
		doubleSeconds = math.max(0, state.doubleUntil - now),
	}
end

-- Seconds left on each free start booster that's running.
function RunStore._freeStartsLeft(self, state, now: number)
	local out = {}
	for kind, untilTime in state.freeStarts do
		if untilTime > now then
			out[kind] = untilTime - now
		end
	end
	return out
end

-- Pays one step's reward. Coins and Gems go into `rewards` for the farm.
function RunStore._payStep(self, state, reward, rewards, now: number)
	if reward.coins then
		rewards.trackCoins = (rewards.trackCoins or 0) + reward.coins
		rewards.coins = (rewards.coins or 0) + reward.coins
	end
	if reward.gems then
		rewards.gems = (rewards.gems or 0) + reward.gems
	end
	for kind, n in reward.boosters or {} do
		state.boosters[kind] = math.min(Boosters.MAX_STOCK, (state.boosters[kind] or 0) + n)
	end
	if reward.unlimitedMinutes then
		state.hearts.unlimitedUntil = math.max(now, state.hearts.unlimitedUntil or 0) + reward.unlimitedMinutes * 60
	end
	if reward.doubleMinutes then
		state.doubleUntil = math.max(now, state.doubleUntil) + reward.doubleMinutes * 60
	end
	local free = reward.freeStart
	if free then
		state.freeStarts[free.kind] = math.max(now, state.freeStarts[free.kind] or 0) + free.minutes * 60
	end
end

--[[
	Adds points to the running track and pays the steps they reach. Returns
	{ id, gained, doubled, points, steps = { step numbers paid } }.
]]
function RunStore._addTrackPoints(self, state, points: number, doubled: boolean, rewards)
	local now = self.now()
	local _, track = self:_track(state, now)
	track.points += points
	local reached = ScoreTracks.stepsReached(track.id, track.points)
	local steps = {}
	local list = ScoreTracks.Tracks[track.id].steps
	for i = track.paid + 1, reached do
		self:_payStep(state, list[i].reward, rewards, now)
		table.insert(steps, i)
	end
	track.paid = math.max(track.paid, reached)
	return { id = track.id, gained = points, doubled = doubled, points = track.points, steps = steps }
end

function RunStore.isUnlocked(self, userId: number, levelId: number): boolean
	return self.unlockAll or levelId <= self:_player(userId).state.highestBeaten + 1
end

-- Runs -----------------------------------------------------------------------

local function cleanPreBoosters(raw: any): ({ string }?, string?)
	if raw == nil then
		return {}, nil
	end
	if type(raw) ~= "table" or #raw > #Boosters.PreLevel then
		return nil, "bad boosters"
	end
	local seen, out = {}, {}
	for _, kind in raw do
		local info = type(kind) == "string" and Boosters.Info[kind]
		if not info or info.when ~= "pre" or seen[kind] then
			return nil, "bad boosters"
		end
		seen[kind] = true
		table.insert(out, kind)
	end
	return out, nil
end

-- Returns { token, levelId, seed, startPowerUps, hotStreak, progress } or nil and a reason.
function RunStore.start(self, userId: number, levelId: any, rawBoosters: any)
	if type(levelId) ~= "number" then
		return nil, "bad level"
	end
	local level = self.levels.get(levelId)
	if not level then
		return nil, "no such level"
	end
	local record = self:_player(userId)
	if not record.loaded then
		return nil, "loading"
	end
	if not self:isUnlocked(userId, levelId) then
		return nil, "level locked"
	end
	local preBoosters, err = cleanPreBoosters(rawBoosters)
	if not preBoosters then
		return nil, err
	end
	local state = record.state
	local now = self.now()
	local free = self:_freeStartsLeft(state, now)
	for _, kind in preBoosters do
		if not free[kind] and (state.boosters[kind] or 0) < 1 then
			return nil, "no " .. Boosters.Info[kind].name
		end
	end
	local clockNow = self.clock()
	if clockNow - record.lastStart < MIN_START_GAP then
		return nil, "too fast"
	end

	local ok, heartTaken = Hearts.take(state.hearts, now)
	if not ok then
		return nil, "no hearts"
	end
	record.lastStart = clockNow

	-- Leaving a level part-way counts as a loss for the Hot Streak.
	if record.run then
		state.streak = 0
	end
	local startPowerUps = {}
	for _, kind in preBoosters do
		if not free[kind] then
			state.boosters[kind] -= 1
		end
	end
	-- Free start boosters from the score track go on every level while they last.
	local freeStarts = {}
	for _, kind in Boosters.PreLevel do
		if free[kind] or table.find(preBoosters, kind) then
			table.insert(startPowerUps, Boosters.Info[kind].power)
		end
		if free[kind] then
			table.insert(freeStarts, kind)
		end
	end
	local hotStreak = Boosters.hotStreakPowers(state.streak)
	for _, power in hotStreak do
		table.insert(startPowerUps, power)
	end

	local token = record.nextToken
	record.nextToken += 1
	-- Starting a new run abandons any open one; its heart stays spent.
	record.run = {
		token = token,
		levelId = levelId,
		seed = self.newSeed(),
		startedAt = clockNow,
		options = { startPowerUps = startPowerUps },
		heartTaken = heartTaken,
		continuesBought = 0,
	}
	return {
		token = token,
		levelId = levelId,
		seed = record.run.seed,
		startPowerUps = startPowerUps,
		hotStreak = hotStreak, -- the free ones among startPowerUps
		freeStarts = freeStarts, -- pre-level boosters given free by the score track
		progress = self:getProgress(userId),
	}
end

--[[
	Closes the open run. Returns { won, levelId, rewards?, firstWin?, progress }
	or nil and a reason. The run is closed whatever the outcome, so an action
	list can only be checked once.
]]
function RunStore.finish(self, userId: number, token: any, rawMoves: any)
	local record = self:_player(userId)
	local run = record.run
	if not run or run.token ~= token then
		return nil, "no open run"
	end
	record.run = nil
	if self.clock() - run.startedAt > MAX_RUN_SECONDS then
		return nil, "run expired"
	end
	local moves, err = CropPop.Replay.sanitize(rawMoves, self.devActions)
	if not moves then
		return nil, err
	end
	local level = self.levels.get(run.levelId)
	local result = CropPop.Replay.run(level, run.seed, moves, run.options)
	if not result.ok then
		return nil, result.reason
	end

	if (result.continues or 0) > run.continuesBought then
		return nil, "used a continue that wasn't paid for"
	end
	local state = record.state
	for kind, used in result.boostersUsed or {} do
		if (state.boosters[kind] or 0) < used then
			return nil, "used a " .. Boosters.Info[kind].name .. " you don't have"
		end
	end
	for kind, used in result.boostersUsed or {} do
		state.boosters[kind] -= used
	end

	if not result.won then
		local lostStreak = state.streak
		state.streak = 0
		return { won = false, levelId = run.levelId, lostStreak = lostStreak, progress = self:getProgress(userId) }
	end
	state.streak += 1
	if run.heartTaken then
		Hearts.give(state.hearts, 1, self.now())
	end
	local firstWin = run.levelId > state.highestBeaten
	if firstWin then
		state.highestBeaten = run.levelId
	end
	local rewards = table.clone(level.rewards)
	rewards.bonusCoins = result.bonusCoins or 0
	rewards.coins = (rewards.coins or 0) + rewards.bonusCoins
	-- A Trail Chest on every 10th level, the first time it's beaten.
	local chest = if firstWin then CropPop.TrailChest.forLevel(run.levelId) else nil
	if chest then
		for kind, count in chest.boosters do
			state.boosters[kind] = math.min(Boosters.MAX_STOCK, (state.boosters[kind] or 0) + count)
		end
		local now = self.now()
		state.hearts.unlimitedUntil = math.max(now, state.hearts.unlimitedUntil or 0) + chest.unlimitedMinutes * 60
		rewards.chestCoins = chest.coins
		rewards.coins += chest.coins
	end
	local cup = if self.cups then self:_addCups(userId, state, level.difficulty) else nil
	local race = if self.races then self:_addRaceWin(userId, state) else nil
	local track
	if self.scoreTracks then
		local _, running = self:_track(state, self.now())
		local doubled = state.doubleUntil > self.now()
		track = self:_addTrackPoints(state, ScoreTracks.pointsFor(running.id, result.stats, doubled), doubled, rewards)
	end
	return {
		won = true,
		levelId = run.levelId,
		rewards = rewards,
		chest = chest,
		track = track,
		cup = cup,
		race = race,
		firstWin = firstWin,
		stats = result.stats,
		progress = self:getProgress(userId),
	}
end

-- Shop -------------------------------------------------------------------------

--[[
	Sells a +5-move continue for the open run. `rawMoves` are the actions so
	far: the replay has to be out of moves with every paid continue used, so a
	continue is never charged by mistake. Returns { continues, progress }.
]]
function RunStore.buyContinue(self, userId: number, token: any, rawMoves: any)
	local record = self:_player(userId)
	local run = record.run
	if not run or run.token ~= token then
		return nil, "no open run"
	end
	local count = run.continuesBought + 1
	if count > Boosters.Continue.MAX_PER_RUN then
		return nil, "no more continues"
	end
	local moves, err = CropPop.Replay.sanitize(rawMoves, self.devActions)
	if not moves then
		return nil, err
	end
	local result = CropPop.Replay.run(self.levels.get(run.levelId), run.seed, moves, run.options)
	if not result.ok then
		return nil, result.reason
	end
	if result.status ~= "Lost" or result.continues ~= run.continuesBought then
		return nil, "not out of moves"
	end
	local step = Boosters.continueStep(count)
	if not self.spendGems or not self.spendGems(userId, step.gems, "CropPop:Continue" .. count) then
		return nil, "not enough Gems"
	end
	run.continuesBought = count
	return { continues = count, progress = self:getProgress(userId) }
end

function RunStore.buyHearts(self, userId: number, packIndex: any)
	local pack = type(packIndex) == "number" and Hearts.Packs[packIndex]
	if not pack then
		return nil, "no such pack"
	end
	local record = self:_player(userId)
	if not record.loaded then
		return nil, "loading"
	end
	local hearts = record.state.hearts
	Hearts.refresh(hearts, self.now())
	if hearts.count >= Hearts.MAX then
		return nil, "hearts are full"
	end
	if pack.count > Hearts.MAX - hearts.count then
		return nil, "that's more hearts than you have room for"
	end
	if not self.spendGems or not self.spendGems(userId, pack.gems, "CropPop:Hearts" .. pack.count) then
		return nil, "not enough Gems"
	end
	Hearts.give(hearts, pack.count, self.now())
	return self:getProgress(userId)
end

function RunStore.buyBooster(self, userId: number, kind: any)
	local info = type(kind) == "string" and Boosters.Info[kind]
	if not info then
		return nil, "no such booster"
	end
	local record = self:_player(userId)
	if not record.loaded then
		return nil, "loading"
	end
	local stock = record.state.boosters
	if (stock[kind] or 0) >= Boosters.MAX_STOCK then
		return nil, "you have plenty"
	end
	if not self.spendGems or not self.spendGems(userId, info.gems, "CropPop:Booster:" .. kind) then
		return nil, "not enough Gems"
	end
	stock[kind] = (stock[kind] or 0) + 1
	return self:getProgress(userId)
end


-- Heart gifts -----------------------------------------------------------------

-- Today's gift counts, starting over each UTC day.
function RunStore._giftDay(self, state)
	local today = self.now() // DAY
	if state.gifts.day ~= today then
		state.gifts = { day = today, sentTo = {}, claimed = 0 }
	end
	return state.gifts
end

-- How many waiting gifts would go into hearts now.
function RunStore._claimable(self, record): number
	local hearts = record.state.hearts
	Hearts.refresh(hearts, self.now())
	local gifts = self:_giftDay(record.state)
	return math.max(0, math.min(record.giftsWaiting, Hearts.MAX - hearts.count, Gifts.CLAIM_PER_DAY - gifts.claimed))
end

function RunStore._giftProgress(self, record)
	local gifts = self:_giftDay(record.state)
	return {
		waiting = record.giftsWaiting,
		claimable = self:_claimable(record),
		claimedToday = gifts.claimed,
		claimPerDay = Gifts.CLAIM_PER_DAY,
		sendLeft = Gifts.SEND_PER_DAY - #gifts.sentTo,
	}
end

-- What the neighbors UI needs: who this player already sent a heart today.
function RunStore.giftStatus(self, userId: number)
	local gifts = self:_giftDay(self:_player(userId).state)
	return {
		sentTo = table.clone(gifts.sentTo),
		left = Gifts.SEND_PER_DAY - #gifts.sentTo,
		perDay = Gifts.SEND_PER_DAY,
	}
end

--[[
	Sends one heart from `fromId` to `toId`'s gift box: once per neighbor per
	day, SEND_PER_DAY a day. The caller checks they're neighbors. May yield
	(the box is a DataStore on live servers). Returns giftStatus or nil and a reason.
]]
function RunStore.sendHeart(self, fromId: number, toId: any)
	if type(toId) ~= "number" or toId ~= toId or toId % 1 ~= 0 or toId == 0 then
		return nil, "no such player"
	end
	if toId == fromId then
		return nil, "that's you"
	end
	local record = self:_player(fromId)
	if not record.loaded then
		return nil, "loading"
	end
	local gifts = self:_giftDay(record.state)
	if table.find(gifts.sentTo, toId) then
		return nil, "already sent today"
	end
	if #gifts.sentTo >= Gifts.SEND_PER_DAY then
		return nil, "no gifts left today"
	end
	-- Hold the slot while the box is written, so a double tap can't send twice.
	table.insert(gifts.sentTo, toId)
	local now = self.now()
	local full = false
	local ok, box = self.giftInbox.update(toId, function(old)
		local live = GiftInbox.clean(old, now)
		full = #live >= Gifts.BOX_MAX
		if full then
			return nil
		end
		table.insert(live, { from = fromId, t = now })
		return live
	end)
	if not ok or full then
		local at = table.find(gifts.sentTo, toId)
		if at then
			table.remove(gifts.sentTo, at)
		end
		return nil, if full then "their gift box is full" else "couldn't send"
	end
	-- A neighbor on this server sees it right away.
	local receiver = self.players[toId]
	if receiver and type(box) == "table" then
		receiver.giftsWaiting = #box
		receiver.giftsReadAt = self.clock()
	end
	return self:giftStatus(fromId)
end

-- Reads this player's gift box again if it's been a while (or `force`). May yield.
function RunStore.refreshGifts(self, userId: number, force: boolean?)
	local record = self:_player(userId)
	if not force and self.clock() - record.giftsReadAt < GIFT_CHECK_SECONDS then
		return
	end
	record.giftsReadAt = self.clock()
	local ok, box = self.giftInbox.read(userId)
	if ok then
		record.giftsWaiting = #GiftInbox.clean(box, self.now())
	end
end

--[[
	Moves waiting gifts into empty hearts, oldest first, up to CLAIM_PER_DAY a
	day. Gifts that don't fit stay in the box. May yield. Returns
	{ claimed, from = { userId }, progress } or nil and a reason.
]]
function RunStore.claimGifts(self, userId: number)
	local record = self:_player(userId)
	if not record.loaded then
		return nil, "loading"
	end
	if record.claiming then
		return nil, "busy"
	end
	local state = record.state
	local gifts = self:_giftDay(state)
	if gifts.claimed >= Gifts.CLAIM_PER_DAY then
		return nil, "no more gifts today"
	end
	Hearts.refresh(state.hearts, self.now())
	local room = math.min(Hearts.MAX - state.hearts.count, Gifts.CLAIM_PER_DAY - gifts.claimed)
	if room <= 0 then
		return nil, "hearts are full"
	end
	local now = self.now()
	local taken = {}
	record.claiming = true
	local ok, box = self.giftInbox.update(userId, function(old)
		local live = GiftInbox.clean(old, now)
		taken = {}
		while #taken < room and #live > 0 do
			table.insert(taken, table.remove(live, 1))
		end
		return if #taken > 0 then live else nil
	end)
	record.claiming = false
	if not ok then
		return nil, "couldn't open the gift box"
	end
	record.giftsReadAt = self.clock()
	if #taken == 0 then
		record.giftsWaiting = #GiftInbox.clean(box, now)
		return nil, "no gifts waiting"
	end
	record.giftsWaiting = if type(box) == "table" then #box else 0
	-- The state may have been replaced by a save load while the box was open.
	state = record.state
	gifts = self:_giftDay(state)
	gifts.claimed = math.min(Gifts.CLAIM_PER_DAY, gifts.claimed + #taken)
	Hearts.give(state.hearts, #taken, self.now())
	local from = {}
	for _, gift in taken do
		table.insert(from, gift.from)
	end
	return { claimed = #taken, from = from, progress = self:getProgress(userId) }
end

-- Studio testing: set the hearts count (the "Dev: 0 hearts" button).
function RunStore.devSetHearts(self, userId: number, count: number)
	if not self.devActions then
		return nil, "not in Studio"
	end
	local hearts = self:_player(userId).state.hearts
	hearts.count = math.clamp(math.floor(count), 0, Hearts.MAX)
	hearts.updatedAt = self.now()
	hearts.unlimitedUntil = 0
	return self:getProgress(userId)
end

-- Studio testing: add `count` of every booster (the "Dev +5🎒" button).
function RunStore.devAddBoosters(self, userId: number, count: number)
	if not self.devActions then
		return nil, "not in Studio"
	end
	local stock = self:_player(userId).state.boosters
	for kind in Boosters.Info do
		stock[kind] = math.clamp((stock[kind] or 0) + math.floor(count), 0, Boosters.MAX_STOCK)
	end
	return self:getProgress(userId)
end

-- Studio testing: track points without playing (the "Dev 🐝" button).
function RunStore.devTrackPoints(self, userId: number, points: number)
	if not self.devActions or not self.scoreTracks then
		return nil, "not in Studio"
	end
	local rewards = { coins = 0 }
	local track = self:_addTrackPoints(self:_player(userId).state, math.floor(points), false, rewards)
	return { track = track, rewards = rewards, progress = self:getProgress(userId) }
end

-- Studio testing: 5 race wins without playing (the T key).
function RunStore.devRace(self, userId: number)
	if not self.devActions or not self.races then
		return nil, "not in Studio"
	end
	local state = self:_player(userId).state
	local last
	for _ = 1, 5 do
		last = self:_addRaceWin(userId, state) or last
		if last and last.finished then
			break
		end
	end
	self:refreshRace(userId, true)
	return { race = last, progress = self:getProgress(userId) }
end

-- Studio testing: "add" scores 10 cups (as 10 Normal wins), "end" ends the
-- player's cup now so the final place and prize can be checked.
function RunStore.devCup(self, userId: number, action: any)
	if not self.devActions or not self.cups then
		return nil, "not in Studio"
	end
	local state = self:_player(userId).state
	if action == "end" then
		local _, cup = self:_cup(state, self.now())
		if cup.group < 0 then
			return nil, "win a level first"
		end
		state.pendingCup = { key = cup.key, group = cup.group, cups = cup.cups, goalPaid = cup.goalPaid }
		state.cup = { key = cup.key, group = -1, cups = 0, goalPaid = false }
	else
		for _ = 1, 10 do
			self:_addCups(userId, state, "Normal")
		end
	end
	self:refreshCup(userId, true)
	return self:getProgress(userId)
end

-- Studio testing: a heart gift from a pretend neighbor (the "Dev 🎁" button).
function RunStore.devGiftSelf(self, userId: number)
	if not self.devActions then
		return nil, "not in Studio"
	end
	local now = self.now()
	local ok = self.giftInbox.update(userId, function(old)
		local live = GiftInbox.clean(old, now)
		if #live >= Gifts.BOX_MAX then
			return nil
		end
		table.insert(live, { from = -1, t = now })
		return live
	end)
	if not ok then
		return nil, "couldn't send"
	end
	self:refreshGifts(userId, true)
	return self:getProgress(userId)
end

function RunStore.forget(self, userId: number)
	self.players[userId] = nil
end

return RunStore
