--!strict
-- Building the Bakery, queueing recipes and collecting finished goods
-- (Design/04 Factories & Recipes). Queueing is paperwork (from anywhere on your plot);
-- collecting is hands-on (walk-by at the output table).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Balance = require(Shared.Config.Balance)
local Factories = require(Shared.Config.Factories)
local Net = require(Shared.Net)
local Recipes = require(Shared.Config.Recipes)
local Timer = require(Shared.Timer)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local Clock = require(script.Parent.Parent.Util.Clock)

local FactoryService = {}

local function isOperational(factory: { [string]: any }, now: number): boolean
	return factory.built and (factory.constructionReadyAt == nil or now >= factory.constructionReadyAt)
end

-- Bring every queue up to now (finished goods move to the output tray).
function FactoryService.advance(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local now = Clock.now()
	for id, factory in data.factories do
		if factory.built and factory.constructionReadyAt ~= nil and now >= factory.constructionReadyAt then
			factory.constructionReadyAt = nil
		end
		local def = Factories[id]
		if def then
			Timer.advanceQueue(factory.queue, factory.output, now, def.trayCapacity)
		end
	end
end

function FactoryService.build(player: Player, factoryId: any): (boolean, string?)
	if not NetService.check.id(factoryId) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local factory = data.factories[factoryId]
	local def = Factories[factoryId]
	if factory == nil or def == nil or factory.built then
		return false
	end
	if data.level < def.unlockLevel then
		return false, string.format("The %s unlocks at level %d", def.displayName, def.unlockLevel)
	end
	if not EconomyService.spend(player, "Coins", def.buildCost, "build_" .. factoryId) then
		return false, string.format("Building the %s costs %d Coins", def.displayName, def.buildCost)
	end
	factory.built = true
	factory.constructionReadyAt = Clock.now() + Clock.duration(def.buildSeconds)
	EconomyService.add(player, "XP", def.xp, "build_" .. factoryId)
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function FactoryService.queue(player: Player, factoryId: any, recipeId: any): (boolean, string?)
	if not NetService.check.id(factoryId) or not NetService.check.id(recipeId) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local factory = data.factories[factoryId]
	local recipe = Recipes[recipeId]
	if factory == nil or recipe == nil or recipe.factory ~= factoryId then
		return false
	end
	FactoryService.advance(player)
	if not isOperational(factory, Clock.now()) then
		return false, "Build the " .. factoryId .. " first"
	end
	if data.level < recipe.unlockLevel then
		return false, string.format("%s unlocks at level %d", recipe.displayName, recipe.unlockLevel)
	end
	if #factory.queue >= factory.slots then
		return false, "The queue is full"
	end
	-- Inputs are taken right away, so a queued item can never stall.
	if not InventoryService.remove(player, recipe.inputs) then
		return false, "Not enough ingredients in the Barn"
	end
	table.insert(factory.queue, { recipe = recipeId, seconds = Clock.duration(recipe.seconds) })
	FactoryService.advance(player)
	PlotService.refresh(player)
	return true
end

function FactoryService.collect(player: Player, factoryId: any): (boolean, string?)
	if not NetService.check.id(factoryId) then
		return false
	end
	local data = DataService.get(player) :: { [string]: any }
	local factory = data.factories[factoryId]
	if factory == nil then
		return false
	end
	FactoryService.advance(player)
	if Timer.countOutput(factory.output) == 0 then
		return false
	end
	local tablePos = PlotService.worldPosition(player, PlotService.LAYOUT.bakeryOutput)
	if tablePos == nil or not NetService.isNear(player, tablePos, Balance.serverReachStuds) then
		return false, "Walk closer to the output table"
	end
	-- Move as much as fits; the rest waits on the tray.
	local collected = 0
	for item, qty in factory.output do
		local space = InventoryService.space(player)
		local take = math.min(qty, space)
		if take > 0 and InventoryService.add(player, { [item] = take }) then
			factory.output[item] = if qty - take > 0 then qty - take else nil
			collected += take
			local recipe = Recipes[item]
			if recipe then
				EconomyService.add(player, "XP", recipe.xp * take, "collect_" .. item)
			end
		end
	end
	if collected == 0 then
		return false, "Your Barn is full. Sell something from the Barn first."
	end
	FactoryService.advance(player) -- a paused queue restarts now that the tray has room
	PlotService.refresh(player)
	return true
end

function FactoryService.init()
	NetService.on(Net.Factory_Build, 1, 2, FactoryService.build)
	NetService.on(Net.Factory_Queue, 5, 8, FactoryService.queue)
	NetService.on(Net.Factory_Collect, 5, 8, FactoryService.collect)
end

return FactoryService
