local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local SaveScheduler = require(script.Parent.SaveScheduler)
local BoostService = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BoostService"))

local BoostManager = {}

local UPDATE_INTERVAL = 1

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder or not remotesFolder:IsA("Folder") then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local boostEvent = remotesFolder:FindFirstChild("BoostsUpdated")
if not boostEvent or not boostEvent:IsA("RemoteEvent") then
	if boostEvent then
		boostEvent:Destroy()
	end
	boostEvent = Instance.new("RemoteEvent")
	boostEvent.Name = "BoostsUpdated"
	boostEvent.Parent = remotesFolder
end

local activePlayers: { [Player]: boolean } = {}
local multiplierCache: { [Player]: { multiplier: number, boosts: { [string]: number } } } = {}
local accumulatedTime = 0

local function shallowCopy(source)
	local target = {}
	for key, value in pairs(source) do
		target[key] = value
	end
	return target
end

local function ensureBoostTable(dataTable)
	if typeof(dataTable.boosts) ~= "table" then
		dataTable.boosts = {}
	end
	return dataTable.boosts
end

local function trimExpiredBoosts(boosts)
	local now = os.time()
	local changed = false
	for boostName, expiration in pairs(boosts) do
		if typeof(expiration) ~= "number" or expiration <= now then
			boosts[boostName] = nil
			changed = true
		end
	end
	return changed
end

local function computeMultiplier(boosts)
	local total = 1
	for boostName in pairs(boosts) do
		local definition = BoostService.GetDefinition(boostName)
		if definition and typeof(definition.multiplier) == "number" then
			total *= definition.multiplier
		end
	end
	return total
end

local function dispatchUpdate(player, boosts, multiplier)
	if not boostEvent then
		return
	end
	boostEvent:FireClient(player, shallowCopy(boosts), multiplier)
end

local function refreshPlayerBoosts(player)
	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return
	end

	local boosts = ensureBoostTable(playerData)
	local expiredRemoved = trimExpiredBoosts(boosts)
	local multiplier = computeMultiplier(boosts)

	local cached = multiplierCache[player]
	local dirty = expiredRemoved

	if cached then
		if cached.multiplier ~= multiplier then
			dirty = true
		else
			for boostName, expiration in pairs(boosts) do
				if cached.boosts[boostName] ~= expiration then
					dirty = true
					break
				end
			end

			if not dirty then
				for boostName in pairs(cached.boosts) do
					if boosts[boostName] == nil then
						dirty = true
						break
					end
				end
			end
		end
	else
		dirty = true
	end

	if dirty then
		PlayerDataService.Set(player, playerData)
		multiplierCache[player] = {
			multiplier = multiplier,
			boosts = shallowCopy(boosts),
		}
		dispatchUpdate(player, boosts, multiplier)
	end
end

function BoostManager.AddBoost(player, boostName)
	local definition = BoostService.GetDefinition(boostName)
	if not definition then
		warn("[BoostManager] Invalid boost:", boostName)
		return
	end
	return BoostManager.AddBoostDuration(player, boostName, definition.duration)
end

function BoostManager.AddBoostDuration(player, boostName, duration)
	if typeof(duration) ~= "number" or duration <= 0 then
		return
	end

	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return
	end

	local boosts = ensureBoostTable(playerData)
	local now = os.time()

	local existingExpiration = boosts[boostName]
	if typeof(existingExpiration) ~= "number" or existingExpiration < now then
		existingExpiration = now
	end

	boosts[boostName] = existingExpiration + duration
	PlayerDataService.Set(player, playerData)
	SaveScheduler.FlushPlayer(player)
	refreshPlayerBoosts(player)
end

function BoostManager.GetMultiplier(player)
	local cached = multiplierCache[player]
	if cached then
		return cached.multiplier
	end
	return 1
end

function BoostManager.GetBoosts(player)
	local cached = multiplierCache[player]
	if cached then
		return shallowCopy(cached.boosts)
	end

	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return {}
	end

	return shallowCopy(ensureBoostTable(data))
end

local function trackPlayer(player)
	activePlayers[player] = true
	refreshPlayerBoosts(player)
end

local function untrackPlayer(player)
	activePlayers[player] = nil
	multiplierCache[player] = nil
end

Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(untrackPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	trackPlayer(player)
end

RunService.Heartbeat:Connect(function(deltaTime)
	accumulatedTime += deltaTime
	if accumulatedTime < UPDATE_INTERVAL then
		return
	end
	accumulatedTime -= UPDATE_INTERVAL

	for player in pairs(activePlayers) do
		if player and player.Parent then
			refreshPlayerBoosts(player)
		else
			activePlayers[player] = nil
			multiplierCache[player] = nil
		end
	end
end)

return BoostManager
