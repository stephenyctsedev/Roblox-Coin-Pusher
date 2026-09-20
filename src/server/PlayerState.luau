local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Payout = require(ReplicatedStorage.Shared.rules.Payout)
local Regen = require(ReplicatedStorage.Shared.rules.Regen)

local PlayerState = {}

local states = {}

local function setCoins(state, value)
	state.data.coins = value
	state.coinsValue.Value = value
end

function PlayerState.add(player, data, status)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = data.coins
	coinsValue.Parent = leaderstats

	local scoreValue = Instance.new("IntValue")
	scoreValue.Name = "Score"
	scoreValue.Value = data.score
	scoreValue.Parent = leaderstats

	leaderstats.Parent = player

	states[player] = {
		data = data,
		-- A failed or corrupt load must never overwrite the stored record.
		persist = status == "new" or status == "loaded",
		regenSeconds = 0,
		coinsValue = coinsValue,
		scoreValue = scoreValue,
	}
end

function PlayerState.remove(player)
	states[player] = nil
end

function PlayerState.canDrop(player): boolean
	local state = states[player]
	return state ~= nil and Payout.canDrop(state.data.coins)
end

function PlayerState.consumeCoin(player)
	local state = states[player]
	setCoins(state, Payout.afterDrop(state.data.coins))
end

function PlayerState.coins(player): number
	local state = states[player]
	return state and state.data.coins or 0
end

function PlayerState.award(userId: number, bonusCoins: number, scoreDelta: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	local state = player and states[player]
	if not state then
		return false
	end
	setCoins(state, state.data.coins + bonusCoins)
	state.data.score += scoreDelta
	state.scoreValue.Value = state.data.score
	return true
end

function PlayerState.tickRegen(elapsedSeconds: number, config)
	for _, state in states do
		local newBalance, leftover = Regen.apply(state.data.coins, state.regenSeconds + elapsedSeconds, config)
		state.regenSeconds = leftover
		if newBalance ~= state.data.coins then
			setCoins(state, newBalance)
		end
	end
end

function PlayerState.snapshot(player)
	local state = states[player]
	if not state or not state.persist then
		return nil
	end
	return { version = state.data.version, coins = state.data.coins, score = state.data.score }
end

return PlayerState
