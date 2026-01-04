local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local DebugConfig = nil
do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.utils:FindFirstChild("DebugConfig"))
	end)
	if ok and type(mod) == "table" then
		DebugConfig = mod
	end
end

local DeveloperDashboardController = {}

-- Configuration
local CONFIG = {
	-- Only available in Studio
	ENABLED = RunService:IsStudio(),
	
	-- UI settings
	UI_POSITION = UDim2.fromOffset(20, 20),
	UI_SIZE = UDim2.fromOffset(400, 600),
	
	-- Auto-refresh settings
	AUTO_REFRESH_INTERVAL = 30, -- seconds
}

-- Internal state
local dashboardFrame = nil
local isInitialized = false
local autoRefreshEnabled = true
local lastRefreshTime = 0

-- Utility functions
local function log(level, message, ...)
	if DebugConfig then
		if level == "error" then
			DebugConfig.Error(message, ...)
		elseif level == "warn" then
			DebugConfig.Warn(message, ...)
		else
			DebugConfig.Log(message, ...)
		end
	end
end

local function createDashboardUI()
	if not CONFIG.ENABLED then
		return nil
	end
	
	-- Create main frame
	local frame = Instance.new("Frame")
	frame.Name = "DeveloperDashboard"
	frame.Size = CONFIG.UI_SIZE
	frame.Position = CONFIG.UI_POSITION
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 10
	
	-- Create title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "System Incremental Production Error Dashboard"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.ZIndex = 11
	title.Parent = frame
	
	-- Create refresh button
	local refreshButton = Instance.new("TextButton")
	refreshButton.Name = "RefreshButton"
	refreshButton.Text = "Refresh"
	refreshButton.Font = Enum.Font.Gotham
	refreshButton.TextSize = 14
	refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	refreshButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	refreshButton.BorderSizePixel = 0
	refreshButton.Size = UDim2.new(0, 80, 0, 25)
	refreshButton.Position = UDim2.new(1, -90, 0, 5)
	refreshButton.ZIndex = 11
	refreshButton.Parent = frame
	
	-- Create auto-refresh toggle
	local autoRefreshToggle = Instance.new("TextButton")
	autoRefreshToggle.Name = "AutoRefreshToggle"
	autoRefreshToggle.Text = "Auto: ON"
	autoRefreshToggle.Font = Enum.Font.Gotham
	autoRefreshToggle.TextSize = 14
	refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoRefreshToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	autoRefreshToggle.BorderSizePixel = 0
	autoRefreshToggle.Size = UDim2.new(0, 100, 0, 25)
	autoRefreshToggle.Position = UDim2.new(1, -200, 0, 5)
	autoRefreshToggle.ZIndex = 11
	autoRefreshToggle.Parent = frame
	
	-- Create summary frame
	local summaryFrame = Instance.new("Frame")
	summaryFrame.Name = "SummaryFrame"
	summaryFrame.Size = UDim2.new(1, 0, 0, 100)
	summaryFrame.Position = UDim2.new(0, 0, 0, 35)
	summaryFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	summaryFrame.BorderSizePixel = 0
	summaryFrame.ZIndex = 11
	summaryFrame.Parent = frame
	
	-- Create summary labels
	local summaryLabels = {}
	local summaryKeys = {"Total Errors", "Unique Services", "Most Problematic", "Last Updated"}
	
	for i, key in ipairs(summaryKeys) do
		local label = Instance.new("TextLabel")
		label.Name = key:gsub(" ", "") .. "Label"
		label.Text = key .. ": --"
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextColor3 = Color3.fromRGB(200, 200, 200)
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 20)
		label.Position = UDim2.new(0, 10, 0, 10 + (i-1) * 22)
		label.ZIndex = 12
		label.Parent = summaryFrame
		summaryLabels[key] = label
	end
	
	-- Create scroll frame for errors
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ErrorsScrollFrame"
	scrollFrame.Size = UDim2.new(1, 0, 1, -145)
	scrollFrame.Position = UDim2.new(0, 0, 0, 135)
	scrollFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 12
	scrollFrame.ZIndex = 11
	scrollFrame.Parent = frame
	
	-- Create error list layout
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = scrollFrame
	
	-- Create dev mode controls
	local devControlsFrame = Instance.new("Frame")
	devControlsFrame.Name = "DevControlsFrame"
	devControlsFrame.Size = UDim2.new(1, 0, 0, 40)
	devControlsFrame.Position = UDim2.new(0, 0, 1, -40)
	devControlsFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	devControlsFrame.BorderSizePixel = 0
	devControlsFrame.ZIndex = 11
	devControlsFrame.Parent = frame
	
	-- Create dev buttons
	local printReportButton = Instance.new("TextButton")
	printReportButton.Name = "PrintReportButton"
	printReportButton.Text = "Print Report"
	printReportButton.Font = Enum.Font.Gotham
	printReportButton.TextSize = 14
	printReportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	printReportButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	printReportButton.BorderSizePixel = 0
	printReportButton.Size = UDim2.new(0, 120, 0, 25)
	printReportButton.Position = UDim2.new(0, 10, 0, 8)
	printReportButton.ZIndex = 12
	printReportButton.Parent = devControlsFrame
	
	-- Bind events
	refreshButton.MouseButton1Click:Connect(function()
		DeveloperDashboardController.RefreshData()
	end)
	
	autoRefreshToggle.MouseButton1Click:Connect(function()
		autoRefreshEnabled = not autoRefreshEnabled
		autoRefreshToggle.Text = "Auto: " .. (autoRefreshEnabled and "ON" or "OFF")
	end)
	
	printReportButton.MouseButton1Click:Connect(function()
		DeveloperDashboardController.PrintReport()
	end)
	
	-- Toggle visibility with F9
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F9 then
			frame.Visible = not frame.Visible
		end
	end)
	
	return frame
end

-- UI update functions
local function updateSummaryUI(summary)
	if not dashboardFrame then
		return
	end
	
	local summaryFrame = dashboardFrame:FindFirstChild("SummaryFrame")
	if not summaryFrame then
		return
	end
	
	local totalErrorsLabel = summaryFrame:FindFirstChild("TotalErrorsLabel")
	local uniqueServicesLabel = summaryFrame:FindFirstChild("UniqueServicesLabel")
	local mostProblematicLabel = summaryFrame:FindFirstChild("MostProblematicLabel")
	local lastUpdatedLabel = summaryFrame:FindFirstChild("LastUpdatedLabel")
	
	if totalErrorsLabel then
		totalErrorsLabel.Text = string.format("Total Errors: %d", summary.totalErrors)
	end
	
	if uniqueServicesLabel then
		uniqueServicesLabel.Text = string.format("Unique Services: %d", summary.uniqueServices)
	end
	
	if mostProblematicLabel then
		mostProblematicLabel.Text = string.format("Most Problematic: %s", summary.mostProblematicService or "None")
	end
	
	if lastUpdatedLabel then
		local timeStr = os.date("%H:%M:%S", summary.timestamp)
		lastUpdatedLabel.Text = string.format("Last Updated: %s", timeStr)
	end
end

local function updateErrorsUI(recentErrors)
	if not dashboardFrame then
		return
	end
	
	local scrollFrame = dashboardFrame:FindFirstChild("ErrorsScrollFrame")
	if not scrollFrame then
		return
	end
	
	-- Clear existing error entries
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("^ErrorEntry") then
			child:Destroy()
		end
	end
	
	-- Create error entries
	for i, error in ipairs(recentErrors) do
		local entryFrame = Instance.new("Frame")
		entryFrame.Name = "ErrorEntry" .. i
		entryFrame.Size = UDim2.new(1, -10, 0, 80)
		entryFrame.Position = UDim2.new(0, 5, 0, (i-1) * 85)
		entryFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		entryFrame.BorderSizePixel = 0
		entryFrame.ZIndex = 12
		entryFrame.Parent = scrollFrame
		
		-- Severity indicator
		local severityColor = Color3.fromRGB(100, 100, 100)
		if error.severity == 4 then severityColor = Color3.fromRGB(255, 50, 50)
		elseif error.severity == 3 then severityColor = Color3.fromRGB(255, 150, 50)
		elseif error.severity == 2 then severityColor = Color3.fromRGB(255, 200, 50)
		else severityColor = Color3.fromRGB(100, 200, 255) end
		
		local severityBar = Instance.new("Frame")
		severityBar.Size = UDim2.new(0, 5, 1, 0)
		severityBar.BackgroundColor3 = severityColor
		severityBar.BorderSizePixel = 0
		severityBar.ZIndex = 13
		severityBar.Parent = entryFrame
		
		-- Error details
		local errorTypeLabel = Instance.new("TextLabel")
		errorTypeLabel.Text = string.format("%s - %s", error.errorType, error.serviceName)
		errorTypeLabel.Font = Enum.Font.GothamBold
		errorTypeLabel.TextSize = 14
		errorTypeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		errorTypeLabel.BackgroundTransparency = 1
		errorTypeLabel.Size = UDim2.new(1, -10, 0, 20)
		errorTypeLabel.Position = UDim2.new(0, 10, 0, 5)
		errorTypeLabel.ZIndex = 13
		errorTypeLabel.Parent = entryFrame
		
		local messageLabel = Instance.new("TextLabel")
		messageLabel.Text = error.shortMessage
		messageLabel.Font = Enum.Font.Gotham
		messageLabel.TextSize = 12
		messageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		messageLabel.BackgroundTransparency = 1
		messageLabel.Size = UDim2.new(1, -10, 0, 20)
		messageLabel.Position = UDim2.new(0, 10, 0, 25)
		messageLabel.ZIndex = 13
		messageLabel.Parent = entryFrame
		
		local countLabel = Instance.new("TextLabel")
		countLabel.Text = string.format("Count: %d | Players: %d", error.totalCount, error.uniquePlayerCount)
		countLabel.Font = Enum.Font.Gotham
		countLabel.TextSize = 12
		countLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		countLabel.BackgroundTransparency = 1
		countLabel.Size = UDim2.new(1, -10, 0, 20)
		countLabel.Position = UDim2.new(0, 10, 0, 45)
		countLabel.ZIndex = 13
		countLabel.Parent = entryFrame
	end
end

-- Remote function call
local function getDashboardData()
	if not CONFIG.ENABLED then
		return nil
	end
	
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		return nil
	end
	
	local getDashboardDataRemote = remotesFolder:FindFirstChild("GetDashboardData")
	if not getDashboardDataRemote or not getDashboardDataRemote:IsA("RemoteFunction") then
		return nil
	end
	
	local success, result = pcall(function()
		return getDashboardDataRemote:InvokeServer()
	end)
	
	if success and result then
		return result
	else
		log("warn", "Failed to get dashboard data:", result)
		return nil
	end
end

-- Public API functions
function DeveloperDashboardController.Init()
	if not CONFIG.ENABLED then
		log("info", "Developer Dashboard Controller disabled (not in Studio)")
		return false
	end
	
	if isInitialized then
		return true
	end
	
	dashboardFrame = createDashboardUI()
	if dashboardFrame then
		dashboardFrame.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		isInitialized = true
		
		-- Start auto-refresh loop
		task.spawn(function()
			while isInitialized do
				if autoRefreshEnabled and (tick() - lastRefreshTime) > CONFIG.AUTO_REFRESH_INTERVAL then
					DeveloperDashboardController.RefreshData()
				end
				task.wait(5)
			end
		end)
		
		log("info", "Developer Dashboard Controller initialized")
		return true
	else
		log("error", "Failed to create dashboard UI")
		return false
	end
end

function DeveloperDashboardController.RefreshData()
	if not CONFIG.ENABLED or not isInitialized then
		return
	end
	
	local data = getDashboardData()
	if data and data.enabled and data.summary then
		updateSummaryUI(data.summary)
		updateErrorsUI(data.summary.recentErrors)
		lastRefreshTime = tick()
		log("info", "Dashboard refreshed with", #data.summary.recentErrors, "errors")
	end
end

function DeveloperDashboardController.PrintReport()
	if not CONFIG.ENABLED then
		return
	end
	
	local data = getDashboardData()
	if data and data.enabled and data.summary then
		print("=== System Incremental Production Error Report ===")
		print(string.format("Total Errors: %d", data.summary.totalErrors))
		print(string.format("Unique Services: %d", data.summary.uniqueServices))
		print(string.format("Most Problematic Service: %s", data.summary.mostProblematicService or "None"))
		print("")
		
		if data.summary.totalErrors > 0 then
			print("Recent Errors:")
			for i, error in ipairs(data.summary.recentErrors) do
				local severityText = ""
				if error.severity == 4 then severityText = "🔴 CRITICAL"
				elseif error.severity == 3 then severityText = "🟠 HIGH"
				elseif error.severity == 2 then severityText = "🟡 MEDIUM"
				else severityText = "🔵 LOW" end
				
				print(string.format("  %d. %s - %s", i, severityText, error.errorType))
				print(string.format("     Service: %s", error.serviceName))
				print(string.format("     Message: %s", error.shortMessage))
				print(string.format("     Count: %d, Players: %d", error.totalCount, error.uniquePlayerCount))
				print("")
			end
		else
			print("No production errors found in the last 24 hours.")
		end
	else
		print("Failed to fetch dashboard data")
	end
end

function DeveloperDashboardController.Show()
	if dashboardFrame then
		dashboardFrame.Visible = true
	end
end

function DeveloperDashboardController.Hide()
	if dashboardFrame then
		dashboardFrame.Visible = false
	end
end

function DeveloperDashboardController.Toggle()
	if dashboardFrame then
		dashboardFrame.Visible = not dashboardFrame.Visible
	end
end

-- Initialize service
function DeveloperDashboardController.OnStart()
	if CONFIG.ENABLED then
		DeveloperDashboardController.Init()
	end
end

return DeveloperDashboardController
