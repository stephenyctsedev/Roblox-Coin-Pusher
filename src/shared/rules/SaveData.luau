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
