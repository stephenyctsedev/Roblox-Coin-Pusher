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

	t:test("PusherMath: retractedCenterZ puts the default slab flush behind the wall", function()
		t:near(PusherMath.retractedCenterZ(24, 12, 6), -12, 1e-9)
	end)

	t:test("PusherMath: the extended rear edge is always flush with the back wall", function()
		for _, case in { { 24, 12, 6 }, { 24, 6, 6 }, { 30, 10, 4 }, { 20, 20, 2 } } do
			local platformDepth, pusherDepth, stroke = case[1], case[2], case[3]
			local center = PusherMath.retractedCenterZ(platformDepth, pusherDepth, stroke)
			local extendedRear = center + stroke - pusherDepth / 2
			t:near(extendedRear, -platformDepth / 2, 1e-9)
		end
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
