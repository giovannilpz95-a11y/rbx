local CropPopCues = load("CropPopCues")

local function names(cues)
	local out = {}
	for _, c in cues do
		table.insert(out, c.sound)
	end
	return table.concat(out, ",")
end

local function pop(over)
	local p = { kind = "Pop", removed = {}, created = {}, transformed = {}, bales = {}, mud = {}, effects = {} }
	for k, v in over do
		p[k] = v
	end
	return p
end

test("swaps: a good one swooshes, a bad one wobbles", function()
	expect.eq(names(CropPopCues.phase({ kind = "Swap", ok = true }, 0)), "PopSwap")
	expect.eq(names(CropPopCues.phase({ kind = "Swap", ok = false }, 0)), "PopBad")
	expect.eq(names(CropPopCues.phase({ kind = "Swap", ok = true, combo = true }, 0)), "PopSwap")
end)

test("each cascade pops higher, up to an octave", function()
	local p = pop({ removed = { { id = 1, x = 1, y = 1 } } })
	expect.eq(CropPopCues.phase(p, 1)[1].pitch, 0)
	expect.eq(CropPopCues.phase(p, 2)[1].pitch, 2)
	expect.eq(CropPopCues.phase(p, 4)[1].pitch, 6)
	expect.eq(CropPopCues.phase(p, 20)[1].pitch, 12)
end)

test("power-ups, obstacles and new power-ups each sound once", function()
	local p = pop({
		removed = { { id = 1 }, { id = 2 } },
		effects = { { type = "Bomb" }, { type = "Bomb" }, { type = "Spray" }, { type = "Bee" } },
		bales = { { x = 1, y = 1, hp = 1 } },
		mud = { { x = 2, y = 2, layers = 0 } },
		created = { { piece = {}, x = 1, y = 1 } },
	})
	expect.eq(names(CropPopCues.phase(p, 1)), "PopBomb,PopSprayer,PopBee,PopMatch,PopBale,PopMud,PopPowerMade")
end)

test("Sunflower, its combo and the Trowel", function()
	expect.eq(names(CropPopCues.phase(pop({ effects = { { type = "Sun" } } }), 1)), "PopSun")
	expect.eq(names(CropPopCues.phase(pop({ effects = { { type = "Everything" } } }), 1)), "PopSun")
	expect.eq(names(CropPopCues.phase(pop({ effects = { { type = "Trowel" } } }), 1)), "PopBooster")
end)

test("shuffles and drops", function()
	expect.eq(names(CropPopCues.phase({ kind = "Shuffle", moves = {} }, 0)), "PopShuffle")
	expect.eq(names(CropPopCues.phase({ kind = "Drop", moves = {}, spawns = {} }, 1)), "")
end)

test("moments", function()
	expect.eq(names(CropPopCues.event("Win")), "PopWin")
	expect.eq(names(CropPopCues.event("Lose")), "PopLose")
	expect.eq(names(CropPopCues.event("MoreMoves")), "PopMoreMoves")
	expect.eq(names(CropPopCues.event("Nope")), "")
end)
