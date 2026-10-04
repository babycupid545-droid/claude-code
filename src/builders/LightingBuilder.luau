--!strict
-- Bright, warm, cartoony lighting: soft shadows, light haze for depth, gentle bloom and a
-- little extra saturation. Low-poly builds live or die by their lighting.

local Lighting = game:GetService("Lighting")

local LightingBuilder = {}

local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

function LightingBuilder.build()
	-- Future gives the nicest lamps and shadows; only plugins/command bar may set it.
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 14.6
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(96, 92, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 175)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0.1

	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(205, 225, 255)
	atmosphere.Decay = Color3.fromRGB(120, 150, 210)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.2

	local sky = ensure("Sky", "Sky") :: Sky
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.CelestialBodiesShown = true

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.5
	bloom.Size = 28
	bloom.Threshold = 1.4

	local color = ensure("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
	color.Saturation = 0.18
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 250, 242)

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.05
	rays.Spread = 0.7

	-- Soft 3D clouds around the islands.
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end
end

return LightingBuilder
