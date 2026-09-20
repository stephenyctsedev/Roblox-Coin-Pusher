--!strict
local ConfigValidation = {}

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function positive(value: number): boolean
	return value > 0
end

local function nonNegative(value: number): boolean
	return value >= 0
end

local function positiveInteger(value: number): boolean
	return value > 0 and value == math.floor(value)
end

local function nonNegativeInteger(value: number): boolean
	return value >= 0 and value == math.floor(value)
end

local function anyNumber(_: number): boolean
	return true
end

local function atLeastOne(value: number): boolean
	return value >= 1
end

local function check(
	errors: { string },
	tbl: any,
	path: string,
	field: string,
	predicate: (number) -> boolean,
	requirement: string
)
	local value = tbl[field]
	if not isFinite(value) or not predicate(value) then
		table.insert(errors, path .. field .. ": must be " .. requirement)
	end
end

function ConfigValidation.validate(config: any): (boolean, { string })
	if type(config) ~= "table" then
		return false, { "config: must be a table" }
	end

	local errors: { string } = {}
	check(errors, config, "", "startingCoins", nonNegativeInteger, "a non-negative integer")
	check(errors, config, "", "regenIntervalSeconds", positive, "a positive number")
	check(errors, config, "", "regenCap", positiveInteger, "a positive integer")
	check(errors, config, "", "dropCooldownSeconds", nonNegative, "a non-negative number")
	check(errors, config, "", "rewardBonusCoins", positiveInteger, "a positive integer")
	check(errors, config, "", "coinsOnMachineCap", positiveInteger, "a positive integer")
	check(errors, config, "", "pusherSpeed", positive, "a positive number")
	check(errors, config, "", "pusherStroke", positive, "a positive number")
	check(errors, config, "", "autosaveSeconds", positive, "a positive number")

	local machine = config.machine
	if type(machine) ~= "table" then
		table.insert(errors, "machine: must be a table")
	else
		check(errors, machine, "machine.", "originX", anyNumber, "a finite number")
		check(errors, machine, "machine.", "originZ", anyNumber, "a finite number")
		check(errors, machine, "machine.", "originY", positive, "a positive number")
		check(errors, machine, "machine.", "platformWidth", positive, "a positive number")
		check(errors, machine, "machine.", "platformDepth", positive, "a positive number")
		check(errors, machine, "machine.", "baseThickness", positive, "a positive number")
		check(errors, machine, "machine.", "wallHeight", positive, "a positive number")
		check(errors, machine, "machine.", "pusherDepth", positive, "a positive number")
		check(errors, machine, "machine.", "pusherHeight", positive, "a positive number")
		check(errors, machine, "machine.", "coinDiameter", positive, "a positive number")
		check(errors, machine, "machine.", "coinThickness", positive, "a positive number")
		check(errors, machine, "machine.", "dropHeight", positive, "a positive number")
		check(errors, machine, "machine.", "dropZ", anyNumber, "a finite number")
		check(errors, machine, "machine.", "rewardZoneDepth", positive, "a positive number")
		check(errors, machine, "machine.", "seedStartZ", anyNumber, "a finite number")
		check(errors, machine, "machine.", "seedEndMargin", nonNegative, "a non-negative number")
		check(errors, machine, "machine.", "seedGapFactor", atLeastOne, "a number of at least 1")

		-- Cross-field rules only run when every field is individually valid.
		if #errors == 0 then
			if machine.originY <= machine.baseThickness / 2 then
				table.insert(errors, "machine.originY: must be above half the base thickness so the stand has height")
			end
			if machine.pusherDepth + config.pusherStroke > machine.platformDepth then
				table.insert(errors, "machine.pusherDepth + pusherStroke: must not exceed machine.platformDepth")
			end
			if math.abs(machine.dropZ) >= machine.platformDepth / 2 then
				table.insert(errors, "machine.dropZ: must sit inside the platform depth")
			end
			if machine.seedStartZ - machine.coinDiameter / 2 < -machine.platformDepth / 2 + machine.pusherDepth then
				table.insert(errors, "machine.seedStartZ: must sit in front of the retracted pusher")
			end
			if machine.seedStartZ >= machine.platformDepth / 2 - machine.seedEndMargin then
				table.insert(errors, "machine.seedStartZ: must be behind the seed end (platformDepth / 2 - seedEndMargin)")
			end
		end
	end

	if #errors > 0 then
		return false, errors
	end
	return true, {}
end

return ConfigValidation
