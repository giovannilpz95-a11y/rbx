--!strict
-- Studio-only shortcuts for playtesting. Every handler refuses outside Studio.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Animals = require(Shared.Config.Animals)
local Net = require(Shared.Net)
local Town = require(Shared.Config.Town)
local TownRules = require(Shared.TownRules)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)

local DebugService = {}

-- Every factory, pen and Community Building, and one House of each type, finished now,
-- ignoring level, Population and Coins (for checking models and tap targets).
function DebugService.buildAll(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not RunService:IsStudio() or data == nil then
		return false
	end
	for _, factory in data.factories do
		factory.built = true
		factory.constructionReadyAt = nil
	end
	for id, pen in data.pens do
		if not pen.built then
			pen.built = true
			for _ = 1, Animals.pens[id].startAnimals do
				table.insert(pen.animals, {})
			end
		end
		pen.constructionReadyAt = nil
	end
	for id in Town.houses do
		local lot = TownRules.freeLot(data, #PlotService.LAYOUT.houseLots)
		if TownRules.copiesBuilt(data, id) == 0 and lot then
			table.insert(data.town.houses, { type = id, lot = lot })
		end
	end
	for id in Town.community do
		data.town.community[id] = {}
	end
	DataService.markDirty(player, true)
	PlotService.refresh(player)
	return true
end

function DebugService.init()
	NetService.on(Net.Debug_BuildAll, 1, 2, DebugService.buildAll)
end

return DebugService
