-- Mailboxes: the first hit opens one, the next takes it away; a letter
-- inside counts for the Letters goal.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", ".l....L.", "........", "........", ".L....l.", "........", "........" }

local function mailLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Letters" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

local function effectsOf(phases, kind)
	local out = {}
	for _, phase in phases do
		for _, e in phase.effects or {} do
			if e.type == kind then
				table.insert(out, e)
			end
		end
	end
	return out
end

test("mailboxes block like 2-layer bales, and the goal counts letters", function()
	local board = Board.fromLayout(LAYOUT)
	local cell = board:get(2, 3)
	eq(cell.bale, 2)
	truthy(cell.mailbox.mail)
	falsy(board:get(7, 3).mailbox.mail)
	falsy(cell.piece)
	truthy(string.find(board:hash(), "L1", 1, true))
	-- The snapshot keeps what's inside a shut mailbox hidden.
	for _, c in board:snapshot() do
		if c.mailbox then
			falsy(c.mailbox.mail)
		end
	end
	local pop = Engine.new(mailLevel(), 1)
	eq(pop.goals:find("Letters").target, 2)
	eq(pop.goals:find("HayBale"), nil)
	eq(Levels.validate(mailLevel()), nil)
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Letters" } } })), "letters goal without letters")
end)

test("the first hit opens a mailbox, the next takes it and its letter", function()
	local pop = Engine.new(mailLevel(), 2)
	local function hit(x, y)
		local wave = { bales = {}, effects = {} }
		pop:_damageBale(wave, pop.board:get(x, y))
		return { wave }
	end
	local opened = effectsOf(hit(2, 3), "Mailbox")
	eq(#opened, 1)
	truthy(opened[1].mail)
	truthy(pop.board:get(2, 3).mailbox.open)
	eq(pop.board:get(2, 3).bale, 1)
	eq(pop.goals:find("Letters").progress, 0)
	eq(#effectsOf(hit(2, 3), "Letter"), 1)
	eq(pop.board:get(2, 3).bale, 0)
	eq(pop.board:get(2, 3).mailbox, nil)
	eq(pop.goals:find("Letters").progress, 1)
	-- An empty one goes the same way, with no letter.
	falsy(effectsOf(hit(7, 3), "Mailbox")[1].mail)
	eq(#effectsOf(hit(7, 3), "Letter"), 0)
	eq(pop.board:get(7, 3).bale, 0)
	eq(pop.goals:find("Letters").progress, 1)
end)

test("matches next to mailboxes open them, and mailbox levels replay the same", function()
	local level = mailLevel({ moves = 30 })
	local opened = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 30 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			opened += #effectsOf(phases, "Mailbox")
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(opened > 0, "matches opened some mailboxes")
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
	truthy(string.find(CropPop.LevelText.write(mailLevel()), '".l....L."', 1, true))
end)
