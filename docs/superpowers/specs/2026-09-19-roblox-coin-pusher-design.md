# Roblox Coin Pusher: Design

Date: 2026-09-19
Status: design approved in chat; spec pending owner review. Not committed.

## Purpose

A small, published Roblox game that the owner can link from a job application (Voldex, Software Engineer - Brookhaven) and explain in an interview. It rebuilds the owner's PlayCanvas Coin Pusher on Roblox so the only new thing is Luau and the Roblox way of working.

The owner has not shipped a Roblox game before. Nothing here may be presented as prior Roblox experience until the game is published.

## Success criteria

1. A published Roblox experience with a public or unlisted link.
2. A Git repo with a README, passing tests (`lune run test/run`), and a manual playtest checklist.
3. A player can drop coins, see coins and score, win rewards, and keep progress after leaving.
4. The server decides everything that matters. The client only sends intent.
5. Tuning values live in one config file. Key events are logged.
6. The owner can explain: the client and server split, the tuning and logging story, and one real bug found after release and how it was fixed.

## Non-goals

Shop, upgrades, sounds, visual polish beyond readable parts, multiple machines, external analytics, session locking across servers, mobile-specific UI beyond tap input.

## Toolchain

- Roblox Studio (free), installed by the owner.
- Rojo, syncs the repo into Studio while playtesting.
- Lune, runs the rule tests without Studio.
- Rokit, pins Rojo and Lune in `rokit.toml`. Versions are pinned to the latest release at install time.
- Git and Node are already installed.

Installing any tool needs the owner's approval first.

## Repo layout

```text
RobloxCoinPusher/
  default.project.json      Rojo project
  rokit.toml                pinned tools
  README.md                 what it is, how to run, how to rebuild, AI-assistance note
  docs/PLAYTEST.md          manual checklist
  docs/superpowers/specs/   this file
  src/
    shared/
      Config.luau           all tuning values
      rules/                pure logic, no Roblox APIs (testable under Lune)
        Cooldown.luau
        Payout.luau
        Regen.luau
        SaveData.luau
        ConfigValidation.luau
        DropZone.luau
        PusherMath.luau
        CapQueue.luau
    server/
      Main.server.luau      starts every service in order
      MachineBuilder.luau
      PusherService.luau
      CoinService.luau
      RewardService.luau
      DataService.luau
      Telemetry.luau
    client/
      InputController.client.luau
      Hud.client.luau
  test/
    run.luau                tiny runner, loads every *.spec.luau
    *.spec.luau             one spec per rules module
```

## Rules modules (pure, unit-tested first)

| Module | Interface | Job |
|---|---|---|
| Cooldown | `Cooldown.new(seconds)`, `:tryUse(id, now) -> boolean`, `:reset(id)` | Server-side drop rate limit per player |
| Payout | `canDrop(balance)`, `afterDrop(balance)`, `forReward(config) -> {bonusCoins, scoreDelta}` | Balance and reward maths |
| Regen | `apply(balance, elapsedSeconds, config) -> newBalance, leftoverSeconds` | 1 coin every N seconds up to a cap |
| SaveData | `new()`, `validate(raw) -> data or nil, err`, `migrate(raw)` | Shape `{version=1, coins, score}`, non-negative integers, safe defaults |
| ConfigValidation | `validate(config) -> ok, errors` | Catches bad tuning values at startup |
| DropZone | `clamp(x, halfWidth) -> x` | Keeps a requested drop position on the machine |
| PusherMath | `positionAt(t, stroke, speed) -> offset` | Back-and-forth motion, deterministic |
| CapQueue | `push(list, item, cap) -> evicted or nil` | Oldest coin is evicted past the cap |

Everything with Roblox APIs (services, builder, HUD) is verified by playtest, not unit tests.

## Config (initial values, tuned in Studio)

`startingCoins = 20`, `regenIntervalSeconds = 5`, `regenCap = 20`, `dropCooldownSeconds = 0.5`, `rewardBonusCoins = 3`, `coinsOnMachineCap = 150`, `pusherSpeed = 4` studs per second, `pusherStroke = 6` studs, plus machine dimensions (platform width and depth, wall height, coin size). Exact machine dimensions are set in the implementation plan.

## Gameplay and data flow

1. Client: click or tap converts to a lateral position on the machine and fires `DropCoin(x)`.
2. Server validates: `x` is a finite number, the player is off cooldown, and the balance is at least 1. Rejected requests are dropped and logged as `drop_rejected` with a reason.
3. Server accepts: clamps `x`, deducts 1 coin, spawns a coin above the platform tagged `Coin` with attribute `OwnerUserId`, logs `coin_dropped`.
4. The coin lands on the platform. The pusher moves back and forth and shoves coins toward the front edge.
5. A coin that falls into the reward zone triggers once (attribute `Paid` guards against repeat touches). The owner gets `rewardBonusCoins` and the score goes up. The coin despawns. Logged as `reward_won`.
6. Regen adds coins on a timer up to `regenCap`, so nobody is stuck at zero.
7. Shared machine per server. Coins are attributed by owner tag. The live coin count is capped; the oldest coin is removed past the cap.

Remote: one RemoteEvent, `DropCoin`, client to server only. Coin balance and score are replicated to the client through `leaderstats` and player attributes.

## Pusher motion

First implementation: an anchored part driven by the server each step from `PusherMath.positionAt`. It is deterministic and its position maths is unit-testable. If playtest shows coins tunnelling or jittering, switch to a physics constraint (for example a `PrismaticConstraint`) behind the same `PusherService` interface. This is the largest technical risk and cannot be verified without Studio.

## Persistence

- DataStore `PlayerData_v1`, key `Player_<UserId>`.
- Load with 3 attempts and backoff (1, 2, 4 seconds). If loading fails, use defaults, mark the profile `loaded = false`, and never save it, so a failed load can't wipe real progress. Logged as `load_failed`.
- Save on leave, on server shutdown (`BindToClose`), and every 60 seconds.
- If DataStore access is unavailable (Studio without API access enabled), fall back to an in-memory store and log clearly that progress will not persist.
- Known limitation: no session locking across servers.

## Logging

`Telemetry.log(event, fields)` prints one JSON line: `{"event": ..., "t": ..., ...}`. Events: `player_joined`, `data_loaded`, `data_saved`, `load_failed`, `coin_dropped`, `drop_rejected`, `reward_won`. In a live server the lines are readable in the developer console. External analytics are out of scope.

## Client

- InputController: click or tap to fire `DropCoin`. No game decisions on the client.
- Hud: a `ScreenGui` built in code with two labels (Coins, Score). Readable, not polished.

## Testing

- Rules modules are written test-first and run headlessly with Lune. A tiny runner in `test/run.luau` loads every `*.spec.luau` and reports pass/fail with a non-zero exit code on failure.
- `docs/PLAYTEST.md` is a checklist the owner runs in Studio and reports back: machine builds, pusher moves, coin drop and cooldown, reward payout once per coin, balance and score update, regen works, save and reload works, drop spam is rejected, coin cap holds, and a two-player test if possible.
- The README states that the game was built with Claude Code assistance.

## Publishing (owner's action)

The owner opens Studio with Rojo connected, checks Game Settings (enable Studio API access for DataStore testing), publishes to Roblox, and shares the link. The owner adds the link and repo to the cover letter and CV only after publishing. The owner pushes to GitHub; nothing is committed or pushed without an explicit instruction.

## Risks and open items

1. Pusher physics feel and stability need tuning in Studio.
2. DataStore behaviour needs Studio API access and a published place.
3. The implementer cannot see the game; the playtest checklist is how problems are found.
4. Exact machine dimensions are decided in the implementation plan.
