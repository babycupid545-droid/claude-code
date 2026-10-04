--!strict
-- One colour palette for every build, so the whole world feels like one place.

local rgb = Color3.fromRGB

return {
	-- Road
	Asphalt = rgb(62, 64, 74),
	AsphaltDark = rgb(48, 50, 58),
	LaneLine = rgb(245, 245, 240),
	CenterLine = rgb(255, 196, 40),
	CurbRed = rgb(226, 72, 64),
	CurbWhite = rgb(240, 240, 235),
	-- Sidewalks
	SidewalkA = rgb(214, 206, 196),
	SidewalkB = rgb(204, 198, 190),
	SidewalkEdge = rgb(160, 150, 140),
	-- Nature
	Grass = rgb(106, 190, 90),
	GrassDark = rgb(86, 160, 74),
	Dirt = rgb(150, 102, 70),
	Rock = rgb(126, 118, 128),
	Leaf = rgb(96, 186, 86),
	LeafAutumn = rgb(240, 160, 60),
	Pine = rgb(52, 140, 92),
	Bush = rgb(78, 168, 80),
	Trunk = rgb(122, 82, 58),
	Flowers = { rgb(255, 120, 150), rgb(255, 220, 80), rgb(170, 130, 255), rgb(255, 255, 255) },
	Cloud = rgb(250, 252, 255),
	-- Farm
	BarnRed = rgb(196, 58, 52),
	BarnDark = rgb(110, 40, 40),
	Roof = rgb(84, 74, 88),
	RoofBlue = rgb(76, 110, 170),
	Trim = rgb(250, 248, 240),
	Wood = rgb(176, 124, 84),
	WoodDark = rgb(130, 88, 60),
	Hay = rgb(240, 202, 96),
	HayDark = rgb(204, 160, 70),
	Plaster = rgb(245, 238, 222),
	Brick = rgb(170, 90, 70),
	Window = rgb(150, 210, 245),
	Sail = rgb(250, 245, 235),
	Metal = rgb(190, 196, 206),
	MetalDark = rgb(90, 96, 110),
	LampGlow = rgb(255, 226, 150),
	-- Lobby
	Coop = rgb(255, 196, 92),
	Straw = rgb(246, 214, 120),
	Accent = rgb(255, 120, 60),
}
