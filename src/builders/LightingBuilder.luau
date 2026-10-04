--!strict
-- Warm late-afternoon farm lighting: a golden sun with soft shadows, sky-blue fill, haze for
-- depth, bloom on neon/headlights, a touch of far blur, and punchy cartoon colour grading.
-- Re-running the build command re-applies all of this (it never skips lighting).

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
	Lighting.ClockTime = 15.4
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = 3.4
	-- Warm sunlit tops, cool sky-blue shadows: the classic cartoon look.
	Lighting.ColorShift_Top = Color3.fromRGB(255, 226, 180)
	Lighting.ColorShift_Bottom = Color3.fromRGB(120, 150, 210)
	Lighting.Ambient = Color3.fromRGB(100, 96, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 190)
	Lighting.EnvironmentDiffuseScale = 0.75
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.ExposureCompensation = 0.15

	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(214, 228, 255)
	atmosphere.Decay = Color3.fromRGB(255, 196, 150)
	atmosphere.Glare = 0.8
	atmosphere.Haze = 1.6

	local sky = ensure("Sky", "Sky") :: Sky
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8
	sky.CelestialBodiesShown = true

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.65
	bloom.Size = 30
	bloom.Threshold = 1.25

	local color = ensure("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
	color.Saturation = 0.22
	color.Contrast = 0.1
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 248, 236)

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.08
	rays.Spread = 0.75

	-- Only the far scenery softens; the road and chickens stay crisp.
	local dof = ensure("DepthOfFieldEffect", "DepthOfField") :: DepthOfFieldEffect
	dof.FarIntensity = 0.12
	dof.FocusDistance = 140
	dof.InFocusRadius = 160
	dof.NearIntensity = 0

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
