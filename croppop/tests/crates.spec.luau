-- Surprise crates: open like a 1-layer bale and leave a power-up (or now and then a hay bale).

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng

local LAYOUT = { "........", "........", "..x..x..", "........", "........", "..x..x..", "........", "........" }

local function crateLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

test("a crate blocks its cell like a bale but isn't one for the goal", function()
	local board = Board.fromLayout(LAYOUT)
	local cell = board:get(3, 3)
	truthy(cell.crate)
	eq(cell.bale, 1)
	truthy(string.find(board:hash(), "X", 1, true))
	eq(Levels.validate(crateLevel()), nil)
	truthy(Levels.validate(crateLevel({ goals = { { kind = "HayBale" } } })), "crates alone don't make a HayBale goal")
end)

test("the Trowel opens a crate and it leaves a power-up or a bale", function()
	local powers, bales = 0, 0
	for seed = 1, 24 do
		local pop = Engine.new(crateLevel(), seed)
		local ok, phases = pop:useBooster("Trowel", 3, 3)
		truthy(ok)
		local cell = pop.board:get(3, 3)
		falsy(cell.crate)
		local opened = false
		for _, phase in phases do
			for _, e in phase.effects or {} do
				opened = opened or e.type == "Crate"
			end
		end
		truthy(opened)
		if cell.bale == 1 then
			bales += 1
		else
			-- The power-up may have fallen or gone off in a cascade; it was created in the Pop phase.
			local made = false
			for _, phase in phases do
				for _, c in phase.created or {} do
					made = made or (c.x == 3 and c.y == 3 and c.piece.power ~= nil)
				end
			end
			truthy(made, "seed " .. seed .. " made a power-up")
			powers += 1
		end
	end
	truthy(powers > bales and bales > 0, "mostly power-ups, sometimes a bale")
end)

test("matches next to a crate open it, and crate levels replay the same", function()
	local level = crateLevel()
	local opened = 0
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 40 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			for _, phase in phases do
				for _, e in phase.effects or {} do
					if e.type == "Crate" then
						opened += 1
					end
				end
			end
			table.insert(swaps, m)
		end
		local again = Engine.new(level, seed)
		for _, m in swaps do
			again:trySwap(m[1], m[2], m[3], m[4])
		end
		eq(again:hash(), pop:hash())
	end
	truthy(opened > 0)
end)
