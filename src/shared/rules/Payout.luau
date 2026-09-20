--!strict
local Payout = {}

function Payout.canDrop(balance: number): boolean
	return balance >= 1
end

function Payout.afterDrop(balance: number): number
	assert(balance >= 1, "Payout.afterDrop: balance is below 1")
	return balance - 1
end

function Payout.forReward(config: { rewardBonusCoins: number }): { bonusCoins: number, scoreDelta: number }
	return { bonusCoins = config.rewardBonusCoins, scoreDelta = config.rewardBonusCoins }
end

return Payout
