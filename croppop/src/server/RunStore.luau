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
]]

local CropPop = require(game:GetService("ReplicatedStorage"):WaitForChild("CropPop"))

local Boosters = CropPop.Boosters
local Hearts = CropPop.Hearts
local Gifts = Hearts.Gifts
local GiftInbox = require(script.Parent.GiftInbox)

local RunStore = {}
RunStore.__index = RunStore

local MIN_START_GAP = 1 -- seconds between level starts per player
local MAX_RUN_SECONDS = 2 * 60 * 60
local SAVE_VERSION = 1
local GIFT_CHECK_SECONDS = 30 -- how often a player's gift box is read again
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
	}
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
	}
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
	for _, kind in preBoosters do
		if (state.boosters[kind] or 0) < 1 then
			return nil, "no " .. Boosters.Info[kind].name
		end
	end
	local clockNow = self.clock()
	if clockNow - record.lastStart < MIN_START_GAP then
		return nil, "too fast"
	end

	local ok, heartTaken = Hearts.take(state.hearts, self.now())
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
		state.boosters[kind] -= 1
		table.insert(startPowerUps, Boosters.Info[kind].power)
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
	return {
		won = true,
		levelId = run.levelId,
		rewards = rewards,
		chest = chest,
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
