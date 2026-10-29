--!strict
-- Sunny afternoon lighting for the farm (Design/12 Art & Audio Direction: warm afternoon sun,
-- soft shadows, light bloom). Colors are pushed a little warmer and more saturated so the
-- flat palette doesn't wash out in Roblox's lighting (16 §1.6). The server calls apply() once.

local ArtLighting = {}

local function effect(lighting: Instance, className: string, name: string): Instance
	local existing = lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local e = Instance.new(className)
	e.Name = name
	e.Parent = lighting
	return e
end

function ArtLighting.apply(lighting: Lighting)
	lighting.ClockTime = 14.5
	lighting.GeographicLatitude = 35
	lighting.Brightness = 2.4
	lighting.Ambient = Color3.fromRGB(118, 108, 98)
	lighting.OutdoorAmbient = Color3.fromRGB(150, 142, 132)
	lighting.ColorShift_Top = Color3.fromRGB(255, 238, 214)
	lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	lighting.EnvironmentDiffuseScale = 0.6
	lighting.EnvironmentSpecularScale = 0.15
	lighting.GlobalShadows = true
	lighting.ShadowSoftness = 0.35

	local grade = effect(lighting, "ColorCorrectionEffect", "FarmGrade") :: ColorCorrectionEffect
	grade.Saturation = 0.14
	grade.Contrast = 0.06
	grade.Brightness = 0.02
	grade.TintColor = Color3.fromRGB(255, 250, 242)

	local bloom = effect(lighting, "BloomEffect", "FarmBloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.4

	local air = effect(lighting, "Atmosphere", "FarmAir") :: Atmosphere
	air.Density = 0.22
	air.Offset = 0.1
	air.Color = Color3.fromRGB(205, 232, 246)
	air.Decay = Color3.fromRGB(150, 196, 226)
	air.Glare = 0
	air.Haze = 0.8
end

return ArtLighting
