-- Matching, power-ups, combos, obstacles, goals and move rules.

local eq, truthy, falsy = expect.eq, expect.truthy, expect.falsy
local engine, phase, removedAt = Helpers.engine, Helpers.phase, Helpers.removedAt

local X8 = "x x x x x x x x"

local function rows(top)
	local out = table.clone(top)
	while #out < 8 do
		table.insert(out, X8)
	end
	return out
end

test("three in a row pops and uses a move", function()
	local pop = engine(nil, rows({
		"1 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	local ok, phases = pop:trySwap(3, 2, 3, 1)
	truthy(ok)
	local first = phase(phases, "Pop")
	local set, count = removedAt(first)
	eq(count, 3)
	truthy(set["1,1"] and set["2,1"] and set["3,1"])
	eq(#first.created, 0)
	eq(pop.movesLeft, 29)
	eq(pop.goals.list[1].progress >= 3, true)
end)

test("a swap that matches nothing is undone and costs no move", function()
	local pop = engine(nil, rows({}))
	local before = pop:hash()
	local ok, phases = pop:trySwap(1, 1, 2, 1)
	falsy(ok)
	eq(#phases, 1)
	eq(phases[1].ok, false)
	eq(pop.movesLeft, 30)
	eq(pop:hash(), before)
end)

test("only neighbouring tiles can swap", function()
	local pop = engine(nil, rows({}))
	falsy(pop:canSwap(1, 1, 3, 1))
	falsy(pop:canSwap(1, 1, 2, 2))
	falsy(pop:canSwap(1, 1, 0, 1))
	truthy(pop:canSwap(1, 1, 1, 2))
end)

test("four in a row makes a row Seed Sprayer where the tile was moved", function()
	local pop = engine(nil, rows({
		"1 1 2 1 x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local created = phase(phases, "Pop").created
	eq(#created, 1)
	eq(created[1].piece.power, "SprayerRow")
	eq(created[1].piece.color, 1)
	eq(created[1].x, 3)
	eq(created[1].y, 1)
end)

test("four in a column makes a column Seed Sprayer", function()
	local pop = engine(nil, rows({
		"1 x x x x x x x",
		"1 x x x x x x x",
		"2 1 x x x x x x",
		"1 x x x x x x x",
	}))
	local _, phases = pop:trySwap(2, 3, 1, 3)
	local created = phase(phases, "Pop").created
	eq(created[1].piece.power, "SprayerColumn")
	eq(created[1].x, 1)
	eq(created[1].y, 3)
end)

test("five in a row makes a Sunflower", function()
	local pop = engine(nil, rows({
		"1 1 2 1 1 x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local created = phase(phases, "Pop").created
	eq(created[1].piece.power, "Sunflower")
	eq(created[1].piece.color, 0)
end)

test("an L shape makes a Hay Bomb", function()
	local pop = engine(nil, rows({
		"1 1 2 1 x x x x",
		"x x 1 x x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(4, 1, 3, 1)
	local first = phase(phases, "Pop")
	local _, count = removedAt(first)
	eq(count, 5)
	eq(first.created[1].piece.power, "HayBomb")
	eq(first.created[1].x, 3)
end)

test("a T shape makes a Hay Bomb", function()
	local pop = engine(nil, rows({
		"3 1 2 x x x x x",
		"1 2 1 x x x x x",
		"x 1 x x x x x x",
		"x 1 x x x x x x",
	}))
	local _, phases = pop:trySwap(2, 1, 2, 2)
	local first = phase(phases, "Pop")
	eq(first.created[1].piece.power, "HayBomb")
	eq(first.created[1].x, 2)
	eq(first.created[1].y, 2)
end)

test("a 2x2 square makes a Bumblebee", function()
	local pop = engine(nil, rows({
		"1 1 x x x x x x",
		"1 2 x x x x x x",
		"x 1 x x x x x x",
	}))
	local _, phases = pop:trySwap(2, 3, 2, 2)
	local first = phase(phases, "Pop")
	local _, count = removedAt(first)
	eq(count, 4)
	eq(first.created[1].piece.power, "Bumblebee")
	eq(first.created[1].x, 2)
	eq(first.created[1].y, 2)
end)

test("a row Seed Sprayer in a match clears its whole row", function()
	local pop = engine(nil, rows({
		"x x x x x x x x",
		"1r 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 3, 3, 2)
	local first = phase(phases, "Pop")
	local set = removedAt(first)
	for x = 1, 8 do
		truthy(set[x .. ",2"], "row cell " .. x)
	end
	eq(first.effects[1].type, "Spray")
	eq(first.effects[1].dir, "Row")
end)

test("a column Seed Sprayer clears its whole column", function()
	local pop = engine(nil, rows({
		"1c 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local set = removedAt(phase(phases, "Pop"))
	for y = 1, 8 do
		truthy(set["1," .. y], "column cell " .. y)
	end
end)

test("a Hay Bomb clears a diamond around it", function()
	local pop = engine(nil, rows({
		"x x x x x x x x",
		"x x x x x x x x",
		"x x x x x x x x",
		"x x 1h 1 2 x x x",
		"x x x x 1 x x x",
	}))
	local _, phases = pop:trySwap(5, 5, 5, 4)
	local set = removedAt(phase(phases, "Pop"))
	truthy(set["3,2"] and set["1,4"] and set["3,6"] and set["2,5"], "cells two steps away")
	falsy(set["1,2"], "corner three steps away")
end)

test("a Bumblebee in a match flies to a hay bale when bales are a goal", function()
	local pop = engine({
		layout = { "........", "........", "........", "........", "........", "........", "........", ".......1" },
		goals = { { kind = "HayBale" } },
	}, {
		"1b 1 2 x x x x x",
		"x x 1 x x x x x",
		X8,
		X8,
		X8,
		X8,
		X8,
		"x x x x x x x B1",
	})
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local first = phase(phases, "Pop")
	local bee
	for _, effect in first.effects do
		if effect.type == "Bee" then
			bee = effect
		end
	end
	truthy(bee, "bee effect")
	eq(bee.toX, 8)
	eq(bee.toY, 8)
	eq(pop.board:get(8, 8).bale, 0)
	eq(pop.status, "Won")
end)

test("Sunflower swapped with a tile clears every tile of that colour", function()
	local pop = engine(nil, rows({
		"S 2 x x x x x x",
		"x x x x x x x x",
		"x x 2 x x 2 x x",
		"x x x x x x x x",
		"2 x x x x x x 2",
	}))
	local _, phases = pop:trySwap(1, 1, 2, 1)
	local first = phase(phases, "Pop")
	local set, count = removedAt(first)
	eq(count, 6) -- five tiles plus the Sunflower
	truthy(set["3,3"] and set["6,3"] and set["1,5"] and set["8,5"] and set["2,1"])
	eq(pop.movesLeft, 29)
end)

test("Sprayer + Sprayer clears a cross", function()
	local pop = engine(nil, rows({
		"x x x x x x x x",
		"x x x x x x x x",
		"x x 1r 2c x x x x",
	}))
	local _, phases = pop:trySwap(3, 3, 4, 3)
	local set = removedAt(phase(phases, "Pop"))
	for i = 1, 8 do
		truthy(set[i .. ",3"], "row " .. i)
		truthy(set["4," .. i], "column " .. i)
	end
	falsy(set["1,1"])
	eq(pop.stats.combos, 1)
end)

test("Sprayer + Hay Bomb clears three rows and three columns", function()
	local pop = engine(nil, rows({
		"x x x x x x x x",
		"x x x x x x x x",
		"x x x x x x x x",
		"x x x 1h 2r x x x",
	}))
	local _, phases = pop:trySwap(4, 4, 5, 4)
	local set, count = removedAt(phase(phases, "Pop"))
	eq(count, 8 * 3 + 8 * 3 - 9)
	truthy(set["1,3"] and set["8,5"] and set["4,1"] and set["6,8"])
	falsy(set["1,1"])
end)

test("Hay Bomb + Hay Bomb makes a big blast", function()
	local pop = engine(nil, rows({
		"x x x x x x x x",
		"x x x x x x x x",
		"x x x x x x x x",
		"x x x 1h 2h x x x",
	}))
	local _, phases = pop:trySwap(4, 4, 5, 4)
	local set = removedAt(phase(phases, "Pop"))
	truthy(set["1,4"] and set["5,8"] and set["5,1"], "four steps away")
	falsy(set["1,8"], "eight steps away")
end)

test("Bumblebee + Bumblebee sends three bees", function()
	local pop = engine(nil, rows({
		"x x x x x x x x",
		"x x x 1b 2b x x x",
	}))
	local _, phases = pop:trySwap(4, 2, 5, 2)
	local bees = 0
	for _, effect in phase(phases, "Pop").effects do
		if effect.type == "Bee" then
			bees += 1
		end
	end
	eq(bees, 3)
end)

test("Bumblebee + Sprayer carries the sprayer to its target", function()
	local pop = engine(nil, rows({
		"x x x x x x x x",
		"x x x 1b 2r x x x",
	}))
	local _, phases = pop:trySwap(4, 2, 5, 2)
	local effects = phase(phases, "Pop").effects
	eq(effects[1].type, "Bee")
	eq(effects[1].payload, "SprayerRow")
	eq(effects[2].type, "Spray")
	eq(effects[2].y, effects[1].toY)
end)

test("Sunflower + Sunflower clears the whole board", function()
	local pop = engine(nil, rows({
		"x x x x x x x x",
		"x x x S S x x x",
	}))
	local _, phases = pop:trySwap(4, 2, 5, 2)
	local _, count = removedAt(phase(phases, "Pop"))
	eq(count, 64)
end)

test("Sunflower + Sprayer turns that colour into sprayers", function()
	local pop = engine(nil, rows({
		"1 x x x x x x x",
		"x x x S 2r x x x",
		"x x x x x x x x",
		"x x x x x x 2 x",
		"x 2 x x x x x x",
	}))
	local _, phases = pop:trySwap(4, 2, 5, 2)
	local first = phase(phases, "Pop")
	eq(#first.transformed, 2)
	local sprays = 0
	for _, effect in first.effects do
		if effect.type == "Spray" then
			sprays += 1
		end
	end
	eq(sprays, 3)
end)

test("a match next to a hay bale knocks off one layer", function()
	local pop = engine({
		layout = { "........", ".2......", "........", "........", "........", "........", "........", "........" },
		goals = { { kind = "HayBale" } },
	}, rows({
		"1 1 2 x x x x x",
		"x B2 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	local first = phase(phases, "Pop")
	eq(#first.bales, 1)
	eq(first.bales[1].hp, 1)
	eq(pop.goals.list[1].progress, 0)
end)

test("popping tiles on mud clears it and can win the level", function()
	local pop = engine({
		layout = { "mmm.....", "........", "........", "........", "........", "........", "........", "........" },
		goals = { { kind = "Mud" } },
	}, rows({
		"1 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	eq(pop.goals.list[1].target, 3)
	local _, phases = pop:trySwap(3, 2, 3, 1)
	eq(#phase(phases, "Pop").mud, 3)
	eq(pop.status, "Won")
	falsy(pop:canSwap(1, 1, 1, 2), "no swaps after winning")
end)

test("winning with moves left turns them into bonus Seed Sprayers", function()
	local pop = engine({
		moves = 6,
		layout = { "mmm.....", "........", "........", "........", "........", "........", "........", "........" },
		goals = { { kind = "Mud" } },
	}, rows({
		"1 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	local _, phases = pop:trySwap(3, 2, 3, 1)
	eq(pop.status, "Won")
	eq(pop.movesLeft, 0)
	eq(pop.bonus.moves, 5)
	eq(pop.bonus.coins, 10)
	local bonusPop
	for _, p in phases do
		if p.kind == "Pop" and p.bonus then
			bonusPop = p
		end
	end
	truthy(bonusPop, "bonus phase")
	eq(#bonusPop.transformed, 5)
	eq(#Helpers.phase(phases, "Pop").transformed, 0, "the winning match itself is not a bonus")
end)

test("running out of moves loses, and extra moves continue", function()
	local pop = engine({ moves = 1 }, rows({
		"1 1 2 x x x x x",
		"x x 1 x x x x x",
	}))
	truthy(pop:trySwap(3, 2, 3, 1))
	eq(pop.status, "Lost")
	eq(pop.movesLeft, 0)
	pop:addMoves(5)
	eq(pop.status, "Playing")
	eq(pop.movesLeft, 5)
end)

test("start power-ups are placed on the board", function()
	local level = Helpers.level()
	local pop = CropPop.Engine.new(level, 42, { startPowerUps = { "SprayerRow", "HayBomb", "Sunflower" } })
	local found = {}
	pop.board:eachCell(function(cell)
		if cell.piece and cell.piece.power then
			found[cell.piece.power] = true
		end
	end)
	truthy(found.SprayerRow and found.HayBomb and found.Sunflower)
end)
