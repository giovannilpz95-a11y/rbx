--!strict
-- The Train Station's rules (Config/Train): pure, so the server, the panel and the tests agree.
--
-- Save block `trains`:
--   seed    the RNG state new cars and rewards are drawn from
--   trips   trains sent so far
--   lines   one entry per train the farm has (the first at level 5, the others bought):
--           { cars = { Car }, bonus = Reward, returnAt? }
--           returnAt is set while the train is away; once it has passed the train is back and
--           its rewards wait to be unloaded. Without it the train is at the platform, loading.

local BlimpConfig = require("./Config/Blimp")
local Config = require("./Config/Train")
local Items = require("./Items")
local OrderGen = require("./OrderGen")
local Rng = require("./Rng")

local Train = {}

export type Reward = { item: string, qty: number }
-- flagged: the owner asked neighbors for help with it; helpedBy: the user id of the neighbor
-- who loaded it
export type Car = { item: string, qty: number, reward: Reward, loaded: boolean?, flagged: boolean?, helpedBy: number? }
export type Line = { cars: { Car }, bonus: Reward, returnAt: number? }

-- Seconds a new timer runs for under the Studio time scale (as the server's Clock.duration)
local function secs(seconds: number, scale: number?): number
	return math.max(1, math.floor(seconds * (scale or 1) + 0.5))
end

function Train.record(data: { [string]: any }): { [string]: any }
	return data.trains
end

function Train.lines(data: { [string]: any }): { Line }
	return data.trains.lines
end

function Train.line(data: { [string]: any }, index: any): Line?
	if type(index) ~= "number" or index % 1 ~= 0 then
		return nil
	end
	return data.trains.lines[index]
end

-- Cars a new train brings at `level`
function Train.carsAt(level: number): number
	local cars = 0
	for _, row in Config.cars do
		if level >= row.level then
			cars = row.cars
		end
	end
	return cars
end

-- How long a trip takes at `level`
function Train.travelSeconds(level: number): number
	local t = math.clamp((level - Config.unlockLevel) / (Config.travelFullLevel - Config.unlockLevel), 0, 1)
	return math.floor(Config.travelMin + (Config.travelMax - Config.travelMin) * t + 0.5)
end

-- The per-car range for `item` (Township's train quantities, or a share of its Cargo Blimp
-- crate), or nil when trains never ask for it
function Train.baseRange(item: string): (number?, number?)
	local range = Config.qty[item]
	if range then
		return range[1], range[2]
	end
	local crate = BlimpConfig.crates[item]
	if crate then
		local low = math.max(1, math.floor(crate[1] / Config.blimpDivisor))
		return low, math.max(low, math.floor(crate[2] / Config.blimpDivisor))
	end
	return nil, nil
end

-- How many of `item` a car asks for at `level`: the low end at first, the whole range later
function Train.qtyRange(item: string, level: number): (number, number)
	local low, high = Train.baseRange(item)
	if low == nil or high == nil then
		return 1, 1
	end
	local t = math.clamp((level - Config.qtyFromLevel) / (Config.qtyFullLevel - Config.qtyFromLevel), 0, 1)
	local share = Config.qtyStartShare + (1 - Config.qtyStartShare) * t
	return low, math.max(low, low + math.floor((high - low) * share + 0.5))
end

-- Goods a train can ask this farm for: makeable now and with a train range
function Train.pool(data: { [string]: any }): { string }
	local pool = {}
	for _, id in OrderGen.makeablePool(data) do
		local def = Items[id]
		if def and def.kind ~= "Material" and def.unlockLevel <= data.level and Train.baseRange(id) ~= nil then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	return pool
end

local function weightOf(id: string): number
	local kind = Items[id].kind
	return if kind == "Crop" or kind == "Animal" then Config.rawWeight else 1
end

-- Picks one entry by integer weight
local function pick<T>(seed: number, entries: { T }, weight: (T) -> number): (T?, number)
	local total = 0
	for _, e in entries do
		total += weight(e)
	end
	if total <= 0 then
		return nil, seed
	end
	local roll
	roll, seed = Rng.int(seed, 1, total)
	for _, e in entries do
		roll -= weight(e)
		if roll <= 0 then
			return e, seed
		end
	end
	return entries[#entries], seed
end

-- Rewards a car can bring at `level`
function Train.rewardPool(level: number): { Config.Reward }
	local out = {}
	for _, r in Config.rewards do
		if level >= r.fromLevel then
			table.insert(out, r)
		end
	end
	return out
end

function Train.drawReward(seed: number, level: number): (Reward, number)
	local r, nextSeed = pick(seed, Train.rewardPool(level), function(e: Config.Reward)
		return e.weight
	end)
	local chosen = r or Config.rewards[1]
	return { item = chosen.item, qty = chosen.qty }, nextSeed
end

-- A train at the platform with new cars, each asking for a different good while the pool
-- lasts, and the bonus reward for loading them all. Returns the line and the next seed.
function Train.newLine(data: { [string]: any }, seed: number): (Line, number)
	seed = Rng.normalize(seed)
	local level = data.level
	local pool = Train.pool(data)
	local remaining = table.clone(pool)
	local cars = {}
	for _ = 1, Train.carsAt(level) do
		if #pool == 0 then
			break
		end
		if #remaining == 0 then
			remaining = table.clone(pool)
		end
		local item
		item, seed = pick(seed, remaining, weightOf)
		local id = item :: string
		table.remove(remaining, table.find(remaining, id) :: number)
		local low, high = Train.qtyRange(id, level)
		local qty
		qty, seed = Rng.int(seed, low, high)
		local reward
		reward, seed = Train.drawReward(seed, level)
		table.insert(cars, { item = id, qty = qty, reward = reward })
	end
	local bonus
	bonus, seed = Train.drawReward(seed, level)
	return { cars = cars, bonus = bonus }, seed
end

-- Gives the farm its first train once it reaches the Station's level. True when it did.
function Train.ensure(data: { [string]: any }): boolean
	local record = data.trains
	if data.level < Config.unlockLevel or #record.lines > 0 then
		return false
	end
	local line
	line, record.seed = Train.newLine(data, record.seed)
	record.lines[1] = line
	return true
end

-- The next train the farm can buy: its number and definition, or nil when it has them all
function Train.nextTrain(data: { [string]: any }): (number?, { level: number, coins: number }?)
	local index = #data.trains.lines + 1
	local def = Config.trains[index]
	if def == nil or index == 1 then
		return nil, nil
	end
	return index, def
end

-- Can the next train be bought now? (Coins are checked by the caller.)
function Train.canBuy(data: { [string]: any }): (boolean, string?)
	local index, def = Train.nextTrain(data)
	if index == nil or def == nil then
		return false
	elseif data.level < def.level then
		return false, string.format("Train %d can be bought at level %d", index, def.level)
	end
	return true
end

function Train.buy(data: { [string]: any })
	local record = data.trains
	local line
	line, record.seed = Train.newLine(data, record.seed)
	table.insert(record.lines, line)
end

function Train.isAway(line: Line, now: number): boolean
	return line.returnAt ~= nil and now < line.returnAt
end

function Train.isBack(line: Line, now: number): boolean
	return line.returnAt ~= nil and now >= line.returnAt
end

function Train.loadedCount(line: Line): number
	local n = 0
	for _, car in line.cars do
		if car.loaded then
			n += 1
		end
	end
	return n
end

function Train.isFull(line: Line): boolean
	return #line.cars > 0 and Train.loadedCount(line) == #line.cars
end

-- The car a load request names, if it can be loaded now (the caller checks the Barn)
function Train.canLoad(data: { [string]: any }, index: any, carIndex: any, now: number): (Car?, string?)
	local line = Train.line(data, index)
	if line == nil or type(carIndex) ~= "number" then
		return nil
	end
	local car = line.cars[carIndex]
	if car == nil then
		return nil
	elseif line.returnAt ~= nil then
		return nil, if now < line.returnAt then "That train is away" else "Unload the train first"
	elseif car.loaded then
		return nil, "That car is already loaded"
	end
	return car
end

-- Loads a car; `helper` is the user id of a neighbor who loaded it for the owner
function Train.load(car: Car, helper: number?)
	car.loaded = true
	car.flagged = nil
	car.helpedBy = helper
end

-- Flag a car for help, one a train; flagging another car moves the flag, and flagging the
-- flagged car takes it off
function Train.flag(data: { [string]: any }, index: any, carIndex: any, now: number): (boolean, string?)
	local car, reason = Train.canLoad(data, index, carIndex, now)
	if car == nil then
		return false, reason
	elseif data.level < Config.helpFromLevel then
		return false, string.format("Neighbors can help with your trains from level %d", Config.helpFromLevel)
	end
	local on = not car.flagged
	for _, other in (Train.line(data, index) :: Line).cars do
		other.flagged = nil
	end
	car.flagged = if on then true else nil
	return true
end

-- What a neighbor earns for loading a flagged car: Coins and XP
function Train.helperRewards(car: Car): (number, number)
	local def = Items[car.item]
	local value = (def and def.sellPrice or 1) * car.qty
	return math.max(1, math.floor(value * Config.helperCoinMult + 0.5)), Train.carXp(car)
end

-- The flagged cars still waiting, for the Help Board: "12 Wheat, 3 Milk" ("" when none)
function Train.helpText(data: { [string]: any }): string
	local asks = {}
	for _, line in data.trains.lines do
		if line.returnAt == nil then
			for _, car in line.cars do
				if car.flagged and not car.loaded then
					local def = Items[car.item]
					table.insert(asks, string.format("%d %s", car.qty, if def then def.displayName else car.item))
				end
			end
		end
	end
	return table.concat(asks, ", ")
end

-- XP a loaded car pays at once
function Train.carXp(car: Car): number
	local def = Items[car.item]
	return math.max(1, math.floor((def and def.xpPerUnit or 1) * car.qty * Config.carXpMult + 0.5))
end

function Train.canSend(data: { [string]: any }, index: any): (Line?, string?)
	local line = Train.line(data, index)
	if line == nil then
		return nil
	elseif line.returnAt ~= nil then
		return nil, "That train is already out"
	end
	return line
end

function Train.send(data: { [string]: any }, line: Line, now: number, scale: number?)
	line.returnAt = now + secs(Train.travelSeconds(data.level), scale)
	data.trains.trips = (data.trains.trips or 0) + 1
end

-- Brings an away train back now (the caller has charged the Gems)
function Train.speedUp(line: Line, now: number): boolean
	if not Train.isAway(line, now) then
		return false
	end
	line.returnAt = now
	return true
end

-- What a train brings back: each loaded car's reward, plus the bonus when every car went out
-- loaded. Merged by item.
function Train.rewards(line: Line): { [string]: number }
	local out = {}
	for _, car in line.cars do
		if car.loaded then
			out[car.reward.item] = (out[car.reward.item] or 0) + car.reward.qty
		end
	end
	if Train.isFull(line) then
		out[line.bonus.item] = (out[line.bonus.item] or 0) + line.bonus.qty
	end
	return out
end

-- Takes a returned train's rewards (nil when it isn't back) and puts new cars on it
function Train.unload(data: { [string]: any }, index: any, now: number): { [string]: number }?
	local line = Train.line(data, index)
	if line == nil or not Train.isBack(line, now) then
		return nil
	end
	local out = Train.rewards(line)
	local record = data.trains
	local fresh
	fresh, record.seed = Train.newLine(data, record.seed)
	record.lines[index :: number] = fresh
	return out
end

return Train
