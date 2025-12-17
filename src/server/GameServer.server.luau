local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")

local REMOTES_FOLDER_NAME = "Remotes"
local PLAYER_GUI_WAIT_TIME = 5
local PRESTIGE_OFFLINE_STEP = 0.1

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder or not remotesFolder:IsA("Folder") then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = REMOTES_FOLDER_NAME
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
local requestPrestigePreview = ensureRemote("RemoteFunction", "RequestPrestigePreview")
local saveStatusEvent = ensureRemote("RemoteEvent", "SaveStatus")
local storeAnalyticsEvent = ensureRemote("RemoteEvent", "StoreAnalyticsEvent")
local offlinePreviewEvent = ensureRemote("RemoteEvent", "OfflineEarningsPreview")
local loadingProgressEvent = ensureRemote("RemoteEvent", "LoadingProgress")
local prestigePreviewEvent = ensureRemote("RemoteEvent", "PrestigePreviewUpdate")
local sessionBonusEvent = ensureRemote("RemoteEvent", "SessionBonusUpdate")
local globalAnnouncementEvent = ensureRemote("RemoteEvent", "GlobalAnnouncement")
local globalStatsEvent = ensureRemote("RemoteEvent", "GlobalStatsUpdate")
local serverPowerEvent = ensureRemote("RemoteEvent", "ServerPowerUpdate")
local systemNotificationEvent = ensureRemote("RemoteEvent", "SystemNotification")
local autoBuyPresetApplyEvent = ensureRemote("RemoteEvent", "AutoBuyPresetApply")
local autoBuyPresetSaveEvent = ensureRemote("RemoteEvent", "AutoBuyPresetSave")
local autoBuyPresetStateEvent = ensureRemote("RemoteEvent", "AutoBuyPresetState")
local requestAutoBuyPresets = ensureRemote("RemoteFunction", "RequestAutoBuyPresets")

local PlayerDataService = require(script.Parent.PlayerDataService)
local ProductionService = require(script.Parent.ProductionService)
local UpgradeService = require(script.Parent.UpgradeService)
local PrestigeService = require(script.Parent.PrestigeService)
local SessionRewardService = require(script.Parent.SessionRewardService)
local GlobalAnnouncementService = require(script.Parent.GlobalAnnouncementService)
local GlobalStatsService = require(script.Parent.GlobalStatsService)
local EconomyAnalytics = require(script.Parent.EconomyAnalytics)
local OfflineProgress = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("OfflineProgress"))
local AnalyticsLogger = require(script.Parent.AnalyticsLogger)
local AutomationService = require(script.Parent.AutomationService)

local activePlayers = {}
local productionLoopStarted = false
local productionConnection
local autosaveFlags = {}
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

local AUTOSAVE_INTERVAL = 60

local sendSessionBonusUpdate
local sendGlobalStats
local sendServerPowerUpdate
local sendSystemNotification

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

	local baseProduction = ProductionService.GetBaseDataPerSecond(player)
	if typeof(baseProduction) ~= "number" or baseProduction <= 0 then
		playerData.lastSeen = os.time()
		PlayerDataService.Set(player, playerData)
		return
	end

	local now = os.time()
	local lastSeen = typeof(playerData.lastSeen) == "number" and math.max(playerData.lastSeen, 0) or now
	local timeAway = math.max(0, now - lastSeen)
	local gain, _, hadOfflineBoosts, baseAmount, boostedAmount = OfflineProgress.Calculate(playerData, baseProduction, now)
	local prestigeLevel = typeof(playerData.prestige) == "number" and math.max(playerData.prestige, 0) or 0
	local prestigeMultiplier = 1 + (prestigeLevel * PRESTIGE_OFFLINE_STEP)

	local totalGain = gain * prestigeMultiplier
	local totalBase = baseAmount * prestigeMultiplier
	local totalBoosted = boostedAmount * prestigeMultiplier

	if totalGain > 0 then
		sessionInfo[player] = sessionInfo[player] or {}
		sessionInfo[player].lastOfflineEarnings = {
			total = totalGain,
			hadBoosts = hadOfflineBoosts == true,
			prestige = prestigeLevel,
			timeAway = timeAway,
		}
	end

	if totalGain > 0 then
		playerData.data = math.max(0, (playerData.data or 0) + totalGain)
	end

	PlayerDataService.Set(player, playerData)

	if totalGain > 0 then
		EconomyAnalytics.LogSource(
			player,
			totalGain,
			playerData.data,
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

	local payload = AutomationService.GetPresetState(player)
	if payload then
		autoBuyPresetStateEvent:FireClient(player, payload)
	end
end

AutomationService.OnPresetStateChanged(function(player)
	sendAutoBuyPresetState(player)
end)

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
	startAutosave(player)
	sendPrestigePreview(player, true)
	sendSessionBonusUpdate(player)
	sendGlobalStats(player)
	sendServerPowerUpdate()
	sendSystemNotification("➕ Player joined the system")

	fireLoadingProgress(player, "Finalizing", 1)
end

local function removePlayer(player)
	activePlayers[player] = nil
	stopAutosave(player)
	savePlayerWithStatus(player)
	PlayerDataService.Release(player)
	storeStateByPlayer[player] = nil
	storePlatformByPlayer[player] = nil
	offlinePreviewSent[player] = nil
	sessionInfo[player] = nil
	prestigePreviewState[player] = nil
	pendingPrestigePreviews[player] = nil
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
	playerData.data = math.max((playerData.data or 0) + added, 0)
	PlayerDataService.Set(player, playerData)

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

sendGlobalStats = function(player)
	if not globalStatsEvent then
		return
	end

	local stats = GlobalStatsService.GetStats()
	local payload = {
		totalData = stats.totalDataGenerated or 0,
		totalPrestiges = stats.totalPrestiges or 0,
	}

	if player then
		globalStatsEvent:FireClient(player, payload)
	else
		globalStatsEvent:FireAllClients(payload)
	end
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

requestPrestigePreview.OnServerInvoke = function(player)
	return PrestigeService.GetPreview(player)
end

if requestAutoBuyPresets then
	requestAutoBuyPresets.OnServerInvoke = function(player)
		return AutomationService.GetPresetState(player)
	end
end

if autoBuyPresetApplyEvent then
	autoBuyPresetApplyEvent.OnServerEvent:Connect(function(player, presetIndex)
		if not player then
			return
		end

		local success = AutomationService.ApplyPreset(player, presetIndex)
		if not success then
			sendAutoBuyPresetState(player)
		end
	end)
end

if autoBuyPresetSaveEvent then
	autoBuyPresetSaveEvent.OnServerEvent:Connect(function(player, presetIndex, payload)
		if not player then
			return
		end

		local success = AutomationService.SavePreset(player, presetIndex, payload)
		if not success then
			sendAutoBuyPresetState(player)
		end
	end)
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
startProductionLoop()
startSessionBonusLoop()
startGlobalStatsLoop()
GlobalAnnouncementService.Init(globalAnnouncementEvent)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayerWithStatus(player)
		PlayerDataService.Release(player)
	end
	GlobalStatsService.Save()
end)

