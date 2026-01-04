-- ClientLoader.client.lua
-- Optimized client-side loader for System Incremental UI
-- Handles module loading and fallback logic efficiently

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
	screenGuiName = "TerminalUI",
	rootFrameName = "Root",
	backgroundColor = Color3.fromRGB(15, 17, 21),
	borderColor = Color3.fromRGB(42, 48, 64),
	textColor = Color3.fromRGB(230, 230, 230),
}

-- State management
local state = {
	isInitialized = false,
	notificationQueue = {},
}

-- UI Elements storage
local UI = {}

-- Utility functions
local function createFrame(name, parent, size, position, backgroundColor, borderSize, borderColor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = backgroundColor or CONFIG.backgroundColor
	frame.BorderSizePixel = borderSize or 1
	frame.BorderColor3 = borderColor or CONFIG.borderColor
	frame.Parent = parent
	return frame
end

local function createTextLabel(name, parent, text, size, position, textColor, textSize, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = textSize or 16
	label.TextColor3 = textColor or CONFIG.textColor
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.TextXAlignment = alignment and alignment.x or Enum.TextXAlignment.Left
	label.TextYAlignment = alignment and alignment.y or Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

-- Create immediate fallback UI
local function createImmediateFallbackUI()
	if not playerGui then
		warn("[ClientLoader] PlayerGui not available for immediate UI creation")
		return false
	end
	
	-- Check if UI already exists
	if playerGui:FindFirstChild(CONFIG.screenGuiName) then
		return true
	end
	
	-- Create ScreenGui immediately
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = CONFIG.screenGuiName
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	-- Create Root Frame immediately
	local rootFrame = createFrame(CONFIG.rootFrameName, screenGui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
	
	-- Create Title Label immediately
	local titleLabel = createTextLabel("TitleLabel", rootFrame, "System Incremental UI Loaded (Immediate Fallback)", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), CONFIG.textColor, 20, {x = Enum.TextXAlignment.Center, y = Enum.TextYAlignment.Center})
	
	print("[ClientLoader] Created immediate UI fallback")
	return true
end

-- Create fallback SystemIncrementalUI module
local function createFallbackSystemIncrementalUI()
	print("[ClientLoader] Creating fallback SystemIncrementalUI module")
	local fallbackUI = {}
	
	function fallbackUI.buildUI(player)
		if not player or not player:IsA("Player") then
			return false
		end
		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			return false
		end
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "TerminalUI"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = playerGui
		local rootFrame = Instance.new("Frame")
		rootFrame.Name = "Root"
		rootFrame.Size = UDim2.new(1, 0, 1, 0)
		rootFrame.Position = UDim2.new(0, 0, 0, 0)
		rootFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 21)
		rootFrame.BorderSizePixel = 1
		rootFrame.BorderColor3 = Color3.fromRGB(42, 48, 64)
		rootFrame.Parent = screenGui
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "TitleLabel"
		titleLabel.Text = "System Incremental UI Loaded (Fallback)"
		titleLabel.Font = Enum.Font.GothamSemibold
		titleLabel.TextSize = 20
		titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Size = UDim2.new(1, 0, 0, 40)
		titleLabel.Position = UDim2.new(0, 0, 0, 0)
		titleLabel.TextYAlignment = Enum.TextYAlignment.Center
		titleLabel.TextXAlignment = Enum.TextXAlignment.Center
		titleLabel.Parent = rootFrame
		return true
	end
	
	function fallbackUI.notify(message, kind)
		print("[ClientLoader] Fallback notify:", tostring(message))
	end
	
	function fallbackUI.refreshLeaderboard()
		print("[ClientLoader] Fallback refreshLeaderboard")
	end
	
	function fallbackUI.refreshCommunity()
		print("[ClientLoader] Fallback refreshCommunity")
	end
	
	return fallbackUI
end

-- Load SystemIncrementalUI module
local SystemIncrementalUI = nil

-- Try to load the real SystemIncrementalUI module
local function loadSystemIncrementalUI()
	local success, result = pcall(function()
		return require(ReplicatedStorage.Shared.SystemIncrementalUI)
	end)
	
	if success then
		SystemIncrementalUI = result
		print("[ClientLoader] SystemIncrementalUI loaded successfully from ReplicatedStorage")
		return true
	else
		warn("[ClientLoader] Failed to load SystemIncrementalUI from ReplicatedStorage:", result)
		return false
	end
end

-- Try to load SingleFileGUI as alternative
local function loadSingleFileGUI()
	local success, result = pcall(function()
		return require(script.Parent.SingleFileGUI)
	end)
	
	if success then
		SystemIncrementalUI = result
		print("[ClientLoader] SingleFileGUI loaded successfully")
		return true
	else
		warn("[ClientLoader] Failed to load SingleFileGUI:", result)
		return false
	end
end

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
	print("[ClientLoader] Initializing controllers...")
	
	-- Core controllers
	local terminalController = loadController("TerminalController")
	local antiCheatClient = loadController("AntiCheatClient")
	
	-- UI shell controllers
	local upgradeController = loadController("UpgradeController")
	local communityController = loadController("CommunityController")
	
	-- Lazy-loaded features
	local prestigeUpgradesController = loadController("PrestigeUpgradesController")
	local storeUIController = loadController("StoreUIController")
	
	-- Initialize controllers
	if terminalController then
		pcall(terminalController.OnStart)
		print("[ClientLoader] TerminalController initialized")
	else
		print("[ClientLoader] TerminalController failed to load")
	end
	
	if antiCheatClient then
		pcall(antiCheatClient.OnStart)
		print("[ClientLoader] AntiCheatClient initialized")
	else
		print("[ClientLoader] AntiCheatClient failed to load")
	end
	
	if upgradeController then
		pcall(upgradeController.OnStart)
		print("[ClientLoader] UpgradeController initialized")
	else
		print("[ClientLoader] UpgradeController failed to load")
	end
	
	if communityController then
		pcall(communityController.OnStart)
		print("[ClientLoader] CommunityController initialized")
	else
		print("[ClientLoader] CommunityController failed to load")
	end
	
	if prestigeUpgradesController then
		pcall(prestigeUpgradesController.OnStart)
		print("[ClientLoader] PrestigeUpgradesController initialized")
	else
		print("[ClientLoader] PrestigeUpgradesController failed to load")
	end
	
	if storeUIController then
		pcall(storeUIController.OnStart)
		print("[ClientLoader] StoreUIController initialized")
	else
		print("[ClientLoader] StoreUIController failed to load")
	end
end

-- Main initialization
local function initialize()
	print("[ClientLoader] Starting System Incremental UI integration")
	
	-- Create immediate fallback UI to ensure something is available
	createImmediateFallbackUI()
	
	-- Try to load the real UI system
	local uiLoaded = false
	
	-- Try SystemIncrementalUI first
	if not uiLoaded then
		uiLoaded = loadSystemIncrementalUI()
	end
	
	-- Try SingleFileGUI as alternative
	if not uiLoaded then
		uiLoaded = loadSingleFileGUI()
	end
	
	-- If still no UI, create fallback
	if not uiLoaded then
		SystemIncrementalUI = createFallbackSystemIncrementalUI()
		print("[ClientLoader] Created fallback SystemIncrementalUI module")
	end
	
	-- Ensure SystemIncrementalUI has all required methods
	if SystemIncrementalUI then
		-- Ensure all methods exist
		if not SystemIncrementalUI.notify then
			SystemIncrementalUI.notify = function(message, kind)
				print("[ClientLoader] Fallback notify:", tostring(message))
			end
		end
		if not SystemIncrementalUI.refreshLeaderboard then
			SystemIncrementalUI.refreshLeaderboard = function()
				print("[ClientLoader] Fallback refreshLeaderboard")
			end
		end
		if not SystemIncrementalUI.refreshCommunity then
			SystemIncrementalUI.refreshCommunity = function()
				print("[ClientLoader] Fallback refreshCommunity")
			end
		end
	else
		-- If still nil, create a basic fallback
		SystemIncrementalUI = {
			buildUI = function(p) return true end,
			notify = function(message, kind) print("[ClientLoader] Basic fallback notify:", tostring(message)) end,
			refreshLeaderboard = function() print("[ClientLoader] Basic fallback refreshLeaderboard") end,
			refreshCommunity = function() print("[ClientLoader] Basic fallback refreshCommunity") end,
		}
		print("[ClientLoader] SystemIncrementalUI was still nil, created basic fallback")
	end
	
	-- Initialize the UI system
	if SystemIncrementalUI and SystemIncrementalUI.buildUI then
		local uiResult = SystemIncrementalUI.buildUI(player)
		if uiResult then
			print("[ClientLoader] SystemIncrementalUI loaded successfully")
		else
			warn("[ClientLoader] Failed to load SystemIncrementalUI")
		end
	else
		warn("[ClientLoader] SystemIncrementalUI module not available")
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

-- Return API for external access
return {
	notify = SystemIncrementalUI and SystemIncrementalUI.notify or function() end,
	refreshLeaderboard = SystemIncrementalUI and SystemIncrementalUI.refreshLeaderboard or function() end,
	refreshCommunity = SystemIncrementalUI and SystemIncrementalUI.refreshCommunity or function() end,
}
