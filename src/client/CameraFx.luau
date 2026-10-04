--!strict
-- Screen shake and field-of-view punches, layered on top of the normal camera.

local RunService = game:GetService("RunService")

local CameraFx = {}

local trauma = 0
local fovOffset = 0
local fovTarget = 0
local appliedFov = 0
local seed = math.random() * 1000
-- The camera before and after last frame's shake, so it can be undone.
local unshaken: CFrame? = nil
local shaken: CFrame? = nil

-- Adds shake (0..1); it decays on its own.
function CameraFx.shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

-- Briefly widens the view (e.g. GO!, gliding).
function CameraFx.fovPunch(amount: number)
	fovOffset += amount
end

-- A held FOV change (e.g. while gliding); 0 to release.
function CameraFx.setFovTarget(amount: number)
	fovTarget = amount
end

function CameraFx.start()
	-- The default camera reads its own look direction back from the camera, and a Scriptable
	-- camera (Road Rage) keeps whatever was set, so shake applied after them would build up
	-- into a permanent tilt. Take last frame's shake off before they run.
	RunService:BindToRenderStep("CameraFxUndo", Enum.RenderPriority.Camera.Value - 1, function()
		local camera = workspace.CurrentCamera
		if camera and shaken and unshaken and camera.CFrame == shaken then
			camera.CFrame = unshaken
		end
		shaken, unshaken = nil, nil
	end)
	RunService:BindToRenderStep("CameraFx", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		-- Undo last frame's FOV change before applying this frame's.
		camera.FieldOfView -= appliedFov
		fovOffset += (fovTarget - fovOffset) * math.min(1, dt * 6)
		appliedFov = fovOffset
		camera.FieldOfView += appliedFov

		if trauma > 0 then
			local t = os.clock() * 25
			local s = trauma * trauma
			local rx = (math.noise(seed, t) * 2) * s * 0.05
			local ry = (math.noise(seed + 10, t) * 2) * s * 0.05
			local rz = (math.noise(seed + 20, t) * 2) * s * 0.04
			unshaken = camera.CFrame
			camera.CFrame *= CFrame.Angles(rx, ry, rz)
			shaken = camera.CFrame
			trauma = math.max(0, trauma - dt * 1.6)
		end
	end)
end

return CameraFx
