local BridgeLayout = require("../src/shared/rules/BridgeLayout")
local Config = require("../src/shared/Config")

local bridge = {
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
}

return function(t)
	t:test("BridgeLayout: the deck top sits at deckHeight and spans frontZ to frontZ + depth", function()
		local layout = BridgeLayout.compute(bridge)
		t:near(layout.deck.cy + layout.deck.sy / 2, 10, 1e-9)
		t:near(layout.deck.cz - layout.deck.sz / 2, -8, 1e-9)
		t:near(layout.deck.cz + layout.deck.sz / 2, 0, 1e-9)
		t:near(layout.deck.cx, 0, 1e-9)
		t:near(layout.deck.sx, 20, 1e-9)
	end)

	t:test("BridgeLayout: the spawn pad is centred on the deck, resting on top", function()
		local layout = BridgeLayout.compute(bridge)
		t:near(layout.spawn.cx, 0, 1e-9)
		t:near(layout.spawn.cz, -4, 1e-9)
		t:near(layout.spawn.cy - layout.spawn.sy / 2, 10, 1e-9)
	end)

	t:test("BridgeLayout: the ramp top meets the deck top at the back edge and the ground at its run", function()
		local layout = BridgeLayout.compute(bridge)
		local ramp = layout.ramp
		-- Walk along the ramp's top surface from centre outwards; the ends are the ramp's two edges.
		local up = { y = math.cos(ramp.angle), z = math.sin(ramp.angle) }
		local along = { y = -math.sin(ramp.angle), z = math.cos(ramp.angle) }
		local topCentreY = ramp.cy + up.y * ramp.sy / 2
		local topCentreZ = ramp.cz + up.z * ramp.sy / 2
		local highY = topCentreY - along.y * ramp.sz / 2
		local highZ = topCentreZ - along.z * ramp.sz / 2
		local lowY = topCentreY + along.y * ramp.sz / 2
		local lowZ = topCentreZ + along.z * ramp.sz / 2
		t:near(highY, 10, 1e-9)
		t:near(highZ, 0, 1e-9)
		t:near(lowY, 0, 1e-9)
		t:near(lowZ, 18, 1e-9)
	end)

	t:test("BridgeLayout: the ramp is as wide as configured and centred", function()
		local layout = BridgeLayout.compute(bridge)
		t:near(layout.ramp.sx, 8, 1e-9)
		t:near(layout.ramp.cx, 0, 1e-9)
	end)

	t:test("BridgeLayout: the front rail runs the deck width along the machine-side edge", function()
		local layout = BridgeLayout.compute(bridge)
		local front
		for _, rail in layout.rails do
			if rail.name == "FrontRail" then
				front = rail
			end
		end
		t:eq(front ~= nil, true)
		t:near(front.sx, 20, 1e-9)
		t:near(front.cy - front.sy / 2, 10, 1e-9)
		t:near(front.cz, -8 + front.sz / 2, 1e-9)
	end)

	t:test("BridgeLayout: the back edge keeps an opening exactly as wide as the ramp", function()
		local layout = BridgeLayout.compute(bridge)
		local backSegments = {}
		for _, rail in layout.rails do
			if rail.name == "BackRail" then
				table.insert(backSegments, rail)
			end
		end
		t:eq(#backSegments, 2)
		local gapLeft = math.max(backSegments[1].cx, backSegments[2].cx) - math.max(backSegments[1].sx, backSegments[2].sx) / 2
		local gapRight = math.min(backSegments[1].cx, backSegments[2].cx) + math.min(backSegments[1].sx, backSegments[2].sx) / 2
		t:near(gapLeft - gapRight, 8, 1e-9)
	end)

	t:test("BridgeLayout: no back rail segments when the ramp is as wide as the deck", function()
		local wide = table.clone(bridge)
		wide.rampWidth = 20
		local layout = BridgeLayout.compute(wide)
		for _, rail in layout.rails do
			t:eq(rail.name ~= "BackRail", true)
		end
	end)

	t:test("BridgeLayout: four pillars reach from the ground to the deck underside", function()
		local layout = BridgeLayout.compute(bridge)
		t:eq(#layout.pillars, 4)
		for _, pillar in layout.pillars do
			t:near(pillar.cy - pillar.sy / 2, 0, 1e-9)
			t:near(pillar.cy + pillar.sy / 2, 9, 1e-9)
		end
	end)

	t:test("BridgeLayout: everything stays behind the reward zone for the shipped Config", function()
		local layout = BridgeLayout.compute(Config.bridge)
		local rewardEnd = Config.machine.originZ + Config.machine.platformDepth / 2 + Config.machine.rewardZoneDepth
		t:eq(layout.deck.cz - layout.deck.sz / 2 >= rewardEnd, true)
		for _, pillar in layout.pillars do
			t:eq(pillar.cz - pillar.sz / 2 >= rewardEnd, true)
		end
	end)
end
