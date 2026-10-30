--!strict
-- Animal pens (Design/03 Animals): build a pen, buy animals 4-6, feed and collect.
-- Building and buying are paperwork (from anywhere on your plot); feeding and collecting are
-- hands-on, so the avatar must be in reach of the pen. Collecting refeeds the same animals
-- when there is feed ("Collect & Refeed", on by default).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Animals = require(Shared.Config.Animals)
local Balance = require(Shared.Config.Balance)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Pen = require(Shared.Pen)
local Speedup = require(Shared.Speedup)
local Tutorial = require(Shared.Tutorial)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local QuestService = require(script.Parent.QuestService)
local Clock = require(script.Parent.Parent.Util.Clock)

local AnimalService = {}

local function penFor(player: Player, penId: any): (Animals.PenDef?, { [string]: any }?)
	if not NetService.check.id(penId) then
		return nil, nil
	end
	local data = DataService.get(player)
	local def = Animals.pens[penId]
	if data == nil or def == nil or data.pens[penId] == nil then
		return nil, nil
	end
	return def, data.pens[penId]
end

local function nearPen(player: Player, penId: string): boolean
	local pos = PlotService.penPosition(player, penId)
	return pos ~= nil and NetService.isNear(player, pos, Balance.serverReachStuds)
end

local function feedPen(player: Player, def: Animals.PenDef, pen: { [string]: any }): number
	local seconds = Tutorial.seconds(DataService.get(player) :: any, def.product, def.produceSeconds)
	return Pen.feed(pen, Clock.now(), Clock.duration(seconds), function()
		return InventoryService.remove(player, { [def.feed] = 1 })
	end)
end

function AnimalService.build(player: Player, penId: any): (boolean, string?)
	local def, pen = penFor(player, penId)
	if def == nil or pen == nil or pen.built then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	if data.level < def.unlockLevel then
		return false, string.format("The %s unlocks at level %d", def.displayName, def.unlockLevel)
	end
	if not EconomyService.spend(player, "Coins", def.buildCost, "build_" .. def.id) then
		return false, string.format("Building the %s costs %d Coins", def.displayName, def.buildCost)
	end
	pen.built = true
	pen.constructionReadyAt = Clock.now() + Clock.duration(def.buildSeconds)
	pen.animals = {}
	for _ = 1, def.startAnimals do
		table.insert(pen.animals, {})
	end
	EconomyService.add(player, "XP", def.xp, "build_" .. def.id)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function AnimalService.buyAnimal(player: Player, penId: any): (boolean, string?)
	local def, pen = penFor(player, penId)
	if def == nil or pen == nil or not pen.built then
		return false
	end
	local cost = Pen.nextAnimalCost(def, pen)
	if cost == nil then
		return false, "This pen is full"
	end
	if not EconomyService.spend(player, "Coins", cost, "animal_" .. def.id) then
		return false, string.format("Another %s costs %d Coins", def.animalName, cost)
	end
	table.insert(pen.animals, {})
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function AnimalService.feed(player: Player, penId: any): (boolean, string?)
	local def, pen = penFor(player, penId)
	if def == nil or pen == nil then
		return false
	end
	local now = Clock.now()
	if not Pen.isOperational(pen, now) then
		return false
	end
	local counts = Pen.counts(pen, now)
	if counts.hungry == 0 then
		return false
	end
	if not nearPen(player, def.id) then
		return false, "Walk closer to the " .. def.displayName
	end
	if feedPen(player, def, pen) == 0 then
		return false, string.format("No %s in the Barn. Make some at the Feed Mill.", Items[def.feed].displayName)
	end
	PlotService.refresh(player)
	return true
end

function AnimalService.collect(player: Player, penId: any): (boolean, string?)
	local def, pen = penFor(player, penId)
	if def == nil or pen == nil then
		return false
	end
	local now = Clock.now()
	-- 1 s of slack for the client's countdown reaching zero first
	if not Pen.isOperational(pen, now) or Pen.counts(pen, now + 1).ready == 0 then
		return false
	end
	if not nearPen(player, def.id) then
		return false, "Walk closer to the " .. def.displayName
	end
	local taken = Pen.collect(pen, now + 1, InventoryService.space(player))
	if taken == 0 then
		return false, "Your Barn is full. Sell something from the Barn first."
	end
	InventoryService.add(player, { [def.product] = taken })
	EconomyService.add(player, "XP", def.productXP * taken, "collect_" .. def.product)
	QuestService.progress(player, "animal", taken)
	feedPen(player, def, pen)
	PlotService.refresh(player)
	return true
end

-- Gems finish construction, or else every animal that's producing (each priced on its own).
function AnimalService.speedUp(player: Player, penId: any): (boolean, string?)
	local def, pen = penFor(player, penId)
	if def == nil or pen == nil or not pen.built then
		return false
	end
	local now = Clock.now()
	local building = not Pen.isOperational(pen, now)
	local gems = if building then Speedup.building(pen.constructionReadyAt - now) else Speedup.pen(pen, now)
	if gems <= 0 then
		return false
	end
	if not EconomyService.spend(player, "Gems", gems, "speedup_" .. def.id) then
		return false, "Not enough Gems"
	end
	if building then
		pen.constructionReadyAt = now
	else
		for _, animal in pen.animals do
			if animal.readyAt ~= nil and animal.readyAt > now then
				animal.readyAt = now
			end
		end
	end
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function AnimalService.init()
	NetService.on(Net.Pen_Build, 1, 2, AnimalService.build)
	NetService.on(Net.Pen_BuyAnimal, 2, 3, AnimalService.buyAnimal)
	NetService.on(Net.Pen_Feed, 8, 12, AnimalService.feed)
	NetService.on(Net.Pen_Collect, 8, 12, AnimalService.collect)
	NetService.on(Net.Pen_SpeedUp, 2, 3, AnimalService.speedUp)
end

return AnimalService
