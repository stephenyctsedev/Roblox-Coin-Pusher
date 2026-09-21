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
			pusherDepth = 12,
			pusherHeight = 1,
			coinDiameter = 2,
			coinThickness = 0.4,
			dropHeight = 8,
			dropZ = -4.5,
			rewardZoneDepth = 6,
			seedStartZ = 0.5,
			seedEndMargin = 1.5,
			seedGapFactor = 1.02,
		},
		bridge = {
			centerX = 0,
			frontZ = -8,
			deckWidth = 20,
			deckDepth = 8,
			deckHeight = 10,
			deckThickness = 1,
			deckTransparency = 0.5,
			rampWidth = 8,
			rampRun = 18,
			railHeight = 3,
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

	t:test("ConfigValidation: the pusher must be shallower than the platform", function()
		local config = validConfig()
		config.machine.pusherDepth = 30
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.pusherDepth"), true)
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

	t:test("ConfigValidation: the seed gap factor must be at least 1", function()
		local config = validConfig()
		config.machine.seedGapFactor = 0.9
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.seedGapFactor"), true)
	end)

	t:test("ConfigValidation: seeded coins must start in front of the retracted pusher", function()
		local config = validConfig()
		config.machine.seedStartZ = -8
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.seedStartZ"), true)
	end)

	t:test("ConfigValidation: the seed band must not be empty", function()
		local config = validConfig()
		config.machine.seedStartZ = 11
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.seedStartZ"), true)
	end)

	t:test("ConfigValidation: a missing bridge table is rejected", function()
		local config = validConfig()
		config.bridge = nil
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "bridge"), true)
	end)

	t:test("ConfigValidation: bad bridge numbers are named in the errors", function()
		local config = validConfig()
		config.bridge.deckWidth = 0
		config.bridge.rampRun = -1
		config.bridge.deckTransparency = 1.5
		config.bridge.frontZ = "-8"
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "bridge.deckWidth"), true)
		t:eq(hasError(errors, "bridge.rampRun"), true)
		t:eq(hasError(errors, "bridge.deckTransparency"), true)
		t:eq(hasError(errors, "bridge.frontZ"), true)
	end)

	t:test("ConfigValidation: the deck must be higher than the machine walls", function()
		local config = validConfig()
		config.bridge.deckHeight = 7 -- wall top is 3 + 0.5 + 4 = 7.5
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "bridge.deckHeight"), true)
	end)

	t:test("ConfigValidation: the deck must be thinner than its height", function()
		local config = validConfig()
		config.bridge.deckThickness = 10
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "bridge.deckThickness"), true)
	end)

	t:test("ConfigValidation: the bridge must stay in front of the reward zone", function()
		local config = validConfig()
		config.bridge.frontZ = -12 -- reward zone ends at -28 + 12 + 6 = -10
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "bridge.frontZ"), true)
	end)

	t:test("ConfigValidation: the ramp cannot be wider than the deck", function()
		local config = validConfig()
		config.bridge.rampWidth = 25
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "bridge.rampWidth"), true)
	end)
end
