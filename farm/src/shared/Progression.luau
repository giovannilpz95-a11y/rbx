--!strict
-- Level math from total XP (pure).

local Levels = require("./Config/Levels")

local Progression = {}

export type LevelInfo = {
	level: number,
	xpIntoLevel: number,
	xpToNext: number, -- 0 at the level cap
	atCap: boolean,
}

function Progression.info(totalXP: number): LevelInfo
	local remaining = totalXP
	for _, def in Levels.list do
		if def.level >= Levels.cap then
			return { level = Levels.cap, xpIntoLevel = remaining, xpToNext = 0, atCap = true }
		end
		if remaining < def.xpToNext then
			return { level = def.level, xpIntoLevel = remaining, xpToNext = def.xpToNext, atCap = false }
		end
		remaining -= def.xpToNext
	end
	return { level = Levels.cap, xpIntoLevel = remaining, xpToNext = 0, atCap = true }
end

function Progression.levelFor(totalXP: number): number
	return Progression.info(totalXP).level
end

function Progression.reward(level: number): (number, number)
	local def = Levels.list[level]
	if def == nil then
		return 0, 0
	end
	return def.rewardCoins, def.rewardGems
end

return Progression
