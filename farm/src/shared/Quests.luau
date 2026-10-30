--!strict
-- Daily Quest rules (Config/Quests), pure for the server and the Lune tests. Saved as
-- data.quests = { day = UTC day, seed = Rng seed, list = { Quest }, rerolled = bool,
-- chest = bool (bonus taken) }.

local Config = require("./Config/Quests")
local Rng = require("./Rng")
local Tools = require("./Config/Tools")

export type Quest = { kind: string, target: number, progress: number, claimed: boolean }

local Quests = {}

local byKind: { [string]: Config.QuestDef } = {}
for _, def in Config.pool do
	byKind[def.kind] = def
end

function Quests.def(kind: string): Config.QuestDef?
	return byKind[kind]
end

function Quests.isOpen(data: { [string]: any }): boolean
	return not Config.afterTutorial or (data.tutorial.step or 0) == 0
end

-- Which quest kinds this farm can do now
function Quests.eligible(data: { [string]: any }): { string }
	local out = {}
	for _, def in Config.pool do
		local ok = true
		if def.kind == "animal" then
			ok = false
			for _, pen in data.pens do
				if pen.built and #pen.animals > 0 then
					ok = true
				end
			end
		elseif def.kind == "factory" then
			ok = false
			for _, factory in data.factories do
				if factory.built then
					ok = true
				end
			end
		end
		if ok then
			table.insert(out, def.kind)
		end
	end
	return out
end

local function targetFor(data: { [string]: any }, def: Config.QuestDef): number
	if data.level < Config.smallTargetsBelow then
		return math.max(1, math.ceil(def.target / 2))
	end
	return def.target
end

-- Pick one kind from `kinds` not in `taken`, advancing the saved seed
local function pick(data: { [string]: any }, kinds: { string }, taken: { [string]: boolean }): string?
	local free = {}
	for _, kind in kinds do
		if not taken[kind] then
			table.insert(free, kind)
		end
	end
	if #free == 0 then
		return nil
	end
	local i, seed = Rng.int(data.quests.seed, 1, #free)
	data.quests.seed = seed
	return free[i]
end

-- Start a new day's list if the UTC day changed. Returns true when it did.
function Quests.refresh(data: { [string]: any }, day: number): boolean
	local q = data.quests
	if not Quests.isOpen(data) or q.day == day then
		return false
	end
	q.day = day
	q.list = {}
	q.rerolled = false
	q.chest = false
	if q.seed == 0 then
		q.seed = Rng.normalize(day * 7919 + (data.meta.createdAt or 0) % 100003) -- farms differ
	end
	local kinds = Quests.eligible(data)
	local taken = {}
	for _ = 1, Config.perDay do
		local kind = pick(data, kinds, taken)
		if kind == nil then
			break
		end
		taken[kind] = true
		table.insert(q.list, {
			kind = kind,
			target = targetFor(data, byKind[kind]),
			progress = 0,
			claimed = false,
		})
	end
	return true
end

-- Count progress; returns the indexes of quests this finished
function Quests.add(data: { [string]: any }, kind: string, amount: number): { number }
	local done = {}
	for i, quest in data.quests.list do
		if quest.kind == kind and quest.progress < quest.target then
			quest.progress = math.min(quest.target, quest.progress + amount)
			if quest.progress >= quest.target then
				table.insert(done, i)
			end
		end
	end
	return done
end

-- The quest's reward if it can be claimed now
function Quests.claim(data: { [string]: any }, index: number): (Config.QuestDef?, string?)
	local quest = data.quests.list[index]
	if quest == nil or quest.claimed then
		return nil, nil
	end
	if quest.progress < quest.target then
		return nil, "Not finished yet"
	end
	quest.claimed = true
	return byKind[quest.kind], nil
end

-- One free reroll a day, on a quest not yet finished
function Quests.reroll(data: { [string]: any }, index: number): (boolean, string?)
	local q = data.quests
	local quest = q.list[index]
	if quest == nil or quest.progress >= quest.target then
		return false, nil
	end
	if q.rerolled then
		return false, "You've used today's free reroll"
	end
	local taken = {}
	for _, other in q.list do
		taken[other.kind] = true
	end
	local kind = pick(data, Quests.eligible(data), taken)
	if kind == nil then
		return false, "No other quest to swap in yet"
	end
	q.list[index] = { kind = kind, target = targetFor(data, byKind[kind]), progress = 0, claimed = false }
	q.rerolled = true
	return true, nil
end

function Quests.chestReady(data: { [string]: any }): boolean
	local q = data.quests
	if q.chest or #q.list == 0 then
		return false
	end
	for _, quest in q.list do
		if not quest.claimed then
			return false
		end
	end
	return true
end

-- Open the bonus chest: Gems, or (from the tool level, sometimes) a tool id
function Quests.openChest(data: { [string]: any }, scarcestTool: string): (number, string?)
	local q = data.quests
	q.chest = true
	local roll, seed = Rng.next(q.seed)
	q.seed = seed
	if data.level >= Tools.fromLevel and roll < Config.chest.toolChance then
		return 0, scarcestTool
	end
	local gems, nextSeed = Rng.int(q.seed, Config.chest.minGems, Config.chest.maxGems)
	q.seed = nextSeed
	return gems, nil
end

function Quests.text(quest: Quest): string
	local def = byKind[quest.kind]
	return if def then string.format(def.text, quest.target) else quest.kind
end

return Quests
