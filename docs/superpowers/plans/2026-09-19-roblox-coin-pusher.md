# Roblox Coin Pusher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small Roblox coin pusher game in a Rojo-managed Git repo, with its rules tested under Lune, ready for the owner to playtest in Studio and publish.

**Architecture:** The server builds the coin machine from code and owns every decision (drops, payouts, saving). Game rules live in pure Luau modules with no Roblox APIs, so they are written test-first and run headlessly with Lune. Roblox-facing services and a small client are verified by a manual Studio playtest checklist.

**Tech Stack:** Luau, Rojo (project sync), Lune (headless tests), Rokit (tool manager), Roblox Studio, Git.

**Spec:** `docs/superpowers/specs/2026-09-19-roblox-coin-pusher-design.md`

## Global Constraints

- The Rules modules in `src/shared/rules/` use no Roblox APIs and no `require` of other project files, so Lune can load them.
- `src/shared/Config.luau` holds plain numbers only (no `Vector3`), so a Lune test can validate the shipped config.
- Rojo file suffixes: `*.server.luau` becomes a Script, `*.client.luau` a LocalScript, plain `*.luau` a ModuleScript.
- The server decides everything that matters. The client only sends intent (`DropCoin(x)`).
- Never commit or push unless the owner has said to. Every "Commit" step below runs only after the owner has said to commit; otherwise stop and report. No remote exists and nothing is pushed.
- Every commit message ends with these two trailer lines: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf`.
- Installing any tool (Rokit, Rojo, Lune, Roblox Studio) needs the owner's explicit approval first.
- Nothing may be presented as prior Roblox experience until the game is published. The README states the game was built with Claude Code assistance.
- External analytics, shop, sounds, multiple machines and session locking are out of scope.
- Working directory for every command: `C:\Users\stephen\Documents\Project\RobloxCoinPusher` (Git Bash syntax below).

## File Map

| File | Responsibility |
|---|---|
| `test/harness.luau` | Tiny test harness: `test`, `eq`, `near`, `throws` |
| `test/run.luau` | Runs every registered spec, exits non-zero on failure |
| `test/*.spec.luau` | One spec per rules module (plus the harness) |
| `src/shared/rules/*.luau` | Pure logic modules (Cooldown, Payout, Regen, SaveData, ConfigValidation, DropZone, PusherMath, CapQueue) |
| `src/shared/Config.luau` | All tuning values, plain numbers |
| `src/server/Telemetry.luau` | One JSON log line per event |
| `src/server/MachineBuilder.luau` | Builds the machine parts in Workspace |
| `src/server/PusherService.luau` | Moves the pusher slab each physics step |
| `src/server/CoinService.luau` | Spawns, tracks, caps and removes coins |
| `src/server/RewardService.luau` | Pays a coin once when it enters the reward zone |
| `src/server/PlayerState.luau` | Per-player coins, score, leaderstats, regen |
| `src/server/DataService.luau` | DataStore load and save with retry and memory fallback |
| `src/server/DropService.luau` | Validates and handles `DropCoin` requests |
| `src/server/Main.server.luau` | Starts everything in order |
| `src/client/InputController.client.luau` | Click or tap to `DropCoin(x)` |
| `src/client/Hud.client.luau` | Coins and Score labels |
| `default.project.json` | Rojo project mapping |
| `docs/PLAYTEST.md`, `README.md` | Manual checklist, how to run |

---

### Task 1: Toolchain and test harness

**Files:**
- Create: `.gitignore`, `.gitattributes`, `rokit.toml` (created by Rokit), `test/harness.luau`, `test/run.luau`, `test/harness.spec.luau`

**Interfaces:**
- Produces: `Harness.new() -> h`; `h:test(name, fn)`; `h:eq(actual, expected, message?)`; `h:near(actual, expected, epsilon)`; `h:throws(fn)`; fields `h.passed`, `h.failed`, `h.failures`. Each spec file returns `function(t) ... end`. `test/run.luau` has a `specs` table of `{ name = string, run = function }`.

- [ ] **Step 1: Ask the owner to approve installing Rokit, Rojo and Lune**

Say: "Task 1 installs three tools: Rokit (a tool manager), Rojo and Lune, from their official GitHub releases. OK to install?" Stop until the owner says yes.

- [ ] **Step 2: Install Rokit**

Download the Windows x86_64 binary from https://github.com/rojo-rbx/rokit/releases (latest release), then run it once with `self-install`:

```bash
./rokit-<version>-windows-x86_64.exe self-install
```

Open a new terminal, then run: `rokit --version`
Expected: prints a version number. If `self-install` is not accepted, run the binary with `--help` and follow the install command it lists.

- [ ] **Step 3: Add Rojo and Lune to the repo (this writes `rokit.toml`)**

```bash
rokit init
rokit add rojo-rbx/rojo
rokit add lune-org/lune
rojo --version
lune --version
```

Answer yes if Rokit asks to trust a tool. Expected: both `--version` commands print a version.

- [ ] **Step 4: Create `.gitignore` and `.gitattributes`**

`.gitignore`:

```text
build/
*.rbxl
*.rbxlx
*.rbxl.lock
*.rbxm
Packages/
.claude/
```

`.gitattributes`:

```text
* text=auto
*.luau text eol=lf
*.json text eol=lf
*.md text eol=lf
```

- [ ] **Step 5: Write the harness**

`test/harness.luau`:

```lua
local Harness = {}
Harness.__index = Harness

function Harness.new()
	return setmetatable({ passed = 0, failed = 0, failures = {} }, Harness)
end

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function show(value)
	if type(value) == "table" then
		local parts = {}
		for key, item in value do
			table.insert(parts, tostring(key) .. "=" .. show(item))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

function Harness.test(self, name, fn)
	local ok, err = pcall(fn)
	if ok then
		self.passed += 1
	else
		self.failed += 1
		table.insert(self.failures, name .. "\n    " .. tostring(err))
	end
end

function Harness.eq(_self, actual, expected, message)
	if not deepEqual(actual, expected) then
		local prefix = message and (message .. ": ") or ""
		error(string.format("%sexpected %s, got %s", prefix, show(expected), show(actual)), 2)
	end
end

function Harness.near(_self, actual, expected, epsilon)
	if type(actual) ~= "number" or math.abs(actual - expected) > epsilon then
		error(string.format("expected %s within %s, got %s", tostring(expected), tostring(epsilon), tostring(actual)), 2)
	end
end

function Harness.throws(_self, fn)
	local ok = pcall(fn)
	if ok then
		error("expected an error, but none was thrown", 2)
	end
end

return Harness
```

- [ ] **Step 6: Write the failing harness spec and the runner**

`test/harness.spec.luau`:

```lua
local Harness = require("./harness")

return function(t)
	t:test("harness: eq passes on equal nested tables", function()
		t:eq({ a = 1, b = { 2, 3 } }, { a = 1, b = { 2, 3 } })
	end)

	t:test("harness: eq throws on different tables", function()
		t:throws(function()
			t:eq({ a = 1 }, { a = 2 })
		end)
	end)

	t:test("harness: near accepts values inside epsilon and rejects outside", function()
		t:near(1.0000001, 1, 0.001)
		t:throws(function()
			t:near(1.1, 1, 0.001)
		end)
	end)

	t:test("harness: a failing test is recorded and is not fatal", function()
		local inner = Harness.new()
		inner:test("boom", function()
			error("boom")
		end)
		t:eq(inner.failed, 1)
		t:eq(inner.passed, 0)
	end)
end
```

`test/run.luau`:

```lua
local process = require("@lune/process")
local Harness = require("./harness")

local specs = {
	{ name = "harness", run = require("./harness.spec") },
}

local t = Harness.new()
for _, spec in specs do
	spec.run(t)
end

print(string.format("%d passed, %d failed", t.passed, t.failed))
for _, failure in t.failures do
	print("FAIL " .. failure)
end
if t.failed > 0 then
	process.exit(1)
end
```

- [ ] **Step 7: Run the tests**

Run: `lune run test/run`
Expected: `4 passed, 0 failed` and exit code 0 (`echo $?` prints 0).

If Lune cannot resolve `require("./harness.spec")` (a dot in the file name), rename every spec to use an underscore (`harness_spec.luau`, `Cooldown_spec.luau`, and so on), and update the `require` lines in `test/run.luau` and the spec paths in this plan to match. Do this once, now, before writing more specs.

Verify the runner really fails on a broken test: temporarily change `t:eq({ a = 1 }, { a = 2 })` to expect nothing to throw (for example replace the `t:throws(function()` wrapper with a bare call), run again, expect `FAIL` output and exit code 1, then restore the file and re-run to see `4 passed, 0 failed`.

- [ ] **Step 8: Commit (only if the owner has said to commit)**

```bash
git add .gitignore .gitattributes rokit.toml test/
git commit -m $'chore: add toolchain pins and Lune test harness\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf'
```

---

### Task 2: Cooldown rule

**Files:**
- Create: `src/shared/rules/Cooldown.luau`, `test/Cooldown.spec.luau`
- Modify: `test/run.luau` (add the spec to `specs`)

**Interfaces:**
- Produces: `Cooldown.new(seconds: number) -> Cooldown`; `cd:tryUse(id: any, now: number) -> boolean`; `cd:reset(id: any)`. `seconds` must be a non-negative number or `new` raises an error.

- [ ] **Step 1: Write the failing spec**

`test/Cooldown.spec.luau`:

```lua
local Cooldown = require("../src/shared/rules/Cooldown")

return function(t)
	t:test("Cooldown: first use is allowed", function()
		local cd = Cooldown.new(0.5)
		t:eq(cd:tryUse("a", 10), true)
	end)

	t:test("Cooldown: a second use inside the window is rejected", function()
		local cd = Cooldown.new(0.5)
		cd:tryUse("a", 10)
		t:eq(cd:tryUse("a", 10.2), false)
	end)

	t:test("Cooldown: use is allowed once the window has passed", function()
		local cd = Cooldown.new(0.5)
		cd:tryUse("a", 10)
		t:eq(cd:tryUse("a", 10.5), true)
	end)

	t:test("Cooldown: a rejected attempt does not extend the window", function()
		local cd = Cooldown.new(0.5)
		cd:tryUse("a", 10)
		cd:tryUse("a", 10.4)
		t:eq(cd:tryUse("a", 10.5), true)
	end)

	t:test("Cooldown: ids are independent", function()
		local cd = Cooldown.new(0.5)
		cd:tryUse("a", 10)
		t:eq(cd:tryUse("b", 10.1), true)
	end)

	t:test("Cooldown: reset clears the window", function()
		local cd = Cooldown.new(0.5)
		cd:tryUse("a", 10)
		cd:reset("a")
		t:eq(cd:tryUse("a", 10.1), true)
	end)

	t:test("Cooldown: rejects a negative or non-number window", function()
		t:throws(function()
			Cooldown.new(-1)
		end)
		t:throws(function()
			Cooldown.new("x")
		end)
	end)
end
```

In `test/run.luau`, add this line inside the `specs` table, after the harness entry:

```lua
	{ name = "Cooldown", run = require("./Cooldown.spec") },
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run test/run`
Expected: FAIL. An error that the module `../src/shared/rules/Cooldown` cannot be found, and a non-zero exit code.

- [ ] **Step 3: Write the implementation**

`src/shared/rules/Cooldown.luau`:

```lua
--!strict
local Cooldown = {}
Cooldown.__index = Cooldown

export type Cooldown = {
	seconds: number,
	last: { [any]: number },
	tryUse: (self: Cooldown, id: any, now: number) -> boolean,
	reset: (self: Cooldown, id: any) -> (),
}

function Cooldown.new(seconds: number): Cooldown
	assert(type(seconds) == "number" and seconds >= 0, "Cooldown.new: seconds must be a non-negative number")
	return setmetatable({ seconds = seconds, last = {} }, Cooldown) :: any
end

function Cooldown.tryUse(self: Cooldown, id: any, now: number): boolean
	local last = self.last[id]
	if last ~= nil and now - last < self.seconds then
		return false
	end
	self.last[id] = now
	return true
end

function Cooldown.reset(self: Cooldown, id: any)
	self.last[id] = nil
end

return Cooldown
```

- [ ] **Step 4: Run to verify it passes**

Run: `lune run test/run`
Expected: `11 passed, 0 failed`, exit code 0.

- [ ] **Step 5: Commit (only if the owner has said to commit)**

```bash
git add src/shared/rules/Cooldown.luau test/Cooldown.spec.luau test/run.luau
git commit -m $'feat: add Cooldown rule\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf'
```

---

### Task 3: Payout and Regen rules

**Files:**
- Create: `src/shared/rules/Payout.luau`, `src/shared/rules/Regen.luau`, `test/Payout.spec.luau`, `test/Regen.spec.luau`
- Modify: `test/run.luau`

**Interfaces:**
- Produces: `Payout.canDrop(balance: number) -> boolean`; `Payout.afterDrop(balance: number) -> number` (raises if balance < 1); `Payout.forReward(config: { rewardBonusCoins: number }) -> { bonusCoins: number, scoreDelta: number }`.
- Produces: `Regen.apply(balance: number, elapsedSeconds: number, config: { regenIntervalSeconds: number, regenCap: number }) -> (number, number)` returning `newBalance, leftoverSeconds`.

- [ ] **Step 1: Write the failing specs**

`test/Payout.spec.luau`:

```lua
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
```

`test/Regen.spec.luau`:

```lua
local Regen = require("../src/shared/rules/Regen")

local config = { regenIntervalSeconds = 5, regenCap = 20 }

return function(t)
	t:test("Regen: less than one interval adds nothing and keeps the leftover", function()
		local balance, leftover = Regen.apply(5, 4, config)
		t:eq(balance, 5)
		t:eq(leftover, 4)
	end)

	t:test("Regen: one full interval adds one coin", function()
		local balance, leftover = Regen.apply(5, 5, config)
		t:eq(balance, 6)
		t:eq(leftover, 0)
	end)

	t:test("Regen: several intervals add several coins and keep the remainder", function()
		local balance, leftover = Regen.apply(5, 12, config)
		t:eq(balance, 7)
		t:eq(leftover, 2)
	end)

	t:test("Regen: stops at the cap and drops the leftover", function()
		local balance, leftover = Regen.apply(19, 20, config)
		t:eq(balance, 20)
		t:eq(leftover, 0)
		local exactBalance, exactLeftover = Regen.apply(18, 10, config)
		t:eq(exactBalance, 20)
		t:eq(exactLeftover, 0)
	end)

	t:test("Regen: a balance at the cap stays put", function()
		local balance, leftover = Regen.apply(20, 3, config)
		t:eq(balance, 20)
		t:eq(leftover, 0)
	end)

	t:test("Regen: a balance above the cap is never reduced", function()
		local balance, leftover = Regen.apply(30, 10, config)
		t:eq(balance, 30)
		t:eq(leftover, 0)
	end)

	t:test("Regen: negative elapsed time is treated as zero", function()
		local balance, leftover = Regen.apply(5, -3, config)
		t:eq(balance, 5)
		t:eq(leftover, 0)
	end)
end
```

In `test/run.luau` add inside `specs`:

```lua
	{ name = "Payout", run = require("./Payout.spec") },
	{ name = "Regen", run = require("./Regen.spec") },
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run test/run`
Expected: FAIL, module `../src/shared/rules/Payout` not found, non-zero exit.

- [ ] **Step 3: Write the implementations**

`src/shared/rules/Payout.luau`:

```lua
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
```

`src/shared/rules/Regen.luau`:

```lua
--!strict
local Regen = {}

function Regen.apply(
	balance: number,
	elapsedSeconds: number,
	config: { regenIntervalSeconds: number, regenCap: number }
): (number, number)
	if balance >= config.regenCap then
		return balance, 0
	end
	local elapsed = math.max(elapsedSeconds, 0)
	local ticks = math.floor(elapsed / config.regenIntervalSeconds)
	local room = config.regenCap - balance
	if ticks >= room then
		return config.regenCap, 0
	end
	return balance + ticks, elapsed - ticks * config.regenIntervalSeconds
end

return Regen
```

- [ ] **Step 4: Run to verify it passes**

Run: `lune run test/run`
Expected: `22 passed, 0 failed`, exit code 0.

- [ ] **Step 5: Commit (only if the owner has said to commit)**

```bash
git add src/shared/rules/Payout.luau src/shared/rules/Regen.luau test/Payout.spec.luau test/Regen.spec.luau test/run.luau
git commit -m $'feat: add Payout and Regen rules\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf'
```

---

### Task 4: SaveData rule

**Files:**
- Create: `src/shared/rules/SaveData.luau`, `test/SaveData.spec.luau`
- Modify: `test/run.luau`

**Interfaces:**
- Produces: `SaveData.new(startingCoins: number) -> { version: number, coins: number, score: number }`; `SaveData.migrate(raw: any) -> (any?, string?)`; `SaveData.validate(raw: any) -> (Data?, string?)`; `SaveData.resolve(raw: any, startingCoins: number) -> { data: Data, status: string }` where `status` is `"new"`, `"loaded"` or `"invalid"`.

- [ ] **Step 1: Write the failing spec**

`test/SaveData.spec.luau`:

```lua
local SaveData = require("../src/shared/rules/SaveData")

return function(t)
	t:test("SaveData: new starts at version 1 with the starting coins and zero score", function()
		t:eq(SaveData.new(20), { version = 1, coins = 20, score = 0 })
	end)

	t:test("SaveData: validate accepts a good record", function()
		local data, err = SaveData.validate({ version = 1, coins = 7, score = 12 })
		t:eq(data, { version = 1, coins = 7, score = 12 })
		t:eq(err, nil)
	end)

	t:test("SaveData: validate returns a copy, not the input table", function()
		local raw = { version = 1, coins = 7, score = 12 }
		local data = SaveData.validate(raw)
		data.coins = 99
		t:eq(raw.coins, 7)
	end)

	t:test("SaveData: validate rejects non-tables", function()
		t:eq((SaveData.validate(nil)), nil)
		t:eq((SaveData.validate("x")), nil)
		t:eq((SaveData.validate(5)), nil)
	end)

	t:test("SaveData: validate rejects a missing or future version", function()
		local _, missing = SaveData.validate({ coins = 1, score = 1 })
		t:eq(missing, "missing version")
		local _, future = SaveData.validate({ version = 2, coins = 1, score = 1 })
		t:eq(future, "unsupported future version 2")
		local _, zero = SaveData.validate({ version = 0, coins = 1, score = 1 })
		t:eq(zero, "invalid version")
	end)

	t:test("SaveData: validate rejects bad coins and score", function()
		t:eq((SaveData.validate({ version = 1, coins = -1, score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = 1.5, score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = 0 / 0, score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = math.huge, score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = "5", score = 0 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = 1, score = -3 })), nil)
		t:eq((SaveData.validate({ version = 1, coins = 1 })), nil)
	end)

	t:test("SaveData: resolve treats a missing record as a new player", function()
		t:eq(SaveData.resolve(nil, 20), { data = { version = 1, coins = 20, score = 0 }, status = "new" })
	end)

	t:test("SaveData: resolve loads a valid record", function()
		local resolved = SaveData.resolve({ version = 1, coins = 4, score = 9 }, 20)
		t:eq(resolved, { data = { version = 1, coins = 4, score = 9 }, status = "loaded" })
	end)

	t:test("SaveData: resolve flags a corrupt record and returns safe defaults", function()
		local resolved = SaveData.resolve({ version = 1, coins = -5, score = 0 }, 20)
		t:eq(resolved, { data = { version = 1, coins = 20, score = 0 }, status = "invalid" })
	end)
end
```

Add to `specs` in `test/run.luau`:

```lua
	{ name = "SaveData", run = require("./SaveData.spec") },
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run test/run`
Expected: FAIL, module `../src/shared/rules/SaveData` not found, non-zero exit.

- [ ] **Step 3: Write the implementation**

`src/shared/rules/SaveData.luau`:

```lua
--!strict
local SaveData = {}

local VERSION = 1

export type Data = { version: number, coins: number, score: number }
export type Resolved = { data: Data, status: string }

local function isCount(value: any): boolean
	return type(value) == "number"
		and value == value
		and value >= 0
		and value < math.huge
		and value == math.floor(value)
end

function SaveData.new(startingCoins: number): Data
	return { version = VERSION, coins = startingCoins, score = 0 }
end

function SaveData.migrate(raw: any): (any?, string?)
	if type(raw) ~= "table" then
		return nil, "record is not a table"
	end
	local version = raw.version
	if type(version) ~= "number" then
		return nil, "missing version"
	end
	if version > VERSION then
		return nil, "unsupported future version " .. tostring(version)
	end
	if version < 1 then
		return nil, "invalid version"
	end
	return raw, nil
end

function SaveData.validate(raw: any): (Data?, string?)
	local migrated, err = SaveData.migrate(raw)
	if migrated == nil then
		return nil, err
	end
	if not isCount(migrated.coins) then
		return nil, "coins must be a non-negative integer"
	end
	if not isCount(migrated.score) then
		return nil, "score must be a non-negative integer"
	end
	return { version = VERSION, coins = migrated.coins, score = migrated.score }, nil
end

function SaveData.resolve(raw: any, startingCoins: number): Resolved
	if raw == nil then
		return { data = SaveData.new(startingCoins), status = "new" }
	end
	local data = SaveData.validate(raw)
	if data == nil then
		return { data = SaveData.new(startingCoins), status = "invalid" }
	end
	return { data = data, status = "loaded" }
end

return SaveData
```

- [ ] **Step 4: Run to verify it passes**

Run: `lune run test/run`
Expected: `31 passed, 0 failed`, exit code 0.

- [ ] **Step 5: Commit (only if the owner has said to commit)**

```bash
git add src/shared/rules/SaveData.luau test/SaveData.spec.luau test/run.luau
git commit -m $'feat: add SaveData rule\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf'
```

---

### Task 5: Config and ConfigValidation

**Files:**
- Create: `src/shared/Config.luau`, `src/shared/rules/ConfigValidation.luau`, `test/ConfigValidation.spec.luau`
- Modify: `test/run.luau`

**Interfaces:**
- Produces: `Config` table (fields below). `ConfigValidation.validate(config: any) -> (boolean, { string })`.
- `Config` fields: `startingCoins`, `regenIntervalSeconds`, `regenCap`, `dropCooldownSeconds`, `rewardBonusCoins`, `coinsOnMachineCap`, `pusherSpeed`, `pusherStroke`, `autosaveSeconds`, and `machine = { originX, originY, originZ, platformWidth, platformDepth, baseThickness, wallHeight, pusherDepth, pusherHeight, coinDiameter, coinThickness, dropHeight, dropZ, rewardZoneDepth }`.

- [ ] **Step 1: Write the failing spec**

`test/ConfigValidation.spec.luau`:

```lua
local ConfigValidation = require("../src/shared/rules/ConfigValidation")
local Config = require("../src/shared/Config")

local function validConfig()
	return {
		startingCoins = 20,
		regenIntervalSeconds = 5,
		regenCap = 20,
		dropCooldownSeconds = 0.5,
		rewardBonusCoins = 3,
		coinsOnMachineCap = 150,
		pusherSpeed = 4,
		pusherStroke = 6,
		autosaveSeconds = 60,
		machine = {
			originX = 0,
			originY = 3,
			originZ = -28,
			platformWidth = 20,
			platformDepth = 24,
			baseThickness = 1,
			wallHeight = 4,
			pusherDepth = 6,
			pusherHeight = 1,
			coinDiameter = 2,
			coinThickness = 0.4,
			dropHeight = 8,
			dropZ = -4.5,
			rewardZoneDepth = 6,
		},
	}
end

local function hasError(errors, fragment)
	for _, message in errors do
		if string.find(message, fragment, 1, true) then
			return true
		end
	end
	return false
end

return function(t)
	t:test("ConfigValidation: a good config passes", function()
		local ok, errors = ConfigValidation.validate(validConfig())
		t:eq(ok, true)
		t:eq(errors, {})
	end)

	t:test("ConfigValidation: the shipped Config passes", function()
		local ok, errors = ConfigValidation.validate(Config)
		t:eq(ok, true, table.concat(errors, "; "))
	end)

	t:test("ConfigValidation: a non-table is rejected", function()
		local ok = ConfigValidation.validate(nil)
		t:eq(ok, false)
	end)

	t:test("ConfigValidation: bad top-level numbers are named in the errors", function()
		local config = validConfig()
		config.startingCoins = -1
		config.regenIntervalSeconds = 0
		config.regenCap = 1.5
		config.dropCooldownSeconds = -0.1
		config.rewardBonusCoins = 0
		config.coinsOnMachineCap = 0
		config.pusherSpeed = 0
		config.pusherStroke = -2
		config.autosaveSeconds = 0
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		for _, field in { "startingCoins", "regenIntervalSeconds", "regenCap", "dropCooldownSeconds", "rewardBonusCoins", "coinsOnMachineCap", "pusherSpeed", "pusherStroke", "autosaveSeconds" } do
			t:eq(hasError(errors, field), true, field)
		end
	end)

	t:test("ConfigValidation: NaN and non-numbers are rejected", function()
		local config = validConfig()
		config.pusherSpeed = 0 / 0
		config.pusherStroke = "6"
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "pusherSpeed"), true)
		t:eq(hasError(errors, "pusherStroke"), true)
	end)

	t:test("ConfigValidation: a missing machine table is rejected", function()
		local config = validConfig()
		config.machine = nil
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine"), true)
	end)

	t:test("ConfigValidation: bad machine numbers are named in the errors", function()
		local config = validConfig()
		config.machine.platformWidth = 0
		config.machine.coinDiameter = -1
		config.machine.originX = "0"
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.platformWidth"), true)
		t:eq(hasError(errors, "machine.coinDiameter"), true)
		t:eq(hasError(errors, "machine.originX"), true)
	end)

	t:test("ConfigValidation: the pusher must fit inside the platform", function()
		local config = validConfig()
		config.pusherStroke = 20
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "pusherDepth + pusherStroke"), true)
	end)

	t:test("ConfigValidation: the drop point must sit on the platform", function()
		local config = validConfig()
		config.machine.dropZ = 30
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.dropZ"), true)
	end)

	t:test("ConfigValidation: the base must sit above the ground", function()
		local config = validConfig()
		config.machine.originY = 0.4
		local ok, errors = ConfigValidation.validate(config)
		t:eq(ok, false)
		t:eq(hasError(errors, "machine.originY"), true)
	end)
end
```

Add to `specs` in `test/run.luau`:

```lua
	{ name = "ConfigValidation", run = require("./ConfigValidation.spec") },
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run test/run`
Expected: FAIL, module `../src/shared/rules/ConfigValidation` (or `Config`) not found, non-zero exit.

- [ ] **Step 3: Write Config and ConfigValidation**

`src/shared/Config.luau`:

```lua
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
```

`src/shared/rules/ConfigValidation.luau`:

```lua
--!strict
local ConfigValidation = {}

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function positive(value: number): boolean
	return value > 0
end

local function nonNegative(value: number): boolean
	return value >= 0
end

local function positiveInteger(value: number): boolean
	return value > 0 and value == math.floor(value)
end

local function nonNegativeInteger(value: number): boolean
	return value >= 0 and value == math.floor(value)
end

local function check(errors: { string }, tbl: any, path: string, field: string, predicate: (number) -> boolean, requirement: string)
	local value = tbl[field]
	if not isFinite(value) or not predicate(value) then
		table.insert(errors, path .. field .. ": must be " .. requirement)
	end
end

function ConfigValidation.validate(config: any): (boolean, { string })
	if type(config) ~= "table" then
		return false, { "config: must be a table" }
	end

	local errors: { string } = {}
	check(errors, config, "", "startingCoins", nonNegativeInteger, "a non-negative integer")
	check(errors, config, "", "regenIntervalSeconds", positive, "a positive number")
	check(errors, config, "", "regenCap", positiveInteger, "a positive integer")
	check(errors, config, "", "dropCooldownSeconds", nonNegative, "a non-negative number")
	check(errors, config, "", "rewardBonusCoins", positiveInteger, "a positive integer")
	check(errors, config, "", "coinsOnMachineCap", positiveInteger, "a positive integer")
	check(errors, config, "", "pusherSpeed", positive, "a positive number")
	check(errors, config, "", "pusherStroke", positive, "a positive number")
	check(errors, config, "", "autosaveSeconds", positive, "a positive number")

	local machine = config.machine
	if type(machine) ~= "table" then
		table.insert(errors, "machine: must be a table")
	else
		local anyNumber = function(_: number): boolean
			return true
		end
		check(errors, machine, "machine.", "originX", anyNumber, "a finite number")
		check(errors, machine, "machine.", "originZ", anyNumber, "a finite number")
		check(errors, machine, "machine.", "originY", positive, "a positive number")
		check(errors, machine, "machine.", "platformWidth", positive, "a positive number")
		check(errors, machine, "machine.", "platformDepth", positive, "a positive number")
		check(errors, machine, "machine.", "baseThickness", positive, "a positive number")
		check(errors, machine, "machine.", "wallHeight", positive, "a positive number")
		check(errors, machine, "machine.", "pusherDepth", positive, "a positive number")
		check(errors, machine, "machine.", "pusherHeight", positive, "a positive number")
		check(errors, machine, "machine.", "coinDiameter", positive, "a positive number")
		check(errors, machine, "machine.", "coinThickness", positive, "a positive number")
		check(errors, machine, "machine.", "dropHeight", positive, "a positive number")
		check(errors, machine, "machine.", "dropZ", anyNumber, "a finite number")
		check(errors, machine, "machine.", "rewardZoneDepth", positive, "a positive number")

		if #errors == 0 then
			if machine.originY <= machine.baseThickness / 2 then
				table.insert(errors, "machine.originY: must be above half the base thickness so the stand has height")
			end
			if machine.pusherDepth + config.pusherStroke > machine.platformDepth then
				table.insert(errors, "machine.pusherDepth + pusherStroke: must not exceed machine.platformDepth")
			end
			if math.abs(machine.dropZ) >= machine.platformDepth / 2 then
				table.insert(errors, "machine.dropZ: must sit inside the platform depth")
			end
		end
	end

	if #errors > 0 then
		return false, errors
	end
	return true, {}
end

return ConfigValidation
```

Note on the cross-field checks: they only run when every field is individually valid (`#errors == 0`), so a bad `originY` never reaches the arithmetic.

In the "base must sit above the ground" test, `originY = 0.4` passes the individual check (positive) but fails the cross-field check (0.4 <= 0.5), so the error is `machine.originY: ...`, as the test expects. In the "bad machine numbers" test `originX = "0"` is caught by the individual check.

- [ ] **Step 4: Run to verify it passes**

Run: `lune run test/run`
Expected: `41 passed, 0 failed`, exit code 0.

- [ ] **Step 5: Commit (only if the owner has said to commit)**

```bash
git add src/shared/Config.luau src/shared/rules/ConfigValidation.luau test/ConfigValidation.spec.luau test/run.luau
git commit -m $'feat: add Config and ConfigValidation\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf'
```

---

### Task 6: DropZone, PusherMath and CapQueue rules

**Files:**
- Create: `src/shared/rules/DropZone.luau`, `src/shared/rules/PusherMath.luau`, `src/shared/rules/CapQueue.luau`, `test/DropZone.spec.luau`, `test/PusherMath.spec.luau`, `test/CapQueue.spec.luau`
- Modify: `test/run.luau`

**Interfaces:**
- Produces: `DropZone.clamp(x: number, halfWidth: number) -> number`; `DropZone.sanitize(x: any, halfWidth: number) -> number?` (nil for non-numbers, NaN, infinity).
- Produces: `PusherMath.positionAt(t: number, stroke: number, speed: number) -> number` (offset in `[0, stroke]`, triangle wave, period `2 * stroke / speed`; raises if stroke or speed is not positive).
- Produces: `CapQueue.push(list: { any }, item: any, cap: number) -> any?` (returns the evicted oldest item or nil); `CapQueue.remove(list: { any }, item: any) -> boolean`.

- [ ] **Step 1: Write the failing specs**

`test/DropZone.spec.luau`:

```lua
local DropZone = require("../src/shared/rules/DropZone")

return function(t)
	t:test("DropZone: clamp keeps values inside the half width", function()
		t:eq(DropZone.clamp(3, 10), 3)
		t:eq(DropZone.clamp(100, 10), 10)
		t:eq(DropZone.clamp(-100, 10), -10)
	end)

	t:test("DropZone: sanitize clamps valid numbers", function()
		t:eq(DropZone.sanitize(3, 10), 3)
		t:eq(DropZone.sanitize(100, 10), 10)
		t:eq(DropZone.sanitize(-100, 10), -10)
	end)

	t:test("DropZone: sanitize rejects anything that is not a finite number", function()
		t:eq(DropZone.sanitize(nil, 10), nil)
		t:eq(DropZone.sanitize("5", 10), nil)
		t:eq(DropZone.sanitize(0 / 0, 10), nil)
		t:eq(DropZone.sanitize(math.huge, 10), nil)
		t:eq(DropZone.sanitize(-math.huge, 10), nil)
		t:eq(DropZone.sanitize({}, 10), nil)
	end)
end
```

`test/PusherMath.spec.luau`:

```lua
local PusherMath = require("../src/shared/rules/PusherMath")

return function(t)
	t:test("PusherMath: starts retracted", function()
		t:near(PusherMath.positionAt(0, 6, 4), 0, 1e-9)
	end)

	t:test("PusherMath: moves forward at the given speed", function()
		t:near(PusherMath.positionAt(0.75, 6, 4), 3, 1e-9)
		t:near(PusherMath.positionAt(1.5, 6, 4), 6, 1e-9)
	end)

	t:test("PusherMath: comes back after the stroke", function()
		t:near(PusherMath.positionAt(2.25, 6, 4), 3, 1e-9)
		t:near(PusherMath.positionAt(3, 6, 4), 0, 1e-9)
	end)

	t:test("PusherMath: repeats every period", function()
		t:near(PusherMath.positionAt(4.5, 6, 4), 6, 1e-9)
		t:near(PusherMath.positionAt(300.75, 6, 4), 3, 1e-9)
	end)

	t:test("PusherMath: negative time still stays inside the stroke", function()
		t:near(PusherMath.positionAt(-0.75, 6, 4), 3, 1e-9)
	end)

	t:test("PusherMath: rejects a non-positive stroke or speed", function()
		t:throws(function()
			PusherMath.positionAt(1, 0, 4)
		end)
		t:throws(function()
			PusherMath.positionAt(1, 6, 0)
		end)
	end)
end
```

`test/CapQueue.spec.luau`:

```lua
local CapQueue = require("../src/shared/rules/CapQueue")

return function(t)
	t:test("CapQueue: push below the cap evicts nothing", function()
		local list = {}
		t:eq(CapQueue.push(list, "a", 2), nil)
		t:eq(CapQueue.push(list, "b", 2), nil)
		t:eq(list, { "a", "b" })
	end)

	t:test("CapQueue: push past the cap evicts the oldest", function()
		local list = { "a", "b" }
		t:eq(CapQueue.push(list, "c", 2), "a")
		t:eq(list, { "b", "c" })
	end)

	t:test("CapQueue: remove takes an item out and reports it", function()
		local list = { "a", "b", "c" }
		t:eq(CapQueue.remove(list, "b"), true)
		t:eq(list, { "a", "c" })
	end)

	t:test("CapQueue: remove reports false for an unknown item", function()
		local list = { "a" }
		t:eq(CapQueue.remove(list, "z"), false)
		t:eq(list, { "a" })
	end)

	t:test("CapQueue: a removed item does not count toward the cap", function()
		local list = { "a", "b" }
		CapQueue.remove(list, "a")
		t:eq(CapQueue.push(list, "c", 2), nil)
		t:eq(list, { "b", "c" })
	end)
end
```

Add to `specs` in `test/run.luau`:

```lua
	{ name = "DropZone", run = require("./DropZone.spec") },
	{ name = "PusherMath", run = require("./PusherMath.spec") },
	{ name = "CapQueue", run = require("./CapQueue.spec") },
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run test/run`
Expected: FAIL, module `../src/shared/rules/DropZone` not found, non-zero exit.

- [ ] **Step 3: Write the implementations**

`src/shared/rules/DropZone.luau`:

```lua
--!strict
local DropZone = {}

function DropZone.clamp(x: number, halfWidth: number): number
	return math.max(-halfWidth, math.min(halfWidth, x))
end

function DropZone.sanitize(x: any, halfWidth: number): number?
	if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then
		return nil
	end
	return DropZone.clamp(x, halfWidth)
end

return DropZone
```

`src/shared/rules/PusherMath.luau`:

```lua
--!strict
local PusherMath = {}

function PusherMath.positionAt(t: number, stroke: number, speed: number): number
	assert(stroke > 0 and speed > 0, "PusherMath.positionAt: stroke and speed must be positive")
	local period = 2 * stroke / speed
	local distance = (t % period) * speed
	if distance <= stroke then
		return distance
	end
	return 2 * stroke - distance
end

return PusherMath
```

`src/shared/rules/CapQueue.luau`:

```lua
--!strict
local CapQueue = {}

function CapQueue.push(list: { any }, item: any, cap: number): any?
	table.insert(list, item)
	if #list > cap then
		return table.remove(list, 1)
	end
	return nil
end

function CapQueue.remove(list: { any }, item: any): boolean
	local index = table.find(list, item)
	if index == nil then
		return false
	end
	table.remove(list, index)
	return true
end

return CapQueue
```

- [ ] **Step 4: Run to verify it passes**

Run: `lune run test/run`
Expected: `55 passed, 0 failed`, exit code 0. All eight rules modules now have specs.

- [ ] **Step 5: Commit (only if the owner has said to commit)**

```bash
git add src/shared/rules/DropZone.luau src/shared/rules/PusherMath.luau src/shared/rules/CapQueue.luau test/DropZone.spec.luau test/PusherMath.spec.luau test/CapQueue.spec.luau test/run.luau
git commit -m $'feat: add DropZone, PusherMath and CapQueue rules\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf'
```

---

### Task 7: Rojo project, machine and pusher (first Studio checkpoint)

**Files:**
- Create: `default.project.json`, `src/server/Telemetry.luau`, `src/server/MachineBuilder.luau`, `src/server/PusherService.luau`, `src/server/Main.server.luau`

**Interfaces:**
- Consumes: `Config` (Task 5), `ConfigValidation.validate`, `PusherMath.positionAt`.
- Produces: `Telemetry.log(event: string, fields: { [string]: any }?)`. `MachineBuilder.build(config) -> { folder: Folder, origin: CFrame, pusher: Part, rewardZone: Part, dropPlane: Part }` (also parents the folder to Workspace as `CoinMachine`, replacing an old one). `PusherService.start(machine, config) -> RBXScriptConnection`.

- [ ] **Step 1: Write the Rojo project file**

`default.project.json`:

```json
{
  "name": "RobloxCoinPusher",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": {
        "$path": "src/shared"
      }
    },
    "ServerScriptService": {
      "Server": {
        "$path": "src/server"
      }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": {
          "$path": "src/client"
        }
      }
    }
  }
}
```

Create the empty client folder so the project builds: `mkdir -p src/client && touch src/client/.gitkeep`.

- [ ] **Step 2: Write Telemetry**

`src/server/Telemetry.luau`:

```lua
local HttpService = game:GetService("HttpService")

local Telemetry = {}

function Telemetry.log(event: string, fields: { [string]: any }?)
	local payload: { [string]: any } = { event = event, t = os.time() }
	if fields then
		for key, value in fields do
			payload[key] = value
		end
	end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
	if ok then
		print("[telemetry] " .. encoded)
	else
		print("[telemetry] " .. event .. " (could not encode fields)")
	end
end

return Telemetry
```

- [ ] **Step 3: Write MachineBuilder**

`src/server/MachineBuilder.luau`:

```lua
local Workspace = game:GetService("Workspace")

local MachineBuilder = {}

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function MachineBuilder.build(config)
	local m = config.machine

	local existing = Workspace:FindFirstChild("CoinMachine")
	if existing then
		existing:Destroy()
	end

	local origin = CFrame.new(m.originX, m.originY, m.originZ)
	local halfWidth = m.platformWidth / 2
	local halfDepth = m.platformDepth / 2
	local baseTop = m.baseThickness / 2
	local wallY = baseTop + m.wallHeight / 2
	local standHeight = m.originY - m.baseThickness / 2

	local folder = Instance.new("Folder")
	folder.Name = "CoinMachine"

	newPart("Base", Vector3.new(m.platformWidth, m.baseThickness, m.platformDepth), origin, Color3.fromRGB(70, 70, 85), folder)
	newPart(
		"Stand",
		Vector3.new(m.platformWidth, standHeight, m.platformDepth),
		origin * CFrame.new(0, -(m.baseThickness / 2 + standHeight / 2), 0),
		Color3.fromRGB(40, 40, 50),
		folder
	)

	for _, side in { -1, 1 } do
		newPart(
			"SideWall",
			Vector3.new(1, m.wallHeight, m.platformDepth),
			origin * CFrame.new(side * (halfWidth + 0.5), wallY, 0),
			Color3.fromRGB(200, 60, 60),
			folder
		)
	end
	newPart(
		"BackWall",
		Vector3.new(m.platformWidth + 2, m.wallHeight, 1),
		origin * CFrame.new(0, wallY, -(halfDepth + 0.5)),
		Color3.fromRGB(200, 60, 60),
		folder
	)

	local retractCenterZ = -halfDepth + m.pusherDepth / 2
	local pusherY = baseTop + m.pusherHeight / 2
	local pusher = newPart(
		"Pusher",
		Vector3.new(m.platformWidth - 0.4, m.pusherHeight, m.pusherDepth),
		origin * CFrame.new(0, pusherY, retractCenterZ),
		Color3.fromRGB(240, 240, 240),
		folder
	)

	local rewardZone = newPart(
		"RewardZone",
		Vector3.new(m.platformWidth, 4, m.rewardZoneDepth),
		origin * CFrame.new(0, baseTop - 3, halfDepth + m.rewardZoneDepth / 2 - 0.5),
		Color3.fromRGB(60, 220, 120),
		folder
	)
	rewardZone.Transparency = 0.6
	rewardZone.CanCollide = false
	rewardZone.CanTouch = true

	local dropPlane = newPart(
		"DropPlane",
		Vector3.new(m.platformWidth, 0.2, m.platformDepth),
		origin * CFrame.new(0, baseTop + m.dropHeight, 0),
		Color3.fromRGB(120, 180, 255),
		folder
	)
	dropPlane.Transparency = 0.85
	dropPlane.CanCollide = false
	dropPlane.CanTouch = false
	dropPlane.CanQuery = true

	folder.Parent = Workspace

	return {
		folder = folder,
		origin = origin,
		pusher = pusher,
		rewardZone = rewardZone,
		dropPlane = dropPlane,
	}
end

return MachineBuilder
```

- [ ] **Step 4: Write PusherService**

`src/server/PusherService.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PusherMath = require(ReplicatedStorage.Shared.rules.PusherMath)

local PusherService = {}

function PusherService.start(machine, config)
	local m = config.machine
	local retractCenterZ = -m.platformDepth / 2 + m.pusherDepth / 2
	local pusherY = m.baseThickness / 2 + m.pusherHeight / 2
	local startTime = os.clock()

	-- PreSimulation runs before physics each frame, so coins react to the new position this frame.
	-- If PreSimulation is unavailable in your Studio version, use RunService.Heartbeat instead.
	return RunService.PreSimulation:Connect(function()
		local offset = PusherMath.positionAt(os.clock() - startTime, config.pusherStroke, config.pusherSpeed)
		machine.pusher.CFrame = machine.origin * CFrame.new(0, pusherY, retractCenterZ + offset)
	end)
end

return PusherService
```

- [ ] **Step 5: Write the first version of Main**

`src/server/Main.server.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ConfigValidation = require(Shared.rules.ConfigValidation)

local Server = script.Parent
local MachineBuilder = require(Server.MachineBuilder)
local PusherService = require(Server.PusherService)
local Telemetry = require(Server.Telemetry)

local valid, errors = ConfigValidation.validate(Config)
if not valid then
	error("Invalid Config:\n" .. table.concat(errors, "\n"))
end

local machine = MachineBuilder.build(Config)
PusherService.start(machine, Config)

Telemetry.log("server_started", { pusherSpeed = Config.pusherSpeed, pusherStroke = Config.pusherStroke })
```

- [ ] **Step 6: Verify the Rojo project builds**

Run: `mkdir -p build && rojo build -o build/CoinPusher.rbxlx`
Expected: `Built project to build/CoinPusher.rbxlx` with no errors. The `build/` folder is git-ignored.

- [ ] **Step 7: Owner Studio checkpoint 1 (the owner runs this)**

Ask the owner to do these steps and report back:

1. Install Roblox Studio from https://create.roblox.com/ if it is not installed, and sign in.
2. In the repo folder run `rojo plugin install`, then restart Studio. If that command is not available, run `rojo plugin --help` or install the Rojo plugin from the Roblox Creator Store.
3. In Studio create a new Baseplate place. Save it outside the repo (for example `Documents\Roblox\CoinPusher.rbxl`).
4. In a terminal in the repo folder run `rojo serve`. In Studio open the Plugins tab, click Rojo, then Connect.
5. Click Play (F5). Watch the Output window and the 3D view.

Expected: no red errors; one line like `[telemetry] {"event":"server_started",...}`; a machine (grey base on a dark stand, red walls, a white slab, a faint green zone in front) appears near `(0, 3, -28)`; the white slab slides forward and back once every 3 seconds. The owner reports what they see, including any red error text.

If the slab is not visible or does not move, fix `MachineBuilder` or `PusherService` before going on. If the slab jitters, note it for Task 9 tuning; do not change the design yet.

- [ ] **Step 8: Commit (only if the owner has said to commit)**

```bash
git add default.project.json src/server src/client/.gitkeep
git commit -m $'feat: add Rojo project, machine builder and pusher\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf'
```

---

### Task 8: Gameplay services, saving and client (second Studio checkpoint)

**Files:**
- Create: `src/server/PlayerState.luau`, `src/server/DataService.luau`, `src/server/CoinService.luau`, `src/server/DropService.luau`, `src/server/RewardService.luau`, `src/client/InputController.client.luau`, `src/client/Hud.client.luau`
- Modify: `src/server/Main.server.luau` (replace with the full version below), delete `src/client/.gitkeep`

**Interfaces:**
- Consumes: `Payout.canDrop`, `Payout.afterDrop`, `Payout.forReward`, `Regen.apply`, `SaveData.new`, `SaveData.resolve`, `Cooldown.new`, `DropZone.sanitize`, `CapQueue.push`, `CapQueue.remove`, `Telemetry.log`, and the `machine` table from `MachineBuilder.build`.
- Produces:
  - `PlayerState.add(player, data, status)`, `PlayerState.remove(player)`, `PlayerState.canDrop(player) -> boolean`, `PlayerState.consumeCoin(player)`, `PlayerState.coins(player) -> number`, `PlayerState.award(userId, bonusCoins, scoreDelta) -> boolean`, `PlayerState.tickRegen(elapsedSeconds, config)`, `PlayerState.snapshot(player) -> Data?` (nil when the profile must not be saved).
  - `DataService.load(userId, startingCoins) -> (Data, status)` with status `"new"`, `"loaded"`, `"invalid"` or `"failed"`; `DataService.save(userId, data)`.
  - `CoinService.init(machine, config)`, `CoinService.spawn(ownerUserId, localX) -> Part`, `CoinService.remove(coin)`.
  - `DropService.start(remote, config)`, `DropService.forget(player)`.
  - `RewardService.start(machine, onReward)` where `onReward(ownerUserId: number)`.

- [ ] **Step 1: Write PlayerState**

`src/server/PlayerState.luau`:

```lua
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
```

- [ ] **Step 2: Write DataService**

`src/server/DataService.luau`:

```lua
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SaveData = require(ReplicatedStorage.Shared.rules.SaveData)
local Telemetry = require(script.Parent.Telemetry)

local DataService = {}

local STORE_NAME = "PlayerData_v1"
local ATTEMPTS = 3
local BASE_DELAY_SECONDS = 1

local memory = {}
local usingMemory = false

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

local function withRetry(fn)
	local lastError
	for attempt = 1, ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < ATTEMPTS then
			task.wait(BASE_DELAY_SECONDS * 2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

function DataService.load(userId: number, startingCoins: number)
	if usingMemory then
		local resolved = SaveData.resolve(memory[keyFor(userId)], startingCoins)
		return resolved.data, resolved.status
	end

	local ok, raw = withRetry(function()
		return DataStoreService:GetDataStore(STORE_NAME):GetAsync(keyFor(userId))
	end)

	if not ok then
		if RunService:IsStudio() then
			usingMemory = true
			Telemetry.log("datastore_unavailable", {
				reason = tostring(raw),
				note = "using in-memory store, progress will not persist",
			})
			return DataService.load(userId, startingCoins)
		end
		Telemetry.log("load_failed", { userId = userId, error = tostring(raw) })
		return SaveData.new(startingCoins), "failed"
	end

	local resolved = SaveData.resolve(raw, startingCoins)
	if resolved.status == "invalid" then
		Telemetry.log("load_failed", { userId = userId, error = "stored record failed validation" })
	end
	return resolved.data, resolved.status
end

function DataService.save(userId: number, data)
	local copy = { version = data.version, coins = data.coins, score = data.score }
	if usingMemory then
		memory[keyFor(userId)] = copy
		return
	end
	local ok, err = withRetry(function()
		DataStoreService:GetDataStore(STORE_NAME):SetAsync(keyFor(userId), copy)
	end)
	if not ok then
		Telemetry.log("save_failed", { userId = userId, error = tostring(err) })
	end
end

return DataService
```

- [ ] **Step 3: Write CoinService**

`src/server/CoinService.luau`:

```lua
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CapQueue = require(ReplicatedStorage.Shared.rules.CapQueue)

local CoinService = {}

local machine
local config
local coins = {}

function CoinService.init(machineRef, configRef)
	machine = machineRef
	config = configRef
end

function CoinService.spawn(ownerUserId: number, localX: number): Part
	local m = config.machine
	local baseTop = m.baseThickness / 2

	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(m.coinThickness, m.coinDiameter, m.coinDiameter)
	coin.Material = Enum.Material.Metal
	coin.Color = Color3.fromRGB(240, 190, 40)
	coin.TopSurface = Enum.SurfaceType.Smooth
	coin.BottomSurface = Enum.SurfaceType.Smooth
	-- density, friction, elasticity, frictionWeight, elasticityWeight
	coin.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.1, 1, 1)
	-- A cylinder's axis is X; rotating 90 degrees about Z lays the coin flat.
	coin.CFrame = machine.origin
		* CFrame.new(localX, baseTop + m.dropHeight, m.dropZ)
		* CFrame.Angles(0, 0, math.rad(90))
	coin:SetAttribute("OwnerUserId", ownerUserId)
	CollectionService:AddTag(coin, "Coin")
	coin.Parent = machine.folder
	-- Keep coin physics on the server so pushing is consistent for everyone.
	coin:SetNetworkOwner(nil)

	local evicted = CapQueue.push(coins, coin, config.coinsOnMachineCap)
	if evicted then
		evicted:Destroy()
	end
	return coin
end

function CoinService.remove(coin: Instance)
	CapQueue.remove(coins, coin)
	coin:Destroy()
end

return CoinService
```

- [ ] **Step 4: Write DropService**

`src/server/DropService.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cooldown = require(ReplicatedStorage.Shared.rules.Cooldown)
local DropZone = require(ReplicatedStorage.Shared.rules.DropZone)

local Server = script.Parent
local CoinService = require(Server.CoinService)
local PlayerState = require(Server.PlayerState)
local Telemetry = require(Server.Telemetry)

local DropService = {}

local cooldown

function DropService.start(remote: RemoteEvent, config)
	local m = config.machine
	local halfWidth = m.platformWidth / 2 - m.coinDiameter / 2
	cooldown = Cooldown.new(config.dropCooldownSeconds)

	remote.OnServerEvent:Connect(function(player: Player, requestedX: any)
		local userId = player.UserId

		local x = DropZone.sanitize(requestedX, halfWidth)
		if x == nil then
			Telemetry.log("drop_rejected", { userId = userId, reason = "invalid_position" })
			return
		end

		if not PlayerState.canDrop(player) then
			Telemetry.log("drop_rejected", { userId = userId, reason = "no_coins" })
			return
		end

		if not cooldown:tryUse(userId, os.clock()) then
			Telemetry.log("drop_rejected", { userId = userId, reason = "cooldown" })
			return
		end

		PlayerState.consumeCoin(player)
		CoinService.spawn(userId, x)
		Telemetry.log("coin_dropped", { userId = userId, x = x, coins = PlayerState.coins(player) })
	end)
end

function DropService.forget(player: Player)
	if cooldown then
		cooldown:reset(player.UserId)
	end
end

return DropService
```

- [ ] **Step 5: Write RewardService**

`src/server/RewardService.luau`:

```lua
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
		CoinService.remove(hit)
		if typeof(ownerUserId) == "number" then
			onReward(ownerUserId)
		end
	end)
end

return RewardService
```

- [ ] **Step 6: Replace Main with the full version**

`src/server/Main.server.luau`:

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ConfigValidation = require(Shared.rules.ConfigValidation)
local Payout = require(Shared.rules.Payout)

local Server = script.Parent
local CoinService = require(Server.CoinService)
local DataService = require(Server.DataService)
local DropService = require(Server.DropService)
local MachineBuilder = require(Server.MachineBuilder)
local PlayerState = require(Server.PlayerState)
local PusherService = require(Server.PusherService)
local RewardService = require(Server.RewardService)
local Telemetry = require(Server.Telemetry)

local valid, errors = ConfigValidation.validate(Config)
if not valid then
	error("Invalid Config:\n" .. table.concat(errors, "\n"))
end

local dropRemote = Instance.new("RemoteEvent")
dropRemote.Name = "DropCoin"
dropRemote.Parent = ReplicatedStorage

local machine = MachineBuilder.build(Config)
PusherService.start(machine, Config)
CoinService.init(machine, Config)

RewardService.start(machine, function(ownerUserId: number)
	local reward = Payout.forReward(Config)
	if PlayerState.award(ownerUserId, reward.bonusCoins, reward.scoreDelta) then
		Telemetry.log("reward_won", { userId = ownerUserId, bonusCoins = reward.bonusCoins })
	end
end)

DropService.start(dropRemote, Config)

local function saveFor(player: Player)
	local snapshot = PlayerState.snapshot(player)
	if snapshot then
		DataService.save(player.UserId, snapshot)
		Telemetry.log("data_saved", { userId = player.UserId })
	end
end

local function onPlayerAdded(player: Player)
	Telemetry.log("player_joined", { userId = player.UserId })
	local data, status = DataService.load(player.UserId, Config.startingCoins)
	if player.Parent == nil then
		return -- left while loading
	end
	PlayerState.add(player, data, status)
	Telemetry.log("data_loaded", { userId = player.UserId, status = status })
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	saveFor(player)
	PlayerState.remove(player)
	DropService.forget(player)
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveFor(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.autosaveSeconds)
		for _, player in Players:GetPlayers() do
			saveFor(player)
		end
	end
end)

task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(1)
		local now = os.clock()
		PlayerState.tickRegen(now - last, Config)
		last = now
	end
end)

Telemetry.log("server_started", { pusherSpeed = Config.pusherSpeed, pusherStroke = Config.pusherStroke })
```

- [ ] **Step 7: Write the client scripts**

Delete the placeholder: `rm src/client/.gitkeep`.

`src/client/InputController.client.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local dropRemote = ReplicatedStorage:WaitForChild("DropCoin") :: RemoteEvent
local machineFolder = Workspace:WaitForChild("CoinMachine")
local dropPlane = machineFolder:WaitForChild("DropPlane") :: BasePart

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.FilterDescendantsInstances = { dropPlane }

-- Returns the X position on the machine (relative to its centre) under a screen point, or nil.
local function screenToLocalX(position: Vector3): number?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	-- InputObject.Position is already adjusted for the top bar, which ScreenPointToRay expects.
	-- If drops land off from the cursor, switch to UserInputService:GetMouseLocation() with
	-- camera:ViewportPointToRay() instead.
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
	if not result then
		return nil
	end
	return dropPlane.CFrame:PointToObjectSpace(result.Position).X
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local inputType = input.UserInputType
	if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
		return
	end
	local x = screenToLocalX(input.Position)
	if x ~= nil then
		dropRemote:FireServer(x)
	end
end)
```

`src/client/Hud.client.luau`:

```lua
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local leaderstats = player:WaitForChild("leaderstats")
local coins = leaderstats:WaitForChild("Coins") :: IntValue
local score = leaderstats:WaitForChild("Score") :: IntValue

local gui = Instance.new("ScreenGui")
gui.Name = "CoinHud"
gui.ResetOnSpawn = false

local function makeLabel(name: string, yOffset: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(0, 220, 0, 36)
	label.Position = UDim2.new(0, 16, 0, yOffset)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = gui
	return label
end

local coinsLabel = makeLabel("CoinsLabel", 16)
local scoreLabel = makeLabel("ScoreLabel", 60)

local function refresh()
	coinsLabel.Text = "  Coins: " .. coins.Value
	scoreLabel.Text = "  Score: " .. score.Value
end

coins.Changed:Connect(refresh)
score.Changed:Connect(refresh)
refresh()

gui.Parent = playerGui
```

- [ ] **Step 8: Re-run the Lune tests and rebuild the place**

Run: `lune run test/run && rojo build -o build/CoinPusher.rbxlx`
Expected: `55 passed, 0 failed`, then `Built project to build/CoinPusher.rbxlx`.

- [ ] **Step 9: Owner Studio checkpoint 2 (the owner runs this)**

With `rojo serve` running and Rojo connected, the owner presses Play and works through `docs/PLAYTEST.md` (written in Task 9; until it exists, use this short list) and reports back:

1. The HUD shows `Coins: 20` and `Score: 0`.
2. Clicking over the machine drops one coin at the click's left/right position; Coins goes to 19.
3. Clicking very fast does not drop more than about two coins per second.
4. The pusher shoves coins toward the green zone; a coin that reaches the zone disappears and Coins goes up by 3 and Score by 3.
5. The Output window shows `[telemetry]` lines for `coin_dropped`, `reward_won`, `drop_rejected`.
6. Wait 5 seconds after spending a coin: Coins goes up by 1.
7. Stop and Play again: Output says either the data loaded, or `datastore_unavailable` (progress will not persist until API access is enabled and the place is saved to Roblox).

Ask the owner to describe anything that looks wrong: coins jittering on the slab, passing through the pusher, flying off, or landing far from the cursor. These are physics tuning items handled in Task 9.

- [ ] **Step 10: Commit (only if the owner has said to commit)**

```bash
git add src
git commit -m $'feat: add gameplay services, saving and client\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf'
```

---

### Task 9: Playtest checklist, tuning, README and release

**Files:**
- Create: `docs/PLAYTEST.md`, `README.md`
- Modify: `src/shared/Config.luau` (tuning values only, driven by playtest findings)

**Interfaces:**
- Consumes: everything from Tasks 1 to 8.

- [ ] **Step 1: Write the playtest checklist**

`docs/PLAYTEST.md`:

```markdown
# Playtest checklist

Run in Roblox Studio with `rojo serve` running and Rojo connected. Tick each item and note what you saw.

## Setup
- [ ] Output shows no red errors on Play.
- [ ] Output shows `[telemetry] {"event":"server_started",...}`.

## Machine
- [ ] Base, stand, red walls, white pusher and faint green reward zone are visible.
- [ ] The pusher slides forward and back about every 3 seconds, smoothly.
- [ ] Coins on the base are pushed toward the front edge.
- [ ] Coins do not pass through the pusher or pop off the top of it.

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
- [ ] Coins regenerate by 1 about every 5 seconds and stop at 20.

## Limits
- [ ] Temporarily set `coinsOnMachineCap` to 10 in Config, drop many coins: the oldest coins vanish. Set it back to 150.

## Saving
- [ ] Stop and Play again. Output shows `data_loaded` with status `loaded`, or `datastore_unavailable` (in-memory fallback in Studio).
- [ ] With Game Settings, Security, "Enable Studio Access to API Services" on and the place saved to Roblox: coins and score come back after a restart.

## Two players
- [ ] Test, Clients and Servers, 2 players: each player's coins pay only that player.

## After publishing
- [ ] Play the published game with at least one other person. Write down one bug you found and how you fixed it (the interview story).
```

- [ ] **Step 2: Tune from the owner's findings**

Ask the owner for the results of Tasks 7 and 8 and `docs/PLAYTEST.md`. Make changes only in `src/shared/Config.luau`, one at a time, then re-run `lune run test/run` (the shipped-config test must still pass):

- Coins jitter or tunnel through the pusher: lower `pusherSpeed` (for example 4 to 2.5), or raise `pusherHeight` (1 to 1.5, keeping it above `coinThickness`).
- Coins never reach the front edge: raise `pusherStroke` (6 to 8) as long as `pusherDepth + pusherStroke <= platformDepth`, or spawn closer to the front by raising `dropZ` (for example -4.5 to 0).
- Coins pile up and never pay: reduce `coinsOnMachineCap` or raise `pusherStroke`.
- Too easy or too hard: change `rewardBonusCoins`, `regenIntervalSeconds`, `regenCap`.

If tuning cannot fix jitter or tunnelling, switch `PusherService` to a `PrismaticConstraint` motor while keeping `PusherService.start(machine, config)` unchanged, then ask the owner to re-run the Machine checks.

- [ ] **Step 3: Write the README**

`README.md`:

```markdown
# Roblox Coin Pusher

A small Roblox coin pusher. Drop coins onto a machine, a pusher slab shoves them toward the edge, and coins that fall into the reward zone pay a bonus. Progress is saved per player.

Built with Claude Code assistance. Game rules are plain Luau modules with automated tests; the Roblox-facing parts are checked with a manual playtest checklist.

Play: (add the published link here after publishing)

## How it works

- The server builds the machine from code and decides everything: drops, cooldown, payouts, saving. The client only sends "drop a coin at this X".
- Rules live in `src/shared/rules/` and use no Roblox APIs, so they run under Lune.
- All tuning values are in `src/shared/Config.luau`.
- Each event (`coin_dropped`, `reward_won`, `drop_rejected`, and so on) is one JSON log line in the server output.

## Requirements

- Roblox Studio
- [Rokit](https://github.com/rojo-rbx/rokit), which installs the pinned Rojo and Lune from `rokit.toml`

## Run it

```bash
rokit install
rojo serve
```

In Studio: open a Baseplate place, click the Rojo plugin, Connect, then Play. Install the plugin once with `rojo plugin install`.

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
- `src/server/` services: machine, pusher, coins, rewards, saving
- `src/client/` input and HUD
- `test/` Lune specs
- `docs/` design spec, plan and playtest checklist

## Publishing notes

1. In Studio: File, Publish to Roblox.
2. Game Settings, Security: enable Studio access to API services to test saving in Studio.
3. Set the experience to public or unlisted and copy its link into this README.
```

- [ ] **Step 4: Final verification**

Run: `lune run test/run && rojo build -o build/CoinPusher.rbxlx && git status --short`
Expected: `55 passed, 0 failed`, `Built project`, and only the expected files listed.

- [ ] **Step 5: Owner release steps (the owner runs these)**

1. Work through `docs/PLAYTEST.md`; fix anything failing (Step 2).
2. Publish from Studio and set the experience to public or unlisted.
3. Play it with someone else, find and fix at least one bug, and note it in the checklist's "After publishing" item.
4. Put the link in `README.md` and, only then, in the cover letter and CV.
5. Create a GitHub repo and push when ready (this plan never pushes).

- [ ] **Step 6: Commit (only if the owner has said to commit)**

```bash
git add docs/PLAYTEST.md README.md src/shared/Config.luau
git commit -m $'docs: add playtest checklist and README, tune config\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01ABqqGS6NiBq2MWM51W2Uzf'
```

---

## Self-Review Notes

- **Spec coverage:** rules modules (Tasks 2 to 6), Config (5), machine/pusher (7), drop flow, rewards, regen, cap, persistence with retry and memory fallback, telemetry, client (8), testing and playtest checklist (1 to 6, 9), README with AI-assistance note and publishing (9). Non-goals are not implemented.
- **Additions to the spec** (already written into the spec): `PlayerState` and `DropService` modules, `SaveData.resolve`, `DropZone.sanitize`, `CapQueue.remove`, plain-number `Config`.
- **Known unverified items** (cannot be tested without Studio): pusher physics feel, `PreSimulation` availability, input coordinate mapping, `rojo plugin install` and Rokit `self-install` command names. Each has a stated fallback in its step.
