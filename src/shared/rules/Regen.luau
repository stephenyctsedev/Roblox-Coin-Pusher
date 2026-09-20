--!strict
local Regen = {}

function Regen.apply(
	balance: number,
	elapsedSeconds: number,
	config: { regenIntervalSeconds: number, regenCap: number }
): (number, number)
	if balance >= config.regenCap then
		return balance, 0
	end
	local elapsed = math.max(elapsedSeconds, 0)
	local ticks = math.floor(elapsed / config.regenIntervalSeconds)
	local room = config.regenCap - balance
	if ticks >= room then
		return config.regenCap, 0
	end
	return balance + ticks, elapsed - ticks * config.regenIntervalSeconds
end

return Regen
