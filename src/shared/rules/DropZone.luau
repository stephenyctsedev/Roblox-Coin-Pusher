--!strict
local DropZone = {}

function DropZone.clamp(x: number, halfWidth: number): number
	return math.max(-halfWidth, math.min(halfWidth, x))
end

function DropZone.sanitize(x: any, halfWidth: number): number?
	if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then
		return nil
	end
	return DropZone.clamp(x, halfWidth)
end

return DropZone
