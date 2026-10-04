--!strict
-- Screen shake and field-of-view punches, layered on top of the normal camera.

local RunService = game:GetService("RunService")

local CameraFx = {}

local trauma = 0
local fovOffset = 0
local fovTarget = 0
local appliedFov = 0
local seed = math.random() * 1000

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
			camera.CFrame *= CFrame.Angles(rx, ry, rz)
			trauma = math.max(0, trauma - dt * 1.6)
		end
	end)
end

return CameraFx
