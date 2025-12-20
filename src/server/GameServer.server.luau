local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder or not remotesFolder:IsA("Folder") then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemote(instanceClass, name)
	local existing = remotesFolder:FindFirstChild(name)
	if existing and existing:IsA(instanceClass) then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local remote = Instance.new(instanceClass)
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local requestSync = ensureRemote("RemoteFunction", "RequestSync")
local buyUpgradeEvent = ensureRemote("RemoteEvent", "RequestBuyUpgrade")
local prestigeEvent = ensureRemote("RemoteEvent", "RequestPrestige")
local saveStatusEvent = ensureRemote("RemoteEvent", "SaveStatus")

local PlayerDataService = require(script.Parent.PlayerDataService)
local ProductionService = require(script.Parent.ProductionService)
local UpgradeService = require(script.Parent.UpgradeService)
local PrestigeService = require(script.Parent.PrestigeService)

local activePlayers = {}
local productionLoopStarted = false
local productionConnection
local autosaveFlags = {}

local AUTOSAVE_INTERVAL = 60

local debugTimer = 0
local dtAccumulator = 0
local dtSamples = 0
local lastDebugDps = 0
local lastDebugAmount = 0

local function savePlayerWithStatus(player)
	if not player then
		return
	end

	if saveStatusEvent then
		saveStatusEvent:FireClient(player, "saving")
	end

	local success = PlayerDataService.Save(player)

	if saveStatusEvent then
		if success then
			saveStatusEvent:FireClient(player, "saved")
		else
			saveStatusEvent:FireClient(player, "offline")
		end
	end

	return success
end

local function startAutosave(player)
	if autosaveFlags[player] then
		return
	end

	autosaveFlags[player] = true

	task.spawn(function()
		while autosaveFlags[player] do
			task.wait(AUTOSAVE_INTERVAL)
			if not autosaveFlags[player] then
				break
			end

			if player and player.Parent then
				savePlayerWithStatus(player)
			else
				autosaveFlags[player] = nil
				break
			end
		end
	end)
end

local function stopAutosave(player)
	autosaveFlags[player] = nil
end

local function addPlayer(player)
	PlayerDataService.InitPlayer(player)
	activePlayers[player] = true
	startAutosave(player)
end

local function removePlayer(player)
	activePlayers[player] = nil
	stopAutosave(player)
	savePlayerWithStatus(player)
	PlayerDataService.Release(player)
end

local function applyProduction(player, deltaTime)
	if deltaTime <= 0 then
		return nil, nil
	end

	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return nil, nil
	end

	local dps = ProductionService.GetDataPerSecond(player)
	if typeof(dps) ~= "number" or dps <= 0 then
		return nil, nil
	end

	-- Accumulate DPS using delta time so production remains smooth and frame-rate independent.
	local added = dps * deltaTime
	playerData.data = math.max((playerData.data or 0) + added, 0)
	PlayerDataService.Set(player, playerData)

	return dps, added
end

local function startProductionLoop()
	if productionLoopStarted or productionConnection then
		return
	end
	productionLoopStarted = true

	productionConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if deltaTime <= 0 then
			return
		end

		local exampleDps
		local exampleAdded

		for player in pairs(activePlayers) do
			if player and player.Parent then
				local dps, added = applyProduction(player, deltaTime)
				if dps and not exampleDps then
					exampleDps = dps
					exampleAdded = added
				end
			else
				activePlayers[player] = nil
			end
		end

		dtAccumulator += deltaTime
		dtSamples += 1
		debugTimer += deltaTime

		if exampleDps then
			lastDebugDps = exampleDps
			lastDebugAmount = exampleAdded
		end

		if debugTimer >= 2 then
			local avgDt = dtSamples > 0 and (dtAccumulator / dtSamples) or 0
			debugTimer = 0
			dtAccumulator = 0
			dtSamples = 0
		end
	end)
end

requestSync.OnServerInvoke = function(player)
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end

	local state = table.clone(data)
	local dps = ProductionService.GetDataPerSecond(player)
	state.dps = typeof(dps) == "number" and dps or 0

	return state
end

buyUpgradeEvent.OnServerEvent:Connect(function(player, upgradeId)
	if not player then
		return
	end

	UpgradeService.Buy(player, upgradeId)
end)

prestigeEvent.OnServerEvent:Connect(function(player)
	if not player then
		return
	end

	PrestigeService.Prestige(player)
end)

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)

for _, player in Players:GetPlayers() do
	addPlayer(player)
end

startProductionLoop()

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayerWithStatus(player)
		PlayerDataService.Release(player)
	end
end)
