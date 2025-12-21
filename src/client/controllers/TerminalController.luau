local TerminalController = {}

local initialized = false
local DebugConfig = nil
local DebugTrace = nil
do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Utils:FindFirstChild("DebugTrace"))
	end)
	if ok and type(mod) == "table" then
		DebugTrace = mod
	end
end
do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.utils:FindFirstChild("DebugConfig"))
	end)
	if ok and type(mod) == "table" then
		DebugConfig = mod
	end
end

function TerminalController.OnStart()
	if initialized then
		return
	end
	initialized = true

	local success, errorMessage = pcall(function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")

	local function logDebug(...)
		if DebugConfig then
			DebugConfig.Log("[TerminalClient]", ...)
		end
	end

	local function safeWait(parent, childName, timeout)
		if not parent then
			return nil
		end

		local ok, result = pcall(function()
			return parent:WaitForChild(childName, timeout or 5)
		end)

		if ok then
			return result
		end

		return nil
	end

	local sharedFolder = safeWait(ReplicatedStorage, "Shared", 5)
	if not sharedFolder then
		warn("[TerminalClient] Shared folder missing")
		return
	end

	local upgradeConfigModule = safeWait(sharedFolder, "UpgradeConfig", 5)
	if not upgradeConfigModule then
		warn("[TerminalClient] UpgradeConfig module missing")
		return
	end

	local numberFormatterModule = safeWait(sharedFolder, "NumberFormatter", 5)
	if not numberFormatterModule then
		warn("[TerminalClient] NumberFormatter module missing")
		return
	end

	local UpgradeConfig = require(upgradeConfigModule)
	local NumberFormatter = require(numberFormatterModule)

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	if not player then
		warn("[TerminalClient] LocalPlayer missing")
		return
	end

	local playerGui = safeWait(player, "PlayerGui", 5)
	if not playerGui then
		warn("[TerminalClient] PlayerGui missing")
		return
	end

	local terminalUi = safeWait(playerGui, "TerminalUI", 5)
	if not terminalUi then
		warn("[TerminalClient] TerminalUI missing")
		return
	end
	if terminalUi.Parent ~= playerGui or terminalUi.Name ~= "TerminalUI" then
		warn("[TerminalClient] TerminalUI is not PlayerGui.TerminalUI")
		return
	end

	local root = safeWait(terminalUi, "Root", 5)
	if not root then
		warn("[TerminalClient] Root missing")
		return
	end

	local safeArea = safeWait(root, "SafeArea", 5)
	if not safeArea then
		warn("[TerminalClient] SafeArea missing")
		return
	end

	local main = safeWait(safeArea, "Main", 5)
	if not main then
		warn("[TerminalClient] Main missing")
		return
	end

	local topBar = safeWait(safeArea, "TopBar", 5)
	if not topBar then
		warn("[TerminalClient] TopBar missing")
		return
	end

	local dataValueLabel = safeWait(topBar, "DataValue", 5)
	if not dataValueLabel then
		warn("[TerminalClient] DataValue missing")
		return
	end
	if DebugTrace then
		DebugTrace.LogBind(dataValueLabel:GetFullName(), true)
	end

	local saveStatusLabel = topBar:FindFirstChild("SaveStatus")

	local columns = safeWait(main, "Columns", 5)
	if not columns then
		warn("[TerminalClient] Columns missing")
		return
	end

	local cpuColumn = safeWait(columns, "CPUColumn", 5)
	if not cpuColumn then
		warn("[TerminalClient] Column 'CPUColumn' missing")
		return
	end

	local ramColumn = safeWait(columns, "RAMColumn", 5)
	if not ramColumn then
		warn("[TerminalClient] Column 'RAMColumn' missing")
		return
	end

	local stoColumn = safeWait(columns, "STOColumn", 5)
	if not stoColumn then
		warn("[TerminalClient] Column 'STOColumn' missing")
		return
	end

	local cpuCardsFolder = safeWait(cpuColumn, "Cards_CPU", 5)
	if not cpuCardsFolder then
		warn("[TerminalClient] Column 'CPUColumn' cards missing")
		return
	end

	local ramCardsFolder = safeWait(ramColumn, "Cards_RAM", 5)
	if not ramCardsFolder then
		warn("[TerminalClient] Column 'RAMColumn' cards missing")
		return
	end

	local stoCardsFolder = safeWait(stoColumn, "Cards_STORAGE", 5)
	if not stoCardsFolder then
		warn("[TerminalClient] Column 'STOColumn' cards missing")
		return
	end
	local cpuAutoBuyButton = cpuColumn:FindFirstChild("AutoBuyButton")
	local ramAutoBuyButton = ramColumn:FindFirstChild("AutoBuyButton")
	local stoAutoBuyButton = stoColumn:FindFirstChild("AutoBuyButton")

	local rightPanel = safeWait(main, "RightPanel", 5)
	if not rightPanel then
		warn("[TerminalClient] RightPanel missing")
		return
	end

	local function normalizeBackgrounds()
		root.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
		if root:IsA("Frame") then
			root.BackgroundTransparency = 0
		end
		safeArea.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
		if safeArea:IsA("Frame") then
			safeArea.BackgroundTransparency = 0
		end
		main.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
		if main:IsA("Frame") then
			main.BackgroundTransparency = 0
		end
		columns.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
		if columns:IsA("Frame") then
			columns.BackgroundTransparency = 0
		end
		rightPanel.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
		if rightPanel:IsA("Frame") then
			rightPanel.BackgroundTransparency = 0
		end
		cpuCardsFolder.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
		cpuCardsFolder.BackgroundTransparency = 0
		ramCardsFolder.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
		ramCardsFolder.BackgroundTransparency = 0
		stoCardsFolder.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
		stoCardsFolder.BackgroundTransparency = 0
	end

	local function normalizeAutoBuyButton(button)
		if not button or not button:IsA("TextButton") then
			return
		end
		button.Active = true
		button.Selectable = true
		button.AutoButtonColor = true
		button.ZIndex = 20
		for _, desc in ipairs(button:GetDescendants()) do
			if desc:IsA("GuiObject") then
				desc.ZIndex = button.ZIndex + 1
			end
		end
	end

	local function normalizeAutoBuyInput()
		if cpuCardsFolder and cpuCardsFolder:IsA("ScrollingFrame") then
			cpuCardsFolder.Active = false
			cpuCardsFolder.Selectable = false
			cpuCardsFolder.ZIndex = 1
		end
		if ramCardsFolder and ramCardsFolder:IsA("ScrollingFrame") then
			ramCardsFolder.Active = false
			ramCardsFolder.Selectable = false
			ramCardsFolder.ZIndex = 1
		end
		if stoCardsFolder and stoCardsFolder:IsA("ScrollingFrame") then
			stoCardsFolder.Active = false
			stoCardsFolder.Selectable = false
			stoCardsFolder.ZIndex = 1
		end
		normalizeAutoBuyButton(cpuAutoBuyButton)
		normalizeAutoBuyButton(ramAutoBuyButton)
		normalizeAutoBuyButton(stoAutoBuyButton)
	end

	local normalizationDone = false
	local upgradeReady = false
	local function forceUIVisible()
		if upgradeReady then
			warn("[CRITICAL] Normalization running after UI mount")
			return
		end
		if normalizationDone then
			warn("[TerminalClient] Normalization attempted after init")
			return
		end
		terminalUi.Enabled = true
		terminalUi.DisplayOrder = 100

		local framesUpdated = 0
		local scrollingFramesUpdated = 0
		local textObjectsUpdated = 0

		local function forcePanel(frame)
			if not frame then
				return
			end
			if frame:IsA("Frame") then
				frame.Visible = true
				frame.BackgroundTransparency = 0
				framesUpdated += 1
			elseif frame:IsA("ScrollingFrame") then
				frame.Visible = true
				frame.BackgroundTransparency = 0
				scrollingFramesUpdated += 1
			elseif frame:IsA("GuiObject") then
				frame.Visible = true
			end
		end

		forcePanel(root)
		forcePanel(safeArea)
		forcePanel(main)
		forcePanel(columns)
		forcePanel(rightPanel)

		local function forceCards(container)
			if not container then
				return
			end
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Frame") then
					child.Visible = true
					child.BackgroundTransparency = 0
					framesUpdated += 1
				elseif child:IsA("ScrollingFrame") then
					child.Visible = true
					child.BackgroundTransparency = 0
					scrollingFramesUpdated += 1
				end
			end
		end

		forceCards(cpuCardsFolder)
		forceCards(ramCardsFolder)
		forceCards(stoCardsFolder)

		local storeOverlay = safeArea:FindFirstChild("StoreOverlay")
		if storeOverlay and storeOverlay:IsA("GuiObject") then
			storeOverlay.Visible = false
			storeOverlay.Active = false
		end

		textObjectsUpdated += 0
		if DebugConfig then
			DebugConfig.Log(("[TerminalClient] Normalization counts: FramesUpdated=%d ScrollingFramesUpdated=%d TextObjectsUpdated=%d"):format(framesUpdated, scrollingFramesUpdated, textObjectsUpdated))
		end
		normalizationDone = true
	end

	normalizeBackgrounds()
	normalizeAutoBuyInput()
	forceUIVisible()
	if DebugConfig then
		DebugConfig.Log("[UI FIX] Background transparency normalization complete")
	end

	local pages = safeWait(rightPanel, "Pages", 5)
	if not pages then
		warn("[TerminalClient] Pages missing")
		return
	end

	local statsPage = safeWait(pages, "StatsBox", 5)
	if not statsPage then
		error(("[TerminalClient][UI PATH] Missing: %s.StatsBox"):format(pages:GetFullName()))
	end
	local statsDpsValue = statsPage and statsPage:FindFirstChild("Stat1")
	local statsPrestigeValue = statsPage and statsPage:FindFirstChild("Stat3")
	local autoStatusFrame = nil
	local autoCpuLabel = nil
	local autoRamLabel = nil
	local autoStoLabel = nil
	local statsCorePowerValue = nil
	if DebugTrace then
		DebugTrace.LogBind(statsPage and statsPage:GetFullName() or "Pages.StatsBox", statsPage ~= nil)
	end
	if statsPage and statsPage:IsA("GuiObject") then
		statsPage.Visible = true
	end
	local function ensureAutoStatusFrame()
		if not pages then
			return
		end
		autoStatusFrame = pages:FindFirstChild("AutoStatusFrame")
		if not autoStatusFrame then
			autoStatusFrame = Instance.new("Frame")
			autoStatusFrame.Name = "AutoStatusFrame"
			autoStatusFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
			autoStatusFrame.BackgroundTransparency = 0.1
			autoStatusFrame.BorderSizePixel = 0
			autoStatusFrame.LayoutOrder = 50
			autoStatusFrame.Size = UDim2.new(1, 0, 0, 66)
			autoStatusFrame.Parent = pages
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = autoStatusFrame
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(60, 80, 110)
			stroke.Thickness = 1
			stroke.Transparency = 0.4
			stroke.Parent = autoStatusFrame
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 6)
			padding.PaddingBottom = UDim.new(0, 6)
			padding.PaddingLeft = UDim.new(0, 8)
			padding.PaddingRight = UDim.new(0, 8)
			padding.Parent = autoStatusFrame
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Vertical
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 2)
			layout.Parent = autoStatusFrame
			local header = Instance.new("TextLabel")
			header.Name = "AutoStatusHeader"
			header.BackgroundTransparency = 1
			header.Font = Enum.Font.GothamBold
			header.TextSize = 12
			header.TextColor3 = Color3.fromRGB(140, 200, 255)
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.Size = UDim2.new(1, 0, 0, 14)
			header.Text = "AUTOMATION"
			header.LayoutOrder = 1
			header.Parent = autoStatusFrame
			local function makeRow(name, labelText, order)
				local row = Instance.new("TextLabel")
				row.Name = name
				row.BackgroundTransparency = 1
				row.Font = Enum.Font.Gotham
				row.TextSize = 12
				row.TextColor3 = Color3.fromRGB(200, 200, 210)
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Size = UDim2.new(1, 0, 0, 14)
				row.Text = labelText .. ": LOCKED"
				row.LayoutOrder = order
				row.Parent = autoStatusFrame
				return row
			end
			autoCpuLabel = makeRow("AutoCPU", "Auto CPU", 2)
			autoRamLabel = makeRow("AutoRAM", "Auto RAM", 3)
			autoStoLabel = makeRow("AutoSTO", "Auto STO", 4)
		else
			autoCpuLabel = autoStatusFrame:FindFirstChild("AutoCPU")
			autoRamLabel = autoStatusFrame:FindFirstChild("AutoRAM")
			autoStoLabel = autoStatusFrame:FindFirstChild("AutoSTO")
		end
	end

	ensureAutoStatusFrame()

	local function findLabelByNames(rootNode, names)
		if not rootNode then
			return nil
		end
		for _, name in ipairs(names) do
			local found = rootNode:FindFirstChild(name, true)
			if found and (found:IsA("TextLabel") or found:IsA("TextButton")) then
				return found
			end
		end
		return nil
	end

	local systemCpuValue = statsPage and statsPage:FindFirstChild("Stat2")
	local systemRamValue = nil
	local systemStorageValue = nil

	local multBaseValue = findLabelByNames(rightPanel, { "BaseValue", "BaseOutputValue", "BaseStatValue" })
	local multAddValue = findLabelByNames(rightPanel, { "AddValue", "AdditiveValue", "AdditiveStatValue" })
	local multUpgradeValue = findLabelByNames(rightPanel, { "UpgradeMultiplierValue", "UpgradeMulValue", "UpgradeMultiplier" })
	local multPrestigeValue = findLabelByNames(rightPanel, { "PrestigeMultiplierValue", "PrestigeMulValue", "PrestigeMultiplier" })
	local multPassValue = findLabelByNames(rightPanel, { "PassMultiplierValue", "PassMulValue", "PassMultiplier" })
	local multBoostValue = findLabelByNames(rightPanel, { "BoostMultiplierValue", "BoostMulValue", "BoostMultiplier" })
	local multFinalValue = findLabelByNames(rightPanel, { "FinalValue", "FinalDpsValue", "FinalStatValue" })

	local prestigeBox = safeWait(pages, "PrestigeBox", 5)
	if not prestigeBox then
		error(("[TerminalClient][UI PATH] Missing: %s.PrestigeBox"):format(pages:GetFullName()))
	end
	local prestigePageName = "PrestigePage"
	local prestigePage = nil
	local PRESTIGE_PANEL_HEIGHT = 180
	local PRESTIGE_PANEL_PADDING = 8
	local PRESTIGE_CANVAS_PX = 4000
	local PRESTIGE_UPGRADES_HEIGHT = 220
	local prestigeUpgradesPanel = nil
	local prestigeUpgradesList = nil
	local communityPageName = "CommunityPage"
	local communityPage = nil
	local communityLikeGoals = nil
	local communityFavorite = nil
	local communityLikesLabel = nil
	local communityMilestoneList = nil
	local communityMilestoneTemplate = nil
	local communityMilestoneEmpty = nil
	local communityFavoriteClaimButton = nil
	local communityFavoriteStatusLabel = nil
	local communityErrorLabel = nil
	local communityRetryButton = nil
	local communityProgressBar = nil
	local communityProgressFill = nil
	local communityNextRewardLabel = nil
	local communityClaimNextButton = nil
	local communityClaimAllButton = nil
	local PrestigeUpgradesController
	local prestigePanel = nil
	local prestigePanelRoot = nil
	local prestigePanelHeader = nil
	local prestigePanelSummary = nil
	local prestigeTreeWrapper = nil
	local prestigePointsLabel = nil
	local prestigePreviewLabel = nil
	local prestigeLevelLabel = nil
	local prestigeLifetimeLabel = nil
	local prestigeTreeViewport = nil
	local prestigeTreeViewportFrame = nil
	local prestigeTreeContainer = nil
	local prestigeTreeCentered = false
	local prestigeTreeFixed = false
	local prestigeTreeWarned = false
	local prestigeButton = prestigeBox and prestigeBox:FindFirstChild("PrestigeButton")
	local prestigeOverlay = prestigeBox and prestigeBox:FindFirstChild("PrestigeLockedOverlay")
	if DebugTrace then
		DebugTrace.LogBind(prestigeButton and prestigeButton:GetFullName() or "PrestigeButton", prestigeButton ~= nil)
	end
	if prestigeBox and prestigeBox:IsA("GuiObject") then
		prestigeBox.Visible = true
	end

	local function ensurePrestigePanel()
		if prestigePanel and prestigePanel.Parent then
			return
		end
		prestigePanelRoot = prestigeBox:FindFirstChild("PrestigePanelRoot")
		if not prestigePanelRoot then
			prestigePanelRoot = Instance.new("Frame")
			prestigePanelRoot.Name = "PrestigePanelRoot"
			prestigePanelRoot.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
			prestigePanelRoot.BackgroundTransparency = 0.1
			prestigePanelRoot.Size = UDim2.new(1, 0, 1, 0)
			prestigePanelRoot.Position = UDim2.new(0, 0, 0, 0)
			prestigePanelRoot.Parent = prestigeBox
			local panelPadding = Instance.new("UIPadding")
			panelPadding.PaddingTop = UDim.new(0, 10)
			panelPadding.PaddingBottom = UDim.new(0, 10)
			panelPadding.PaddingLeft = UDim.new(0, 10)
			panelPadding.PaddingRight = UDim.new(0, 10)
			panelPadding.Parent = prestigePanelRoot
		end
		prestigePanel = prestigePanelRoot

		prestigePanelHeader = prestigePanel:FindFirstChild("HeaderSummary")
		if not prestigePanelHeader then
			prestigePanelHeader = Instance.new("Frame")
			prestigePanelHeader.Name = "HeaderSummary"
			prestigePanelHeader.BackgroundTransparency = 1
			prestigePanelHeader.Size = UDim2.new(1, 0, 0, 180)
			prestigePanelHeader.Parent = prestigePanel
			local headerLayout = Instance.new("UIListLayout")
			headerLayout.FillDirection = Enum.FillDirection.Vertical
			headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
			headerLayout.Padding = UDim.new(0, 10)
			headerLayout.Parent = prestigePanelHeader
		end

		local header = prestigePanelHeader:FindFirstChild("Header")
		if not header then
			header = Instance.new("Frame")
			header.Name = "Header"
			header.BackgroundTransparency = 1
			header.Size = UDim2.new(1, 0, 0, 60)
			header.LayoutOrder = 1
			header.Parent = prestigePanelHeader
		end
		local headerTitle = header:FindFirstChild("HeaderTitle")
		if not headerTitle then
			headerTitle = Instance.new("TextLabel")
			headerTitle.Name = "HeaderTitle"
			headerTitle.BackgroundTransparency = 1
			headerTitle.Font = Enum.Font.GothamBold
			headerTitle.TextSize = 18
			headerTitle.TextColor3 = Color3.fromRGB(120, 190, 255)
			headerTitle.TextXAlignment = Enum.TextXAlignment.Left
			headerTitle.Text = "PRESTIGE SYSTEM"
			headerTitle.Size = UDim2.new(1, 0, 0, 22)
			headerTitle.Parent = header
		end
		local headerPrestige = header:FindFirstChild("PrestigeCountLabel")
		if not headerPrestige then
			headerPrestige = Instance.new("TextLabel")
			headerPrestige.Name = "PrestigeCountLabel"
			headerPrestige.BackgroundTransparency = 1
			headerPrestige.Font = Enum.Font.Gotham
			headerPrestige.TextSize = 14
			headerPrestige.TextColor3 = Color3.fromRGB(230, 230, 235)
			headerPrestige.TextXAlignment = Enum.TextXAlignment.Left
			headerPrestige.Position = UDim2.new(0, 0, 0, 26)
			headerPrestige.Size = UDim2.new(0.5, -5, 0, 18)
			headerPrestige.Text = "Prestige 0"
			headerPrestige.Parent = header
		end
		prestigePointsLabel = header:FindFirstChild("PrestigePointsLabel")
		if not prestigePointsLabel then
			prestigePointsLabel = Instance.new("TextLabel")
			prestigePointsLabel.Name = "PrestigePointsLabel"
			prestigePointsLabel.BackgroundTransparency = 1
			prestigePointsLabel.Font = Enum.Font.Gotham
			prestigePointsLabel.TextSize = 14
			prestigePointsLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
			prestigePointsLabel.TextXAlignment = Enum.TextXAlignment.Right
			prestigePointsLabel.Position = UDim2.new(0.5, 5, 0, 26)
			prestigePointsLabel.Size = UDim2.new(0.5, -5, 0, 18)
			prestigePointsLabel.Text = "PP: 0"
			prestigePointsLabel.Parent = header
		end

		local summary = prestigePanelHeader:FindFirstChild("Summary")
		if not summary then
			summary = Instance.new("Frame")
			summary.Name = "Summary"
			summary.BackgroundTransparency = 1
			summary.Size = UDim2.new(1, 0, 0, 110)
			summary.LayoutOrder = 2
			summary.Parent = prestigePanelHeader
			local summaryLayout = Instance.new("UIListLayout")
			summaryLayout.FillDirection = Enum.FillDirection.Vertical
			summaryLayout.SortOrder = Enum.SortOrder.LayoutOrder
			summaryLayout.Padding = UDim.new(0, 4)
			summaryLayout.Parent = summary
		end

		local function ensureSummaryRow(name, labelText)
			local row = summary:FindFirstChild(name)
			if not row then
				row = Instance.new("Frame")
				row.Name = name
				row.BackgroundTransparency = 1
				row.Size = UDim2.new(1, 0, 0, 20)
				row.Parent = summary
				local label = Instance.new("TextLabel")
				label.Name = "Label"
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.Gotham
				label.TextSize = 13
				label.TextColor3 = Color3.fromRGB(180, 185, 200)
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.Text = labelText
				label.Size = UDim2.new(0.6, -4, 1, 0)
				label.Parent = row
				local value = Instance.new("TextLabel")
				value.Name = "Value"
				value.BackgroundTransparency = 1
				value.Font = Enum.Font.GothamMedium
				value.TextSize = 13
				value.TextColor3 = Color3.fromRGB(230, 230, 235)
				value.TextXAlignment = Enum.TextXAlignment.Right
				value.Size = UDim2.new(0.4, -4, 1, 0)
				value.Position = UDim2.new(0.6, 0, 0, 0)
				value.Text = "-"
				value.Parent = row
			end
			return row
		end

		local levelRow = ensureSummaryRow("PrestigeLevelRow", "Prestige Level")
		local pointsRow = ensureSummaryRow("PrestigePointsRow", "Prestige Points")
		local lifeRow = ensureSummaryRow("LifetimeDataRow", "Lifetime Data")
		local previewRow = ensureSummaryRow("PrestigePreviewRow", "Next Prestige Grants")

		prestigeLevelLabel = levelRow:FindFirstChild("Value")
		prestigePreviewLabel = previewRow:FindFirstChild("Value")
		prestigeLifetimeLabel = lifeRow:FindFirstChild("Value")
		local summaryPointsValue = pointsRow:FindFirstChild("Value")
		if summaryPointsValue and summaryPointsValue:IsA("TextLabel") then
			summaryPointsValue.Name = "PrestigePointsValue"
		end

	end

	local function ensurePrestigePage()
		prestigePage = pages:FindFirstChild(prestigePageName)
		if not prestigePage then
			prestigePage = Instance.new("Frame")
			prestigePage.Name = prestigePageName
			prestigePage.BackgroundTransparency = 1
			prestigePage.Size = UDim2.new(1, 0, 1, 0)
			prestigePage.Visible = false
			prestigePage.Parent = pages
			local pagePadding = Instance.new("UIPadding")
			pagePadding.PaddingTop = UDim.new(0, PRESTIGE_PANEL_PADDING)
			pagePadding.PaddingBottom = UDim.new(0, PRESTIGE_PANEL_PADDING)
			pagePadding.PaddingLeft = UDim.new(0, PRESTIGE_PANEL_PADDING)
			pagePadding.PaddingRight = UDim.new(0, PRESTIGE_PANEL_PADDING)
			pagePadding.Parent = prestigePage
		end

		if prestigeBox and prestigeBox.Parent ~= prestigePage then
			prestigeBox.Parent = prestigePage
			prestigeBox.Position = UDim2.new(0, 0, 0, 0)
			prestigeBox.Size = UDim2.new(1, 0, 0, PRESTIGE_PANEL_HEIGHT)
		end

		prestigeUpgradesPanel = prestigePage:FindFirstChild("PrestigeUpgradesPanel")
		if not prestigeUpgradesPanel then
			prestigeUpgradesPanel = Instance.new("Frame")
			prestigeUpgradesPanel.Name = "PrestigeUpgradesPanel"
			prestigeUpgradesPanel.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
			prestigeUpgradesPanel.BackgroundTransparency = 0.1
			prestigeUpgradesPanel.BorderSizePixel = 0
			prestigeUpgradesPanel.Position = UDim2.new(0, 0, 0, PRESTIGE_PANEL_HEIGHT + PRESTIGE_PANEL_PADDING)
			prestigeUpgradesPanel.Size = UDim2.new(1, 0, 0, PRESTIGE_UPGRADES_HEIGHT)
			prestigeUpgradesPanel.Parent = prestigePage
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = prestigeUpgradesPanel
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(60, 80, 110)
			stroke.Transparency = 0.5
			stroke.Parent = prestigeUpgradesPanel
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 8)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.PaddingLeft = UDim.new(0, 8)
			padding.PaddingRight = UDim.new(0, 8)
			padding.Parent = prestigeUpgradesPanel
			local header = Instance.new("TextLabel")
			header.Name = "Header"
			header.BackgroundTransparency = 1
			header.Font = Enum.Font.GothamBold
			header.TextSize = 14
			header.TextColor3 = Color3.fromRGB(140, 200, 255)
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.Size = UDim2.new(1, 0, 0, 20)
			header.Text = "Prestige Upgrades"
			header.Parent = prestigeUpgradesPanel
			prestigeUpgradesList = Instance.new("ScrollingFrame")
			prestigeUpgradesList.Name = "PrestigeUpgradesList"
			prestigeUpgradesList.BackgroundTransparency = 1
			prestigeUpgradesList.BorderSizePixel = 0
			prestigeUpgradesList.Position = UDim2.new(0, 0, 0, 24)
			prestigeUpgradesList.Size = UDim2.new(1, 0, 1, -24)
			prestigeUpgradesList.ScrollBarThickness = 6
			prestigeUpgradesList.Active = true
			prestigeUpgradesList.AutomaticCanvasSize = Enum.AutomaticSize.Y
			prestigeUpgradesList.CanvasSize = UDim2.new(0, 0, 0, 0)
			prestigeUpgradesList.Parent = prestigeUpgradesPanel
			local listLayout = Instance.new("UIListLayout")
			listLayout.FillDirection = Enum.FillDirection.Vertical
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.Padding = UDim.new(0, 6)
			listLayout.Parent = prestigeUpgradesList
		else
			prestigeUpgradesList = prestigeUpgradesPanel:FindFirstChild("PrestigeUpgradesList")
		end

		prestigeTreeWrapper = prestigePage:FindFirstChild("TreeWrapper")
		if not prestigeTreeWrapper then
			prestigeTreeWrapper = Instance.new("Frame")
			prestigeTreeWrapper.Name = "TreeWrapper"
			prestigeTreeWrapper.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
			prestigeTreeWrapper.BackgroundTransparency = 0.1
			prestigeTreeWrapper.BorderSizePixel = 0
			local topOffset = PRESTIGE_PANEL_HEIGHT + PRESTIGE_PANEL_PADDING + PRESTIGE_UPGRADES_HEIGHT + PRESTIGE_PANEL_PADDING
			prestigeTreeWrapper.Size = UDim2.new(1, 0, 1, -topOffset)
			prestigeTreeWrapper.Position = UDim2.new(0, 0, 0, topOffset)
			prestigeTreeWrapper.Parent = prestigePage
		end

		local treeViewportFrame = prestigeTreeWrapper:FindFirstChild("TreeViewport")
		if not treeViewportFrame then
			treeViewportFrame = Instance.new("Frame")
			treeViewportFrame.Name = "TreeViewport"
			treeViewportFrame.BackgroundTransparency = 1
			treeViewportFrame.BorderSizePixel = 0
			treeViewportFrame.Size = UDim2.new(1, 0, 1, 0)
			treeViewportFrame.ClipsDescendants = true
			treeViewportFrame.Parent = prestigeTreeWrapper
		end
		prestigeTreeViewportFrame = treeViewportFrame

		local treeCanvas = treeViewportFrame:FindFirstChild("TreeCanvas")
		if not treeCanvas then
			treeCanvas = Instance.new("ScrollingFrame")
			treeCanvas.Name = "TreeCanvas"
			treeCanvas.BackgroundTransparency = 1
			treeCanvas.BorderSizePixel = 0
			treeCanvas.Size = UDim2.new(1, 0, 1, 0)
			treeCanvas.ScrollBarThickness = 6
			treeCanvas.Parent = treeViewportFrame
		end
		prestigeTreeViewport = treeCanvas

		prestigeTreeContainer = treeCanvas:FindFirstChild("TreeContainer")
		if not prestigeTreeContainer then
			prestigeTreeContainer = Instance.new("Frame")
			prestigeTreeContainer.Name = "TreeContainer"
			prestigeTreeContainer.BackgroundTransparency = 1
			prestigeTreeContainer.AnchorPoint = Vector2.new(0.5, 0.5)
			prestigeTreeContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
			prestigeTreeContainer.Size = UDim2.fromOffset(PRESTIGE_CANVAS_PX, PRESTIGE_CANVAS_PX)
			prestigeTreeContainer.Parent = treeCanvas
			local treeScale = Instance.new("UIScale")
			treeScale.Scale = 1
			treeScale.Parent = prestigeTreeContainer
			local treeLabel = Instance.new("TextLabel")
			treeLabel.Name = "TreeLabel"
			treeLabel.BackgroundTransparency = 1
			treeLabel.Font = Enum.Font.GothamBold
			treeLabel.TextSize = 14
			treeLabel.TextColor3 = Color3.fromRGB(130, 150, 170)
			treeLabel.Text = ""
			treeLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			treeLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
			treeLabel.Size = UDim2.new(1, -20, 0, 20)
			treeLabel.Parent = prestigeTreeContainer
		end
	end

	local function ensureCommunityPage()
		communityPage = pages:FindFirstChild(communityPageName)
		if not communityPage then
			communityPage = Instance.new("Frame")
			communityPage.Name = communityPageName
			communityPage.BackgroundTransparency = 1
			communityPage.Size = UDim2.new(1, 0, 1, 0)
			communityPage.Visible = false
			communityPage.Parent = pages
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 8)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.PaddingLeft = UDim.new(0, 8)
			padding.PaddingRight = UDim.new(0, 8)
			padding.Parent = communityPage
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Vertical
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 10)
			layout.Parent = communityPage
		end

		communityLikeGoals = communityPage:FindFirstChild("LikeGoals")
		if not communityLikeGoals then
			communityLikeGoals = Instance.new("Frame")
			communityLikeGoals.Name = "LikeGoals"
			communityLikeGoals.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
			communityLikeGoals.BackgroundTransparency = 0.1
			communityLikeGoals.BorderSizePixel = 0
			communityLikeGoals.Size = UDim2.new(1, 0, 0, 320)
			communityLikeGoals.LayoutOrder = 1
			communityLikeGoals.Parent = communityPage
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = communityLikeGoals
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(60, 80, 110)
			stroke.Transparency = 0.5
			stroke.Parent = communityLikeGoals
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 8)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.PaddingLeft = UDim.new(0, 8)
			padding.PaddingRight = UDim.new(0, 8)
			padding.Parent = communityLikeGoals
			local header = Instance.new("TextLabel")
			header.Name = "Header"
			header.BackgroundTransparency = 1
			header.Font = Enum.Font.GothamBold
			header.TextSize = 14
			header.TextColor3 = Color3.fromRGB(140, 200, 255)
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.Size = UDim2.new(1, 0, 0, 20)
			header.Text = "Global Like Goals"
			header.Parent = communityLikeGoals
			communityLikesLabel = Instance.new("TextLabel")
			communityLikesLabel.Name = "Progress"
			communityLikesLabel.BackgroundTransparency = 1
			communityLikesLabel.Font = Enum.Font.Gotham
			communityLikesLabel.TextSize = 12
			communityLikesLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
			communityLikesLabel.TextXAlignment = Enum.TextXAlignment.Left
			communityLikesLabel.Position = UDim2.new(0, 0, 0, 24)
			communityLikesLabel.Size = UDim2.new(1, 0, 0, 16)
			communityLikesLabel.Text = "Current: 0 / Next: -"
			communityLikesLabel.Parent = communityLikeGoals
			communityProgressBar = Instance.new("Frame")
			communityProgressBar.Name = "ProgressBar"
			communityProgressBar.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
			communityProgressBar.BorderSizePixel = 0
			communityProgressBar.Position = UDim2.new(0, 0, 0, 44)
			communityProgressBar.Size = UDim2.new(1, 0, 0, 10)
			communityProgressBar.Parent = communityLikeGoals
			local progressCorner = Instance.new("UICorner")
			progressCorner.CornerRadius = UDim.new(0, 6)
			progressCorner.Parent = communityProgressBar
			communityProgressFill = Instance.new("Frame")
			communityProgressFill.Name = "ProgressFill"
			communityProgressFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
			communityProgressFill.BorderSizePixel = 0
			communityProgressFill.Size = UDim2.new(0, 0, 1, 0)
			communityProgressFill.Parent = communityProgressBar
			local fillCorner = Instance.new("UICorner")
			fillCorner.CornerRadius = UDim.new(0, 6)
			fillCorner.Parent = communityProgressFill
			communityNextRewardLabel = Instance.new("TextLabel")
			communityNextRewardLabel.Name = "NextReward"
			communityNextRewardLabel.BackgroundTransparency = 1
			communityNextRewardLabel.Font = Enum.Font.Gotham
			communityNextRewardLabel.TextSize = 12
			communityNextRewardLabel.TextColor3 = Color3.fromRGB(190, 210, 240)
			communityNextRewardLabel.TextXAlignment = Enum.TextXAlignment.Left
			communityNextRewardLabel.Position = UDim2.new(0, 0, 0, 88)
			communityNextRewardLabel.Size = UDim2.new(0.6, 0, 0, 16)
			communityNextRewardLabel.Text = "Next Reward: -"
			communityNextRewardLabel.Parent = communityLikeGoals
			communityClaimNextButton = Instance.new("TextButton")
			communityClaimNextButton.Name = "ClaimNextButton"
			communityClaimNextButton.AutoButtonColor = true
			communityClaimNextButton.Font = Enum.Font.GothamBold
			communityClaimNextButton.TextSize = 12
			communityClaimNextButton.TextColor3 = Color3.fromRGB(230, 230, 235)
			communityClaimNextButton.BackgroundColor3 = Color3.fromRGB(28, 40, 70)
			communityClaimNextButton.BorderSizePixel = 0
			communityClaimNextButton.AnchorPoint = Vector2.new(0, 0)
			communityClaimNextButton.Position = UDim2.new(0, 0, 0, 56)
			communityClaimNextButton.Size = UDim2.new(0, 80, 0, 22)
			communityClaimNextButton.Text = "CLAIM"
			communityClaimNextButton.Parent = communityLikeGoals
			local claimNextCorner = Instance.new("UICorner")
			claimNextCorner.CornerRadius = UDim.new(0, 6)
			claimNextCorner.Parent = communityClaimNextButton
			communityClaimAllButton = Instance.new("TextButton")
			communityClaimAllButton.Name = "ClaimAllButton"
			communityClaimAllButton.AutoButtonColor = true
			communityClaimAllButton.Font = Enum.Font.GothamBold
			communityClaimAllButton.TextSize = 12
			communityClaimAllButton.TextColor3 = Color3.fromRGB(230, 230, 235)
			communityClaimAllButton.BackgroundColor3 = Color3.fromRGB(22, 32, 58)
			communityClaimAllButton.BorderSizePixel = 0
			communityClaimAllButton.AnchorPoint = Vector2.new(0, 0)
			communityClaimAllButton.Position = UDim2.new(0, 90, 0, 56)
			communityClaimAllButton.Size = UDim2.new(0, 96, 0, 22)
			communityClaimAllButton.Text = "CLAIM ALL"
			communityClaimAllButton.Parent = communityLikeGoals
			local claimAllCorner = Instance.new("UICorner")
			claimAllCorner.CornerRadius = UDim.new(0, 6)
			claimAllCorner.Parent = communityClaimAllButton
			communityMilestoneList = Instance.new("ScrollingFrame")
			communityMilestoneList.Name = "MilestoneList"
			communityMilestoneList.BackgroundTransparency = 1
			communityMilestoneList.BorderSizePixel = 0
			communityMilestoneList.Position = UDim2.new(0, 0, 0, 48)
			communityMilestoneList.Size = UDim2.new(1, 0, 1, -48)
			communityMilestoneList.ScrollBarThickness = 6
			communityMilestoneList.Active = true
			communityMilestoneList.ScrollingDirection = Enum.ScrollingDirection.Y
			communityMilestoneList.AutomaticCanvasSize = Enum.AutomaticSize.Y
			communityMilestoneList.CanvasSize = UDim2.new(0, 0, 0, 0)
			communityMilestoneList.Parent = communityLikeGoals
			communityMilestoneList.Visible = false
			local listLayout = Instance.new("UIListLayout")
			listLayout.FillDirection = Enum.FillDirection.Vertical
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.Padding = UDim.new(0, 6)
			listLayout.Parent = communityMilestoneList
			communityMilestoneTemplate = Instance.new("Frame")
			communityMilestoneTemplate.Name = "MilestoneTemplate"
			communityMilestoneTemplate.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
			communityMilestoneTemplate.BackgroundTransparency = 0.1
			communityMilestoneTemplate.BorderSizePixel = 0
			communityMilestoneTemplate.Size = UDim2.new(1, -6, 0, 54)
			communityMilestoneTemplate.Visible = false
			communityMilestoneTemplate.Parent = communityMilestoneList
			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 6)
			rowCorner.Parent = communityMilestoneTemplate
			local goal = Instance.new("TextLabel")
			goal.Name = "GoalLabel"
			goal.BackgroundTransparency = 1
			goal.Font = Enum.Font.GothamBold
			goal.TextSize = 12
			goal.TextColor3 = Color3.fromRGB(230, 230, 235)
			goal.TextXAlignment = Enum.TextXAlignment.Left
			goal.Position = UDim2.new(0, 8, 0, 6)
			goal.Size = UDim2.new(0.5, -8, 0, 18)
			goal.Text = "100 Likes"
			goal.Parent = communityMilestoneTemplate
			local reward = Instance.new("TextLabel")
			reward.Name = "RewardLabel"
			reward.BackgroundTransparency = 1
			reward.Font = Enum.Font.Gotham
			reward.TextSize = 12
			reward.TextColor3 = Color3.fromRGB(180, 200, 240)
			reward.TextXAlignment = Enum.TextXAlignment.Left
			reward.Position = UDim2.new(0, 8, 0, 26)
			reward.Size = UDim2.new(0.6, -8, 0, 16)
			reward.TextWrapped = true
			reward.TextYAlignment = Enum.TextYAlignment.Top
			reward.Text = "+1 Prestige Points"
			reward.Parent = communityMilestoneTemplate
			local claim = Instance.new("TextButton")
			claim.Name = "ClaimButton"
			claim.AutoButtonColor = true
			claim.Font = Enum.Font.GothamBold
			claim.TextSize = 12
			claim.TextColor3 = Color3.fromRGB(230, 230, 235)
			claim.BackgroundColor3 = Color3.fromRGB(28, 40, 70)
			claim.BorderSizePixel = 0
			claim.AnchorPoint = Vector2.new(1, 0.5)
			claim.Position = UDim2.new(1, -8, 0.5, 0)
			claim.Size = UDim2.new(0, 86, 0, 28)
			claim.Text = "LOCKED"
			claim.Parent = communityMilestoneTemplate
			local claimCorner = Instance.new("UICorner")
			claimCorner.CornerRadius = UDim.new(0, 6)
			claimCorner.Parent = claim
			communityMilestoneEmpty = Instance.new("TextLabel")
			communityMilestoneEmpty.Name = "EmptyLabel"
			communityMilestoneEmpty.BackgroundTransparency = 1
			communityMilestoneEmpty.Font = Enum.Font.Gotham
			communityMilestoneEmpty.TextSize = 12
			communityMilestoneEmpty.TextColor3 = Color3.fromRGB(190, 190, 200)
			communityMilestoneEmpty.TextXAlignment = Enum.TextXAlignment.Center
			communityMilestoneEmpty.Size = UDim2.new(1, 0, 0, 20)
			communityMilestoneEmpty.Text = "No goals configured."
			communityMilestoneEmpty.Visible = false
			communityMilestoneEmpty.Parent = communityMilestoneList
		end

		communityFavorite = communityPage:FindFirstChild("FavoriteReward")
		if not communityFavorite then
			communityFavorite = Instance.new("Frame")
			communityFavorite.Name = "FavoriteReward"
			communityFavorite.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
			communityFavorite.BackgroundTransparency = 0.1
			communityFavorite.BorderSizePixel = 0
			communityFavorite.Size = UDim2.new(1, 0, 0, 140)
			communityFavorite.LayoutOrder = 2
			communityFavorite.Parent = communityPage
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = communityFavorite
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(60, 80, 110)
			stroke.Transparency = 0.5
			stroke.Parent = communityFavorite
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 8)
			padding.PaddingBottom = UDim.new(0, 8)
			padding.PaddingLeft = UDim.new(0, 8)
			padding.PaddingRight = UDim.new(0, 8)
			padding.Parent = communityFavorite
			local header = Instance.new("TextLabel")
			header.Name = "Header"
			header.BackgroundTransparency = 1
			header.Font = Enum.Font.GothamBold
			header.TextSize = 14
			header.TextColor3 = Color3.fromRGB(255, 190, 200)
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.Size = UDim2.new(1, 0, 0, 20)
			header.Text = "Favorite Reward ❤️"
			header.Parent = communityFavorite
			local desc = Instance.new("TextLabel")
			desc.Name = "Description"
			desc.BackgroundTransparency = 1
			desc.Font = Enum.Font.Gotham
			desc.TextSize = 12
			desc.TextColor3 = Color3.fromRGB(200, 200, 210)
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.Position = UDim2.new(0, 0, 0, 26)
			desc.Size = UDim2.new(1, 0, 0, 30)
			desc.TextWrapped = true
			desc.TextYAlignment = Enum.TextYAlignment.Top
			desc.Text = "Support the game with a favorite to claim a one-time reward."
			desc.Parent = communityFavorite
			communityFavoriteStatusLabel = Instance.new("TextLabel")
			communityFavoriteStatusLabel.Name = "StatusLabel"
			communityFavoriteStatusLabel.BackgroundTransparency = 1
			communityFavoriteStatusLabel.Font = Enum.Font.Gotham
			communityFavoriteStatusLabel.TextSize = 12
			communityFavoriteStatusLabel.TextColor3 = Color3.fromRGB(180, 200, 240)
			communityFavoriteStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
			communityFavoriteStatusLabel.Position = UDim2.new(0, 0, 0, 56)
			communityFavoriteStatusLabel.Size = UDim2.new(0.6, 0, 0, 18)
			communityFavoriteStatusLabel.Text = "Reward available"
			communityFavoriteStatusLabel.Parent = communityFavorite
			communityFavoriteClaimButton = Instance.new("TextButton")
			communityFavoriteClaimButton.Name = "ClaimButton"
			communityFavoriteClaimButton.AutoButtonColor = true
			communityFavoriteClaimButton.Font = Enum.Font.GothamBold
			communityFavoriteClaimButton.TextSize = 12
			communityFavoriteClaimButton.TextColor3 = Color3.fromRGB(230, 230, 235)
			communityFavoriteClaimButton.BackgroundColor3 = Color3.fromRGB(28, 40, 70)
			communityFavoriteClaimButton.BorderSizePixel = 0
			communityFavoriteClaimButton.AnchorPoint = Vector2.new(1, 1)
			communityFavoriteClaimButton.Position = UDim2.new(1, -8, 1, -10)
			communityFavoriteClaimButton.Size = UDim2.new(0, 110, 0, 32)
			communityFavoriteClaimButton.Text = "CLAIM"
			communityFavoriteClaimButton.Parent = communityFavorite
			local claimCorner = Instance.new("UICorner")
			claimCorner.CornerRadius = UDim.new(0, 6)
			claimCorner.Parent = communityFavoriteClaimButton
		end
		communityLikesLabel = communityLikesLabel or communityLikeGoals:FindFirstChild("Progress")
		communityProgressBar = communityProgressBar or (communityLikeGoals and communityLikeGoals:FindFirstChild("ProgressBar"))
		communityProgressFill = communityProgressFill or (communityProgressBar and communityProgressBar:FindFirstChild("ProgressFill"))
		communityNextRewardLabel = communityNextRewardLabel or (communityLikeGoals and communityLikeGoals:FindFirstChild("NextReward"))
		communityClaimNextButton = communityClaimNextButton or (communityLikeGoals and communityLikeGoals:FindFirstChild("ClaimNextButton"))
		communityClaimAllButton = communityClaimAllButton or (communityLikeGoals and communityLikeGoals:FindFirstChild("ClaimAllButton"))
		communityMilestoneList = communityMilestoneList or (communityLikeGoals and communityLikeGoals:FindFirstChild("MilestoneList"))
		communityMilestoneTemplate = communityMilestoneTemplate or (communityMilestoneList and communityMilestoneList:FindFirstChild("MilestoneTemplate"))
		communityMilestoneEmpty = communityMilestoneEmpty or (communityMilestoneList and communityMilestoneList:FindFirstChild("EmptyLabel"))
		communityFavoriteClaimButton = communityFavoriteClaimButton or (communityFavorite and communityFavorite:FindFirstChild("ClaimButton"))
		communityFavoriteStatusLabel = communityFavoriteStatusLabel or (communityFavorite and communityFavorite:FindFirstChild("StatusLabel"))

		local errorLabel = communityPage:FindFirstChild("ErrorLabel")
		if not errorLabel then
			errorLabel = Instance.new("TextLabel")
			errorLabel.Name = "ErrorLabel"
			errorLabel.BackgroundTransparency = 1
			errorLabel.Font = Enum.Font.Gotham
			errorLabel.TextSize = 12
			errorLabel.TextColor3 = Color3.fromRGB(220, 170, 170)
			errorLabel.TextXAlignment = Enum.TextXAlignment.Left
			errorLabel.Size = UDim2.new(1, -120, 0, 18)
			errorLabel.LayoutOrder = 3
			errorLabel.Visible = false
			errorLabel.Text = "Failed to load community data."
			errorLabel.Parent = communityPage
		end
		communityErrorLabel = errorLabel
		local retryButton = communityPage:FindFirstChild("RetryButton")
		if not retryButton then
			retryButton = Instance.new("TextButton")
			retryButton.Name = "RetryButton"
			retryButton.AutoButtonColor = true
			retryButton.Font = Enum.Font.GothamBold
			retryButton.TextSize = 12
			retryButton.TextColor3 = Color3.fromRGB(230, 230, 235)
			retryButton.BackgroundColor3 = Color3.fromRGB(28, 40, 70)
			retryButton.BorderSizePixel = 0
			retryButton.Size = UDim2.new(0, 90, 0, 24)
			retryButton.LayoutOrder = 3
			retryButton.Visible = false
			retryButton.Text = "RETRY"
			retryButton.Parent = communityPage
			local retryCorner = Instance.new("UICorner")
			retryCorner.CornerRadius = UDim.new(0, 6)
			retryCorner.Parent = retryButton
		end
		communityRetryButton = retryButton
	end

	local function fixPrestigeTreeCanvas()
		if prestigeTreeFixed or not prestigeTreeViewport then
			return
		end
		prestigeTreeFixed = true

		for _, d in ipairs(prestigeTreeViewport:GetDescendants()) do
			if d:IsA("UIListLayout") or d:IsA("UIGridLayout") or d:IsA("UIPageLayout") or d:IsA("UIGridStyleLayout") then
				d:Destroy()
			end
		end
		if prestigeTreeViewportFrame and prestigeTreeViewportFrame:IsA("GuiObject") then
			prestigeTreeViewportFrame.AutomaticSize = Enum.AutomaticSize.None
			prestigeTreeViewportFrame.ClipsDescendants = true
		end
		if prestigeTreeWrapper and prestigeTreeWrapper:IsA("GuiObject") then
			prestigeTreeWrapper.AutomaticSize = Enum.AutomaticSize.None
		end
		if prestigeTreeContainer and prestigeTreeContainer:IsA("GuiObject") then
			prestigeTreeContainer.AutomaticSize = Enum.AutomaticSize.None
		end
		for _, d in ipairs(prestigeTreeViewport:GetDescendants()) do
			if d:IsA("UIScale") and d.Parent ~= prestigeTreeContainer then
				d:Destroy()
			end
		end

		prestigeTreeViewport.AutomaticCanvasSize = Enum.AutomaticSize.None
		prestigeTreeViewport.ScrollingDirection = Enum.ScrollingDirection.XY
		prestigeTreeViewport.ScrollBarThickness = 6
		prestigeTreeViewport.ScrollBarImageTransparency = 0.35
		prestigeTreeViewport.ElasticBehavior = Enum.ElasticBehavior.Never
		prestigeTreeViewport.ClipsDescendants = true
		prestigeTreeViewport.Size = UDim2.new(1, 0, 1, 0)
		prestigeTreeViewport.CanvasSize = UDim2.fromOffset(PRESTIGE_CANVAS_PX, PRESTIGE_CANVAS_PX)
	end

	ensurePrestigePanel()
	ensurePrestigePage()
	ensureCommunityPage()
	fixPrestigeTreeCanvas()

	local statsHeader = rightPanel:FindFirstChild("StatsHeader")
	local tabs = rightPanel:FindFirstChild("Tabs")
	local tabsContainer = tabs
	if tabs and not tabs:IsA("ScrollingFrame") then
		local tabsScroll = Instance.new("ScrollingFrame")
		tabsScroll.Name = tabs.Name
		tabsScroll.BackgroundTransparency = tabs.BackgroundTransparency
		tabsScroll.BackgroundColor3 = tabs.BackgroundColor3
		tabsScroll.BorderSizePixel = 0
		tabsScroll.Size = tabs.Size
		tabsScroll.Position = tabs.Position
		tabsScroll.AnchorPoint = tabs.AnchorPoint
		tabsScroll.ClipsDescendants = true
		tabsScroll.ScrollingDirection = Enum.ScrollingDirection.X
		tabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
		tabsScroll.ScrollBarImageTransparency = 1
		tabsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		tabsScroll.Parent = tabs.Parent
		for _, child in ipairs(tabs:GetChildren()) do
			child.Parent = tabsScroll
		end
		tabsScroll.LayoutOrder = tabs.LayoutOrder
		tabs:Destroy()
		tabsContainer = tabsScroll
	end
	if tabsContainer and tabsContainer:IsA("ScrollingFrame") then
		tabsContainer.ScrollingDirection = Enum.ScrollingDirection.X
		tabsContainer.AutomaticCanvasSize = Enum.AutomaticSize.None
		tabsContainer.ScrollBarImageTransparency = 1
		tabsContainer.ClipsDescendants = true
	end

	local statsTab = tabsContainer and tabsContainer:FindFirstChild("StatsTab")
	local leaderboardTab = tabsContainer and tabsContainer:FindFirstChild("LeaderboardTab")
	local prestigeTab = tabsContainer and tabsContainer:FindFirstChild("PrestigeTab")
	local communityTab = tabsContainer and tabsContainer:FindFirstChild("CommunityTab")
	if not prestigeTab and statsTab then
		prestigeTab = statsTab:Clone()
		prestigeTab.Name = "PrestigeTab"
		prestigeTab.Text = "Prestige"
		prestigeTab.Parent = tabsContainer
	end
	if not communityTab and statsTab then
		communityTab = statsTab:Clone()
		communityTab.Name = "CommunityTab"
		communityTab.Text = "Community"
		communityTab.Parent = tabsContainer
	end
	if tabsContainer and tabsContainer:IsA("ScrollingFrame") then
		local layout = tabsContainer:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 8)
			local function updateTabsCanvas()
				local content = layout.AbsoluteContentSize
				tabsContainer.CanvasSize = UDim2.new(0, content.X, 0, tabsContainer.AbsoluteSize.Y)
			end
			updateTabsCanvas()
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateTabsCanvas)
			tabsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTabsCanvas)
		end
		for _, child in ipairs(tabsContainer:GetChildren()) do
			if child:IsA("GuiButton") then
				if child.Size.X.Scale ~= 0 then
					child.Size = UDim2.fromOffset(120, child.Size.Y.Offset > 0 and child.Size.Y.Offset or 32)
				end
				if child.Size.Y.Scale ~= 0 then
					child.Size = UDim2.fromOffset(child.Size.X.Offset > 0 and child.Size.X.Offset or 120, 32)
				end
			end
		end
	end
	local leaderboardsPage = safeWait(pages, "LeaderboardPage", 5)
	if not leaderboardsPage then
		error(("[TerminalClient][UI PATH] Missing: %s.LeaderboardPage"):format(pages:GetFullName()))
	end
	local listFrame = leaderboardsPage and leaderboardsPage:FindFirstChild("List")
	local rowTemplate = listFrame and listFrame:FindFirstChild("RowTemplate")
	if rowTemplate and rowTemplate:IsA("GuiObject") then
		rowTemplate.Visible = false
	end
	local yourRankPanel = leaderboardsPage and leaderboardsPage:FindFirstChild("YourRank")
	local yourRankRow = nil
	local headerRow = leaderboardsPage and leaderboardsPage:FindFirstChild("Header")
	local lastPayload = nil
	local leaderboardCache = nil
	local leaderboardCacheUntil = 0
	local lastLeaderboardHash = nil
	local lastRenderedHash = nil
	local requestLeaderboard = nil
	local getPrestigeState = nil
	local purchasePrestigeNode = nil
	local uxEvent = nil
	local lastTabUxAt = {}
	local leaderboardRequested = false
	local leaderboardInFlight = false
	local lastLeaderboardFetch = 0
	local LEADERBOARD_REFRESH_SECONDS = 30
	local LEADERBOARD_CACHE_SECONDS = 15
	local DEBUG_LEADERBOARD = false
	local prestigeStateCache = nil
	local prestigeStateDirty = true
	local prestigeStateInFlight = false
	local prestigeNodeButtons = {}
	local prestigeNodePositions = {
		auto_cpu_1 = Vector2.new(-220, 0),
		auto_ram_1 = Vector2.new(0, 0),
		auto_sto_1 = Vector2.new(220, 0),
	}
	local UpgradeController
	local CommunityController
	local statsPageName = "StatsBox"
	local leaderboardsPageName = "LeaderboardPage"
	local activePage = statsPageName

	if DebugConfig then
		DebugConfig.Log(("[UI PATHS] Pages=%s StatsBox=%s LeaderboardPage=%s PrestigeBox=%s PrestigeButton=%s"):format(
			pages and pages:GetFullName() or "nil",
			statsPage and statsPage:GetFullName() or "nil",
			leaderboardsPage and leaderboardsPage:GetFullName() or "nil",
			prestigeBox and prestigeBox:GetFullName() or "nil",
			prestigeButton and prestigeButton:GetFullName() or "nil"
		))
	end

	local ACTIVE_TAB_BG = 0
	local INACTIVE_TAB_BG = 0.2

	local function setTabActive(tab, active)
		if not tab or not tab:IsA("TextButton") then
			return
		end
		tab.AutoButtonColor = true
		tab.BackgroundTransparency = active and ACTIVE_TAB_BG or INACTIVE_TAB_BG
	end

	local function setActivePage(pageName)
		activePage = pageName
		assert(pages, "[TerminalClient] Pages missing in setActivePage")
		if pages:IsA("GuiObject") then
			pages.Visible = true
		end
		local targetPage = nil
		if pageName == statsPageName then
			targetPage = statsPage
		elseif pageName == leaderboardsPageName then
			targetPage = leaderboardsPage
		elseif pageName == prestigePageName then
			targetPage = prestigePage
		elseif pageName == communityPageName then
			targetPage = communityPage
		else
			targetPage = pages:FindFirstChild(pageName)
		end
		assert(targetPage and targetPage:IsA("Frame"), ("[TerminalClient] Page '%s' missing under Pages"):format(tostring(pageName)))
		for _, child in ipairs(pages:GetChildren()) do
			if child:IsA("Frame") then
				child.Visible = (child == targetPage)
			end
		end
		targetPage.Visible = true
		if autoStatusFrame and autoStatusFrame:IsA("GuiObject") then
			autoStatusFrame.Visible = (pageName == statsPageName)
		end
		if pageName ~= prestigePageName then
			prestigeTreeCentered = false
		end
		if pageName == prestigePageName and prestigeTreeViewport and prestigeTreeViewportFrame and not prestigeTreeCentered then
			task.defer(function()
				if prestigeTreeViewportFrame.AbsoluteSize.Magnitude > 0 then
					local canvasSize = prestigeTreeViewport.CanvasSize
					local canvasX = canvasSize.X.Offset
					local canvasY = canvasSize.Y.Offset
					local viewX = prestigeTreeViewportFrame.AbsoluteSize.X
					local viewY = prestigeTreeViewportFrame.AbsoluteSize.Y
					prestigeTreeViewport.CanvasPosition = Vector2.new(
						math.max((canvasX - viewX) / 2, 0),
						math.max((canvasY - viewY) / 2, 0)
					)
					prestigeTreeCentered = true
					if not prestigeTreeWarned and prestigeTreeViewport.AbsoluteSize ~= prestigeTreeViewportFrame.AbsoluteSize then
						warn("[PrestigeTree] TreeCanvas size mismatch with viewport")
						prestigeTreeWarned = true
					end
				end
			end)
		end
		if prestigeButton and prestigeButton:IsA("GuiButton") then
			local isVisible = (pageName == prestigePageName)
			prestigeButton.Visible = isVisible
			prestigeButton.Active = isVisible
			prestigeButton.Selectable = isVisible
		end
		if uxEvent and uxEvent:IsA("RemoteEvent") then
			local now = os.clock()
			local last = lastTabUxAt[pageName] or 0
			if (now - last) >= 1 then
				lastTabUxAt[pageName] = now
				local tabName = (pageName == statsPageName and "Stats")
					or (pageName == leaderboardsPageName and "Leaderboards")
					or (pageName == prestigePageName and "Prestige")
					or (pageName == communityPageName and "Community")
				if tabName then
					uxEvent:FireServer({ type = "TabOpened", tab = tabName })
				end
			end
		end
	end

	local function isSkeletonRow(node)
		if not node then
			return false
		end
		if node:GetAttribute("__LeaderboardSkeleton") then
			return true
		end
		if node.Name == "Skeletons" or node.Name:find("Skeleton") then
			return true
		end
		return false
	end

	local function clearLeaderboardRows()
		if not listFrame then
			return
		end
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("Frame")
				and child ~= rowTemplate
				and not child:IsA("UIListLayout")
				and not isSkeletonRow(child)
			then
				child:Destroy()
			end
		end
	end

	local loggedTemplateChildren = false
	local function logRowTemplateChildren()
		if loggedTemplateChildren or not rowTemplate then
			return
		end
		local names = {}
		for _, child in ipairs(rowTemplate:GetDescendants()) do
			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("Frame") then
				table.insert(names, child.Name)
			end
		end
		if DEBUG_LEADERBOARD then
			print(("[TerminalClient][Leaderboard] RowTemplate children=%s"):format(table.concat(names, ", ")))
		end
		loggedTemplateChildren = true
	end

	local function setHeaderText()
		if not headerRow then
			return
		end
		local rankHeader = headerRow:FindFirstChild("Rank")
		local playerHeader = headerRow:FindFirstChild("PlayerName")
		local valueHeader = headerRow:FindFirstChild("Value")
		if rankHeader and rankHeader:IsA("TextLabel") then
			rankHeader.Text = "Rank"
		end
		if playerHeader and playerHeader:IsA("TextLabel") then
			playerHeader.Text = "Player"
		end
		if valueHeader and valueHeader:IsA("TextLabel") then
			valueHeader.Text = "Data"
		end
	end

	local function setRowText(row, entry, shouldWarn, deepLookup)
		if not row or typeof(entry) ~= "table" then
			return
		end
		local function findLabel(names)
			for _, name in ipairs(names) do
				local found = deepLookup and row:FindFirstChild(name, true) or row:FindFirstChild(name)
				if found then
					return found
				end
			end
			return nil
		end

		local rankLabel = findLabel(deepLookup and { "Rank", "RankLabel", "RankValue", "RankText", "Place", "Position" } or { "Rank" })
		local nameLabel = findLabel(deepLookup and { "PlayerName", "NameLabel", "Username", "UsernameLabel", "Player", "User", "Name" } or { "PlayerName" })
		local scoreLabel = findLabel(deepLookup and { "Value", "ValueLabel", "Score", "ScoreValue", "Data", "Amount" } or { "Value" })

		local function isText(node)
			return node and (node:IsA("TextLabel") or (deepLookup and node:IsA("TextButton")))
		end

		if not (isText(rankLabel) and isText(nameLabel) and isText(scoreLabel)) then
			if shouldWarn and DEBUG_LEADERBOARD then
				warn("[TerminalClient][Leaderboard] Missing row fields on RowTemplate")
			end
			return
		end

		rankLabel.Text = tostring(entry.rank)
		nameLabel.Text = tostring(entry.name or entry.username or "Unknown")
		scoreLabel.Text = NumberFormatter.format(entry.value)
		if rankLabel:IsA("TextLabel") then
			rankLabel.TextTransparency = 0
		end
		if nameLabel:IsA("TextLabel") then
			nameLabel.TextTransparency = 0
		end
		if scoreLabel:IsA("TextLabel") then
			scoreLabel.TextTransparency = 0
		end
	end

	local function animateRowIn(row)
		local targets = {}
		if row:IsA("GuiObject") then
			targets[row] = { BackgroundTransparency = row.BackgroundTransparency }
			row.BackgroundTransparency = 1
		end
		for _, child in ipairs(row:GetDescendants()) do
			if child:IsA("TextLabel") then
				targets[child] = { TextTransparency = child.TextTransparency }
				child.TextTransparency = 1
			elseif child:IsA("ImageLabel") then
				targets[child] = { ImageTransparency = child.ImageTransparency }
				child.ImageTransparency = 1
			elseif child:IsA("Frame") then
				targets[child] = { BackgroundTransparency = child.BackgroundTransparency }
				child.BackgroundTransparency = 1
			end
		end
		local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for instance, props in pairs(targets) do
			local tween = TweenService:Create(instance, tweenInfo, props)
			tween:Play()
		end
	end

	local function bindRowHover(row, baseColor, baseTransparency)
		if not row:IsA("GuiObject") then
			return
		end
		row.Active = true
		local hoverColor = baseColor:Lerp(Color3.new(1, 1, 1), 0.06)
		local enterConn
		local leaveConn
		enterConn = row.MouseEnter:Connect(function()
			row.BackgroundColor3 = hoverColor
			row.BackgroundTransparency = math.max(baseTransparency - 0.05, 0)
		end)
		leaveConn = row.MouseLeave:Connect(function()
			row.BackgroundColor3 = baseColor
			row.BackgroundTransparency = baseTransparency
		end)
		row.AncestryChanged:Connect(function(_, parent)
			if not parent then
				if enterConn then
					enterConn:Disconnect()
				end
				if leaveConn then
					leaveConn:Disconnect()
				end
			end
		end)
	end

	local function styleRow(row, entry, index, deepLookup)
		local isEven = (index % 2) == 0
		local baseColor = isEven and Color3.fromRGB(22, 24, 30) or Color3.fromRGB(18, 20, 26)
		local baseTransparency = 0.35
		local finalColor = baseColor
		local finalTransparency = baseTransparency

		if row:IsA("GuiObject") then
			row.BackgroundColor3 = finalColor
			row.BackgroundTransparency = finalTransparency
		end

		local function findLabel(names)
			for _, name in ipairs(names) do
				local found = deepLookup and row:FindFirstChild(name, true) or row:FindFirstChild(name)
				if found then
					return found
				end
			end
			return nil
		end

		local rankLabel = findLabel(deepLookup and { "Rank", "RankLabel", "RankValue", "RankText", "Place", "Position" } or { "Rank" })
		local nameLabel = findLabel(deepLookup and { "PlayerName", "NameLabel", "Username", "UsernameLabel", "Player", "User", "Name" } or { "PlayerName" })
		local scoreLabel = findLabel(deepLookup and { "Value", "ValueLabel", "Score", "ScoreValue", "Data", "Amount" } or { "Value" })

		if rankLabel and (rankLabel:IsA("TextLabel") or (deepLookup and rankLabel:IsA("TextButton"))) then
			rankLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
			rankLabel.TextStrokeTransparency = 0.7
		end
		if nameLabel and (nameLabel:IsA("TextLabel") or (deepLookup and nameLabel:IsA("TextButton"))) then
			nameLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
			nameLabel.TextStrokeTransparency = 0.7
		end
		if scoreLabel and (scoreLabel:IsA("TextLabel") or (deepLookup and scoreLabel:IsA("TextButton"))) then
			scoreLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
			scoreLabel.TextStrokeTransparency = 0.7
		end

		if entry.rank == 1 then
			local gold = Color3.fromRGB(255, 210, 80)
			if rankLabel and (rankLabel:IsA("TextLabel") or (deepLookup and rankLabel:IsA("TextButton"))) then
				rankLabel.TextColor3 = gold
				rankLabel.TextStrokeTransparency = 0.3
			end
			if row:IsA("GuiObject") then
				finalColor = Color3.fromRGB(32, 28, 18)
				row.BackgroundColor3 = finalColor
			end
		elseif entry.rank == 2 then
			local silver = Color3.fromRGB(200, 200, 210)
			if rankLabel and (rankLabel:IsA("TextLabel") or (deepLookup and rankLabel:IsA("TextButton"))) then
				rankLabel.TextColor3 = silver
				rankLabel.TextStrokeTransparency = 0.35
			end
			if row:IsA("GuiObject") then
				finalColor = Color3.fromRGB(26, 26, 30)
				row.BackgroundColor3 = finalColor
			end
		elseif entry.rank == 3 then
			local bronze = Color3.fromRGB(205, 140, 90)
			if rankLabel and (rankLabel:IsA("TextLabel") or (deepLookup and rankLabel:IsA("TextButton"))) then
				rankLabel.TextColor3 = bronze
				rankLabel.TextStrokeTransparency = 0.35
			end
			if row:IsA("GuiObject") then
				finalColor = Color3.fromRGB(30, 24, 20)
				row.BackgroundColor3 = finalColor
			end
		end

		if player and entry.userId == player.UserId then
			if row:IsA("GuiObject") then
				finalColor = Color3.fromRGB(28, 36, 46)
				finalTransparency = 0.2
				row.BackgroundColor3 = finalColor
				row.BackgroundTransparency = finalTransparency
			end
			if nameLabel and (nameLabel:IsA("TextLabel") or (deepLookup and nameLabel:IsA("TextButton"))) then
				nameLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
				nameLabel.TextStrokeTransparency = 0.2
			end
		end

		bindRowHover(row, finalColor, finalTransparency)
	end

	local function setSkeletonsVisible(visible)
		if not listFrame then
			return
		end
		for _, child in ipairs(listFrame:GetChildren()) do
			if isSkeletonRow(child) and child:IsA("GuiObject") then
				child.Visible = visible
			end
		end
	end

	local function setYourRank(entries)
		if not yourRankPanel or not yourRankPanel:IsA("GuiObject") then
			return
		end
		local function resolveYourRankRow()
			if yourRankRow and yourRankRow.Parent then
				return yourRankRow
			end
			local existing = yourRankPanel:FindFirstChild("YourRankRow")
				or yourRankPanel:FindFirstChild("RowTemplate")
				or yourRankPanel:FindFirstChild("Row")
			if existing and existing:IsA("Frame") then
				yourRankRow = existing
				return yourRankRow
			end
			if rowTemplate then
				yourRankRow = rowTemplate:Clone()
				yourRankRow.Name = "YourRankRow"
				yourRankRow.Visible = true
				yourRankRow.Parent = yourRankPanel
				if yourRankRow:IsA("GuiObject") then
					yourRankRow.Position = UDim2.new(0, 0, 0, 0)
					yourRankRow.Size = UDim2.new(1, 0, 1, 0)
				end
				return yourRankRow
			end
			return nil
		end

		if typeof(entries) ~= "table" or #entries == 0 then
			yourRankPanel.Visible = false
			return
		end

		local localEntry = nil
		local localRank = nil
		for index, entry in ipairs(entries) do
			if player and entry.userId == player.UserId then
				localEntry = entry
				localRank = index
				break
			end
		end

		yourRankPanel.Visible = true
		local targetRow = resolveYourRankRow()
		if not targetRow then
			return
		end
		if localEntry then
			localEntry.rank = localRank or localEntry.rank
			setRowText(targetRow, localEntry, false, true)
			styleRow(targetRow, localEntry, localRank or 0, true)
			targetRow.Visible = true
		else
			local fallbackValue = 0
			if lastPayload and typeof(lastPayload) == "table" and typeof(lastPayload.data) == "number" then
				fallbackValue = lastPayload.data
			end
			setRowText(targetRow, {
				rank = "Unranked",
				name = "You",
				value = fallbackValue,
			}, false, true)
			styleRow(targetRow, { rank = 0, userId = player and player.UserId or 0 }, #entries + 1, true)
			targetRow.Visible = true
		end
	end

	local function computeLeaderboardHash(entries)
		if typeof(entries) ~= "table" then
			return ""
		end
		local parts = {}
		for _, entry in ipairs(entries) do
			local userId = entry.userId or 0
			local value = entry.value or entry.score or 0
			local rank = entry.rank or 0
			table.insert(parts, ("%s:%s:%s"):format(userId, value, rank))
		end
		return table.concat(parts, "|")
	end

	local function renderLeaderboard(payload)
		if not leaderboardsPage or not listFrame or not rowTemplate then
			return
		end
		setHeaderText()
		logRowTemplateChildren()
		local entries = nil
		if payload and typeof(payload) == "table" then
			if typeof(payload[1]) == "table" then
				entries = payload
			else
				entries = payload.leaderboard or payload.leaderboards or payload.weeklyLeaderboard
			end
		end
		if typeof(entries) ~= "table" or #entries == 0 then
			clearLeaderboardRows()
			setSkeletonsVisible(true)
			if lastPayload and typeof(lastPayload) == "table" then
				setYourRank({
					{
						rank = "Unranked",
						userId = player and player.UserId or 0,
						name = "You",
						value = lastPayload.data or 0,
					},
				})
			else
				setYourRank(nil)
			end
			local row = rowTemplate:Clone()
			row.Visible = true
			row.LayoutOrder = 0
			row:SetAttribute("__LeaderboardRow", true)
			row.Parent = listFrame
			setRowText(row, { rank = "-", username = "No entries yet", value = 0 }, true, false)
			return
		end
		setYourRank(entries)
		local hash = computeLeaderboardHash(entries)
		if hash == lastRenderedHash then
			return
		end
		clearLeaderboardRows()
		lastRenderedHash = hash
		setSkeletonsVisible(false)
		local created = 0
		for index, entry in ipairs(entries) do
			local row = rowTemplate:Clone()
			row.Visible = true
			row.LayoutOrder = tonumber(entry.rank) or 0
			row:SetAttribute("__LeaderboardRow", true)
			row.Parent = listFrame
			styleRow(row, entry, index, false)
			setRowText(row, entry, true, false)
			animateRowIn(row)
			created += 1
		end
		setYourRank(entries)
		if DEBUG_LEADERBOARD then
			print(("[TerminalClient][Leaderboard] Rendered entries=%d clones=%d"):format(#entries, created))
		end
	end

	local function fetchLeaderboard(force)
		if leaderboardInFlight then
			return
		end
		local now = os.time()
		if not force and now < leaderboardCacheUntil then
			return
		end
		if not requestLeaderboard then
			if DEBUG_LEADERBOARD then
				warn("[TerminalClient] RequestLeaderboard remote missing")
			end
			return
		end
		leaderboardInFlight = true
		leaderboardRequested = true
		local ok, result = pcall(function()
			return requestLeaderboard:InvokeServer(50)
		end)
		if ok and typeof(result) == "table" then
			leaderboardCache = result
		else
			leaderboardCache = {}
		end
		lastLeaderboardFetch = now
		leaderboardCacheUntil = now + LEADERBOARD_CACHE_SECONDS
		local newHash = computeLeaderboardHash(leaderboardCache)
		local shouldRender = (newHash ~= lastLeaderboardHash)
		lastLeaderboardHash = newHash
		leaderboardInFlight = false
		if shouldRender and activePage == leaderboardsPageName then
			renderLeaderboard(leaderboardCache)
		end
	end

	local applyPrestigeState = nil

	local function ensurePrestigeNodeButton(nodeId, def)
		if not prestigeTreeContainer or typeof(def) ~= "table" then
			return nil
		end
		local existing = prestigeNodeButtons[nodeId]
		if existing and existing.Parent then
			return existing
		end
		local button = prestigeTreeContainer:FindFirstChild(nodeId)
		if not button then
			button = Instance.new("TextButton")
			button.Name = nodeId
			button.AutoButtonColor = true
			button.Font = Enum.Font.GothamBold
			button.TextSize = 13
			button.TextColor3 = Color3.fromRGB(230, 230, 235)
			button.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
			button.BorderSizePixel = 0
			button.Size = UDim2.fromOffset(160, 80)
			button.AnchorPoint = Vector2.new(0.5, 0.5)
			button.Parent = prestigeTreeContainer
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = button
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(80, 110, 160)
			stroke.Thickness = 1
			stroke.Transparency = 0.4
			stroke.Parent = button
			button.MouseButton1Click:Connect(function()
				if uxEvent and uxEvent:IsA("RemoteEvent") then
					uxEvent:FireServer({ type = "PrestigeNodeSelected", nodeId = nodeId })
				end
				if not purchasePrestigeNode then
					return
				end
				local ok, result = pcall(function()
					return purchasePrestigeNode:InvokeServer(nodeId)
				end)
				if ok and typeof(result) == "table" then
					prestigeStateCache = result
					prestigeStateDirty = false
					applyPrestigeState(result)
				end
			end)
		end
		local pos = prestigeNodePositions[nodeId] or Vector2.new(0, 0)
		button.Position = UDim2.new(0.5, pos.X, 0.5, pos.Y)
		prestigeNodeButtons[nodeId] = button
		return button
	end

	local function updatePrestigeNodeButton(button, nodeId, def, state)
		if not button or not state or typeof(def) ~= "table" then
			return
		end
		local title = def.title or nodeId
		local unlocks = typeof(state.unlocks) == "table" and state.unlocks or {}
		local unlocked = unlocks[nodeId] == true
		local points = tonumber(state.prestigePoints) or 0
		local cost = tonumber(def.cost) or 0
		local prereq = def.prereq
		local prereqMet = true
		if prereq then
			prereqMet = unlocks[prereq] == true
		end
		local canAfford = points >= cost and prereqMet
		button.Active = (not unlocked) and canAfford
		button.Selectable = (not unlocked) and canAfford
		if unlocked then
			button.Text = string.format("%s\nUNLOCKED", title)
			button.BackgroundColor3 = Color3.fromRGB(18, 60, 36)
		elseif canAfford then
			button.Text = string.format("%s\nCOST: %d", title, cost)
			button.BackgroundColor3 = Color3.fromRGB(26, 40, 70)
		else
			button.Text = string.format("%s\nLOCKED", title)
			button.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
		end
	end

	applyPrestigeState = function(state)
		if typeof(state) ~= "table" then
			return
		end
		local prestigeCount = tonumber(state.prestige) or 0
		local points = tonumber(state.prestigePoints) or 0
		local header = prestigePanelHeader and prestigePanelHeader:FindFirstChild("Header")
		if header then
			local countLabel = header:FindFirstChild("PrestigeCountLabel")
			if countLabel and countLabel:IsA("TextLabel") then
				countLabel.Text = string.format("Prestige %d", prestigeCount)
			end
			if prestigePointsLabel and prestigePointsLabel:IsA("TextLabel") then
				prestigePointsLabel.Text = string.format("PP: %d", points)
			end
		end

		local nodes = typeof(state.nodes) == "table" and state.nodes or {}
		for nodeId, def in pairs(nodes) do
			local button = ensurePrestigeNodeButton(nodeId, def)
			if button then
				updatePrestigeNodeButton(button, nodeId, def, state)
			end
		end
		if PrestigeUpgradesController and PrestigeUpgradesController.UpdateState then
			PrestigeUpgradesController.UpdateState(state)
		end
	end

	local function fetchPrestigeState(force)
		if prestigeStateInFlight then
			return
		end
		if not force and not prestigeStateDirty and prestigeStateCache then
			return
		end
		if not getPrestigeState then
			return
		end
		prestigeStateInFlight = true
		local ok, result = pcall(function()
			return getPrestigeState:InvokeServer()
		end)
		prestigeStateInFlight = false
		if ok and typeof(result) == "table" then
			prestigeStateCache = result
			prestigeStateDirty = false
			applyPrestigeState(result)
		end
	end

	local function showStats()
		setActivePage(statsPageName)
	end

	local function showLeaderboard()
		setActivePage(leaderboardsPageName)
		if leaderboardCache then
			renderLeaderboard(leaderboardCache)
		end
		fetchLeaderboard(true)
	end
	local function showPrestige()
		setActivePage(prestigePageName)
		if prestigeStateCache then
			applyPrestigeState(prestigeStateCache)
		end
		fetchPrestigeState(false)
	end
	local function showCommunity()
		setActivePage(communityPageName)
		if CommunityController and CommunityController.Open then
			CommunityController.Open()
		end
	end

	if statsTab and statsTab:IsA("GuiButton") then
		statsTab.Active = true
		statsTab.MouseButton1Click:Connect(showStats)
	end
	if leaderboardTab and leaderboardTab:IsA("GuiButton") then
		leaderboardTab.Active = true
		leaderboardTab.MouseButton1Click:Connect(showLeaderboard)
	end
	if prestigeTab and prestigeTab:IsA("GuiButton") then
		prestigeTab.Active = true
		prestigeTab.MouseButton1Click:Connect(showPrestige)
	end
	if communityTab and communityTab:IsA("GuiButton") then
		communityTab.Active = true
		communityTab.MouseButton1Click:Connect(showCommunity)
	end
	showStats()

	local remotesFolder = safeWait(ReplicatedStorage, "Remotes", 5)
	if not remotesFolder then
		warn("[TerminalClient] Remotes folder missing")
		return
	end

	local requestSync = safeWait(remotesFolder, "RequestSync", 5)
	if not requestSync or not requestSync:IsA("RemoteFunction") then
		warn("[TerminalClient] RequestSync remote missing")
		return
	end
	requestLeaderboard = remotesFolder:FindFirstChild("RequestLeaderboard")
	if requestLeaderboard and not requestLeaderboard:IsA("RemoteFunction") then
		if DEBUG_LEADERBOARD then
			warn("[TerminalClient] RequestLeaderboard is not a RemoteFunction")
		end
		requestLeaderboard = nil
	end
	uxEvent = remotesFolder:FindFirstChild("ClientUXEvent")
	if uxEvent and not uxEvent:IsA("RemoteEvent") then
		uxEvent = nil
	end
	getPrestigeState = remotesFolder:FindFirstChild("GetPrestigeState")
	if getPrestigeState and not getPrestigeState:IsA("RemoteFunction") then
		getPrestigeState = nil
	end
	purchasePrestigeNode = remotesFolder:FindFirstChild("PurchasePrestigeNode")
	if purchasePrestigeNode and not purchasePrestigeNode:IsA("RemoteFunction") then
		purchasePrestigeNode = nil
	end

	task.spawn(function()
		while true do
			task.wait(LEADERBOARD_REFRESH_SECONDS)
			fetchLeaderboard(false)
		end
	end)

	local buyUpgradeEvent = remotesFolder:FindFirstChild("RequestBuyUpgrade")
	local prestigeEvent = remotesFolder:FindFirstChild("RequestPrestige")
	local saveStatusEvent = safeWait(remotesFolder, "SaveStatus", 5)

	local function collectChildrenNames(container)
		if not container then
			return {}
		end

		local names = {}
		for _, child in container:GetChildren() do
			table.insert(names, child.Name)
		end

		return names
	end

	local template = playerGui:FindFirstChild("UpgradeCardTemplate")
	if not template then
		warn(string.format("[TerminalClient] UpgradeCardTemplate missing in PlayerGui (children: %s)", table.concat(collectChildrenNames(playerGui), ", ")))
		template = ReplicatedStorage:FindFirstChild("UpgradeCardTemplate")
		if not template then
			warn("[TerminalClient] UpgradeCardTemplate missing in ReplicatedStorage")
			return
		end
	end

	if template:IsA("GuiObject") then
		template.Visible = false
	end

	local toastLabel = safeArea:FindFirstChild("ToastMessage")
	if not toastLabel then
		toastLabel = Instance.new("TextLabel")
		toastLabel.Name = "ToastMessage"
		toastLabel.BackgroundTransparency = 1
		toastLabel.TextColor3 = Color3.new(1, 1, 1)
		toastLabel.TextStrokeTransparency = 0.5
		toastLabel.Font = Enum.Font.GothamBold
		toastLabel.TextSize = 20
		toastLabel.Text = ""
		toastLabel.AnchorPoint = Vector2.new(0.5, 0)
		toastLabel.Position = UDim2.new(0.5, 0, 0.05, 0)
		toastLabel.Size = UDim2.new(0.3, 0, 0, 30)
		toastLabel.Visible = false
		toastLabel.Parent = safeArea
	end

	local upgradeControllerModule = script.Parent:FindFirstChild("UpgradeController")
	if not upgradeControllerModule then
		warn("[TerminalClient] UpgradeController missing")
		return
	end
	UpgradeController = require(upgradeControllerModule)

	local storeControllerModule = script.Parent:FindFirstChild("StoreUIController")
	local StoreUIController = storeControllerModule and require(storeControllerModule)
	local communityControllerModule = script.Parent:FindFirstChild("CommunityController")
	local CommunityController = communityControllerModule and require(communityControllerModule)
	local prestigeUpgradesControllerModule = script.Parent:FindFirstChild("PrestigeUpgradesController")
	if prestigeUpgradesControllerModule then
		PrestigeUpgradesController = require(prestigeUpgradesControllerModule)
	end
	local storeRoot = safeArea:FindFirstChild("StoreUI") or safeArea:FindFirstChild("StoreOverlay")
		local function handleSync(payload)
			lastPayload = payload
			if StoreUIController then
				StoreUIController.Update(payload)
			end
		end
	if StoreUIController then
		StoreUIController.Init({
			terminalGui = terminalUi,
			terminalUi = terminalUi,
			storeRoot = storeRoot,
			player = player,
			uxEvent = uxEvent,
			onRequestSync = function()
				if UpgradeController.RequestSyncNow then
					UpgradeController.RequestSyncNow()
				end
			end,
		})
	end
	if CommunityController then
		CommunityController.Init({
			player = player,
			ReplicatedStorage = ReplicatedStorage,
			communityPage = communityPage,
			likeGoals = communityLikeGoals,
			likesLabel = communityLikesLabel,
			milestoneList = communityMilestoneList,
			milestoneTemplate = communityMilestoneTemplate,
			milestoneEmpty = communityMilestoneEmpty,
			progressBar = communityProgressBar,
			progressFill = communityProgressFill,
			nextRewardLabel = communityNextRewardLabel,
			claimNextButton = communityClaimNextButton,
			claimAllButton = communityClaimAllButton,
			favoriteClaimButton = communityFavoriteClaimButton,
			favoriteStatusLabel = communityFavoriteStatusLabel,
			errorLabel = communityErrorLabel,
			retryButton = communityRetryButton,
			toastLabel = toastLabel,
		})
	end
	if PrestigeUpgradesController then
		PrestigeUpgradesController.Init({
			player = player,
			ReplicatedStorage = ReplicatedStorage,
			template = template,
			container = prestigeUpgradesList,
			requestPrestigeState = getPrestigeState,
			NumberFormatter = NumberFormatter,
			toastLabel = toastLabel,
		})
	end

		UpgradeController.Init({
		terminalGui = terminalUi,
		UpgradeConfig = UpgradeConfig,
		NumberFormatter = NumberFormatter,
		RunService = RunService,
		TweenService = TweenService,
		template = template,
		cpuCardsFolder = cpuCardsFolder,
		ramCardsFolder = ramCardsFolder,
		stoCardsFolder = stoCardsFolder,
		dataValueLabel = dataValueLabel,
		statsDpsValue = statsDpsValue,
		statsPrestigeValue = statsPrestigeValue,
		statsCorePowerValue = statsCorePowerValue,
		systemCpuValue = systemCpuValue,
		systemRamValue = systemRamValue,
		systemStorageValue = systemStorageValue,
		multBaseValue = multBaseValue,
		multAddValue = multAddValue,
		multUpgradeValue = multUpgradeValue,
		multPrestigeValue = multPrestigeValue,
		multPassValue = multPassValue,
		multBoostValue = multBoostValue,
		multFinalValue = multFinalValue,
			prestigeButton = prestigeButton,
			prestigeOverlay = prestigeOverlay,
			prestigeBox = prestigeBox,
			prestigePanel = prestigePanel,
			prestigePointsLabel = prestigePointsLabel,
			prestigePreviewLabel = prestigePreviewLabel,
			prestigeLevelLabel = prestigeLevelLabel,
			prestigeLifetimeLabel = prestigeLifetimeLabel,
			prestigeTreeViewport = prestigeTreeViewport,
			autoCpuLabel = autoCpuLabel,
			autoRamLabel = autoRamLabel,
			autoStoLabel = autoStoLabel,
			requestSync = requestSync,
		buyUpgradeEvent = buyUpgradeEvent,
		prestigeEvent = prestigeEvent,
		saveStatusEvent = saveStatusEvent,
		toastLabel = toastLabel,
		MarketplaceService = game:GetService("MarketplaceService"),
		Players = Players,
		player = player,
			onSync = handleSync,
			onPrestige = function()
				prestigeStateDirty = true
				if activePage == prestigePageName then
					fetchPrestigeState(true)
				end
			end,
			onReady = function()
				upgradeReady = true
			end,
	})

		if DebugConfig then
			DebugConfig.Log(("[UI SYNC CHECK] TerminalUI source: %s Controllers mounted: YES Normalization disabled post-init: %s"):format(terminalUi:GetFullName(), tostring(upgradeReady)))
		end
	end)

	if not success then
		warn("[TerminalClient] Initialization failed:", errorMessage)
		return
	end

	print("[TerminalClient] Initialized successfully")
end

return TerminalController
