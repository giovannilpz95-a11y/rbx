--!strict
-- Moving buildings (the free-placement sandbox, shared/Layout): the player picks a building in
-- Move mode, walks its ghost to a new spot and places it. The server checks the land, that
-- nothing else stands there, then saves the spot and rebuilds the building there.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Layout = require(Shared.Layout)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local Clock = require(script.Parent.Parent.Util.Clock)

local LayoutService = {}

function LayoutService.move(player: Player, key: any, x: any, z: any, r: any): (boolean, string?)
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local ok, reason = Layout.canMove(data, key, x, z, r, Clock.now())
	if not ok then
		return false, reason
	end
	local kind = Layout.parse(key) :: string
	if PlotService.footprintBlocked(player, kind, x, z, r, PlotService.layoutModel(player, key)) then
		return false, "Something is already there"
	end
	data.layout[key] = { x = x, z = z, r = r }
	DataService.markDirty(player, true)
	PlotService.relocate(player, key)
	TelemetryService.custom(player, "BuildingMoved", 1, kind)
	NetService.pushState(player)
	return true
end

function LayoutService.init()
	NetService.on(Net.Layout_Move, 4, 8, LayoutService.move)
end

return LayoutService
