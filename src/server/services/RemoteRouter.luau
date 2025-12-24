local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local AntiCheatService = require(script.Parent.AntiCheatService)
local UpgradeService = require(script.Parent.UpgradeService)
local PrestigeService = require(script.Parent.PrestigeService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local StoreService = require(script.Parent.MonetizationService)
local SocialGoalsService = require(script.Parent.SocialGoalsService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProductionFeedbackService = require(script.Parent.ProductionFeedbackService)
local DebugConfig = nil

do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.utils:FindFirstChild("DebugConfig"))
	end)
	if ok and type(mod) == "table" then
		DebugConfig = mod
	end
end

local RemoteRouter = {}

-- Remote event/function definitions
local Remotes = {}

-- Configuration
local CONFIG = {
	DEBUG = false,
	ENABLE_ANTI_CHEAT = true,
}

-- Utility functions
local function log(level, message, ...)
	if CONFIG.DEBUG and DebugConfig then
		if level == "error" then
			DebugConfig.Error(message, ...)
		elseif level == "warn" then
			DebugConfig.Warn(message, ...)
		else
			DebugConfig.Log(message, ...)
		end
	end
end

local function createRemote(name, isEvent)
	local remote
	if isEvent then
		remote = Instance.new("RemoteEvent")
	else
		remote = Instance.new("RemoteFunction")
	end
	remote.Name = name
	remote.Parent = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
	return remote
end

-- Anti-cheat integration wrapper
local function withAntiCheat(player, remoteName, payload, callback)
	if not CONFIG.ENABLE_ANTI_CHEAT then
		return callback()
	end
	
	-- Generate session nonce for new players
	local state = AntiCheatService.GetPlayerState(player.UserId)
	local sessionNonce = state and state.sessionNonce or HttpService:GenerateGUID(false)
	
	local success, reason = AntiCheatService.Check(player, remoteName, payload, sessionNonce)
	if not success then
		log("warn", "Anti-cheat blocked request", player.UserId, remoteName, reason)
		return false, AntiCheatService.GetReasonText(reason), sessionNonce
	end
	
	return callback()
end

-- Remote handlers
local function handleBuyUpgrade(player, payload)
	return withAntiCheat(player, "BuyUpgrade", payload, function()
		local upgradeId = payload.upgradeId
		local count = payload.count or 1
		
		local success, newState = UpgradeService.Buy(player, upgradeId, count)
		if success then
			-- Audit economy after successful transaction
			local playerData = PlayerDataService.Get(player)
			AntiCheatService.AuditPlayer(player.UserId, playerData)
			
			return true, newState, HttpService:GenerateGUID(false)
		else
			return false, "Purchase failed", HttpService:GenerateGUID(false)
		end
	end)
end

local function handleAutoBuyBest(player, payload)
	return withAntiCheat(player, "AutoBuyBest", payload, function()
		local branch = payload.branch
		
		local success, newState = UpgradeService.AutoBuyBest(player, branch)
		if success then
			-- Audit economy after successful transaction
			local playerData = PlayerDataService.Get(player)
			AntiCheatService.AuditPlayer(player.UserId, playerData)
			
			return true, newState, HttpService:GenerateGUID(false)
		else
			return false, "Auto-buy failed", HttpService:GenerateGUID(false)
		end
	end)
end

local function handlePrestige(player, payload)
	return withAntiCheat(player, "Prestige", payload, function()
		local success, newState = PrestigeService.Prestige(player)
		if success then
			-- Audit economy after prestige
			local playerData = PlayerDataService.Get(player)
			AntiCheatService.AuditPlayer(player.UserId, playerData)
			
			return true, newState, HttpService:GenerateGUID(false)
		else
			return false, "Prestige failed", HttpService:GenerateGUID(false)
		end
	end)
end

local function handleFetchLeaderboard(player, payload)
	return withAntiCheat(player, "FetchLeaderboard", payload, function()
		local page = payload.page or 1
		local type = payload.type or "global"
		
		local success, data = pcall(function()
			return LeaderboardService.GetLeaderboard(type, page)
		end)
		
		if success then
			return true, data, HttpService:GenerateGUID(false)
		else
			log("error", "Leaderboard fetch failed", player.UserId, data)
			return false, "Leaderboard unavailable", HttpService:GenerateGUID(false)
		end
	end)
end

local function handleToggleAuto(player, payload)
	return withAntiCheat(player, "ToggleAuto", payload, function()
		-- This is UI preference only - server controls actual automation
		local branch = payload.branch
		local enabled = payload.enabled
		
		-- Store auto preferences in player data
		local playerData = PlayerDataService.Get(player)
		if not playerData.automation then
			playerData.automation = {}
		end
		playerData.automation[branch] = enabled
		PlayerDataService.Set(player, playerData)
		
		return true, { automation = playerData.automation }, HttpService:GenerateGUID(false)
	end)
end

local function handlePurchaseStore(player, payload)
	return withAntiCheat(player, "PurchaseStore", payload, function()
		local itemId = payload.itemId
		local quantity = payload.quantity or 1
		
		local success, result = StoreService.Purchase(player, itemId, quantity)
		if success then
			-- Audit economy after purchase
			local playerData = PlayerDataService.Get(player)
			AntiCheatService.AuditPlayer(player.UserId, playerData)
			
			return true, result, HttpService:GenerateGUID(false)
		else
			return false, "Purchase failed", HttpService:GenerateGUID(false)
		end
	end)
end

local function handleLikeGoal(player, payload)
	return withAntiCheat(player, "LikeGoal", payload, function()
		local goalId = payload.goalId
		
		local success, result = SocialGoalsService.LikeGoal(player, goalId)
		if success then
			return true, result, HttpService:GenerateGUID(false)
		else
			return false, "Like failed", HttpService:GenerateGUID(false)
		end
	end)
end

local function handleRequestSync(player, payload)
	return withAntiCheat(player, "RequestSync", payload, function()
		-- Return current player state
		local playerData = PlayerDataService.Get(player)
		if playerData then
			-- Audit economy on sync
			AntiCheatService.AuditPlayer(player.UserId, playerData)
			
			return true, playerData, HttpService:GenerateGUID(false)
		else
			return false, "No player data", HttpService:GenerateGUID(false)
		end
	end)
end

local function handleRequestPrestigeState(player, payload)
	return withAntiCheat(player, "RequestPrestigeState", payload, function()
		local playerData = PlayerDataService.Get(player)
		if playerData then
			return true, {
				prestigePoints = playerData.prestigePoints or 0,
				prestigeUpgrades = playerData.prestigeUpgrades or {},
			}, HttpService:GenerateGUID(false)
		else
			return false, "No player data", HttpService:GenerateGUID(false)
		end
	end)
end

local function handleRequestPrestigePurchase(player, payload)
	return withAntiCheat(player, "RequestPrestigePurchase", payload, function()
		local upgradeId = payload.upgradeId
		
		local success = PrestigeService.Purchase(player, upgradeId)
		if success then
			local playerData = PlayerDataService.Get(player)
			return true, {
				prestigePoints = playerData.prestigePoints or 0,
				prestigeUpgrades = playerData.prestigeUpgrades or {},
			}, HttpService:GenerateGUID(false)
		else
			return false, "Purchase failed", HttpService:GenerateGUID(false)
		end
	end)
end

-- Initialize remotes
function RemoteRouter.Init()
	log("info", "Initializing RemoteRouter")
	
	-- Create remotes folder
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end
	
	-- Define remotes
	Remotes.BuyUpgrade = createRemote("BuyUpgrade", true)
	Remotes.AutoBuyBest = createRemote("AutoBuyBest", true)
	Remotes.Prestige = createRemote("Prestige", true)
	Remotes.FetchLeaderboard = createRemote("FetchLeaderboard", true)
	Remotes.ToggleAuto = createRemote("ToggleAuto", true)
	Remotes.PurchaseStore = createRemote("PurchaseStore", true)
	Remotes.LikeGoal = createRemote("LikeGoal", true)
	Remotes.RequestSync = createRemote("RequestSync", false)
	Remotes.RequestPrestigeState = createRemote("RequestPrestigeState", false)
	Remotes.RequestPrestigePurchase = createRemote("RequestPrestigePurchase", false)
	
	-- Connect remote handlers
	Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, payload)
		local success, result, sessionNonce = handleBuyUpgrade(player, payload)
		if not success then
			-- Send error to client
			Remotes.BuyUpgrade:FireClient(player, { error = result, sessionNonce = sessionNonce })
		end
	end)
	
	Remotes.AutoBuyBest.OnServerEvent:Connect(function(player, payload)
		local success, result, sessionNonce = handleAutoBuyBest(player, payload)
		if not success then
			Remotes.AutoBuyBest:FireClient(player, { error = result, sessionNonce = sessionNonce })
		end
	end)
	
	Remotes.Prestige.OnServerEvent:Connect(function(player, payload)
		local success, result, sessionNonce = handlePrestige(player, payload)
		if not success then
			Remotes.Prestige:FireClient(player, { error = result, sessionNonce = sessionNonce })
		end
	end)
	
	Remotes.FetchLeaderboard.OnServerEvent:Connect(function(player, payload)
		local success, result, sessionNonce = handleFetchLeaderboard(player, payload)
		if not success then
			Remotes.FetchLeaderboard:FireClient(player, { error = result, sessionNonce = sessionNonce })
		end
	end)
	
	Remotes.ToggleAuto.OnServerEvent:Connect(function(player, payload)
		local success, result, sessionNonce = handleToggleAuto(player, payload)
		if not success then
			Remotes.ToggleAuto:FireClient(player, { error = result, sessionNonce = sessionNonce })
		end
	end)
	
	Remotes.PurchaseStore.OnServerEvent:Connect(function(player, payload)
		local success, result, sessionNonce = handlePurchaseStore(player, payload)
		if not success then
			Remotes.PurchaseStore:FireClient(player, { error = result, sessionNonce = sessionNonce })
		end
	end)
	
	Remotes.LikeGoal.OnServerEvent:Connect(function(player, payload)
		local success, result, sessionNonce = handleLikeGoal(player, payload)
		if not success then
			Remotes.LikeGoal:FireClient(player, { error = result, sessionNonce = sessionNonce })
		end
	end)
	
	-- Remote functions
	Remotes.RequestSync.OnServerInvoke = handleRequestSync
	Remotes.RequestPrestigeState.OnServerInvoke = handleRequestPrestigeState
	Remotes.RequestPrestigePurchase.OnServerInvoke = handleRequestPrestigePurchase
	
	log("info", "RemoteRouter initialized with anti-cheat protection")
end

-- Get remote for external use
function RemoteRouter.GetRemote(name)
	return Remotes[name]
end

-- Admin functions
function RemoteRouter.EnableAntiCheat(enable)
	CONFIG.ENABLE_ANTI_CHEAT = enable
	log("info", "Anti-cheat " .. (enable and "enabled" or "disabled"))
end

function RemoteRouter.ResetPlayerViolations(playerId)
	AntiCheatService.ResetViolations(playerId)
	log("info", "Reset violations for player", playerId)
end

function RemoteRouter.GetPlayerState(playerId)
	return AntiCheatService.GetPlayerState(playerId)
end

-- Initialize service
function RemoteRouter.OnStart()
	RemoteRouter.Init()
end

return RemoteRouter
