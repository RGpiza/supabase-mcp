local GameServerService = {}

function GameServerService.OnStart()
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
local requestLeaderboard = ensureRemote("RemoteFunction", "RequestLeaderboard")
local saveStatusEvent = ensureRemote("RemoteEvent", "SaveStatus")

local PlayerDataService = require(script.Parent.PlayerDataService)
local ProductionService = require(script.Parent.ProductionService)
local UpgradeService = require(script.Parent.UpgradeService)
local PrestigeService = require(script.Parent.PrestigeService)
local MonetizationService = require(script.Parent.MonetizationService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local DebugConfig = nil
do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.utils:FindFirstChild("DebugConfig"))
	end)
	if ok and type(mod) == "table" then
		DebugConfig = mod
	end
end
local DEBUG_LEADERBOARD = false

local activePlayers = {}
local productionLoopStarted = false
local autosaveFlags = {}

local AUTOSAVE_INTERVAL = 60
local LEADERBOARD_LIMIT = 50

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
				local cached = PlayerDataService.Get(player)
				if cached and typeof(cached) == "table" then
					LeaderboardService.UpdatePlayerStat(player, cached.data or 0)
				end
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
	local data = PlayerDataService.InitPlayer(player)
	MonetizationService.ApplyPasses(player)
	activePlayers[player] = true
	startAutosave(player)
	if data and typeof(data) == "table" then
		LeaderboardService.EnsurePlayerEntry(player, data.data or 0)
	else
		LeaderboardService.EnsurePlayerEntry(player, 0)
	end
end

local function removePlayer(player)
	activePlayers[player] = nil
	stopAutosave(player)
	local cached = PlayerDataService.Get(player)
	if cached and typeof(cached) == "table" then
		LeaderboardService.UpdatePlayerStat(player, cached.data or 0)
	else
		LeaderboardService.UpdatePlayerStat(player, 0)
	end
	savePlayerWithStatus(player)
	PlayerDataService.Release(player)
end

local function buildLeaderboard(limit)
	local entries = {}
	for player in pairs(activePlayers) do
		if player and player.Parent then
			local data = PlayerDataService.Get(player)
			if typeof(data) == "table" then
				table.insert(entries, {
					userId = player.UserId,
					username = player.Name,
					score = data.data or 0,
				})
			end
		end
	end

	table.sort(entries, function(a, b)
		return (a.score or 0) > (b.score or 0)
	end)

	local result = {}
	limit = limit or 10
	for index = 1, math.min(limit, #entries) do
		local entry = entries[index]
		result[#result + 1] = {
			rank = index,
			userId = entry.userId,
			username = entry.username,
			score = entry.score,
		}
	end

	return result
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

	local added = dps * deltaTime
	playerData.data = math.max((playerData.data or 0) + added, 0)
	PlayerDataService.Set(player, playerData)

	return dps, added
end

local function startProductionLoop()
	if productionLoopStarted then
		return
	end
	productionLoopStarted = true

	RunService.Heartbeat:Connect(function(deltaTime)
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
			if DebugConfig then
				DebugConfig.Log(string.format("[System Incremental] avg dt: %.4f, sample dps: %.2f, sample added: %.4f", avgDt, lastDebugDps or 0, lastDebugAmount or 0))
			end
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

	MonetizationService.ApplyPasses(player)

	local production = ProductionService.ComputeFinalProduction(data)
	local boostActive = MonetizationService.IsBoostActive(data)
	local system = ProductionService.GetSystemStats(data.upgrades or {})
	local breakdown = production.breakdown or {}
	local leaderboard = buildLeaderboard(10)

	return {
		data = data.data,
		upgrades = data.upgrades,
		prestige = data.prestige,
		corePower = data.corePower,
		owns2xData = data.owns2xData,
		ownsFasterAuto = data.ownsFasterAuto,
		passes = data.passes,
		boostActive = boostActive,
		boostExpiresAt = data.boostExpiresAt,
		boostEnd = data.boostEnd,
		production = {
			base = production.baseDps,
			add = breakdown.additive,
			mulUpgrade = breakdown.upgradeMul,
			mulPrestige = breakdown.prestigeMul,
			mulPass = breakdown.passMul,
			mulBoost = breakdown.boostMul,
			final = production.finalDps,
		},
		system = system,
		baseDps = production.baseDps,
		finalDps = production.finalDps,
		multiplierBreakdown = production.breakdown,
		leaderboard = leaderboard,
	}
end

requestLeaderboard.OnServerInvoke = function(player, limit)
	if not player then
		return {}
	end

	local entries = LeaderboardService.GetTopPlayers(limit or LEADERBOARD_LIMIT)
	local result = {}
	for index, entry in ipairs(entries) do
		local username = nil
		local ok, nameOrErr = pcall(function()
			return Players:GetNameFromUserIdAsync(entry.userId)
		end)
		if ok and nameOrErr then
			username = nameOrErr
		else
			username = ("Player%s"):format(tostring(entry.userId))
		end
		result[#result + 1] = {
			rank = index,
			userId = entry.userId,
			username = username,
			value = entry.value,
		}
	end

	if DEBUG_LEADERBOARD then
		print(("[Leaderboard] Fetched entries=%d"):format(#result))
	end
	return result
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

	print(string.format("[Prestige] Request from %s", player.Name))
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
		local cached = PlayerDataService.Get(player)
		if cached and typeof(cached) == "table" then
			LeaderboardService.UpdatePlayerStat(player, cached.data or 0)
		else
			LeaderboardService.UpdatePlayerStat(player, 0)
		end
		savePlayerWithStatus(player)
		PlayerDataService.Release(player)
	end
end)

end

return GameServerService
