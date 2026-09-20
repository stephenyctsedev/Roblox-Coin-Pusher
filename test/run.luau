local process = require("@lune/process")
local Harness = require("./harness")

local specs = {
	{ name = "harness", run = require("./harness.spec") },
	{ name = "Cooldown", run = require("./Cooldown.spec") },
	{ name = "Payout", run = require("./Payout.spec") },
	{ name = "Regen", run = require("./Regen.spec") },
	{ name = "SaveData", run = require("./SaveData.spec") },
	{ name = "ConfigValidation", run = require("./ConfigValidation.spec") },
	{ name = "DropZone", run = require("./DropZone.spec") },
	{ name = "PusherMath", run = require("./PusherMath.spec") },
	{ name = "CapQueue", run = require("./CapQueue.spec") },
}

local t = Harness.new()
for _, spec in specs do
	spec.run(t)
end

print(string.format("%d passed, %d failed", t.passed, t.failed))
for _, failure in t.failures do
	print("FAIL " .. failure)
end
if t.failed > 0 then
	process.exit(1)
end
