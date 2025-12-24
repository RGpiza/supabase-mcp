-- SystemIncrementalUI - Single File Implementation (Standalone)
-- Replaces the controller-based architecture with a unified UI system
-- This version is standalone and doesn't depend on external modules

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
	UI_PADDING = 10,
	ANIMATION_DURATION = 0.3,
	COLORS = {
		PRIMARY = Color3.fromHex("#00ffff"), -- Cyan
		SECONDARY = Color3.fromHex("#8000ff"), -- Purple
		BACKGROUND = Color3.fromHex("#1a1a1a"),
		TEXT = Color3.fromHex("#ffffff"),
		ACCENT = Color3.fromHex("#ff00ff"),
		SUCCESS = Color3.fromHex("#00ff00"),
		WARNING = Color3.fromHex("#ffff00"),
		ERROR = Color3.fromHex("#ff0000")
	}
}

-- State Management
local state = {
	currentTab = "upgrades",
	isPrestigeMode = false,
	notifications = {},
	leaderboardData = {},
	communityData = {},
	isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
}

-- UI Elements Storage
local ui = {
	mainFrame = nil,
	topBar = nil,
	leftPanel = nil,
	rightPanel = nil,
	contentArea = nil,
	tabs = {},
	notificationsContainer = nil
}

-- Utility Functions
local function createFrame(name, parent, size, position, backgroundColor, borderSize)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = backgroundColor
	frame.BorderSizePixel = borderSize or 0
	frame.Parent = parent
	return frame
end

local function createTextButton(name, parent, text, size, position, backgroundColor)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = backgroundColor
	button.TextColor3 = CONFIG.COLORS.TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Parent = parent
	return button
end

local function createTextLabel(name, parent, text, size, position, textColor, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor or CONFIG.COLORS.TEXT
	label.Font = Enum.Font.Gotham
	label.TextSize = textSize or 14
	label.Parent = parent
	return label
end

-- UI Building Functions
local function buildTopBar()
	local topBar = createFrame("TopBar", ui.mainFrame, UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 0), CONFIG.COLORS.BACKGROUND, 1)
	
	-- Logo
	local logo = createTextLabel("Logo", topBar, "SYSTEM INCREMENTAL", UDim2.new(0, 200, 0, 40), UDim2.new(0, 20, 0, 10), CONFIG.COLORS.PRIMARY, 24)
	logo.Font = Enum.Font.GothamBold
	
	-- Status Indicators
	local statusContainer = createFrame("StatusContainer", topBar, UDim2.new(0, 300, 0, 40), UDim2.new(1, -320, 0, 10), Color3.new(0, 0, 0), 0)
	statusContainer.BackgroundTransparency = 1
	
	local moneyLabel = createTextLabel("MoneyLabel", statusContainer, "$0", UDim2.new(0, 100, 0, 20), UDim2.new(0, 0, 0, 0), CONFIG.COLORS.SUCCESS, 18)
	local prestigeLabel = createTextLabel("PrestigeLabel", statusContainer, "Prestige: 0", UDim2.new(0, 150, 0, 20), UDim2.new(0, 110, 0, 0), CONFIG.COLORS.ACCENT, 14)
	
	-- Controls
	local controlsContainer = createFrame("ControlsContainer", topBar, UDim2.new(0, 200, 0, 40), UDim2.new(1, -210, 0, 10), Color3.new(0, 0, 0), 0)
	controlsContainer.BackgroundTransparency = 1
	
	local prestigeBtn = createTextButton("PrestigeBtn", controlsContainer, "PRESTIGE", UDim2.new(0, 90, 0, 30), UDim2.new(0, 0, 0, 5), CONFIG.COLORS.ERROR)
	local settingsBtn = createTextButton("SettingsBtn", controlsContainer, "SETTINGS", UDim2.new(0, 90, 0, 30), UDim2.new(0, 100, 0, 5), CONFIG.COLORS.SECONDARY)
	
	ui.topBar = topBar
	ui.moneyLabel = moneyLabel
	ui.prestigeLabel = prestigeLabel
	ui.prestigeBtn = prestigeBtn
	ui.settingsBtn = settingsBtn
end

local function buildLeftPanel()
	local leftPanel = createFrame("LeftPanel", ui.mainFrame, UDim2.new(0, 250, 1, -60), UDim2.new(0, 0, 0, 60), CONFIG.COLORS.BACKGROUND, 1)
	
	-- Tabs
	local tabsContainer = createFrame("TabsContainer", leftPanel, UDim2.new(1, 0, 0, 200), UDim2.new(0, 0, 0, 0), Color3.new(0, 0, 0), 0)
	tabsContainer.BackgroundTransparency = 1
	
	local tabs = {"upgrades", "prestige", "leaderboard", "community"}
	for i, tabName in ipairs(tabs) do
		local tabBtn = createTextButton(tabName:upper() .. "Btn", tabsContainer, tabName:upper(), UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 10 + (i-1) * 45), CONFIG.COLORS.BACKGROUND)
		tabBtn.BorderSizePixel = 1
		tabBtn.BorderColor3 = CONFIG.COLORS.PRIMARY
		ui.tabs[tabName] = tabBtn
	end
	
	-- Stats
	local statsContainer = createFrame("StatsContainer", leftPanel, UDim2.new(1, -20, 0, 150), UDim2.new(0, 10, 0, 220), CONFIG.COLORS.BACKGROUND, 1)
	
	local statsTitle = createTextLabel("StatsTitle", statsContainer, "STATISTICS", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 5), CONFIG.COLORS.PRIMARY, 16)
	
	local stats = {
		{"Total Earned", "0"},
		{"Total Prestiges", "0"},
		{"Time Played", "0h 0m"},
		{"Best Streak", "0"}
	}
	
	for i, stat in ipairs(stats) do
		local statLabel = createTextLabel("Stat" .. i, statsContainer, stat[1] .. ": " .. stat[2], UDim2.new(1, 0, 0, 25), UDim2.new(0, 10, 0, 40 + (i-1) * 25), CONFIG.COLORS.TEXT, 14)
	end
	
	ui.leftPanel = leftPanel
end

local function buildRightPanel()
	local rightPanel = createFrame("RightPanel", ui.mainFrame, UDim2.new(0, 300, 1, -60), UDim2.new(1, -300, 0, 60), CONFIG.COLORS.BACKGROUND, 1)
	
	-- Notifications
	local notificationsContainer = createFrame("NotificationsContainer", rightPanel, UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), Color3.new(0, 0, 0), 0)
	notificationsContainer.BackgroundTransparency = 1
	
	local notificationsTitle = createTextLabel("NotificationsTitle", notificationsContainer, "NOTIFICATIONS", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), CONFIG.COLORS.PRIMARY, 16)
	
	ui.rightPanel = rightPanel
	ui.notificationsContainer = notificationsContainer
end

local function buildContentArea()
	local contentArea = createFrame("ContentArea", ui.mainFrame, UDim2.new(1, -560, 1, -60), UDim2.new(0, 260, 0, 60), CONFIG.COLORS.BACKGROUND, 1)
	
	-- Content will be dynamically loaded based on selected tab
	ui.contentArea = contentArea
end

-- Tab Management
local function switchTab(tabName)
	state.currentTab = tabName
	
	-- Update tab button styles
	for tab, button in pairs(ui.tabs) do
		if tab == tabName then
			button.BackgroundColor3 = CONFIG.COLORS.PRIMARY
			button.TextColor3 = Color3.new(0, 0, 0)
		else
			button.BackgroundColor3 = CONFIG.COLORS.BACKGROUND
			button.TextColor3 = CONFIG.COLORS.TEXT
		end
	end
	
	-- Clear content area
	for _, child in ipairs(ui.contentArea:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "ContentMask" then
			child:Destroy()
		end
	end
	
	-- Load tab content
	if tabName == "upgrades" then
		buildUpgradesContent()
	elseif tabName == "prestige" then
		buildPrestigeContent()
	elseif tabName == "leaderboard" then
		buildLeaderboardContent()
	elseif tabName == "community" then
		buildCommunityContent()
	end
end

-- Content Builders
local function buildUpgradesContent()
	local upgradesContainer = createFrame("UpgradesContainer", ui.contentArea, UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), Color3.new(0, 0, 0), 0)
	upgradesContainer.BackgroundTransparency = 1
	
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollFrame.Position = UDim2.new(0, 0, 0, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 10
	scrollFrame.ScrollBarImageColor3 = CONFIG.COLORS.PRIMARY
	scrollFrame.Parent = upgradesContainer
	
	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.Padding = UDim.new(0, 10)
	uiListLayout.Parent = scrollFrame
	
	-- Create sample upgrade buttons
	local sampleUpgrades = {
		{name = "Auto Clicker", cost = 100},
		{name = "Double Click", cost = 500},
		{name = "Click Multiplier", cost = 1000},
		{name = "Auto Generator", cost = 5000}
	}
	
	for i, upgrade in ipairs(sampleUpgrades) do
		local upgradeFrame = createFrame("UpgradeFrame_" .. i, scrollFrame, UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 0), CONFIG.COLORS.BACKGROUND, 1)
		
		local nameLabel = createTextLabel("NameLabel", upgradeFrame, upgrade.name, UDim2.new(0, 200, 0, 20), UDim2.new(0, 10, 0, 5), CONFIG.COLORS.TEXT, 16)
		local costLabel = createTextLabel("CostLabel", upgradeFrame, "Cost: $" .. upgrade.cost, UDim2.new(0, 200, 0, 20), UDim2.new(0, 10, 0, 30), CONFIG.COLORS.SUCCESS, 14)
		
		local buyBtn = createTextButton("BuyBtn", upgradeFrame, "BUY", UDim2.new(0, 80, 0, 30), UDim2.new(1, -90, 0, 15), CONFIG.COLORS.PRIMARY)
		buyBtn.AnchorPoint = Vector2.new(1, 0)
		
		-- Add click handler
		buyBtn.MouseButton1Click:Connect(function()
			notify("Purchase successful!", "success")
		end)
	end
end

local function buildPrestigeContent()
	local prestigeContainer = createFrame("PrestigeContainer", ui.contentArea, UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), Color3.new(0, 0, 0), 0)
	prestigeContainer.BackgroundTransparency = 1
	
	local title = createTextLabel("PrestigeTitle", prestigeContainer, "PRESTIGE SYSTEM", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), CONFIG.COLORS.ACCENT, 24)
	
	-- Prestige nodes
	local nodesContainer = createFrame("NodesContainer", prestigeContainer, UDim2.new(1, 0, 1, -50), UDim2.new(0, 0, 0, 50), Color3.new(0, 0, 0), 0)
	nodesContainer.BackgroundTransparency = 1
	
	local sampleNodes = {
		{name = "Node 1: Basic Boost"},
		{name = "Node 2: Advanced Boost"},
		{name = "Node 3: Expert Boost"},
		{name = "Node 4: Master Boost"}
	}
	
	for i, node in ipairs(sampleNodes) do
		local nodeFrame = createFrame("Node_" .. i, nodesContainer, UDim2.new(0, 200, 0, 40), UDim2.new(0, 10 + (i-1) * 210, 0, 10), CONFIG.COLORS.BACKGROUND, 1)
		
		local nameLabel = createTextLabel("NodeName", nodeFrame, node.name, UDim2.new(1, -10, 1, 0), UDim2.new(0, 5, 0, 0), CONFIG.COLORS.TEXT, 14)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	end
end

local function buildLeaderboardContent()
	local leaderboardContainer = createFrame("LeaderboardContainer", ui.contentArea, UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), Color3.new(0, 0, 0), 0)
	leaderboardContainer.BackgroundTransparency = 1
	
	local title = createTextLabel("LeaderboardTitle", leaderboardContainer, "LEADERBOARDS", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), CONFIG.COLORS.PRIMARY, 24)
	
	-- Leaderboard data will be populated dynamically
	local dataContainer = createFrame("DataContainer", leaderboardContainer, UDim2.new(1, 0, 1, -50), UDim2.new(0, 0, 0, 50), CONFIG.COLORS.BACKGROUND, 1)
	
	local uiListLayout = Instance.new("UIListLayout")
	uiListLayout.Padding = UDim.new(0, 5)
	uiListLayout.Parent = dataContainer
	
	-- Sample leaderboard entries
	local sampleEntries = {
		{"Player1", "1,000,000"},
		{"Player2", "950,000"},
		{"Player3", "875,000"},
		{"Player4", "750,000"},
		{"Player5", "625,000"}
	}
	
	for i, entry in ipairs(sampleEntries) do
		local entryFrame = createFrame("Entry_" .. i, dataContainer, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), CONFIG.COLORS.BACKGROUND, 1)
		
		local rankLabel = createTextLabel("RankLabel", entryFrame, i .. ".", UDim2.new(0, 30, 1, 0), UDim2.new(0, 5, 0, 0), CONFIG.COLORS.TEXT, 14)
		local nameLabel = createTextLabel("NameLabel", entryFrame, entry[1], UDim2.new(0, 150, 1, 0), UDim2.new(0, 35, 0, 0), CONFIG.COLORS.TEXT, 14)
		local scoreLabel = createTextLabel("ScoreLabel", entryFrame, entry[2], UDim2.new(0, 100, 1, 0), UDim2.new(1, -105, 0, 0), CONFIG.COLORS.SUCCESS, 14)
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
	end
end

local function buildCommunityContent()
	local communityContainer = createFrame("CommunityContainer", ui.contentArea, UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), Color3.new(0, 0, 0), 0)
	communityContainer.BackgroundTransparency = 1
	
	local title = createTextLabel("CommunityTitle", communityContainer, "COMMUNITY", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), CONFIG.COLORS.SECONDARY, 24)
	
	-- Community goals and rewards
	local goalsContainer = createFrame("GoalsContainer", communityContainer, UDim2.new(1, 0, 1, -50), UDim2.new(0, 0, 0, 50), CONFIG.COLORS.BACKGROUND, 1)
	
	local sampleGoals = {
		{description = "Reach 1000 total players"},
		{description = "Achieve 1 million total clicks"},
		{description = "Complete 5000 prestige resets"},
		{description = "Earn 100 million total money"}
	}
	
	for i, goal in ipairs(sampleGoals) do
		local goalFrame = createFrame("Goal_" .. i, goalsContainer, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, (i-1) * 60), CONFIG.COLORS.BACKGROUND, 1)
		
		local goalLabel = createTextLabel("GoalLabel", goalFrame, goal.description, UDim2.new(1, -10, 1, 0), UDim2.new(0, 5, 0, 0), CONFIG.COLORS.TEXT, 14)
		goalLabel.TextXAlignment = Enum.TextXAlignment.Left
	end
end

-- Notification System
local function notify(message, type)
	local notification = createFrame("Notification", ui.notificationsContainer, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, #ui.notificationsContainer:GetChildren() * 45), CONFIG.COLORS.BACKGROUND, 1)
	
	local messageLabel = createTextLabel("Message", notification, message, UDim2.new(1, -10, 1, 0), UDim2.new(0, 5, 0, 0), CONFIG.COLORS.TEXT, 14)
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	
	-- Set color based on type
	if type == "success" then
		notification.BorderColor3 = CONFIG.COLORS.SUCCESS
	elseif type == "warning" then
		notification.BorderColor3 = CONFIG.COLORS.WARNING
	elseif type == "error" then
		notification.BorderColor3 = CONFIG.COLORS.ERROR
	end
	
	-- Auto-remove after 3 seconds
	task.delay(3, function()
		notification:TweenPosition(UDim2.new(0, 0, 0, -50), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true, function()
			notification:Destroy()
		end)
	end)
end

-- Event Handlers
local function setupEventHandlers()
	-- Tab buttons
	for tabName, button in pairs(ui.tabs) do
		button.MouseButton1Click:Connect(function()
			switchTab(tabName)
		end)
	end
	
	-- Prestige button
	ui.prestigeBtn.MouseButton1Click:Connect(function()
		notify("Prestige functionality coming soon!", "warning")
	end)
	
	-- Settings button
	ui.settingsBtn.MouseButton1Click:Connect(function()
		notify("Settings functionality coming soon!", "info")
	end)
end

-- Main Build Function
local function buildUI()
	print("[SystemIncrementalUI] Building UI...")
	
	-- Check if TerminalController has already created the hierarchy
	local existingTerminalUI = playerGui:FindFirstChild("TerminalUI")
	if existingTerminalUI then
		print("[SystemIncrementalUI] Using existing TerminalUI hierarchy")
		ui.mainFrame = existingTerminalUI
	else
		-- Create main frame if TerminalController hasn't created it
		ui.mainFrame = createFrame("SystemIncrementalUI", playerGui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.new(0, 0, 0), 0)
		ui.mainFrame.BackgroundTransparency = 1
		print("[SystemIncrementalUI] Created new UI hierarchy")
	end
	
	-- Build UI components
	buildTopBar()
	buildLeftPanel()
	buildRightPanel()
	buildContentArea()
	
	-- Setup event handlers
	setupEventHandlers()
	
	-- Initialize with upgrades tab
	switchTab("upgrades")
	
	print("[SystemIncrementalUI] UI built successfully")
	return true
end

-- Public API
local SystemIncrementalUI = {
	buildUI = buildUI,
	notify = notify,
	refreshLeaderboard = function()
		-- Implementation for refreshing leaderboard
		print("[SystemIncrementalUI] Refreshing leaderboard...")
	end,
	refreshCommunity = function()
		-- Implementation for refreshing community data
		print("[SystemIncrementalUI] Refreshing community data...")
	end
}

return SystemIncrementalUI
