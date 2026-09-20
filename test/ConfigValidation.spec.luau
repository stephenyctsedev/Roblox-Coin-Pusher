local ConfigValidation = require("../src/shared/rules/ConfigValidation")
local Config = require("../src/shared/Config")

local function validConfig()
	return {
		startingCoins = 20,
		regenIntervalSeconds = 5,
		regenCap = 20,
		dropCooldownSeconds = 0.5,
		rewardBonusCoins = 3,
		coinsOnMachineCap = 150,
		pusherSpeed = 4,
		pusherStroke = 6,
		autosaveSeconds = 60,
		machine = {
			originX = 0,
			originY = 3,
			originZ = -28,
			platformWidth = 20,
			platformDepth = 24,
			baseThickness = 1,
			wallHeight = 4,
			pusherDepth = 6,
			pusherHeight = 1,
			coinDiameter = 2,
			coinThickness = 0.4,
			dropHeight = 8,
			dropZ = -4.5,
			rewardZoneDepth = 6,
		},
	}
end

local function hasError(errors, fragment)
	for _, message in errors do
		if string.find(message, fragment, 1, true) then
			return true
		end
	end
	return false
end

return function(t)
	t:test("ConfigValidation: a good config passes", function()
		local ok, errors = ConfigValidation.validate(validConfig())
		t:eq(ok, true)
		t:eq(errors, {})
	end)

	t:test("ConfigValidation: the shipped Config passes", function()
		local ok, errors = ConfigValidation.validate(Config)
		t:eq(ok, true, table.concat(errors, "; "))
	end)

	t:test("ConfigValidation: a non-table is rejected", function()
		local ok = ConfigValidation.validate(nil)
		t:eq(ok, false)
	end)

	t:test("ConfigValidation: bad top-level numbers are named in the errors", function()
		local config = validConfig()
		config.startingCoins = -1
		config.regenIntervalSeconds = 0
		config.regenCap = 1.5
		config.dropCooldownSeconds = -0.1
		config.rewardBonusCoins = 0
		config.coinsOnMachineCap = 0
		config.pusherSpeed = 0
		config.pusherStroke = -2
		config.autosaveSeconds = 0
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		for _, field in {
			"startingCoins",
			"regenIntervalSeconds",
			"regenCap",
			"dropCooldownSeconds",
			"rewardBonusCoins",
			"coinsOnMachineCap",
			"pusherSpeed",
			"pusherStroke",
			"autosaveSeconds",
		} do
			t:eq(hasError(errors, field), true, field)
		end
	end)

	t:test("ConfigValidation: NaN and non-numbers are rejected", function()
		local config = validConfig()
		config.pusherSpeed = 0 / 0
		config.pusherStroke = "6"
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "pusherSpeed"), true)
		t:eq(hasError(errors, "pusherStroke"), true)
	end)

	t:test("ConfigValidation: a missing machine table is rejected", function()
		local config = validConfig()
		config.machine = nil
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine"), true)
	end)

	t:test("ConfigValidation: bad machine numbers are named in the errors", function()
		local config = validConfig()
		config.machine.platformWidth = 0
		config.machine.coinDiameter = -1
		config.machine.originX = "0"
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.platformWidth"), true)
		t:eq(hasError(errors, "machine.coinDiameter"), true)
		t:eq(hasError(errors, "machine.originX"), true)
	end)

	t:test("ConfigValidation: the pusher must fit inside the platform", function()
		local config = validConfig()
		config.pusherStroke = 20
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "pusherDepth + pusherStroke"), true)
	end)

	t:test("ConfigValidation: the drop point must sit on the platform", function()
		local config = validConfig()
		config.machine.dropZ = 30
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.dropZ"), true)
	end)

	t:test("ConfigValidation: the base must sit above the ground", function()
		local config = validConfig()
		config.machine.originY = 0.4
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.originY"), true)
	end)
end
