local HttpService = game:GetService("HttpService")

local Telemetry = {}

function Telemetry.log(event: string, fields: { [string]: any }?)
	local payload: { [string]: any } = { event = event, t = os.time() }
	if fields then
		for key, value in fields do
			payload[key] = value
		end
	end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
	if ok then
		print("[telemetry] " .. encoded)
	else
		print("[telemetry] " .. event .. " (could not encode fields)")
	end
end

return Telemetry
