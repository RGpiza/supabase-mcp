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
	local statsCorePowerValue = nil
	if DebugTrace then
		DebugTrace.LogBind(statsPage and statsPage:GetFullName() or "Pages.StatsBox", statsPage ~= nil)
	end
	if statsPage and statsPage:IsA("GuiObject") then
		statsPage.Visible = true
	end

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
	local prestigeButton = prestigeBox and prestigeBox:FindFirstChild("PrestigeButton")
	local prestigeOverlay = prestigeBox and prestigeBox:FindFirstChild("PrestigeLockedOverlay")
	if DebugTrace then
		DebugTrace.LogBind(prestigeButton and prestigeButton:GetFullName() or "PrestigeButton", prestigeButton ~= nil)
	end
	if prestigeBox and prestigeBox:IsA("GuiObject") then
		prestigeBox.Visible = true
	end

	local statsHeader = rightPanel:FindFirstChild("StatsHeader")
	local tabs = rightPanel:FindFirstChild("Tabs")
	local statsTab = tabs and tabs:FindFirstChild("StatsTab")
	local leaderboardTab = tabs and tabs:FindFirstChild("LeaderboardTab")
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
	local lastPayload = nil
	local leaderboardCache = nil
	local leaderboardCacheUntil = 0
	local lastLeaderboardHash = nil
	local lastRenderedHash = nil
	local requestLeaderboard = nil
	local leaderboardRequested = false
	local leaderboardInFlight = false
	local lastLeaderboardFetch = 0
	local LEADERBOARD_REFRESH_SECONDS = 30
	local LEADERBOARD_CACHE_SECONDS = 15
	local DEBUG_LEADERBOARD = false
	local UpgradeController
	local activePage = "Stats"
	local statsPageName = "Stats"
	local leaderboardsPageName = "Leaderboards"

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
		else
			targetPage = pages:FindFirstChild(pageName)
		end
		assert(targetPage and targetPage:IsA("Frame"), ("[TerminalClient] Page '%s' missing under Pages"):format(tostring(pageName)))
		if statsPage and statsPage:IsA("Frame") then
			statsPage.Visible = (pageName == statsPageName)
		end
		if leaderboardsPage and leaderboardsPage:IsA("Frame") then
			leaderboardsPage.Visible = (pageName == leaderboardsPageName)
		end
		for _, child in ipairs(pages:GetChildren()) do
			if child:IsA("Frame") and child ~= statsPage and child ~= leaderboardsPage and child ~= prestigeBox then
				child.Visible = (pageName == child.Name)
			end
		end
		targetPage.Visible = true
		if prestigeBox and prestigeBox:IsA("GuiObject") then
			prestigeBox.Visible = (pageName == statsPageName)
		end
		if prestigeButton and prestigeButton:IsA("GuiButton") then
			prestigeButton.Visible = prestigeBox and prestigeBox.Visible or false
			prestigeButton.Active = prestigeBox and prestigeBox.Visible or false
			prestigeButton.Selectable = prestigeBox and prestigeBox.Visible or false
		end
		print(("[TerminalClient][UI TAB] activePage=%s"):format(tostring(pageName)))
		print(("[TerminalClient][UI TAB] StatsBox.Visible=%s Leaderboards.Visible=%s PrestigeBox.Visible=%s"):format(
			tostring(statsPage and statsPage.Visible),
			tostring(leaderboardsPage and leaderboardsPage.Visible),
			tostring(prestigeBox and prestigeBox.Visible)
		))
		if not statsPage or not leaderboardsPage or not prestigeBox then
			print(("[TerminalClient][UI TAB] Paths StatsBox=%s Leaderboards=%s PrestigeBox=%s"):format(
				statsPage and statsPage:GetFullName() or "nil",
				leaderboardsPage and leaderboardsPage:GetFullName() or "nil",
				prestigeBox and prestigeBox:GetFullName() or "nil"
			))
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

	local function setRowText(row, entry, shouldWarn)
		if not row or typeof(entry) ~= "table" then
			return
		end
		local rankLabel = row:FindFirstChild("Rank")
		local nameLabel = row:FindFirstChild("PlayerName")
		local scoreLabel = row:FindFirstChild("Value")

		if not (
			rankLabel
			and nameLabel
			and scoreLabel
			and rankLabel:IsA("TextLabel")
			and nameLabel:IsA("TextLabel")
			and scoreLabel:IsA("TextLabel")
		) then
			if shouldWarn and DEBUG_LEADERBOARD then
				warn("[TerminalClient][Leaderboard] Missing row fields on RowTemplate")
			end
			return
		end

		rankLabel.Text = tostring(entry.rank)
		nameLabel.Text = tostring(entry.name or entry.username or "Unknown")
		scoreLabel.Text = NumberFormatter.format(entry.value)
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

	local function setYourRank(entry)
		if not yourRankPanel or not yourRankPanel:IsA("GuiObject") then
			return
		end
		if not entry then
			yourRankPanel.Visible = false
			return
		end
		yourRankPanel.Visible = true
		setRowText(yourRankPanel, entry, false)
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
			setYourRank(nil)
			local row = rowTemplate:Clone()
			row.Visible = true
			row.LayoutOrder = 0
			row:SetAttribute("__LeaderboardRow", true)
			row.Parent = listFrame
			setRowText(row, { rank = "-", username = "No entries yet", value = 0 }, true)
			return
		end
		local hash = computeLeaderboardHash(entries)
		if hash == lastRenderedHash then
			return
		end
		clearLeaderboardRows()
		lastRenderedHash = hash
		setSkeletonsVisible(false)
		local created = 0
		local localEntry = nil
		for _, entry in ipairs(entries) do
			local row = rowTemplate:Clone()
			row.Visible = true
			row.LayoutOrder = tonumber(entry.rank) or 0
			row:SetAttribute("__LeaderboardRow", true)
			row.Parent = listFrame
			setRowText(row, entry, true)
			created += 1
			if player and entry.userId == player.UserId then
				localEntry = entry
			end
		end
		setYourRank(localEntry)
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
		if shouldRender and activePage == "Leaderboards" then
			renderLeaderboard(leaderboardCache)
		end
	end

	local function showStats()
		setActivePage("Stats")
	end

	local function showLeaderboard()
		setActivePage("Leaderboards")
		if leaderboardCache then
			renderLeaderboard(leaderboardCache)
		end
		fetchLeaderboard(true)
	end

	if statsTab and statsTab:IsA("GuiButton") then
		statsTab.Active = true
		statsTab.MouseButton1Click:Connect(showStats)
	end
	if leaderboardTab and leaderboardTab:IsA("GuiButton") then
		leaderboardTab.Active = true
		leaderboardTab.MouseButton1Click:Connect(showLeaderboard)
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
			onRequestSync = function()
				if UpgradeController.RequestSyncNow then
					UpgradeController.RequestSyncNow()
				end
			end,
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
		requestSync = requestSync,
		buyUpgradeEvent = buyUpgradeEvent,
		prestigeEvent = prestigeEvent,
		saveStatusEvent = saveStatusEvent,
		toastLabel = toastLabel,
		MarketplaceService = game:GetService("MarketplaceService"),
		Players = Players,
		player = player,
		onSync = handleSync,
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
