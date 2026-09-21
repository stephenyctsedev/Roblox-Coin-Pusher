# Playtest checklist

Run in Roblox Studio with `rojo serve` running and the Rojo plugin connected. Tick each item and note what you saw. Open View, Output to read the log lines.

## Setup
- [ ] Output shows no red errors on Play.
- [ ] Output shows `[telemetry] {"event":"server_started",...}`.
- [ ] Output shows `machine_seeded` with a count of 51.

## Bridge and spawn
- [ ] You spawn on the green pad on the glass bridge in front of the machine, facing the machine.
- [ ] You are not spawned at the old ground spawn (the Baseplate SpawnLocation is removed).
- [ ] The camera looks down at the machine. The front rows of coins are not hidden behind the deck edge (if they are, raise `bridge.deckTransparency` toward 0.8 or lower `bridge.deckHeight`).
- [ ] The ramp at the back of the deck lets you walk down and back up without getting stuck.
- [ ] The rails stop you falling off the sides and the front; the back opening lines up with the ramp.
- [ ] Clicking over the machine still drops coins under the cursor while you stand on the bridge.

## Machine
- [ ] Base, stand, red walls, red back block, white pusher and faint green reward zone are visible.
- [ ] The pusher slides forward and back about every 3 seconds, smoothly.
- [ ] No bare base is ever visible behind the pusher (its rear stays at the back wall).
- [ ] The retracted pusher looks like it comes out of the back block.

## Pre-filled coins
- [ ] About 51 gold coins sit in staggered rows in front of the pusher and settle within a couple of seconds.
- [ ] No coin sinks into the base, jitters, or pops upward.
- [ ] The pusher nudges the pile toward the green zone on each stroke.

## Dropping
- [ ] HUD shows Coins 20 and Score 0 at the start.
- [ ] A click over the machine drops one coin at the click's left/right position.
- [ ] Coins goes down by 1 for each coin.
- [ ] Clicking very fast drops no more than about 2 coins per second (`drop_rejected` reason `cooldown` in Output).
- [ ] At 0 coins, clicking does nothing (`drop_rejected` reason `no_coins`).
- [ ] A tap on a touch device (Studio device emulator) drops a coin under the finger.

## Rewards and regen
- [ ] A coin that enters the green zone disappears and pays +3 coins and +3 score, once.
- [ ] `reward_won` appears in Output.
- [ ] A pre-filled coin that falls into the zone pays the player who dropped a coin most recently.
- [ ] Coins regenerate by 1 about every 5 seconds and stop at 20.

## Limits
- [ ] Temporarily set `coinsOnMachineCap` to 60 in Config and drop many coins: the oldest coins vanish. Set it back to 150.

## Saving
- [ ] Stop and Play again. Output shows `data_loaded` with status `loaded`, or `datastore_unavailable` (the in-memory fallback in Studio).
- [ ] With Game Settings, Security, "Enable Studio Access to API Services" on and the place saved to Roblox: coins and score come back after a restart.

## Two players
- [ ] Test, Clients and Servers, 2 players: each player's own coins pay only that player.

## After publishing
- [ ] Play the published game with at least one other person. Write down one bug you found and how you fixed it (the interview story).
