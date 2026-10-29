-- Hearts: refills over time, taking and giving back, saves.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Hearts = CropPop.Hearts
local REFILL = Hearts.REFILL_SECONDS

test("a new player has full hearts and no countdown", function()
	local h = Hearts.new(1000)
	eq(h.count, Hearts.MAX)
	eq(Hearts.secondsToNext(h, 1000), nil)
end)

test("hearts come back one per refill period, even offline", function()
	local h = Hearts.new(0)
	for _ = 1, 3 do
		truthy(Hearts.take(h, 0))
	end
	eq(h.count, 2)
	eq(Hearts.secondsToNext(h, 0), REFILL)
	Hearts.refresh(h, REFILL - 1)
	eq(h.count, 2)
	Hearts.refresh(h, REFILL)
	eq(h.count, 3)
	eq(Hearts.secondsToNext(h, REFILL + 60), REFILL - 60, "the next countdown continues from the last refill")
	Hearts.refresh(h, 10 * REFILL)
	eq(h.count, Hearts.MAX, "never more than the max")
end)

test("no hearts means no play until one comes back", function()
	local h = Hearts.new(0)
	for _ = 1, Hearts.MAX do
		truthy(Hearts.take(h, 0))
	end
	falsy(Hearts.take(h, 10))
	truthy(Hearts.take(h, REFILL))
end)

test("taking from full starts the countdown then", function()
	local h = Hearts.new(0)
	Hearts.take(h, 5000)
	eq(Hearts.secondsToNext(h, 5000), REFILL)
end)

test("Unlimited Hearts don't use hearts", function()
	local h = Hearts.new(0)
	h.unlimitedUntil = 100
	local ok, taken = Hearts.take(h, 50)
	truthy(ok)
	falsy(taken)
	eq(h.count, Hearts.MAX)
	local _, takenLater = Hearts.take(h, 150)
	truthy(takenLater)
end)

test("giving back caps at the max", function()
	local h = Hearts.new(0)
	Hearts.take(h, 0)
	Hearts.give(h, 3, 0)
	eq(h.count, Hearts.MAX)
end)

test("bad saves fall back to full hearts, odd values are clamped", function()
	eq(Hearts.fromSave(nil, 10).count, Hearts.MAX)
	eq(Hearts.fromSave({ count = "x" }, 10).count, Hearts.MAX)
	eq(Hearts.fromSave({ count = 0 / 0, updatedAt = 1 }, 10).count, Hearts.MAX)
	local h = Hearts.fromSave({ count = 99, updatedAt = 99999 }, 10)
	eq(h.count, Hearts.MAX)
	eq(h.updatedAt, 10, "a save from the future can't skip the timer")
	eq(Hearts.fromSave({ count = -3, updatedAt = 0 }, 10).count, 0)
end)
