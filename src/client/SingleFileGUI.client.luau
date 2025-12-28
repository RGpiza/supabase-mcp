-- Single File GUI System for System Incremental
-- Consolidated GUI creation and management in one script

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
	screenGuiName = "SystemIncrementalUI",
	rootFrameName = "MainContainer",
	backgroundColor = Color3.fromRGB(15, 17, 21),
	borderColor = Color3.fromRGB(42, 48, 64),
	textColor = Color3.fromRGB(230, 230, 230),
	accentColor1 = Color3.fromRGB(50, 150, 255), -- Blue
	accentColor2 = Color3.fromRGB(50, 255, 150), -- Green
	accentColor3 = Color3.fromRGB(255, 150, 50), -- Orange
	errorColor = Color3.fromRGB(200, 50, 50), -- Red
}

-- State management
local state = {
	data = 0,
	dps = 1,
	prestigeLevel = 0,
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

local function createTextButton(name, parent, text, size, position, backgroundColor, textColor)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = Enum.Font.GothamSemibold
	button.TextSize = 14
	button.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	button.BackgroundColor3 = backgroundColor
	button.BorderSizePixel = 1
	button.BorderColor3 = CONFIG.borderColor
	button.Size = size
	button.Position = position
	button.Parent = parent
	return button
end

-- GUI Sections

-- 1. Header Section
local function createHeaderSection(container)
	local header = createFrame("Header", container, UDim2.new(1, 0, 0.15, 0), UDim2.new(0, 0, 0, 0), CONFIG.backgroundColor, 1, CONFIG.borderColor)
	
	-- Title
	UI.title = createTextLabel("Title", header, "System Incremental", UDim2.new(0.5, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), CONFIG.textColor, 24, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	
	-- Data Display
	UI.dataDisplay = createTextLabel("DataDisplay", header, "Data: 0", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.5, 0, 0, 0), CONFIG.textColor, 20, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	
	-- Stats Display
	UI.statsDisplay = createTextLabel("StatsDisplay", header, "DPS: 1 | Prestige: 0", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.8, 0, 0, 0), CONFIG.textColor, 16, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	
	return header
end

-- 2. Upgrades Section
local function createUpgradesSection(container)
	local upgrades = createFrame("Upgrades", container, UDim2.new(0.6, 0, 0.85, 0), UDim2.new(0, 0, 0.15, 0), CONFIG.backgroundColor, 1, CONFIG.borderColor)
	
	-- Section Title
	local sectionTitle = createTextLabel("SectionTitle", upgrades, "System Upgrades", UDim2.new(1, 0, 0.1, 0), UDim2.new(0, 0, 0.02, 0), CONFIG.textColor, 18, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	
	-- Upgrade Buttons
	UI.cpuUpgrade = createTextButton("CPUUpgrade", upgrades, "CPU Upgrade\n+0.5 DPS\nCost: 100 Data", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.15, 0), CONFIG.accentColor1)
	UI.ramUpgrade = createTextButton("RAMUpgrade", upgrades, "RAM Upgrade\n+1.0 DPS\nCost: 500 Data", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.4, 0), CONFIG.accentColor2)
	UI.storageUpgrade = createTextButton("StorageUpgrade", upgrades, "Storage Upgrade\n+2.0 DPS\nCost: 1000 Data", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.65, 0), CONFIG.accentColor3)
	
	return upgrades
end

-- 3. Stats Section
local function createStatsSection(container)
	local stats = createFrame("Stats", container, UDim2.new(0.35, 0, 0.85, 0), UDim2.new(0.65, 0, 0.15, 0), CONFIG.backgroundColor, 1, CONFIG.borderColor)
	
	-- Section Title
	local sectionTitle = createTextLabel("SectionTitle", stats, "System Stats", UDim2.new(1, 0, 0.1, 0), UDim2.new(0, 0, 0.02, 0), CONFIG.textColor, 18, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	
	-- Detailed Stats
	UI.detailedStats = createTextLabel("DetailedStats", stats, "Core Power: 1.0x\nStorage Capacity: 1000\nAuto-Production: OFF\nMultipliers: 1.0x", UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0.15, 0), CONFIG.textColor, 14, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Top})
	
	-- Prestige Button
	UI.prestigeButton = createTextButton("PrestigeButton", stats, "PRESTIGE\nReset for Bonus", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.5, 0), CONFIG.errorColor)
	
	return stats
end

-- 4. Notifications System
local function createNotificationsSystem()
	-- Create notification container
	local notificationContainer = Instance.new("Frame")
	notificationContainer.Name = "Notifications"
	notificationContainer.Size = UDim2.new(0.3, 0, 0.2, 0)
	notificationContainer.Position = UDim2.new(0.7, 0, 0.05, 0)
	notificationContainer.BackgroundTransparency = 1
	notificationContainer.Parent = UI.rootFrame
	
	-- Notification function
	function UI.notify(message, kind)
		local kind = kind or "info"
		local color = CONFIG.textColor
		
		if kind == "success" then
			color = CONFIG.accentColor2
		elseif kind == "error" then
			color = CONFIG.errorColor
		elseif kind == "warning" then
			color = CONFIG.accentColor3
		end
		
		local notification = createTextLabel("Notification_" .. tick(), notificationContainer, message, UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, #state.notificationQueue * 0.25, 0), color, 14, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
		
		table.insert(state.notificationQueue, notification)
		
		-- Auto-remove after 3 seconds
		task.delay(3, function()
			if notification and notification.Parent then
				notification:Destroy()
			end
			for i, v in ipairs(state.notificationQueue) do
				if v == notification then
					table.remove(state.notificationQueue, i)
					break
				end
			end
			-- Re-position remaining notifications
			for i, v in ipairs(state.notificationQueue) do
				v.Position = UDim2.new(0, 0, (i - 1) * 0.25, 0)
			end
		end)
	end
end

-- 5. Core Logic
local function updateDisplays()
	UI.dataDisplay.Text = "Data: " .. math.floor(state.data)
	UI.statsDisplay.Text = "DPS: " .. state.dps .. " | Prestige: " .. state.prestigeLevel
	UI.detailedStats.Text = "Core Power: " .. (state.prestigeLevel * 0.1 + 1) .. "x\nStorage Capacity: " .. (1000 + state.prestigeLevel * 500) .. "\nAuto-Production: ON\nMultipliers: " .. (state.prestigeLevel * 0.05 + 1) .. "x"
end

local function checkUpgradeAvailability()
	-- CPU Upgrade
	if state.data >= 100 then
		UI.cpuUpgrade.BackgroundColor3 = CONFIG.accentColor1
		UI.cpuUpgrade.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		UI.cpuUpgrade.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		UI.cpuUpgrade.TextColor3 = Color3.fromRGB(150, 150, 150)
	end
	
	-- RAM Upgrade
	if state.data >= 500 then
		UI.ramUpgrade.BackgroundColor3 = CONFIG.accentColor2
		UI.ramUpgrade.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		UI.ramUpgrade.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		UI.ramUpgrade.TextColor3 = Color3.fromRGB(150, 150, 150)
	end
	
	-- Storage Upgrade
	if state.data >= 1000 then
		UI.storageUpgrade.BackgroundColor3 = CONFIG.accentColor3
		UI.storageUpgrade.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		UI.storageUpgrade.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		UI.storageUpgrade.TextColor3 = Color3.fromRGB(150, 150, 150)
	end
end

-- 6. Event Handlers
local function setupEventHandlers()
	-- CPU Upgrade
	UI.cpuUpgrade.MouseButton1Click:Connect(function()
		if state.data >= 100 then
			state.data = state.data - 100
			state.dps = state.dps + 0.5
			UI.notify("CPU Upgrade purchased! +0.5 DPS", "success")
			updateDisplays()
		else
			UI.notify("Not enough data for CPU Upgrade", "error")
		end
	end)
	
	-- RAM Upgrade
	UI.ramUpgrade.MouseButton1Click:Connect(function()
		if state.data >= 500 then
			state.data = state.data - 500
			state.dps = state.dps + 1.0
			UI.notify("RAM Upgrade purchased! +1.0 DPS", "success")
			updateDisplays()
		else
			UI.notify("Not enough data for RAM Upgrade", "error")
		end
	end)
	
	-- Storage Upgrade
	UI.storageUpgrade.MouseButton1Click:Connect(function()
		if state.data >= 1000 then
			state.data = state.data - 1000
			state.dps = state.dps + 2.0
			UI.notify("Storage Upgrade purchased! +2.0 DPS", "success")
			updateDisplays()
		else
			UI.notify("Not enough data for Storage Upgrade", "error")
		end
	end)
	
	-- Prestige
	UI.prestigeButton.MouseButton1Click:Connect(function()
		if state.data >= 10000 then
			state.prestigeLevel = state.prestigeLevel + 1
			state.data = 0
			state.dps = 1
			UI.notify("Prestige activated! Reset with bonus", "success")
			updateDisplays()
		else
			UI.notify("Need 10,000 data to prestige", "warning")
		end
	end)
end

-- 7. Auto-Production System
local function startAutoProduction()
	spawn(function()
		while true do
			task.wait(1)
			if state.isInitialized then
				state.data = state.data + state.dps
				updateDisplays()
				checkUpgradeAvailability()
			end
		end
	end)
end

-- 8. Main Initialization
local function initialize()
	print("Initializing Single File GUI System...")
	
	-- Create main container
	UI.screenGui = Instance.new("ScreenGui")
	UI.screenGui.Name = CONFIG.screenGuiName
	UI.screenGui.ResetOnSpawn = false
	UI.screenGui.Parent = playerGui
	
	UI.rootFrame = createFrame(CONFIG.rootFrameName, UI.screenGui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
	
	-- Create sections
	createHeaderSection(UI.rootFrame)
	createUpgradesSection(UI.rootFrame)
	createStatsSection(UI.rootFrame)
	createNotificationsSystem()
	
	-- Setup event handlers
	setupEventHandlers()
	
	-- Start auto-production
	startAutoProduction()
	
	-- Initial display update
	updateDisplays()
	checkUpgradeAvailability()
	
	state.isInitialized = true
	UI.notify("System Incremental GUI loaded successfully!", "success")
	
	print("Single File GUI System initialized successfully!")
end

-- 9. Public API
local SingleFileGUI = {
	buildUI = function()
		if not state.isInitialized then
			initialize()
			return true
		else
			return false
		end
	end,
	
	notify = function(message, kind)
		if UI.notify then
			UI.notify(message, kind)
		else
			print("SingleFileGUI: " .. tostring(message))
		end
	end,
	
	refreshLeaderboard = function()
		-- Placeholder for leaderboard functionality
		UI.notify("Leaderboard refresh requested", "info")
	end,
	
	refreshCommunity = function()
		-- Placeholder for community functionality
		UI.notify("Community refresh requested", "info")
	end,
	
	getData = function()
		return state.data
	end,
	
	getDPS = function()
		return state.dps
	end,
	
	getPrestigeLevel = function()
		return state.prestigeLevel
	end,
	
	addData = function(amount)
		state.data = state.data + amount
		updateDisplays()
		checkUpgradeAvailability()
	end,
	
	reset = function()
		state.data = 0
		state.dps = 1
		state.prestigeLevel = 0
		updateDisplays()
		checkUpgradeAvailability()
		UI.notify("System reset!", "warning")
	end
}

-- Auto-initialize
spawn(function()
	repeat
		task.wait()
	until playerGui and playerGui.Parent
	initialize()
end)

return SingleFileGUI
