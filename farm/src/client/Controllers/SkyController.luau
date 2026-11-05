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

---------------------------------------------------------------------------------------------
-- The Rainbow: an arc of bands ending at a chest on one farm, for everyone on the server
---------------------------------------------------------------------------------------------

local RAINBOW_COLORS = {
	Color3.fromRGB(235, 87, 87),
	Color3.fromRGB(242, 153, 74),
	Color3.fromRGB(242, 201, 76),
	Color3.fromRGB(111, 207, 151),
	Color3.fromRGB(86, 156, 236),
	Color3.fromRGB(155, 114, 230),
}
local BAND = 1.4 -- studs per band
local SPAN = 70 -- studs from the far end of the arc to the chest
local RISE = 64 -- the arc's control-point height

type RainbowView = { key: string, model: Model, pos: Vector3, endsAt: number, opened: boolean, pending: number? }
local rainbowView: RainbowView? = nil

local function buildRainbow(pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Rainbow"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = model
		return p
	end
	-- The chest: a wooden box with a gold band and a glow
	local base = CFrame.new(pos)
	local box = part("Chest", Vector3.new(2.6, 1.6, 1.8), base * CFrame.new(0, 0.8, 0), Palette.wood)
	part("Lid", Vector3.new(2.7, 0.6, 1.9), base * CFrame.new(0, 1.9, 0), Palette.woodDark)
	part("Band", Vector3.new(0.4, 2.3, 1.95), base * CFrame.new(0, 1.15, 0), Palette.coins, Enum.Material.Neon)
	model.PrimaryPart = box
	local light = Instance.new("PointLight")
	light.Color = Palette.coins
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = box
	local glints = Instance.new("ParticleEmitter")
	glints.Color = ColorSequence.new(Palette.coins, Palette.cream)
	glints.LightEmission = 1
	glints.Size = NumberSequence.new(0.35, 0)
	glints.Transparency = NumberSequence.new(0.1, 1)
	glints.Lifetime = NumberRange.new(0.8, 1.2)
	glints.Rate = if reduced() then 3 else 8
	glints.Speed = NumberRange.new(1, 2)
	glints.SpreadAngle = Vector2.new(60, 60)
	glints.Parent = box
	-- The arc: one beam per band, concentric, from the far end down to the chest
	local anchor = part("Arc", Vector3.one * 0.2, base, Palette.cream)
	anchor.Transparency = 1
	local dir = Vector3.new(1, 0, 0.35).Unit
	for i, color in RAINBOW_COLORS do
		local k = (i - 1) * BAND
		local a = Instance.new("Attachment")
		a.Parent = anchor -- parented first: WorldPosition needs it
		a.WorldPosition = pos - dir * (SPAN + k)
		local b = Instance.new("Attachment")
		b.Parent = anchor
		b.WorldPosition = pos + dir * k
		a.Axis, b.Axis = Vector3.yAxis, Vector3.yAxis
		a.SecondaryAxis, b.SecondaryAxis = dir, dir
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a, b
		beam.CurveSize0 = RISE + k * 1.3
		beam.CurveSize1 = -(RISE + k * 1.3)
		beam.Width0, beam.Width1 = BAND, BAND
		beam.Segments = 40
		beam.FaceCamera = true
		beam.LightEmission = 0.5
		beam.Color = ColorSequence.new(color)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.35),
			NumberSequenceKeypoint.new(1, 0.25),
		})
		beam.Parent = anchor
	end
	return model
end

local function clearRainbow()
	if rainbowView then
		rainbowView.model:Destroy()
		rainbowView = nil
	end
end

local function applyRainbow(text: string)
	if text == "" then
		clearRainbow()
		return
	end
	local ok, r = pcall(HttpService.JSONDecode, HttpService, text)
	if not ok or type(r) ~= "table" or type(r.x) ~= "number" then
		clearRainbow()
		return
	end
	if rainbowView and rainbowView.key == text then
		return
	end
	clearRainbow()
	local pos = Vector3.new(r.x, r.y, r.z)
	local model = buildRainbow(pos)
	model.Parent = starFolder()
	rainbowView = { key = text, model = model, pos = pos, endsAt = r.endsAt, opened = false }
	local minutes = math.max(1, math.floor((r.endsAt - ClientStore.now()) / 60 + 0.5))
	if r.owner == Players.LocalPlayer.UserId then
		Hud.toast(
			string.format(
				"A rainbow ends on your farm, by the gate! Open its chest within %d minutes. Neighbors who visit get one too.",
				minutes
			),
			"celebrate"
		)
	else
		Hud.toast(
			string.format(
				"A rainbow ends on %s's farm! Visit within %d minutes for a chest (the Notice Board has a Visit button).",
				tostring(r.name),
				minutes
			),
			"celebrate"
		)
	end
end

local function stepRainbow(root: BasePart?, clock: number)
	local view = rainbowView
	if view == nil or view.opened or root == nil then
		return
	end
	if view.pending and clock - view.pending < 2 then
		return
	end
	local offset = root.Position - view.pos
	if Vector3.new(offset.X, 0, offset.Z).Magnitude <= CATCH_STUDS then
		view.pending = clock
		Remotes.fire("Sky_Rainbow")
	end
end

---------------------------------------------------------------------------------------------
-- The Golden Goose: a rare visitor on one farm, for everyone on the server
---------------------------------------------------------------------------------------------

local GOOSE_WHITE = Color3.fromRGB(250, 246, 236)
local GOOSE_GOLD = Color3.fromRGB(255, 214, 102)
local BEAK = Color3.fromRGB(242, 153, 74)

type GooseView = { key: string, model: Model, pos: Vector3, petted: boolean, pending: number? }
local gooseView: GooseView? = nil

local function buildGoose(): Model
	local model = Instance.new("Model")
	model.Name = "GoldenGoose"
	local function part(
		name: string,
		shape: Enum.PartType,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		neon: boolean?
	)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = offset
		p.Color = color
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = model
		return p
	end
	local body = part("Body", Enum.PartType.Ball, Vector3.new(3, 2.2, 2.2), CFrame.new(0, 1.6, 0), GOOSE_WHITE)
	part("WingL", Enum.PartType.Ball, Vector3.new(2.2, 1.1, 0.5), CFrame.new(0.1, 1.9, -1.05), GOOSE_GOLD, true)
	part("WingR", Enum.PartType.Ball, Vector3.new(2.2, 1.1, 0.5), CFrame.new(0.1, 1.9, 1.05), GOOSE_GOLD, true)
	part(
		"Neck",
		Enum.PartType.Cylinder,
		Vector3.new(1.8, 0.6, 0.6),
		CFrame.new(1.2, 2.9, 0) * CFrame.Angles(0, 0, math.rad(75)),
		GOOSE_WHITE
	)
	part("Head", Enum.PartType.Ball, Vector3.new(1, 1, 1), CFrame.new(1.45, 3.8, 0), GOOSE_WHITE)
	part("Beak", Enum.PartType.Block, Vector3.new(0.6, 0.25, 0.35), CFrame.new(2.05, 3.7, 0), BEAK)
	part("Crown", Enum.PartType.Ball, Vector3.new(0.5, 0.3, 0.5), CFrame.new(1.45, 4.3, 0), GOOSE_GOLD, true)
	part("FootL", Enum.PartType.Block, Vector3.new(0.7, 0.15, 0.4), CFrame.new(0.3, 0.1, -0.5), BEAK)
	part("FootR", Enum.PartType.Block, Vector3.new(0.7, 0.15, 0.4), CFrame.new(0.3, 0.1, 0.5), BEAK)
	model.WorldPivot = CFrame.new() -- at its feet, so PivotTo stands it on the ground
	local light = Instance.new("PointLight")
	light.Color = GOOSE_GOLD
	light.Range = 12
	light.Brightness = 1
	light.Parent = body
	local glints = Instance.new("ParticleEmitter")
	glints.Color = ColorSequence.new(GOOSE_GOLD, Palette.cream)
	glints.LightEmission = 1
	glints.Size = NumberSequence.new(0.3, 0)
	glints.Transparency = NumberSequence.new(0.1, 1)
	glints.Lifetime = NumberRange.new(0.8, 1.2)
	glints.Rate = if reduced() then 2 else 6
	glints.Speed = NumberRange.new(0.5, 1.5)
	glints.SpreadAngle = Vector2.new(90, 90)
	glints.Parent = body
	return model
end

local function clearGoose()
	if gooseView then
		gooseView.model:Destroy()
		gooseView = nil
	end
end

local function applyGoose(text: string)
	if text == "" then
		clearGoose()
		return
	end
	local ok, g = pcall(HttpService.JSONDecode, HttpService, text)
	if not ok or type(g) ~= "table" or type(g.x) ~= "number" then
		clearGoose()
		return
	end
	if gooseView and gooseView.key == text then
		return
	end
	clearGoose()
	local pos = Vector3.new(g.x, g.y, g.z)
	local model = buildGoose()
	model:PivotTo(CFrame.new(pos))
	model.Parent = starFolder()
	gooseView = { key = text, model = model, pos = pos, petted = false }
	if g.owner == Players.LocalPlayer.UserId then
		Hud.toast(
			"The Golden Goose landed on your farm, up the path from the gate! Pet it for a Golden Egg. Neighbors who visit get one too.",
			"celebrate"
		)
	end -- everyone else hears it from the Town Crier
end

local function stepGoose(root: BasePart?, clock: number)
	local view = gooseView
	if view == nil then
		return
	end
	-- A slow waddle-bob, turning to the player who's nearest it (this one)
	local face = CFrame.new(view.pos)
	if root then
		local look = Vector3.new(root.Position.X, view.pos.Y, root.Position.Z)
		if (look - view.pos).Magnitude > 0.5 then
			face = CFrame.lookAt(view.pos, look) * CFrame.Angles(0, math.rad(90), 0)
		end
	end
	local bob = if reduced() then 0 else 0.12 * math.sin(clock * 3)
	view.model:PivotTo(face * CFrame.new(0, bob, 0))
	if view.petted or root == nil or (view.pending and clock - view.pending < 2) then
		return
	end
	local offset = root.Position - view.pos
	if Vector3.new(offset.X, 0, offset.Z).Magnitude <= CATCH_STUDS then
		view.pending = clock
		Remotes.fire("Sky_Goose")
	end
end

local function step()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local clock = os.clock()
	local now = ClientStore.now()
	stepRainbow(root, clock)
	stepGoose(root, clock)
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
	Hud.handlers.RainbowOpened = function(payload)
		if rainbowView then
			rainbowView.opened = true
			local lid = rainbowView.model:FindFirstChild("Lid") :: BasePart?
			if lid then
				lid.CFrame = lid.CFrame * CFrame.new(0, 0.3, 0.9) * CFrame.Angles(math.rad(-70), 0, 0)
			end
		end
		Hud.toast("The rainbow's chest: " .. tostring(payload.text), "celebrate")
	end
	Hud.handlers.GooseEgg = function(payload)
		if gooseView then
			gooseView.petted = true
		end
		Hud.toast(
			string.format("A Golden Egg! It sold on the spot: +%d Coins  +%d XP", payload.coins or 0, payload.xp or 0),
			"celebrate"
		)
	end
	Workspace:GetAttributeChangedSignal("SkyGoose"):Connect(function()
		applyGoose(Workspace:GetAttribute("SkyGoose") or "")
	end)
	applyGoose(Workspace:GetAttribute("SkyGoose") or "")
	Workspace:GetAttributeChangedSignal("SkyRainbow"):Connect(function()
		applyRainbow(Workspace:GetAttribute("SkyRainbow") or "")
	end)
	applyRainbow(Workspace:GetAttribute("SkyRainbow") or "")
	RunService.RenderStepped:Connect(step)
end

return SkyController
