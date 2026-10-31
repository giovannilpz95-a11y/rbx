--!strict
-- Gives Roblox badges for Town Record medals (shared/Badges). Each call checks first, so a
-- badge already owned isn't awarded twice; failures (Studio, an unpublished place, a
-- throttled request) are only logged, because the medal itself is already saved.

local BadgeService = game:GetService("BadgeService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Badges = require(Shared.Badges)

local DataService = require(script.Parent.DataService)

local FarmBadges = {}

function FarmBadges.award(player: Player, badgeId: number?)
	if badgeId == nil then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
				BadgeService:AwardBadge(player.UserId, badgeId)
			end
		end)
		if not ok then
			warn(string.format("[Badges] %d for %s: %s", badgeId, player.Name, tostring(err)))
		end
	end)
end

-- On join: any badge for a medal claimed before its badge existed
function FarmBadges.playerLoaded(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	for _, badgeId in Badges.earned(data) do
		FarmBadges.award(player, badgeId)
	end
end

return FarmBadges
