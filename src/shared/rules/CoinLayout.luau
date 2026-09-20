--!strict
local CoinLayout = {}

export type Point = { x: number, z: number }

export type Machine = {
	platformWidth: number,
	platformDepth: number,
	coinDiameter: number,
	seedStartZ: number,
	seedEndMargin: number,
	seedGapFactor: number,
}

-- Honeycomb packing: coins in a row are `spacing` apart, every other row is shifted by half
-- a spacing, and rows are `spacing * sqrt(3) / 2` apart, so neighbours are exactly `spacing`
-- apart. `spacing` is the coin diameter times the gap factor, so coins never start overlapping.
-- Coordinates are relative to the centre of the base (x across, z toward the front edge).
function CoinLayout.staggeredGrid(machine: Machine): { Point }
	local spacing = machine.coinDiameter * machine.seedGapFactor
	local halfWidth = machine.platformWidth / 2 - machine.coinDiameter / 2
	local rowSpacing = spacing * math.sqrt(3) / 2
	local endZ = machine.platformDepth / 2 - machine.seedEndMargin

	local points: { Point } = {}
	if halfWidth < 0 or endZ < machine.seedStartZ then
		return points
	end

	local fullRowCount = math.floor(2 * halfWidth / spacing) + 1
	local firstX = -(fullRowCount - 1) * spacing / 2

	local row = 0
	while true do
		local z = machine.seedStartZ + row * rowSpacing
		if z > endZ + 1e-9 then
			break
		end
		if row % 2 == 0 then
			for i = 0, fullRowCount - 1 do
				table.insert(points, { x = firstX + i * spacing, z = z })
			end
		else
			for i = 0, fullRowCount - 2 do
				table.insert(points, { x = firstX + spacing / 2 + i * spacing, z = z })
			end
		end
		row += 1
	end

	return points
end

return CoinLayout
