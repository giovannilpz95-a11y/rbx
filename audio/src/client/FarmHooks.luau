--[[
	Farm sounds without sound calls in the farm code: listens to the farm's own remotes
	(ReplicatedStorage.FarmRemotes) and lets FarmCues work out what happened.

	  State_Snapshot  compare with the last one: planting, harvesting, building, selling...
	  Reward_Popup    order delivered or level up: their jingle (and the Coins stay quiet)
	  Toast           the farm's "can't do that" messages: a soft error blip
	  every 0.5 s     timers that ran out: a factory job or a building finishing
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FarmHooks = {}

local REWARD_WINDOW = 0.75 -- seconds a popup's jingle covers the snapshot that follows it
local TICK = 0.5

function FarmHooks.start(GameAudio)
	local FarmCues = GameAudio.FarmCues
	local remotes = ReplicatedStorage:WaitForChild("FarmRemotes", 30)
	if remotes == nil then
		return -- no farm in this place (Crop Pop on its own)
	end

	local last: { [string]: any }? = nil
	local receivedAt = 0
	local lastPopupAt = -math.huge

	-- The farm's clock, which the debug panel can speed up (snapshot.timeScale).
	local function farmNow(): number?
		if last == nil or type(last.serverNow) ~= "number" then
			return nil
		end
		return last.serverNow + (os.clock() - receivedAt) * (last.timeScale or 1)
	end

	remotes:WaitForChild("Reward_Popup").OnClientEvent:Connect(function(payload)
		-- The Town Crier is news from someone else's farm; nothing changed on ours.
		if type(payload) == "table" and payload.kind ~= "Crier" then
			lastPopupAt = os.clock()
		end
		GameAudio.playCues(FarmCues.popup(payload))
	end)

	remotes:WaitForChild("Toast").OnClientEvent:Connect(function()
		GameAudio.play("UiError")
	end)

	local lastTick: number? = nil
	remotes:WaitForChild("State_Snapshot").OnClientEvent:Connect(function(state)
		local rewardShown = os.clock() - lastPopupAt < REWARD_WINDOW
		GameAudio.playCues(FarmCues.diff(last, state, { rewardShown = rewardShown }))
		last = state
		receivedAt = os.clock()
		lastTick = lastTick or farmNow()
	end)

	while true do
		task.wait(TICK)
		local now = farmNow()
		if now and lastTick then
			GameAudio.playCues(FarmCues.timed(last, lastTick, now))
		end
		lastTick = now
	end
end

return FarmHooks
