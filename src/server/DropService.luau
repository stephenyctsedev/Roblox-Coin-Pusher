local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cooldown = require(ReplicatedStorage.Shared.rules.Cooldown)
local DropZone = require(ReplicatedStorage.Shared.rules.DropZone)

local Server = script.Parent
local CoinService = require(Server.CoinService)
local PlayerState = require(Server.PlayerState)
local Telemetry = require(Server.Telemetry)

local DropService = {}

local cooldown

function DropService.start(remote: RemoteEvent, config)
	local m = config.machine
	local halfWidth = m.platformWidth / 2 - m.coinDiameter / 2
	cooldown = Cooldown.new(config.dropCooldownSeconds)

	remote.OnServerEvent:Connect(function(player: Player, requestedX: any)
		local userId = player.UserId

		local x = DropZone.sanitize(requestedX, halfWidth)
		if x == nil then
			Telemetry.log("drop_rejected", { userId = userId, reason = "invalid_position" })
			return
		end

		if not PlayerState.canDrop(player) then
			Telemetry.log("drop_rejected", { userId = userId, reason = "no_coins" })
			return
		end

		if not cooldown:tryUse(userId, os.clock()) then
			Telemetry.log("drop_rejected", { userId = userId, reason = "cooldown" })
			return
		end

		PlayerState.consumeCoin(player)
		CoinService.spawn(userId, x)
		Telemetry.log("coin_dropped", { userId = userId, x = x, coins = PlayerState.coins(player) })
	end)
end

function DropService.forget(player: Player)
	if cooldown then
		cooldown:reset(player.UserId)
	end
end

return DropService
