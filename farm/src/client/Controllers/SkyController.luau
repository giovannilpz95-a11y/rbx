--!strict
-- Sky events on this client (SkyService, Config/Sky): the Rain Shower's clouds and rain, the
-- Starfall's dusk sky and this player's own stars. Walking up to a landed star catches it (the
-- server checks the distance and pays). Everything here is local and for show: the server
-- decides what the events do.

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Sky)
local Palette = require(Shared.Art.Palette)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Remotes = require(script.Parent.Parent.Remotes)
local Hud = require(script.Parent.Parent.UI.Hud)
local Ui = require(script.Parent.Parent.UI.Ui)

local SkyController = {}

local CATCH_STUDS = 7 -- the server allows Config.starReach
local FADE = 4 -- seconds the sky takes to change
local RAIN_RATE = 380
local RAIN_RATE_REDUCED = 90
local STAR_COLOR = Palette.coins
local LUCKY_COLOR = Palette.gems

type Shown = { kind: string, startsAt: number, endsAt: number }
type StarView = {
	model: Model,
	pos: Vector3,
	landAt: number, -- os.clock() it lands
	goneAt: number, -- server time it goes
	pending: number?, -- os.clock() a catch was sent
}

local shown: Shown? = nil
local stars: { [number]: StarView } = {}
local folder: Folder? = nil
local rainPart: BasePart? = nil
local rainEmitter: ParticleEmitter? = nil
local clouds: Clouds? = nil
local grade: ColorCorrectionEffect? = nil
local base: { [string]: any }? = nil -- the lighting before the sky changed

local function reduced(): boolean
	return Ui.theme.Motion.reduced == true
end

local function tween(target: Instance, props: { [string]: any })
	local info = TweenInfo.new(if reduced() then 0 else FADE, Enum.EasingStyle.Sine)
	TweenService:Create(target, info, props):Play()
end

local function starFolder(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "SkyStars"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function air(): Atmosphere?
	return Lighting:FindFirstChildOfClass("Atmosphere")
end

-- The sky for an event (nil: back to the farm's sunny afternoon)
local function setSky(kind: string?)
	if base == nil then
		local a = air()
		base = {
			Brightness = Lighting.Brightness,
			ClockTime = Lighting.ClockTime,
			Density = a and a.Density or 0,
		}
	end
	local saved = base :: { [string]: any }
	if grade == nil then
		local g = Instance.new("ColorCorrectionEffect")
		g.Name = "SkyGrade"
		g.Parent = Lighting
		grade = g
	end
	if clouds == nil then
		local c = Instance.new("Clouds")
		c.Name = "SkyClouds"
		c.Cover = 0
		c.Density = 0.7
		c.Color = Color3.fromRGB(200, 206, 214)
		c.Parent = Workspace.Terrain
		clouds = c
	end
	local a = air()
	if kind == "Rain" then
		tween(Lighting, { Brightness = saved.Brightness * 0.7 })
		tween(grade :: Instance, { Brightness = -0.05, Saturation = -0.12, TintColor = Color3.fromRGB(222, 232, 242) })
		tween(clouds :: Instance, { Cover = 0.8 })
		if a then
			tween(a, { Density = saved.Density + 0.14 })
		end
	elseif kind == "Starfall" then
		tween(Lighting, { ClockTime = 18.6, Brightness = saved.Brightness * 0.8 })
		tween(grade :: Instance, { Brightness = -0.03, Saturation = 0, TintColor = Color3.fromRGB(214, 214, 255) })
		tween(clouds :: Instance, { Cover = 0 })
		if a then
			tween(a, { Density = saved.Density })
		end
	else
		tween(Lighting, { ClockTime = saved.ClockTime, Brightness = saved.Brightness })
		tween(grade :: Instance, { Brightness = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
		tween(clouds :: Instance, { Cover = 0 })
		if a then
			tween(a, { Density = saved.Density })
		end
	end
end

-- Rain falls from a sheet that follows the camera
local function setRain(on: boolean)
	if on and rainPart == nil then
		local p = Instance.new("Part")
		p.Name = "SkyRain"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(90, 1, 90)
		local e = Instance.new("ParticleEmitter")
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Color = ColorSequence.new(Color3.fromRGB(200, 224, 255))
		e.LightEmission = 0.2
		e.Size = NumberSequence.new(0.09)
		e.Squash = NumberSequence.new(2.6)
		e.Transparency = NumberSequence.new(0.35)
		e.Lifetime = NumberRange.new(0.7, 0.9)
		e.Speed = NumberRange.new(60, 70)
		e.Rate = if reduced() then RAIN_RATE_REDUCED else RAIN_RATE
		e.Parent = p
		p.Parent = Workspace
		rainPart, rainEmitter = p, e
	elseif not on and rainPart then
		local p = rainPart
		rainPart, rainEmitter = nil, nil
		local e = p:FindFirstChildOfClass("ParticleEmitter")
		if e then
			e.Enabled = false
		end
		task.delay(1.5, function()
			p:Destroy()
		end)
	end
end

local function intro(kind: string)
	local def = Config.kinds[kind]
	if def == nil then
		return
	end
	if kind == "Rain" then
		Hud.toast(
			string.format(
				"A Rain Shower! Growing crops grow %d%% faster for %d minutes, and some may turn Dewkissed.",
				math.floor((def.growBoost or 0) * 100 + 0.5),
				def.seconds // 60
			),
			"celebrate"
		)
	else
		Hud.toast(
			"Starfall! Walk up to the stars landing around you to catch them. Growing crops may turn Starlit.",
			"celebrate"
		)
	end
end

local function apply(text: string)
	local event: Shown? = nil
	if text ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, text)
		if ok and type(decoded) == "table" and Config.kinds[decoded.kind] then
			event = decoded
		end
	end
	local was = shown
	shown = event
	if event and (was == nil or was.startsAt ~= event.startsAt or was.kind ~= event.kind) then
		setSky(event.kind)
		setRain(event.kind == "Rain")
		if ClientStore.now() < event.endsAt then
			intro(event.kind)
		end
	elseif event == nil and was ~= nil then
		setSky(nil)
		setRain(false)
	end
end

---------------------------------------------------------------------------------------------
-- Stars
---------------------------------------------------------------------------------------------

local function buildStar(lucky: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Star"
	local color = if lucky then LUCKY_COLOR else STAR_COLOR
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * (if lucky then 2 else 1.5)
	core.Material = Enum.Material.Neon
	core.Color = color
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Parent = model
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = core
	local glints = Instance.new("ParticleEmitter")
	glints.Color = ColorSequence.new(color, Palette.cream)
	glints.LightEmission = 1
	glints.Size = NumberSequence.new(0.4, 0)
	glints.Transparency = NumberSequence.new(0.1, 1)
	glints.Lifetime = NumberRange.new(0.6, 1)
	glints.Rate = if reduced() then 4 else 12
	glints.Speed = NumberRange.new(1, 2)
	glints.SpreadAngle = Vector2.new(180, 180)
	glints.Parent = core
	model.PrimaryPart = core
	return model
end

local function addStar(payload: { [string]: any })
	if type(payload.id) ~= "number" or stars[payload.id] then
		return
	end
	local pos = Vector3.new(payload.x, payload.y, payload.z)
	local model = buildStar(payload.lucky == true)
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 60, 0)))
	model.Parent = starFolder()
	stars[payload.id] = {
		model = model,
		pos = pos,
		landAt = os.clock() + Config.starFall,
		goneAt = payload.goneAt or (ClientStore.now() + 120),
	}
end

local function removeStar(id: number, caught: boolean)
	local star = stars[id]
	if star == nil then
		return
	end
	stars[id] = nil
	local model = star.model
	if not caught or reduced() then
		model:Destroy()
		return
	end
	-- Up and away, shrinking
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / 0.5)
		if model.Parent == nil then
			conn:Disconnect()
			return
		end
		model:PivotTo(CFrame.new(star.pos + Vector3.new(0, 1 + t * 6, 0)))
		model:ScaleTo(math.max(0.05, 1 - t))
		if t >= 1 then
			conn:Disconnect()
			model:Destroy()
		end
	end)
end

local function step()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local clock = os.clock()
	local now = ClientStore.now()
	for id, star in stars do
		if now > star.goneAt then
			removeStar(id, false)
			continue
		end
		-- Falling, then a gentle bob and spin where it landed
		local fall = 1 - math.clamp((star.landAt - clock) / Config.starFall, 0, 1)
		local height = if fall < 1 then 60 * (1 - fall) ^ 2 else 0.3 * math.sin(clock * 2.4 + id)
		star.model:PivotTo(CFrame.new(star.pos + Vector3.new(0, height, 0)) * CFrame.Angles(0, clock * 1.5 + id, 0))
		if fall >= 1 and root and (star.pending == nil or clock - (star.pending :: number) > 2) then
			local offset = root.Position - star.pos
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= CATCH_STUDS then
				star.pending = clock
				Remotes.fire("Sky_Collect", id)
			end
		end
	end
	if rainPart then
		local camera = Workspace.CurrentCamera
		if camera then
			local at = camera.Focus.Position
			rainPart.CFrame = CFrame.new(at.X, at.Y + 32, at.Z)
		end
		if rainEmitter then
			rainEmitter.Rate = if reduced() then RAIN_RATE_REDUCED else RAIN_RATE
		end
	end
end

function SkyController.init()
	Hud.handlers.Star = addStar
	Hud.handlers.StarCaught = function(payload)
		if type(payload.id) == "number" then
			removeStar(payload.id, true)
		end
		if type(payload.extra) == "string" and payload.extra ~= "" then
			Hud.toast("Star bonus: " .. payload.extra .. "!", "celebrate")
		end
	end
	Workspace:GetAttributeChangedSignal("SkyEvent"):Connect(function()
		apply(Workspace:GetAttribute("SkyEvent") or "")
	end)
	apply(Workspace:GetAttribute("SkyEvent") or "")
	RunService.RenderStepped:Connect(step)
end

return SkyController
