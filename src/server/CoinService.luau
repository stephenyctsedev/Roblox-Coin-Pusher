local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CapQueue = require(ReplicatedStorage.Shared.rules.CapQueue)

local CoinService = {}

local machine
local config
local coins = {}

function CoinService.init(machineRef, configRef)
	machine = machineRef
	config = configRef
end

function CoinService.spawn(ownerUserId: number, localX: number): Part
	local m = config.machine
	local baseTop = m.baseThickness / 2

	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(m.coinThickness, m.coinDiameter, m.coinDiameter)
	coin.Material = Enum.Material.Metal
	coin.Color = Color3.fromRGB(240, 190, 40)
	coin.TopSurface = Enum.SurfaceType.Smooth
	coin.BottomSurface = Enum.SurfaceType.Smooth
	-- density, friction, elasticity, frictionWeight, elasticityWeight
	coin.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.1, 1, 1)
	-- A cylinder's axis is X; rotating 90 degrees about Z lays the coin flat.
	coin.CFrame = machine.origin
		* CFrame.new(localX, baseTop + m.dropHeight, m.dropZ)
		* CFrame.Angles(0, 0, math.rad(90))
	coin:SetAttribute("OwnerUserId", ownerUserId)
	CollectionService:AddTag(coin, "Coin")
	coin.Parent = machine.folder
	-- Keep coin physics on the server so pushing is consistent for everyone.
	coin:SetNetworkOwner(nil)

	local evicted = CapQueue.push(coins, coin, config.coinsOnMachineCap)
	if evicted then
		evicted:Destroy()
	end
	return coin
end

function CoinService.remove(coin: Instance)
	CapQueue.remove(coins, coin)
	coin:Destroy()
end

return CoinService
