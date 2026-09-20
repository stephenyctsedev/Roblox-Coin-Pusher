local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CapQueue = require(ReplicatedStorage.Shared.rules.CapQueue)
local CoinLayout = require(ReplicatedStorage.Shared.rules.CoinLayout)

local CoinService = {}

local machine
local config
local coins = {}
local lastDropperUserId: number? = nil

local function createCoin(cframe: CFrame, ownerUserId: number?): Part
	local m = config.machine

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
	coin.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	if ownerUserId ~= nil then
		coin:SetAttribute("OwnerUserId", ownerUserId)
	else
		coin:SetAttribute("Seeded", true)
	end
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

function CoinService.init(machineRef, configRef)
	machine = machineRef
	config = configRef
end

function CoinService.spawn(ownerUserId: number, localX: number): Part
	local m = config.machine
	lastDropperUserId = ownerUserId
	return createCoin(machine.origin * CFrame.new(localX, m.baseThickness / 2 + m.dropHeight, m.dropZ), ownerUserId)
end

-- Fills the shelf with resting coins in a honeycomb pattern. Returns how many were placed.
-- Seeded coins have no owner: a reward for one goes to the most recent dropper (see lastDropper).
function CoinService.seed(): number
	local m = config.machine
	local restingY = m.baseThickness / 2 + m.coinThickness / 2
	local points = CoinLayout.staggeredGrid(m)
	for _, point in points do
		createCoin(machine.origin * CFrame.new(point.x, restingY, point.z), nil)
	end
	return #points
end

function CoinService.lastDropper(): number?
	return lastDropperUserId
end

function CoinService.remove(coin: Instance)
	CapQueue.remove(coins, coin)
	coin:Destroy()
end

return CoinService
