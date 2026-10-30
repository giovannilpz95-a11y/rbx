local Mixer = load("Mixer")

test("a cooldown stops the same sound restarting too soon", function()
	local m = Mixer.new(12)
	local s = { cooldown = 0.1, voices = 5, length = 0.05 }
	expect.truthy(m:tryStart("Coin", s, 0))
	expect.falsy(m:tryStart("Coin", s, 0.05))
	expect.truthy(m:tryStart("Coin", s, 0.11))
end)

test("a sound can't overlap itself more than its voices", function()
	local m = Mixer.new(12)
	local s = { cooldown = 0, voices = 2, length = 1 }
	expect.truthy(m:tryStart("Pop", s, 0))
	expect.truthy(m:tryStart("Pop", s, 0.01))
	expect.falsy(m:tryStart("Pop", s, 0.02))
	expect.truthy(m:tryStart("Pop", s, 1.01), "the first one has ended")
end)

test("no more than the cap play at once", function()
	local m = Mixer.new(3)
	local s = { cooldown = 0, voices = 1, length = 1 }
	expect.truthy(m:tryStart("A", s, 0))
	expect.truthy(m:tryStart("B", s, 0))
	expect.truthy(m:tryStart("C", s, 0))
	expect.falsy(m:tryStart("D", s, 0))
	expect.eq(m:count(0), 3)
	expect.truthy(m:tryStart("D", s, 1.5))
end)

test("defaults apply when a sound sets nothing", function()
	local m = Mixer.new(12)
	expect.truthy(m:tryStart("X", {}, 0))
	expect.falsy(m:tryStart("X", {}, 0.01), "default cooldown")
	expect.truthy(m:tryStart("X", {}, 0.06))
	expect.falsy(m:tryStart("X", {}, 0.12), "default 2 voices")
end)
