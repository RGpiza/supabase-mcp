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
	local rightPanel = ui.rightPanel
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

	local sessionBonusPanel
	local sessionBonusProgressFill
	local sessionBonusProgressLabel
	local sessionBonusTargetSeconds = 20 * 60
	local globalStatsPanel
	local globalStatsDataValue
	local globalStatsPrestigeValue
	local serverPowerPanel
	local serverPowerLabel
	local autoBuyPresetsFrame = rightPanel and safeFind(rightPanel, "AutoBuyPresets")

	local function ensureSessionBonusUI()
		if sessionBonusPanel and sessionBonusPanel.Parent == rightPanel then
			return
		end
		if not rightPanel then
			return
		end

		local panel = rightPanel:FindFirstChild("SessionBonusPanel")
		if not (panel and panel:IsA("Frame")) then
			panel = Instance.new("Frame")
			panel.Name = "SessionBonusPanel"
			panel.Parent = rightPanel
		end

		panel.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		panel.BackgroundTransparency = 0.1
		panel.Size = UDim2.new(1, -10, 0, 80)
		panel.Position = UDim2.new(0, 5, 0, 0)
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.BorderSizePixel = 0
		panel.LayoutOrder = -2
		panel.Visible = true

		local panelCorner = panel:FindFirstChildOfClass("UICorner")
		if not panelCorner then
			panelCorner = Instance.new("UICorner")
			panelCorner.Parent = panel
		end
		panelCorner.CornerRadius = UDim.new(0, 8)

		local stroke = panel:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Parent = panel
		end
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(70, 90, 110)
		stroke.Thickness = 1
		stroke.Transparency = 0.4

		local padding = panel:FindFirstChildOfClass("UIPadding")
		if not padding then
			padding = Instance.new("UIPadding")
			padding.Parent = panel
		end
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)

		local title = panel:FindFirstChild("SessionBonusTitle")
		if not (title and title:IsA("TextLabel")) then
			title = Instance.new("TextLabel")
			title.Name = "SessionBonusTitle"
			title.Parent = panel
		end
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(200, 240, 255)
		title.Text = "SESSION BONUS"
		title.Size = UDim2.new(1, 0, 0, 18)

		local progressLabel = panel:FindFirstChild("SessionBonusProgressText")
		if not (progressLabel and progressLabel:IsA("TextLabel")) then
			progressLabel = Instance.new("TextLabel")
			progressLabel.Name = "SessionBonusProgressText"
			progressLabel.Parent = panel
		end
		progressLabel.BackgroundTransparency = 1
		progressLabel.Font = Enum.Font.GothamSemibold
		progressLabel.TextSize = 16
		progressLabel.TextXAlignment = Enum.TextXAlignment.Left
		progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		progressLabel.Position = UDim2.new(0, 0, 0, 22)
		progressLabel.Size = UDim2.new(1, 0, 0, 22)

		local barBackground = panel:FindFirstChild("SessionBonusProgressBar")
		if not (barBackground and barBackground:IsA("Frame")) then
			barBackground = Instance.new("Frame")
			barBackground.Name = "SessionBonusProgressBar"
			barBackground.Parent = panel
		end
		barBackground.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
		barBackground.BorderSizePixel = 0
		barBackground.Position = UDim2.new(0, 0, 0, 48)
		barBackground.Size = UDim2.new(1, 0, 0, 18)

		local barCorner = barBackground:FindFirstChildOfClass("UICorner")
		if not barCorner then
			barCorner = Instance.new("UICorner")
			barCorner.Parent = barBackground
		end
		barCorner.CornerRadius = UDim.new(0, 9)

		local fill = barBackground:FindFirstChild("SessionBonusProgressFill")
		if not (fill and fill:IsA("Frame")) then
			fill = Instance.new("Frame")
			fill.Name = "SessionBonusProgressFill"
			fill.Parent = barBackground
		end
		fill.BackgroundColor3 = Color3.fromRGB(110, 225, 255)
		fill.BorderSizePixel = 0
		fill.AnchorPoint = Vector2.new(0, 0)
		fill.Position = UDim2.new(0, 0, 0, 0)
		fill.Size = UDim2.new(0, 0, 1, 0)

		local fillCorner = fill:FindFirstChildOfClass("UICorner")
		if not fillCorner then
			fillCorner = Instance.new("UICorner")
			fillCorner.Parent = fill
		end
		fillCorner.CornerRadius = UDim.new(0, 9)

		sessionBonusPanel = panel
		sessionBonusProgressFill = fill
		sessionBonusProgressLabel = progressLabel
	end

	local function formatSessionTime(seconds)
		local totalSeconds = math.max(0, math.floor(seconds or 0))
		local minutes = math.floor(totalSeconds / 60)
		local secs = totalSeconds % 60
		return string.format("%02d:%02d", minutes, secs)
	end

	local function updateSessionBonusUI(elapsedSeconds, targetSeconds)
		ensureSessionBonusUI()
		if not (sessionBonusProgressFill and sessionBonusProgressLabel) then
			return
		end

		local safeTarget = math.max(targetSeconds, 1)
		local ratio = math.clamp((elapsedSeconds or 0) / safeTarget, 0, 1)
		sessionBonusProgressFill.Size = UDim2.new(ratio, 0, 1, 0)
		sessionBonusProgressLabel.Text = string.format(
			"%s / %s",
			formatSessionTime(elapsedSeconds),
			formatSessionTime(targetSeconds)
		)
		sessionBonusTargetSeconds = safeTarget
	end

	local function handleSessionBonusUpdate(payload)
		if typeof(payload) ~= "table" then
			return
		end

		local elapsed = tonumber(payload.elapsedSeconds) or 0
		local target = tonumber(payload.targetSeconds) or sessionBonusTargetSeconds
		updateSessionBonusUI(elapsed, target)

		local activatedRewards = payload.activatedRewards
		if typeof(activatedRewards) == "table" then
			for _ in ipairs(activatedRewards) do
				showToast("Session Bonus Activated!")
			end
		end
	end

	updateSessionBonusUI(0, sessionBonusTargetSeconds)

	local function ensureGlobalStatsUI()
		if globalStatsPanel and globalStatsPanel.Parent == rightPanel then
			return
		end
		if not rightPanel then
			return
		end

		local panel = rightPanel:FindFirstChild("GlobalStatsPanel")
		if not (panel and panel:IsA("Frame")) then
			panel = Instance.new("Frame")
			panel.Name = "GlobalStatsPanel"
			panel.Parent = rightPanel
		end

		panel.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		panel.BackgroundTransparency = 0.1
		panel.Size = UDim2.new(1, -10, 0, 110)
		panel.Position = UDim2.new(0, 5, 0, 0)
		panel.BorderSizePixel = 0
		panel.LayoutOrder = -3
		panel.Visible = true

		local panelCorner = panel:FindFirstChildOfClass("UICorner")
		if not panelCorner then
			panelCorner = Instance.new("UICorner")
			panelCorner.Parent = panel
		end
		panelCorner.CornerRadius = UDim.new(0, 8)

		local stroke = panel:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Parent = panel
		end
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(70, 90, 110)
		stroke.Thickness = 1
		stroke.Transparency = 0.4

		local padding = panel:FindFirstChildOfClass("UIPadding")
		if not padding then
			padding = Instance.new("UIPadding")
			padding.Parent = panel
		end
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)

		local title = panel:FindFirstChild("GlobalStatsTitle")
		if not (title and title:IsA("TextLabel")) then
			title = Instance.new("TextLabel")
			title.Name = "GlobalStatsTitle"
			title.Parent = panel
		end
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(200, 240, 255)
		title.Text = "GLOBAL STATS"
		title.Position = UDim2.new(0, 0, 0, 0)
		title.Size = UDim2.new(1, 0, 0, 18)

		local dataLabel = panel:FindFirstChild("GlobalStatsDataLabel")
		if not (dataLabel and dataLabel:IsA("TextLabel")) then
			dataLabel = Instance.new("TextLabel")
			dataLabel.Name = "GlobalStatsDataLabel"
			dataLabel.Parent = panel
		end
		dataLabel.BackgroundTransparency = 1
		dataLabel.Font = Enum.Font.Gotham
		dataLabel.TextSize = 13
		dataLabel.TextXAlignment = Enum.TextXAlignment.Left
		dataLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
		dataLabel.Text = "Total Data Generated:"
		dataLabel.Position = UDim2.new(0, 0, 0, 22)
		dataLabel.Size = UDim2.new(1, 0, 0, 18)

		local dataValue = panel:FindFirstChild("GlobalStatsDataValue")
		if not (dataValue and dataValue:IsA("TextLabel")) then
			dataValue = Instance.new("TextLabel")
			dataValue.Name = "GlobalStatsDataValue"
			dataValue.Parent = panel
		end
		dataValue.BackgroundTransparency = 1
		dataValue.Font = Enum.Font.GothamSemibold
		dataValue.TextSize = 18
		dataValue.TextXAlignment = Enum.TextXAlignment.Left
		dataValue.TextColor3 = Color3.fromRGB(255, 255, 255)
		dataValue.Position = UDim2.new(0, 0, 0, 42)
		dataValue.Size = UDim2.new(1, 0, 0, 22)

		local prestigeLabel = panel:FindFirstChild("GlobalStatsPrestigeLabel")
		if not (prestigeLabel and prestigeLabel:IsA("TextLabel")) then
			prestigeLabel = Instance.new("TextLabel")
			prestigeLabel.Name = "GlobalStatsPrestigeLabel"
			prestigeLabel.Parent = panel
		end
		prestigeLabel.BackgroundTransparency = 1
		prestigeLabel.Font = Enum.Font.Gotham
		prestigeLabel.TextSize = 13
		prestigeLabel.TextXAlignment = Enum.TextXAlignment.Left
		prestigeLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
		prestigeLabel.Text = "Total Prestiges:"
		prestigeLabel.Position = UDim2.new(0, 0, 0, 68)
		prestigeLabel.Size = UDim2.new(1, 0, 0, 18)

		local prestigeValue = panel:FindFirstChild("GlobalStatsPrestigeValue")
		if not (prestigeValue and prestigeValue:IsA("TextLabel")) then
			prestigeValue = Instance.new("TextLabel")
			prestigeValue.Name = "GlobalStatsPrestigeValue"
			prestigeValue.Parent = panel
		end
		prestigeValue.BackgroundTransparency = 1
		prestigeValue.Font = Enum.Font.GothamSemibold
		prestigeValue.TextSize = 18
		prestigeValue.TextXAlignment = Enum.TextXAlignment.Left
		prestigeValue.TextColor3 = Color3.fromRGB(255, 255, 255)
		prestigeValue.Position = UDim2.new(0, 0, 0, 88)
		prestigeValue.Size = UDim2.new(1, 0, 0, 22)

		globalStatsPanel = panel
		globalStatsDataValue = dataValue
		globalStatsPrestigeValue = prestigeValue
	end

	local function updateGlobalStatsUI(totalData, totalPrestiges)
		ensureGlobalStatsUI()
		if globalStatsDataValue then
			globalStatsDataValue.Text = NumberFormatter.format(totalData or 0)
		end
		if globalStatsPrestigeValue then
			globalStatsPrestigeValue.Text = NumberFormatter.format(totalPrestiges or 0)
		end
	end

	local function handleGlobalStatsUpdate(payload)
		if typeof(payload) ~= "table" then
			return
		end

		local totalData = tonumber(payload.totalData) or 0
		local totalPrestiges = tonumber(payload.totalPrestiges) or 0
		updateGlobalStatsUI(totalData, totalPrestiges)
	end

	updateGlobalStatsUI(0, 0)

	local function ensureServerPowerUI()
		if serverPowerPanel and serverPowerPanel.Parent == rightPanel then
			return
		end
		if not rightPanel then
			return
		end

		local panel = rightPanel:FindFirstChild("ServerPowerPanel")
		if not (panel and panel:IsA("Frame")) then
			panel = Instance.new("Frame")
			panel.Name = "ServerPowerPanel"
			panel.Parent = rightPanel
		end

		panel.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		panel.BackgroundTransparency = 0.1
		panel.Size = UDim2.new(1, -10, 0, 60)
		panel.Position = UDim2.new(0, 5, 0, 0)
		panel.BorderSizePixel = 0
		panel.LayoutOrder = -1
		panel.Visible = true

		local panelCorner = panel:FindFirstChildOfClass("UICorner")
		if not panelCorner then
			panelCorner = Instance.new("UICorner")
			panelCorner.Parent = panel
		end
		panelCorner.CornerRadius = UDim.new(0, 8)

		local stroke = panel:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Parent = panel
		end
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(70, 90, 110)
		stroke.Thickness = 1
		stroke.Transparency = 0.4

		local padding = panel:FindFirstChildOfClass("UIPadding")
		if not padding then
			padding = Instance.new("UIPadding")
			padding.Parent = panel
		end
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)

		local title = panel:FindFirstChild("ServerPowerTitle")
		if not (title and title:IsA("TextLabel")) then
			title = Instance.new("TextLabel")
			title.Name = "ServerPowerTitle"
			title.Parent = panel
		end
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(200, 240, 255)
		title.Text = "SERVER POWER"
		title.Size = UDim2.new(1, 0, 0, 18)

		local status = panel:FindFirstChild("ServerPowerStatus")
		if not (status and status:IsA("TextLabel")) then
			status = Instance.new("TextLabel")
			status.Name = "ServerPowerStatus"
			status.Parent = panel
		end
		status.BackgroundTransparency = 1
		status.Font = Enum.Font.GothamSemibold
		status.TextSize = 16
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextColor3 = Color3.fromRGB(255, 255, 255)
		status.Position = UDim2.new(0, 0, 0, 26)
		status.Size = UDim2.new(1, 0, 0, 24)

		serverPowerPanel = panel
		serverPowerLabel = status
	end

	local function updateServerPowerUI(multiplier, playerCount)
		ensureServerPowerUI()
		if not serverPowerLabel then
			return
		end

		local percent = math.max((tonumber(multiplier) or 1) - 1, 0) * 100
		local players = math.max(tonumber(playerCount) or 0, 0)
		serverPowerLabel.Text = string.format("+%.1f%% (%d Players)", percent, players)
	end

	local function handleServerPowerUpdate(payload)
		if typeof(payload) ~= "table" then
			return
		end

		updateServerPowerUI(payload.multiplier, payload.playerCount)
	end

	updateServerPowerUI(0, 0)

	local function handleSystemNotification(message)
		if typeof(message) ~= "string" then
			return
		end
		showToast(message, Color3.fromRGB(210, 215, 225))
	end

	local function handleGlobalAnnouncement(payload)
		if typeof(payload) ~= "table" then
			return
		end

		local message = payload.message
		if typeof(message) ~= "string" then
			return
		end

		local color = payload.color
		if typeof(color) ~= "Color3" then
			color = Color3.fromRGB(225, 230, 240)
		end

		showToast(message, color)
	end

	if storeController then
		if storeController.RefreshGamepassOwnership then
			storeController.RefreshGamepassOwnership()
		end
		setLoadingStep("Checking Store Ownership", 0.8)
	end

	local prestigeButton = safeFind(prestigeBox, "PrestigeButton")
	local prestigeOverlay = safeFind(prestigeBox, "PrestigeLockedOverlay")
	local prestigePreviewPanel
	local prestigePreviewTitle
	local prestigePreviewSubtext
	local prestigePreviewBody
	local prestigePreviewStroke
	local previewGlowConnection
	local lastPreviewPayload

	local function stopPreviewGlowPulse()
		if previewGlowConnection then
			previewGlowConnection:Disconnect()
			previewGlowConnection = nil
		end
	end

	local function ensurePreviewStroke(panel)
		if prestigePreviewStroke and prestigePreviewStroke.Parent == panel then
			return prestigePreviewStroke
		end

		local stroke = panel:FindFirstChild("PreviewGlowStroke")
		if stroke and stroke:IsA("UIStroke") then
			prestigePreviewStroke = stroke
			return stroke
		end

		stroke = Instance.new("UIStroke")
		stroke.Name = "PreviewGlowStroke"
		stroke.Thickness = 1
		stroke.Transparency = 0.7
		stroke.Color = Color3.fromRGB(80, 88, 100)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = panel
		prestigePreviewStroke = stroke
		return stroke
	end

	local function startPreviewGlowPulse()
		if previewGlowConnection or not prestigePreviewStroke then
			return
		end

		local pulseTime = 0
		previewGlowConnection = RunService.RenderStepped:Connect(function(dt)
			if not prestigePreviewStroke or not prestigePreviewStroke.Parent then
				stopPreviewGlowPulse()
				return
			end
			pulseTime += dt
			local normalized = (math.sin(pulseTime * 5) + 1) * 0.5
			prestigePreviewStroke.Transparency = 0.05 + (normalized * 0.25)
		end)
	end

	local function applyPreviewGlow(multiplier)
		if not prestigePreviewStroke then
			return
		end

		local numericMultiplier = typeof(multiplier) == "number" and multiplier or 0
		if numericMultiplier >= 25 then
			prestigePreviewStroke.Enabled = true
			prestigePreviewStroke.Thickness = 3
			prestigePreviewStroke.Color = Color3.fromRGB(255, 226, 150)
			prestigePreviewStroke.Transparency = 0.1
			startPreviewGlowPulse()
			return
		end

		stopPreviewGlowPulse()

		if numericMultiplier >= 10 then
			prestigePreviewStroke.Enabled = true
			prestigePreviewStroke.Thickness = 3
			prestigePreviewStroke.Color = Color3.fromRGB(255, 198, 120)
			prestigePreviewStroke.Transparency = 0.15
		elseif numericMultiplier >= 5 then
			prestigePreviewStroke.Enabled = true
			prestigePreviewStroke.Thickness = 2
			prestigePreviewStroke.Color = Color3.fromRGB(120, 210, 255)
			prestigePreviewStroke.Transparency = 0.35
		else
			prestigePreviewStroke.Enabled = true
			prestigePreviewStroke.Thickness = 1
			prestigePreviewStroke.Color = Color3.fromRGB(80, 88, 100)
			prestigePreviewStroke.Transparency = 0.7
		end
	end

	local function ensurePrestigePreviewPanel()
		if prestigePreviewPanel and prestigePreviewPanel.Parent == prestigeBox then
			return
		end

		if not prestigeBox then
			return
		end

		local panel = prestigeBox:FindFirstChild("PrestigePreviewPanel")
		if not (panel and panel:IsA("Frame")) then
			panel = Instance.new("Frame")
			panel.Name = "PrestigePreviewPanel"
			panel.Parent = prestigeBox
		end

		panel.BackgroundColor3 = Color3.fromRGB(17, 24, 35)
		panel.BackgroundTransparency = 0.1
		panel.BorderSizePixel = 0
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.Size = UDim2.new(1, -10, 0, 0)
		panel.Position = UDim2.new(0, 5, 0, 0)
		panel.LayoutOrder = prestigeButton and ((prestigeButton.LayoutOrder or 0) - 1) or -1
		panel.ClipsDescendants = true
		panel.Visible = true

		local padding = panel:FindFirstChildOfClass("UIPadding")
		if not padding then
			padding = Instance.new("UIPadding")
			padding.Name = "PreviewPadding"
			padding.Parent = panel
		end
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)

		local corner = panel:FindFirstChildOfClass("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Name = "PreviewCorner"
			corner.Parent = panel
		end
		corner.CornerRadius = UDim.new(0, 8)

		local layout = panel:FindFirstChild("PreviewLayout")
		if not (layout and layout:IsA("UIListLayout")) then
			layout = Instance.new("UIListLayout")
			layout.Name = "PreviewLayout"
			layout.Parent = panel
		end
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.Padding = UDim.new(0, 4)

		local function configureLabel(label, font, size, color)
			label.BackgroundTransparency = 1
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextWrapped = true
			label.Font = font
			label.TextSize = size
			label.Size = UDim2.new(1, 0, 0, 0)
			label.AutomaticSize = Enum.AutomaticSize.Y
			label.TextColor3 = color
		end

		local title = panel:FindFirstChild("PreviewTitle")
		if not (title and title:IsA("TextLabel")) then
			title = Instance.new("TextLabel")
			title.Name = "PreviewTitle"
			title.Parent = panel
		end
		configureLabel(title, Enum.Font.GothamBold, 14, Color3.fromRGB(190, 255, 255))
		title.Text = "PRESTIGE PREVIEW"
		title.LayoutOrder = 1

		local subtext = panel:FindFirstChild("PreviewSubtext")
		if not (subtext and subtext:IsA("TextLabel")) then
			subtext = Instance.new("TextLabel")
			subtext.Name = "PreviewSubtext"
			subtext.Parent = panel
		end
		configureLabel(subtext, Enum.Font.Gotham, 12, Color3.fromRGB(210, 210, 210))
		subtext.LayoutOrder = 2

		local body = panel:FindFirstChild("PreviewBody")
		if not (body and body:IsA("TextLabel")) then
			body = Instance.new("TextLabel")
			body.Name = "PreviewBody"
			body.Parent = panel
		end
		configureLabel(body, Enum.Font.GothamSemibold, 18, Color3.fromRGB(255, 255, 255))
		body.LayoutOrder = 3

		panel:GetPropertyChangedSignal("Parent"):Connect(function()
			if not panel.Parent then
				stopPreviewGlowPulse()
			end
		end)

		prestigePreviewPanel = panel
		prestigePreviewTitle = title
		prestigePreviewSubtext = subtext
		prestigePreviewBody = body
		prestigePreviewStroke = ensurePreviewStroke(panel)
	end

	ensurePrestigePreviewPanel()

	local function setPreviewPending()
		if prestigePreviewSubtext then
			prestigePreviewSubtext.Text = "Calculating preview..."
		end
		if prestigePreviewBody then
			prestigePreviewBody.Text = "..."
		end
		applyPreviewGlow(0)
	end

	local function formatMultiplier(value)
		local numericValue = typeof(value) == "number" and value or 0
		return string.format("%.2f", math.max(numericValue, 0))
	end

	local function updatePreviewText(payload)
		if not prestigePreviewPanel then
			return
		end

		if typeof(payload) ~= "table" then
			setPreviewPending()
			return
		end

		local canPrestige = payload.canPrestige == true
		local nextMultiplier = typeof(payload.nextMultiplier) == "number" and payload.nextMultiplier or 0
		local multiplierGain = typeof(payload.multiplierGain) == "number" and payload.multiplierGain or 0

		if prestigePreviewSubtext then
			if canPrestige then
				prestigePreviewSubtext.Text = "If you prestiged now:"
			else
				local requirement = NumberFormatter.format(payload.unlockRequirement or 0)
				prestigePreviewSubtext.Text = string.format("Unlocks at %s Data", requirement)
			end
		end

		if prestigePreviewBody then
			if canPrestige then
				local gainText = multiplierGain
				if gainText <= 0 then
					gainText = nextMultiplier - 1
				end
				prestigePreviewBody.Text = string.format("+%sx Permanent Power", formatMultiplier(gainText))
			else
				local current = NumberFormatter.format(payload.currentData or 0)
				prestigePreviewBody.Text = string.format("Currently: %s Data", current)
			end
		end

		applyPreviewGlow(canPrestige and nextMultiplier or 0)
	end

	setPreviewPending()

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

	local function waitForRemote(name)
		return waitForChildWithTimeout(remotesFolder, name) or safeFind(remotesFolder, name)
	end

	local requestSync = waitForRemote("RequestSync")
	local buyUpgradeEvent = waitForRemote("RequestBuyUpgrade")
	local prestigeEvent = waitForRemote("RequestPrestige")
	local prestigePreviewEvent = waitForRemote("PrestigePreviewUpdate")
	local requestPrestigePreview = waitForRemote("RequestPrestigePreview")
	local sessionBonusEvent = waitForRemote("SessionBonusUpdate")
	local globalAnnouncementEvent = waitForRemote("GlobalAnnouncement")
	local globalStatsEvent = waitForRemote("GlobalStatsUpdate")
	local serverPowerEvent = waitForRemote("ServerPowerUpdate")
	local systemNotificationEvent = waitForRemote("SystemNotification")
	local autoBuyPresetApplyEvent = safeFind(remotesFolder, "AutoBuyPresetApply")
	local autoBuyPresetSaveEvent = safeFind(remotesFolder, "AutoBuyPresetSave")
	local autoBuyPresetStateEvent = safeFind(remotesFolder, "AutoBuyPresetState")
	local requestAutoBuyPresets = safeFind(remotesFolder, "RequestAutoBuyPresets")
	if
		not (
			requestSync
			and buyUpgradeEvent
			and prestigeEvent
			and prestigePreviewEvent
			and requestPrestigePreview
			and sessionBonusEvent
			and globalAnnouncementEvent
			and globalStatsEvent
			and serverPowerEvent
			and systemNotificationEvent
		)
	then
		warn("[TerminalClient] Required remotes missing")
		return
	end

	local pendingPrestigePreviewPayloads = {}
	local prestigePreviewHandler

	if prestigePreviewEvent then
		prestigePreviewEvent.OnClientEvent:Connect(function(payload)
			if prestigePreviewHandler then
				prestigePreviewHandler(payload)
			else
				table.insert(pendingPrestigePreviewPayloads, payload)
			end
		end)
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
	local autoBuyPresetButtons = {}
	local autoBuyPresetSaveButton
	local currentPresetSettings = nil
	local activePresetIndex = nil
	local lastPresetIndex = 1
	local recommendedPresetIndex = nil
	local presetButtonCooldowns = {}
	local pendingPresetSaveToast = false
	local lastRecommendationContext = nil
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

		if lastPreviewPayload then
			applyPreviewGlow(lastPreviewPayload.canPrestige and lastPreviewPayload.nextMultiplier or 0)
		end
	end

	local function handlePrestigePreview(payload)
		if typeof(payload) ~= "table" then
			return
		end
		lastPreviewPayload = payload
		updatePreviewText(payload)
	end

	prestigePreviewHandler = handlePrestigePreview
	if #pendingPrestigePreviewPayloads > 0 then
		for _, pending in ipairs(pendingPrestigePreviewPayloads) do
			prestigePreviewHandler(pending)
		end
		table.clear(pendingPrestigePreviewPayloads)
	end

	local function requestInitialPrestigePreview()
		if not requestPrestigePreview then
			return
		end

		task.spawn(function()
			local ok, payload = pcall(function()
				return requestPrestigePreview:InvokeServer()
			end)
			if ok and typeof(payload) == "table" then
				handlePrestigePreview(payload)
			end
		end)
	end

	requestInitialPrestigePreview()
	if sessionBonusEvent then
		sessionBonusEvent.OnClientEvent:Connect(handleSessionBonusUpdate)
	end
	if globalAnnouncementEvent then
		globalAnnouncementEvent.OnClientEvent:Connect(handleGlobalAnnouncement)
	end
	if globalStatsEvent then
		globalStatsEvent.OnClientEvent:Connect(handleGlobalStatsUpdate)
		updateGlobalStatsUI(0, 0)
	end
	if serverPowerEvent then
		serverPowerEvent.OnClientEvent:Connect(handleServerPowerUpdate)
		updateServerPowerUI(1, #Players:GetPlayers())
	end
	if systemNotificationEvent then
		systemNotificationEvent.OnClientEvent:Connect(handleSystemNotification)
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

	local AUTO_PRESET_COUNT = 3
	local MID_GAME_DPS_THRESHOLD = 125000
	local STORAGE_LAG_DELTA = 5
	local LEVEL_BUCKET_SIZE = 5

	local function ensureRecommendedTag(buttonInfo)
		if not buttonInfo or not buttonInfo.button then
			return nil
		end

		local tag = buttonInfo.recommendedLabel
		if tag and tag.Parent == buttonInfo.button then
			return tag
		end

		tag = Instance.new("TextLabel")
		tag.Name = "RecommendedTag"
		tag.BackgroundTransparency = 1
		tag.Text = "* RECOMMENDED"
		tag.Font = Enum.Font.GothamBold
		tag.TextSize = 10
		tag.TextColor3 = Color3.fromRGB(255, 237, 178)
		tag.TextTransparency = 0.2
		tag.AnchorPoint = Vector2.new(0, 0)
		tag.Position = UDim2.new(0, 6, 0, 6)
		tag.Size = UDim2.new(0, 0, 0, 0)
		tag.AutomaticSize = Enum.AutomaticSize.XY
		tag.ZIndex = (buttonInfo.button.ZIndex or 1) + 1
		tag.Visible = false
		tag.Parent = buttonInfo.button
		buttonInfo.recommendedLabel = tag
		return tag
	end

	local function stylePresetButton(buttonInfo, isActive, isRecommended)
		if not buttonInfo or not buttonInfo.button then
			return
		end
		local button = buttonInfo.button

		if not buttonInfo.baseColor then
			buttonInfo.baseColor = button.BackgroundColor3
			buttonInfo.baseTransparency = button.BackgroundTransparency
		end

		local stroke = buttonInfo.stroke
		if not stroke then
			stroke = button:FindFirstChildOfClass("UIStroke")
			if not stroke then
				stroke = Instance.new("UIStroke")
				stroke.Name = "PresetStroke"
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = button
			end
			buttonInfo.stroke = stroke
			buttonInfo.baseStrokeColor = stroke.Color
			buttonInfo.baseStrokeTransparency = stroke.Transparency
			buttonInfo.baseStrokeThickness = stroke.Thickness
		end

		local highlightColor = Color3.fromRGB(255, 247, 200)
		local restingColor = buttonInfo.baseColor or Color3.fromRGB(34, 40, 49)
		if isActive then
			button.BackgroundColor3 = restingColor:Lerp(highlightColor, 0.25)
			button.BackgroundTransparency = math.clamp((buttonInfo.baseTransparency or 0) - 0.1, 0, 1)
			stroke.Thickness = math.max(buttonInfo.baseStrokeThickness or 1, 2)
			stroke.Transparency = 0.1
			stroke.Color = Color3.fromRGB(255, 236, 160)
		else
			button.BackgroundColor3 = restingColor
			button.BackgroundTransparency = buttonInfo.baseTransparency or 0
			stroke.Thickness = buttonInfo.baseStrokeThickness or 1
			stroke.Transparency = buttonInfo.baseStrokeTransparency or 0.6
			stroke.Color = buttonInfo.baseStrokeColor or Color3.fromRGB(70, 88, 110)
		end

		local tag = ensureRecommendedTag(buttonInfo)
		if tag then
			if isRecommended then
				if isActive then
					tag.Text = "* ACTIVE"
					tag.TextColor3 = Color3.fromRGB(255, 244, 200)
				else
					tag.Text = "* RECOMMENDED"
					tag.TextColor3 = Color3.fromRGB(255, 237, 178)
				end
			end
			tag.Visible = isRecommended
		end
	end

	local function updateAutoBuyPresetVisuals()
		for index, buttonInfo in pairs(autoBuyPresetButtons) do
			local isActive = activePresetIndex == index
			local isRecommended = recommendedPresetIndex == index
			stylePresetButton(buttonInfo, isActive, isRecommended)
		end
	end

	local function sumUpgradesForPrefix(prefix)
		local total = 0
		for upgradeId, level in pairs(playerState.upgrades or {}) do
			if typeof(upgradeId) == "string" and string.sub(upgradeId, 1, #prefix) == prefix then
				if typeof(level) == "number" and level > 0 then
					total += level
				end
			end
		end
		return total
	end

	local function determineRecommendedPreset()
		local prestige = typeof(playerState.prestige) == "number" and playerState.prestige or 0
		local dps = typeof(playerState.dps) == "number" and playerState.dps or 0
		local cpuLevels = sumUpgradesForPrefix("cpu_")
		local ramLevels = sumUpgradesForPrefix("ram_")
		local storageLevels = sumUpgradesForPrefix("storage_")
		local recommended = 1

		if prestige == 0 then
			recommended = 1
		elseif prestige >= 2 and storageLevels + STORAGE_LAG_DELTA < math.min(cpuLevels, ramLevels) then
			recommended = 3
		elseif prestige >= 1 and dps < MID_GAME_DPS_THRESHOLD then
			recommended = 2
		else
			recommended = 1
		end

		local context = {
			prestige = prestige,
			dpsBucket = dps < MID_GAME_DPS_THRESHOLD and "low" or "high",
			cpuBucket = math.floor(cpuLevels / LEVEL_BUCKET_SIZE),
			ramBucket = math.floor(ramLevels / LEVEL_BUCKET_SIZE),
			storageBucket = math.floor(storageLevels / LEVEL_BUCKET_SIZE),
		}

		return recommended, context
	end

	local function updateAutoBuyRecommendation(force)
		local recommended, context = determineRecommendedPreset()
		if not recommended then
			return
		end

		local contextChanged = force or not lastRecommendationContext
		if not contextChanged then
			for key, value in pairs(context) do
				if lastRecommendationContext[key] ~= value then
					contextChanged = true
					break
				end
			end
		end

		if contextChanged or recommendedPresetIndex ~= recommended then
			lastRecommendationContext = context
			recommendedPresetIndex = recommended
			updateAutoBuyPresetVisuals()
		end
	end

	local function handleAutoBuyPresetState(payload)
		if typeof(payload) ~= "table" then
			return
		end

		if typeof(payload.presets) == "table" then
			for index, preset in ipairs(payload.presets) do
				local buttonInfo = autoBuyPresetButtons[index]
				if buttonInfo and buttonInfo.button and typeof(preset) == "table" and typeof(preset.name) == "string" then
					buttonInfo.button.Text = preset.name
				end
			end
		end

		if typeof(payload.settings) == "table" then
			currentPresetSettings = {
				enabled = table.clone(payload.settings.enabled or {}),
				priority = table.clone(payload.settings.priority or {}),
			}
		end

		if typeof(payload.activePreset) == "number" then
			activePresetIndex = math.clamp(math.floor(payload.activePreset + 0.5), 1, AUTO_PRESET_COUNT)
			lastPresetIndex = activePresetIndex
		else
			activePresetIndex = nil
		end

		for index, buttonInfo in pairs(autoBuyPresetButtons) do
			if buttonInfo.button then
				buttonInfo.button.Active = true
				buttonInfo.button.AutoButtonColor = true
			end
		end
		if autoBuyPresetSaveButton then
			autoBuyPresetSaveButton.Active = true
		end
		table.clear(presetButtonCooldowns)

		updateAutoBuyPresetVisuals()

		if pendingPresetSaveToast then
			showToast("Preset Saved")
			pendingPresetSaveToast = false
		end
	end

	local function throttlePresetButton(index)
		local info = autoBuyPresetButtons[index]
		if info and info.button then
			info.button.Active = false
		end
		presetButtonCooldowns[index] = true
		task.delay(1.5, function()
			presetButtonCooldowns[index] = nil
			local refreshed = autoBuyPresetButtons[index]
			if refreshed and refreshed.button then
				refreshed.button.Active = true
			end
		end)
	end

	local function handlePresetApply(index)
		if not autoBuyPresetApplyEvent or not autoBuyPresetButtons[index] then
			return
		end
		if presetButtonCooldowns[index] then
			return
		end

		throttlePresetButton(index)
		autoBuyPresetApplyEvent:FireServer(index)
		lastPresetIndex = index
	end

	local function handlePresetSave()
		if not autoBuyPresetSaveEvent or not currentPresetSettings then
			return
		end

		local targetIndex = activePresetIndex or lastPresetIndex or 1
		local payload = {
			enabled = table.clone(currentPresetSettings.enabled or {}),
			priority = table.clone(currentPresetSettings.priority or {}),
		}

		if autoBuyPresetSaveButton then
			autoBuyPresetSaveButton.Active = false
		end
		autoBuyPresetSaveEvent:FireServer(targetIndex, payload)
		pendingPresetSaveToast = true
		task.delay(1.5, function()
			if autoBuyPresetSaveButton then
				autoBuyPresetSaveButton.Active = true
			end
		end)
	end

	local function initAutoBuyPresetUI()
		if not autoBuyPresetsFrame then
			if rightPanel then
				autoBuyPresetsFrame = (waitForChildWithTimeout(rightPanel, "AutoBuyPresets"))
			end
		end

		if not autoBuyPresetsFrame then
			return
		end

		for index = 1, AUTO_PRESET_COUNT do
			local button = safeFind(autoBuyPresetsFrame, "Preset" .. index)
			if button and button:IsA("GuiButton") then
				autoBuyPresetButtons[index] = {
					button = button,
					baseColor = button.BackgroundColor3,
					baseTransparency = button.BackgroundTransparency,
					stroke = button:FindFirstChildOfClass("UIStroke"),
				}
				button.MouseButton1Click:Connect(function()
					handlePresetApply(index)
				end)
			end
		end

		autoBuyPresetSaveButton = safeFind(autoBuyPresetsFrame, "SavePreset")
		if autoBuyPresetSaveButton and autoBuyPresetSaveButton:IsA("GuiButton") then
			autoBuyPresetSaveButton.MouseButton1Click:Connect(handlePresetSave)
		end
	end

	local function requestAutoBuyPresetState()
		if not requestAutoBuyPresets then
			return
		end

		task.spawn(function()
			local ok, response = pcall(function()
				return requestAutoBuyPresets:InvokeServer()
			end)
			if ok and response then
				handleAutoBuyPresetState(response)
			end
		end)
	end

	initAutoBuyPresetUI()
	if autoBuyPresetStateEvent then
		autoBuyPresetStateEvent.OnClientEvent:Connect(handleAutoBuyPresetState)
	end
	requestAutoBuyPresetState()
	updateAutoBuyRecommendation(true)

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
		updateAutoBuyRecommendation()
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
