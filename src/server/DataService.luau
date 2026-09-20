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
