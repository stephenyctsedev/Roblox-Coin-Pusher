local PusherMath = require("../src/shared/rules/PusherMath")

return function(t)
	t:test("PusherMath: starts retracted", function()
		t:near(PusherMath.positionAt(0, 6, 4), 0, 1e-9)
	end)

	t:test("PusherMath: moves forward at the given speed", function()
		t:near(PusherMath.positionAt(0.75, 6, 4), 3, 1e-9)
		t:near(PusherMath.positionAt(1.5, 6, 4), 6, 1e-9)
	end)

	t:test("PusherMath: comes back after the stroke", function()
		t:near(PusherMath.positionAt(2.25, 6, 4), 3, 1e-9)
		t:near(PusherMath.positionAt(3, 6, 4), 0, 1e-9)
	end)

	t:test("PusherMath: repeats every period", function()
		t:near(PusherMath.positionAt(4.5, 6, 4), 6, 1e-9)
		t:near(PusherMath.positionAt(300.75, 6, 4), 3, 1e-9)
	end)

	t:test("PusherMath: negative time still stays inside the stroke", function()
		t:near(PusherMath.positionAt(-0.75, 6, 4), 3, 1e-9)
	end)

	t:test("PusherMath: rejects a non-positive stroke or speed", function()
		t:throws(function()
			PusherMath.positionAt(1, 0, 4)
		end)
		t:throws(function()
			PusherMath.positionAt(1, 6, 0)
		end)
	end)
end
