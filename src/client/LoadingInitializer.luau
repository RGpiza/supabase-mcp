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

	if player.GetAttribute and player.SetAttribute then
		player:SetAttribute("PrestigeInProgress", false)
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
	local LONG_PRESS_THRESHOLD = 0.4
	local MIN_BUTTON_HEIGHT = 44
	local PENDING_MAX_TIMEOUT = 2
	local BUY_MODE_SINGLE = "single"
	local BUY_MODE_MAX = "max"
	local isTouchOnlyDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local AUTO_TOGGLE_MIN_HEIGHT = 44
	local AUTO_TOGGLE_ON_COLOR = Color3.fromRGB(75, 255, 190)
	local AUTO_TOGGLE_OFF_COLOR = Color3.fromRGB(45, 55, 65)
	local AUTO_TOGGLE_TEXT_COLOR = Color3.fromRGB(10, 15, 20)
	local AUTO_TOGGLE_PENDING_TIMEOUT = 1.5
	local AUTO_BUY_TOAST_THRESHOLD = 10
	local AUTO_PULSE_COLOR = Color3.fromRGB(85, 255, 205)
	local AUTO_PULSE_FADE_TIME = 0.25
	local PRESTIGE_FAILSAFE_DELAY = 4

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
	local cpuColumn = ui.cpuColumn
	local ramColumn = ui.ramColumn
	local stoColumn = ui.stoColumn
	local cpuCards = ui.cpuCards
	local ramCards = ui.ramCards
	local stoCards = ui.stoCards
	local statsBox = ui.statsBox
	local prestigeBox = ui.prestigeBox
	local toastArea = ui.toastArea
	local branchConfigs = {
		CPU = {
			column = cpuColumn,
			cards = cpuCards,
			attribute = "AutoBuyCPU",
		},
		RAM = {
			column = ramColumn,
			cards = ramCards,
			attribute = "AutoBuyRAM",
		},
		STORAGE = {
			column = stoColumn,
			cards = stoCards,
			attribute = "AutoBuySTORAGE",
		},
	}
	local autoToggleButtons = {}
	local autoToggleState = {}
	local autoTogglePending = {}

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
	local prestigeRequestInFlight = false
	local lastPrestigeSynced = 0
	local prestigeFailsafeToken = 0

	local function setPrestigeAttribute(value)
		if player and player.SetAttribute then
			player:SetAttribute("PrestigeInProgress", value and true or false)
		end
	end

	local function schedulePrestigeFailsafe()
		prestigeFailsafeToken += 1
		local token = prestigeFailsafeToken
		task.delay(PRESTIGE_FAILSAFE_DELAY, function()
			if token ~= prestigeFailsafeToken then
				return
			end
			if prestigeRequestInFlight then
				prestigeRequestInFlight = false
				setPrestigeAttribute(false)
			end
		end)
	end

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
	local toggleAutoBuyEvent = safeFind(remotesFolder, "ToggleAutoBuy")
	local autoBuyFeedbackEvent = safeFind(remotesFolder, "AutoBuyFeedback")
	if not (requestSync and buyUpgradeEvent and prestigeEvent and toggleAutoBuyEvent and autoBuyFeedbackEvent) then
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

	local pendingBuyMaxQueue = {}

	local function queueBuyMaxFeedback(upgradeId)
		table.insert(pendingBuyMaxQueue, {
			id = upgradeId,
			startLevel = getUpgradeLevel(upgradeId),
			timestamp = os.clock(),
		})
	end

	local function processPendingBuyMaxFeedback()
		if #pendingBuyMaxQueue == 0 then
			return
		end

		local remaining = {}
		for _, pending in ipairs(pendingBuyMaxQueue) do
			local newLevel = getUpgradeLevel(pending.id)
			local delta = math.max(newLevel - (pending.startLevel or 0), 0)

			if delta > 0 then
				local cardData = upgradeCards[pending.id]
				if showToast then
					if cardData and cardData.definition then
						local message = string.format(
							"Bought %d %s of %s",
							delta,
							delta == 1 and "level" or "levels",
							cardData.definition.name
						)
						showToast(message)
					else
						showToast(string.format("Bought %d upgrades", delta))
					end
				end

				if delta >= 10 then
					flashMaxBadge(cardData)
				end
			else
				if os.clock() - pending.timestamp < PENDING_MAX_TIMEOUT then
					table.insert(remaining, pending)
				else
					playErrorFeedback(upgradeCards[pending.id])
				end
			end
		end

		pendingBuyMaxQueue = remaining
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

	local function ensureInteractionScale(button)
		if not button then
			return nil
		end

		local scale = button:FindFirstChild("InteractionScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "InteractionScale"
			scale.Scale = 1
			scale.Parent = button
		end

		return scale
	end

	local function playButtonFeedback(button, isMax)
		if not button or not TweenService then
			return
		end

		local scale = ensureInteractionScale(button)
		if not scale then
			return
		end

		local target = isMax and 1.08 or 1.03
		local tweenIn = TweenService:Create(
			scale,
			TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Scale = target }
		)
		tweenIn:Play()
		tweenIn.Completed:Connect(function()
			TweenService:Create(
				scale,
				TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end)
	end

	local function playErrorFeedback(cardData)
		local card = cardData and cardData.card
		if not card or not TweenService then
			return
		end

		local stroke = card:FindFirstChild("ErrorStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "ErrorStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = Color3.fromRGB(255, 115, 115)
			stroke.Transparency = 1
			stroke.Parent = card
		end

		local flash = TweenService:Create(
			stroke,
			TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Transparency = 0.2 }
		)
		flash:Play()
		flash.Completed:Connect(function()
			if not stroke.Parent then
				return
			end
			TweenService:Create(
				stroke,
				TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
				{ Transparency = 1 }
			):Play()
		end)
	end

	local function flashMaxBadge(cardData)
		local card = cardData and cardData.card
		if not card or not TweenService then
			return
		end

		local badge = card:FindFirstChild("MaxBadge")
		if not badge then
			badge = Instance.new("TextLabel")
			badge.Name = "MaxBadge"
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, -6, 0, 6)
			badge.Size = UDim2.new(0, 60, 0, 22)
			badge.BackgroundColor3 = Color3.fromRGB(72, 255, 170)
			badge.BackgroundTransparency = 0.1
			badge.TextColor3 = Color3.fromRGB(10, 35, 20)
			badge.Font = Enum.Font.GothamBold
			badge.TextSize = 12
			badge.TextXAlignment = Enum.TextXAlignment.Center
			badge.TextYAlignment = Enum.TextYAlignment.Center
			badge.Text = "MAX"
			badge.ZIndex = card.ZIndex + 1
			badge.Visible = false

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = badge

			badge.Parent = card
		end

		badge.Visible = true
		badge.TextTransparency = 1

		local fadeIn = TweenService:Create(
			badge,
			TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		)
		fadeIn:Play()

		task.delay(0.6, function()
			if not badge.Parent then
				return
			end
			TweenService:Create(
				badge,
				TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
				{ TextTransparency = 1 }
			):Play()
		end)
	end

	local function enforceMinimumButtonHeight(button)
		if not button or not button:IsA("GuiButton") then
			return
		end

		local size = button.Size
		if size.Y.Scale == 0 and size.Y.Offset < MIN_BUTTON_HEIGHT then
			button.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, MIN_BUTTON_HEIGHT)
		end
	end

	local function pulseBranchColumn(branchName)
		local config = branchConfigs[branchName]
		local column = config and config.column
		if not column or not column:IsA("GuiObject") or not TweenService then
			return
		end

		local stroke = column:FindFirstChild("AutoPulseStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "AutoPulseStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Thickness = 3
			stroke.Color = AUTO_PULSE_COLOR
			stroke.Transparency = 1
			stroke.Parent = column
		end

		local fadeIn = TweenService:Create(
			stroke,
			TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Transparency = 0.15 }
		)
		fadeIn:Play()
		fadeIn.Completed:Connect(function()
			if not stroke.Parent then
				return
			end
			TweenService:Create(
				stroke,
				TweenInfo.new(AUTO_PULSE_FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
				{ Transparency = 1 }
			):Play()
		end)
	end

	local function updateAutoToggleVisual(branchName)
		local button = autoToggleButtons[branchName]
		if not button or not button:IsA("GuiButton") then
			return
		end

		local isEnabled = autoToggleState[branchName] == true
		local isPending = autoTogglePending[branchName] ~= nil
		local backgroundColor = isEnabled and AUTO_TOGGLE_ON_COLOR or AUTO_TOGGLE_OFF_COLOR
		button.BackgroundColor3 = backgroundColor
		button.Text = "AUTO"
		button.TextColor3 = AUTO_TOGGLE_TEXT_COLOR
		button.TextTransparency = isPending and 0.35 or 0
		button.AutoButtonColor = false
		button.Active = not isPending

		local stroke = button:FindFirstChild("AutoToggleStroke")
		if stroke then
			if isEnabled then
				stroke.Color = backgroundColor:Lerp(Color3.new(1, 1, 1), 0.35)
				stroke.Transparency = isPending and 0.3 or 0.15
			else
				stroke.Color = Color3.fromRGB(90, 110, 120)
				stroke.Transparency = isPending and 0.5 or 0.35
			end
		end
	end

	local function refreshAutoToggleState(branchName)
		local config = branchConfigs[branchName]
		if not config or not config.attribute then
			autoToggleState[branchName] = false
		else
			autoToggleState[branchName] = player:GetAttribute(config.attribute) == true
		end

		updateAutoToggleVisual(branchName)
	end

	local function createAutoToggleButton(branchName, column)
		if not column or not column:IsA("GuiObject") then
			return nil
		end

		local button = Instance.new("TextButton")
		button.Name = string.format("%sAutoToggle", branchName)
		button.AutoButtonColor = false
		button.BackgroundColor3 = AUTO_TOGGLE_OFF_COLOR
		button.BorderSizePixel = 0
		button.LayoutOrder = -100
		button.Size = UDim2.new(1, 0, 0, AUTO_TOGGLE_MIN_HEIGHT)
		button.Text = "AUTO"
		button.TextColor3 = AUTO_TOGGLE_TEXT_COLOR
		button.TextSize = 16
		button.Font = Enum.Font.GothamBold
		button.TextWrapped = false
		button.ZIndex = (column.ZIndex or 1) + 1
		button.Parent = column

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Name = "AutoToggleStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 2
		stroke.Transparency = 0.35
		stroke.Parent = button

		ensureInteractionScale(button)
		return button
	end

	local function setupAutoToggleButtons()
		for branchName, config in pairs(branchConfigs) do
			local branchKey = branchName
			local branchConfig = config
			if branchConfig.column and not autoToggleButtons[branchKey] then
				local button = createAutoToggleButton(branchKey, branchConfig.column)
				if button then
					autoToggleButtons[branchKey] = button
					refreshAutoToggleState(branchKey)

					if player and player.GetAttributeChangedSignal and branchConfig.attribute then
						player:GetAttributeChangedSignal(branchConfig.attribute):Connect(function()
							autoTogglePending[branchKey] = nil
							refreshAutoToggleState(branchKey)
						end)
					end

					button.Activated:Connect(function()
						if not toggleAutoBuyEvent then
							return
						end
						if autoTogglePending[branchKey] then
							return
						end

						local desiredState = not (autoToggleState[branchKey] == true)
						autoTogglePending[branchKey] = os.clock()
						updateAutoToggleVisual(branchKey)
						playButtonFeedback(button, false)
						toggleAutoBuyEvent:FireServer(branchKey, desiredState)

						task.delay(AUTO_TOGGLE_PENDING_TIMEOUT, function()
							local pendingSince = autoTogglePending[branchKey]
							if pendingSince and os.clock() - pendingSince >= AUTO_TOGGLE_PENDING_TIMEOUT then
								autoTogglePending[branchKey] = nil
								refreshAutoToggleState(branchKey)
							end
						end)
					end)
				end
			end
		end
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

		local isUnlocked = not atMax and meetsRequirements and hasCost
		cardData.isUnlocked = isUnlocked
		cardData.canAfford = isUnlocked and canAfford

		if cardData.button then
			cardData.button.Text = atMax and "MAX" or "BUY"
			cardData.button.Active = isUnlocked
			cardData.button.AutoButtonColor = isUnlocked and not isTouchOnlyDevice
			if cardData.button:IsA("TextButton") then
				cardData.button.TextTransparency = isUnlocked and 0 or 0.35
			end
		end

		applyGlow(cardData.card, cardData.canAfford == true)
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
		local prestigeValue = typeof(newState.prestige) == "number" and newState.prestige or 0
		playerState.prestige = prestigeValue
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
		processPendingBuyMaxFeedback()

		if prestigeRequestInFlight and prestigeValue > lastPrestigeSynced then
			prestigeRequestInFlight = false
			setPrestigeAttribute(false)
			prestigeFailsafeToken += 1
		end
		lastPrestigeSynced = prestigeValue
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

	local function handleBuy(upgradeId, mode)
		if not buyUpgradeEvent then
			return
		end

		local normalizedMode = mode == BUY_MODE_MAX and BUY_MODE_MAX or BUY_MODE_SINGLE
		local cardData = upgradeCards[upgradeId]
		if not cardData or not cardData.isUnlocked then
			playErrorFeedback(cardData)
			return
		end

		if not cardData.canAfford then
			playErrorFeedback(cardData)
			return
		end

		local payload
		if normalizedMode == BUY_MODE_MAX then
			payload = {
				upgradeId = upgradeId,
				mode = BUY_MODE_MAX,
			}
			queueBuyMaxFeedback(upgradeId)
		else
			payload = upgradeId
		end

		playButtonFeedback(cardData.button, normalizedMode == BUY_MODE_MAX)
		buyUpgradeEvent:FireServer(payload)
		task.defer(syncState)
	end

	local function bindDesktopButton(button, upgradeId)
		if not button or not button:IsA("GuiButton") then
			return
		end

		button.MouseButton1Click:Connect(function()
			handleBuy(upgradeId, BUY_MODE_SINGLE)
		end)

		if UserInputService.MouseEnabled then
			button.MouseButton2Click:Connect(function()
				handleBuy(upgradeId, BUY_MODE_MAX)
			end)
		end
	end

	local function bindTouchButton(button, upgradeId)
		if not button or not button:IsA("GuiButton") then
			return
		end

		local activeTouch
		local touchToken = 0
		local touchConnection
		local longPressTriggered = false

		local function resetTouch()
			if touchConnection then
				touchConnection:Disconnect()
				touchConnection = nil
			end
			activeTouch = nil
		end

		button.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch or activeTouch then
				return
			end

			activeTouch = input
			longPressTriggered = false
			touchToken += 1
			local currentToken = touchToken

			if touchConnection then
				touchConnection:Disconnect()
			end
			touchConnection = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.Cancel then
					resetTouch()
				end
			end)

			task.delay(LONG_PRESS_THRESHOLD, function()
				if activeTouch ~= input or longPressTriggered or touchToken ~= currentToken then
					return
				end

				longPressTriggered = true
				resetTouch()
				handleBuy(upgradeId, BUY_MODE_MAX)
			end)
		end)

		button.InputEnded:Connect(function(input)
			if input ~= activeTouch then
				return
			end

			local pressWasLong = longPressTriggered
			resetTouch()
			if pressWasLong then
				return
			end

			handleBuy(upgradeId, BUY_MODE_SINGLE)
		end)
	end

	local function handlePrestige()
		if not prestigeEvent or prestigeRequestInFlight then
			return
		end
		prestigeRequestInFlight = true
		setPrestigeAttribute(true)
		schedulePrestigeFailsafe()
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
				enforceMinimumButtonHeight(button)
				button.AutoButtonColor = not isTouchOnlyDevice
				if isTouchOnlyDevice then
					bindTouchButton(button, definition.id)
				else
					bindDesktopButton(button, definition.id)
				end
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
	setupAutoToggleButtons()
	setLoadingStep("Initializing Terminal UI", 0.9)
	ensureUiUpdateLoop()
	syncState()
	startSyncLoop()

	if autoBuyFeedbackEvent then
		autoBuyFeedbackEvent.OnClientEvent:Connect(function(branchName, amount)
			local normalizedBranch = typeof(branchName) == "string" and string.upper(branchName) or nil
			local totalPurchased = typeof(amount) == "number" and math.max(amount, 0) or 0
			if not normalizedBranch or totalPurchased <= 0 then
				return
			end

			pulseBranchColumn(normalizedBranch)

			if totalPurchased >= AUTO_BUY_TOAST_THRESHOLD and showToast then
				showToast(string.format("AUTO x%d (%s)", totalPurchased, normalizedBranch))
			end
		end)
	end

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
