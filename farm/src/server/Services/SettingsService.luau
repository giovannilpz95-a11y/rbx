--!strict
-- The player's options (shared/Settings): sound volumes, text size, Reduce Motion and the
-- Gem confirm. The client applies them; the server only checks and saves them.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Net = require(Shared.Net)
local Settings = require(Shared.Settings)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)

local SettingsService = {}

function SettingsService.set(player: Player, key: any, value: any): (boolean, string?)
	if not Settings.valid(key, value) then
		return false
	end
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	if data.settings[key] == value then
		return false
	end
	data.settings[key] = value
	return true
end

function SettingsService.init()
	-- Volume sliders send a step per tap, so the burst is generous
	NetService.on(Net.Settings_Set, 4, 10, SettingsService.set)
end

return SettingsService
