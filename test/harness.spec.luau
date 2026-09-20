local Harness = require("./harness")

return function(t)
	t:test("harness: eq passes on equal nested tables", function()
		t:eq({ a = 1, b = { 2, 3 } }, { a = 1, b = { 2, 3 } })
	end)

	t:test("harness: eq throws on different tables", function()
		t:throws(function()
			t:eq({ a = 1 }, { a = 2 })
		end)
	end)

	t:test("harness: near accepts values inside epsilon and rejects outside", function()
		t:near(1.0000001, 1, 0.001)
		t:throws(function()
			t:near(1.1, 1, 0.001)
		end)
	end)

	t:test("harness: a failing test is recorded and is not fatal", function()
		local inner = Harness.new()
		inner:test("boom", function()
			error("boom")
		end)
		t:eq(inner.failed, 1)
		t:eq(inner.passed, 0)
	end)
end
