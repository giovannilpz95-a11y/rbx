--[[
	Audio client: starts the farm music and ambience, gives every on-screen button a tap
	sound, and turns farm events into sounds. Crop Pop calls GameAudio itself
	(croppop/src/client/Sfx.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameAudio = require(ReplicatedStorage:WaitForChild("GameAudio"))
local UiTaps = require(script.Parent.UiTaps)
local FarmHooks = require(script.Parent.FarmHooks)

GameAudio.setMusic("Farm") -- brings the farm ambience with it (Sounds.contextAmbience)
UiTaps.start(GameAudio)
task.spawn(FarmHooks.start, GameAudio)
