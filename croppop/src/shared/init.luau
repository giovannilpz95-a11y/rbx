--[[
	Crop Pop: the match-3 side game (Design/Features/F12 Crop Pop Puzzle).

	Shared between client and server (lives in ReplicatedStorage.CropPop).
	The farm game should only need this entry point:

		local CropPop = require(ReplicatedStorage.CropPop)
		local game = CropPop.Engine.new(CropPop.Levels.get(1), seed)
]]

return {
	Board = require(script.Board),
	Bot = require(script.Bot),
	Boosters = require(script.Boosters),
	Cup = require(script.Cup),
	Engine = require(script.Engine),
	Goals = require(script.Goals),
	Hearts = require(script.Hearts),
	LevelText = require(script.LevelText),
	Levels = require(script.Levels),
	Matcher = require(script.Matcher),
	Race = require(script.Race),
	Replay = require(script.Replay),
	Rng = require(script.Rng),
	ScoreTracks = require(script.ScoreTracks),
	Tiles = require(script.Tiles),
	TrailChest = require(script.TrailChest),
}
