local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BridgeLayout = require(ReplicatedStorage.Shared.rules.BridgeLayout)

local BridgeBuilder = {}

local function newPart(box: BridgeLayout.Box, className: string, color: Color3, parent: Instance): Part
	local part = Instance.new(className) :: Part
	part.Name = box.name
	part.Anchored = true
	part.Size = Vector3.new(box.sx, box.sy, box.sz)
	part.CFrame = CFrame.new(box.cx, box.cy, box.cz)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function BridgeBuilder.build(config)
	local bridge = config.bridge

	local existing = Workspace:FindFirstChild("Bridge")
	if existing then
		existing:Destroy()
	end
	-- The Baseplate template ships its own SpawnLocation on the ground; players must spawn on the bridge.
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local layout = BridgeLayout.compute(bridge)
	local folder = Instance.new("Folder")
	folder.Name = "Bridge"

	-- Glass, so the deck edge does not hide the front of the pile from a camera looking down over it.
	local deck = newPart(layout.deck, "Part", Color3.fromRGB(150, 200, 255), folder)
	deck.Material = Enum.Material.Glass
	deck.Transparency = bridge.deckTransparency

	local ramp = newPart(layout.ramp, "Part", Color3.fromRGB(70, 70, 85), folder)
	ramp.CFrame = CFrame.new(layout.ramp.cx, layout.ramp.cy, layout.ramp.cz) * CFrame.Angles(layout.ramp.angle, 0, 0)

	for _, rail in layout.rails do
		local part = newPart(rail, "Part", Color3.fromRGB(200, 60, 60), folder)
		part.Transparency = 0.3
	end
	for _, pillar in layout.pillars do
		newPart(pillar, "Part", Color3.fromRGB(40, 40, 50), folder)
	end

	-- A default SpawnLocation faces -Z, which is toward the machine.
	local spawn = newPart(layout.spawn, "SpawnLocation", Color3.fromRGB(60, 220, 120), folder) :: SpawnLocation
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.3

	folder.Parent = Workspace
	return { folder = folder, spawn = spawn }
end

return BridgeBuilder
