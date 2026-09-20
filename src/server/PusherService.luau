local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PusherMath = require(ReplicatedStorage.Shared.rules.PusherMath)

local PusherService = {}

function PusherService.start(machine, config)
	local m = config.machine
	local retractCenterZ = PusherMath.retractedCenterZ(m.platformDepth, m.pusherDepth, config.pusherStroke)
	local pusherY = m.baseThickness / 2 + m.pusherHeight / 2
	local startTime = os.clock()

	-- PreSimulation runs before physics each frame, so coins react to the new position this frame.
	-- If PreSimulation is unavailable in your Studio version, use RunService.Heartbeat instead.
	return RunService.PreSimulation:Connect(function()
		local offset = PusherMath.positionAt(os.clock() - startTime, config.pusherStroke, config.pusherSpeed)
		machine.pusher.CFrame = machine.origin * CFrame.new(0, pusherY, retractCenterZ + offset)
	end)
end

return PusherService
