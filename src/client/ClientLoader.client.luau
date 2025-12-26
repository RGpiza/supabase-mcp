local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create a fallback SystemIncrementalUI module
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

-- Create the UI immediately to ensure it's available for the return statement
if not playerGui then
	warn("[ClientLoader] PlayerGui not available for immediate UI creation")
else
	-- Create ScreenGui immediately
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TerminalUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	-- Create Root Frame immediately
	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.Size = UDim2.new(1, 0, 1, 0)
	rootFrame.Position = UDim2.new(0, 0, 0, 0)
	rootFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 21)
	rootFrame.BorderSizePixel = 1
	rootFrame.BorderColor3 = Color3.fromRGB(42, 48, 64)
	rootFrame.Parent = screenGui
	
	-- Create Title Label immediately
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Text = "System Incremental UI Loaded (Immediate Fallback)"
	titleLabel.Font = Enum.Font.GothamSemibold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = rootFrame
	
	print("[ClientLoader] Created immediate UI fallback")
end

-- Create a basic SystemIncrementalUI fallback immediately
local SystemIncrementalUI = {
	buildUI = function(p) return true end,
	notify = function(message, kind) print("[ClientLoader] Basic fallback notify:", tostring(message)) end,
	refreshLeaderboard = function() print("[ClientLoader] Basic fallback refreshLeaderboard") end,
	refreshCommunity = function() print("[ClientLoader] Basic fallback refreshCommunity") end,
}
print("[ClientLoader] Created basic SystemIncrementalUI fallback")

-- Import SystemIncrementalUI from ReplicatedStorage
local success, result = pcall(function()
	return require(ReplicatedStorage.Shared.SystemIncrementalUI)
end)
if success then
	SystemIncrementalUI = result
	print("[ClientLoader] SystemIncrementalUI loaded successfully")
else
	warn("[ClientLoader] Failed to load SystemIncrementalUI from ReplicatedStorage:", result)
	-- Try alternative path
	local success2, result2 = pcall(function()
		return require(script.Parent.SystemIncrementalUI)
	end)
	if success2 then
		SystemIncrementalUI = result2
		print("[ClientLoader] SystemIncrementalUI loaded from alternative path")
	else
		warn("[ClientLoader] Failed to load SystemIncrementalUI from alternative path:", result2)
		-- Create a fallback SystemIncrementalUI module since the real one isn't available
		SystemIncrementalUI = createFallbackSystemIncrementalUI()
		print("[ClientLoader] Created fallback SystemIncrementalUI module")
	end
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
	if SystemIncrementalUI and SystemIncrementalUI.buildUI then
		local uiResult = SystemIncrementalUI.buildUI(player)
		if uiResult then
			print("[ClientLoader] SystemIncrementalUI loaded successfully")
		else
			warn("[ClientLoader] Failed to load SystemIncrementalUI")
			-- Force create fallback UI directly
			createDirectUI()
		end
	else
		warn("[ClientLoader] SystemIncrementalUI module not available - creating direct UI")
		-- Create UI directly without relying on the module
		createDirectUI()
	end
	
	-- Initialize remaining controllers for compatibility
	initializeControllers()
	
	print("[ClientLoader] Initialization complete")
end

-- Create UI directly without relying on modules
local function createDirectUI()
	print("[ClientLoader] Creating direct UI fallback")
	
	if not playerGui then
		warn("[ClientLoader] PlayerGui not available")
		return false
	end
	
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TerminalUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	-- Create Root Frame
	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "Root"
	rootFrame.Size = UDim2.new(1, 0, 1, 0)
	rootFrame.Position = UDim2.new(0, 0, 0, 0)
	rootFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 21)
	rootFrame.BorderSizePixel = 1
	rootFrame.BorderColor3 = Color3.fromRGB(42, 48, 64)
	rootFrame.Parent = screenGui
	
	-- Create Title Label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Text = "System Incremental UI Loaded (Direct Fallback)"
	titleLabel.Font = Enum.Font.GothamSemibold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = rootFrame
	
	-- Update SystemIncrementalUI to use the direct UI
	SystemIncrementalUI = {
		buildUI = function(p)
			return true -- UI already created
		end,
		notify = function(message, kind)
			print("[ClientLoader] Direct UI notify:", tostring(message))
		end,
		refreshLeaderboard = function()
			print("[ClientLoader] Direct UI refreshLeaderboard")
		end,
		refreshCommunity = function()
			print("[ClientLoader] Direct UI refreshCommunity")
		end,
	}
	
	return true
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
	notify = SystemIncrementalUI and SystemIncrementalUI.notify or function() end,
	refreshLeaderboard = SystemIncrementalUI and SystemIncrementalUI.refreshLeaderboard or function() end,
	refreshCommunity = SystemIncrementalUI and SystemIncrementalUI.refreshCommunity or function() end,
}
