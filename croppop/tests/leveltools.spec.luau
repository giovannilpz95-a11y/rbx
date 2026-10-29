-- The level editor's helpers: writing levels as Luau, and the test bot.

local eq, truthy = expect.eq, expect.truthy
local Levels, LevelText, Bot = CropPop.Levels, CropPop.LevelText, CropPop.Bot

test("every level written out reads back the same", function()
	for _, level in Levels.List do
		local text = LevelText.write(level)
		-- The text ends with "}," so it can be pasted into Levels.List as is.
		local back = loadmodule("return " .. string.gsub(text, ",$", ""), "level " .. level.id, {})()
		eq(back.id, level.id)
		eq(back.name, level.name)
		eq(back.moves, level.moves)
		eq(table.concat(back.layout, "/"), table.concat(level.layout, "/"))
		eq(table.concat(back.colors, ","), table.concat(level.colors, ","))
		eq(#back.goals, #level.goals)
		for i, goal in level.goals do
			eq(back.goals[i].kind, goal.kind)
			eq(back.goals[i].tile, goal.tile)
			eq(back.goals[i].count, goal.count)
		end
		eq(Levels.validate(back), nil)
	end
end)

test("the bot plays the first levels and reports a win rate", function()
	for id = 1, 5 do
		local level = Levels.get(id)
		local report = Bot.play(level, 20, level.id)
		eq(report.games, 20)
		truthy(report.winRate >= 0 and report.winRate <= 1)
		print(string.format("    level %d %-14s bot wins %2d%%, %.1f moves left on wins, %.0f%% of goals on losses", level.id, level.name, report.winRate * 100, report.avgMovesLeft, report.avgGoalShare * 100))
	end
end)

test("the bot is repeatable for the same seed", function()
	local a = Bot.play(Levels.get(2), 10, 7)
	local b = Bot.play(Levels.get(2), 10, 7)
	eq(a.wins, b.wins)
	eq(a.avgGoalShare, b.avgGoalShare)
end)
