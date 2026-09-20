local Workspace = game:GetService("Workspace")

local MachineBuilder = {}

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function MachineBuilder.build(config)
	local m = config.machine

	local existing = Workspace:FindFirstChild("CoinMachine")
	if existing then
		existing:Destroy()
	end

	local origin = CFrame.new(m.originX, m.originY, m.originZ)
	local halfWidth = m.platformWidth / 2
	local halfDepth = m.platformDepth / 2
	local baseTop = m.baseThickness / 2
	local wallY = baseTop + m.wallHeight / 2
	local standHeight = m.originY - m.baseThickness / 2

	local folder = Instance.new("Folder")
	folder.Name = "CoinMachine"

	newPart("Base", Vector3.new(m.platformWidth, m.baseThickness, m.platformDepth), origin, Color3.fromRGB(70, 70, 85), folder)
	newPart(
		"Stand",
		Vector3.new(m.platformWidth, standHeight, m.platformDepth),
		origin * CFrame.new(0, -(m.baseThickness / 2 + standHeight / 2), 0),
		Color3.fromRGB(40, 40, 50),
		folder
	)

	for _, side in { -1, 1 } do
		newPart(
			"SideWall",
			Vector3.new(1, m.wallHeight, m.platformDepth),
			origin * CFrame.new(side * (halfWidth + 0.5), wallY, 0),
			Color3.fromRGB(200, 60, 60),
			folder
		)
	end
	newPart(
		"BackWall",
		Vector3.new(m.platformWidth + 2, m.wallHeight, 1),
		origin * CFrame.new(0, wallY, -(halfDepth + 0.5)),
		Color3.fromRGB(200, 60, 60),
		folder
	)

	local retractCenterZ = -halfDepth + m.pusherDepth / 2
	local pusherY = baseTop + m.pusherHeight / 2
	local pusher = newPart(
		"Pusher",
		Vector3.new(m.platformWidth - 0.4, m.pusherHeight, m.pusherDepth),
		origin * CFrame.new(0, pusherY, retractCenterZ),
		Color3.fromRGB(240, 240, 240),
		folder
	)

	local rewardZone = newPart(
		"RewardZone",
		Vector3.new(m.platformWidth, 4, m.rewardZoneDepth),
		origin * CFrame.new(0, baseTop - 3, halfDepth + m.rewardZoneDepth / 2 - 0.5),
		Color3.fromRGB(60, 220, 120),
		folder
	)
	rewardZone.Transparency = 0.6
	rewardZone.CanCollide = false
	rewardZone.CanTouch = true

	local dropPlane = newPart(
		"DropPlane",
		Vector3.new(m.platformWidth, 0.2, m.platformDepth),
		origin * CFrame.new(0, baseTop + m.dropHeight, 0),
		Color3.fromRGB(120, 180, 255),
		folder
	)
	dropPlane.Transparency = 0.85
	dropPlane.CanCollide = false
	dropPlane.CanTouch = false
	dropPlane.CanQuery = true

	folder.Parent = Workspace

	return {
		folder = folder,
		origin = origin,
		pusher = pusher,
		rewardZone = rewardZone,
		dropPlane = dropPlane,
	}
end

return MachineBuilder
