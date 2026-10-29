--[[
	Crop Pop: the match-3 side game (Design/Features/F12 Crop Pop Puzzle).

	Shared between client and server (lives in ReplicatedStorage.CropPop).
	The farm game should only need this entry point:

		local CropPop = require(ReplicatedStorage.CropPop)
		local game = CropPop.Engine.new(CropPop.Levels.get(1), seed)
]]

return {
	Board = require(script.Board),
	Engine = require(script.Engine),
	Goals = require(script.Goals),
	Levels = require(script.Levels),
	Matcher = require(script.Matcher),
	Replay = require(script.Replay),
	Rng = require(script.Rng),
	Tiles = require(script.Tiles),
}
