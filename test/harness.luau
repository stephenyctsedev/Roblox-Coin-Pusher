local Harness = {}
Harness.__index = Harness

function Harness.new()
	return setmetatable({ passed = 0, failed = 0, failures = {} }, Harness)
end

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function show(value)
	if type(value) == "table" then
		local parts = {}
		for key, item in value do
			table.insert(parts, tostring(key) .. "=" .. show(item))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

function Harness.test(self, name, fn)
	local ok, err = pcall(fn)
	if ok then
		self.passed += 1
	else
		self.failed += 1
		table.insert(self.failures, name .. "\n    " .. tostring(err))
	end
end

function Harness.eq(_self, actual, expected, message)
	if not deepEqual(actual, expected) then
		local prefix = message and (message .. ": ") or ""
		error(string.format("%sexpected %s, got %s", prefix, show(expected), show(actual)), 2)
	end
end

function Harness.near(_self, actual, expected, epsilon)
	if type(actual) ~= "number" or math.abs(actual - expected) > epsilon then
		error(string.format("expected %s within %s, got %s", tostring(expected), tostring(epsilon), tostring(actual)), 2)
	end
end

function Harness.throws(_self, fn)
	local ok = pcall(fn)
	if ok then
		error("expected an error, but none was thrown", 2)
	end
end

return Harness
