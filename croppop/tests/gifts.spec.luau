-- Heart gifts between neighbors: sending, daily limits, the gift box, claiming.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local RunStore = require(game.ServerScriptService.CropPopServer.RunStore)
local GiftInbox = require(game.ServerScriptService.CropPopServer.GiftInbox)
local Hearts = CropPop.Hearts
local Gifts = Hearts.Gifts
local DAY = 24 * 60 * 60

local function makeStore(inbox)
	local t = { now = 100 * DAY + 3600 }
	local store = RunStore.new({
		clock = function()
			return t.now
		end,
		newSeed = function()
			return 1
		end,
		giftInbox = inbox,
		devActions = true,
	})
	return store, t
end

local function emptyHearts(store, userId, count)
	store:devSetHearts(userId, count or 0)
end

test("a sent heart lands in the neighbor's box and can be claimed into an empty heart", function()
	local store = makeStore()
	store:refreshGifts(2) -- player 2 is on this server
	local status = assert(store:sendHeart(1, 2))
	eq(status.left, Gifts.SEND_PER_DAY - 1)
	eq(status.sentTo[1], 2)
	local progress = store:getProgress(2)
	eq(progress.gifts.waiting, 1, "a neighbor on this server sees it right away")
	eq(progress.gifts.claimable, 0, "hearts are full")
	local _, err = store:claimGifts(2)
	eq(err, "hearts are full")

	emptyHearts(store, 2, 3)
	eq(store:getProgress(2).gifts.claimable, 1)
	local result = assert(store:claimGifts(2))
	eq(result.claimed, 1)
	eq(result.from[1], 1)
	eq(result.progress.hearts.count, 4)
	eq(result.progress.gifts.waiting, 0)
	local _, again = store:claimGifts(2)
	eq(again, "no gifts waiting")
end)

test("one heart per neighbor per day, and a daily send limit", function()
	local store, t = makeStore()
	truthy(store:sendHeart(1, 2))
	local _, err = store:sendHeart(1, 2)
	eq(err, "already sent today")
	for to = 3, Gifts.SEND_PER_DAY + 1 do
		truthy(store:sendHeart(1, to))
	end
	_, err = store:sendHeart(1, 999)
	eq(err, "no gifts left today")
	eq(store:giftStatus(1).left, 0)
	t.now += DAY
	eq(store:giftStatus(1).left, Gifts.SEND_PER_DAY, "a new day")
	truthy(store:sendHeart(1, 2))
end)

test("bad targets are refused", function()
	local store = makeStore()
	local _, err = store:sendHeart(1, 1)
	eq(err, "that's you")
	for _, bad in { "2", 0, 1.5, 0 / 0, nil } do
		_, err = store:sendHeart(1, bad)
		eq(err, "no such player")
	end
end)

test("a player whose save hasn't loaded can't send", function()
	local store = RunStore.new({
		clock = function()
			return 0
		end,
		newSeed = function()
			return 1
		end,
		autoLoad = false,
	})
	local _, err = store:sendHeart(1, 2)
	eq(err, "loading")
	store:markLoaded(1)
	truthy(store:sendHeart(1, 2))
end)

test("claiming stops at empty hearts and at the daily claim limit", function()
	local inbox = GiftInbox.memory()
	local store, t = makeStore(inbox)
	for from = 10, 10 + Gifts.CLAIM_PER_DAY + 2 do
		truthy(store:sendHeart(from, 2))
	end
	emptyHearts(store, 2, 2)
	local result = assert(store:claimGifts(2))
	eq(result.claimed, Hearts.MAX - 2)
	eq(result.from[1], 10, "oldest first")
	eq(result.progress.gifts.waiting, Gifts.CLAIM_PER_DAY + 3 - (Hearts.MAX - 2))
	emptyHearts(store, 2, 0)
	result = assert(store:claimGifts(2))
	eq(result.claimed, Gifts.CLAIM_PER_DAY - (Hearts.MAX - 2))
	local _, err = store:claimGifts(2)
	eq(err, "no more gifts today")
	local gifts = store:getProgress(2).gifts
	eq(gifts.claimable, 0)
	truthy(gifts.waiting > 0, "the rest stay in the box")
	t.now += DAY
	emptyHearts(store, 2)
	truthy(store:getProgress(2).gifts.claimable > 0, "more tomorrow")
end)

test("a full box refuses more gifts and gives the sender their slot back", function()
	local store = makeStore()
	for from = 100, 100 + Gifts.BOX_MAX - 1 do
		truthy(store:sendHeart(from, 2))
	end
	local _, err = store:sendHeart(1, 2)
	eq(err, "their gift box is full")
	eq(store:giftStatus(1).left, Gifts.SEND_PER_DAY)
end)

test("a failed write gives the sender their slot back", function()
	local store = makeStore({
		read = function()
			return false, "down"
		end,
		update = function()
			return false, "down"
		end,
	})
	local _, err = store:sendHeart(1, 2)
	eq(err, "couldn't send")
	eq(store:giftStatus(1).left, Gifts.SEND_PER_DAY)
end)

test("gifts reach players on other servers, who see them on the next read", function()
	local inbox = GiftInbox.memory()
	local here, t = makeStore(inbox)
	local there = makeStore(inbox)
	here:refreshGifts(2)
	eq(here:getProgress(2).gifts.waiting, 0)
	truthy(there:sendHeart(1, 2))
	here:refreshGifts(2)
	eq(here:getProgress(2).gifts.waiting, 0, "read again only every so often")
	t.now += 31
	here:refreshGifts(2)
	eq(here:getProgress(2).gifts.waiting, 1)
end)

test("old gifts expire", function()
	local inbox = GiftInbox.memory()
	local store, t = makeStore(inbox)
	truthy(store:sendHeart(1, 2))
	t.now += Gifts.KEEP_DAYS * DAY
	store:refreshGifts(2, true)
	eq(store:getProgress(2).gifts.waiting, 0)
	emptyHearts(store, 2)
	local _, err = store:claimGifts(2)
	eq(err, "no gifts waiting")
end)

test("today's gift counts are saved with the puzzle block", function()
	local store = makeStore()
	truthy(store:sendHeart(1, 2))
	truthy(store:sendHeart(1, 3))
	local block = store:exportSave(1)
	eq(#block.gifts.sentTo, 2)

	local other = makeStore()
	other:importSave(1, block)
	local _, err = other:sendHeart(1, 2)
	eq(err, "already sent today")
	eq(other:giftStatus(1).left, Gifts.SEND_PER_DAY - 2)

	other:importSave(1, { gifts = { day = "x", sentTo = 5 } })
	eq(other:giftStatus(1).left, Gifts.SEND_PER_DAY, "junk is ignored")
end)

test("GiftInbox.clean drops junk and keeps at most a box's worth", function()
	local raw = { 5, { from = 1 }, { from = 2, t = 0 } }
	for i = 1, Gifts.BOX_MAX + 5 do
		table.insert(raw, { from = i, t = 50 })
	end
	local clean = GiftInbox.clean(raw, 100)
	eq(#clean, Gifts.BOX_MAX)
	eq(clean[1].from, 2)
	eq(#GiftInbox.clean("nope", 0), 0)
end)

test("Studio's Dev gift puts a pretend neighbor's heart in your own box", function()
	local store = makeStore()
	local progress = assert(store:devGiftSelf(1))
	eq(progress.gifts.waiting, 1)
	local live = RunStore.new({
		clock = function()
			return 0
		end,
		newSeed = function()
			return 1
		end,
	})
	falsy(live:devGiftSelf(1))
end)
