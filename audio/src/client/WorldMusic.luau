--[[
	Music for where the player is: the farm's tunes at home and in the Town Square, the
	visiting tune on someone else's farm. The farm server keeps the attribute OnPlot on each
	player (the owner's UserId of the farm they stand on, 0 off any farm; farm SocialService).
	GameAudio holds the change back while Crop Pop is open.
]]

local Players = game:GetService("Players")

local WorldMusic = {}

function WorldMusic.contextFor(onPlot: any, userId: number): string
	if type(onPlot) == "number" and onPlot ~= 0 and onPlot ~= userId then
		return "Visit"
	end
	return "Farm"
end

function WorldMusic.start(GameAudio)
	local player = Players.LocalPlayer
	local function update()
		GameAudio.setWorld(WorldMusic.contextFor(player:GetAttribute("OnPlot"), player.UserId))
	end
	player:GetAttributeChangedSignal("OnPlot"):Connect(update)
	update()
end

return WorldMusic
