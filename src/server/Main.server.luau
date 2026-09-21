local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ConfigValidation = require(Shared.rules.ConfigValidation)
local Payout = require(Shared.rules.Payout)

local Server = script.Parent
local BridgeBuilder = require(Server.BridgeBuilder)
local CoinService = require(Server.CoinService)
local DataService = require(Server.DataService)
local DropService = require(Server.DropService)
local MachineBuilder = require(Server.MachineBuilder)
local PlayerState = require(Server.PlayerState)
local PusherService = require(Server.PusherService)
local RewardService = require(Server.RewardService)
local Telemetry = require(Server.Telemetry)

local valid, errors = ConfigValidation.validate(Config)
if not valid then
	error("Invalid Config:\n" .. table.concat(errors, "\n"))
end

local dropRemote = Instance.new("RemoteEvent")
dropRemote.Name = "DropCoin"
dropRemote.Parent = ReplicatedStorage

local machine = MachineBuilder.build(Config)
BridgeBuilder.build(Config)
PusherService.start(machine, Config)
CoinService.init(machine, Config)
Telemetry.log("machine_seeded", { count = CoinService.seed() })

RewardService.start(machine, function(ownerUserId: number)
	local reward = Payout.forReward(Config)
	if PlayerState.award(ownerUserId, reward.bonusCoins, reward.scoreDelta) then
		Telemetry.log("reward_won", { userId = ownerUserId, bonusCoins = reward.bonusCoins })
	end
end)

DropService.start(dropRemote, Config)

local function saveFor(player: Player)
	local snapshot = PlayerState.snapshot(player)
	if snapshot then
		DataService.save(player.UserId, snapshot)
		Telemetry.log("data_saved", { userId = player.UserId })
	end
end

local function onPlayerAdded(player: Player)
	Telemetry.log("player_joined", { userId = player.UserId })
	local data, status = DataService.load(player.UserId, Config.startingCoins)
	if player.Parent == nil then
		return -- left while loading
	end
	PlayerState.add(player, data, status)
	Telemetry.log("data_loaded", { userId = player.UserId, status = status })
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	saveFor(player)
	PlayerState.remove(player)
	DropService.forget(player)
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveFor(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.autosaveSeconds)
		for _, player in Players:GetPlayers() do
			saveFor(player)
		end
	end
end)

task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(1)
		local now = os.clock()
		PlayerState.tickRegen(now - last, Config)
		last = now
	end
end)

Telemetry.log("server_started", { pusherSpeed = Config.pusherSpeed, pusherStroke = Config.pusherStroke })
