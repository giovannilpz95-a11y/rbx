--[[
	Audio client: starts the music and ambience for where the player is, gives every
	on-screen button a tap sound, hums busy factories and turns farm events into sounds.
	Crop Pop calls GameAudio itself (croppop/src/client/Sfx.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameAudio = require(ReplicatedStorage:WaitForChild("GameAudio"))
local UiTaps = require(script.Parent.UiTaps)
local FarmHooks = require(script.Parent.FarmHooks)
local FactoryHum = require(script.Parent.FactoryHum)
local WorldMusic = require(script.Parent.WorldMusic)

WorldMusic.start(GameAudio) -- "Farm" or "Visit", each with its ambience (Sounds.contextAmbience)
UiTaps.start(GameAudio)
task.spawn(FarmHooks.start, GameAudio)
task.spawn(FactoryHum.start, GameAudio)
