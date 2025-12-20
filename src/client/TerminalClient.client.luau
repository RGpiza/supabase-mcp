<<<<<<< HEAD
return
=======
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

	local statsBox = safeWait(rightPanel, "StatsBox", 5)
	local statsDpsValue = statsBox and statsBox:FindFirstChild("DpsValue")
	local statsPrestigeValue = statsBox and statsBox:FindFirstChild("PrestigeValue")
	local statsCorePowerValue = statsBox and statsBox:FindFirstChild("CorePowerValue")

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

	local playerState = {
		data = 0,
		upgrades = {},
		prestige = 0,
		corePower = 0,
	}

	local upgradeCards = {}
	local storageTierMap = {
		[1] = "sto_1",
		[2] = "sto_2",
		[3] = "sto_3",
	}
	local upgradeRequirements = {
		sto_2 = 1,
		sto_3 = 2,
		cpu_2 = 2,
		cpu_3 = 3,
		ram_2 = 2,
	}

	local lastKnownTier = 0
	local lastKnownDps = 0
	local predictedData = 0
	local displayedData = 0
	local syncInProgress = false
	local saveStatusHideToken

	local function lerpNumber(current, target, alpha)
		alpha = math.clamp(alpha, 0, 1)
		return current + ((target - current) * alpha)
	end

	local function formatNumber(value)
		return NumberFormatter.format(value or 0)
	end

	local function ensureUIScale(instance)
		if not instance then
			return nil
		end

		local uiScale = instance:FindFirstChildOfClass("UIScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Scale = 1
			uiScale.Parent = instance
		end

		return uiScale
	end

	local function applyHoverEffects(button)
		if not button or not button:IsA("TextButton") then
			return
		end

		if button:GetAttribute("HoverBound") then
			return
		end
		button:SetAttribute("HoverBound", true)

		local originalColor = button.BackgroundColor3
		local originalTextColor = button.TextColor3
		button:SetAttribute("OriginalColor", originalColor)
		button:SetAttribute("OriginalTextColor", originalTextColor)
		button.AutoButtonColor = false

		local uiScale = ensureUIScale(button)

		button.MouseEnter:Connect(function()
			if button.Active then
				button.BackgroundColor3 = originalColor:Lerp(Color3.new(1, 1, 1), 0.1)
			end
		end)

		button.MouseLeave:Connect(function()
			button.BackgroundColor3 = originalColor
			if uiScale then
				TweenService:Create(uiScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end)

		button.MouseButton1Down:Connect(function()
			if uiScale then
				TweenService:Create(uiScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.97 }):Play()
			end
		end)

		button.MouseButton1Up:Connect(function()
			if uiScale then
				TweenService:Create(uiScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end)
	end

	local function setButtonState(button, enabled, text)
		if not button then
			return
		end

		button.Text = text or button.Text
		button.Active = enabled
		button.AutoButtonColor = false
		button.Selectable = enabled
		local originalColor = button:GetAttribute("OriginalColor") or button.BackgroundColor3
		local originalTextColor = button:GetAttribute("OriginalTextColor") or button.TextColor3

		if enabled then
			button.BackgroundColor3 = originalColor
			button.TextColor3 = originalTextColor
			button.TextTransparency = 0
			button.BackgroundTransparency = 0
		else
			button.BackgroundColor3 = originalColor:Lerp(Color3.fromRGB(80, 80, 80), 0.4)
			button.TextColor3 = originalTextColor:Lerp(Color3.fromRGB(200, 200, 200), 0.4)
			button.TextTransparency = 0.1
			button.BackgroundTransparency = 0.1
		end
	end

	local function stylizeStorageCard(card, unlocked)
		if not card then
			return
		end

		local stroke = card:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = card
		end

		if unlocked then
			stroke.Color = Color3.fromRGB(255, 214, 10)
			stroke.Transparency = 0.05
		else
			stroke.Color = Color3.fromRGB(120, 200, 120)
			stroke.Transparency = 0.3
		end
	end

	local toastCooldown = false

	local function showToast(message)
		if not toastLabel then
			return
		end

		if toastCooldown then
			return
		end

		toastCooldown = true
		toastLabel.Text = message
		toastLabel.TextTransparency = 1
		toastLabel.Visible = true

		local fadeIn = TweenService:Create(toastLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })
		local fadeOut = TweenService:Create(toastLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })

		fadeIn.Completed:Connect(function()
			task.delay(1.2, function()
				fadeOut:Play()
			end)
		end)

		fadeOut.Completed:Connect(function()
			toastLabel.Visible = false
			toastCooldown = false
		end)

		fadeIn:Play()
	end

	local activePulseTweens = {}

	local function highlightStorageCard(card, tier)
		if not card then
			return
		end

		local uiScale = ensureUIScale(card)
		local pulseInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)
		local shrinkInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0, false, 0)

		if uiScale then
			if activePulseTweens[card] then
				activePulseTweens[card]:Cancel()
			end

			local tweenUp = TweenService:Create(uiScale, pulseInfo, { Scale = 1.05 })
			local tweenDown = TweenService:Create(uiScale, shrinkInfo, { Scale = 1 })
			activePulseTweens[card] = tweenUp

			tweenUp.Completed:Connect(function()
				tweenDown:Play()
				activePulseTweens[card] = nil
			end)

			tweenDown.Completed:Connect(function()
				if activePulseTweens[card] == tweenDown then
					activePulseTweens[card] = nil
				end
			end)

			tweenUp:Play()
		end

		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			local originalTransparency = stroke.Transparency
			stroke.Transparency = 0
			task.delay(0.3, function()
				if stroke then
					stroke.Transparency = originalTransparency
				end
			end)
		end

		showToast(string.format("Storage Tier %d Unlocked", tier))
	end

	local function setSaveStatus(state)
		if not saveStatusLabel then
			return
		end

		if state == "saving" then
			saveStatusLabel.Text = "Saving..."
		elseif state == "saved" then
			saveStatusLabel.Text = "Saved"
			local token = {}
			saveStatusHideToken = token
			task.delay(1.5, function()
				if saveStatusHideToken == token then
					saveStatusLabel.Text = ""
				end
			end)
		elseif state == "offline" then
			saveStatusLabel.Text = "Offline"
		end
	end

	local cpuUpgrades = UpgradeConfig.GetUpgradesByBranch("CPU")
	local ramUpgrades = UpgradeConfig.GetUpgradesByBranch("RAM")
	local BASE_DPS = 1
	local PRESTIGE_UNIT = 0.1

	local function getUpgradeLevel(upgradeId)
		if typeof(playerState.upgrades) ~= "table" then
			return 0
		end

		local level = playerState.upgrades[upgradeId]
		if typeof(level) ~= "number" then
			return 0
		end

		return math.max(level, 0)
	end

	local function calculateClientDps()
		local flat = 0
		for _, upgrade in ipairs(cpuUpgrades) do
			local level = getUpgradeLevel(upgrade.id)
			if level > 0 then
				local effect = upgrade.effect(level)
				if effect and typeof(effect.flatDps) == "number" then
					flat += effect.flatDps
				end
			end
		end

		local multiplier = 1
		for _, upgrade in ipairs(ramUpgrades) do
			local level = getUpgradeLevel(upgrade.id)
			if level > 0 then
				local effect = upgrade.effect(level)
				if effect and typeof(effect.multiplier) == "number" then
					multiplier *= effect.multiplier
				end
			end
		end

		local corePower = typeof(playerState.corePower) == "number" and playerState.corePower or 0
		local prestigeMultiplier = 1 + (corePower * PRESTIGE_UNIT)

		return (BASE_DPS + flat) * multiplier * prestigeMultiplier
	end

	local function updateStats()
		if statsDpsValue then
			statsDpsValue.Text = formatNumber(lastKnownDps)
		end

		if statsPrestigeValue then
			statsPrestigeValue.Text = string.format("Prestige %d", playerState.prestige or 0)
		end

		if statsCorePowerValue then
			statsCorePowerValue.Text = string.format("Core Power %s", formatNumber(playerState.corePower or 0))
		end
	end

	local function buildEffectText(upgrade, level)
		if level >= upgrade.maxLevel then
			if upgrade.branch == "STORAGE" then
				return "UNLOCKED"
			end
			return "Maxed"
		end

		local currentEffect = upgrade.effect(level)
		local nextEffect = upgrade.effect(level + 1)

		local currentFlat = currentEffect and currentEffect.flatDps or 0
		local nextFlat = nextEffect and nextEffect.flatDps or 0
		local currentMult = currentEffect and currentEffect.multiplier or 1
		local nextMult = nextEffect and nextEffect.multiplier or 1

		if nextFlat > currentFlat then
			local delta = nextFlat - currentFlat
			return string.format("+%s Data/sec", formatNumber(delta))
		end

		if nextMult > currentMult then
			local deltaPercent = ((nextMult - currentMult) * 100)
			return string.format("+%.0f%% Global", deltaPercent)
		end

		if upgrade.branch == "STORAGE" and nextEffect and nextEffect.storageTier then
			return string.format("Unlocks Tier %d", nextEffect.storageTier)
		end

		return "Upgrade"
	end

	local function setPrestigeState(canPrestige)
		if prestigeButton then
			setButtonState(prestigeButton, canPrestige, canPrestige and "PRESTIGE" or "LOCKED")
		end

		if prestigeOverlay then
			prestigeOverlay.Visible = not canPrestige
		end
	end

	local function applyStorageTierHighlights(newTier)
		if newTier <= lastKnownTier then
			lastKnownTier = newTier
			return
		end

		for tier = lastKnownTier + 1, newTier do
			local upgradeId = storageTierMap[tier]
			local cardEntry = upgradeCards[upgradeId]
			if cardEntry then
				highlightStorageCard(cardEntry.card, tier)
			end
		end

		lastKnownTier = newTier
	end

	local function refreshUpgradeCard(upgradeId)
		local cardEntry = upgradeCards[upgradeId]
		if not cardEntry then
			return
		end

		local upgrade = cardEntry.definition
		local currentLevel = getUpgradeLevel(upgradeId)
		local requirement = upgradeRequirements[upgradeId] or 0
		local storageTier = UpgradeConfig.GetStorageTier(playerState.upgrades or {})
		local nextCost = UpgradeConfig.getUpgradeCost(upgradeId, currentLevel)
		local atMax = currentLevel >= upgrade.maxLevel
		local hasStorage = storageTier >= requirement
		local hasData = typeof(playerState.data) == "number" and nextCost and playerState.data >= nextCost

		if cardEntry.levelLabel then
			cardEntry.levelLabel.Text = string.format("Level %d / %d", currentLevel, upgrade.maxLevel)
		end

		if cardEntry.effectLabel then
			cardEntry.effectLabel.Text = buildEffectText(upgrade, currentLevel)
		end

		if cardEntry.costLabel then
			if atMax then
				cardEntry.costLabel.Text = "Maxed"
			elseif upgrade.branch == "STORAGE" and currentLevel >= 1 then
				cardEntry.costLabel.Text = "UNLOCKED"
			elseif nextCost then
				cardEntry.costLabel.Text = string.format("Cost: %s", formatNumber(nextCost))
			end
		end

		if upgrade.branch == "STORAGE" then
			stylizeStorageCard(cardEntry.card, currentLevel >= 1)
		end

		local buttonStateText = "BUY"
		local enabled = true

		if atMax then
			enabled = false
			buttonStateText = "MAX"
		elseif upgrade.branch == "STORAGE" and currentLevel >= 1 then
			enabled = false
			buttonStateText = "UNLOCKED"
		elseif not hasStorage then
			enabled = false
			buttonStateText = "LOCKED"
		elseif not hasData then
			enabled = false
			buttonStateText = "LOCKED"
		end

		setButtonState(cardEntry.buyButton, enabled, buttonStateText)
	end

	local function refreshAllUpgradeCards()
		for upgradeId in pairs(upgradeCards) do
			refreshUpgradeCard(upgradeId)
		end

		local currentTier = UpgradeConfig.GetStorageTier(playerState.upgrades or {})
		setPrestigeState(currentTier >= 3)
	end

	local syncStateFromServer

	local function handleBuyUpgrade(upgradeId)
		if not buyUpgradeEvent then
			warn("[TerminalClient] Buy upgrade remote missing")
			return
		end

		buyUpgradeEvent:FireServer(upgradeId)
		task.delay(0.25, function()
			refreshUpgradeCard(upgradeId)
			updateStats()
			syncStateFromServer(true)
		end)
	end

	local function handlePrestige()
		if not prestigeEvent then
			warn("[TerminalClient] Prestige remote missing")
			return
		end

		prestigeEvent:FireServer()
		task.delay(0.4, function()
			syncStateFromServer(true)
		end)
	end

	local function sanitizeState(state)
		local sanitized = {
			data = typeof(state.data) == "number" and state.data or 0,
			upgrades = typeof(state.upgrades) == "table" and state.upgrades or {},
			prestige = typeof(state.prestige) == "number" and state.prestige or 0,
			corePower = typeof(state.corePower) == "number" and state.corePower or 0,
		}

		return sanitized
	end

	local function applyState(newState, shouldHighlight)
		playerState = sanitizeState(newState)
		predictedData = playerState.data
		displayedData = playerState.data

		local serverDps = typeof(newState.dps) == "number" and newState.dps or calculateClientDps()
		lastKnownDps = serverDps

		updateStats()
		refreshAllUpgradeCards()

		local tier = UpgradeConfig.GetStorageTier(playerState.upgrades or {})
		if shouldHighlight then
			applyStorageTierHighlights(tier)
		else
			lastKnownTier = tier
		end
	end

	syncStateFromServer = function(shouldHighlight)
		if syncInProgress or not requestSync then
			return
		end

		syncInProgress = true
		task.spawn(function()
			local ok, result = pcall(function()
				return requestSync:InvokeServer()
			end)
			syncInProgress = false

			if not ok then
				warn("[TerminalClient] RequestSync failed", result)
				setSaveStatus("offline")
				return
			end

			if typeof(result) ~= "table" then
				warn("[TerminalClient] Invalid sync payload")
				return
			end

			applyState(result, shouldHighlight)
		end)
	end

	local function createUpgradeCard(upgrade, parentFolder)
		if not template or not parentFolder then
			return
		end

		local card = template:Clone()
		card.Visible = true
		card.Name = upgrade.id
		card.Parent = parentFolder

		local titleLabel = card:FindFirstChild("Title")
		if titleLabel then
			titleLabel.Text = upgrade.name
		end

		local descriptionLabel = card:FindFirstChild("Description")
		if descriptionLabel then
			descriptionLabel.Text = upgrade.description
		end

		local buyButton = card:FindFirstChild("BuyButton")
		if buyButton then
			applyHoverEffects(buyButton)
			buyButton.MouseButton1Click:Connect(function()
				handleBuyUpgrade(upgrade.id)
			end)
		end

		if upgrade.branch == "STORAGE" then
			stylizeStorageCard(card, false)
		end

		upgradeCards[upgrade.id] = {
			card = card,
			definition = upgrade,
			buyButton = buyButton,
			costLabel = card:FindFirstChild("CostLabel"),
			levelLabel = card:FindFirstChild("LevelLabel"),
			effectLabel = card:FindFirstChild("EffectLabel"),
		}
	end

	for _, upgrade in ipairs(UpgradeConfig.GetUpgradesByBranch("CPU")) do
		createUpgradeCard(upgrade, cpuCardsFolder)
	end

	for _, upgrade in ipairs(UpgradeConfig.GetUpgradesByBranch("RAM")) do
		createUpgradeCard(upgrade, ramCardsFolder)
	end

	for _, upgrade in ipairs(UpgradeConfig.GetUpgradesByBranch("STORAGE")) do
		createUpgradeCard(upgrade, stoCardsFolder)
	end

	if prestigeButton then
		applyHoverEffects(prestigeButton)
		prestigeButton.MouseButton1Click:Connect(handlePrestige)
	end

	if saveStatusEvent then
		local ok, err = pcall(function()
			saveStatusEvent.OnClientEvent:Connect(function(state)
				local successState, callbackErr = pcall(function()
					setSaveStatus(state)
				end)

				if not successState then
					warn("[TerminalClient] Failed to handle save status", callbackErr)
				end
			end)
		end)

		if not ok then
			warn("[TerminalClient] Failed to bind SaveStatus event", err)
		end
	else
		warn("[TerminalClient] SaveStatus remote missing")
		setSaveStatus("offline")
	end

	syncStateFromServer(false)

	local syncInterval = 6
	local syncTimer = 0

	RunService.RenderStepped:Connect(function(dt)
		predictedData += math.max(lastKnownDps, 0) * dt
		displayedData = lerpNumber(displayedData, predictedData, math.clamp(dt * 4, 0, 1))
		dataValueLabel.Text = formatNumber(displayedData)

		syncTimer += dt
		if syncTimer >= syncInterval then
			syncTimer = 0
			syncStateFromServer(true)
		end
	end)
end)

if not success then
	warn("[TerminalClient] Initialization failed:", errorMessage)
	return
end

print("[TerminalClient] Initialized successfully")
>>>>>>> parent of 0324c3d (Add automation, group bonus, and milestone services)
