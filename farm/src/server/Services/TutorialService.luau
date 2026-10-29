--!strict
-- Runs the first-session guide (shared/Tutorial): checks each player's step every second,
-- logs each finished step to the onboarding funnel, and handles "Got it" and Skip.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Net = require(Shared.Net)
local Tutorial = require(Shared.Tutorial)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local Clock = require(script.Parent.Parent.Util.Clock)

local TutorialService = {}

local stepIndex: { [string]: number } = {}
for i, step in Tutorial.steps do
	stepIndex[step.id] = i
end

local function logStep(player: Player, id: string)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, stepIndex[id], "Ftue" .. id)
	end)
end

function TutorialService.check(player: Player): boolean
	local data = DataService.get(player)
	if data == nil then
		return false
	end
	local finished = Tutorial.advance(data, Clock.now())
	for _, id in finished do
		logStep(player, id)
	end
	if #finished > 0 then
		DataService.markDirty(player, true)
		return true
	end
	return false
end

-- "Got it" on the last step: the wrap-up Gems, then the guide is done.
function TutorialService.next(player: Player): (boolean, string?)
	local data = DataService.get(player)
	local step = data and Tutorial.current(data)
	if data == nil or step == nil or step.done ~= nil then
		return false
	end
	logStep(player, step.id)
	data.tutorial.step = 0
	EconomyService.add(player, "Gems", Tutorial.wrapUpGems, "tutorial")
	DataService.markDirty(player, true)
	return true
end

function TutorialService.skip(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if data == nil or data.tutorial.step < Tutorial.skippableFrom then
		return false
	end
	data.tutorial.step = 0
	DataService.markDirty(player, true)
	return true
end

function TutorialService.init()
	NetService.on(Net.Tutorial_Next, 1, 2, TutorialService.next)
	NetService.on(Net.Tutorial_Skip, 1, 2, TutorialService.skip)
	-- DEV-only: replay the guide on an existing farm. Ignored outside Studio.
	NetService.on(Net.Debug_RestartTutorial, 1, 2, function(player)
		local data = DataService.get(player)
		if not RunService:IsStudio() or data == nil then
			return false
		end
		Tutorial.start(data, Clock.now())
		PlotService.refresh(player)
		return true
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if TutorialService.check(player) then
					NetService.pushState(player)
				end
			end
		end
	end)
end

return TutorialService
