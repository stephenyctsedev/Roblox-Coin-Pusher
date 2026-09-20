local CollectionService = game:GetService("CollectionService")

local CoinService = require(script.Parent.CoinService)

local RewardService = {}

function RewardService.start(machine, onReward: (ownerUserId: number) -> ())
	machine.rewardZone.Touched:Connect(function(hit: BasePart)
		if not CollectionService:HasTag(hit, "Coin") then
			return
		end
		-- Touched can fire several times for one coin; pay exactly once.
		if hit:GetAttribute("Paid") then
			return
		end
		hit:SetAttribute("Paid", true)

		local ownerUserId = hit:GetAttribute("OwnerUserId")
		if hit:GetAttribute("Seeded") then
			-- Pre-filled coins have no owner; credit the most recent dropper, if any.
			ownerUserId = CoinService.lastDropper()
		end
		CoinService.remove(hit)
		if typeof(ownerUserId) == "number" then
			onReward(ownerUserId)
		end
	end)
end

return RewardService
