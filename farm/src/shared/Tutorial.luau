--!strict
-- The first-session guide (Design/11 UI & UX FTUE, 01 Core Loop "First 30 Minutes" and the
-- first-60-seconds script in Launch/17), pure so the server, the client and the Lune tests
-- share it. Saved as data.tutorial.step: 0 = off (finished, skipped, or a farm from before
-- the guide), otherwise the index of the current step. Each step ends on its own as soon as
-- its goal is true, so a player who runs ahead never gets stuck. Pacing is first-pass.

local OrderGen = require("./OrderGen")
local Town = require("./Config/Town")

local Tutorial = {}

export type Step = {
	id: string,
	guide: string, -- the townsfolk guide who speaks (16 Model Catalog §2.15)
	text: string, -- one sentence
	target: string?, -- what the pointer marks: "ReadyField", "EmptyField", "OrderBoard", "Factory:<id>", "Pen:<id>"
	done: ((data: { [string]: any }, now: number) -> boolean)?, -- nil = the player taps "Got it"
}

-- Tutorial cycles: these runs are short the first time so no wait in the first minutes is
-- long (01 Core Loop: "the first Milk is a short tutorial cycle").
Tutorial.cycleSeconds = 30
Tutorial.wrapUpGems = 5 -- 11 UI & UX step 10
Tutorial.skippableFrom = 3 -- "every step is skippable after step 3"
Tutorial.firstOrder = table.freeze({ Wheat = 4 }) -- first-60-seconds script
Tutorial.ripeFields = table.freeze({ "F1", "F2", "F3" })

local function anyField(data: { [string]: any }, test: (field: { [string]: any }) -> boolean): boolean
	for _, field in data.fields do
		if test(field) then
			return true
		end
	end
	return false
end

local function count(data: { [string]: any }, item: string): number
	return data.inventory.items[item] or 0
end

local function built(data: { [string]: any }, factoryId: string, now: number): boolean
	local factory = data.factories[factoryId]
	return factory.built and now >= (factory.constructionReadyAt or 0)
end

local function busy(data: { [string]: any }, factoryId: string): boolean
	local factory = data.factories[factoryId]
	return #factory.queue > 0 or next(factory.output) ~= nil
end

local function reach(level: number): (data: { [string]: any }) -> boolean
	return function(data)
		return data.level >= level
	end
end

Tutorial.steps = table.freeze({
	{
		id = "Harvest",
		guide = "Hattie",
		text = "Welcome to your farm! Walk up to the golden Wheat and harvest it.",
		target = "ReadyField",
		done = function(data, now)
			return not anyField(data, function(field)
				return field.crop ~= nil and now >= (field.readyAt or 0)
			end)
		end,
	},
	{
		id = "Plant",
		guide = "Hattie",
		text = "Plant more Wheat on the empty fields.",
		target = "EmptyField",
		done = function(data, now)
			return anyField(data, function(field)
				return field.crop ~= nil and now < (field.readyAt or 0)
			end)
		end,
	},
	{
		id = "Ship",
		guide = "Pip",
		text = "A truck order! Ship the Wheat from the Order Board.",
		target = "OrderBoard",
		done = function(data)
			return data.orders.delivered >= 1
		end,
	},
	{
		id = "Level2",
		guide = "Pip",
		text = "Harvest your new Wheat and fill another order to reach level 2.",
		target = "ReadyField",
		done = function(data)
			return data.level >= 2
		end,
	},
	{
		id = "Bakery",
		guide = "Auntie Crumb",
		text = "Level 2 opens the Bakery. Walk to it and build it.",
		target = "Factory:Bakery",
		done = function(data, now)
			return built(data, "Bakery", now)
		end,
	},
	{
		id = "Bread",
		guide = "Auntie Crumb",
		text = "Bake Bread at the Bakery from 2 Wheat.",
		target = "Factory:Bakery",
		done = function(data)
			return busy(data, "Bakery") or count(data, "Bread") > 0
		end,
	},
	{
		id = "Feed",
		guide = "Hattie",
		text = "Your Cows are hungry. Feed them at the Cow Barn.",
		target = "Pen:CowBarn",
		done = function(data)
			for _, animal in data.pens.CowBarn.animals do
				if animal.readyAt ~= nil then
					return true
				end
			end
			return count(data, "Milk") > 0
		end,
	},
	{
		id = "Milk",
		guide = "Hattie",
		text = "Collect the Milk when it's ready.",
		target = "Pen:CowBarn",
		done = function(data)
			return count(data, "Milk") > 0
		end,
	},
	{
		id = "Level3",
		guide = "Pip",
		text = "Keep filling orders. Level 3 brings Corn and the Feed Mill.",
		target = "OrderBoard",
		done = reach(3),
	},
	{
		id = "FeedMill",
		guide = "Auntie Crumb",
		text = "Build the Feed Mill so your Cows never run out of feed.",
		target = "Factory:FeedMill",
		done = function(data, now)
			return built(data, "FeedMill", now)
		end,
	},
	{
		id = "CowFeed",
		guide = "Auntie Crumb",
		text = "Make Cow Feed from 2 Wheat and 1 Corn. Plant some Corn first!",
		target = "Factory:FeedMill",
		done = function(data)
			return busy(data, "FeedMill") or data.level >= 4
		end,
	},
	{
		id = "Level4",
		guide = "Pip",
		text = "Fill orders with Wheat, Milk and Bread to reach level 4.",
		target = "OrderBoard",
		done = reach(4),
	},
	{
		id = "House",
		guide = "Mort",
		text = "Your town can grow! Open the Town panel (T) and build a Lean-to Cabin.",
		done = function(data)
			return #data.town.houses > #Town.starterHouses
		end,
	},
	{
		id = "Dairy",
		guide = "Auntie Crumb",
		text = "Build the Dairy. It takes an hour, but the first Finish is on me!",
		target = "Factory:Dairy",
		done = function(data, now)
			return built(data, "Dairy", now)
		end,
	},
	{
		id = "Land",
		guide = "Mort",
		text = "More fields need more room. Start clearing the West Meadow from the Town panel (T).",
		done = function(data)
			return data.land[1] ~= nil
		end,
	},
	{
		id = "Level5",
		guide = "Pip",
		text = "Fill orders to reach level 5. Chickens are waiting!",
		target = "OrderBoard",
		done = reach(5),
	},
	{
		id = "WrapUp",
		guide = "Hattie",
		text = "Great start! Plant something long and queue Cream before you go: timers run while you're away. Here are 5 Gems.",
	},
} :: { Step })

function Tutorial.current(data: { [string]: any }): Step?
	local step = data.tutorial and data.tutorial.step or 0
	return if step > 0 then Tutorial.steps[step] else nil
end

-- Set a new farm up for the guide: 3 ripe Wheat fields and an easy Wheat order on the board.
function Tutorial.start(data: { [string]: any }, now: number)
	data.tutorial.step = 1
	for _, id in Tutorial.ripeFields do
		local field = data.fields[id]
		if field and field.crop == nil then
			field.crop = "Wheat"
			field.plantedAt = now
			field.readyAt = now
		end
	end
	local coins, xp = OrderGen.rewards(Tutorial.firstOrder, data.level)
	data.orders.board[1] = {
		order = {
			id = "tutorial",
			wants = table.clone(Tutorial.firstOrder),
			top = "Wheat",
			rewardCoins = coins,
			rewardXP = xp,
		},
	}
end

-- Move past every finished step. Returns the ids of the steps finished, in order.
function Tutorial.advance(data: { [string]: any }, now: number): { string }
	local finished = {}
	local step = Tutorial.current(data)
	while step and step.done and step.done(data, now) do
		table.insert(finished, step.id)
		data.tutorial.step += 1
		step = Tutorial.current(data)
	end
	return finished
end

-- The first construction Finish is free (01 Core Loop: shown once, on the Dairy build).
function Tutorial.freeFinish(data: { [string]: any }, factoryId: string): boolean
	local step = Tutorial.current(data)
	return step ~= nil and step.id == factoryId and factoryId == "Dairy"
end

-- How long a run takes: short the first time while its step is on, else the normal time.
function Tutorial.seconds(data: { [string]: any }, item: string, normal: number): number
	local step = Tutorial.current(data)
	if step == nil then
		return normal
	end
	local short = (item == "Wheat" and (step.id == "Harvest" or step.id == "Plant" or step.id == "Ship"))
		or (item == "Bread" and step.id == "Bread")
		or (item == "Milk" and (step.id == "Feed" or step.id == "Milk"))
	return if short then math.min(normal, Tutorial.cycleSeconds) else normal
end

return Tutorial
