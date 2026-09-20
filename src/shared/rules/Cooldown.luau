--!strict
local Cooldown = {}
Cooldown.__index = Cooldown

export type Cooldown = {
	seconds: number,
	last: { [any]: number },
	tryUse: (self: Cooldown, id: any, now: number) -> boolean,
	reset: (self: Cooldown, id: any) -> (),
}

function Cooldown.new(seconds: number): Cooldown
	assert(type(seconds) == "number" and seconds >= 0, "Cooldown.new: seconds must be a non-negative number")
	return setmetatable({ seconds = seconds, last = {} }, Cooldown) :: any
end

function Cooldown.tryUse(self: Cooldown, id: any, now: number): boolean
	local last = self.last[id]
	if last ~= nil and now - last < self.seconds then
		return false
	end
	self.last[id] = now
	return true
end

function Cooldown.reset(self: Cooldown, id: any)
	self.last[id] = nil
end

return Cooldown
