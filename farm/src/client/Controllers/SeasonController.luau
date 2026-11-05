--!strict
-- The seasonal look (Config/Seasons, shared/Seasons): petals, leaves or snow drifting around
-- the camera and a light colour grade, switched by the calendar. Drawn only on this client,
-- so it costs nothing on the plot's part budget. Reduce motion thins the particles.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("FarmShared")
local Config = require(Shared.Config.Seasons)
local Seasons = require(Shared.Seasons)

local ClientStore = require(script.Parent.Parent.ClientStore)
local Ui = require(script.Parent.Parent.UI.Ui)

local SeasonController = {}

local current: string? = nil
local sheet: BasePart? = nil
local emitter: ParticleEmitter? = nil
local grade: ColorCorrectionEffect? = nil

local function reduced(): boolean
	return Ui.theme.Motion.reduced == true
end

local function clear()
	if sheet then
		sheet:Destroy()
		sheet, emitter = nil, nil
	end
end

local function apply(season: Config.Season)
	if current == season.id then
		return
	end
	current = season.id
	clear()
	if grade == nil then
		local g = Instance.new("ColorCorrectionEffect")
		g.Name = "SeasonGrade"
		g.Parent = Lighting
		grade = g
	end
	local g = grade :: ColorCorrectionEffect
	g.TintColor = season.tint
	g.Saturation = season.saturation
	local spec = season.particles
	if spec == nil then
		return
	end
	local p = Instance.new("Part")
	p.Name = "SeasonDrift"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(80, 1, 80)
	local e = Instance.new("ParticleEmitter")
	local keys = {}
	for i, color in spec.colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #spec.colors - 1), color))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, spec.colors[1]))
	end
	e.Color = ColorSequence.new(keys)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Size = NumberSequence.new(spec.size)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.1),
		NumberSequenceKeypoint.new(0.85, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(7, 10)
	e.Speed = NumberRange.new(spec.speed * 0.7, spec.speed * 1.2)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(spec.sway, 0, spec.sway * 0.5)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Drag = 0.4
	e.Rate = if reduced() then spec.reducedRate else spec.rate
	e.Parent = p
	p.Parent = Workspace
	sheet, emitter = p, e
end

function SeasonController.init()
	apply(Seasons.at(ClientStore.now()))
	local checked = 0
	RunService.RenderStepped:Connect(function()
		local now = time()
		if now - checked >= 30 then -- the calendar only turns a few times a year
			checked = now
			apply(Seasons.at(ClientStore.now()))
		end
		local p = sheet
		if p then
			local camera = Workspace.CurrentCamera
			if camera then
				local at = camera.Focus.Position
				p.CFrame = CFrame.new(at.X, at.Y + 26, at.Z)
			end
			local season = current and Config.seasons[current]
			local spec = season and season.particles
			if emitter and spec then
				emitter.Rate = if reduced() then spec.reducedRate else spec.rate
			end
		end
	end)
end

return SeasonController
