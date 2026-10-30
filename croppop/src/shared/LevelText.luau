--[[
	Writes a level as Luau source in the same layout as the Levels set files,
	so the level editor's output can be pasted straight into one.
]]

local LevelText = {}

local function quote(s: string): string
	return string.format("%q", s)
end

local function goalText(goal): string
	if goal.kind == "Collect" then
		return string.format("{ kind = \"Collect\", tile = %s, count = %d }", quote(goal.tile), goal.count)
	end
	if goal.count then
		return string.format("{ kind = %s, count = %d }", quote(goal.kind), goal.count)
	end
	return string.format("{ kind = %s }", quote(goal.kind))
end

function LevelText.write(level): string
	local lines = {
		"{",
		string.format("\tid = %d,", level.id),
		string.format("\tname = %s,", quote(level.name or "Untitled")),
		string.format("\tdifficulty = %s,", quote(level.difficulty)),
		string.format("\tmoves = %d,", level.moves),
	}
	local colors = {}
	for _, name in level.colors do
		table.insert(colors, quote(name))
	end
	table.insert(lines, "\tcolors = { " .. table.concat(colors, ", ") .. " },")
	table.insert(lines, "\tlayout = {")
	for _, row in level.layout do
		table.insert(lines, "\t\t" .. quote(row) .. ",")
	end
	table.insert(lines, "\t},")
	table.insert(lines, "\tgoals = {")
	for _, goal in level.goals do
		table.insert(lines, "\t\t" .. goalText(goal) .. ",")
	end
	table.insert(lines, "\t},")
	local rewards = level.rewards or {}
	table.insert(lines, string.format("\trewards = { coins = %d, xp = %d },", rewards.coins or 0, rewards.xp or 0))
	table.insert(lines, "},")
	return table.concat(lines, "\n")
end

return LevelText
