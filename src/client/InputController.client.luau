local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local dropRemote = ReplicatedStorage:WaitForChild("DropCoin") :: RemoteEvent
local machineFolder = Workspace:WaitForChild("CoinMachine")
local dropPlane = machineFolder:WaitForChild("DropPlane") :: BasePart

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.FilterDescendantsInstances = { dropPlane }

-- Returns the X position on the machine (relative to its centre) under a screen point, or nil.
local function screenToLocalX(position: Vector3): number?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	-- InputObject.Position is already adjusted for the top bar, which ScreenPointToRay expects.
	-- If drops land off from the cursor, switch to UserInputService:GetMouseLocation() with
	-- camera:ViewportPointToRay() instead.
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
	if not result then
		return nil
	end
	return dropPlane.CFrame:PointToObjectSpace(result.Position).X
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local inputType = input.UserInputType
	if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
		return
	end
	local x = screenToLocalX(input.Position)
	if x ~= nil then
		dropRemote:FireServer(x)
	end
end)
