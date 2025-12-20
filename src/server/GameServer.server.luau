local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")

local REMOTES_FOLDER_NAME = "Remotes"
local PLAYER_GUI_WAIT_TIME = 5
local PRESTIGE_OFFLINE_STEP = 0.1

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
if not remotesFolder then
	warn("[GameServer] Remotes folder not found after timeout.")
	return
end

local function safeGetRemote(name)
	return remotesFolder:FindFirstChild(name)
end

local requestSync = safeGetRemote("RequestSync")
local getLeaderboard = safeGetRemote("GetLeaderboard")
local getLifetimeLeaderboard = safeGetRemote("GetLifetimeLeaderboard")
local purchaseUpgradeEvent = safeGetRemote("PurchaseUpgrade")
local prestigeEvent = safeGetRemote("RequestPrestige")
local requestPrestigePreview = safeGetRemote("RequestPrestigePreview")
local saveStatusEvent = safeGetRemote("SaveStatus")
local storeAnalyticsEvent = safeGetRemote("StoreAnalyticsEvent")
local offlinePreviewEvent = safeGetRemote("OfflineEarningsPreview")
local weeklyResetTimeFunction = safeGetRemote("GetWeeklyResetTime")
local loadingProgressEvent = safeGetRemote("LoadingProgress")
local prestigePreviewEvent = safeGetRemote("PrestigePreviewUpdate")
local sessionBonusEvent = safeGetRemote("SessionBonusUpdate")
local globalAnnouncementEvent = safeGetRemote("GlobalAnnouncement")
local globalStatsEvent = safeGetRemote("GlobalStatsUpdate")
local getGlobalStatsFunction = safeGetRemote("GetGlobalStats")
local serverPowerEvent = safeGetRemote("ServerPowerUpdate")
local systemNotificationEvent = safeGetRemote("SystemNotification")
local autoBuyPresetApplyEvent = safeGetRemote("AutoBuyPresetApply")
local autoBuyPresetSaveEvent = safeGetRemote("AutoBuyPresetSave")
local autoBuyPresetStateEvent = safeGetRemote("AutoBuyPresetState")
local requestAutoBuyPresets = safeGetRemote("RequestAutoBuyPresets")
local autoBuyPresetUnlockPromptEvent = safeGetRemote("AutoBuyPresetUnlockPrompt")
local autoBuyAutoSwitchSettingsEvent = safeGetRemote("AutoBuyAutoSwitchSettings")
local setAutoBuyEvent = safeGetRemote("SetAutoBuy")
local autoBuyStateEvent = safeGetRemote("AutoBuyState")

local PlayerDataService = require(script.Parent.PlayerDataService)
local ProductionService = require(script.Parent.ProductionService)
local UpgradeService = require(script.Parent.UpgradeService)
local PrestigeService = require(script.Parent.PrestigeService)
local SessionRewardService = require(script.Parent.SessionRewardService)
local GlobalAnnouncementService = require(script.Parent.GlobalAnnouncementService)
local GlobalStatsService = require(script.Parent.GlobalStatsService)
local EconomyAnalytics = require(script.Parent.EconomyAnalytics)
local OfflineProgress
do
	local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
	local offlineProgressModule = sharedFolder and sharedFolder:FindFirstChild("OfflineProgress")
	if offlineProgressModule then
		OfflineProgress = require(offlineProgressModule)
	else
		warn("[GameServer] OfflineProgress module not found - offline earnings disabled.")
	end
end
local AnalyticsLogger = require(script.Parent.AnalyticsLogger)
local AutomationService = require(script.Parent.AutomationService)
local SaveScheduler = require(script.Parent.SaveScheduler)
local LeaderboardService = require(script.Parent.LeaderboardService)
local TitleDisplayService = require(script.Parent.TitleDisplayService)
local DataGrantService = require(script.Parent.DataGrantService)

local activePlayers = {}
local productionLoopStarted = false
local productionConnection
local storeStateByPlayer = {}
local storePlatformByPlayer = {}
local offlinePreviewSent = {}
local sessionInfo = {}
local prestigePreviewState = {}
local pendingPrestigePreviews = {}
local clientReadyConnections = {}
local sessionBonusLoopStarted = false
local globalStatsLoopStarted = false
local GLOBAL_STATS_BROADCAST_INTERVAL = 45
local SERVER_POWER_PER_PLAYER = 0.005
local SERVER_POWER_CAP = 0.05
local weeklyWinnerInfo = nil
local weeklyWinnerShown = {}

local sendSessionBonusUpdate
local sendGlobalStats
local sendServerPowerUpdate
local sendSystemNotification

local GLOBAL_STATS_DATA_STEP = 1_000_000
local accumulatedGlobalStatsDelta = 0

local function shallowCopy(source)
	if typeof(source) ~= "table" then
		return nil
	end

	local copy = {}
	for key, value in source do
		copy[key] = value
	end
	return copy
end

local function previewPayloadChanged(previous, nextPayload)
	if not previous then
		return true
	end

	for _, key in ipairs({
		"currentData",
		"nextMultiplier",
		"multiplierGain",
		"canPrestige",
		"unlockRequirement",
		"storageTier",
	}) do
		if previous[key] ~= nextPayload[key] then
			return true
		end
	end

	return false
end

local function sendPrestigePreview(player, force)
	if not prestigePreviewEvent then
		return
	end

	local payload = PrestigeService.GetPreview(player)
	if typeof(payload) ~= "table" then
		return
	end

	local previous = prestigePreviewState[player]
	if not force and not previewPayloadChanged(previous, payload) then
		return
	end

	prestigePreviewState[player] = shallowCopy(payload)
	if player:GetAttribute("ClientReady") then
		prestigePreviewEvent:FireClient(player, payload)
	else
		pendingPrestigePreviews[player] = payload
	end
end

local function flushPendingPrestigePreview(player)
	if not prestigePreviewEvent then
		return
	end

	local pending = pendingPrestigePreviews[player] or prestigePreviewState[player]
	if pending then
		prestigePreviewEvent:FireClient(player, pending)
		pendingPrestigePreviews[player] = nil
	end
end

local function trackClientReady(player)
	if clientReadyConnections[player] then
		return
	end

	clientReadyConnections[player] = player:GetAttributeChangedSignal("ClientReady"):Connect(function()
		if player:GetAttribute("ClientReady") then
			flushPendingPrestigePreview(player)
		end
	end)

	if player:GetAttribute("ClientReady") then
		flushPendingPrestigePreview(player)
	end
end

local function savePlayerWithStatus(player, force)
	if not player then
		return
	end

	if saveStatusEvent then
		saveStatusEvent:FireClient(player, "saving")
	end

	local success = SaveScheduler.FlushPlayer(player, force ~= false)

	if saveStatusEvent then
		if success then
			saveStatusEvent:FireClient(player, "saved")
		else
			saveStatusEvent:FireClient(player, "offline")
		end
	end

	return success
end

PlayerDataService.OnAfterSet(function(player)
	if not player then
		return
	end
	sendPrestigePreview(player)
end)

local function applyOfflineProgress(player, playerData)
	if typeof(playerData) ~= "table" then
		return
	end
	if not OfflineProgress then
		return
	end

	local baseProduction = ProductionService.GetBaseDataPerSecond(player)
	if typeof(baseProduction) ~= "number" or baseProduction <= 0 then
		playerData.lastSeen = os.time()
		PlayerDataService.Set(player, {
			lastSeen = playerData.lastSeen,
			boosts = playerData.boosts,
		})
		return
	end

	local now = os.time()
	local lastSeen = typeof(playerData.lastSeen) == "number" and math.max(playerData.lastSeen, 0) or now
	local timeAway = math.max(0, now - lastSeen)
	local gain, _, hadOfflineBoosts, baseAmount, boostedAmount = OfflineProgress.Calculate(playerData, baseProduction, now)
	local prestigeLevel = typeof(playerData.prestige) == "number" and math.max(playerData.prestige, 0) or 0
	local prestigeMultiplier = 1 + (prestigeLevel * PRESTIGE_OFFLINE_STEP)

	gain = typeof(gain) == "number" and gain or 0
	baseAmount = typeof(baseAmount) == "number" and baseAmount or 0
	boostedAmount = typeof(boostedAmount) == "number" and boostedAmount or 0
	if typeof(prestigeMultiplier) ~= "number" then
		prestigeMultiplier = 1
	end
	if typeof(timeAway) ~= "number" or timeAway < 0 then
		timeAway = 0
	end

	local totalGain = gain * prestigeMultiplier
	local totalBase = baseAmount * prestigeMultiplier
	local totalBoosted = boostedAmount * prestigeMultiplier
	local startingData = typeof(playerData.data) == "number" and playerData.data or 0

	if totalGain <= 0 then
		PlayerDataService.Set(player, {
			lastSeen = playerData.lastSeen,
			boosts = playerData.boosts,
		})
		return
	end

	if totalGain > 0 then
		sessionInfo[player] = sessionInfo[player] or {}
		sessionInfo[player].lastOfflineEarnings = {
			total = totalGain,
			hadBoosts = hadOfflineBoosts == true,
			prestige = prestigeLevel,
			timeAway = timeAway,
		}
	end

	local balanceAfter
	if totalGain > 0 then
		local _, newBalance = DataGrantService.GrantData(player, totalGain, "OfflineEarnings")
		balanceAfter = newBalance
	end

	PlayerDataService.Set(player, {
		lastSeen = playerData.lastSeen,
		boosts = playerData.boosts,
	})

	if totalGain > 0 then
		EconomyAnalytics.LogSource(
			player,
			totalGain,
			balanceAfter or (startingData + totalGain),
			Enum.AnalyticsEconomyTransactionType.TimedReward,
			"OfflineEarnings",
			{
				BoostType = "Offline",
				PrestigeLevel = playerData.prestige or 0,
			}
		)

		if offlinePreviewEvent and not offlinePreviewSent[player] then
			local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:FindFirstChild("PlayerGui")
			if not playerGui then
				playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIME)
			end

			if playerGui then
				local terminalUi = playerGui:FindFirstChild("TerminalUI")
				if not terminalUi then
					terminalUi = playerGui:WaitForChild("TerminalUI", PLAYER_GUI_WAIT_TIME)
				end

				if terminalUi then
					offlinePreviewSent[player] = true
					offlinePreviewEvent:FireClient(player, {
						totalAmount = totalGain,
						baseAmount = totalBase,
						boostedAmount = totalBoosted,
						hadBoosts = hadOfflineBoosts == true,
						prestigeMultiplier = prestigeMultiplier,
					})
				end
			end
		end
	end
end

local function fireLoadingProgress(player, message, progress)
	if not loadingProgressEvent then
		return
	end

	loadingProgressEvent:FireClient(player, message, progress)
end

local function sendAutoBuyPresetState(player)
	if not autoBuyPresetStateEvent or not player then
		return
	end

	local payload = AutomationService.GetPresetState(player, true)
	if payload then
		autoBuyPresetStateEvent:FireClient(player, payload)
	end
end

local function sendAutoBuyState(player)
	if not (autoBuyStateEvent and player) then
		return
	end

	local state = AutomationService.GetAutoBuyState(player)
	if state then
		autoBuyStateEvent:FireClient(player, state)
	end
end

AutomationService.OnPresetStateChanged(function(player)
	sendAutoBuyPresetState(player)
	sendAutoBuyState(player)
end)

local function broadcastWeeklyWinner(info, isFresh)
	if not (globalAnnouncementEvent and info) then
		return
	end

	weeklyWinnerInfo = info

	local payload = {
		type = "WeeklyWinner",
		name = info.name,
		value = info.value,
		fresh = isFresh ~= false,
	}

	globalAnnouncementEvent:FireAllClients(payload)

	for _, player in ipairs(Players:GetPlayers()) do
		weeklyWinnerShown[player] = true
	end
end

local function sendWeeklyWinnerRecap(player)
	if not (player and player.Parent and globalAnnouncementEvent and weeklyWinnerInfo) then
		return
	end

	if weeklyWinnerShown[player] then
		return
	end

	weeklyWinnerShown[player] = true

	globalAnnouncementEvent:FireClient(player, {
		type = "WeeklyWinner",
		name = weeklyWinnerInfo.name,
		value = weeklyWinnerInfo.value,
		fresh = false,
	})
end

local function addPlayer(player)
	fireLoadingProgress(player, "Loading data", 0.25)

	local playerData = PlayerDataService.InitPlayer(player)
	player:SetAttribute("StorePlatform", player:GetAttribute("StorePlatform") or "Unknown")
	sessionInfo[player] = {
		joinTime = os.time(),
	}

	fireLoadingProgress(player, "Applying offline earnings", 0.5)

	applyOfflineProgress(player, playerData)

	fireLoadingProgress(player, "Syncing boosts", 0.75)

	activePlayers[player] = true
	trackClientReady(player)
	sendPrestigePreview(player, true)
	sendSessionBonusUpdate(player)
	sendGlobalStats(player)
	sendServerPowerUpdate()
	sendSystemNotification("➕ Player joined the system")
	sendAutoBuyState(player)
	sendWeeklyWinnerRecap(player)

	fireLoadingProgress(player, "Finalizing", 1)
end

local function removePlayer(player)
	activePlayers[player] = nil
	savePlayerWithStatus(player, true)
	LeaderboardService.ForceSync(player)
	PlayerDataService.Release(player)
	storeStateByPlayer[player] = nil
	storePlatformByPlayer[player] = nil
	offlinePreviewSent[player] = nil
	sessionInfo[player] = nil
	prestigePreviewState[player] = nil
	pendingPrestigePreviews[player] = nil
	AutomationService.ClearAutoBuyState(player)
	weeklyWinnerShown[player] = nil
	if clientReadyConnections[player] then
		clientReadyConnections[player]:Disconnect()
		clientReadyConnections[player] = nil
	end
	sendServerPowerUpdate()
	sendSystemNotification("ホ- Player disconnected")
end

local validStoreEventTypes = {
	StoreOpened = true,
	StoreClosed = true,
	ItemClicked = true,
	PurchasePromptShown = true,
}

local function logStoreAnalytics(player, eventName, payload)
	local enriched = table.clone(payload)
	enriched.UserId = player and player.UserId or 0

	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName, 1, enriched)
	end)

	if not ok then
		warn("[GameServer] Failed to log store analytics:", err)
	end
end

local function setupWeeklyWinnerAnnouncements()
	if LeaderboardService.OnWeeklyWinnerAnnounced then
		LeaderboardService.OnWeeklyWinnerAnnounced(function(info)
			if typeof(info) ~= "table" then
				return
			end
			info.name = info.name or string.format("User %d", info.userId or 0)
			if typeof(info.value) ~= "number" then
				info.value = 0
			end
			broadcastWeeklyWinner(info, true)
		end)
	end

	if LeaderboardService.GetLatestWeeklyWinner then
		local latest = LeaderboardService.GetLatestWeeklyWinner()
		if typeof(latest) == "table" then
			latest.name = latest.name or string.format("User %d", latest.userId or 0)
			if typeof(latest.value) ~= "number" then
				latest.value = 0
			end
			weeklyWinnerInfo = latest
			for _, player in ipairs(Players:GetPlayers()) do
				task.defer(sendWeeklyWinnerRecap, player)
			end
		end
	end
end

if storeAnalyticsEvent and storeAnalyticsEvent:IsA("RemoteEvent") then
	storeAnalyticsEvent.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			return
		end

		local eventName = payload.Event
		if typeof(eventName) ~= "string" or not validStoreEventTypes[eventName] then
			return
		end

		local platform = typeof(payload.Platform) == "string" and payload.Platform or nil
		if platform then
			storePlatformByPlayer[player] = platform
			player:SetAttribute("StorePlatform", platform)
		end

		if eventName == "StoreOpened" then
			if storeStateByPlayer[player] then
				return
			end
			storeStateByPlayer[player] = true
		elseif eventName == "StoreClosed" then
			if storeStateByPlayer[player] == false then
				return
			end
			storeStateByPlayer[player] = false
		end

		local data = {
			ItemName = tostring(payload.ItemName or ""),
			ProductType = tostring(payload.ProductType or ""),
			ProductId = typeof(payload.ProductId) == "number" and payload.ProductId or 0,
			Platform = storePlatformByPlayer[player] or "Unknown",
		}

		logStoreAnalytics(player, "Store" .. eventName, data)
	end)
end

local function getActivePlayerCount()
	local count = 0
	for player in pairs(activePlayers) do
		if player then
			count += 1
		end
	end
	return count
end

local function getServerPowerMultiplier(count)
	local playerCount = count or getActivePlayerCount()
	local bonus = math.min(playerCount * SERVER_POWER_PER_PLAYER, SERVER_POWER_CAP)
	return 1 + bonus, playerCount
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
	local dataMultiplier = SessionRewardService.GetDataMultiplier(player)
	if typeof(dataMultiplier) == "number" and dataMultiplier > 0 then
		dps *= dataMultiplier
	end
	local serverPowerMultiplier = getServerPowerMultiplier()
	dps *= serverPowerMultiplier
	if typeof(dps) ~= "number" or dps <= 0 then
		return nil, nil
	end

	-- Accumulate DPS using delta time so production remains smooth and frame-rate independent.
	local added = dps * deltaTime
	if added > 0 then
		DataGrantService.GrantData(player, added, "Production")
	end

	return dps, added
end

sendSessionBonusUpdate = function(player)
	if not sessionBonusEvent then
		return
	end

	local progress = SessionRewardService.GetProgress(player)
	if not progress then
		return
	end

	local payload = {
		elapsedSeconds = progress.elapsedSeconds,
		targetSeconds = progress.targetSeconds,
		activeRewards = progress.activeRewards,
	}

	local activations = SessionRewardService.PopPendingActivations(player)
	if activations and #activations > 0 then
		payload.activatedRewards = activations
	end

	sessionBonusEvent:FireClient(player, payload)
end

sendServerPowerUpdate = function()
	if not serverPowerEvent then
		return
	end

	local multiplier, playerCount = getServerPowerMultiplier()
	serverPowerEvent:FireAllClients({
		multiplier = multiplier,
		playerCount = playerCount,
	})
end

sendSystemNotification = function(message)
	if not systemNotificationEvent or typeof(message) ~= "string" then
		return
	end
	systemNotificationEvent:FireAllClients(message)
end

local function buildGlobalStatsPayload(stats)
	local statsTable = stats or GlobalStatsService.GetStats()
	local totalData = 0
	local totalPrestiges = 0

	if typeof(statsTable) == "table" then
		totalData = statsTable.totalDataGenerated or statsTable.LifetimeData or statsTable.totalData or 0
		totalPrestiges = statsTable.totalPrestiges or statsTable.TotalPrestiges or 0
	end

	return {
		totalData = totalData,
		totalPrestiges = totalPrestiges,
	}
end

sendGlobalStats = function(player, overrideStats)
	if not globalStatsEvent then
		return
	end

	local payload = buildGlobalStatsPayload(overrideStats)

	if player then
		globalStatsEvent:FireClient(player, payload)
	else
		globalStatsEvent:FireAllClients(payload)
	end
end

local statsChangeConnection
if GlobalStatsService.OnChanged then
	statsChangeConnection = GlobalStatsService.OnChanged(function(kind, delta, lifetime, prestiges)
		local changeType = tostring(kind or "")
		local deltaValue = typeof(delta) == "number" and delta or 0
		local stats = {
			totalDataGenerated = lifetime or 0,
			totalPrestiges = prestiges or 0,
		}

		if changeType == "data" then
			accumulatedGlobalStatsDelta += deltaValue
			if accumulatedGlobalStatsDelta >= GLOBAL_STATS_DATA_STEP then
				accumulatedGlobalStatsDelta -= GLOBAL_STATS_DATA_STEP
				sendGlobalStats(nil, stats)
			end
		elseif changeType == "prestige" then
			accumulatedGlobalStatsDelta = 0
			sendGlobalStats(nil, stats)
		end
	end)
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

		for player in pairs(activePlayers) do
			if player and player.Parent then
				applyProduction(player, deltaTime)
			else
				activePlayers[player] = nil
			end
		end
	end)
end

local function startSessionBonusLoop()
	if sessionBonusLoopStarted then
		return
	end
	sessionBonusLoopStarted = true

	task.spawn(function()
		while true do
			task.wait(1)
			for player in pairs(activePlayers) do
				if player and player.Parent then
					sendSessionBonusUpdate(player)
				else
					activePlayers[player] = nil
				end
			end
		end
	end)
end

local function startGlobalStatsLoop()
	if globalStatsLoopStarted then
		return
	end
	globalStatsLoopStarted = true

	task.spawn(function()
		while true do
			task.wait(GLOBAL_STATS_BROADCAST_INTERVAL)
			sendGlobalStats()
		end
	end)
end

-- RequestSync is handled by RequestSyncHandler; avoid assigning here to prevent conflicts.

if getLeaderboard and getLeaderboard:IsA("RemoteFunction") then
	getLeaderboard.OnServerInvoke = function(player, mode)
		local result = LeaderboardService.GetLeaderboard(player, mode)
		if typeof(result) == "table" then
			return result
		end
		return {}
	end
end

if getLifetimeLeaderboard and getLifetimeLeaderboard:IsA("RemoteFunction") then
	getLifetimeLeaderboard.OnServerInvoke = function(player, force)
		local result = LeaderboardService.GetLifetimeLeaderboard(player, force == true)
		if typeof(result) == "table" then
			return result
		end
		return {}
	end
end

if weeklyResetTimeFunction and weeklyResetTimeFunction:IsA("RemoteFunction") then
	weeklyResetTimeFunction.OnServerInvoke = function(player)
		local result = LeaderboardService.GetWeeklyResetInfo(player)
		if typeof(result) == "table" then
			return result
		end
		return {}
	end
end

if purchaseUpgradeEvent and purchaseUpgradeEvent:IsA("RemoteEvent") then
	purchaseUpgradeEvent.OnServerEvent:Connect(function(player, payload)
		if not player or typeof(payload) ~= "table" then
			return
		end

		local upgradeId = payload.upgradeId
		if typeof(upgradeId) ~= "string" then
			return
		end

		local mode = payload.mode == "max" and "max" or "single"
		if mode == "max" then
			UpgradeService.BuyMax(player, upgradeId)
		else
			UpgradeService.Buy(player, upgradeId)
		end
	end)
end

if prestigeEvent and prestigeEvent:IsA("RemoteEvent") then
	prestigeEvent.OnServerEvent:Connect(function(player)
		if not player then
			return
		end

		local success = PrestigeService.Prestige(player)
		if success then
			AutomationService.ApplyAutoSwitchPreset(player)
			AutomationService.DisableAllAutoBuy(player)
			sendAutoBuyState(player)
		end
	end)
end

if requestPrestigePreview and requestPrestigePreview:IsA("RemoteFunction") then
	requestPrestigePreview.OnServerInvoke = function(player)
		local result = PrestigeService.GetPreview(player)
		if typeof(result) == "table" then
			return result
		end
		return {}
	end
end

if requestAutoBuyPresets and requestAutoBuyPresets:IsA("RemoteFunction") then
	requestAutoBuyPresets.OnServerInvoke = function(player)
		local result = AutomationService.GetPresetState(player)
		if typeof(result) == "table" then
			return result
		end
		return {}
	end
end

if autoBuyPresetApplyEvent and autoBuyPresetApplyEvent:IsA("RemoteEvent") then
	autoBuyPresetApplyEvent.OnServerEvent:Connect(function(player, presetIndex)
		if not player then
			return
		end

		local success, result = AutomationService.ApplyPreset(player, presetIndex)
		if not success then
			if result == "locked_preset" then
				if autoBuyPresetUnlockPromptEvent then
					autoBuyPresetUnlockPromptEvent:FireClient(player)
				end
			else
				sendAutoBuyPresetState(player)
			end
		end
	end)
end

if autoBuyPresetSaveEvent and autoBuyPresetSaveEvent:IsA("RemoteEvent") then
	autoBuyPresetSaveEvent.OnServerEvent:Connect(function(player, presetIndex, payload)
		if not player then
			return
		end

		local success, result = AutomationService.SavePreset(player, presetIndex, payload)
		if not success then
			if result == "locked_preset" then
				if autoBuyPresetUnlockPromptEvent then
					autoBuyPresetUnlockPromptEvent:FireClient(player)
				end
			else
				sendAutoBuyPresetState(player)
			end
		end
	end)
end

if autoBuyAutoSwitchSettingsEvent and autoBuyAutoSwitchSettingsEvent:IsA("RemoteEvent") then
	autoBuyAutoSwitchSettingsEvent.OnServerEvent:Connect(function(player, enabled, presetIndex)
		if not player then
			return
		end

		AutomationService.SetAutoSwitchSettings(player, enabled, presetIndex)
	end)
end

if setAutoBuyEvent and setAutoBuyEvent:IsA("RemoteEvent") then
	setAutoBuyEvent.OnServerEvent:Connect(function(player, payload)
		if not player or typeof(payload) ~= "table" then
			return
		end

		local branch = payload.upgradeType or payload.branch
		local enabled = payload.enabled == true
		local success = AutomationService.SetAutoBuyBranch(player, branch, enabled)
		if success then
			sendAutoBuyState(player)
		end
	end)
end

if getGlobalStatsFunction and getGlobalStatsFunction:IsA("RemoteFunction") then
	getGlobalStatsFunction.OnServerInvoke = function()
		local result = buildGlobalStatsPayload()
		if typeof(result) == "table" then
			return result
		end
		return {}
	end
end

local function onPlayerRemoving(player)
	local info = sessionInfo[player]
	if info and info.lastOfflineEarnings then
		local sessionDuration = 0
		if typeof(info.joinTime) == "number" then
			sessionDuration = math.max(0, os.time() - info.joinTime)
		end

		AnalyticsLogger.LogOfflineSession(
			player,
			info.lastOfflineEarnings.total,
			info.lastOfflineEarnings.hadBoosts,
			info.lastOfflineEarnings.prestige,
			info.lastOfflineEarnings.timeAway,
			sessionDuration
		)
	end

	removePlayer(player)
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	addPlayer(player)
end

AutomationService.Init()
LeaderboardService.Init()
setupWeeklyWinnerAnnouncements()
TitleDisplayService.Init()
startProductionLoop()
startSessionBonusLoop()
startGlobalStatsLoop()
GlobalAnnouncementService.Init(globalAnnouncementEvent)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayerWithStatus(player, true)
		PlayerDataService.Release(player)
	end
	GlobalStatsService.Save()
end)
