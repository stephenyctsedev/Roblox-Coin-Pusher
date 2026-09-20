local Payout = require("../src/shared/rules/Payout")

return function(t)
	t:test("Payout: canDrop needs at least one coin", function()
		t:eq(Payout.canDrop(0), false)
		t:eq(Payout.canDrop(1), true)
		t:eq(Payout.canDrop(20), true)
	end)

	t:test("Payout: afterDrop removes exactly one coin", function()
		t:eq(Payout.afterDrop(5), 4)
		t:eq(Payout.afterDrop(1), 0)
	end)

	t:test("Payout: afterDrop refuses to go below zero", function()
		t:throws(function()
			Payout.afterDrop(0)
		end)
	end)

	t:test("Payout: forReward pays the configured bonus and the same score", function()
		t:eq(Payout.forReward({ rewardBonusCoins = 3 }), { bonusCoins = 3, scoreDelta = 3 })
		t:eq(Payout.forReward({ rewardBonusCoins = 5 }), { bonusCoins = 5, scoreDelta = 5 })
	end)
end
