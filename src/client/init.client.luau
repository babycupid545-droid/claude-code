--!strict
-- Client entry point.

local Controllers = script.Controllers
require(Controllers.TrafficRenderer).start()
require(Controllers.MovementController).start()
require(Controllers.EggController).start()
require(Controllers.DriverController).start()
require(Controllers.RoundUI).start()
