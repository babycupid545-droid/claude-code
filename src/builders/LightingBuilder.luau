--!strict
-- Warm afternoon farm lighting: soft shadows, gentle haze for depth, bloom only on neon
-- (headlights, lamps), a touch of far blur and mild cartoon colour grading.
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

-- Bump when the look changes so places built with an older version get updated at runtime.
LightingBuilder.Version = 3

function LightingBuilder.build()
	-- Future gives the nicest lamps and shadows; only plugins/command bar may set it.
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	Lighting:SetAttribute("LightingVersion", LightingBuilder.Version)
	Lighting.ClockTime = 15.2
	Lighting.GeographicLatitude = 28
	-- Kept moderate: with Future lighting, bloom and sky glare stack up quickly and wash the
	-- screen out when you look toward the sun.
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = -0.1
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 220)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.Ambient = Color3.fromRGB(92, 88, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 160)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(200, 216, 240)
	atmosphere.Decay = Color3.fromRGB(150, 140, 170)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.9

	local sky = ensure("Sky", "Sky") :: Sky
	sky.SunAngularSize = 11
	sky.MoonAngularSize = 8
	sky.CelestialBodiesShown = true

	-- Only neon (headlights, lamps, beacons) should bloom.
	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.3
	bloom.Size = 24
	bloom.Threshold = 2

	local color = ensure("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
	color.Saturation = 0.15
	color.Contrast = 0.05
	color.Brightness = 0
	color.TintColor = Color3.fromRGB(255, 250, 244)

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.02
	rays.Spread = 0.6

	-- Only the far scenery softens; the road and chickens stay crisp.
	local dof = ensure("DepthOfFieldEffect", "DepthOfField") :: DepthOfFieldEffect
	dof.FarIntensity = 0.1
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
