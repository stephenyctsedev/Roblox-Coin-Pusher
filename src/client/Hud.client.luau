local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local leaderstats = player:WaitForChild("leaderstats")
local coins = leaderstats:WaitForChild("Coins") :: IntValue
local score = leaderstats:WaitForChild("Score") :: IntValue

local gui = Instance.new("ScreenGui")
gui.Name = "CoinHud"
gui.ResetOnSpawn = false

local function makeLabel(name: string, yOffset: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(0, 220, 0, 36)
	label.Position = UDim2.new(0, 16, 0, yOffset)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = gui
	return label
end

local coinsLabel = makeLabel("CoinsLabel", 16)
local scoreLabel = makeLabel("ScoreLabel", 60)

local function refresh()
	coinsLabel.Text = "  Coins: " .. coins.Value
	scoreLabel.Text = "  Score: " .. score.Value
end

coins.Changed:Connect(refresh)
score.Changed:Connect(refresh)
refresh()

gui.Parent = playerGui
