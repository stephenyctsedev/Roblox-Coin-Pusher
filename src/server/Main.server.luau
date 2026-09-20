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
