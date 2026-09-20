local CoinLayout = require("../src/shared/rules/CoinLayout")
local Config = require("../src/shared/Config")

local function machine()
	return {
		platformWidth = 20,
		platformDepth = 24,
		coinDiameter = 2,
		seedStartZ = 0.5,
		seedEndMargin = 1.5,
		seedGapFactor = 1.02,
	}
end

local function distinctRows(points)
	local seen, rows = {}, {}
	for _, p in points do
		local key = string.format("%.6f", p.z)
		if not seen[key] then
			seen[key] = true
			table.insert(rows, p.z)
		end
	end
	table.sort(rows)
	return rows
end

local function rowXs(points, z)
	local xs = {}
	for _, p in points do
		if math.abs(p.z - z) < 1e-6 then
			table.insert(xs, p.x)
		end
	end
	table.sort(xs)
	return xs
end

return function(t)
	t:test("CoinLayout: the default machine gets 6 rows and 51 coins", function()
		local points = CoinLayout.staggeredGrid(machine())
		t:eq(#points, 51)
		t:eq(#distinctRows(points), 6)
	end)

	t:test("CoinLayout: the shipped Config produces the same layout", function()
		t:eq(#CoinLayout.staggeredGrid(Config.machine), 51)
	end)

	t:test("CoinLayout: every coin sits inside the walls and inside the seed band", function()
		local m = machine()
		local halfWidth = m.platformWidth / 2 - m.coinDiameter / 2
		local endZ = m.platformDepth / 2 - m.seedEndMargin
		for _, p in CoinLayout.staggeredGrid(m) do
			t:eq(math.abs(p.x) <= halfWidth + 1e-9, true, "x " .. p.x)
			t:eq(p.z >= m.seedStartZ - 1e-9 and p.z <= endZ + 1e-9, true, "z " .. p.z)
		end
	end)

	t:test("CoinLayout: no two coins overlap", function()
		local m = machine()
		local points = CoinLayout.staggeredGrid(m)
		for i = 1, #points do
			for j = i + 1, #points do
				local dx = points[i].x - points[j].x
				local dz = points[i].z - points[j].z
				t:eq(math.sqrt(dx * dx + dz * dz) >= m.coinDiameter - 1e-9, true, i .. " vs " .. j)
			end
		end
	end)

	t:test("CoinLayout: rows are centred and every other row is offset by half a spacing", function()
		local points = CoinLayout.staggeredGrid(machine())
		local rows = distinctRows(points)
		local first = rowXs(points, rows[1])
		local second = rowXs(points, rows[2])
		t:eq(#first, 9)
		t:eq(#second, 8)
		t:near(first[1], -first[#first], 1e-9)
		t:near(second[1], (first[1] + first[2]) / 2, 1e-9)
	end)

	t:test("CoinLayout: the layout is deterministic", function()
		t:eq(CoinLayout.staggeredGrid(machine()), CoinLayout.staggeredGrid(machine()))
	end)

	t:test("CoinLayout: an empty band or a platform narrower than a coin gives no crash", function()
		local m = machine()
		m.seedStartZ = 11
		t:eq(#CoinLayout.staggeredGrid(m), 0)
		local narrow = machine()
		narrow.platformWidth = 1
		t:eq(#CoinLayout.staggeredGrid(narrow), 0)
	end)
end
