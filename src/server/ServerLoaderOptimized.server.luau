local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import the InitManager
local InitManager = require(ReplicatedStorage.Shared.utils.InitManager)

-- Configure InitManager for server
InitManager.definePhase("core", {})
InitManager.definePhase("ui_shell", {"core"})
InitManager.definePhase("features", {"ui_shell"})

-- Register core services
InitManager.registerService("PlayerDataService", function()
	local PlayerDataService = require(script.Parent.services.PlayerDataService)
	return PlayerDataService
end, "core")

InitManager.registerService("ProductionService", function()
	local ProductionService = require(script.Parent.services.ProductionService)
	return ProductionService
end, "core")

InitManager.registerService("UpgradeService", function()
	local UpgradeService = require(script.Parent.services.UpgradeService)
	return UpgradeService
end, "core")

InitManager.registerService("PrestigeService", function()
	local PrestigeService = require(script.Parent.services.PrestigeService)
	return PrestigeService
end, "core")

InitManager.registerService("PrestigePointsService", function()
	local PrestigePointsService = require(script.Parent.services.PrestigePointsService)
	return PrestigePointsService
end, "core")

InitManager.registerService("PrestigeNodeService", function()
	local PrestigeNodeService = require(script.Parent.services.PrestigeNodeService)
	return PrestigeNodeService
end, "core")

InitManager.registerService("AnalyticsTrackerService", function()
	local AnalyticsTrackerService = require(script.Parent.services.AnalyticsTrackerService)
	return AnalyticsTrackerService
end, "core")

InitManager.registerService("MonetizationService", function()
	local MonetizationService = require(script.Parent.services.MonetizationService)
	return MonetizationService
end, "core")

InitManager.registerService("LeaderboardService", function()
	local LeaderboardService = require(script.Parent.services.LeaderboardService)
	return LeaderboardService
end, "core")

InitManager.registerService("SocialGoalsService", function()
	local SocialGoalsService = require(script.Parent.services.SocialGoalsService)
	return SocialGoalsService
end, "core")

InitManager.registerService("GameServerService", function()
	local GameServerService = require(script.Parent.services.GameServerService)
	return GameServerService
end, "core")

InitManager.registerService("GlobalLikeGoalService", function()
	local GlobalLikeGoalService = require(script.Parent.services.GlobalLikeGoalService)
	return GlobalLikeGoalService
end, "core")

InitManager.registerService("FavoriteRewardService", function()
	local FavoriteRewardService = require(script.Parent.services.FavoriteRewardService)
	return FavoriteRewardService
end, "core")

-- Register anti-cheat services
InitManager.registerService("AntiCheatService", function()
	local AntiCheatService = require(script.Parent.services.AntiCheatService)
	return AntiCheatService
end, "core")

InitManager.registerService("RemoteRouter", function()
	local RemoteRouter = require(script.Parent.services.RemoteRouter)
	return RemoteRouter
end, "core")

-- Register lazy-loaded features

-- Start initialization
local success = InitManager.initialize()
if success then
	print("[ServerLoader] Initialization complete")
else
	warn("[ServerLoader] Initialization failed")
end

return InitManager
