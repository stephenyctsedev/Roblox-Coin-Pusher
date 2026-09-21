# Code tour: learn the Coin Pusher

This is a study guide for the project owner. Claude Code generated all of the code in this repo. The owner chose the features, playtested in Studio and published the game. The goal of this guide is simple: after it, you can open any file, explain what it does, and change it yourself.

How to use it: do one stop at a time (30 to 60 minutes each). At every stop, read the file, read the notes here, then do the "Try it" exercise. Do not skip the exercises. You learn code by changing it, not by reading it.

Run commands from the project folder. If `lune` or `rojo` is not found, add `%USERPROFILE%\.rokit\bin` to your PATH.

---

## Part 0. Luau in 10 minutes

Luau is Roblox's version of Lua. You only need these ideas to read this project.

```lua
local coins = 20                  -- a variable. "local" means only this file/block can see it
local name = "Coin"               -- a string
local ok = true                   -- a boolean
local nothing = nil               -- nil means "no value"

local list = { 10, 20, 30 }       -- a table used as a list. list[1] is 10 (Luau starts at 1, not 0)
local config = { speed = 4 }      -- a table used as a dictionary. config.speed is 4
print(#list)                      -- # gives the length: 3

local function add(a, b)          -- a function
	return a + b
end

if coins >= 1 then ... elseif ... else ... end
for i = 1, 3 do ... end           -- loop with a counter
for _, item in list do ... end    -- loop over a table. _ means "I don't use this value"

print("Coins: " .. coins)         -- .. joins strings
```

A common surprise: positions start at 1, so `list[0]` does not exist. It returns `nil` and does not crash.

```lua
local list = { 10, 20, 30 }
print(list[0])   -- nil  (there is no position 0)
print(list[1])   -- 10
print(list[4])   -- nil  (past the end)
print(#list)     -- 3
```

A wrong index does not crash by itself. The error comes later, when you use the `nil`. For example, `list[0] + 1` fails with "attempt to perform arithmetic on a nil value". You can store a value at key 0 (`list[0] = 99`), but `#list` and `for _, item in list do` ignore it.

Three more ideas you will see everywhere:

1. **Modules.** A file that ends with `return SomeTable` is a module. Another file loads it with `require(...)`. The module is a box of functions: `local Payout = require(...)` then `Payout.canDrop(5)`.
2. **`.` and `:`.** `Payout.canDrop(5)` is a normal call. `cooldown:tryUse(id, now)` is a method call: Luau passes `cooldown` in as the first argument (`self`). It is the same as `Cooldown.tryUse(cooldown, id, now)`.
3. **Type notes.** `function f(x: number): boolean` means "x is a number, returns a boolean". `--!strict` at the top of a file asks Luau to check these. They are notes for humans and tools. They do not change how the code runs.

Roblox ideas you need:

- **Instance**: everything in the game is an Instance (Part, Folder, Script, IntValue). `Instance.new("Part")` makes one. Setting `part.Parent = something` puts it in the world.
- **Service**: `game:GetService("Players")` gets a built-in system (Players, RunService, CollectionService, DataStoreService ...).
- **Event**: `something.Touched:Connect(function(hit) ... end)` means "run this function every time it happens".
- **Server and client**: the server is the one true game (rules, saving). Each player's computer is a client (screen, mouse). A client can be cheated, so the server must not trust it.
- **RemoteEvent**: a pipe from client to server. The client calls `remote:FireServer(x)`. The server receives it in `remote.OnServerEvent`.
- **Attributes and tags**: small labels on an Instance. `coin:SetAttribute("Paid", true)` and `CollectionService:AddTag(coin, "Coin")`.

Check yourself: what is the difference between `list[1]` and `config.speed`? What does `require` do?

---

## Part 1. The big picture

```
 CLIENT (your computer)                     SERVER (Roblox)
 ------------------------                   ----------------------------------------------
 InputController                            DropService
   click -> ray hits DropPlane                sanitize x  ->  has coins?  ->  cooldown ok?
   remote:FireServer(x)  ------------------>        |
                                                    v
                                              PlayerState.consumeCoin
                                              CoinService.spawn  -> coin Part falls
                                                    |
   Hud (Coins / Score labels)                 PusherService moves the pusher (PreSimulation)
        ^                                           |  coins get pushed off the front
        |                                           v
   leaderstats IntValues  <--- PlayerState <--- RewardService (Touched on RewardZone)
   (replicate automatically)     award(+3 coins, +3 score)
                                       |
                                 DataService saves coins and score (DataStore)
```

The key design idea: **the client only sends "drop a coin at this X".** The server decides everything else. That is called *server-authoritative* design, and it is the answer to "how do you stop cheating in a Roblox game?"

The rules (cooldown, payout, regeneration, save data) live in small files under `src/shared/rules/` that use no Roblox parts at all. That is why they can be tested on your PC with Lune, without opening Studio.

---

## Stop 1. `src/shared/Config.luau` (10 min)

**What it does.** One table with every number you can tune: starting coins, cooldown, reward bonus, pusher speed, machine size, bridge size.

**Try it.**
1. Change `rewardBonusCoins = 3` to `5`.
2. Run `lune run test/run`. Do the tests still pass? Why (or why not)?
3. Start `rojo serve`, connect in Studio, press Play, and win one reward. How many coins do you get now?
4. Change it back.

**Can you answer?** Why is everything in one file? (Answer: one place to tune, and `ConfigValidation` checks the whole table at startup.)

---

## Stop 2. The rules: `src/shared/rules/` (2 to 3 hours in total)

These are the easiest files to learn, and the most useful to explain in an interview. Read each rule together with its test in `test/`.

| File | What it does in one sentence |
|---|---|
| `Payout.luau` | A drop needs at least 1 coin and costs 1; a reward gives `rewardBonusCoins` coins and the same score |
| `Cooldown.luau` | Remembers the last use time per player and says no if less than `dropCooldownSeconds` has passed |
| `DropZone.luau` | Cleans the X value from the client: not a number, NaN or infinity is rejected, anything else is clamped to the machine width |
| `Regen.luau` | Adds 1 coin per `regenIntervalSeconds` up to `regenCap`, and returns the leftover seconds |
| `CapQueue.luau` | A list with a maximum size: when a new coin makes it too long, the oldest one is removed and returned |
| `SaveData.luau` | Checks a saved record: version, coins and score must be valid, otherwise the player starts fresh |
| `PusherMath.luau` | Where the pusher is at time `t`: it goes forward and back at constant speed (a triangle wave) |
| `CoinLayout.luau` | Where the 51 starting coins go: rows of coins, every second row shifted half a coin (honeycomb) |
| `ConfigValidation.luau` | Checks the whole Config at startup, and stops the server with a clear message if a value is wrong |

**Try it (do these in order).**
1. Open `test/Cooldown.spec.luau`. Read one test. Write in your own words what it checks.
2. Open `Payout.luau`. Read `forReward`. Now change it so a reward gives **1 more score than coins**: `scoreDelta = config.rewardBonusCoins + 1`.
3. Run `lune run test/run`. One test should fail. Read the message. That is the red step.
4. Fix the test so it expects the new behaviour. Run again. That is the green step.
5. Undo your change and run again. All tests should pass.

**Can you answer?**
- Why does `DropZone.sanitize` check `x ~= x`? (Answer: NaN is the only value that is not equal to itself. A cheater could send NaN.)
- Why does a rejected cooldown attempt not reset the timer? (Look at the test "a rejected attempt does not extend the window".)
- What does `Regen.apply` return, and why two values?

---

## Stop 3. `src/server/Main.server.luau` (30 min)

**What it does.** The startup script. It runs once when the server starts. The order matters:

1. Check `Config` with `ConfigValidation`. Stop with an error if it is wrong.
2. Create the `DropCoin` RemoteEvent.
3. Build the machine (`MachineBuilder`) and the bridge (`BridgeBuilder`).
4. Start the pusher moving (`PusherService.start`).
5. Set up coins and fill the machine (`CoinService.init`, then `seed`).
6. Start reward detection (`RewardService.start`) and drop handling (`DropService.start`).
7. Handle players: load data when a player joins, save when they leave, and every `autosaveSeconds`.
8. Every second, give regenerating coins (`PlayerState.tickRegen`).

**Try it.** Add a line `print("hello from Main")` after step 3. Play in Studio. Find your message in Output (set the context dropdown to Server). Then remove it.

**Can you answer?** Why is the config check the very first thing?

---

## Stop 4. `src/server/DropService.luau` (45 min) - the most important file

**What it does.** It handles every drop request from a client. Read the function body slowly. The checks run in this order, and each one can stop the request:

1. `DropZone.sanitize` - is the X value a real number? (Otherwise: `invalid_position`)
2. `PlayerState.canDrop` - does the player have at least 1 coin? (`no_coins`)
3. `cooldown:tryUse` - has enough time passed? (`cooldown`)
4. Only now: take the coin (`consumeCoin`), spawn it (`CoinService.spawn`), log `coin_dropped`.

**Why this order?** The cooldown check is after the coin check, and the coin is taken only after both pass. So a rejected request never costs a coin.

**Try it.** Change the cooldown in Config to `2`. Click fast in Studio. Watch Output for `drop_rejected` lines with reason `cooldown`. Change it back.

**Can you answer?** If a cheater edits their client to send 1,000 drops per second, what happens? (Answer: the server rejects all but one per cooldown window, and no coins are created for the rejected ones.)

---

## Stop 5. `CoinService.luau` and `RewardService.luau` (1 hour)

**CoinService.** Creates coin Parts. A coin is a cylinder rotated to lie flat. It gets the tag `Coin` and an attribute: `OwnerUserId` (who dropped it) or `Seeded` (pre-filled). `SetNetworkOwner(nil)` keeps the coin's physics on the server, so pushing is the same for everyone. `CapQueue` removes the oldest coin when there are more than `coinsOnMachineCap`.

**RewardService.** When any Part touches the reward zone, and it is a coin, and it was not paid yet:
- mark it `Paid` (because `Touched` can fire many times for one coin),
- work out who gets paid (the owner; for a pre-filled coin, the most recent dropper),
- remove the coin and call the reward function.

**Try it.** In `RewardService`, temporarily comment out the `Paid` check (put `--` at the start of those 3 lines). Play and win a reward. You may get paid more than once for one coin. Put the lines back. This shows why that check exists.

**Can you answer?** Why do pre-filled coins have no owner? Why is the reward paid to the last dropper?

---

## Stop 6. `PlayerState.luau` and `DataService.luau` (1 hour)

**PlayerState.** Keeps each player's coins and score in memory, and mirrors them into `leaderstats` (IntValues). Roblox copies `leaderstats` to the client automatically, which is how the HUD updates. It has a `persist` flag: only data with status `new` or `loaded` may be saved. A failed or corrupt load must never overwrite the saved record.

**DataService.** Loads and saves with `DataStoreService`. It tries up to 3 times with a growing delay. In Studio, if the place is not published, DataStore fails, so it falls back to an in-memory store and logs `datastore_unavailable`. In the live game a failed load returns fresh data with status `failed`, which `PlayerState` will not save.

**Try it.** Play in Studio and read the Output lines `data_loaded` and `data_saved`. Match each to the line in `Main.server.luau` that prints it.

**Can you answer?** Why not save when the load failed? (Answer: you would overwrite a good record with the starting values.)

---

## Stop 7. Building the world: `MachineBuilder`, `BridgeBuilder`, `PusherService` (1 hour)

`MachineBuilder` and `BridgeBuilder` create Parts from numbers in Config. `BridgeLayout.luau` does the maths (positions and sizes) as plain numbers, so it is tested in `test/BridgeLayout.spec.luau`. `PusherService` uses `RunService.PreSimulation`: every frame, before physics runs, it sets the pusher's position from `PusherMath.positionAt`.

**Try it.** Change `bridge.deckHeight` from `10` to `14` in Config. Play. Is the view better or worse? Try `deckTransparency = 0.8`. Change both back.

**Can you answer?** Why is the math in a separate module from the code that creates Parts?

---

## Stop 8. The client: `InputController` and `Hud` (30 min)

**InputController.** On click or tap it builds a ray from the camera through the screen point, and checks where it hits the invisible `DropPlane`. It converts that hit to an X value relative to the machine, and sends only that X with `dropRemote:FireServer(x)`.

**Hud.** Reads the `Coins` and `Score` IntValues from `leaderstats` and updates two labels whenever they change.

**Try it.** In `Hud`, change `"  Coins: "` to `"  Gold: "`. Play and read the HUD. Change it back.

**Can you answer?** Why does the client send a number and not "drop a coin now"? (Answer: the server needs the position, and the client must not decide anything else.)

---

## Stop 9. Tests and Lune (30 min)

`lune run test/run` runs every spec file. `test/harness.luau` is a tiny test tool: `t:test(name, function)` runs a test, and `t:eq(actual, expected)` compares. A failing test prints the name and message.

**Try it.** Write a new test for `CapQueue`: push 3 items into a list with cap 2 and check that the first item is returned and the list has 2 items left. Put it in `test/CapQueue.spec.luau`. Run it.

---

## Exercise ladder (do these after the tour)

1. **Easy.** Make the reward pay `10` coins. Explain what you changed.
2. **Medium.** Make coins regenerate every 3 seconds instead of 5, and cap at 30. Which two Config numbers? Does `ConfigValidation` complain?
3. **Medium.** Make the cooldown different per player group: you do not need to finish it, but write down which files would change.
4. **Bigger.** Add a "streak bonus": every 5th reward in a row gives +2 extra score. Start in `Payout.luau` with a test, then wire it in. Ask a person or an AI to review it, but you write the first version.
5. **After publishing.** Find one bug from another player, fix it, and write down: what did you see, why did it happen, what did you change?

---

## Interview answers, in your own words

Practise saying these out loud in simple English. Change the words so they sound like you.

1. **What is it?** "A small coin pusher on Roblox. You drop coins, a pusher slides forward and back, and coins that fall into the green zone give a bonus."
2. **How much did AI write?** "Claude Code wrote all of the code. I chose the features, tested it in Studio, told it what to change, and published it. I am studying the code now so I can read and change it myself." (Say the last sentence only if it is true.)
3. **How do you stop cheating?** "The client only sends the click position. The server checks the number, the coin balance and a cooldown before it creates a coin."
4. **Why do rewards pay only once?** "The `Touched` event can fire many times for one coin, so the first time I mark the coin `Paid`."
5. **What if saving fails?** "It retries. If the load fails, the player is not saved, so a bad load can never overwrite a good record."
6. **Why tests in Lune?** "The game rules are plain functions with no Roblox parts, so they run on my PC in a second and I can change them safely."
7. **What would you improve?** Your own answer. Ideas: stop players walking onto the machine, prevent coins piling on the bridge side, add more than one machine, track how many players come back.
8. **What bug did you fix after release?** Fill this in after publishing. Do not invent one.

## Resources

- Roblox Creator Docs: https://create.roblox.com/docs
- Luau language: https://luau.org
- Rojo: https://rojo.space/docs
