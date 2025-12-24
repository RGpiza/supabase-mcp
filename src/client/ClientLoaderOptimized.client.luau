-- System Incremental UI Integration
-- Replaces the controller-based approach with a single-file UI implementation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Import SystemIncrementalUI
local SystemIncrementalUI = require(script.Parent.SystemIncrementalUI)

-- Import other controllers for compatibility
local function loadController(name)
	local ok, controller = pcall(function()
		return require(script.Parent.controllers[name])
	end)
	if ok and controller then
		return controller
	else
		warn("Failed to load controller:", name)
		return nil
	end
end

-- Initialize controllers
local function initializeControllers()
	-- Core controllers
	local terminalController = loadController("TerminalController")
	local antiCheatClient = loadController("AntiCheatClient")
	
	-- UI shell controllers
	local upgradeController = loadController("UpgradeController")
	local communityController = loadController("CommunityController")
	
	-- Lazy-loaded features
	local prestigeUpgradesController = loadController("PrestigeUpgradesController")
	local storeUIController = loadController("StoreUIController")
	local testController = loadController("TestController")
	
	-- Initialize controllers
	if terminalController then
		pcall(terminalController.OnStart)
	end
	
	if antiCheatClient then
		pcall(antiCheatClient.OnStart)
	end
	
	if upgradeController then
		pcall(upgradeController.OnStart)
	end
	
	if communityController then
		pcall(communityController.OnStart)
	end
	
	if prestigeUpgradesController then
		pcall(prestigeUpgradesController.OnStart)
	end
	
	if storeUIController then
		pcall(storeUIController.OnStart)
	end
	
	if testController then
		pcall(testController.OnStart)
	end
end

-- Main initialization
local function initialize()
	print("[ClientLoader] Starting System Incremental UI integration")
	
	-- Initialize the new single-file UI
	local uiResult = SystemIncrementalUI.buildUI()
	if uiResult then
		print("[ClientLoader] SystemIncrementalUI loaded successfully")
	else
		warn("[ClientLoader] Failed to load SystemIncrementalUI")
	end
	
	-- Initialize remaining controllers for compatibility
	initializeControllers()
	
	print("[ClientLoader] Initialization complete")
end

-- Start initialization
spawn(function()
	-- Wait for PlayerGui to be ready
	repeat
		task.wait()
	until playerGui and playerGui.Parent
	
	initialize()
end)

return {
	notify = SystemIncrementalUI.notify,
	refreshLeaderboard = SystemIncrementalUI.refreshLeaderboard,
	refreshCommunity = SystemIncrementalUI.refreshCommunity,
}
