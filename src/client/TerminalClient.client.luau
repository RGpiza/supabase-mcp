local DEBUG = false
local initialized = false

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
		if DEBUG then
			print("[TerminalClient]", ...)
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

	local function forceUIVisible()
		terminalUi.Enabled = true
		terminalUi.DisplayOrder = 100

		local function forcePanel(frame)
			if frame and frame:IsA("Frame") then
				frame.Visible = true
				frame.BackgroundTransparency = 0
			elseif frame and frame:IsA("GuiObject") then
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
					local title = child:FindFirstChild("CardTitle") or child:FindFirstChild("Title")
					local desc = child:FindFirstChild("CardDesc") or child:FindFirstChild("Description")
					local cost = child:FindFirstChild("CardCostLabel") or child:FindFirstChild("Cost")
					if title and title:IsA("TextLabel") then
						title.TextTransparency = 0
					end
					if desc and desc:IsA("TextLabel") then
						desc.TextTransparency = 0
					end
					if cost and cost:IsA("TextLabel") then
						cost.TextTransparency = 0
					end
					local buyButton = child:FindFirstChild("CardBuyButton") or child:FindFirstChild("BuyButton")
					if buyButton and buyButton:IsA("GuiButton") then
						buyButton.Active = true
						buyButton.AutoButtonColor = true
						buyButton.Selectable = true
					end
				end
			end
		end

		forceCards(cpuCardsFolder)
		forceCards(ramCardsFolder)
		forceCards(stoCardsFolder)

		local storeOverlay = safeArea:FindFirstChild("StoreOverlay")
		if storeOverlay and storeOverlay:IsA("GuiObject") then
			storeOverlay.Visible = false
		end

		local bgOne = 0
		local textOne = 0
		for _, desc in ipairs(terminalUi:GetDescendants()) do
			if desc:IsA("GuiObject") and desc.BackgroundTransparency >= 1 then
				bgOne += 1
			end
			if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.TextTransparency >= 1 then
				textOne += 1
			end
		end
		print(("[TerminalClient] Transparency dump: Background=1 count=%d Text=1 count=%d"):format(bgOne, textOne))
		if bgOne > 0 or textOne > 0 then
			for _, desc in ipairs(terminalUi:GetDescendants()) do
				if desc:IsA("GuiObject") and desc.BackgroundTransparency >= 1 then
					print(("[TerminalClient] BackgroundTransparency=1: %s"):format(desc:GetFullName()))
				end
				if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.TextTransparency >= 1 then
					print(("[TerminalClient] TextTransparency=1: %s"):format(desc:GetFullName()))
				end
			end
		end
	end

	normalizeBackgrounds()
	forceUIVisible()
	print("[UI FIX] Background transparency normalization complete")

	local statsBox = safeWait(rightPanel, "StatsBox", 5)
	local statsDpsValue = statsBox and statsBox:FindFirstChild("DpsValue")
	local statsPrestigeValue = statsBox and statsBox:FindFirstChild("PrestigeValue")
	local statsCorePowerValue = statsBox and statsBox:FindFirstChild("CorePowerValue")

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

	local systemCpuValue = findLabelByNames(rightPanel, { "CpuValue", "CPUValue", "CpuStatValue", "CPUStatValue", "CpuStat", "CPUStat" })
	local systemRamValue = findLabelByNames(rightPanel, { "RamValue", "RAMValue", "RamStatValue", "RAMStatValue", "RamStat", "RAMStat" })
	local systemStorageValue = findLabelByNames(rightPanel, { "StorageValue", "STOValue", "StorageStatValue", "STOStatValue", "StorageStat", "STOStat" })

	local multBaseValue = findLabelByNames(rightPanel, { "BaseValue", "BaseOutputValue", "BaseStatValue" })
	local multAddValue = findLabelByNames(rightPanel, { "AddValue", "AdditiveValue", "AdditiveStatValue" })
	local multUpgradeValue = findLabelByNames(rightPanel, { "UpgradeMultiplierValue", "UpgradeMulValue", "UpgradeMultiplier" })
	local multPrestigeValue = findLabelByNames(rightPanel, { "PrestigeMultiplierValue", "PrestigeMulValue", "PrestigeMultiplier" })
	local multPassValue = findLabelByNames(rightPanel, { "PassMultiplierValue", "PassMulValue", "PassMultiplier" })
	local multBoostValue = findLabelByNames(rightPanel, { "BoostMultiplierValue", "BoostMulValue", "BoostMultiplier" })
	local multFinalValue = findLabelByNames(rightPanel, { "FinalValue", "FinalDpsValue", "FinalStatValue" })

	local prestigeBox = safeWait(rightPanel, "PrestigeBox", 5)
	local prestigeButton = prestigeBox and prestigeBox:FindFirstChild("PrestigeButton")
	local prestigeOverlay = prestigeBox and prestigeBox:FindFirstChild("PrestigeLockedOverlay")

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
	local UpgradeController = require(upgradeControllerModule)

	local storeControllerModule = script.Parent:FindFirstChild("StoreUIController")
	local StoreUIController = storeControllerModule and require(storeControllerModule)
	local storeRoot = safeArea:FindFirstChild("StoreUI") or safeArea:FindFirstChild("StoreOverlay")
	local function handleSync(payload)
		if StoreUIController then
			StoreUIController.Update(payload)
		end
	end
	if StoreUIController then
		StoreUIController.Init({
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
	})
end)

if not success then
	warn("[TerminalClient] Initialization failed:", errorMessage)
	return
end

print("[TerminalClient] Initialized successfully")
