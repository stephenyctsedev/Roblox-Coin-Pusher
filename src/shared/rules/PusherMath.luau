--!strict
local PusherMath = {}

function PusherMath.positionAt(t: number, stroke: number, speed: number): number
	assert(stroke > 0 and speed > 0, "PusherMath.positionAt: stroke and speed must be positive")
	local period = 2 * stroke / speed
	local distance = (t % period) * speed
	if distance <= stroke then
		return distance
	end
	return 2 * stroke - distance
end

return PusherMath
