local LoadingInitializer = {}

function LoadingInitializer.Init()
	local success, errorMessage = pcall(function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local MarketplaceService = game:GetService("MarketplaceService")
	local UserInputService = game:GetService("UserInputService")
	local TerminalUIBinder = require(script.Parent:WaitForChild("TerminalUIBinder"))
	local ToastController = require(script.Parent:WaitForChild("ToastController"))
	local StoreUIController = require(script.Parent:WaitForChild("StoreUIController"))
	local BoostUIController = require(script.Parent:WaitForChild("BoostUIController"))
	local StarterGui = game:GetService("StarterGui")

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	if not player then
		warn("[TerminalClient] LocalPlayer missing")
		return
	end

	local clientReadyFlag = false
	local readyCallbacks = {}

	local function signalClientReady()
		if clientReadyFlag then
			return
		end

		clientReadyFlag = true

		if player then
			player:SetAttribute("ClientReady", true)
		end

		for _, callback in ipairs(readyCallbacks) do
			task.defer(callback)
		end
		table.clear(readyCallbacks)
	end

	local function safeFind(parent, name)
		if not parent then
			return nil
		end
		return parent:FindFirstChild(name)
	end
	local WAIT_TIMEOUT = 5
	local LOADING_UI_DISPLAY_ORDER = 999999
	local READY_TIMEOUT = 15

	local function waitForChildWithTimeout(parent, childName)
		if not parent then
			return nil
		end

		local ok, child = pcall(function()
			return parent:WaitForChild(childName, WAIT_TIMEOUT)
		end)

		if ok then
			return child
		end

		return nil
	end

	local function cloneLoadingUi(parent)
		if not parent or not StarterGui then
			return nil
		end

		local template = StarterGui:FindFirstChild("LoadingUI")
		if not template then
			return nil
		end

		local clone = template:Clone()
		if clone:IsA("LayerCollector") then
			clone.ResetOnSpawn = false
		end
		clone.Parent = parent
		return clone
	end

	local function ensureLoadingUiProperties(ui)
		if not ui then
			return
		end

		if ui:IsA("LayerCollector") then
			ui.DisplayOrder = LOADING_UI_DISPLAY_ORDER
			ui.Enabled = true
			ui.ResetOnSpawn = false
		elseif ui:IsA("GuiObject") then
			ui.Visible = true
			ui.ZIndex = math.max(ui.ZIndex, LOADING_UI_DISPLAY_ORDER)
		end

		local background = safeFind(ui, "Background")
		if background and background:IsA("GuiObject") then
			background.Visible = true
		end
	end

	local playerGui = player:WaitForChild("PlayerGui", 5)
	if not playerGui then
		warn("[TerminalClient] PlayerGui missing")
		return
	end

	local loadingUi = playerGui:FindFirstChild("LoadingUI")
	if not loadingUi then
		loadingUi = cloneLoadingUi(playerGui)
	end
	if not loadingUi then
		loadingUi = waitForChildWithTimeout(playerGui, "LoadingUI")
	end
	if loadingUi then
		ensureLoadingUiProperties(loadingUi)
	end

	local remotesFolder = waitForChildWithTimeout(ReplicatedStorage, "Remotes") or safeFind(ReplicatedStorage, "Remotes")
	local loadingProgressEvent = remotesFolder and safeFind(remotesFolder, "LoadingProgress")
	local storeAnalyticsEvent = remotesFolder and safeFind(remotesFolder, "StoreAnalyticsEvent")
	local boostsUpdatedEvent = remotesFolder and safeFind(remotesFolder, "BoostsUpdated")
	local offlinePreviewEvent = remotesFolder and safeFind(remotesFolder, "OfflineEarningsPreview")

	local loadingBackground = loadingUi and safeFind(loadingUi, "Background")
	local loadingStatus = loadingUi and safeFind(loadingUi, "Status") or (loadingBackground and safeFind(loadingBackground, "Status"))
	local loadingBarBack = (loadingBackground and safeFind(loadingBackground, "BarBack")) or (loadingUi and safeFind(loadingUi, "BarBack"))
	local loadingBarFill = loadingBarBack and safeFind(loadingBarBack, "BarFill")
	local loadingBarFillBaseSize = loadingBarFill and loadingBarFill.Size or UDim2.new(1, 0, 1, 0)

	local handleLoadingProgress
	local pendingLoadingUpdates = {}
	local loadingBarTween
	local loadingUiFadeTween
	local loadingUiFinalized = false
	local loadingInputLocked = false
	local previousModalState = UserInputService.ModalEnabled
	local readyFired = false
	local serverReady = false
	local localReady = false
	local latestServerProgress = 0
	local failsafeWarned = false

	local function setBarFillInstant(scale)
		if loadingBarFill and loadingBarFill:IsA("GuiObject") then
			loadingBarFill.Size = UDim2.new(
				math.clamp(scale, 0, 1),
				loadingBarFillBaseSize.X.Offset,
				loadingBarFillBaseSize.Y.Scale,
				loadingBarFillBaseSize.Y.Offset
			)
		end
	end

	local function lockLoadingInput()
		if loadingInputLocked then
			return
		end

		loadingInputLocked = true
		previousModalState = UserInputService.ModalEnabled
		UserInputService.ModalEnabled = true
	end

	local function unlockLoadingInput()
		if not loadingInputLocked then
			return
		end

		loadingInputLocked = false
		UserInputService.ModalEnabled = previousModalState
	end

	if loadingUi then
		lockLoadingInput()
	end

	if loadingBarFill then
		setBarFillInstant(0)
	end

	local function destroyLoadingUi()
		if loadingUi then
			if loadingUi:IsA("LayerCollector") then
				loadingUi.Enabled = false
			elseif loadingUi:IsA("GuiObject") then
				loadingUi.Visible = false
			end
			loadingUi:Destroy()
			loadingUi = nil
		end

		loadingBackground = nil
		loadingStatus = nil
		loadingBarFill = nil
		loadingBarBack = nil
		table.clear(pendingLoadingUpdates)

		unlockLoadingInput()

		signalClientReady()
	end

	local function finalizeLoadingUi()
		if loadingUiFinalized then
			return
		end

		loadingUiFinalized = true

		if loadingBarTween then
			loadingBarTween:Cancel()
			loadingBarTween = nil
		end

		if loadingUiFadeTween then
			loadingUiFadeTween:Cancel()
			loadingUiFadeTween = nil
		end

		local fadeTarget = (loadingBackground and loadingBackground:IsA("GuiObject")) and loadingBackground or loadingUi
		if fadeTarget and fadeTarget:IsA("GuiObject") then
			if loadingStatus and loadingStatus:IsA("TextLabel") then
				TweenService:Create(
					loadingStatus,
					TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ TextTransparency = 1 }
				):Play()
			end

			if loadingBarFill and loadingBarFill:IsA("GuiObject") then
				TweenService:Create(
					loadingBarFill,
					TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ BackgroundTransparency = 1 }
				):Play()
			end

			loadingUiFadeTween = TweenService:Create(
				fadeTarget,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ BackgroundTransparency = 1 }
			)
			loadingUiFadeTween.Completed:Connect(function()
				loadingUiFadeTween = nil
				destroyLoadingUi()
			end)
			loadingUiFadeTween:Play()
		else
			destroyLoadingUi()
		end
	end

	local function applyLoadingProgress(statusText, progress)
		if loadingUiFinalized then
			return
		end

		lockLoadingInput()

		if typeof(statusText) == "string" and loadingStatus and loadingStatus:IsA("TextLabel") then
			loadingStatus.Text = statusText
		end

		local numericProgress = tonumber(progress)
		if numericProgress then
			numericProgress = math.clamp(numericProgress, 0, 1)

			if loadingBarFill and loadingBarFill:IsA("GuiObject") then
				if loadingBarTween then
					loadingBarTween:Cancel()
				end

				local tween = TweenService:Create(
					loadingBarFill,
					TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Size = UDim2.new(
							numericProgress,
							loadingBarFillBaseSize.X.Offset,
							loadingBarFillBaseSize.Y.Scale,
							loadingBarFillBaseSize.Y.Offset
						),
					}
				)
				loadingBarTween = tween
				tween.Completed:Connect(function()
					if loadingBarTween == tween then
						loadingBarTween = nil
					end
				end)
				tween:Play()
			end

		end
	end

	local function setLoadingStep(stepName, progress)
		applyLoadingProgress(stepName, progress)
	end

	local function setLoadingStep(stepName, progress)
		applyLoadingProgress(stepName, progress)
	end

	local function trySetReady(force)
		if readyFired then
			return
		end

		if not force then
			if not (serverReady and localReady) then
				return
			end
		end

		readyFired = true

		setLoadingStep("Finalizing", 1)

		if not loadingUiFinalized then
			finalizeLoadingUi()
		else
			unlockLoadingInput()
			if not loadingUi then
				signalClientReady()
			end
		end
	end

	handleLoadingProgress = function(statusText, progress)
		if not loadingUi then
			table.insert(pendingLoadingUpdates, { statusText, progress })
			if typeof(progress) == "number" and progress >= 1 then
				finalizeLoadingUi()
			end
			return
		end

		applyLoadingProgress(statusText, progress)
	end

	local function flushPendingLoadingProgress()
		if not loadingUi or #pendingLoadingUpdates == 0 then
			return
		end

		local queued = table.clone(pendingLoadingUpdates)
		table.clear(pendingLoadingUpdates)
		for _, payload in ipairs(queued) do
			applyLoadingProgress(payload[1], payload[2])
		end
	end

	if loadingUi then
		handleLoadingProgress("Preparing UI", 0)
		flushPendingLoadingProgress()
	end

	if remotesFolder then
		setLoadingStep("Connecting Remotes", 0.05)
	end

	local serverStepMap = {
		["Loading data"] = { name = "Loading Player Data", progress = 0.25 },
		["Applying offline earnings"] = { name = "Applying Offline Earnings", progress = 0.5 },
		["Syncing boosts"] = { name = "Syncing Boosts", progress = 0.75 },
		["Finalizing"] = { name = "Finalizing", progress = 1 },
	}

	if loadingProgressEvent then
		loadingProgressEvent.OnClientEvent:Connect(function(message, progress)
			local mapped = serverStepMap[message]
			local resolvedProgress = progress
			if mapped then
				resolvedProgress = mapped.progress
				setLoadingStep(mapped.name, resolvedProgress)
			else
				handleLoadingProgress(message, progress)
			end

			if typeof(resolvedProgress) == "number" then
				local clamped = math.clamp(resolvedProgress, 0, 1)
				if clamped > latestServerProgress then
					latestServerProgress = clamped
				end
				if clamped >= 1 then
					serverReady = true
					trySetReady(false)
				end
			end
		end)
	end

	task.delay(READY_TIMEOUT, function()
		if readyFired then
			return
		end

		if not failsafeWarned then
			failsafeWarned = true
			warn("[TerminalClient] Loading timed out, forcing ready")
		end

		trySetReady(true)
	end)

	local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
	local NumberFormatter = require(sharedFolder:WaitForChild("NumberFormatter"))

	local context = {
		player = player,
		playerGui = playerGui,
		safeFind = safeFind,
		waitForChildWithTimeout = waitForChildWithTimeout,
		TweenService = TweenService,
		MarketplaceService = MarketplaceService,
		UserInputService = UserInputService,
		NumberFormatter = NumberFormatter,
		IsClientReady = function()
			return clientReadyFlag
		end,
		OnClientReady = function(callback)
			if clientReadyFlag then
				task.defer(callback)
			else
				table.insert(readyCallbacks, callback)
			end
		end,
		remotes = {
			storeAnalyticsEvent = storeAnalyticsEvent,
			boostsUpdatedEvent = boostsUpdatedEvent,
			offlinePreviewEvent = offlinePreviewEvent,
		},
	}

	if not TerminalUIBinder.Init(context) then
		return
	end

	local ui = context.ui
	local root = ui.root
	local safeArea = ui.safeArea
	local topBar = ui.topBar
	local main = ui.main
	local columns = ui.columns
	local cpuCards = ui.cpuCards
	local ramCards = ui.ramCards
	local stoCards = ui.stoCards
	local statsBox = ui.statsBox
	local prestigeBox = ui.prestigeBox
	local toastArea = ui.toastArea

	local dataValueLabel = safeFind(topBar, "DataValue")
	if not dataValueLabel then
		warn("[TerminalClient] DataValue missing")
		return
	end

	local statsLabels = {
		safeFind(statsBox, "Stat1"),
		safeFind(statsBox, "Stat2"),
		safeFind(statsBox, "Stat3"),
	}

	local toastController = ToastController.Init(context)
	local storeController = StoreUIController.Init(context)
	local boostController = BoostUIController.Init(context)
	local showToast = toastController and toastController.ShowToast or function() end

	if storeController then
		if storeController.RefreshGamepassOwnership then
			storeController.RefreshGamepassOwnership()
		end
		setLoadingStep("Checking Store Ownership", 0.8)
	end

	local prestigeButton = safeFind(prestigeBox, "PrestigeButton")
	local prestigeOverlay = safeFind(prestigeBox, "PrestigeLockedOverlay")

	local template = playerGui:FindFirstChild("UpgradeCardTemplate")
	if not template then
		warn("[TerminalClient] UpgradeCardTemplate missing")
		return
	end

	if template:IsA("GuiObject") then
		template.Visible = false
	end

	if not remotesFolder then
		warn("[TerminalClient] Remotes folder missing")
		return
	end

	local requestSync = safeFind(remotesFolder, "RequestSync")
	local buyUpgradeEvent = safeFind(remotesFolder, "RequestBuyUpgrade")
	local prestigeEvent = safeFind(remotesFolder, "RequestPrestige")
	if not (requestSync and buyUpgradeEvent and prestigeEvent) then
		warn("[TerminalClient] Required remotes missing")
		return
	end

	local UpgradeConfig = require(sharedFolder:WaitForChild("UpgradeConfig"))

	local function formatIntegerWithCommas(value)
		local str = tostring(value)
		while true do
			local formatted, k = str:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
			str = formatted
			if k == 0 then
				break
			end
		end
		return str
	end

	local function formatDataValueText(value)
		local n = typeof(value) == "number" and value or 0
		if n < 0 then
			n = 0
		end

		if n < 100_000 then
			local integerPart = math.floor(n)
			local fractionalPart = n - integerPart

			local formatted = formatIntegerWithCommas(integerPart)
			if fractionalPart > 0 then
				local fractionalText = string.sub(string.format("%.3f", fractionalPart), 2)
				fractionalText = fractionalText:gsub("0+$", "")
				if fractionalText ~= "." then
					formatted ..= fractionalText
				end
			end

			return formatted
		end

		local suffix
		local divisor

		if n < 1_000_000 then
			suffix = "K"
			divisor = 1_000
		elseif n < 1_000_000_000 then
			suffix = "M"
			divisor = 1_000_000
		else
			suffix = "B"
			divisor = 1_000_000_000
		end

		local scaled = math.floor((n / divisor) * 100) / 100
		return string.format("%.2f%s", scaled, suffix)
	end

	local playerState = {
		data = 0,
		upgrades = {},
		prestige = 0,
		corePower = 0,
	}
	local cachedState = nil
	local uiUpdateStarted = false
	local displayedData = nil

	local upgradeCards = {}
	local syncLoopStarted = false
	local syncLoopWarningIssued = false

	local function getUpgradeLevel(upgradeId)
		local level = playerState.upgrades[upgradeId]
		if typeof(level) ~= "number" then
			return 0
		end
		return math.max(level, 0)
	end

	local function applyStateToUI(state)
		if not state then
			return
		end

		if statsLabels[1] then
			local dpsValue = typeof(state.dps) == "number" and state.dps or 0
			statsLabels[1].Text = string.format("Data/sec: %s", NumberFormatter.format(dpsValue))
		end

		local cpuLevelSum = 0
		if typeof(state.upgrades) == "table" then
			for upgradeId, level in pairs(state.upgrades) do
				if typeof(level) == "number" and string.sub(upgradeId, 1, 4) == "cpu_" then
					cpuLevelSum += math.max(level, 0)
				end
			end
		end

		if statsLabels[2] then
			statsLabels[2].Text = string.format("CPU Level: %d", cpuLevelSum)
		end

		if statsLabels[3] then
			local prestigeValue = typeof(state.prestige) == "number" and state.prestige or 0
			local coreValue = typeof(state.corePower) == "number" and state.corePower or 0
			statsLabels[3].Text = string.format("Prestige: %d | Core: %s", prestigeValue, NumberFormatter.format(coreValue))
		end
	end

	local function setPrestigeState(canPrestige)
		if prestigeButton then
			prestigeButton.Active = canPrestige
			prestigeButton.Text = canPrestige and "PRESTIGE" or "LOCKED"
		end
		if prestigeOverlay then
			prestigeOverlay.Visible = not canPrestige
		end
	end

	local function applyGlow(card, active)
		if not card then
			return
		end
		local stroke = card:FindFirstChild("AffordStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "AffordStroke"
			stroke.Thickness = 2
			stroke.Color = Color3.fromRGB(120, 255, 180)
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = card
		end
		stroke.Transparency = active and 0.25 or 0.7
	end

	local function refreshCard(upgradeId)
		local cardData = upgradeCards[upgradeId]
		if not cardData then
			return
		end

		local definition = cardData.definition
		local currentLevel = getUpgradeLevel(upgradeId)
		local nextCost = UpgradeConfig.GetCost(upgradeId, currentLevel)
		local hasCost = typeof(nextCost) == "number"
		local canAfford = hasCost and (playerState.data or 0) >= nextCost
		local meetsRequirements = UpgradeConfig.MeetsRequirements(playerState.upgrades, upgradeId)
		local atMax = currentLevel >= definition.maxLevel

		if cardData.title then
			cardData.title.Text = string.format("%s (Lv %d/%d)", definition.name, currentLevel, definition.maxLevel)
		end
		if cardData.description then
			cardData.description.Text = definition.description
		end

		if cardData.costLabel then
			if atMax then
				cardData.costLabel.Text = "Maxed"
			elseif hasCost then
				cardData.costLabel.Text = string.format("Cost: %s", NumberFormatter.format(nextCost))
			else
				cardData.costLabel.Text = "Cost: --"
			end
		end

		local buttonEnabled = cardData.button and not atMax and meetsRequirements and hasCost and canAfford
		if cardData.button then
			cardData.button.Text = atMax and "MAX" or "BUY"
			cardData.button.Active = buttonEnabled
			cardData.button.AutoButtonColor = buttonEnabled
		end

		applyGlow(cardData.card, buttonEnabled)
	end

	local function refreshAllCards()
		for upgradeId in pairs(upgradeCards) do
			refreshCard(upgradeId)
		end

		local storageTier = UpgradeConfig.GetStorageTier(playerState.upgrades)
		setPrestigeState(storageTier >= 3)
	end

	local function ensureUiUpdateLoop()
		if uiUpdateStarted then
			return
		end
		uiUpdateStarted = true

		task.spawn(function()
			while task.wait(0.1) do
				if not script.Parent then
					break
				end
				if cachedState then
					applyStateToUI(cachedState)
				end
			end
			uiUpdateStarted = false
		end)
	end

	local function applyState(newState)
		playerState.data = typeof(newState.data) == "number" and newState.data or 0
		playerState.upgrades = typeof(newState.upgrades) == "table" and newState.upgrades or {}
		playerState.prestige = typeof(newState.prestige) == "number" and newState.prestige or 0
		playerState.corePower = typeof(newState.corePower) == "number" and newState.corePower or 0
		if typeof(newState.dps) == "number" then
			playerState.dps = newState.dps
		else
			playerState.dps = 0
		end

		local stateClone = table.clone(newState)
		stateClone.data = playerState.data
		stateClone.upgrades = playerState.upgrades
		stateClone.prestige = playerState.prestige
		stateClone.corePower = playerState.corePower
		stateClone.dps = typeof(newState.dps) == "number" and newState.dps or 0
		cachedState = stateClone

		if displayedData == nil then
			displayedData = playerState.data
		else
			local targetValue = playerState.data or 0
			local snapThreshold = math.max(math.abs(targetValue) * 0.05, 100)
			if math.abs(targetValue - displayedData) > snapThreshold then
				displayedData = targetValue
			end
		end

		refreshAllCards()
	end

	local function syncState()
		local payload
		local ok, err = pcall(function()
			payload = requestSync:InvokeServer()
		end)

		if not ok then
			warn("[TerminalClient] RequestSync failed", err)
			return
		end

		if typeof(payload) ~= "table" then
			warn("[TerminalClient] Invalid sync payload")
			return
		end

		applyState(payload)
	end

	local function handleBuy(upgradeId)
		if not buyUpgradeEvent then
			return
		end
		buyUpgradeEvent:FireServer(upgradeId)
		task.defer(function()
			syncState()
		end)
	end

	local function handlePrestige()
		if not prestigeEvent then
			return
		end
		prestigeEvent:FireServer()
		task.defer(function()
			syncState()
		end)
	end

	local function buildUpgradeCards()
		local function createCard(definition, parentFolder)
			if not parentFolder then
				return
			end
			local card = template:Clone()
			card.Name = definition.id
			card.Parent = parentFolder
			card.Visible = true

			local title = card:FindFirstChild("Title") or card:FindFirstChild("CardTitle")
			local description = card:FindFirstChild("Description") or card:FindFirstChild("CardDesc")
			local costLabel = card:FindFirstChild("CostLabel") or card:FindFirstChild("CardCostLabel")
			local button = card:FindFirstChild("BuyButton") or card:FindFirstChild("CardBuyButton")

			if button then
				button.MouseButton1Click:Connect(function()
					handleBuy(definition.id)
				end)
			end

			upgradeCards[definition.id] = {
				card = card,
				title = title,
				description = description,
				costLabel = costLabel,
				button = button,
				definition = definition,
			}
		end

		for _, definition in ipairs(UpgradeConfig.GetUpgradesByBranch("CPU")) do
			createCard(definition, cpuCards)
		end
		for _, definition in ipairs(UpgradeConfig.GetUpgradesByBranch("RAM")) do
			createCard(definition, ramCards)
		end
		for _, definition in ipairs(UpgradeConfig.GetUpgradesByBranch("STORAGE")) do
			createCard(definition, stoCards)
		end
	end

	local function startSyncLoop()
		if syncLoopStarted then
			return
		end
		syncLoopStarted = true

		task.spawn(function()
			while script.Parent do
				task.wait(0.5)

				if not requestSync then
					if not syncLoopWarningIssued then
						warn("[TerminalClient] RequestSync missing, stopping poll loop")
						syncLoopWarningIssued = true
					end
					break
				end

				local payload
				local ok, result = pcall(function()
					return requestSync:InvokeServer()
				end)

				if not ok then
					local err = result
					if not syncLoopWarningIssued then
						warn("[TerminalClient] RequestSync poll failed:", err)
						syncLoopWarningIssued = true
					end
					break
				else
					payload = result
				end

				if typeof(payload) == "table" then
					applyState(payload)
				end
			end

			syncLoopStarted = false
		end)
	end

	buildUpgradeCards()
	setLoadingStep("Initializing Terminal UI", 0.9)
	ensureUiUpdateLoop()
	syncState()
	startSyncLoop()

	if prestigeButton then
		prestigeButton.MouseButton1Click:Connect(handlePrestige)
	end

	RunService.RenderStepped:Connect(function(dt)
		if not dataValueLabel then
			return
		end

		local frameDt = typeof(dt) == "number" and dt or 0

		local targetData = 0
		if cachedState and typeof(cachedState.data) == "number" then
			targetData = cachedState.data
		elseif typeof(playerState.data) == "number" then
			targetData = playerState.data
		end

		if displayedData == nil then
			displayedData = targetData
		end

		local snapThreshold = math.max(math.abs(targetData) * 0.05, 100)
		if math.abs(targetData - displayedData) > snapThreshold then
			displayedData = targetData
		else
			local alpha = 1 - math.exp(-frameDt * 10)
			displayedData = displayedData + (targetData - displayedData) * alpha
		end

		local predictedDps = 0
		if cachedState and typeof(cachedState.dps) == "number" then
			predictedDps = cachedState.dps
		end

		if predictedDps ~= 0 and frameDt > 0 then
			displayedData += predictedDps * frameDt
		end

		local maxOvershoot = math.max(25, math.abs(targetData) * 0.01, math.abs(predictedDps) * 0.5)
		if displayedData > targetData + maxOvershoot then
			displayedData = targetData + maxOvershoot
		end
		if displayedData < 0 then
			displayedData = 0
		end

		dataValueLabel.Text = formatDataValueText(displayedData)
	end)

	localReady = true
	trySetReady(false)
end)

	if not success then
		warn("[TerminalClient] Initialization failed:", errorMessage)
	end
end

return LoadingInitializer
