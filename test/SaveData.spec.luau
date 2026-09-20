local SaveData = require("../src/shared/rules/SaveData")

return function(t)
	t:test("SaveData: new starts at version 1 with the starting coins and zero score", function()
		t:eq(SaveData.new(20), { version = 1, coins = 20, score = 0 })
	end)

	t:test("SaveData: validate accepts a good record", function()
		local data, err = SaveData.validate({ version = 1, coins = 7, score = 12 })
		t:eq(data, { version = 1, coins = 7, score = 12 })
		t:eq(err, nil)
	end)

	t:test("SaveData: validate returns a copy, not the input table", function()
		local raw = { version = 1, coins = 7, score = 12 }
		local data = SaveData.validate(raw)
		data.coins = 99
		t:eq(raw.coins, 7)
	end)

	t:test("SaveData: validate rejects non-tables", function()
		t:eq((SaveData.validate(nil)), nil)
		t:eq((SaveData.validate("x")), nil)
		t:eq((SaveData.validate(5)), nil)
	end)

	t:test("SaveData: validate rejects a missing or future version", function()
		local _, missing = SaveData.validate({ coins = 1, score = 1 })
		t:eq(missing, "missing version")
		local _, future = SaveData.validate({ version = 2, coins = 1, score = 1 })
		t:eq(future, "unsupported future version 2")
		local _, zero = SaveData.validate({ version = 0, coins = 1, score = 1 })
		t:eq(zero, "invalid version")
	end)

	t:test("SaveData: validate rejects bad coins and score", function()
		t:eq((SaveData.validate({ version = 1, coins = -1, score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = 1.5, score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = 0 / 0, score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = math.huge, score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = "5", score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = 1, score = -3 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = 1 })), nil)
	end)

	t:test("SaveData: resolve treats a missing record as a new player", function()
		t:eq(SaveData.resolve(nil, 20), { data = { version = 1, coins = 20, score = 0 }, status = "new" })
	end)

	t:test("SaveData: resolve loads a valid record", function()
		local resolved = SaveData.resolve({ version = 1, coins = 4, score = 9 }, 20)
		t:eq(resolved, { data = { version = 1, coins = 4, score = 9 }, status = "loaded" })
	end)

	t:test("SaveData: resolve flags a corrupt record and returns safe defaults", function()
		local resolved = SaveData.resolve({ version = 1, coins = -5, score = 0 }, 20)
		t:eq(resolved, { data = { version = 1, coins = 20, score = 0 }, status = "invalid" })
	end)
end
