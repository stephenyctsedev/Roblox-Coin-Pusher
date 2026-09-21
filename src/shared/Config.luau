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
		pusherDepth = 12, -- Z length of the pusher slab; its rear stays flush with the back wall
		pusherHeight = 1, -- slab sits on the base
		coinDiameter = 2,
		coinThickness = 0.4,
		dropHeight = 8, -- coins spawn this far above the base top
		dropZ = -4.5, -- Z where coins spawn, relative to the base centre
		rewardZoneDepth = 6, -- Z length of the sensor beyond the front edge
		seedStartZ = 0.5, -- first row of pre-filled coins; the full stroke reaches 0, so it nudges this row
		seedEndMargin = 1.5, -- empty strip left before the front edge
		seedGapFactor = 1.02, -- spacing between pre-filled coins as a multiple of the coin diameter
	},

	-- Raised viewing bridge in front of the machine. Players spawn on it and look down at the
	-- pile. All values are world coordinates in studs.
	bridge = {
		centerX = 0,
		frontZ = -8, -- deck edge nearest the machine; must stay in front of the reward zone
		deckWidth = 20,
		deckDepth = 8,
		deckHeight = 10, -- world Y of the deck top; must clear the machine's side walls
		deckThickness = 1,
		deckTransparency = 0.5, -- glass, so the deck does not hide the pile from the camera
		rampWidth = 8,
		rampRun = 18, -- how far the walk-up ramp reaches back from the deck
		railHeight = 3,
	},
}
