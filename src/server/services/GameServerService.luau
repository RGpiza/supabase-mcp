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
local requestPrestigeState = ensureRemote("RemoteFunction", "GetPrestigeState")
local requestPrestigeNode = ensureRemote("RemoteFunction", "PurchasePrestigeNode")
local requestPrestigePurchase = ensureRemote("RemoteFunction", "RequestPrestigePurchase")
local requestLeaderboard = ensureRemote("RemoteFunction", "RequestLeaderboard")
local saveStatusEvent = ensureRemote("RemoteEvent", "SaveStatus")
local clientUxEvent = ensureRemote("RemoteEvent", "ClientUXEvent")
local requestGlobalLikeState = ensureRemote("RemoteFunction", "GetGlobalLikeState")
local requestLikeClaim = ensureRemote("RemoteFunction", "ClaimLikeReward")
local requestFavoriteReward = ensureRemote("RemoteFunction", "RequestFavoriteReward")
local requestCommunityState = ensureRemote("RemoteFunction", "GetCommunityState")
local requestCommunityLikeClaim = ensureRemote("RemoteFunction", "ClaimLikeMilestone")
local requestCommunityFavoriteClaim = ensureRemote("RemoteFunction", "ClaimFavoriteReward")
local communityStateUpdated = ensureRemote("RemoteEvent", "CommunityStateUpdated")
local requestSocialGoalsState = ensureRemote("RemoteFunction", "GetSocialGoalsState")
local requestSocialGoalClaim = ensureRemote("RemoteFunction", "ClaimMilestone")
local requestSocialForceRefresh = ensureRemote("RemoteFunction", "ForceSocialRefresh")
local socialGoalsUpdated = ensureRemote("RemoteEvent", "SocialGoalsStateUpdated")

local PlayerDataService = require(script.Parent.PlayerDataService)
local ProductionService = require(script.Parent.ProductionService)
local UpgradeService = require(script.Parent.UpgradeService)
local PrestigeService = require(script.Parent.PrestigeService)
local PrestigeNodeService = require(script.Parent.PrestigeNodeService)
local PrestigeConfig = require(ReplicatedStorage.Shared.PrestigeConfig)
local PrestigePointsService = require(script.Parent.PrestigePointsService)
local AnalyticsTrackerService = require(script.Parent.AnalyticsTrackerService)
local GlobalLikeGoalService = require(script.Parent.GlobalLikeGoalService)
local FavoriteRewardService = require(script.Parent.FavoriteRewardService)
local SocialGoalsService = require(script.Parent.SocialGoalsService)
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
local savingFlags = {}
local autoUpgradeFlags = {}

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

	savingFlags[player] = true
	local success = PlayerDataService.Save(player)
	savingFlags[player] = nil

	if saveStatusEvent then
		if success then
			saveStatusEvent:FireClient(player, "saved")
		else
			saveStatusEvent:FireClient(player, "offline")
		end
	end

	return success
end

local function runAutoUpgrades(player)
	if autoUpgradeFlags[player] then
		return
	end
	autoUpgradeFlags[player] = true

	task.spawn(function()
		while autoUpgradeFlags[player] do
			local data = PlayerDataService.Get(player)
			local tickMs = PrestigeConfig.AUTOMATION_TICK_MS_DEFAULT
			if typeof(data) == "table" and typeof(data.automation) == "table" then
				if typeof(data.automation.tickMs) == "number" then
					tickMs = data.automation.tickMs
				end
			end
			local autoSpeedLevel = 0
			if typeof(data) == "table" then
				autoSpeedLevel = PrestigePointsService.GetUpgradeLevel(data, "pp_auto_speed_1")
			end
			local autoSpeedMult = math.clamp(1 - (autoSpeedLevel * 0.05), 0.5, 1)
			local autoMul = 0
			if typeof(data) == "table" and typeof(data.automationMultiplier) == "number" then
				autoMul = data.automationMultiplier
			end
			local effectiveTick = tickMs * math.clamp(1 - autoMul, 0.4, 1) * autoSpeedMult
			task.wait(math.max(effectiveTick / 1000, 0.25))
			if not autoUpgradeFlags[player] then
				break
			end
			if not player or not player.Parent then
				autoUpgradeFlags[player] = nil
				break
			end
			data = PlayerDataService.Get(player)
			if typeof(data) ~= "table" then
				continue
			end
			local automation = typeof(data.automation) == "table" and data.automation or {}
			local unlocks = typeof(data.unlocks) == "table" and data.unlocks or {}
			local bypassLevel = PrestigePointsService.GetUpgradeLevel(data, "pp_auto_bypass_1")
			if automation.enabled == false and bypassLevel <= 0 then
				continue
			end
			if bypassLevel > 0 or unlocks.auto_cpu_1 or automation.cpuAuto then
				UpgradeService.AutoBuyBest(player, "CPU")
			end
			if bypassLevel > 0 or unlocks.auto_ram_1 or automation.ramAuto then
				UpgradeService.AutoBuyBest(player, "RAM")
			end
			if bypassLevel > 0 or unlocks.auto_sto_1 or automation.stoAuto then
				UpgradeService.AutoBuyBest(player, "STORAGE")
			end
		end
	end)
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
	runAutoUpgrades(player)
	AnalyticsTrackerService.OnPlayerAdded(player)
	if data and typeof(data) == "table" then
		LeaderboardService.EnsurePlayerEntry(player, data.data or 0)
	else
		LeaderboardService.EnsurePlayerEntry(player, 0)
	end
end

local function removePlayer(player)
	activePlayers[player] = nil
	stopAutosave(player)
	autoUpgradeFlags[player] = nil
	AnalyticsTrackerService.OnPlayerRemoving(player)
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
	playerData.peakData = math.max((playerData.peakData or 0), playerData.data or 0)
	playerData.dataEarnedThisRun = math.floor(math.max((playerData.dataEarnedThisRun or 0) + added, 0))
	PlayerDataService.Set(player, playerData)
	if playerData.data > 0 then
		AnalyticsTrackerService.TrackFirstData(player)
	end
	AnalyticsTrackerService.AccumulateData(player, added, playerData.data, {
		source = "Production",
		boostActive = MonetizationService.IsBoostActive(playerData),
		prestigeLevel = playerData.prestige or 0,
	})

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
		peakData = data.peakData,
		dataEarnedThisRun = data.dataEarnedThisRun,
		upgrades = data.upgrades,
		prestige = data.prestige,
		prestigePoints = data.prestigePoints,
		ppSpent = data.ppSpent,
		unlocks = data.unlocks,
		automation = data.automation,
		prestigeUpgrades = data.prestigeUpgrades,
		prestigePointsNext = PrestigeService.CalculatePrestigePointsGain(data),
		prestigeNextAt = PrestigeService.CalculateNextPrestigeThreshold(data),
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

requestPrestigeState.OnServerInvoke = function(player)
	if not player then
		return nil
	end
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end
	local state = PrestigeNodeService.GetState(player)
	if not state then
		return nil
	end
	state.prestigePointsNext = PrestigeService.CalculatePrestigePointsGain(data)
	state.prestigeNextAt = PrestigeService.CalculateNextPrestigeThreshold(data)
	return state
end

requestPrestigeNode.OnServerInvoke = function(player, nodeId)
	if not player then
		return nil
	end
	if savingFlags[player] or PrestigeService.IsPrestiging(player) then
		return nil
	end
	local ok = PrestigeNodeService.Purchase(player, nodeId)
	if not ok then
		return nil
	end
	return PrestigeNodeService.GetState(player)
end

requestPrestigePurchase.OnServerInvoke = function(player, upgradeId)
	if not player then
		return nil
	end
	if savingFlags[player] or PrestigeService.IsPrestiging(player) then
		return nil
	end
	local ok = PrestigePointsService.Purchase(player, upgradeId)
	if not ok then
		return nil
	end
	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end
	return {
		prestigePoints = data.prestigePoints,
		prestigeUpgrades = data.prestigeUpgrades,
	}
end

requestGlobalLikeState.OnServerInvoke = function(player)
	if not player then
		return nil
	end
	return GlobalLikeGoalService.GetState(player)
end

requestLikeClaim.OnServerInvoke = function(player, milestoneId)
	if not player then
		return nil
	end
	local ok = GlobalLikeGoalService.Claim(player, milestoneId)
	if not ok then
		return nil
	end
	return GlobalLikeGoalService.GetState(player)
end

requestFavoriteReward.OnServerInvoke = function(player)
	if not player then
		return nil
	end
	local ok = FavoriteRewardService.Claim(player)
	if not ok then
		return nil
	end
	return FavoriteRewardService.GetState(player)
end

local function buildCommunityState(player)
	local likeState = GlobalLikeGoalService.GetState(player) or {}
	local favoriteState = FavoriteRewardService.GetState(player) or {}
	return {
		likes = likeState.globalLikes,
		milestones = likeState.milestones or {},
		favorite = favoriteState,
	}
end

requestCommunityState.OnServerInvoke = function(player)
	if not player then
		return nil
	end
	return buildCommunityState(player)
end

requestCommunityLikeClaim.OnServerInvoke = function(player, milestoneId)
	if not player then
		return nil
	end
	local ok = GlobalLikeGoalService.Claim(player, milestoneId)
	if not ok then
		return nil
	end
	local state = buildCommunityState(player)
	if communityStateUpdated then
		communityStateUpdated:FireClient(player, state)
	end
	return state
end

requestCommunityFavoriteClaim.OnServerInvoke = function(player)
	if not player then
		return nil
	end
	local ok = FavoriteRewardService.Claim(player)
	if not ok then
		return nil
	end
	local state = buildCommunityState(player)
	if communityStateUpdated then
		communityStateUpdated:FireClient(player, state)
	end
	return state
end

local function buildSocialGoalsState(player)
	local state = SocialGoalsService.GetState(player)
	local favorite = FavoriteRewardService.GetState(player)
	if typeof(state) == "table" then
		state.favorite = favorite
	end
	return state
end

requestSocialGoalsState.OnServerInvoke = function(player)
	if not player then
		return nil
	end
	return buildSocialGoalsState(player)
end

requestSocialGoalClaim.OnServerInvoke = function(player, mode)
	if not player then
		return nil
	end
	local ok = SocialGoalsService.Claim(player, mode)
	if not ok then
		return nil
	end
	local state = buildSocialGoalsState(player)
	if socialGoalsUpdated then
		socialGoalsUpdated:FireClient(player, state)
	end
	return state
end

requestSocialForceRefresh.OnServerInvoke = function(player)
	if not player then
		return nil
	end
	local ok = SocialGoalsService.ForceRefresh(player)
	if not ok then
		return nil
	end
	return true
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

clientUxEvent.OnServerEvent:Connect(function(player, payload)
	if not player or typeof(payload) ~= "table" then
		return
	end
	local eventType = payload.type
	if eventType == "TabOpened" then
		local tab = tostring(payload.tab or "")
		if tab ~= "Stats" and tab ~= "Leaderboards" and tab ~= "Prestige" then
			return
		end
		if not AnalyticsTrackerService.DebouncedTabEvent(player, tab) then
			return
		end
		AnalyticsTrackerService.LogCustomCounter(player, "TabOpened", { tab = tab })
		if tab == "Prestige" then
			AnalyticsTrackerService.TrackPrestigeTabOpened(player)
			local sessionId = AnalyticsTrackerService.GetOrStartFunnel(player, "PrestigeTreePurchase")
			if sessionId then
				AnalyticsTrackerService.LogFunnelStep(player, "PrestigeTreePurchase", sessionId, 1, "Opened Prestige Tab")
			end
		elseif tab == "Leaderboards" then
			AnalyticsTrackerService.LogCustomCounter(player, "LeaderboardViewed")
		end
	elseif eventType == "StoreOpened" then
		local sessionId = AnalyticsTrackerService.StartFunnelSession(player, "StoreCheckout")
		if sessionId then
			AnalyticsTrackerService.LogFunnelStep(player, "StoreCheckout", sessionId, 1, "Opened Store", {
				placement = tostring(payload.placement or "Unknown"),
			})
		end
	elseif eventType == "StorePurchaseClicked" then
		local sessionId = AnalyticsTrackerService.GetOrStartFunnel(player, "StoreCheckout")
		if sessionId then
			AnalyticsTrackerService.LogFunnelStep(player, "StoreCheckout", sessionId, 3, "Clicked Purchase", {
				itemSKU = tostring(payload.itemSKU or "Unknown"),
			})
		end
	elseif eventType == "PrestigeNodeSelected" then
		local nodeId = tostring(payload.nodeId or "")
		if nodeId == "" then
			return
		end
		local sessionId = AnalyticsTrackerService.GetOrStartFunnel(player, "PrestigeTreePurchase")
		if sessionId then
			AnalyticsTrackerService.LogFunnelStep(player, "PrestigeTreePurchase", sessionId, 2, "Selected Node", {
				itemSKU = nodeId,
			})
		end
	end
end)

buyUpgradeEvent.OnServerEvent:Connect(function(player, upgradeId, count)
	if not player then
		return
	end

	UpgradeService.Buy(player, upgradeId, count)
end)

prestigeEvent.OnServerEvent:Connect(function(player)
	if not player then
		return
	end

	if savingFlags[player] or PrestigeService.IsPrestiging(player) then
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
SocialGoalsService.Start()

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
