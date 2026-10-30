--!strict
-- Boot: start the services in dependency order, then run the join flow
-- (Design/09 Roblox Architecture §5): load profile -> catch up timers -> assign plot -> state.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Balance = require(Shared.Config.Balance)
local Net = require(Shared.Net)

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local NetService = require(Services.NetService)
local EconomyService = require(Services.EconomyService)
local InventoryService = require(Services.InventoryService)
local PlotService = require(Services.PlotService)
local FarmService = require(Services.FarmService)
local ShopService = require(Services.ShopService)
local NoticeService = require(Services.NoticeService)
local SocialService = require(Services.SocialService)
local HelpService = require(Services.HelpService)
local FactoryService = require(Services.FactoryService)
local AnimalService = require(Services.AnimalService)
local TownService = require(Services.TownService)
local OrderService = require(Services.OrderService)
local ReturnService = require(Services.ReturnService)
local TutorialService = require(Services.TutorialService)
local CropPopBridge = require(Services.CropPopBridge)
local DebugService = require(Services.DebugService)
local DecorService = require(Services.DecorService)
local TelemetryService = require(Services.TelemetryService)
local QuestService = require(Services.QuestService)
local SettingsService = require(Services.SettingsService)
local MissingService = require(Services.MissingService)
local Clock = require(script.Parent.Util.Clock)

DataService.init()
NetService.init()
TelemetryService.init()
InventoryService.init()
PlotService.init()
NoticeService.init() -- after the map exists
SocialService.init()
HelpService.init()
FarmService.init()
FactoryService.init()
AnimalService.init()
TownService.init()
DecorService.init()
OrderService.init()
ReturnService.init()
TutorialService.init()
QuestService.init()
SettingsService.init()
MissingService.init()
CropPopBridge.init()
ShopService.init()
DebugService.init()

-- DEV-only: shorter timers for playtesting. Ignored outside Studio.
NetService.on(Net.Debug_SetTimeScale, 1, 2, function(_player, scale)
	if not RunService:IsStudio() or table.find(Balance.timeScaleOptions, scale) == nil then
		return false
	end
	Clock.setTimeScale(scale)
	for _, other in Players:GetPlayers() do
		NetService.pushState(other)
	end
	return false, string.format("Timers now run at x%s length (new timers only)", tostring(scale))
end)

local function placeCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Balance.walkSpeed
	local target = PlotService.spawnCFrame(player)
	if target then
		task.defer(function()
			character:PivotTo(target)
		end)
	end
end

local function onPlayerAdded(player: Player)
	if not DataService.load(player) then
		return
	end
	FactoryService.advance(player) -- offline production lands on the output tray
	CropPopBridge.playerLoaded(player)
	OrderService.refreshBoard(player)
	TelemetryService.playerLoaded(player) -- before anything saves over meta.lastSeenAt
	ReturnService.playerLoaded(player)
	EconomyService.checkLevel(player) -- after a cap raise, banked XP levels up now
	QuestService.refresh(player)
	ShopService.playerLoaded(player)

	SocialService.playerLoaded(player)
	local plot = PlotService.assign(player, SocialService.friendsOnServer(player))
	if plot == nil then
		player:Kick("This server's farms are all taken. Please join another server.")
		return
	end

	player.CharacterAdded:Connect(function(character)
		placeCharacter(player, character)
	end)
	if player.Character then
		placeCharacter(player, player.Character)
	end
	NetService.pushState(player)
	SocialService.welcome(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
