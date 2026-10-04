--!strict
-- Client entry point.

local Controllers = script.Controllers

require(script.Sprites).start()
require(script.Anim).start()
require(script.CameraFx).start()

require(Controllers.TrafficRenderer).start()
require(Controllers.MovementController).start()
require(Controllers.EggController).start()
require(Controllers.EmoteController).start()
require(Controllers.WorldAnimator).start()
require(Controllers.ChickenAnimator).start()
require(Controllers.MusicController).start()

-- These wait for the Studio-built GUI to arrive in PlayerGui (after the first spawn).
task.spawn(function()
	require(Controllers.RoundUI).start()
end)
task.spawn(function()
	require(Controllers.MenuUI).start()
end)
task.spawn(function()
	require(Controllers.DriverController).start()
end)
