--!strict
-- Farm emotes and the photo spots' group pose (Config/Emotes, EmoteService; Design/14 I1, I2).
-- The Emotes panel (H, or the Emote button) lists the six; picking one plays its stock R15
-- animation on our own avatar (Roblox replicates it to everyone) and asks the server to hand
-- us its prop. A tap on a Town Square photo spot asks for a group pose: everyone standing in
-- the frame strikes it, and the one who asked is offered a Roblox capture.

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Emotes)

local ReachController = require(script.Parent.Parent.Controllers.ReachController)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Ui = require(script.Parent.Ui)

local EmotesUi = {}

local lastEmote = -math.huge
local playing: AnimationTrack? = nil
local playingConn: RBXScriptConnection? = nil
local animations: { [string]: Animation } = {}

local function sorted(): { Config.Emote }
	local list = {}
	for _, def in Config.emotes do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

local function stop()
	if playingConn then
		playingConn:Disconnect()
		playingConn = nil
	end
	if playing then
		playing:Stop(0.25)
		playing = nil
	end
end

-- Play the emote's animation on our avatar for Config.seconds, or until we walk off. R6
-- avatars have no R15 emotes: they still get the prop.
local function animate(emoteId: string)
	local def = Config.emotes[emoteId]
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if def == nil or humanoid == nil or animator == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	stop()
	local animation = animations[def.animation]
	if animation == nil then
		animation = Instance.new("Animation")
		animation.AnimationId = def.animation
		animations[def.animation] = animation
	end
	local ok, track = pcall(animator.LoadAnimation, animator, animation)
	if not ok or track == nil then
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true -- the short ones (wave, point) repeat until the prop goes
	track:Play(0.15)
	playing = track
	local started = time()
	local hum = humanoid :: Humanoid
	playingConn = RunService.Heartbeat:Connect(function()
		if time() - started >= Config.seconds or hum.MoveDirection.Magnitude > 0.1 or hum.Health <= 0 then
			stop()
		end
	end)
end

function EmotesUi.play(emoteId: string)
	if Config.emotes[emoteId] == nil or time() - lastEmote < Config.cooldown then
		return
	end
	lastEmote = time()
	animate(emoteId)
	Remotes.fire("Emote_Play", emoteId)
end

local function render(_state: { [string]: any }, body: ScrollingFrame, title: TextLabel)
	title.Text = "Emotes"
	for _, def in sorted() do
		Ui.button(string.format("%s  %s", def.icon, def.displayName), function()
			Panels.close()
			EmotesUi.play(def.id)
		end, {
			Size = UDim2.new(1, -8, 0, 44),
			LayoutOrder = def.order,
			Parent = body,
		})
	end
	Ui.label(
		"Everyone nearby sees your emote. Walking stops it. Tap a PHOTO SPOT in the Town Square for a group pose.",
		{
			Size = UDim2.new(1, -8, 0, 40),
			TextWrapped = true,
			TextSize = 13,
			TextColor3 = Ui.colors.muted,
			LayoutOrder = 100,
			Parent = body,
		}
	)
end

-- Offer the pose to the Roblox Captures gallery (Roblox's own flow: nothing leaves Roblox
-- another way). Not every device has it; then a plain screenshot is the way.
local function capture()
	local ok = pcall(function()
		CaptureService:CaptureScreenshot(function(contentId)
			pcall(function()
				CaptureService:PromptSaveCapturesToGallery({ contentId }, function() end)
			end)
		end)
	end)
	if not ok then
		Hud.toast("Take a screenshot to keep this one!")
	end
end

function EmotesUi.init()
	Panels.register("Emotes", render)
	Hud.handlers.GroupPose = function(payload)
		lastEmote = time()
		animate(Config.photoEmote)
		local count = if type(payload.count) == "number" then payload.count else 1
		local spot = if type(payload.spot) == "string" then payload.spot else "the photo spot"
		if payload.presser then
			Hud.toast(
				if count > 1
					then string.format("Say cheese! %d farmers posing at the %s", count, spot)
					else string.format("Say cheese at the %s!", spot),
				"celebrate"
			)
			task.delay(1.2, capture) -- once the pose is up
		else
			Hud.toast(
				string.format(
					"%s called a group pose at the %s. Say cheese!",
					tostring(payload.by or "A neighbor"),
					spot
				)
			)
		end
	end
	-- The photo spots stand in the Town Square, off our plot: walk into the frame, then pose
	local previous = ReachController.otherTarget
	ReachController.otherTarget = function(part: BasePart)
		if part:GetAttribute("Interact") == "PhotoSpot" then
			local kind = part:GetAttribute("PhotoSpot")
			return function()
				Remotes.fire("Emote_Pose", kind)
			end, true
		end
		return previous(part)
	end
end

return EmotesUi
