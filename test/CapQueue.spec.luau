local CapQueue = require("../src/shared/rules/CapQueue")

return function(t)
	t:test("CapQueue: push below the cap evicts nothing", function()
		local list = {}
		t:eq(CapQueue.push(list, "a", 2), nil)
		t:eq(CapQueue.push(list, "b", 2), nil)
		t:eq(list, { "a", "b" })
	end)

	t:test("CapQueue: push past the cap evicts the oldest", function()
		local list = { "a", "b" }
		t:eq(CapQueue.push(list, "c", 2), "a")
		t:eq(list, { "b", "c" })
	end)

	t:test("CapQueue: remove takes an item out and reports it", function()
		local list = { "a", "b", "c" }
		t:eq(CapQueue.remove(list, "b"), true)
		t:eq(list, { "a", "c" })
	end)

	t:test("CapQueue: remove reports false for an unknown item", function()
		local list = { "a" }
		t:eq(CapQueue.remove(list, "z"), false)
		t:eq(list, { "a" })
	end)

	t:test("CapQueue: a removed item does not count toward the cap", function()
		local list = { "a", "b" }
		CapQueue.remove(list, "a")
		t:eq(CapQueue.push(list, "c", 2), nil)
		t:eq(list, { "b", "c" })
	end)
end
