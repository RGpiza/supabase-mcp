local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create comprehensive GUI content
local function createComprehensiveGUIContent(rootFrame)
	print("[ClientLoader] Creating comprehensive GUI content...")
	
	-- Create a main content area that fills the entire screen
	local mainContent = Instance.new("Frame")
	mainContent.Name = "MainContent"
	mainContent.Size = UDim2.new(1, 0, 1, 0)
	mainContent.Position = UDim2.new(0, 0, 0, 0)
	mainContent.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
	mainContent.BorderSizePixel = 0
	mainContent.Parent = rootFrame
	
	-- Create header with data display
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0.15, 0)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	header.BorderSizePixel = 1
	header.BorderColor3 = Color3.fromRGB(60, 70, 90)
	header.Parent = mainContent
	
	-- Create data display
	local dataDisplay = Instance.new("TextLabel")
	dataDisplay.Name = "DataDisplay"
	dataDisplay.Text = "Data: 0"
	dataDisplay.Font = Enum.Font.GothamSemibold
	dataDisplay.TextSize = 20
	dataDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
	dataDisplay.BackgroundTransparency = 1
	dataDisplay.Size = UDim2.new(0.3, 0, 1, 0)
	dataDisplay.Position = UDim2.new(0.02, 0, 0, 0)
	dataDisplay.Parent = header
	
	-- Create stats display
	local statsDisplay = Instance.new("TextLabel")
	statsDisplay.Name = "StatsDisplay"
	statsDisplay.Text = "DPS: 1 | Prestige: 0"
	statsDisplay.Font = Enum.Font.GothamSemibold
	statsDisplay.TextSize = 16
	statsDisplay.TextColor3 = Color3.fromRGB(200, 200, 200)
	statsDisplay.BackgroundTransparency = 1
	statsDisplay.Size = UDim2.new(0.3, 0, 1, 0)
	statsDisplay.Position = UDim2.new(0.35, 0, 0, 0)
	statsDisplay.Parent = header
	
	-- Create main content area
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, 0, 0.85, 0)
	contentArea.Position = UDim2.new(0, 0, 0.15, 0)
	contentArea.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
	contentArea.BorderSizePixel = 0
	contentArea.Parent = mainContent
	
	-- Create left panel for upgrades
	local leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.Size = UDim2.new(0.6, 0, 1, 0)
	leftPanel.Position = UDim2.new(0, 0, 0, 0)
	leftPanel.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
	leftPanel.BorderSizePixel = 1
	leftPanel.BorderColor3 = Color3.fromRGB(70, 80, 100)
	leftPanel.Parent = contentArea
	
	-- Create upgrade title
	local upgradeTitle = Instance.new("TextLabel")
	upgradeTitle.Name = "UpgradeTitle"
	upgradeTitle.Text = "System Upgrades"
	upgradeTitle.Font = Enum.Font.GothamSemibold
	upgradeTitle.TextSize = 18
	upgradeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgradeTitle.BackgroundTransparency = 1
	upgradeTitle.Size = UDim2.new(1, 0, 0.1, 0)
	upgradeTitle.Position = UDim2.new(0, 0, 0.02, 0)
	upgradeTitle.Parent = leftPanel
	
	-- Create upgrade buttons
	local upgrade1 = Instance.new("TextButton")
	upgrade1.Name = "CPUUpgrade"
	upgrade1.Text = "CPU Upgrade\n+0.5 DPS\nCost: 100 Data"
	upgrade1.Font = Enum.Font.GothamSemibold
	upgrade1.TextSize = 14
	upgrade1.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgrade1.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	upgrade1.BorderSizePixel = 1
	upgrade1.BorderColor3 = Color3.fromRGB(80, 180, 255)
	upgrade1.Size = UDim2.new(0.9, 0, 0.25, 0)
	upgrade1.Position = UDim2.new(0.05, 0, 0.15, 0)
	upgrade1.Parent = leftPanel
	
	local upgrade2 = Instance.new("TextButton")
	upgrade2.Name = "RAMUpgrade"
	upgrade2.Text = "RAM Upgrade\n+1.0 DPS\nCost: 500 Data"
	upgrade2.Font = Enum.Font.GothamSemibold
	upgrade2.TextSize = 14
	upgrade2.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgrade2.BackgroundColor3 = Color3.fromRGB(50, 255, 150)
	upgrade2.BorderSizePixel = 1
	upgrade2.BorderColor3 = Color3.fromRGB(80, 255, 180)
	upgrade2.Size = UDim2.new(0.9, 0, 0.25, 0)
	upgrade2.Position = UDim2.new(0.05, 0, 0.45, 0)
	upgrade2.Parent = leftPanel
	
	local upgrade3 = Instance.new("TextButton")
	upgrade3.Name = "StorageUpgrade"
	upgrade3.Text = "Storage Upgrade\n+2.0 DPS\nCost: 1000 Data"
	upgrade3.Font = Enum.Font.GothamSemibold
	upgrade3.TextSize = 14
	upgrade3.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgrade3.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
	upgrade3.BorderSizePixel = 1
	upgrade3.BorderColor3 = Color3.fromRGB(255, 180, 80)
	upgrade3.Size = UDim2.new(0.9, 0, 0.25, 0)
	upgrade3.Position = UDim2.new(0.05, 0, 0.75, 0)
	upgrade3.Parent = leftPanel
	
	-- Create right panel for stats and actions
	local rightPanel = Instance.new("Frame")
	rightPanel.Name = "RightPanel"
	rightPanel.Size = UDim2.new(0.35, 0, 1, 0)
	rightPanel.Position = UDim2.new(0.65, 0, 0, 0)
	rightPanel.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
	rightPanel.BorderSizePixel = 1
	rightPanel.BorderColor3 = Color3.fromRGB(70, 80, 100)
	rightPanel.Parent = contentArea
	
	-- Create stats title
	local statsTitle = Instance.new("TextLabel")
	statsTitle.Name = "StatsTitle"
	statsTitle.Text = "System Stats"
	statsTitle.Font = Enum.Font.GothamSemibold
	statsTitle.TextSize = 18
	statsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	statsTitle.BackgroundTransparency = 1
	statsTitle.Size = UDim2.new(1, 0, 0.1, 0)
	statsTitle.Position = UDim2.new(0, 0, 0.02, 0)
	statsTitle.Parent = rightPanel
	
	-- Create detailed stats
	local detailedStats = Instance.new("TextLabel")
	detailedStats.Name = "DetailedStats"
	detailedStats.Text = "Core Power: 1.0x\nStorage Capacity: 1000\nAuto-Production: OFF\nMultipliers: 1.0x"
	detailedStats.Font = Enum.Font.Gotham
	detailedStats.TextSize = 14
	detailedStats.TextColor3 = Color3.fromRGB(200, 200, 200)
	detailedStats.BackgroundTransparency = 1
	detailedStats.Size = UDim2.new(1, 0, 0.3, 0)
	detailedStats.Position = UDim2.new(0, 0, 0.15, 0)
	detailedStats.Parent = rightPanel
	
	-- Create prestige button
	local prestigeButton = Instance.new("TextButton")
	prestigeButton.Name = "PrestigeButton"
	prestigeButton.Text = "PRESTIGE\nReset for Bonus"
	prestigeButton.Font = Enum.Font.GothamSemibold
	prestigeButton.TextSize = 14
	prestigeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	prestigeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	prestigeButton.BorderSizePixel = 1
	prestigeButton.BorderColor3 = Color3.fromRGB(255, 80, 80)
	prestigeButton.Size = UDim2.new(0.9, 0, 0.2, 0)
	prestigeButton.Position = UDim2.new(0.05, 0, 0.5, 0)
	prestigeButton.Parent = rightPanel
	
	-- Add click handlers
	local dataValue = 0
	local dps = 1
	
	upgrade1.MouseButton1Click:Connect(function()
		if dataValue >= 100 then
			dataValue = dataValue - 100
			dps = dps + 0.5
			dataDisplay.Text = "Data: " .. dataValue
			statsDisplay.Text = "DPS: " .. dps .. " | Prestige: 0"
			upgrade1.TextColor3 = Color3.fromRGB(100, 100, 100)
			upgrade1.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			print("[ClientLoader] CPU Upgrade purchased")
		else
			print("[ClientLoader] Not enough data for CPU Upgrade")
		end
	end)
	
	upgrade2.MouseButton1Click:Connect(function()
		if dataValue >= 500 then
			dataValue = dataValue - 500
			dps = dps + 1.0
			dataDisplay.Text = "Data: " .. dataValue
			statsDisplay.Text = "DPS: " .. dps .. " | Prestige: 0"
			upgrade2.TextColor3 = Color3.fromRGB(100, 100, 100)
			upgrade2.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			print("[ClientLoader] RAM Upgrade purchased")
		else
			print("[ClientLoader] Not enough data for RAM Upgrade")
		end
	end)
	
	upgrade3.MouseButton1Click:Connect(function()
		if dataValue >= 1000 then
			dataValue = dataValue - 1000
			dps = dps + 2.0
			dataDisplay.Text = "Data: " .. dataValue
			statsDisplay.Text = "DPS: " .. dps .. " | Prestige: 0"
			upgrade3.TextColor3 = Color3.fromRGB(100, 100, 100)
			upgrade3.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			print("[ClientLoader] Storage Upgrade purchased")
		else
			print("[ClientLoader] Not enough data for Storage Upgrade")
		end
	end)
	
	prestigeButton.MouseButton1Click:Connect(function()
		dataValue = 0
		dps = 1
		dataDisplay.Text = "Data: " .. dataValue
		statsDisplay.Text = "DPS: " .. dps .. " | Prestige: 1"
		print("[ClientLoader] Prestige activated")
	end)
	
	-- Add auto-production simulation
	spawn(function()
		while true do
			task.wait(1)
			dataValue = dataValue + dps
			dataDisplay.Text = "Data: " .. dataValue
		end
	end)
	
	print("[ClientLoader] Comprehensive GUI content created successfully")
end

-- Ensure GUI content is created
local function ensureGUIContent()
	print("[ClientLoader] Ensuring GUI content is created...")
	
	if not playerGui then
		warn("[ClientLoader] PlayerGui not available for GUI content")
		return
	end
	
	local terminalUI = playerGui:FindFirstChild("TerminalUI")
	if not terminalUI then
		warn("[ClientLoader] TerminalUI not found for GUI content")
		return
	end
	
	local rootFrame = terminalUI:FindFirstChild("Root")
	if not rootFrame then
		warn("[ClientLoader] Root frame not found for GUI content")
		return
	end
	
	-- Check if content already exists
	local existingContent = rootFrame:FindFirstChild("DataDisplay") or rootFrame:FindFirstChild("UpgradeFrame")
	if existingContent then
		print("[ClientLoader] GUI content already exists")
		return
	end
	
	-- Create comprehensive GUI content
	createComprehensiveGUIContent(rootFrame)
end

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

-- Use the simplified single-file GUI system
local success, result = pcall(function()
	return require(script.Parent.SingleFileGUI)
end)
if success then
	SystemIncrementalUI = result
	print("[ClientLoader] SingleFileGUI loaded successfully")
else
	warn("[ClientLoader] Failed to load SingleFileGUI:", result)
	-- Try alternative path
	local success2, result2 = pcall(function()
		return require(ReplicatedStorage.Shared.SingleFileGUI)
	end)
	if success2 then
		SystemIncrementalUI = result2
		print("[ClientLoader] SingleFileGUI loaded from alternative path")
	else
		warn("[ClientLoader] Failed to load SingleFileGUI from alternative path:", result2)
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

-- Initialize controllers with fallback content creation
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
		print("[ClientLoader] TerminalController failed to load, using fallback")
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
		print("[ClientLoader] UpgradeController failed to load, creating fallback content")
		createFallbackContent()
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

-- Create fallback content when controllers fail
local function createFallbackContent()
	print("[ClientLoader] Creating fallback content...")
	
	if not playerGui then
		warn("[ClientLoader] PlayerGui not available for fallback content")
		return
	end
	
	local terminalUI = playerGui:FindFirstChild("TerminalUI")
	if not terminalUI then
		warn("[ClientLoader] TerminalUI not found for fallback content")
		return
	end
	
	local rootFrame = terminalUI:FindFirstChild("Root")
	if not rootFrame then
		warn("[ClientLoader] Root frame not found for fallback content")
		return
	end
	
	-- Create a simple data display
	local dataDisplay = Instance.new("TextLabel")
	dataDisplay.Name = "DataDisplay"
	dataDisplay.Text = "Data: 0"
	dataDisplay.Font = Enum.Font.GothamSemibold
	dataDisplay.TextSize = 18
	dataDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
	dataDisplay.BackgroundTransparency = 1
	dataDisplay.Size = UDim2.new(0.2, 0, 0.1, 0)
	dataDisplay.Position = UDim2.new(0.05, 0, 0.1, 0)
	dataDisplay.Parent = rootFrame
	
	-- Create upgrade buttons
	local upgradeFrame = Instance.new("Frame")
	upgradeFrame.Name = "UpgradeFrame"
	upgradeFrame.Size = UDim2.new(0.4, 0, 0.6, 0)
	upgradeFrame.Position = UDim2.new(0.5, 0, 0.2, 0)
	upgradeFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	upgradeFrame.BorderSizePixel = 1
	upgradeFrame.BorderColor3 = Color3.fromRGB(60, 70, 90)
	upgradeFrame.Parent = rootFrame
	
	local upgradeTitle = Instance.new("TextLabel")
	upgradeTitle.Name = "UpgradeTitle"
	upgradeTitle.Text = "Upgrades"
	upgradeTitle.Font = Enum.Font.GothamSemibold
	upgradeTitle.TextSize = 16
	upgradeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgradeTitle.BackgroundTransparency = 1
	upgradeTitle.Size = UDim2.new(1, 0, 0.1, 0)
	upgradeTitle.Position = UDim2.new(0, 0, 0, 0)
	upgradeTitle.Parent = upgradeFrame
	
	-- Create sample upgrade buttons
	local upgrade1 = Instance.new("TextButton")
	upgrade1.Name = "Upgrade1"
	upgrade1.Text = "CPU Upgrade - 100 Data"
	upgrade1.Font = Enum.Font.GothamSemibold
	upgrade1.TextSize = 14
	upgrade1.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgrade1.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	upgrade1.BorderSizePixel = 1
	upgrade1.BorderColor3 = Color3.fromRGB(80, 180, 255)
	upgrade1.Size = UDim2.new(0.9, 0, 0.2, 0)
	upgrade1.Position = UDim2.new(0.05, 0, 0.2, 0)
	upgrade1.Parent = upgradeFrame
	
	local upgrade2 = Instance.new("TextButton")
	upgrade2.Name = "Upgrade2"
	upgrade2.Text = "RAM Upgrade - 500 Data"
	upgrade2.Font = Enum.Font.GothamSemibold
	upgrade2.TextSize = 14
	upgrade2.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgrade2.BackgroundColor3 = Color3.fromRGB(50, 255, 150)
	upgrade2.BorderSizePixel = 1
	upgrade2.BorderColor3 = Color3.fromRGB(80, 255, 180)
	upgrade2.Size = UDim2.new(0.9, 0, 0.2, 0)
	upgrade2.Position = UDim2.new(0.05, 0, 0.45, 0)
	upgrade2.Parent = upgradeFrame
	
	local upgrade3 = Instance.new("TextButton")
	upgrade3.Name = "Upgrade3"
	upgrade3.Text = "Storage Upgrade - 1000 Data"
	upgrade3.Font = Enum.Font.GothamSemibold
	upgrade3.TextSize = 14
	upgrade3.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgrade3.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
	upgrade3.BorderSizePixel = 1
	upgrade3.BorderColor3 = Color3.fromRGB(255, 180, 80)
	upgrade3.Size = UDim2.new(0.9, 0, 0.2, 0)
	upgrade3.Position = UDim2.new(0.05, 0, 0.7, 0)
	upgrade3.Parent = upgradeFrame
	
	-- Add click handlers
	upgrade1.MouseButton1Click:Connect(function()
		print("[ClientLoader] CPU Upgrade clicked")
		dataDisplay.Text = "Data: 100"
	end)
	
	upgrade2.MouseButton1Click:Connect(function()
		print("[ClientLoader] RAM Upgrade clicked")
		dataDisplay.Text = "Data: 600"
	end)
	
	upgrade3.MouseButton1Click:Connect(function()
		print("[ClientLoader] Storage Upgrade clicked")
		dataDisplay.Text = "Data: 1600"
	end)
	
	print("[ClientLoader] Fallback content created successfully")
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
	
	-- Ensure GUI content is created even if controllers fail
	spawn(function()
		task.wait(0.5) -- Slightly longer delay to ensure UI is ready
		if ensureGUIContent then
			ensureGUIContent()
		else
			warn("[ClientLoader] ensureGUIContent function not found")
		end
	end)
	
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
