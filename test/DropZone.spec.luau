local DropZone = require("../src/shared/rules/DropZone")

return function(t)
	t:test("DropZone: clamp keeps values inside the half width", function()
		t:eq(DropZone.clamp(3, 10), 3)
		t:eq(DropZone.clamp(100, 10), 10)
		t:eq(DropZone.clamp(-100, 10), -10)
	end)

	t:test("DropZone: sanitize clamps valid numbers", function()
		t:eq(DropZone.sanitize(3, 10), 3)
		t:eq(DropZone.sanitize(100, 10), 10)
		t:eq(DropZone.sanitize(-100, 10), -10)
	end)

	t:test("DropZone: sanitize rejects anything that is not a finite number", function()
		t:eq(DropZone.sanitize(nil, 10), nil)
		t:eq(DropZone.sanitize("5", 10), nil)
		t:eq(DropZone.sanitize(0 / 0, 10), nil)
		t:eq(DropZone.sanitize(math.huge, 10), nil)
		t:eq(DropZone.sanitize(-math.huge, 10), nil)
		t:eq(DropZone.sanitize({}, 10), nil)
	end)
end
