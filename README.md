# Roblox Coin Pusher

A small Roblox coin pusher. The machine starts full of coins. Drop more coins, a pusher slab shoves the pile toward the edge, and coins that fall into the reward zone pay a bonus. Progress is saved per player.

Built with Claude Code assistance. Game rules are plain Luau modules with automated tests; the Roblox-facing parts are checked with a manual playtest checklist.

Play: (add the published link here after publishing)

## How it works

- The server builds the machine from code and decides everything: drops, cooldown, payouts, saving. The client only sends "drop a coin at this X".
- Rules live in `src/shared/rules/` and use no Roblox APIs, so they run under Lune.
- Players spawn on a raised glass bridge in front of the machine and look down at it. Its size and position are `Config.bridge`; the geometry maths is in `src/shared/rules/BridgeLayout.luau`.
- All tuning values are in `src/shared/Config.luau` and are validated at startup.
- Each event (`coin_dropped`, `reward_won`, `drop_rejected`, `machine_seeded`, and so on) is one JSON log line in the server output.

## Requirements

- Roblox Studio
- [Rokit](https://github.com/rojo-rbx/rokit), which installs the pinned Rojo and Lune from `rokit.toml`

## Run it

```bash
rokit install
rojo serve
```

In Studio: open a Baseplate place, click the Rojo plugin, Connect, then Play.

Install the plugin once with `rojo plugin install`. If that fails ("Couldn't find registry keys"), open and sign in to Studio once, or download `Rojo.rbxm` from the matching Rojo release and put it in `%LOCALAPPDATA%\Roblox\Plugins`.

## Test it

```bash
lune run test/run
```

Then work through `docs/PLAYTEST.md` in Studio.

## Rebuild the place file

```bash
rojo build -o build/CoinPusher.rbxlx
```

## Layout

- `src/shared/` config and rules (`rules/` is the tested logic)
- `src/server/` services: machine, bridge, pusher, coins, rewards, saving
- `src/client/` input and HUD
- `test/` Lune specs
- `docs/` design spec, plan and playtest checklist

## Publishing notes

1. In Studio: File, Publish to Roblox.
2. Game Settings, Security: enable Studio access to API services to test saving in Studio.
3. Set the experience to public or unlisted and copy its link into this README.
