--!strict
-- Geometry of the raised viewing bridge, as plain numbers in world studs. Each box has a centre
-- (cx, cy, cz) and a size (sx, sy, sz). The server turns these into parts; keeping the maths here
-- lets it be tested without Roblox.
local BridgeLayout = {}

local RAIL_THICKNESS = 0.4
local PILLAR_SIZE = 1
local SPAWN_PAD_SIZE = 6
local SPAWN_PAD_THICKNESS = 0.2

export type Box = { name: string, cx: number, cy: number, cz: number, sx: number, sy: number, sz: number }
export type Ramp = Box & { angle: number }
export type Layout = {
	deck: Box,
	ramp: Ramp,
	spawn: Box,
	rails: { Box },
	pillars: { Box },
}

local function box(name: string, cx: number, cy: number, cz: number, sx: number, sy: number, sz: number): Box
	return { name = name, cx = cx, cy = cy, cz = cz, sx = sx, sy = sy, sz = sz }
end

function BridgeLayout.compute(bridge: any): Layout
	local backZ = bridge.frontZ + bridge.deckDepth
	local deckCentreZ = bridge.frontZ + bridge.deckDepth / 2
	local halfWidth = bridge.deckWidth / 2

	local deck = box(
		"Deck",
		bridge.centerX,
		bridge.deckHeight - bridge.deckThickness / 2,
		deckCentreZ,
		bridge.deckWidth,
		bridge.deckThickness,
		bridge.deckDepth
	)

	-- The ramp climbs from the ground at backZ + rampRun up to the deck top at backZ. Its top surface
	-- follows that line, so the centre sits half a thickness below the line's midpoint.
	local rise = bridge.deckHeight
	local angle = math.atan(rise / bridge.rampRun)
	local length = math.sqrt(rise * rise + bridge.rampRun * bridge.rampRun)
	local ramp: Ramp = {
		name = "Ramp",
		cx = bridge.centerX,
		cy = rise / 2 - math.cos(angle) * bridge.deckThickness / 2,
		cz = backZ + bridge.rampRun / 2 - math.sin(angle) * bridge.deckThickness / 2,
		sx = bridge.rampWidth,
		sy = bridge.deckThickness,
		sz = length,
		angle = angle,
	}

	local padSize = math.min(SPAWN_PAD_SIZE, bridge.deckDepth - 1, bridge.deckWidth - 1)
	local spawn = box(
		"Spawn",
		bridge.centerX,
		bridge.deckHeight + SPAWN_PAD_THICKNESS / 2,
		deckCentreZ,
		padSize,
		SPAWN_PAD_THICKNESS,
		padSize
	)

	local railY = bridge.deckHeight + bridge.railHeight / 2
	local rails = {
		box("FrontRail", bridge.centerX, railY, bridge.frontZ + RAIL_THICKNESS / 2, bridge.deckWidth, bridge.railHeight, RAIL_THICKNESS),
	}
	for _, side in { -1, 1 } do
		table.insert(
			rails,
			box("SideRail", bridge.centerX + side * (halfWidth - RAIL_THICKNESS / 2), railY, deckCentreZ, RAIL_THICKNESS, bridge.railHeight, bridge.deckDepth)
		)
	end
	-- The back edge is open where the ramp arrives and railed on either side of it.
	local backSegment = (bridge.deckWidth - bridge.rampWidth) / 2
	if backSegment > 1e-6 then
		for _, side in { -1, 1 } do
			table.insert(
				rails,
				box("BackRail", bridge.centerX + side * (bridge.rampWidth / 2 + backSegment / 2), railY, backZ - RAIL_THICKNESS / 2, backSegment, bridge.railHeight, RAIL_THICKNESS)
			)
		end
	end

	local pillarHeight = bridge.deckHeight - bridge.deckThickness
	local pillars = {}
	for _, side in { -1, 1 } do
		for _, z in { bridge.frontZ + PILLAR_SIZE / 2, backZ - PILLAR_SIZE / 2 } do
			table.insert(
				pillars,
				box("Pillar", bridge.centerX + side * (halfWidth - PILLAR_SIZE / 2), pillarHeight / 2, z, PILLAR_SIZE, pillarHeight, PILLAR_SIZE)
			)
		end
	end

	return { deck = deck, ramp = ramp, spawn = spawn, rails = rails, pillars = pillars }
end

return BridgeLayout
