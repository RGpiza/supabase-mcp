-- PerformanceUIManager.client.lua
-- High-performance UI architecture for System Incremental
-- Optimized for minimal render overhead and efficient updates

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then return end

local playerGui = player:WaitForChild("PlayerGui")

-- Performance Constants
local UI_CONSTANTS = {
	ROOT_NAME = "SystemIncrementalUI",
	ROOT_FRAME_NAME = "Root",
	SCALE_NAME = "UIScale",
	
	-- Layout Constants
	HEADER_HEIGHT = 0.15,
	UPGRADES_WIDTH = 0.6,
	STATS_WIDTH = 0.35,
	STATS_X_OFFSET = 0.65,
	
	-- Colors
	BACKGROUND = Color3.fromRGB(15, 17, 21),
	BORDER = Color3.fromRGB(42, 48, 64),
	TEXT = Color3.fromRGB(230, 230, 230),
	ACCENT_CPU = Color3.fromRGB(50, 150, 255),
	ACCENT_RAM = Color3.fromRGB(50, 255, 150),
	ACCENT_STORAGE = Color3.fromRGB(255, 150, 50),
	ERROR = Color3.fromRGB(200, 50, 50),
}

-- State Management
local UIState = {
	data = 0,
	dps = 1,
	prestigeLevel = 0,
	upgradeAvailability = {
		cpu = false,
		ram = false,
		storage = false,
	},
	isInitialized = false,
}

-- UI Elements Registry
local UIElements = {}

-- Event System
local UIEvents = {
	dataChanged = Instance.new("BindableEvent"),
	dpsChanged = Instance.new("BindableEvent"),
	prestigeChanged = Instance.new("BindableEvent"),
	upgradeAvailabilityChanged = Instance.new("BindableEvent"),
}

-- Performance Utilities
local function createFrame(name, parent, size, position, backgroundColor, borderSize, borderColor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = backgroundColor or UI_CONSTANTS.BACKGROUND
	frame.BorderSizePixel = borderSize or 1
	frame.BorderColor3 = borderColor or UI_CONSTANTS.BORDER
	frame.Parent = parent
	return frame
end

local function createTextLabel(name, parent, text, size, position, textColor, textSize, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = textSize or 16
	label.TextColor3 = textColor or UI_CONSTANTS.TEXT
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
	button.BorderColor3 = UI_CONSTANTS.BORDER
	button.Size = size
	button.Position = position
	button.Parent = parent
	return button
end

-- UI Builders (Called Once Only)
local function buildHeader(container)
	local header = createFrame("Header", container, UDim2.new(1, 0, UI_CONSTANTS.HEADER_HEIGHT, 0), UDim2.new(0, 0, 0, 0))
	
	UIElements.title = createTextLabel("Title", header, "System Incremental", UDim2.new(0.5, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), UI_CONSTANTS.TEXT, 24, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	UIElements.dataDisplay = createTextLabel("DataDisplay", header, "Data: 0", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.5, 0, 0, 0), UI_CONSTANTS.TEXT, 20, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	UIElements.statsDisplay = createTextLabel("StatsDisplay", header, "DPS: 1 | Prestige: 0", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.8, 0, 0, 0), UI_CONSTANTS.TEXT, 16, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	
	return header
end

local function buildUpgrades(container)
	local upgrades = createFrame("Upgrades", container, UDim2.new(UI_CONSTANTS.UPGRADES_WIDTH, 0, 0.85, 0), UDim2.new(0, 0, UI_CONSTANTS.HEADER_HEIGHT, 0))
	
	createTextLabel("SectionTitle", upgrades, "System Upgrades", UDim2.new(1, 0, 0.1, 0), UDim2.new(0, 0, 0.02, 0), UI_CONSTANTS.TEXT, 18, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	
	UIElements.cpuUpgrade = createTextButton("CPUUpgrade", upgrades, "CPU Upgrade\n+0.5 DPS\nCost: 100 Data", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.15, 0), UI_CONSTANTS.ACCENT_CPU)
	UIElements.ramUpgrade = createTextButton("RAMUpgrade", upgrades, "RAM Upgrade\n+1.0 DPS\nCost: 500 Data", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.4, 0), UI_CONSTANTS.ACCENT_RAM)
	UIElements.storageUpgrade = createTextButton("StorageUpgrade", upgrades, "Storage Upgrade\n+2.0 DPS\nCost: 1000 Data", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.65, 0), UI_CONSTANTS.ACCENT_STORAGE)
	
	return upgrades
end

local function buildStats(container)
	local stats = createFrame("Stats", container, UDim2.new(UI_CONSTANTS.STATS_WIDTH, 0, 0.85, 0), UDim2.new(UI_CONSTANTS.STATS_X_OFFSET, 0, UI_CONSTANTS.HEADER_HEIGHT, 0))
	
	createTextLabel("SectionTitle", stats, "System Stats", UDim2.new(1, 0, 0.1, 0), UDim2.new(0, 0, 0.02, 0), UI_CONSTANTS.TEXT, 18, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	
	UIElements.detailedStats = createTextLabel("DetailedStats", stats, "Core Power: 1.0x\nStorage Capacity: 1000\nAuto-Production: OFF\nMultipliers: 1.0x", UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0.15, 0), UI_CONSTANTS.TEXT, 14, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Top})
	UIElements.prestigeButton = createTextButton("PrestigeButton", stats, "PRESTIGE\nReset for Bonus", UDim2.new(0.9, 0, 0.2, 0), UDim2.new(0.05, 0, 0.5, 0), UI_CONSTANTS.ERROR)
	
	return stats
end

local function buildNotifications(container)
	local notificationContainer = createFrame("Notifications", container, UDim2.new(0.3, 0, 0.2, 0), UDim2.new(0.7, 0, 0.05, 0))
	notificationContainer.BackgroundTransparency = 1
	
	UIElements.notificationContainer = notificationContainer
	UIElements.notifications = {}
	
	return notificationContainer
end

-- Event Handlers (No Instance.new calls)
local function handleCPUUpgrade()
	if UIState.data >= 100 then
		UIState.data = UIState.data - 100
		UIState.dps = UIState.dps + 0.5
		UIEvents.dataChanged:Fire()
		UIEvents.dpsChanged:Fire()
		showNotification("CPU Upgrade purchased! +0.5 DPS", "success")
	end
end

local function handleRAMUpgrade()
	if UIState.data >= 500 then
		UIState.data = UIState.data - 500
		UIState.dps = UIState.dps + 1.0
		UIEvents.dataChanged:Fire()
		UIEvents.dpsChanged:Fire()
		showNotification("RAM Upgrade purchased! +1.0 DPS", "success")
	end
end

local function handleStorageUpgrade()
	if UIState.data >= 1000 then
		UIState.data = UIState.data - 1000
		UIState.dps = UIState.dps + 2.0
		UIEvents.dataChanged:Fire()
		UIEvents.dpsChanged:Fire()
		showNotification("Storage Upgrade purchased! +2.0 DPS", "success")
	end
end

local function handlePrestige()
	if UIState.data >= 10000 then
		UIState.prestigeLevel = UIState.prestigeLevel + 1
		UIState.data = 0
		UIState.dps = 1
		UIEvents.dataChanged:Fire()
		UIEvents.prestigeChanged:Fire()
		showNotification("Prestige activated! Reset with bonus", "success")
	end
end

-- UI Updaters (Mutate existing instances only)
local function updateDataDisplay()
	if UIElements.dataDisplay then
		UIElements.dataDisplay.Text = "Data: " .. math.floor(UIState.data)
	end
end

local function updateStatsDisplay()
	if UIElements.statsDisplay then
		UIElements.statsDisplay.Text = "DPS: " .. UIState.dps .. " | Prestige: " .. UIState.prestigeLevel
	end
end

local function updateDetailedStats()
	if UIElements.detailedStats then
		local corePower = UIState.prestigeLevel * 0.1 + 1
		local storageCapacity = 1000 + UIState.prestigeLevel * 500
		local multipliers = UIState.prestigeLevel * 0.05 + 1
		
		UIElements.detailedStats.Text = string.format(
			"Core Power: %.1fx\nStorage Capacity: %d\nAuto-Production: ON\nMultipliers: %.2fx",
			corePower, storageCapacity, multipliers
		)
	end
end

local function updateUpgradeAvailability()
	local cpuAvailable = UIState.data >= 100
	local ramAvailable = UIState.data >= 500
	local storageAvailable = UIState.data >= 1000
	
	if UIState.upgradeAvailability.cpu ~= cpuAvailable then
		UIState.upgradeAvailability.cpu = cpuAvailable
		if UIElements.cpuUpgrade then
			UIElements.cpuUpgrade.BackgroundColor3 = cpuAvailable and UI_CONSTANTS.ACCENT_CPU or Color3.fromRGB(80, 80, 80)
			UIElements.cpuUpgrade.TextColor3 = cpuAvailable and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
		end
	end
	
	if UIState.upgradeAvailability.ram ~= ramAvailable then
		UIState.upgradeAvailability.ram = ramAvailable
		if UIElements.ramUpgrade then
			UIElements.ramUpgrade.BackgroundColor3 = ramAvailable and UI_CONSTANTS.ACCENT_RAM or Color3.fromRGB(80, 80, 80)
			UIElements.ramUpgrade.TextColor3 = ramAvailable and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
		end
	end
	
	if UIState.upgradeAvailability.storage ~= storageAvailable then
		UIState.upgradeAvailability.storage = storageAvailable
		if UIElements.storageUpgrade then
			UIElements.storageUpgrade.BackgroundColor3 = storageAvailable and UI_CONSTANTS.ACCENT_STORAGE or Color3.fromRGB(80, 80, 80)
			UIElements.storageUpgrade.TextColor3 = storageAvailable and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
		end
	end
end

-- Notification System (Performance optimized)
local function showNotification(message, kind)
	local kind = kind or "info"
	local color = UI_CONSTANTS.TEXT
	
	if kind == "success" then
		color = UI_CONSTANTS.ACCENT_RAM
	elseif kind == "error" then
		color = UI_CONSTANTS.ERROR
	elseif kind == "warning" then
		color = UI_CONSTANTS.ACCENT_STORAGE
	end
	
	local notification = createTextLabel("Notification_" .. tick(), UIElements.notificationContainer, message, UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, #UIElements.notifications * 0.25, 0), color, 14, {x = Enum.TextXAlignment.Left, y = Enum.TextYAlignment.Center})
	
	table.insert(UIElements.notifications, notification)
	
	task.delay(3, function()
		if notification and notification.Parent then
			notification:Destroy()
		end
		for i, v in ipairs(UIElements.notifications) do
			if v == notification then
				table.remove(UIElements.notifications, i)
				break
			end
		end
		for i, v in ipairs(UIElements.notifications) do
			v.Position = UDim2.new(0, 0, (i - 1) * 0.25, 0)
		end
	end)
end

-- Event Listeners
local function setupEventListeners()
	UIEvents.dataChanged.Event:Connect(updateDataDisplay)
	UIEvents.dpsChanged.Event:Connect(updateStatsDisplay)
	UIEvents.prestigeChanged.Event:Connect(updateDetailedStats)
	UIEvents.upgradeAvailabilityChanged.Event:Connect(updateUpgradeAvailability)
	
	-- Button connections
	if UIElements.cpuUpgrade then
		UIElements.cpuUpgrade.MouseButton1Click:Connect(handleCPUUpgrade)
	end
	if UIElements.ramUpgrade then
		UIElements.ramUpgrade.MouseButton1Click:Connect(handleRAMUpgrade)
	end
	if UIElements.storageUpgrade then
		UIElements.storageUpgrade.MouseButton1Click:Connect(handleStorageUpgrade)
	end
	if UIElements.prestigeButton then
		UIElements.prestigeButton.MouseButton1Click:Connect(handlePrestige)
	end
end

-- Auto-Production (No RenderStepped)
local function startAutoProduction()
	spawn(function()
		while true do
			task.wait(1)
			if UIState.isInitialized then
				UIState.data = UIState.data + UIState.dps
				UIEvents.dataChanged:Fire()
				UIEvents.upgradeAvailabilityChanged:Fire()
			end
		end
	end)
end

-- Main Initialization
local function initialize()
	if playerGui:FindFirstChild(UI_CONSTANTS.ROOT_NAME) then
		return
	end
	
	-- Build UI hierarchy once
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = UI_CONSTANTS.ROOT_NAME
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	local rootFrame = createFrame(UI_CONSTANTS.ROOT_FRAME_NAME, screenGui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
	
	-- Apply UIScale only at root level
	local uiScale = Instance.new("UIScale")
	uiScale.Name = UI_CONSTANTS.SCALE_NAME
	uiScale.Parent = rootFrame
	
	-- Build sections
	buildHeader(rootFrame)
	buildUpgrades(rootFrame)
	buildStats(rootFrame)
	buildNotifications(rootFrame)
	
	-- Setup event system
	setupEventListeners()
	
	-- Start systems
	startAutoProduction()
	
	-- Initial updates
	updateDataDisplay()
	updateStatsDisplay()
	updateDetailedStats()
	updateUpgradeAvailability()
	
	UIState.isInitialized = true
	showNotification("System Incremental UI loaded!", "success")
end

-- Public API
local PerformanceUIManager = {
	getState = function()
		return UIState
	end,
	
	updateData = function(amount)
		UIState.data = amount
		UIEvents.dataChanged:Fire()
		UIEvents.upgradeAvailabilityChanged:Fire()
	end,
	
	updateDPS = function(amount)
		UIState.dps = amount
		UIEvents.dpsChanged:Fire()
	end,
	
	updatePrestige = function(level)
		UIState.prestigeLevel = level
		UIEvents.prestigeChanged:Fire()
		updateDetailedStats()
	end,
	
	reset = function()
		UIState.data = 0
		UIState.dps = 1
		UIState.prestigeLevel = 0
		UIState.upgradeAvailability = {cpu = false, ram = false, storage = false}
		
		UIEvents.dataChanged:Fire()
		UIEvents.dpsChanged:Fire()
		UIEvents.prestigeChanged:Fire()
		UIEvents.upgradeAvailabilityChanged:Fire()
		
		showNotification("System reset!", "warning")
	end,
	
	notify = function(message, kind)
		showNotification(message, kind)
	end,
}

-- Initialize on spawn
spawn(function()
	repeat
		task.wait()
	until playerGui and playerGui.Parent
	initialize()
end)

return PerformanceUIManager
