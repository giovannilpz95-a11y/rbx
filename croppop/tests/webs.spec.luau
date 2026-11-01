-- Webs: hold a tile in place and out of matches; only a blast clears the web.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local Levels, Engine, Board, Rng, Matcher = CropPop.Levels, CropPop.Engine, CropPop.Board, CropPop.Rng, CropPop.Matcher

local LAYOUT = { "........", "........", "..n..n..", "........", "........", "..n..n..", "........", "........" }

local function webLevel(fields)
	local level = Helpers.level({ layout = LAYOUT, goals = { { kind = "Webs" } }, moves = 40 })
	for k, v in fields or {} do
		level[k] = v
	end
	return level
end

test("a webbed tile can't move or match, and the goal counts webs", function()
	local pop = Engine.new(webLevel(), 1)
	local cell = pop.board:get(3, 3)
	truthy(cell.web)
	truthy(cell.piece)
	falsy(Board.isMovable(cell))
	falsy(pop:canSwap(3, 3, 4, 3))
	eq(Matcher.colorAt(pop.board, 3, 3), 0)
	truthy(string.find(pop.board:hash(), "*", 1, true))
	eq(pop.goals:find("Webs").target, 4)
	eq(Levels.validate(webLevel()), nil)
	truthy(Levels.validate(Helpers.level({ goals = { { kind = "Webs" } } })), "webs goal without webs")
end)

test("a blast clears the web and leaves the tile", function()
	local pop = Engine.new(webLevel(), 2)
	local cell = pop.board:get(3, 3)
	local id = cell.piece.id
	local ok, phases = pop:useBooster("Trowel", 3, 3)
	truthy(ok)
	falsy(cell.web)
	local cleared = false
	for _, phase in phases do
		for _, wb in phase.webs or {} do
			cleared = cleared or (wb.x == 3 and wb.y == 3)
		end
	end
	truthy(cleared)
	eq(pop.goals:find("Webs").progress, 1)
	-- The tile stayed (unless a cascade took it afterwards, which the first wave can't).
	local removedFirst = false
	for _, r in phases[1].removed or {} do
		removedFirst = removedFirst or r.id == id
	end
	falsy(removedFirst, "the blast only clears the web")
end)

test("matches never clear a web, and web levels replay the same", function()
	local level = webLevel()
	for seed = 1, 4 do
		local pop = Engine.new(level, seed)
		local rng = Rng.new(seed)
		local swaps = {}
		while pop.status == "Playing" and #swaps < 40 do
			local m = rng:pick(pop:listPossibleMoves())
			local _, phases = pop:trySwap(m[1], m[2], m[3], m[4])
			for _, phase in phases do
				if phase.kind == "Pop" and #(phase.webs or {}) > 0 then
					local blast = false
					for _, e in phase.effects do
						blast = blast or e.type == "Spray" or e.type == "Bomb" or e.type == "Bee" or e.type == "Sun" or e.type == "Everything"
					end
					truthy(blast, "a web cleared without a blast")
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
	eq(CropPop.Bot.play(level, 6, 1).games, 6)
end)
