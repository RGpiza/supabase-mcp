local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local starterGui = game:GetService("StarterGui")

-- Configuration
local CONFIG = {
	THEME = {
		Background = Color3.fromHex("#0F1115"),
		Panel = Color3.fromHex("#151922"),
		Accent = Color3.fromHex("#00E5FF"),
		Accent2 = Color3.fromHex("#B388FF"),
		Text = Color3.fromHex("#E6E6E6"),
		TextMuted = Color3.fromHex("#A0A0A0"),
		Border = Color3.fromHex("#2A3040"),
		Success = Color3.fromHex("#00C853"),
		Warning = Color3.fromHex("#FFB300"),
		Error = Color3.fromHex("#FF3D00"),
		Info = Color3.fromHex("#29B6F6"),
	},
	SPACING = {
		Small = 8,
		Medium = 12,
		Large = 16,
		XLarge = 24,
	},
	CORNER_RADIUS = 12,
	BORDER_SIZE = 1,
	NOTIFICATION_MAX = 5,
	REFRESH_COOLDOWN = 5,
}

-- UI Helpers
local function createFrame(name, parent, size, position, backgroundColor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position or UDim2.new(0, 0, 0, 0)
	frame.BackgroundColor3 = backgroundColor or CONFIG.THEME.Panel
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false
	frame.Parent = parent
	return frame
end

local function createTextLabel(name, parent, text, fontSize, textColor, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = fontSize or 14
	label.TextColor3 = textColor or CONFIG.THEME.Text
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, fontSize or 16)
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function createTextButton(name, parent, text, fontSize, textColor, backgroundColor)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = fontSize or 14
	btn.TextColor3 = textColor or CONFIG.THEME.Text
	btn.BackgroundColor3 = backgroundColor or CONFIG.THEME.Panel
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(1, 0, 0, fontSize * 1.8)
	btn.Parent = parent
	return btn
end

local function createUICorner(parent)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
	corner.Parent = parent
	return corner
end

local function createUIStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or CONFIG.THEME.Border
	stroke.Thickness = thickness or CONFIG.BORDER_SIZE
	stroke.Parent = parent
	return stroke
end

local function createGradient(parent, color1, color2)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)})
	gradient.Parent = parent
	return gradient
end

-- State Management
local state = {
	dataAmount = 0,
	dps = 0,
	prestige = 0,
	prestigePoints = 0,
	autoBuy = {CPU = false, RAM = false, STO = false},
	leaderboard = {},
	community = {likes = 0, favorites = 0, likeGoal = 100},
	activeTab = "Stats",
	notifications = {},
}

local function setState(partial)
	for k, v in pairs(partial) do
		state[k] = v
	end
	updateUI()
end

-- Remote References
local remotes = {
	RequestPrestige = ReplicatedStorage:FindFirstChild("RequestPrestige"),
	GetLeaderboard = ReplicatedStorage:FindFirstChild("GetLeaderboard"),
	GetCommunityStats = ReplicatedStorage:FindFirstChild("GetCommunityStats"),
	ToggleAutoBuy = ReplicatedStorage:FindFirstChild("ToggleAutoBuy"),
}

-- Upgrade Definitions (fallback)
local upgradeDefs = {
	CPU = {
		{Id = "cpu_1", Name = "CPU Core", Cost = 10, DPS = 1, MaxLevel = 100},
		{Id = "cpu_2", Name = "CPU Array", Cost = 1000, DPS = 10, MaxLevel = 50},
		{Id = "cpu_3", Name = "CPU Cluster", Cost = 100000, DPS = 100, MaxLevel = 20},
	},
	RAM = {
		{Id = "ram_1", Name = "RAM Module", Cost = 50, DPS = 2, MaxLevel = 100},
		{Id = "ram_2", Name = "RAM Bank", Cost = 5000, DPS = 20, MaxLevel = 50},
	},
	STO = {
		{Id = "sto_1", Name = "Storage Drive", Cost = 100, DPS = 3, MaxLevel = 100},
		{Id = "sto_2", Name = "Storage Array", Cost = 10000, DPS = 30, MaxLevel = 50},
		{Id = "sto_3", Name = "Storage Cluster", Cost = 1000000, DPS = 300, MaxLevel = 20},
	},
}

-- UI Construction
local function buildUI()
	-- Clone or create TerminalUI
	local terminalUI = playerGui:FindFirstChild("TerminalUI")
	if not terminalUI then
		local template = game:GetService("StarterGui"):FindFirstChild("TerminalUI")
		if template then
			terminalUI = template:Clone()
			terminalUI.Parent = playerGui
		else
			terminalUI = Instance.new("ScreenGui")
			terminalUI.Name = "TerminalUI"
			terminalUI.ResetOnSpawn = false
			terminalUI.Parent = playerGui
		end
	end

	-- Root container
	local root = createFrame("Root", terminalUI, UDim2.new(1, 0, 1, 0))
	createUICorner(root)
	createUIStroke(root, CONFIG.THEME.Border)

	-- SafeArea
	local safeArea = createFrame("SafeArea", root, UDim2.new(1, 0, 1, 0))
	local uiPadding = Instance.new("UIPadding")
	uiPadding.PaddingTop = UDim.new(0, 10)
	uiPadding.PaddingBottom = UDim.new(0, 10)
	uiPadding.PaddingLeft = UDim.new(0, 10)
	uiPadding.PaddingRight = UDim.new(0, 10)
	uiPadding.Parent = safeArea

	-- TopBar
	local topBar = createFrame("TopBar", safeArea, UDim2.new(1, 0, 0, 60))
	createUICorner(topBar)
	createUIStroke(topBar, CONFIG.THEME.Border)
	topBar.Position = UDim2.new(0, 0, 0, 0)

	-- Title
	local title = createTextLabel("Title", topBar, "System Incremental", 20, CONFIG.THEME.Text)
	title.Position = UDim2.new(0, 16, 0, 16)
	title.Size = UDim2.new(0, 200, 0, 24)

	-- Data Counter
	local dataLabel = createTextLabel("DataLabel", topBar, "Data: 0", 16, CONFIG.THEME.Text)
	dataLabel.Position = UDim2.new(0, 240, 0, 16)
	dataLabel.Size = UDim2.new(0, 200, 0, 20)

	-- Prestige Counter
	local prestigeLabel = createTextLabel("PrestigeLabel", topBar, "Prestige: 0", 16, CONFIG.THEME.Text)
	prestigeLabel.Position = UDim2.new(0, 460, 0, 16)
	prestigeLabel.Size = UDim2.new(0, 200, 0, 20)

	-- Store Button
	local storeBtn = createTextButton("StoreBtn", topBar, "Store", 14, CONFIG.THEME.Text, CONFIG.THEME.Accent)
	storeBtn.Position = UDim2.new(1, -120, 0, 16)
	storeBtn.Size = UDim2.new(0, 100, 0, 32)
	createUICorner(storeBtn)
	createUIStroke(storeBtn, CONFIG.THEME.Border)

	-- Notification Anchor
	local notifAnchor = Instance.new("Frame")
	notifAnchor.Name = "NotificationAnchor"
	notifAnchor.Size = UDim2.new(0, 300, 0, 0)
	notifAnchor.Position = UDim2.new(1, -320, 0, 60)
	notifAnchor.BackgroundTransparency = 1
	notifAnchor.Parent = topBar

	-- Main Content
	local main = createFrame("Main", safeArea, UDim2.new(1, 0, 1, -70))
	main.Position = UDim2.new(0, 0, 0, 70)
	main.ClipsDescendants = true

	-- Left Panel (Columns)
	local leftPanel = createFrame("LeftPanel", main, UDim2.new(0.6, 0, 1, 0))
	leftPanel.Position = UDim2.new(0, 0, 0, 0)
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.FillDirection = Enum.FillDirection.Horizontal
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	leftLayout.Padding = UDim.new(0, CONFIG.SPACING.Medium)
	leftLayout.Parent = leftPanel

	-- Column Template
	local function createColumn(name, titleText)
		local col = createFrame(name, leftPanel, UDim2.new(0.32, 0, 1, 0))
		createUICorner(col)
		createUIStroke(col, CONFIG.THEME.Border)

		local header = createTextLabel("Header", col, titleText, 16, CONFIG.THEME.Text)
		header.Position = UDim2.new(0, 12, 0, 8)
		header.Size = UDim2.new(1, -24, 0, 24)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Scroll"
		scroll.Size = UDim2.new(1, 0, 1, -60)
		scroll.Position = UDim2.new(0, 0, 0, 40)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.ScrollBarImageColor3 = CONFIG.THEME.Border
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.Parent = col

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, CONFIG.SPACING.Small)
		layout.Parent = scroll

		local autoBtn = createTextButton("AutoBtn", col, "Auto: OFF", 14, CONFIG.THEME.Text, CONFIG.THEME.Panel)
		autoBtn.Position = UDim2.new(0, 12, 1, -36)
		autoBtn.Size = UDim2.new(1, -24, 0, 28)
		createUICorner(autoBtn)
		createUIStroke(autoBtn, CONFIG.THEME.Border)

		return {Frame = col, Scroll = scroll, AutoBtn = autoBtn}
	end

	local cpuCol = createColumn("CPUColumn", "CPU")
	local ramCol = createColumn("RAMColumn", "RAM")
	local stoCol = createColumn("STOColumn", "STORAGE")

	-- Right Panel (Tabs)
	local rightPanel = createFrame("RightPanel", main, UDim2.new(0.68, 0, 1, 0))
	rightPanel.Position = UDim2.new(0.6, 0, 0, 0)
	createUICorner(rightPanel)
	createUIStroke(rightPanel, CONFIG.THEME.Border)

	-- Tabs Row
	local tabsRow = createFrame("TabsRow", rightPanel, UDim2.new(1, 0, 0, 40))
	tabsRow.Position = UDim2.new(0, 0, 0, 0)
	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	tabsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabsLayout.Padding = UDim.new(0, 4)
	tabsLayout.Parent = tabsRow

	-- Tab Buttons
	local tabs = {"Stats", "Prestige", "Leaderboards", "Community", "Events"}
	local tabButtons = {}

	for _, tabName in ipairs(tabs) do
		local btn = createTextButton(tabName .. "Tab", tabsRow, tabName, 14, CONFIG.THEME.Text, CONFIG.THEME.Panel)
		btn.Size = UDim2.new(0, 120, 1, 0)
		createUICorner(btn)
		createUIStroke(btn, CONFIG.THEME.Border)
		table.insert(tabButtons, btn)
	end

	-- Pages Container
	local pages = createFrame("Pages", rightPanel, UDim2.new(1, 0, 1, -40))
	pages.Position = UDim2.new(0, 0, 0, 40)
	pages.ClipsDescendants = true

	-- Stats Page
	local statsPage = createFrame("StatsPage", pages, UDim2.new(1, 0, 1, 0))
	statsPage.Visible = true
	local statsLayout = Instance.new("UIListLayout")
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Padding = UDim.new(0, CONFIG.SPACING.Medium)
	statsLayout.Parent = statsPage

	local dpsLabel = createTextLabel("DPSLabel", statsPage, "DPS: 0", 16, CONFIG.THEME.Text)
	dpsLabel.Size = UDim2.new(1, 0, 0, 24)

	local ppLabel = createTextLabel("PPLabel", statsPage, "Prestige Points: 0", 16, CONFIG.THEME.Text)
	ppLabel.Size = UDim2.new(1, 0, 0, 24)

	local prestigeBox = createFrame("PrestigeBox", statsPage, UDim2.new(1, 0, 0, 60))
	createUICorner(prestigeBox)
	createUIStroke(prestigeBox, CONFIG.THEME.Border)
	prestigeBox.BackgroundColor3 = CONFIG.THEME.Panel

	local prestigeBtn = createTextButton("PrestigeBtn", prestigeBox, "PRESTIGE", 16, CONFIG.THEME.Text, CONFIG.THEME.Accent)
	prestigeBtn.Position = UDim2.new(0, 12, 0, 12)
	prestigeBtn.Size = UDim2.new(1, -24, 1, -24)
	createUICorner(prestigeBtn)
	createUIStroke(prestigeBtn, CONFIG.THEME.Border)

	-- Prestige Page
	local prestigePage = createFrame("PrestigePage", pages, UDim2.new(1, 0, 1, 0))
	prestigePage.Visible = false
	local prestigeCanvas = Instance.new("ScrollingFrame")
	prestigeCanvas.Name = "Canvas"
	prestigeCanvas.Size = UDim2.new(1, 0, 1, 0)
	prestigeCanvas.BackgroundTransparency = 1
	prestigeCanvas.ScrollBarThickness = 8
	prestigeCanvas.CanvasSize = UDim2.new(0, 0, 0, 600)
	prestigeCanvas.Parent = prestigePage

	-- Leaderboards Page
	local leaderboardsPage = createFrame("LeaderboardsPage", pages, UDim2.new(1, 0, 1, 0))
	leaderboardsPage.Visible = false
	local lbLayout = Instance.new("UIListLayout")
	lbLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lbLayout.Padding = UDim.new(0, CONFIG.SPACING.Small)
	lbLayout.Parent = leaderboardsPage

	local lbHeader = createTextLabel("LBHeader", leaderboardsPage, "Global Leaderboard", 18, CONFIG.THEME.Text)
	lbHeader.Size = UDim2.new(1, 0, 0, 30)

	local lbScroll = Instance.new("ScrollingFrame")
	lbScroll.Name = "LBScroll"
	lbScroll.Size = UDim2.new(1, 0, 1, -80)
	lbScroll.Position = UDim2.new(0, 0, 0, 40)
	lbScroll.BackgroundTransparency = 1
	lbScroll.ScrollBarThickness = 6
	lbScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	lbScroll.Parent = leaderboardsPage

	local lbListLayout = Instance.new("UIListLayout")
	lbListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lbListLayout.Padding = UDim.new(0, 4)
	lbListLayout.Parent = lbScroll

	local yourRankLabel = createTextLabel("YourRank", leaderboardsPage, "Your Rank: --", 14, CONFIG.THEME.TextMuted)
	yourRankLabel.Size = UDim2.new(1, 0, 0, 24)
	yourRankLabel.Position = UDim2.new(0, 0, 1, -30)

	-- Community Page
	local communityPage = createFrame("CommunityPage", pages, UDim2.new(1, 0, 1, 0))
	communityPage.Visible = false
	local commLayout = Instance.new("UIListLayout")
	commLayout.SortOrder = Enum.SortOrder.LayoutOrder
	commLayout.Padding = UDim.new(0, CONFIG.SPACING.Medium)
	commLayout.Parent = communityPage

	local likesLabel = createTextLabel("LikesLabel", communityPage, "Likes: 0 / 100", 16, CONFIG.THEME.Text)
	likesLabel.Size = UDim2.new(1, 0, 0, 24)

	local favLabel = createTextLabel("FavLabel", communityPage, "Favorites: 0", 16, CONFIG.THEME.Text)
	favLabel.Size = UDim2.new(1, 0, 0, 24)

	local refreshLabel = createTextLabel("RefreshLabel", communityPage, "Next refresh in: --", 12, CONFIG.THEME.TextMuted)
	refreshLabel.Size = UDim2.new(1, 0, 0, 20)

	-- Events Page
	local eventsPage = createFrame("EventsPage", pages, UDim2.new(1, 0, 1, 0))
	eventsPage.Visible = false
	local eventsLabel = createTextLabel("EventsLabel", eventsPage, "Events\nComing soon", 18, CONFIG.THEME.Text)
	eventsLabel.Size = UDim2.new(1, 0, 1, 0)
	eventsLabel.TextYAlignment = Enum.TextYAlignment.Center
	eventsLabel.TextXAlignment = Enum.TextXAlignment.Center

	-- Notification System
	local notifications = createFrame("Notifications", notifAnchor, UDim2.new(1, 0, 0, 0))
	notifications.BackgroundTransparency = 1
	notifications.Position = UDim2.new(0, 0, 0, 0)
	local notifLayout = Instance.new("UIListLayout")
	notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notifLayout.Padding = UDim.new(0, CONFIG.SPACING.Small)
	notifLayout.Parent = notifications

	-- Build Upgrade Cards
	local function buildUpgradeCards()
		-- CPU Cards
		for _, def in ipairs(upgradeDefs.CPU) do
			local card = createFrame(def.Id, cpuCol.Scroll, UDim2.new(1, 0, 0, 40))
			createUICorner(card)
			createUIStroke(card, CONFIG.THEME.Border)
			card.BackgroundColor3 = CONFIG.THEME.Panel

			local name = createTextLabel("Name", card, def.Name, 14, CONFIG.THEME.Text)
			name.Position = UDim2.new(0, 10, 0, 8)
			name.Size = UDim2.new(0.5, -20, 0, 24)

			local cost = createTextLabel("Cost", card, "Cost: " .. def.Cost, 12, CONFIG.THEME.TextMuted)
			cost.Position = UDim2.new(0.5, -80, 0, 8)
			cost.Size = UDim2.new(0.4, 0, 0, 20)

			local buyBtn = createTextButton("BuyBtn", card, "Buy", 12, CONFIG.THEME.Text, CONFIG.THEME.Accent)
			buyBtn.Position = UDim2.new(1, -60, 0, 8)
			buyBtn.Size = UDim2.new(0, 50, 0, 24)
			createUICorner(buyBtn)
			createUIStroke(buyBtn, CONFIG.THEME.Border)
		end

		-- RAM Cards
		for _, def in ipairs(upgradeDefs.RAM) do
			local card = createFrame(def.Id, ramCol.Scroll, UDim2.new(1, 0, 0, 40))
			createUICorner(card)
			createUIStroke(card, CONFIG.THEME.Border)
			card.BackgroundColor3 = CONFIG.THEME.Panel

			local name = createTextLabel("Name", card, def.Name, 14, CONFIG.THEME.Text)
			name.Position = UDim2.new(0, 10, 0, 8)
			name.Size = UDim2.new(0.5, -20, 0, 24)

			local cost = createTextLabel("Cost", card, "Cost: " .. def.Cost, 12, CONFIG.THEME.TextMuted)
			cost.Position = UDim2.new(0.5, -80, 0, 8)
			cost.Size = UDim2.new(0.4, 0, 0, 20)

			local buyBtn = createTextButton("BuyBtn", card, "Buy", 12, CONFIG.THEME.Text, CONFIG.THEME.Accent)
			buyBtn.Position = UDim2.new(1, -60, 0, 8)
			buyBtn.Size = UDim2.new(0, 50, 0, 24)
			createUICorner(buyBtn)
			createUIStroke(buyBtn, CONFIG.THEME.Border)
		end

		-- STO Cards
		for _, def in ipairs(upgradeDefs.STO) do
			local card = createFrame(def.Id, stoCol.Scroll, UDim2.new(1, 0, 0, 40))
			createUICorner(card)
			createUIStroke(card, CONFIG.THEME.Border)
			card.BackgroundColor3 = CONFIG.THEME.Panel

			local name = createTextLabel("Name", card, def.Name, 14, CONFIG.THEME.Text)
			name.Position = UDim2.new(0, 10, 0, 8)
			name.Size = UDim2.new(0.5, -20, 0, 24)

			local cost = createTextLabel("Cost", card, "Cost: " .. def.Cost, 12, CONFIG.THEME.TextMuted)
			cost.Position = UDim2.new(0.5, -80, 0, 8)
			cost.Size = UDim2.new(0.4, 0, 0, 20)

			local buyBtn = createTextButton("BuyBtn", card, "Buy", 12, CONFIG.THEME.Text, CONFIG.THEME.Accent)
			buyBtn.Position = UDim2.new(1, -60, 0, 8)
			buyBtn.Size = UDim2.new(0, 50, 0, 24)
			createUICorner(buyBtn)
			createUIStroke(buyBtn, CONFIG.THEME.Border)
		end
	end

	buildUpgradeCards()

	-- Wiring
	local function switchTab(tabName)
		if state.activeTab == tabName then return end
		state.activeTab = tabName
		for _, pageName in ipairs({"StatsPage", "PrestigePage", "LeaderboardsPage", "CommunityPage", "EventsPage"}) do
			local page = pages:FindFirstChild(pageName)
			if page then
				page.Visible = pageName == tabName .. "Page"
			end
		end
		-- Update tab button styles
		for _, btn in ipairs(tabButtons) do
			local isActive = btn.Name == tabName .. "Tab"
			btn.BackgroundColor3 = isActive and CONFIG.THEME.Accent or CONFIG.THEME.Panel
			btn.TextColor3 = isActive and CONFIG.THEME.Background or CONFIG.THEME.Text
		end
	end

	-- Tab Clicks
	for _, btn in ipairs(tabButtons) do
		btn.MouseButton1Click:Connect(function()
			switchTab(btn.Name:gsub("Tab$", ""))
		end)
	end

	-- AutoBuy Toggles
	cpuCol.AutoBtn.MouseButton1Click:Connect(function()
		state.autoBuy.CPU = not state.autoBuy.CPU
		cpuCol.AutoBtn.Text = "Auto: " .. (state.autoBuy.CPU and "ON" or "OFF")
		cpuCol.AutoBtn.BackgroundColor3 = state.autoBuy.CPU and CONFIG.THEME.Success or CONFIG.THEME.Panel
		-- Send remote if exists
		if remotes.ToggleAutoBuy then
			pcall(remotes.ToggleAutoBuy:FireServer, {category = "CPU", enabled = state.autoBuy.CPU})
		end
	end)

	ramCol.AutoBtn.MouseButton1Click:Connect(function()
		state.autoBuy.RAM = not state.autoBuy.RAM
		ramCol.AutoBtn.Text = "Auto: " .. (state.autoBuy.RAM and "ON" or "OFF")
		ramCol.AutoBtn.BackgroundColor3 = state.autoBuy.RAM and CONFIG.THEME.Success or CONFIG.THEME.Panel
		if remotes.ToggleAutoBuy then
			pcall(remotes.ToggleAutoBuy:FireServer, {category = "RAM", enabled = state.autoBuy.RAM})
		end
	end)

	stoCol.AutoBtn.MouseButton1Click:Connect(function()
		state.autoBuy.STO = not state.autoBuy.STO
		stoCol.AutoBtn.Text = "Auto: " .. (state.autoBuy.STO and "ON" or "OFF")
		stoCol.AutoBtn.BackgroundColor3 = state.autoBuy.STO and CONFIG.THEME.Success or CONFIG.THEME.Panel
		if remotes.ToggleAutoBuy then
			pcall(remotes.ToggleAutoBuy:FireServer, {category = "STO", enabled = state.autoBuy.STO})
		end
	end)

	-- Prestige Button
	prestigeBtn.MouseButton1Click:Connect(function()
		if remotes.RequestPrestige then
			pcall(remotes.RequestPrestige:FireServer)
		else
			notify("Prestige", "Remote not available", "warn")
		end
	end)

	-- Store Button
	storeBtn.MouseButton1Click:Connect(function()
		notify("Store", "Store coming soon", "info")
	end)

	-- Notifications System
	local function notify(title, body, kind)
		-- Remove oldest if max reached
		if #state.notifications >= CONFIG.NOTIFICATION_MAX then
			table.remove(state.notifications, 1)
		end
		local id = HttpService:GenerateGUID(false)
		local notif = {
			Id = id,
			Title = title,
			Body = body,
			Kind = kind or "info",
			Created = tick(),
		}
		table.insert(state.notifications, notif)
		renderNotifications()
	end

	local function renderNotifications()
		-- Clear existing
		for _, child in ipairs(notifications:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "UIListLayout" then
				child:Destroy()
			end
		end
		-- Render
		for _, notif in ipairs(state.notifications) do
			local frame = createFrame(notif.Id, notifications, UDim2.new(1, 0, 0, 60))
			createUICorner(frame)
			createUIStroke(frame, CONFIG.THEME.Border)
			local color = CONFIG.THEME[notif.Kind:upper()] or CONFIG.THEME.INFO
			frame.BackgroundColor3 = color
			frame.BackgroundTransparency = 0.9

			local title = createTextLabel("Title", frame, notif.Title, 14, CONFIG.THEME.Text)
			title.Position = UDim2.new(0, 10, 0, 8)
			title.Size = UDim2.new(1, -20, 0, 20)

			local body = createTextLabel("Body", frame, notif.Body, 12, CONFIG.THEME.TextMuted)
			body.Position = UDim2.new(0, 10, 0, 30)
			body.Size = UDim2.new(1, -20, 0, 20)

			local closeBtn = createTextButton("Close", frame, "×", 16, CONFIG.THEME.Text, CONFIG.THEME.Panel)
			closeBtn.Position = UDim2.new(1, -30, 0, 8)
			closeBtn.Size = UDim2.new(0, 20, 0, 20)
			createUICorner(closeBtn)
			closeBtn.MouseButton1Click:Connect(function()
				state.notifications = table.create(#state.notifications - 1)
				for i, n in ipairs(state.notifications) do
					if n.Id ~= notif.Id then
						table.insert(state.notifications, n)
					end
				end
				renderNotifications()
			end)
		end
	end

	-- Leaderboard Refresh
	local lastLBRefresh = 0
	local function refreshLeaderboard()
		local now = tick()
		if now - lastLBRefresh < CONFIG.REFRESH_COOLDOWN then
			notify("Leaderboard", "Please wait before refreshing", "warn")
			return
		end
		lastLBRefresh = now
		if remotes.GetLeaderboard then
			local success, result = pcall(remotes.GetLeaderboard:InvokeServer, "global", 1)
			if success and type(result) == "table" then
				setState({leaderboard = result})
			else
				-- Fallback dummy data
				local dummy = {}
				for i = 1, 20 do
					table.insert(dummy, {userId = i, name = "Player" .. i, value = math.random(1000, 100000)})
				end
				setState({leaderboard = dummy})
			end
		else
			-- Fallback dummy data
			local dummy = {}
			for i = 1, 20 do
				table.insert(dummy, {userId = i, name = "Player" .. i, value = math.random(1000, 100000)})
			end
			setState({leaderboard = dummy})
		end
	end

	-- Community Refresh
	local lastCommRefresh = 0
	local function refreshCommunity()
		local now = tick()
		if now - lastCommRefresh < CONFIG.REFRESH_COOLDOWN then
			notify("Community", "Please wait before refreshing", "warn")
			return
		end
		lastCommRefresh = now
		if remotes.GetCommunityStats then
			local success, result = pcall(remotes.GetCommunityStats:InvokeServer)
			if success and type(result) == "table" then
				setState({community = result})
			else
				setState({community = {likes = math.random(0, 100), favorites = math.random(0, 50), likeGoal = 100}})
			end
		else
			setState({community = {likes = math.random(0, 100), favorites = math.random(0, 50), likeGoal = 100}})
		end
	end

	-- Auto-refresh timers
	task.spawn(function()
		while true do
			task.wait(1)
			-- Update refresh labels
			if state.activeTab == "Leaderboards" then
				local remaining = math.max(0, CONFIG.REFRESH_COOLDOWN - (tick() - lastLBRefresh))
				lbHeader.Text = "Global Leaderboard (" .. string.format("%.0f", remaining) .. "s)"
			end
			if state.activeTab == "Community" then
				local remaining = math.max(0, CONFIG.REFRESH_COOLDOWN - (tick() - lastCommRefresh))
				refreshLabel.Text = "Next refresh in: " .. string.format("%.0f", remaining) .. "s"
			end
		end
	end)

	-- Initial refresh
	refreshLeaderboard()
	refreshCommunity()

	-- Expose notify function globally for other scripts
	_G.SystemIncrementalNotify = notify

	-- Initial tab
	switchTab("Stats")

	return {
		notify = notify,
		refreshLeaderboard = refreshLeaderboard,
		refreshCommunity = refreshCommunity,
	}
end

-- UI Update
local function updateUI()
	-- TopBar
	local dataLabel = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("TopBar") and playerGui.TerminalUI.Root.SafeArea.TopBar:FindFirstChild("DataLabel")
	local prestigeLabel = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("TopBar") and playerGui.TerminalUI.Root.SafeArea.TopBar:FindFirstChild("PrestigeLabel")

	if dataLabel then
		dataLabel.Text = "Data: " .. string.format("%s", state.dataAmount)
	end
	if prestigeLabel then
		prestigeLabel.Text = "Prestige: " .. state.prestige
	end

	-- Stats Page
	local dpsLabel = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("Main") and playerGui.TerminalUI.Root.SafeArea.Main:FindFirstChild("RightPanel") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel:FindFirstChild("Pages") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages:FindFirstChild("StatsPage") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages.StatsPage:FindFirstChild("DPSLabel")
	local ppLabel = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("Main") and playerGui.TerminalUI.Root.SafeArea.Main:FindFirstChild("RightPanel") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel:FindFirstChild("Pages") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages:FindFirstChild("StatsPage") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages.StatsPage:FindFirstChild("PPLabel")

	if dpsLabel then
		dpsLabel.Text = "DPS: " .. state.dps
	end
	if ppLabel then
		ppLabel.Text = "Prestige Points: " .. state.prestigePoints
	end

	-- AutoBuy Buttons
	local cpuCol = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("Main") and playerGui.TerminalUI.Root.SafeArea.Main:FindFirstChild("LeftPanel") and playerGui.TerminalUI.Root.SafeArea.Main.LeftPanel:FindFirstChild("CPUColumn")
	local ramCol = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("Main") and playerGui.TerminalUI.Root.SafeArea.Main:FindFirstChild("LeftPanel") and playerGui.TerminalUI.Root.SafeArea.Main.LeftPanel:FindFirstChild("RAMColumn")
	local stoCol = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("Main") and playerGui.TerminalUI.Root.SafeArea.Main:FindFirstChild("LeftPanel") and playerGui.TerminalUI.Root.SafeArea.Main.LeftPanel:FindFirstChild("STOColumn")

	if cpuCol and cpuCol:FindFirstChild("AutoBtn") then
		cpuCol.AutoBtn.Text = "Auto: " .. (state.autoBuy.CPU and "ON" or "OFF")
		cpuCol.AutoBtn.BackgroundColor3 = state.autoBuy.CPU and CONFIG.THEME.Success or CONFIG.THEME.Panel
	end
	if ramCol and ramCol:FindFirstChild("AutoBtn") then
		ramCol.AutoBtn.Text = "Auto: " .. (state.autoBuy.RAM and "ON" or "OFF")
		ramCol.AutoBtn.BackgroundColor3 = state.autoBuy.RAM and CONFIG.THEME.Success or CONFIG.THEME.Panel
	end
	if stoCol and stoCol:FindFirstChild("AutoBtn") then
		stoCol.AutoBtn.Text = "Auto: " .. (state.autoBuy.STO and "ON" or "OFF")
		stoCol.AutoBtn.BackgroundColor3 = state.autoBuy.STO and CONFIG.THEME.Success or CONFIG.THEME.Panel
	end

	-- Leaderboard
	local lbScroll = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("Main") and playerGui.TerminalUI.Root.SafeArea.Main:FindFirstChild("RightPanel") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel:FindFirstChild("Pages") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages:FindFirstChild("LeaderboardsPage") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages.LeaderboardsPage:FindFirstChild("LBScroll")
	if lbScroll then
		-- Clear existing rows
		for _, child in ipairs(lbScroll:GetChildren()) do
			if child:IsA("Frame") and child.Name:match("^Row_") then
				child:Destroy()
			end
		end
		-- Render rows
		for i, entry in ipairs(state.leaderboard) do
			local row = createFrame("Row_" .. i, lbScroll, UDim2.new(1, 0, 0, 30))
			createUICorner(row)
			createUIStroke(row, CONFIG.THEME.Border)
			row.BackgroundColor3 = CONFIG.THEME.Panel
			row.LayoutOrder = i

			local rank = createTextLabel("Rank", row, "#" .. i, 14, CONFIG.THEME.TextMuted)
			rank.Position = UDim2.new(0, 10, 0, 8)
			rank.Size = UDim2.new(0.1, 0, 0, 20)

			local name = createTextLabel("Name", row, entry.name or "Player", 14, CONFIG.THEME.Text)
			name.Position = UDim2.new(0.15, 0, 0, 8)
			name.Size = UDim2.new(0.5, 0, 0, 20)

			local value = createTextLabel("Value", row, tostring(entry.value or 0), 14, CONFIG.THEME.Text)
			value.Position = UDim2.new(0.7, 0, 0, 8)
			value.Size = UDim2.new(0.3, 0, 0, 20)
			value.TextXAlignment = Enum.TextXAlignment.Right

			-- Highlight local player
			if entry.userId == player.UserId then
				row.BackgroundColor3 = CONFIG.THEME.Accent
				row.BackgroundTransparency = 0.9
			end
		end
		-- Update your rank
		local yourRankLabel = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("Main") and playerGui.TerminalUI.Root.SafeArea.Main:FindFirstChild("RightPanel") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel:FindFirstChild("Pages") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages:FindFirstChild("LeaderboardsPage") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages.LeaderboardsPage:FindFirstChild("YourRank")
		if yourRankLabel then
			local myRank = 0
			for i, entry in ipairs(state.leaderboard) do
				if entry.userId == player.UserId then
					myRank = i
					break
				end
			end
			yourRankLabel.Text = "Your Rank: " .. (myRank > 0 and "#" .. myRank or "--")
		end
	end

	-- Community
	local likesLabel = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("Main") and playerGui.TerminalUI.Root.SafeArea.Main:FindFirstChild("RightPanel") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel:FindFirstChild("Pages") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages:FindFirstChild("CommunityPage") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages.CommunityPage:FindFirstChild("LikesLabel")
	local favLabel = playerGui:FindFirstChild("TerminalUI") and playerGui.TerminalUI:FindFirstChild("Root") and playerGui.TerminalUI.Root:FindFirstChild("SafeArea") and playerGui.TerminalUI.Root.SafeArea:FindFirstChild("Main") and playerGui.TerminalUI.Root.SafeArea.Main:FindFirstChild("RightPanel") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel:FindFirstChild("Pages") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages:FindFirstChild("CommunityPage") and playerGui.TerminalUI.Root.SafeArea.Main.RightPanel.Pages.CommunityPage:FindFirstChild("FavLabel")
	if likesLabel then
		likesLabel.Text = "Likes: " .. (state.community.likes or 0) .. " / " .. (state.community.likeGoal or 100)
	end
	if favLabel then
		favLabel.Text = "Favorites: " .. (state.community.favorites or 0)
	end
end

-- Data Polling (fallback simulation)
task.spawn(function()
	while true do
		task.wait(1)
		-- Simulate data updates if no remotes
		if not remotes.GetLeaderboard then
			state.dataAmount = state.dataAmount + state.dps
			state.dps = math.random(1, 10)
		end
		updateUI()
	end
end)

-- Initialize
buildUI()
notify("System Incremental", "UI loaded", "info")
