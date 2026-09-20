return {
	startingCoins = 20,
	regenIntervalSeconds = 5,
	regenCap = 20,
	dropCooldownSeconds = 0.5,
	rewardBonusCoins = 3,
	coinsOnMachineCap = 150,
	pusherSpeed = 4, -- studs per second
	pusherStroke = 6, -- studs the pusher travels forward
	autosaveSeconds = 60,

	machine = {
		originX = 0,
		originY = 3, -- world height of the base centre
		originZ = -28,
		platformWidth = 20, -- X
		platformDepth = 24, -- Z, coins are pushed toward +Z
		baseThickness = 1,
		wallHeight = 4,
		pusherDepth = 6, -- Z length of the pusher slab
		pusherHeight = 1, -- slab sits on the base
		coinDiameter = 2,
		coinThickness = 0.4,
		dropHeight = 8, -- coins spawn this far above the base top
		dropZ = -4.5, -- Z where coins spawn, relative to the base centre
		rewardZoneDepth = 6, -- Z length of the sensor beyond the front edge
	},
}
