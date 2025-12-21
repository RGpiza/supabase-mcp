local UpgradeController = {}

local initialized = false
local DebugTrace = nil
local DebugConfig = nil
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

function UpgradeController.Init(ctx)
	if initialized then
		return true
	end
	initialized = true

	local Players = ctx.Players or game:GetService("Players")
	local localPlayer = ctx.player or Players.LocalPlayer
	local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	local liveTerminal = playerGui and playerGui:FindFirstChild("TerminalUI")
	if not ctx.terminalGui or not liveTerminal or ctx.terminalGui ~= liveTerminal then
		warn("[UpgradeController] terminalGui is not PlayerGui.TerminalUI")
		return false
	end

	local UpgradeConfig = ctx.UpgradeConfig
	local NumberFormatter = ctx.NumberFormatter
	local RunService = ctx.RunService
	local TweenService = ctx.TweenService
	local MarketplaceService = ctx.MarketplaceService or game:GetService("MarketplaceService")
	local template = ctx.template
	local cpuCardsFolder = ctx.cpuCardsFolder
	local ramCardsFolder = ctx.ramCardsFolder
	local stoCardsFolder = ctx.stoCardsFolder
	local dataValueLabel = ctx.dataValueLabel
	local statsDpsValue = ctx.statsDpsValue
	local statsPrestigeValue = ctx.statsPrestigeValue
	local statsCorePowerValue = ctx.statsCorePowerValue
	local systemCpuValue = ctx.systemCpuValue
	local systemRamValue = ctx.systemRamValue
	local systemStorageValue = ctx.systemStorageValue
	local multBaseValue = ctx.multBaseValue
	local multAddValue = ctx.multAddValue
	local multUpgradeValue = ctx.multUpgradeValue
	local multPrestigeValue = ctx.multPrestigeValue
	local multPassValue = ctx.multPassValue
	local multBoostValue = ctx.multBoostValue
	local multFinalValue = ctx.multFinalValue
	local prestigeButton = ctx.prestigeButton
	local prestigeOverlay = ctx.prestigeOverlay
	local requestSync = ctx.requestSync
	local buyUpgradeEvent = ctx.buyUpgradeEvent
	local prestigeEvent = ctx.prestigeEvent
	local saveStatusEvent = ctx.saveStatusEvent
	local toastLabel = ctx.toastLabel
	local onSync = ctx.onSync

	local playerState = {
		data = 0,
		upgrades = {},
		prestige = 0,
		corePower = 0,
		owns2xData = false,
		ownsFasterAuto = false,
		boostExpiresAt = 0,
		boostEnd = 0,
		passes = {},
	}

	local upgradeCards = {}
	local boundUpgrades = {}
	local purchaseDebounce = {}
	local prestigeEnabled = true
	local prestigeInFlight = false
	local lastCanPrestige = false
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
	local syncStateFromServer
	local saveStatusHideToken
	local warnedMissingDef = {}
	local validatedUpgradeIds = false
	local cachedPassOwnership = {
		owns2xData = false,
		ownsFasterAuto = false,
	}

	local PASS_IDS = {
		TwoXData = 1635206515,
		FasterAuto = 1635120464,
	}

	local BASE_DPS = 1
	local PRESTIGE_UNIT = 0.1

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
		button.AutoButtonColor = true
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
		if not saveStatusEvent or not saveStatusEvent:IsA("RemoteEvent") then
			return
		end
		if state == "saving" then
			saveStatusEvent:FireServer("saving")
		elseif state == "saved" then
			saveStatusEvent:FireServer("saved")
		elseif state == "offline" then
			saveStatusEvent:FireServer("offline")
		end
	end

	local cpuUpgrades = UpgradeConfig.GetUpgradesByBranch("CPU")
	local ramUpgrades = UpgradeConfig.GetUpgradesByBranch("RAM")

	local function refreshPassOwnership()
		if not localPlayer or not MarketplaceService then
			return
		end
		task.spawn(function()
			local ok2x, owns2x = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, localPlayer.UserId, PASS_IDS.TwoXData)
			if ok2x then
				cachedPassOwnership.owns2xData = owns2x == true
			end
			local okFast, ownsFast = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, localPlayer.UserId, PASS_IDS.FasterAuto)
			if okFast then
				cachedPassOwnership.ownsFasterAuto = ownsFast == true
			end
		end)
	end

	refreshPassOwnership()

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

	local function updateStats()
		if statsDpsValue then
			statsDpsValue.Text = formatNumber(playerState.data)
			statsDpsValue.TextTransparency = 0
			if DebugTrace then
				DebugTrace.LogUpdate(statsDpsValue:GetFullName(), statsDpsValue.Text)
			end
		end
		if statsCorePowerValue then
			statsCorePowerValue.Text = formatNumber(lastKnownDps)
			statsCorePowerValue.TextTransparency = 0
			if DebugTrace then
				DebugTrace.LogUpdate(statsCorePowerValue:GetFullName(), statsCorePowerValue.Text)
			end
		end
		if statsPrestigeValue then
			statsPrestigeValue.Text = string.format("Prestige %d", playerState.prestige or 0)
			statsPrestigeValue.TextTransparency = 0
			if DebugTrace then
				DebugTrace.LogUpdate(statsPrestigeValue:GetFullName(), statsPrestigeValue.Text)
			end
		end
	end

	local function setLabel(label, value, formatter)
		if not label then
			return
		end
		if value == nil then
			label.Text = "—"
			if label:IsA("TextLabel") or label:IsA("TextButton") then
				label.TextTransparency = 0
			end
			return
		end
		if formatter then
			label.Text = formatter(value)
			if label:IsA("TextLabel") or label:IsA("TextButton") then
				label.TextTransparency = 0
			end
			return
		end
		label.Text = tostring(value)
		if label:IsA("TextLabel") or label:IsA("TextButton") then
			label.TextTransparency = 0
		end
	end

	local function formatMultiplier(value)
		if typeof(value) ~= "number" then
			return "—"
		end
		return string.format("x%.2f", value)
	end

	local function updateSystemStats(payload)
		local dataValue = typeof(payload.data) == "number" and payload.data or playerState.data
		local prestigeValue = typeof(payload.prestige) == "number" and payload.prestige or playerState.prestige
		local corePowerValue = typeof(payload.corePower) == "number" and payload.corePower or playerState.corePower
		local production = typeof(payload.production) == "table" and payload.production or nil
		local dpsValue = production and production.final
		if typeof(dpsValue) ~= "number" then
			dpsValue = typeof(payload.finalDps) == "number" and payload.finalDps
				or (typeof(payload.dps) == "number" and payload.dps)
				or lastKnownDps
		end

		lastKnownDps = dpsValue
		playerState.data = dataValue
		playerState.prestige = prestigeValue
		playerState.corePower = corePowerValue
		if typeof(payload.owns2xData) == "boolean" then
			playerState.owns2xData = payload.owns2xData
		end
		if typeof(payload.ownsFasterAuto) == "boolean" then
			playerState.ownsFasterAuto = payload.ownsFasterAuto
		end
		if typeof(payload.boostExpiresAt) == "number" then
			playerState.boostExpiresAt = payload.boostExpiresAt
		end
		if typeof(payload.boostEnd) == "number" then
			playerState.boostEnd = payload.boostEnd
		end
		if typeof(payload.passes) == "table" then
			playerState.passes = payload.passes
		end

		updateStats()

		local systemStats = typeof(payload.system) == "table" and payload.system or {}
		setLabel(systemCpuValue, systemStats.cpu, formatNumber)
		setLabel(systemRamValue, systemStats.ram, formatNumber)
		setLabel(systemStorageValue, systemStats.storage, formatNumber)

		if production then
			setLabel(multBaseValue, production.base, formatNumber)
			setLabel(multAddValue, production.add, formatNumber)
			setLabel(multUpgradeValue, production.mulUpgrade, formatMultiplier)
			setLabel(multPrestigeValue, production.mulPrestige, formatMultiplier)
			setLabel(multPassValue, production.mulPass, formatMultiplier)
			setLabel(multBoostValue, production.mulBoost, formatMultiplier)
			setLabel(multFinalValue, production.final, formatNumber)
		else
			setLabel(multBaseValue, nil)
			setLabel(multAddValue, nil)
			setLabel(multUpgradeValue, nil)
			setLabel(multPrestigeValue, nil)
			setLabel(multPassValue, nil)
			setLabel(multBoostValue, nil)
			setLabel(multFinalValue, nil)
		end

		if DebugConfig then
			DebugConfig.Log(("[UpgradeController] Stats update data=%s dps=%s prestige=%s core=%s"):format(
				tostring(dataValue),
				tostring(dpsValue),
				tostring(prestigeValue),
				tostring(corePowerValue)
			))
		end

		if dataValueLabel then
			dataValueLabel.Text = formatNumber(dataValue)
			dataValueLabel.TextTransparency = 0
		end

		local expectedDataText = formatNumber(dataValue)
		if DebugConfig and dataValueLabel and dataValueLabel.Text ~= expectedDataText then
			DebugConfig.Warn(string.format("[UI SYNC] DataValue mismatch expected=%s actual=%s path=%s time=%s", expectedDataText, tostring(dataValueLabel.Text), dataValueLabel:GetFullName(), tostring(os.time())))
		end
		if DebugConfig and statsDpsValue and statsDpsValue.Text ~= formatNumber(dpsValue) then
			DebugConfig.Warn(string.format("[UI SYNC] Stat1 mismatch expected=%s actual=%s path=%s time=%s", formatNumber(dpsValue), tostring(statsDpsValue.Text), statsDpsValue:GetFullName(), tostring(os.time())))
		end
		local expectedPrestige = string.format("Prestige %d", playerState.prestige or 0)
		if DebugConfig and statsPrestigeValue and statsPrestigeValue.Text ~= expectedPrestige then
			DebugConfig.Warn(string.format("[UI SYNC] Stat3 mismatch expected=%s actual=%s path=%s time=%s", expectedPrestige, tostring(statsPrestigeValue.Text), statsPrestigeValue:GetFullName(), tostring(os.time())))
		end
	end

	local function buildEffectText(upgrade, level, maxLevel)
		if maxLevel ~= -1 and level >= maxLevel then
			if upgrade.branch == "STORAGE" then
				return "UNLOCKED"
			end
			return "Maxed"
		end
		if not upgrade or not upgrade.effect then
			return "Upgrade"
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

	local function updatePrestigeUI(canPrestige)
		lastCanPrestige = canPrestige
		local enabled = prestigeEnabled and canPrestige and not prestigeInFlight
		if prestigeButton then
			setButtonState(prestigeButton, enabled, enabled and "PRESTIGE" or "LOCKED")
			prestigeButton.Active = enabled
		end
		if prestigeOverlay then
			prestigeOverlay.Visible = not canPrestige or not prestigeEnabled
			prestigeOverlay.Active = not canPrestige or not prestigeEnabled
		end
	end

	local function setPrestigeState(canPrestige)
		updatePrestigeUI(canPrestige)
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
		if typeof(cardEntry) ~= "table" then
			return
		end
		local cfg = UpgradeConfig.getUpgradeById(upgradeId)
		if not cfg then
			if DebugConfig then
				DebugConfig.Warn("[UpgradeController] Missing config for upgradeId:", upgradeId)
			end
			if cardEntry.card then
				cardEntry.card.Visible = false
			end
			return
		end
		local upgrade = cfg
		local currentLevel = getUpgradeLevel(upgradeId)
		local maxLevel = cfg.maxLevel
		if maxLevel == nil then
			maxLevel = -1
		end
		local requirement = upgradeRequirements[upgradeId] or 0
		local storageTier = UpgradeConfig.GetStorageTier(playerState.upgrades or {})
		local nextCost = UpgradeConfig.getUpgradeCost(upgradeId, currentLevel)
		local atMax = maxLevel ~= -1 and currentLevel >= maxLevel
		local hasStorage = storageTier >= requirement
		local hasData = typeof(playerState.data) == "number" and nextCost and playerState.data >= nextCost

		if cardEntry.levelLabel then
			if maxLevel == -1 then
				cardEntry.levelLabel.Text = string.format("Level %d / ∞", currentLevel)
			else
				cardEntry.levelLabel.Text = string.format("Level %d / %d", currentLevel, maxLevel)
			end
		end
		if cardEntry.effectLabel then
			cardEntry.effectLabel.Text = buildEffectText(upgrade, currentLevel, maxLevel)
		end
		if cardEntry.costLabel then
			if atMax then
				cardEntry.costLabel.Text = "Maxed"
			elseif upgrade.branch == "STORAGE" and currentLevel >= 1 then
				cardEntry.costLabel.Text = "OWNED"
			elseif nextCost then
				cardEntry.costLabel.Text = string.format("Cost: %s", formatNumber(nextCost))
			else
				cardEntry.costLabel.Text = "Cost: --"
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
			buttonStateText = "OWNED"
		elseif not hasStorage then
			enabled = false
			buttonStateText = "LOCKED"
		elseif not hasData then
			enabled = false
			buttonStateText = nextCost and ("NEED " .. formatNumber(nextCost)) or "NEED"
		end
		setButtonState(cardEntry.buyButton, enabled, buttonStateText)
		if cardEntry.card then
			cardEntry.card.BackgroundTransparency = (currentLevel > 0 or atMax) and 0.2 or 0
		end
		if cardEntry.costLabel and not hasStorage then
			cardEntry.costLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
		elseif cardEntry.costLabel then
			cardEntry.costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		if cardEntry.card then
			local stroke = cardEntry.card:FindFirstChildOfClass("UIStroke")
			if not stroke then
				stroke = Instance.new("UIStroke")
				stroke.Thickness = 1
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = cardEntry.card
			end
			if currentLevel > 0 then
				stroke.Color = Color3.fromRGB(100, 200, 255)
				stroke.Transparency = 0.1
			else
				stroke.Color = Color3.fromRGB(120, 120, 120)
				stroke.Transparency = 0.6
			end
		end
	end

	local function refreshAllUpgradeCards()
		local count = 0
		for upgradeId in pairs(upgradeCards) do
			refreshUpgradeCard(upgradeId)
			count += 1
		end
		local currentTier = UpgradeConfig.GetStorageTier(playerState.upgrades or {})
		setPrestigeState(currentTier >= 3)
		if DebugConfig then
			DebugConfig.Log(("[UpgradeController] Refreshed cards=%d"):format(count))
		end
	end

	local function handleBuyUpgrade(upgradeId)
		if not buyUpgradeEvent then
			warn("[UpgradeController] Buy upgrade remote missing")
			return
		end
		if purchaseDebounce[upgradeId] then
			return
		end
		purchaseDebounce[upgradeId] = true
		if DebugConfig then
			DebugConfig.Log(("[UpgradeController] clicked upgradeId=%s"):format(tostring(upgradeId)))
		end
		buyUpgradeEvent:FireServer(upgradeId)
		task.delay(0.25, function()
			purchaseDebounce[upgradeId] = nil
			refreshUpgradeCard(upgradeId)
			updateStats()
			syncStateFromServer(true)
		end)
	end

	local function handlePrestige()
		if not prestigeEnabled or prestigeInFlight then
			return
		end
		if not prestigeEvent then
			warn("[UpgradeController] Prestige remote missing")
			return
		end
		prestigeInFlight = true
		updatePrestigeUI(lastCanPrestige)
		print("[Prestige] Clicked")
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
			owns2xData = typeof(state.owns2xData) == "boolean" and state.owns2xData or false,
			ownsFasterAuto = typeof(state.ownsFasterAuto) == "boolean" and state.ownsFasterAuto or false,
			boostExpiresAt = typeof(state.boostExpiresAt) == "number" and state.boostExpiresAt or 0,
			boostEnd = typeof(state.boostEnd) == "number" and state.boostEnd or 0,
			passes = typeof(state.passes) == "table" and state.passes or {},
		}
		return sanitized
	end

	local function applyState(newState, shouldHighlight)
		playerState = sanitizeState(newState)
		predictedData = playerState.data
		displayedData = playerState.data
		updateSystemStats(newState)
		if not validatedUpgradeIds then
			validatedUpgradeIds = true
			for upgradeId in pairs(playerState.upgrades or {}) do
				if not UpgradeConfig.getUpgradeById(upgradeId) then
					if DebugConfig then
						DebugConfig.Warn("[UpgradeController] Unknown upgradeId in state:", upgradeId)
					end
				end
			end
		end
		refreshAllUpgradeCards()
		if prestigeInFlight then
			prestigeInFlight = false
			updatePrestigeUI(lastCanPrestige)
		end
		local tier = UpgradeConfig.GetStorageTier(playerState.upgrades or {})
		if shouldHighlight then
			applyStorageTierHighlights(tier)
		else
			lastKnownTier = tier
		end
		if typeof(onSync) == "function" then
			onSync(newState)
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
				warn("[UpgradeController] RequestSync failed", result)
				setSaveStatus("offline")
				return
			end
			if typeof(result) ~= "table" then
				warn("[UpgradeController] Invalid sync payload")
				return
			end
			if DebugConfig then
				DebugConfig.Log("[UpgradeController] RequestSync success")
			end
			applyState(result, shouldHighlight)
		end)
	end

	UpgradeController.RequestSyncNow = function()
		syncStateFromServer(true)
	end

	local function createUpgradeCard(upgrade, parentFolder)
		if not template or not parentFolder then
			return
		end
		if upgradeCards[upgrade.id] then
			return
		end
		if not upgrade or typeof(upgrade.id) ~= "string" then
			return
		end

		local definition = UpgradeConfig.getUpgradeById(upgrade.id)
		if not definition and not warnedMissingDef[upgrade.id] then
			warnedMissingDef[upgrade.id] = true
			if DebugConfig then
				DebugConfig.Warn(("[UpgradeController] Missing upgrade definition for %s"):format(upgrade.id))
			end
		end

		local card = template:Clone()
		card.Visible = true
		card.Name = upgrade.id
		card.Parent = parentFolder

		local titleLabel = card:FindFirstChild("CardTitle") or card:FindFirstChild("Title")
		if titleLabel then
			titleLabel.Text = (definition and definition.name) or upgrade.name or upgrade.id
			titleLabel.TextTransparency = 0
			titleLabel.Visible = true
			if DebugConfig then
				DebugConfig.Log(("[UpgradeController] title set %s = %s"):format(upgrade.id, titleLabel.Text))
			end
		end

		local descriptionLabel = card:FindFirstChild("CardDesc") or card:FindFirstChild("Description")
		if descriptionLabel then
			descriptionLabel.Text = (definition and (definition.description or definition.desc)) or upgrade.description or "Upgrade your system performance."
			descriptionLabel.TextTransparency = 0
			descriptionLabel.Visible = true
		end

		local buyButton = card:FindFirstChild("CardBuyButton") or card:FindFirstChild("BuyButton")
		if buyButton then
			applyHoverEffects(buyButton)
			buyButton.Active = true
			buyButton.AutoButtonColor = true
			buyButton.Visible = true
			buyButton.ZIndex = math.max(buyButton.ZIndex, 5)
			if not boundUpgrades[upgrade.id] then
				boundUpgrades[upgrade.id] = true
				if DebugConfig then
					DebugConfig.Log(("[UpgradeController] button bound upgradeId=%s"):format(upgrade.id))
				end
				buyButton.MouseButton1Click:Connect(function()
					handleBuyUpgrade(upgrade.id)
				end)
			end
		end

		if upgrade.branch == "STORAGE" then
			stylizeStorageCard(card, false)
		end

		upgradeCards[upgrade.id] = {
			card = card,
			definition = definition or upgrade,
			buyButton = buyButton,
			costLabel = card:FindFirstChild("CardCostLabel") or card:FindFirstChild("CostLabel"),
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

	UpgradeController.SetPrestigeEnabled = function(enabled)
		prestigeEnabled = enabled and true or false
		updatePrestigeUI(lastCanPrestige)
	end

	if saveStatusEvent then
		local ok, err = pcall(function()
			saveStatusEvent.OnClientEvent:Connect(function(state)
				local successState, callbackErr = pcall(function()
					setSaveStatus(state)
				end)
				if not successState then
					warn("[UpgradeController] Failed to handle save status", callbackErr)
				end
			end)
		end)
		if not ok then
			warn("[UpgradeController] Failed to bind SaveStatus event", err)
		end
	else
		warn("[UpgradeController] SaveStatus remote missing")
		setSaveStatus("offline")
	end

	syncStateFromServer(false)

	local syncInterval = 6
	local syncTimer = 0

	RunService.RenderStepped:Connect(function(dt)
		predictedData += math.max(lastKnownDps, 0) * dt
		displayedData = displayedData + ((predictedData - displayedData) * math.clamp(dt * 4, 0, 1))
		if dataValueLabel then
			dataValueLabel.Text = formatNumber(displayedData)
		end

		local boostEnd = tonumber(playerState.boostEnd) or tonumber(playerState.boostExpiresAt) or 0
		local remaining = boostEnd - os.time()
		if remaining > 0 and statsPrestigeValue then
			-- no-op: boost timer no longer writes into Stat3
		end

		syncTimer += dt
		if syncTimer >= syncInterval then
			syncTimer = 0
			syncStateFromServer(true)
		end
	end)

	if typeof(ctx.onReady) == "function" then
		ctx.onReady()
	end
	print("[INIT] UpgradeController initialized")
	return true
end

return UpgradeController
