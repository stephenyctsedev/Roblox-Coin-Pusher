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

-- Z of the slab centre when fully retracted, relative to the base centre. The slab is placed
-- so that its rear edge is exactly at the back wall when fully extended, so the base behind
-- it is never exposed. Front edge when retracted = this + pusherDepth / 2.
function PusherMath.retractedCenterZ(platformDepth: number, pusherDepth: number, stroke: number): number
	return -platformDepth / 2 - stroke + pusherDepth / 2
end

return PusherMath
