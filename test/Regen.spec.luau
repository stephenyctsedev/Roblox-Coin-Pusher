local Regen = require("../src/shared/rules/Regen")

local config = { regenIntervalSeconds = 5, regenCap = 20 }

return function(t)
	t:test("Regen: less than one interval adds nothing and keeps the leftover", function()
		local balance, leftover = Regen.apply(5, 4, config)
		t:eq(balance, 5)
		t:eq(leftover, 4)
	end)

	t:test("Regen: one full interval adds one coin", function()
		local balance, leftover = Regen.apply(5, 5, config)
		t:eq(balance, 6)
		t:eq(leftover, 0)
	end)

	t:test("Regen: several intervals add several coins and keep the remainder", function()
		local balance, leftover = Regen.apply(5, 12, config)
		t:eq(balance, 7)
		t:eq(leftover, 2)
	end)

	t:test("Regen: stops at the cap and drops the leftover", function()
		local balance, leftover = Regen.apply(19, 20, config)
		t:eq(balance, 20)
		t:eq(leftover, 0)
		local exactBalance, exactLeftover = Regen.apply(18, 10, config)
		t:eq(exactBalance, 20)
		t:eq(exactLeftover, 0)
	end)

	t:test("Regen: a balance at the cap stays put", function()
		local balance, leftover = Regen.apply(20, 3, config)
		t:eq(balance, 20)
		t:eq(leftover, 0)
	end)

	t:test("Regen: a balance above the cap is never reduced", function()
		local balance, leftover = Regen.apply(30, 10, config)
		t:eq(balance, 30)
		t:eq(leftover, 0)
	end)

	t:test("Regen: negative elapsed time is treated as zero", function()
		local balance, leftover = Regen.apply(5, -3, config)
		t:eq(balance, 5)
		t:eq(leftover, 0)
	end)
end
