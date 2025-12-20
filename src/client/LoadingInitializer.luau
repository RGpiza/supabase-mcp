local LoadingInitializer = {}

local PRESET_ICON_DEFINITIONS = {
	{ id = "auto_cpu", label = "CPU" },
	{ id = "auto_ram", label = "RAM" },
	{ id = "auto_storage", label = "STO" },
}
local PURCHASE_SETTINGS = {
	debounce = 0.2,
	longPressDuration = 0.5,
	activationSuppress = 0.1,
}
local AUTO_BUY_BRANCHES = {
	{ id = "CPU", label = "AUTO CPU" },
	{ id = "RAM", label = "AUTO RAM" },
	{ id = "STORAGE", label = "AUTO STORAGE" },
}

local HAPTIC_COOLDOWN = 0.2
local WEEKLY_REWARD_DEFINITIONS = {
	{ tier = "gold", label = "Rank 1", detail = "Gold Name Color (7 days)" },
	{ tier = "silver", label = "Top 10", detail = "Silver Name Color (7 days)" },
	{ tier = "bronze", label = "Top 50", detail = "Bronze Badge (7 days)" },
}
local WEEKLY_REWARD_HIGHLIGHT = {
	gold = Color3.fromRGB(80, 60, 30),
	silver = Color3.fromRGB(60, 70, 90),
	bronze = Color3.fromRGB(65, 50, 35),
}
local WEEKLY_REWARD_ACCENT = {
	gold = Color3.fromRGB(255, 225, 160),
	silver = Color3.fromRGB(200, 225, 255),
	bronze = Color3.fromRGB(255, 210, 170),
}

local function createHapticTrigger(options)
	local userInputService = options and options.userInputService
	local hapticService = options and options.hapticService
	local lastTriggerTime = 0
	local supportChecked = false
	local smallMotorSupported = false

	local function ensureSupport()
		if supportChecked then
			return smallMotorSupported
		end
		supportChecked = true
		if not hapticService then
			smallMotorSupported = false
			return false
		end

		local ok, supported = pcall(function()
			return hapticService:IsMotorSupported(Enum.UserInputType.Touch, Enum.VibrationMotor.Small)
		end)
		smallMotorSupported = ok and supported == true
		return smallMotorSupported
	end

	return function(impactLevel)
		if not userInputService or not userInputService.TouchEnabled then
			return
		end

		if not ensureSupport() then
			return
		end

		local now = os.clock()
		if now - lastTriggerTime < HAPTIC_COOLDOWN then
			return
		end
		lastTriggerTime = now

		local amplitude = impactLevel == "medium" and 0.7 or 0.35
		local ok = pcall(function()
			hapticService:SetMotor(Enum.UserInputType.Touch, Enum.VibrationMotor.Small, amplitude)
		end)
		if ok then
			task.delay(0.1, function()
				pcall(function()
					hapticService:SetMotor(Enum.UserInputType.Touch, Enum.VibrationMotor.Small, 0)
				end)
			end)
		end
	end
end

local function isShiftHeld(input)
	if input and typeof(input.IsModifierKeyDown) == "function" then
		if input:IsModifierKeyDown(Enum.KeyCode.LeftShift) or input:IsModifierKeyDown(Enum.KeyCode.RightShift) then
			return true
		end
	end
	local UserInputService = game:GetService("UserInputService")
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- Module requires moved to top-level to reduce locals inside Init
local PurchaseHandlerBinder = nil
local SyncLoopBinder = nil
do
	local modulesFolder = script.Parent and script.Parent:FindFirstChild("Modules")
	if modulesFolder then
		pcall(function()
			PurchaseHandlerBinder = require(modulesFolder:FindFirstChild("PurchaseHandlerBinder"))
		end)
		pcall(function()
			SyncLoopBinder = require(modulesFolder:FindFirstChild("SyncLoopBinder"))
		end)
	end
end

local function initWeeklyRewardsPreview(options)
	local safeFind = options and options.safeFind
	local rightPanel = options and options.rightPanel
	local statsBox = options and options.statsBox
	local weeklyResetFunction = options and options.weeklyResetFunction
	if not (rightPanel and weeklyResetFunction) then
		return
	end

	local statsPageFrame
	local weeklyRewardsPanel
	local weeklyRewardRows = {}
	local weeklyRewardsCountdownLabel
	local weeklyRewardsExpiresAt = 0
	local weeklyRewardsQualifyingTier
	local weeklyRewardsCountdownLoopActive = false
	local weeklyRewardsInitialized = false
	local weeklyRewardsVisibilityConnection
	local lastWeeklyRewardsRequest = 0

	local function resolveStatsPage()
		if statsPageFrame and statsPageFrame.Parent then
			return statsPageFrame
		end
		if rightPanel then
			local pages = safeFind and safeFind(rightPanel, "Pages") or rightPanel:FindFirstChild("Pages")
			if pages then
				local found = safeFind and safeFind(pages, "StatsPage") or pages:FindFirstChild("StatsPage")
				if found then
					statsPageFrame = found
					return statsPageFrame
				end
			end
		end
		return statsPageFrame
	end

	local function getWeeklyRewardsParent()
		return resolveStatsPage() or (statsBox and statsBox.Parent) or rightPanel
	 end

	local function formatWeeklyCountdown(seconds)
		local remaining = math.max(math.floor(seconds or 0), 0)
		local days = math.floor(remaining / 86400)
		local hours = math.floor((remaining % 86400) / 3600)
		local minutes = math.floor((remaining % 3600) / 60)
		if days > 0 then
			return string.format("%dd %dh", days, hours)
		end
		if hours > 0 then
			return string.format("%dh %02dm", hours, minutes)
		end
		return string.format("%dm", minutes)
	end

	local function applyWeeklyRewardTierHighlight()
		for tier, info in pairs(weeklyRewardRows) do
			local frame = info.frame
			local stroke = info.stroke
			local statusLabel = info.statusLabel
			local isActive = weeklyRewardsQualifyingTier ~= nil and weeklyRewardsQualifyingTier == tier
			if frame then
				if isActive then
					frame.BackgroundColor3 = info.highlightColor
					frame.BackgroundTransparency = 0.05
				else
					frame.BackgroundColor3 = info.baseColor
					frame.BackgroundTransparency = 0.15
				end
			end
			if stroke then
				if isActive then
					stroke.Transparency = 0.2
					stroke.Color = info.accentColor
				else
					stroke.Transparency = 0.65
					stroke.Color = Color3.fromRGB(60, 75, 95)
				end
			end
			if statusLabel then
				statusLabel.Visible = isActive
			end
		end
	end

	local function updateWeeklyRewardsCountdown()
		if not weeklyRewardsCountdownLabel then
			return
		end

		if weeklyRewardsExpiresAt <= 0 then
			weeklyRewardsCountdownLabel.Text = "Resets in: --"
			return
		end

		local remaining = math.max(0, weeklyRewardsExpiresAt - os.time())
		weeklyRewardsCountdownLabel.Text = string.format("Resets in: %s", formatWeeklyCountdown(remaining))
	end

	local function ensureWeeklyRewardsCountdownLoop()
		if weeklyRewardsCountdownLoopActive then
			return
		end
		weeklyRewardsCountdownLoopActive = true
		task.spawn(function()
			while weeklyRewardsPanel and weeklyRewardsPanel.Parent do
				updateWeeklyRewardsCountdown()
				task.wait(60)
			end
			weeklyRewardsCountdownLoopActive = false
		end)
	end

	local function createWeeklyRewardRow(parent, definition, order)
		local rawFrame = Instance.new("Frame")
		rawFrame.Name = string.format("%sRow", definition.tier)
		rawFrame.Size = UDim2.new(1, 0, 0, 56)
		rawFrame.BackgroundColor3 = Color3.fromRGB(17, 22, 32)
		rawFrame.BackgroundTransparency = 0.15
		rawFrame.BorderSizePixel = 0
		rawFrame.LayoutOrder = order
		rawFrame.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = rawFrame

		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(60, 75, 95)
		stroke.Transparency = 0.65
		stroke.Parent = rawFrame

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 12)
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 6)
		padding.Parent = rawFrame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Requirement"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, -110, 0, 20)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 14
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = WEEKLY_REWARD_ACCENT[definition.tier] or Color3.fromRGB(220, 230, 255)
		nameLabel.Text = definition.label
		nameLabel.Parent = rawFrame

		local detailLabel = Instance.new("TextLabel")
		detailLabel.Name = "Reward"
		detailLabel.BackgroundTransparency = 1
		detailLabel.Size = UDim2.new(1, -110, 0, 18)
		detailLabel.Position = UDim2.new(0, 0, 0, 24)
		detailLabel.Font = Enum.Font.Gotham
		detailLabel.TextSize = 13
		detailLabel.TextXAlignment = Enum.TextXAlignment.Left
		detailLabel.TextColor3 = Color3.fromRGB(205, 215, 230)
		detailLabel.Text = definition.detail
		detailLabel.Parent = rawFrame

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "Status"
		statusLabel.BackgroundTransparency = 1
		statusLabel.Size = UDim2.new(0, 110, 0, 18)
		statusLabel.Position = UDim2.new(1, -110, 0, 8)
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.TextSize = 12
		statusLabel.TextXAlignment = Enum.TextXAlignment.Right
		statusLabel.TextColor3 = WEEKLY_REWARD_ACCENT[definition.tier] or Color3.fromRGB(235, 240, 255)
		statusLabel.Text = "Currently Qualified"
		statusLabel.Visible = false
		statusLabel.Parent = rawFrame

		weeklyRewardRows[definition.tier] = {
			frame = rawFrame,
			stroke = stroke,
			statusLabel = statusLabel,
			baseColor = rawFrame.BackgroundColor3,
			highlightColor = WEEKLY_REWARD_HIGHLIGHT[definition.tier] or rawFrame.BackgroundColor3,
			accentColor = WEEKLY_REWARD_ACCENT[definition.tier] or Color3.fromRGB(235, 240, 255),
		}
	end

	local function ensureWeeklyRewardsPanel()
		local parent = getWeeklyRewardsParent()
		if not parent then
			return nil
		end

		if weeklyRewardsPanel and weeklyRewardsPanel.Parent ~= parent then
			weeklyRewardsPanel.Parent = parent
		end

		if not weeklyRewardsPanel or not weeklyRewardsPanel.Parent then
			weeklyRewardsPanel = Instance.new("Frame")
			weeklyRewardsPanel.Name = "WeeklyRewardsPanel"
			weeklyRewardsPanel.Parent = parent
		end

		weeklyRewardsPanel.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		weeklyRewardsPanel.BackgroundTransparency = 0.1
		weeklyRewardsPanel.Size = UDim2.new(1, -10, 0, 0)
		weeklyRewardsPanel.AutomaticSize = Enum.AutomaticSize.Y
		weeklyRewardsPanel.LayoutOrder = 4
		weeklyRewardsPanel.BorderSizePixel = 0
		weeklyRewardsPanel.Visible = true

		local corner = weeklyRewardsPanel:FindFirstChildOfClass("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Parent = weeklyRewardsPanel
		end
		corner.CornerRadius = UDim.new(0, 10)

		local stroke = weeklyRewardsPanel:FindFirstChildOfClass("UIStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Parent = weeklyRewardsPanel
		end
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(70, 90, 110)
		stroke.Transparency = 0.45

		local padding = weeklyRewardsPanel:FindFirstChildOfClass("UIPadding")
		if not padding then
			padding = Instance.new("UIPadding")
			padding.Parent = weeklyRewardsPanel
		end
		padding.PaddingTop = UDim.new(0, 12)
		padding.PaddingBottom = UDim.new(0, 12)
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 12)

		local layout = weeklyRewardsPanel:FindFirstChild("WeeklyRewardsLayout")
		if not layout then
			layout = Instance.new("UIListLayout")
			layout.Name = "WeeklyRewardsLayout"
			layout.FillDirection = Enum.FillDirection.Vertical
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			layout.VerticalAlignment = Enum.VerticalAlignment.Top
			layout.Padding = UDim.new(0, 10)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = weeklyRewardsPanel
		end

		if not weeklyRewardsPanel:GetAttribute("WeeklyRewardsBuilt") then
			for _, child in ipairs(weeklyRewardsPanel:GetChildren()) do
				if
					child ~= corner
					and child ~= stroke
					and child ~= padding
					and child ~= layout
					and child:IsA("Instance")
				then
					child:Destroy()
				end
			end

			weeklyRewardRows = {}

			local header = Instance.new("TextLabel")
			header.Name = "Header"
			header.BackgroundTransparency = 1
			header.Font = Enum.Font.GothamBold
			header.TextSize = 16
			header.TextColor3 = Color3.fromRGB(220, 230, 255)
			header.Text = "WEEKLY REWARDS"
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.Size = UDim2.new(1, 0, 0, 22)
			header.LayoutOrder = 1
			header.Parent = weeklyRewardsPanel

			for index, definition in ipairs(WEEKLY_REWARD_DEFINITIONS) do
				createWeeklyRewardRow(weeklyRewardsPanel, definition, index + 1)
			end

			local footer = Instance.new("TextLabel")
			footer.Name = "Countdown"
			footer.BackgroundTransparency = 1
			footer.Font = Enum.Font.Gotham
			footer.TextSize = 13
			footer.TextColor3 = Color3.fromRGB(205, 215, 230)
			footer.TextXAlignment = Enum.TextXAlignment.Left
			footer.Text = "Resets in: --"
			footer.Size = UDim2.new(1, 0, 0, 18)
			footer.LayoutOrder = #WEEKLY_REWARD_DEFINITIONS + 2
			footer.Parent = weeklyRewardsPanel
			weeklyRewardsCountdownLabel = footer

			weeklyRewardsPanel:SetAttribute("WeeklyRewardsBuilt", true)
			updateWeeklyRewardsCountdown()
			applyWeeklyRewardTierHighlight()
		end

		ensureWeeklyRewardsCountdownLoop()
		return weeklyRewardsPanel
	end

	local function handleWeeklyRewardsPayload(payload)
		if typeof(payload) ~= "table" then
			return
		end

		if typeof(payload.resetTimestamp) == "number" then
			weeklyRewardsExpiresAt = math.max(payload.resetTimestamp, os.time())
		elseif typeof(payload.resetSeconds) == "number" then
			weeklyRewardsExpiresAt = os.time() + math.max(payload.resetSeconds, 0)
		end

		if typeof(payload.qualifyingTier) == "string" then
			weeklyRewardsQualifyingTier = payload.qualifyingTier
		else
			weeklyRewardsQualifyingTier = nil
		end

		updateWeeklyRewardsCountdown()
		applyWeeklyRewardTierHighlight()
	 end

	local function requestWeeklyRewardsInfo(force)
		if not weeklyResetFunction then
			return
		end

		local now = os.clock()
		if not force and (now - lastWeeklyRewardsRequest) < 60 then
			return
		end
		lastWeeklyRewardsRequest = now

		task.spawn(function()
			local ok, payload = pcall(function()
				return weeklyResetFunction:InvokeServer()
			end)
			if ok and typeof(payload) == "table" then
				handleWeeklyRewardsPayload(payload)
			else
				updateWeeklyRewardsCountdown()
			end
		end)
	end

	local function initWeeklyRewardsPanel()
		if weeklyRewardsInitialized then
			return
		end
		weeklyRewardsInitialized = true

		ensureWeeklyRewardsPanel()
		applyWeeklyRewardTierHighlight()
		updateWeeklyRewardsCountdown()

		local statsRoot = resolveStatsPage()
		if statsRoot and statsRoot:IsA("GuiObject") then
			if weeklyRewardsVisibilityConnection then
				weeklyRewardsVisibilityConnection:Disconnect()
			end
			weeklyRewardsVisibilityConnection = statsRoot:GetPropertyChangedSignal("Visible"):Connect(function()
				if statsRoot.Visible then
					requestWeeklyRewardsInfo(true)
				end
			end)
			if statsRoot.Visible then
				requestWeeklyRewardsInfo(true)
			end
		else
			requestWeeklyRewardsInfo(true)
		end
	end

	initWeeklyRewardsPanel()
end

local function ensureRecommendedBadge(buttonInfo)
	if not buttonInfo or not buttonInfo.button then
		return nil
	end

	local badge = buttonInfo.recommendedLabel
	if badge and badge.Parent == buttonInfo.button then
		return badge
	end

	badge = Instance.new("TextLabel")
	badge.Name = "RecommendedBadge"
	badge.BackgroundTransparency = 1
	badge.Text = "★"
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 16
	badge.TextColor3 = Color3.fromRGB(255, 236, 160)
	badge.TextTransparency = 0.1
	badge.AnchorPoint = Vector2.new(0, 0)
	badge.Position = UDim2.new(0, 6, 0, 6)
	badge.Size = UDim2.new(0, 0, 0, 0)
	badge.AutomaticSize = Enum.AutomaticSize.XY
	badge.ZIndex = (buttonInfo.button.ZIndex or 1) + 2
	badge.Visible = false
	badge.Parent = buttonInfo.button
	buttonInfo.recommendedLabel = badge
	return badge
end

local function ensureLockOverlay(buttonInfo)
	if not buttonInfo or not buttonInfo.button then
		return nil
	end

	local overlay = buttonInfo.lockOverlay
	if overlay and overlay.Parent == buttonInfo.button then
		return overlay
	end

	overlay = Instance.new("Frame")
	overlay.Name = "LockOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(10, 12, 24)
	overlay.BackgroundTransparency = 0.4
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.AnchorPoint = Vector2.new(0, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.ZIndex = (buttonInfo.button.ZIndex or 1) + 5
	overlay.Parent = buttonInfo.button
	overlay.Active = true

	local blocker = overlay:FindFirstChild("Blocker")
	if not (blocker and blocker:IsA("TextButton")) then
		blocker = Instance.new("TextButton")
		blocker.Name = "Blocker"
		blocker.Size = UDim2.fromScale(1, 1)
		blocker.BackgroundTransparency = 1
		blocker.Text = ""
		blocker.AutoButtonColor = false
		blocker.Active = true
		blocker.Selectable = false
		blocker.Parent = overlay
	end

	local label = Instance.new("TextLabel")
	label.Name = "LockLabel"
	label.BackgroundTransparency = 1
	label.Text = "LOCKED"
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 230, 160)
	label.TextTransparency = 0.1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.5, 0)
	label.Size = UDim2.new(1, -12, 0, 18)
	label.ZIndex = overlay.ZIndex + 1
	label.Parent = overlay

	buttonInfo.lockOverlay = overlay
	return overlay
end

local function ensurePresetIconRow(buttonInfo)
	if not buttonInfo or not buttonInfo.button then
		return nil
	end

	local container = buttonInfo.iconContainer
	if container and container.Parent == buttonInfo.button then
		return container
	end

	container = Instance.new("Frame")
	container.Name = "PresetIconRow"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, -12, 0, 14)
	container.Position = UDim2.new(0, 6, 1, -18)
	container.AnchorPoint = Vector2.new(0, 1)
	container.ZIndex = (buttonInfo.button.ZIndex or 1) + 1
	container.Parent = buttonInfo.button

	local layout = Instance.new("UIListLayout")
	layout.Name = "PresetIconLayout"
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	buttonInfo.iconContainer = container
	buttonInfo.iconLabels = {}
	return container
end

local function refreshPresetButtonIcons(buttonInfo, isActive)
	if not buttonInfo then
		return
	end

	local enabledMap = buttonInfo.presetEnabled or {}
	local container = ensurePresetIconRow(buttonInfo)
	if not container then
		return
	end

	buttonInfo.iconLabels = buttonInfo.iconLabels or {}
	for order, definition in ipairs(PRESET_ICON_DEFINITIONS) do
		local label = buttonInfo.iconLabels[definition.id]
		if not label or label.Parent ~= container then
			label = Instance.new("TextLabel")
			label.Name = definition.id
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(0, 0, 1, 0)
			label.AutomaticSize = Enum.AutomaticSize.XY
			label.Font = Enum.Font.GothamBold
			label.TextSize = 12
			label.Text = definition.label
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.ZIndex = container.ZIndex
			label.LayoutOrder = order
			label.Parent = container
			buttonInfo.iconLabels[definition.id] = label
		end

		local enabled = enabledMap[definition.id] == true
		local activeColor = Color3.fromRGB(255, 245, 210)
		local enabledColor = Color3.fromRGB(220, 230, 255)
		local disabledColor = Color3.fromRGB(120, 130, 145)

		if enabled then
			label.TextColor3 = isActive and activeColor or enabledColor
			label.TextTransparency = isActive and 0 or 0.15
		else
			label.TextColor3 = disabledColor
			label.TextTransparency = 0.35
		end
	end
end

local function setPresetLockedState(buttonInfo, locked)
	if not buttonInfo then
		return
	end

	buttonInfo.locked = locked == true
	local overlay = ensureLockOverlay(buttonInfo)
	if overlay then
		overlay.Visible = buttonInfo.locked
	end

	if buttonInfo.button then
		buttonInfo.button.AutoButtonColor = not buttonInfo.locked
	end
end

local function createAutoSwitchButton(name, templateButton)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = templateButton and templateButton.Size or UDim2.new(1, -10, 0, 34)
	button.BackgroundColor3 = templateButton and templateButton.BackgroundColor3 or Color3.fromRGB(34, 40, 49)
	button.BackgroundTransparency = templateButton and templateButton.BackgroundTransparency or 0
	button.TextColor3 = templateButton and templateButton.TextColor3 or Color3.fromRGB(235, 238, 255)
	button.TextSize = templateButton and templateButton.TextSize or 14
	button.Font = templateButton and templateButton.Font or Enum.Font.GothamBold
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Name = "AutoSwitchStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Transparency = 0.6
	stroke.Color = Color3.fromRGB(70, 88, 110)
	stroke.Parent = button
	return button
end

local function ensureAutoSwitchControlsContainer(autoBuyPresetsFrame)
	local controlsContainer = autoBuyPresetsFrame:FindFirstChild("AutoSwitchControls")
	if controlsContainer then
		return controlsContainer
	end

	controlsContainer = Instance.new("Frame")
	controlsContainer.Name = "AutoSwitchControls"
	controlsContainer.BackgroundTransparency = 1
	local parentLayout = autoBuyPresetsFrame:FindFirstChildOfClass("UIListLayout")
	if parentLayout then
		controlsContainer.AutomaticSize = Enum.AutomaticSize.Y
		controlsContainer.Size = UDim2.new(1, 0, 0, 0)
		controlsContainer.LayoutOrder = 1000
	else
		controlsContainer.Size = UDim2.new(1, 0, 0, 80)
		controlsContainer.AnchorPoint = Vector2.new(0, 1)
		controlsContainer.Position = UDim2.new(0, 0, 1, -8)
	end
	controlsContainer.Parent = autoBuyPresetsFrame
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.Name = "AutoSwitchLayout"
	controlsLayout.FillDirection = Enum.FillDirection.Vertical
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	controlsLayout.Padding = UDim.new(0, 6)
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Parent = controlsContainer
	return controlsContainer
end

local function connectAutoSwitchButtons(controlsContainer, templateButton, onToggle, onCycle)
	local toggleButton = controlsContainer:FindFirstChild("AutoSwitchToggle")
	if not toggleButton then
		toggleButton = createAutoSwitchButton("AutoSwitchToggle", templateButton)
		toggleButton.LayoutOrder = 1
		toggleButton.Parent = controlsContainer
	end
	toggleButton.Activated:Connect(onToggle)

	local presetButton = controlsContainer:FindFirstChild("AutoSwitchPreset")
	if not presetButton then
		presetButton = createAutoSwitchButton("AutoSwitchPreset", templateButton)
		presetButton.LayoutOrder = 2
		presetButton.Parent = controlsContainer
	end
	presetButton.Activated:Connect(onCycle)

	return toggleButton, presetButton
end

local function ensureAutoBuyPanel(parent, layoutOrder)
	if not parent then
		return nil
	end

	local panel = parent:FindFirstChild("AutoBuyPanel")
	local created = false
	if not (panel and panel:IsA("Frame")) then
		panel = Instance.new("Frame")
		panel.Name = "AutoBuyPanel"
		panel.BackgroundColor3 = Color3.fromRGB(17, 24, 35)
		panel.BackgroundTransparency = 0.08
		panel.Size = UDim2.new(1, -10, 0, 0)
		panel.LayoutOrder = layoutOrder or 3
		panel.AutomaticSize = Enum.AutomaticSize.Y
		panel.Parent = parent
		created = true

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = panel

		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(60, 78, 110)
		stroke.Transparency = 0.5
		stroke.Parent = panel

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 10)
		padding.PaddingBottom = UDim.new(0, 10)
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.Parent = panel

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = panel
	end

	local header = panel:FindFirstChild("AutoBuyHeader")
	if not (header and header:IsA("TextLabel")) then
		header = Instance.new("TextLabel")
		header.Name = "AutoBuyHeader"
		header.BackgroundTransparency = 1
		header.Font = Enum.Font.GothamBold
		header.TextSize = 14
		header.TextColor3 = Color3.fromRGB(200, 240, 255)
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Text = "AUTO BUY (Server Controlled)"
		header.Size = UDim2.new(1, 0, 0, 18)
		header.LayoutOrder = 1
		header.Parent = panel
	end

	local hint = panel:FindFirstChild("AutoBuyHint")
	if not (hint and hint:IsA("TextLabel")) then
		hint = Instance.new("TextLabel")
		hint.Name = "AutoBuyHint"
		hint.BackgroundTransparency = 1
		hint.Font = Enum.Font.Gotham
		hint.TextSize = 12
		hint.TextColor3 = Color3.fromRGB(165, 185, 210)
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.Text = "Toggles run on the server. Long-press or right-click your upgrades to buy max."
		hint.Size = UDim2.new(1, 0, 0, 0)
		hint.AutomaticSize = Enum.AutomaticSize.Y
		hint.LayoutOrder = 2
		hint.Parent = panel
	end

	if created then
		local layout = panel:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout:ApplyLayout()
		end
	end

	return panel
end

local function styleAutoBuyButton(button, enabled)
	if not button then
		return
	end

	local baseColor = button:GetAttribute("BaseColor") or button.BackgroundColor3
	local highlightColor = button:GetAttribute("HighlightColor") or baseColor:Lerp(Color3.fromRGB(120, 255, 180), 0.35)
	button:SetAttribute("BaseColor", baseColor)
	button:SetAttribute("HighlightColor", highlightColor)

	button.BackgroundColor3 = enabled and highlightColor or baseColor
	button.TextColor3 = enabled and Color3.new(0.1, 0.15, 0.15) or Color3.fromRGB(230, 238, 255)
	button.Text = string.format("%s: %s", button:GetAttribute("DisplayLabel") or button.Name, enabled and "ON" or "OFF")

	local stroke = button:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button
	end
	stroke.Color = enabled and Color3.fromRGB(120, 255, 200) or Color3.fromRGB(70, 88, 110)
	stroke.Transparency = enabled and 0.15 or 0.55
end

local function ensureAutoBuyButton(panel, branchDef)
	if not panel then
		return nil
	end

	local buttonName = "AutoBuy" .. branchDef.id
	local button = panel:FindFirstChild(buttonName)
	if not (button and button:IsA("TextButton")) then
		button = Instance.new("TextButton")
		button.Name = buttonName
		button.Size = UDim2.new(1, -4, 0, 36)
		button.AutoButtonColor = true
		button.Text = branchDef.label
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.BackgroundColor3 = Color3.fromRGB(34, 40, 49)
		button.LayoutOrder = 10
		button.Parent = panel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(70, 88, 110)
		stroke.Transparency = 0.6
		stroke.Parent = button
	end

	button:SetAttribute("DisplayLabel", branchDef.label)
	button:SetAttribute("AutoBuyBranch", branchDef.id)
	return button
end

local function initAutoBuyControls(options)
	local rightPanel = options and options.rightPanel
	local layoutOrder = options and options.layoutOrder
	local panel = ensureAutoBuyPanel(rightPanel, layoutOrder)
	if not panel then
		return nil
	end

	local buttons = {}
	local state = {}
	local setEvent = options and options.setEvent

	local function updateButton(branchId)
		local button = buttons[branchId]
		if button then
			styleAutoBuyButton(button, state[branchId] == true)
		end
	end

	for index, branchDef in ipairs(AUTO_BUY_BRANCHES) do
		local button = ensureAutoBuyButton(panel, branchDef)
		if button then
			button.LayoutOrder = 10 + index
			buttons[branchDef.id] = button
			state[branchDef.id] = false
			button.Activated:Connect(function()
				local newValue = not (state[branchDef.id] == true)
				state[branchDef.id] = newValue
				updateButton(branchDef.id)
				if setEvent then
					setEvent:FireServer({
						upgradeType = branchDef.id,
						enabled = newValue,
					})
				end
			end)
		end
	end

	for branchId in pairs(buttons) do
		updateButton(branchId)
	end

	local controller = {}

	function controller.ApplyState(newState)
		if typeof(newState) ~= "table" then
			return
		end
		for _, branchDef in ipairs(AUTO_BUY_BRANCHES) do
			local desired = newState[branchDef.id] == true
			state[branchDef.id] = desired
			updateButton(branchDef.id)
		end
	end

	function controller.GetState()
		return table.clone(state)
	end

	return controller
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

	local badge = ensureRecommendedBadge(buttonInfo)
	if badge then
		if isRecommended then
			badge.TextColor3 = isActive and Color3.fromRGB(255, 244, 200) or Color3.fromRGB(255, 236, 160)
			badge.TextTransparency = 0.05
		end
		badge.Visible = isRecommended
	end

	refreshPresetButtonIcons(buttonInfo, isActive)
end

local function configurePresetButton(context, index, button)
	local autoBuyPresetButtons = context.autoBuyPresetButtons
	autoBuyPresetButtons[index] = {
		button = button,
		baseColor = button.BackgroundColor3,
		baseTransparency = button.BackgroundTransparency,
		stroke = button:FindFirstChildOfClass("UIStroke"),
		locked = false,
	}

	button.Activated:Connect(function()
		if context.handlePresetApply then
			context.handlePresetApply(index)
		end
	end)

	ensurePresetIconRow(autoBuyPresetButtons[index])
	ensureLockOverlay(autoBuyPresetButtons[index])
end

local function ensureButtonBaseAttributes(button)
	if not button then
		return
	end
	if not button:GetAttribute("BaseColor") then
		button:SetAttribute("BaseColor", button.BackgroundColor3)
		button:SetAttribute("HighlightColor", button.BackgroundColor3:Lerp(Color3.fromRGB(255, 247, 200), 0.35))
	end
	if not button:GetAttribute("BaseStrokeThickness") then
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			button:SetAttribute("BaseStrokeThickness", stroke.Thickness)
		end
	end
end

local function clampAutoSwitchSelection(context, index)
	local fallback = context.autoSwitchPresetIndex or 1
	local numeric = typeof(index) == "number" and math.floor(index + 0.5) or fallback
	local maxIndex = math.max(1, context.autoSwitchMaxPresetIndex or context.autoPresetCount or 1)
	return math.clamp(numeric, 1, maxIndex)
end

local function promptPresetUnlock(context)
	local passId = context.preset4GamepassId
	if typeof(passId) ~= "number" or passId <= 0 then
		local automationConstants = context.AutomationConstants
		if automationConstants then
			passId = automationConstants.GamepassIdPreset4
		end
	end

	if typeof(passId) == "number" and passId > 0 and context.player and context.MarketplaceService then
		context.MarketplaceService:PromptGamePassPurchase(context.player, passId)
	end
end

local function throttlePresetButton(context, index)
	local info = context.autoBuyPresetButtons[index]
	if info and info.button then
		info.button.Active = false
	end
	context.presetButtonCooldowns[index] = true
	task.delay(1.5, function()
		context.presetButtonCooldowns[index] = nil
		local refreshed = context.autoBuyPresetButtons[index]
		if refreshed and refreshed.button then
			refreshed.button.Active = true
		end
	end)
end

local function handlePresetApply(context, index)
	if not context.autoBuyPresetApplyEvent then
		return
	end

	local buttonInfo = context.autoBuyPresetButtons[index]
	if not buttonInfo then
		return
	end

	if buttonInfo.locked then
		promptPresetUnlock(context)
		return
	end

	if context.presetButtonCooldowns[index] then
		return
	end

	if context.triggerHaptic then
		context.triggerHaptic("medium")
	end

	throttlePresetButton(context, index)
	context.autoBuyPresetApplyEvent:FireServer(index)
	context.lastPresetIndex = index
end

local function buildPresetSavePayload(context)
	local settings = context.currentPresetSettings
	if not settings then
		return nil
	end

	local enabledClone = table.clone(settings.enabled or {})
	local priorityClone = table.clone(settings.priority or {})
	local attributeOrder = {}
	local attributeMap = context.automationAttributesById or {}
	for _, automationId in ipairs(priorityClone) do
		local attributeName = attributeMap[automationId]
		table.insert(attributeOrder, attributeName or automationId)
	end

	local payload = {
		enabled = enabledClone,
		priority = priorityClone,
		PriorityOrder = attributeOrder,
	}

	for automationId, attributeName in pairs(attributeMap) do
		payload[attributeName] = enabledClone[automationId] == true
	end

	return payload
end

local function updateAutoSwitchUI(context)
	context.autoSwitchPresetIndex = clampAutoSwitchSelection(context, context.autoSwitchPresetIndex)
	local autoSwitchEnabled = context.autoSwitchEnabled

	local toggleButton = context.autoSwitchToggleButton
	if toggleButton then
		ensureButtonBaseAttributes(toggleButton)
		local baseColor = toggleButton:GetAttribute("BaseColor")
		local highlightColor = toggleButton:GetAttribute("HighlightColor") or baseColor
		if baseColor and highlightColor then
			toggleButton.BackgroundColor3 = autoSwitchEnabled and highlightColor or baseColor
		end
		local stroke = toggleButton:FindFirstChildOfClass("UIStroke")
		if stroke then
			local baseThickness = toggleButton:GetAttribute("BaseStrokeThickness") or stroke.Thickness
			stroke.Thickness = autoSwitchEnabled and math.max(baseThickness, 2) or baseThickness
			stroke.Transparency = autoSwitchEnabled and 0.15 or 0.6
		end
		toggleButton.Text = string.format("AUTO-SWITCH ON PRESTIGE: %s", autoSwitchEnabled and "ON" or "OFF")
	end

	local presetButton = context.autoSwitchPresetButton
	if presetButton then
		ensureButtonBaseAttributes(presetButton)
		local maxIndex = math.max(1, context.autoSwitchMaxPresetIndex or context.autoPresetCount or 1)
		presetButton.Text = string.format("AUTO PRESET SLOT: %d/%d", context.autoSwitchPresetIndex, maxIndex)
		presetButton.TextTransparency = autoSwitchEnabled and 0 or 0.25
		presetButton.AutoButtonColor = maxIndex > 1
		presetButton.Active = maxIndex > 1
		local stroke = presetButton:FindFirstChildOfClass("UIStroke")
		if stroke then
			local baseThickness = presetButton:GetAttribute("BaseStrokeThickness") or stroke.Thickness
			stroke.Thickness = autoSwitchEnabled and math.max(baseThickness, 2) or baseThickness
			stroke.Transparency = autoSwitchEnabled and 0.2 or 0.65
		end
	end
end

local function sendAutoSwitchSettings(context, newEnabled, newPresetIndex)
	local settingsEvent = context.autoBuyAutoSwitchSettingsEvent
	if not settingsEvent then
		return
	end

	local enabledValue = newEnabled
	if enabledValue == nil then
		enabledValue = context.autoSwitchEnabled
	end

	local presetValue = clampAutoSwitchSelection(context, newPresetIndex or context.autoSwitchPresetIndex or 1)
	settingsEvent:FireServer(enabledValue, presetValue)
end

local function handleAutoSwitchToggle(context)
	context.autoSwitchEnabled = not context.autoSwitchEnabled
	updateAutoSwitchUI(context)
	sendAutoSwitchSettings(context, context.autoSwitchEnabled, context.autoSwitchPresetIndex)
	if context.triggerHaptic then
		context.triggerHaptic("light")
	end
end

local function handleAutoSwitchPresetCycle(context)
	local maxIndex = context.autoSwitchMaxPresetIndex or context.autoPresetCount or 1
	if maxIndex <= 1 then
		return
	end

	local nextIndex = (context.autoSwitchPresetIndex or 1) + 1
	if nextIndex > maxIndex then
		nextIndex = 1
	end

	context.autoSwitchPresetIndex = nextIndex
	updateAutoSwitchUI(context)
	sendAutoSwitchSettings(context, context.autoSwitchEnabled, context.autoSwitchPresetIndex)
end

local function updateAutoBuyPresetVisuals(context)
	for index, buttonInfo in pairs(context.autoBuyPresetButtons) do
		local isActive = context.activePresetIndex == index
		local isRecommended = context.recommendedPresetIndex == index
		stylePresetButton(buttonInfo, isActive, isRecommended)
	end
end

local function sumUpgradesForPrefix(context, prefix)
	local total = 0
	local playerState = context.playerState or {}
	local upgrades = playerState.upgrades
	if typeof(upgrades) ~= "table" then
		return 0
	end

	for upgradeId, level in pairs(upgrades) do
		if typeof(upgradeId) == "string" and string.sub(upgradeId, 1, #prefix) == prefix then
			if typeof(level) == "number" and level > 0 then
				total += level
			end
		end
	end

	return total
end

local function bucketUpgradeCount(value, bucketSize)
	if typeof(value) ~= "number" or typeof(bucketSize) ~= "number" or bucketSize <= 0 then
		return 0
	end
	return math.floor(math.max(value, 0) / bucketSize)
end

local function determineRecommendedPreset(context)
	local playerState = context.playerState or {}
	local prestige = typeof(playerState.prestige) == "number" and playerState.prestige or 0
	local cpuLevels = sumUpgradesForPrefix(context, "cpu_")
	local ramLevels = sumUpgradesForPrefix(context, "ram_")
	local storageLevels = sumUpgradesForPrefix(context, "storage_")
	local bucketSize = context.recommendationBucketSize or 1
	local info = {
		prestige = prestige,
		cpuBucket = bucketUpgradeCount(cpuLevels, bucketSize),
		ramBucket = bucketUpgradeCount(ramLevels, bucketSize),
		storageBucket = bucketUpgradeCount(storageLevels, bucketSize),
	}

	if prestige <= 0 then
		return 1, info
	end

	local storageLagDelta = context.storageLagDelta or 0
	if prestige >= 2 and (math.min(cpuLevels, ramLevels) - storageLevels) >= storageLagDelta then
		return 3, info
	end

	if prestige >= 1 and (cpuLevels < ramLevels or cpuLevels < storageLevels) then
		return 2, info
	end

	return 1, info
end

local function updateAutoBuyRecommendation(context, force)
	local recommended, info = determineRecommendedPreset(context)
	if not recommended then
		return
	end

	local contextChanged = force or not context.lastRecommendationContext
	if not contextChanged then
		for key, value in pairs(info) do
			if context.lastRecommendationContext[key] ~= value then
				contextChanged = true
				break
			end
		end
	end

	if contextChanged or context.recommendedPresetIndex ~= recommended then
		context.lastRecommendationContext = info
		context.recommendedPresetIndex = recommended
		updateAutoBuyPresetVisuals(context)
	end
end

local function ensurePresetButton(context, index, template)
	local autoBuyPresetsFrame = context.autoBuyPresetsFrame
	local safeFind = context.safeFind
	if not autoBuyPresetsFrame or not safeFind then
		return
	end

	local button = safeFind(autoBuyPresetsFrame, "Preset" .. index)
	if not button and template then
		button = template:Clone()
		button.Name = "Preset" .. index
		button.LayoutOrder = index
		button.Visible = true
		button.Parent = autoBuyPresetsFrame
	end

	if button and button:IsA("GuiButton") then
		configurePresetButton(context, index, button)
	end
end

local function connectPresetSaveButton(context)
	local autoBuyPresetsFrame = context.autoBuyPresetsFrame
	local safeFind = context.safeFind
	if not (autoBuyPresetsFrame and safeFind) then
		return
	end

	local button = safeFind(autoBuyPresetsFrame, "SavePreset")
	if not (button and button:IsA("GuiButton")) then
		return
	end

	context.autoBuyPresetSaveButton = button
	button.Activated:Connect(function()
		if not context.autoBuyPresetSaveEvent or not context.currentPresetSettings then
			return
		end

		local targetIndex = context.activePresetIndex or context.lastPresetIndex or 1
		local payload = buildPresetSavePayload(context)
		if not payload then
			return
		end

		if context.autoBuyPresetSaveButton then
			context.autoBuyPresetSaveButton.Active = false
		end
		context.autoBuyPresetSaveEvent:FireServer(targetIndex, payload)
		context.pendingPresetSaveToast = true
		task.delay(1.5, function()
			if context.autoBuyPresetSaveButton then
				context.autoBuyPresetSaveButton.Active = true
			end
		end)
	end)
end

local function handleAutoBuyPresetState(context, payload)
	if typeof(payload) ~= "table" then
		return
	end

	if typeof(payload.presets) == "table" then
		for index, preset in ipairs(payload.presets) do
			local buttonInfo = context.autoBuyPresetButtons[index]
			if buttonInfo and buttonInfo.button and typeof(preset) == "table" and typeof(preset.name) == "string" then
				buttonInfo.button.Text = preset.name
				if typeof(preset.enabled) == "table" then
					buttonInfo.presetEnabled = table.clone(preset.enabled)
				else
					buttonInfo.presetEnabled = nil
				end
			end
		end
	end

	if typeof(payload.settings) == "table" then
		context.currentPresetSettings = {
			enabled = table.clone(payload.settings.enabled or {}),
			priority = table.clone(payload.settings.priority or {}),
		}
	end

	if typeof(payload.presetUnlocks) == "table" then
		for index, unlocked in pairs(payload.presetUnlocks) do
			local buttonInfo = context.autoBuyPresetButtons[index]
			if buttonInfo then
				setPresetLockedState(buttonInfo, unlocked ~= true)
			end
		end
	end

	if typeof(payload.presetGamepass) == "table" and typeof(payload.presetGamepass.gamepassId) == "number" then
		context.preset4GamepassId = payload.presetGamepass.gamepassId
	end

	if typeof(payload.autoSwitch) == "table" then
		context.autoSwitchEnabled = payload.autoSwitch.enabled == true
		local maxIndex = typeof(payload.autoSwitch.maxPresetIndex) == "number" and math.floor(payload.autoSwitch.maxPresetIndex + 0.5) or context.autoPresetCount
		maxIndex = maxIndex or 1
		context.autoSwitchMaxPresetIndex = math.max(1, math.min(context.autoPresetCount or maxIndex, maxIndex))
		context.autoSwitchPresetIndex = clampAutoSwitchSelection(context, payload.autoSwitch.presetIndex)
		updateAutoSwitchUI(context)
	end

	if typeof(payload.maxUnlockedPresetIndex) == "number" then
		local numeric = math.floor(payload.maxUnlockedPresetIndex + 0.5)
		context.autoSwitchMaxPresetIndex = math.max(1, math.min(context.autoPresetCount or numeric, numeric))
	end

	if typeof(payload.activePreset) == "number" then
		local maxSlots = context.autoPresetCount or 1
		context.activePresetIndex = math.clamp(math.floor(payload.activePreset + 0.5), 1, maxSlots)
		context.lastPresetIndex = context.activePresetIndex
	else
		context.activePresetIndex = nil
	end

	for _, buttonInfo in pairs(context.autoBuyPresetButtons) do
		if buttonInfo.button then
			buttonInfo.button.Active = true
			if not buttonInfo.locked then
				buttonInfo.button.AutoButtonColor = true
			end
		end
	end

	if context.autoBuyPresetSaveButton then
		context.autoBuyPresetSaveButton.Active = true
	end

	table.clear(context.presetButtonCooldowns)

	updateAutoBuyPresetVisuals(context)

	if context.pendingPresetSaveToast and context.showToast then
		context.showToast("Preset Saved")
		context.pendingPresetSaveToast = false
	end

	if payload.autoSwitchApplied and context.showToast then
		context.showToast("Auto preset applied")
	end
end

local function initAutoBuyPresetUI(context)
	local autoBuyPresetsFrame = context.autoBuyPresetsFrame
	if not autoBuyPresetsFrame and context.rightPanel and context.waitForChildWithTimeout then
		autoBuyPresetsFrame = context.waitForChildWithTimeout(context.rightPanel, "AutoBuyPresets")
	end

	if not autoBuyPresetsFrame then
		return
	end

	context.autoBuyPresetsFrame = autoBuyPresetsFrame

	local safeFind = context.safeFind
	local presetTemplate = safeFind and safeFind(autoBuyPresetsFrame, "Preset1") or nil

	for index = 1, context.autoPresetCount or 1 do
		ensurePresetButton(context, index, presetTemplate)
	end

	connectPresetSaveButton(context)

	local controlsContainer = ensureAutoSwitchControlsContainer(autoBuyPresetsFrame)
	local templateButton = context.autoBuyPresetButtons[1] and context.autoBuyPresetButtons[1].button
	local toggleButton, presetButton = connectAutoSwitchButtons(
		controlsContainer,
		templateButton,
		function()
			handleAutoSwitchToggle(context)
		end,
		function()
			handleAutoSwitchPresetCycle(context)
		end
	)
	context.autoSwitchToggleButton = toggleButton
	context.autoSwitchPresetButton = presetButton

	updateAutoSwitchUI(context)
end

local function requestAutoBuyPresetState(context)
	if not context.requestAutoBuyPresets then
		return
	end

	task.spawn(function()
		local ok, response = pcall(function()
			return context.requestAutoBuyPresets:InvokeServer()
		end)
		if ok and response then
			handleAutoBuyPresetState(context, response)
		end
	end)
end


function LoadingInitializer.Init()
	local success, errorMessage = pcall(function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local MarketplaceService = game:GetService("MarketplaceService")
	local UserInputService = game:GetService("UserInputService")
	local HapticService = game:GetService("HapticService")
	local TerminalUIBinder = require(script.Parent:WaitForChild("TerminalUIBinder"))
	local ToastController = require(script.Parent:WaitForChild("ToastController"))
	local StoreUIController = require(script.Parent:WaitForChild("StoreUIController"))
	local BoostUIController = require(script.Parent:WaitForChild("BoostUIController"))
	local LeaderboardClient = require(script.Parent:WaitForChild("LeaderboardClient"))
	local StarterGui = game:GetService("StarterGui")
	

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	if not player then
		warn("[TerminalClient] LocalPlayer missing")
		return
	end

	local clientReadyFlag = false
	local readyCallbacks = {}
	local weeklyResetFunction

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

	if not remotesFolder then
		warn("[TerminalClient] Remotes folder missing")
		return
	end

	local function waitForRemote(name)
		return waitForChildWithTimeout(remotesFolder, name) or safeFind(remotesFolder, name)
	end

	local function resolveRequestSync()
		local rs = ReplicatedStorage
		if not rs then
			return nil
		end
		local remotes = rs:FindFirstChild("Remotes")
		if not remotes then
			return nil
		end
		local rf = remotes:FindFirstChild("RequestSync")
		if rf and rf:IsA("RemoteFunction") then
			return rf
		end
		return nil
	end

	local requestSync = resolveRequestSync()
	local purchaseUpgradeEvent = waitForRemote("PurchaseUpgrade")
	local prestigeEvent = waitForRemote("RequestPrestige")
	local prestigePreviewEvent = waitForRemote("PrestigePreviewUpdate")
	local requestPrestigePreview = waitForRemote("RequestPrestigePreview")
	local sessionBonusEvent = waitForRemote("SessionBonusUpdate")
	local globalAnnouncementEvent = waitForRemote("GlobalAnnouncement")
	local globalStatsEvent = waitForRemote("GlobalStatsUpdate")
	local serverPowerEvent = waitForRemote("ServerPowerUpdate")
	local systemNotificationEvent = waitForRemote("SystemNotification")
	local leaderboardFunction = waitForRemote("GetLeaderboard")
	local lifetimeLeaderboardFunction = waitForRemote("GetLifetimeLeaderboard")
	weeklyResetFunction = waitForRemote("GetWeeklyResetTime")
	local autoBuyPresetApplyEvent = safeFind(remotesFolder, "AutoBuyPresetApply")
	local autoBuyPresetSaveEvent = safeFind(remotesFolder, "AutoBuyPresetSave")
	local autoBuyPresetStateEvent = safeFind(remotesFolder, "AutoBuyPresetState")
	local requestAutoBuyPresets = safeFind(remotesFolder, "RequestAutoBuyPresets")
	local autoBuyPresetUnlockPromptEvent = safeFind(remotesFolder, "AutoBuyPresetUnlockPrompt")
	local autoBuyAutoSwitchSettingsEvent = safeFind(remotesFolder, "AutoBuyAutoSwitchSettings")
	local setAutoBuyEvent = safeFind(remotesFolder, "SetAutoBuy")
	local autoBuyStateEvent = safeFind(remotesFolder, "AutoBuyState")

	if
		not (
			requestSync
			and purchaseUpgradeEvent
			and prestigeEvent
			and prestigePreviewEvent
			and requestPrestigePreview
			and sessionBonusEvent
			and globalAnnouncementEvent
			and globalStatsEvent
			and serverPowerEvent
			and systemNotificationEvent
			and leaderboardFunction
			and lifetimeLeaderboardFunction
			and weeklyResetFunction
			and setAutoBuyEvent
			and autoBuyStateEvent
		)
	then
		warn("[TerminalClient] Required remotes missing")
		return
	end

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
			leaderboardFunction = leaderboardFunction,
			lifetimeLeaderboardFunction = lifetimeLeaderboardFunction,
			weeklyResetFunction = weeklyResetFunction,
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

	local function initRightPanelTabs()
		if not rightPanel or not waitForChildWithTimeout then
			return
		end

		local tabs = waitForChildWithTimeout(rightPanel, "Tabs")
		local pages = waitForChildWithTimeout(rightPanel, "Pages")
		local statsTab = tabs and waitForChildWithTimeout(tabs, "StatsTab")
		local leaderboardTab = tabs and waitForChildWithTimeout(tabs, "LeaderboardTab")
		local statsPage = pages and waitForChildWithTimeout(pages, "StatsPage")
		local leaderboardPage = pages and waitForChildWithTimeout(pages, "LeaderboardPage")

		if not (tabs and pages and statsTab and leaderboardTab and statsPage and leaderboardPage) then
			warn("[TerminalClient] Leaderboard tabs missing, skipping toggles")
			return
		end

		local function setTabVisual(tab, active)
			if not (tab and tab:IsA("TextButton")) then
				return
			end
			local baseColor = Color3.fromRGB(45, 50, 70)
			local activeColor = Color3.fromRGB(70, 110, 255)
			tab.BackgroundColor3 = active and activeColor or baseColor
			local stroke = tab:FindFirstChild("Stroke") or tab:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = active and 0.25 or 0.5
			end
		end

		local function setActiveTab(which)
			local showStats = which == "Stats"
			statsPage.Visible = showStats
			leaderboardPage.Visible = not showStats
			setTabVisual(statsTab, showStats)
			setTabVisual(leaderboardTab, not showStats)
		end

		statsTab.Activated:Connect(function()
			setActiveTab("Stats")
		end)

		leaderboardTab.Activated:Connect(function()
			setActiveTab("Leaderboard")
		end)

		setActiveTab("Stats")
	end

	initRightPanelTabs()

	local function normalizeLeaderboardList(listObject)
		if not (listObject and listObject:IsA("ScrollingFrame")) then
			return
		end

		listObject.Size = UDim2.new(1, 0, 1, -92)
		listObject.Position = UDim2.fromOffset(0, 92)
		listObject.AutomaticCanvasSize = Enum.AutomaticSize.Y
		listObject.ScrollBarThickness = 6
		listObject.CanvasSize = UDim2.new(0, 0, 0, 0)
		listObject.BorderSizePixel = 0
		listObject.ClipsDescendants = true

		local rowTemplate = listObject:FindFirstChild("RowTemplate")
		if rowTemplate and rowTemplate:IsA("Frame") then
			rowTemplate.Size = UDim2.new(1, 0, 0, 44)
			rowTemplate.Position = UDim2.new(0, 0, 0, 0)
			rowTemplate.AnchorPoint = Vector2.new(0, 0)
		end
	end

	local function normalizeLeaderboardPage(page)
		if not (page and page:IsA("Frame")) then
			return
		end

		page.Size = UDim2.new(1, 0, 1, 0)
		page.Position = UDim2.new(0, 0, 0, 0)
		page.AutomaticSize = Enum.AutomaticSize.None
		page.ZIndex = math.max(page.ZIndex or 0, 20)

		local listObject = page:FindFirstChild("List")
		if listObject then
			normalizeLeaderboardList(listObject)
		end
	end

	local function configureLeaderboardPages()
		if not rightPanel then
			return
		end

		local pages = safeFind(rightPanel, "Pages")
		if not pages then
			return
		end

		for _, pageName in ipairs({ "LeaderboardPage", "FriendsLeaderboardPage", "WeeklyLeaderboardPage" }) do
			local page = safeFind(pages, pageName)
			normalizeLeaderboardPage(page)
		end
	end

	configureLeaderboardPages()

	local autoBuyController = initAutoBuyControls({
		rightPanel = rightPanel,
		layoutOrder = 3,
		setEvent = setAutoBuyEvent,
	})
	local pendingAutoBuyState
	if autoBuyController then
		autoBuyController.ApplyState({
			CPU = false,
			RAM = false,
			STORAGE = false,
		})
	end

	initWeeklyRewardsPreview({
		safeFind = safeFind,
		rightPanel = rightPanel,
		statsBox = statsBox,
		weeklyResetFunction = weeklyResetFunction,
	})
	local toastController = ToastController.Init(context)
	local storeController = StoreUIController.Init(context)
	local boostController = BoostUIController.Init(context)
	local leaderboardController = LeaderboardClient.Init(context)
	local showToast = toastController and toastController.ShowToast or function() end
	local triggerHaptic = createHapticTrigger({
		userInputService = UserInputService,
		hapticService = HapticService,
	})

	local sessionBonusPanel
	local sessionBonusProgressFill
	local sessionBonusProgressLabel
	local sessionBonusTargetSeconds = 20 * 60
	local globalStatsPanel
	local globalStatsDataValue
	local globalStatsPrestigeValue
	local serverPowerPanel
	local serverPowerLabel


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
			local claimedReward = false
			for _ in ipairs(activatedRewards) do
				showToast("Session Bonus Activated!")
				claimedReward = true
			end
			if claimedReward then
				triggerHaptic("medium")
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

	local weeklyChampionToastCounter = 0

	local function playWeeklyChampionToast(payload)
		if not toastArea or not TweenService then
			return
		end

		local isFresh = payload.fresh ~= false
		local playerName = typeof(payload.name) == "string" and payload.name or "Player"
		local totalValue = typeof(payload.value) == "number" and math.max(payload.value, 0) or 0

		local toastFrame = Instance.new("Frame")
		toastFrame.Name = "WeeklyChampionToast"
		toastFrame.AnchorPoint = Vector2.new(0.5, 0)
		toastFrame.BackgroundColor3 = Color3.fromRGB(28, 30, 45)
		toastFrame.BackgroundTransparency = 1
		toastFrame.Size = UDim2.new(1, -20, 0, isFresh and 110 or 90)
		toastFrame.Position = UDim2.new(0.5, 0, 0, 0)
		toastFrame.ZIndex = math.max(toastArea.ZIndex or 0, 60)
		toastFrame.BorderSizePixel = 0
		toastFrame.Parent = toastArea

		weeklyChampionToastCounter += 1
		toastFrame.LayoutOrder = -weeklyChampionToastCounter

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = toastFrame

		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(255, 215, 160)
		stroke.Transparency = isFresh and 0.4 or 0.7
		stroke.Parent = toastFrame

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 10)
		padding.PaddingBottom = UDim.new(0, 12)
		padding.PaddingLeft = UDim.new(0, 14)
		padding.PaddingRight = UDim.new(0, 14)
		padding.Parent = toastFrame

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = isFresh and 18 or 16
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "🏆 Weekly Champion"
		title.Size = UDim2.new(1, 0, 0, 22)
		title.Parent = toastFrame

		local body = Instance.new("TextLabel")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Font = Enum.Font.GothamSemibold
		body.TextSize = isFresh and 17 or 15
		body.TextColor3 = Color3.fromRGB(230, 235, 255)
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Center
		body.TextWrapped = true
		body.Text = string.format("%s dominated the system!", playerName)
		body.Size = UDim2.new(1, 0, 0, 32)
		body.Position = UDim2.new(0, 0, 0, 30)
		body.Parent = toastFrame

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = "Value"
		valueLabel.BackgroundTransparency = 1
		valueLabel.Font = Enum.Font.Gotham
		valueLabel.TextSize = 14
		valueLabel.TextColor3 = Color3.fromRGB(210, 215, 240)
		valueLabel.TextXAlignment = Enum.TextXAlignment.Left
		valueLabel.Text = totalValue > 0 and string.format("+%s Data", NumberFormatter.format(totalValue)) or ""
		valueLabel.Size = UDim2.new(1, 0, 0, 18)
		valueLabel.Position = UDim2.new(0, 0, 0, 68)
		valueLabel.Visible = totalValue > 0
		valueLabel.Parent = toastFrame

		local duration = isFresh and 7 or 4
		local fadeIn = TweenService:Create(
			toastFrame,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.08 }
		)
		fadeIn:Play()

		local function fadeText(label, target)
			if label and label:IsA("TextLabel") then
				TweenService:Create(
					label,
					TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ TextTransparency = target }
				):Play()
			end
		end

		fadeText(title, 0)
		fadeText(body, 0)
		if valueLabel.Visible then
			fadeText(valueLabel, 0)
		end

		local glowTween
		if isFresh then
			glowTween = TweenService:Create(
				stroke,
				TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.1 }
			)
			glowTween:Play()
		end

		task.delay(duration, function()
			if glowTween then
				glowTween:Cancel()
			end

			local fadeOut = TweenService:Create(
				toastFrame,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }
			)
			fadeOut:Play()

			fadeText(title, 1)
			fadeText(body, 1)
			if valueLabel.Visible then
				fadeText(valueLabel, 1)
			end

			fadeOut.Completed:Connect(function()
				toastFrame:Destroy()
			end)
		end)
	end

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

		if payload.type == "WeeklyWinner" then
			playWeeklyChampionToast(payload)
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
	local function setPrestigeOverlayBlocking(overlay, shouldBlock)
		if not overlay then
			return
		end

		overlay.Active = shouldBlock

		local blocker = overlay:FindFirstChild("Blocker")
		if not (blocker and blocker:IsA("TextButton")) then
			if not shouldBlock then
				return
			end

			blocker = Instance.new("TextButton")
			blocker.Name = "Blocker"
			blocker.Parent = overlay
		end

		blocker.Size = UDim2.fromScale(1, 1)
		blocker.Position = UDim2.fromScale(0, 0)
		blocker.BackgroundTransparency = 1
		blocker.Text = ""
		blocker.AutoButtonColor = false
		blocker.Active = shouldBlock
		blocker.Selectable = false
		blocker.ZIndex = (overlay.ZIndex or 0) + 1
	end
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
	local AutomationConfig = require(sharedFolder:WaitForChild("AutomationConfig"))
	local AutomationConstants = require(sharedFolder:WaitForChild("AutomationConstants"))

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

local NUMBER_TWEEN_DURATION = 0.25
local NUMBER_TWEEN_STEP = 0.03
local activeNumberTweens = {}
local labelCurrentValues = {}
local labelTargetValues = {}
local numberTweenConnection = nil
local numberTweenAccumulator = 0

local function cloneNumericValue(value)
	if typeof(value) == "table" then
		local copy = {}
		for key, component in pairs(value) do
			if typeof(component) == "number" then
				copy[key] = component
			end
		end
		return copy
	elseif typeof(value) == "number" then
		return value
	end
	return nil
end

local function valuesEqual(left, right)
	if typeof(left) ~= typeof(right) then
		return false
	end

	if typeof(left) == "table" then
		for key, value in pairs(left) do
			local other = right[key]
			if typeof(value) == "number" and typeof(other) == "number" then
				if math.abs(value - other) > 1e-4 then
					return false
				end
			elseif typeof(value) == "number" or typeof(other) == "number" then
				return false
			end
		end
		for key in pairs(right) do
			if left[key] == nil then
				return false
			end
		end
		return true
	elseif typeof(left) == "number" then
		return math.abs(left - right) <= 1e-4
	end

	return left == right
end

local function blendNumericValue(startValue, targetValue, alpha)
	if typeof(targetValue) == "table" then
		local blended = {}
		for key, targetComponent in pairs(targetValue) do
			if typeof(targetComponent) == "number" then
				local startComponent = 0
				if typeof(startValue) == "table" and typeof(startValue[key]) == "number" then
					startComponent = startValue[key]
				else
					startComponent = targetComponent
				end
				blended[key] = startComponent + (targetComponent - startComponent) * alpha
			end
		end
		return blended
	elseif typeof(targetValue) == "number" then
		local startNumber = typeof(startValue) == "number" and startValue or targetValue
		return startNumber + (targetValue - startNumber) * alpha
	end

	return targetValue
end

local function applyFormattedValue(formatFn, value)
	local ok, err = pcall(formatFn, value)
	if not ok then
		warn("[TerminalClient] Failed to update stat text:", err)
	end
end

local function stepNumberTweens(dt)
	numberTweenAccumulator += dt
	if numberTweenAccumulator < NUMBER_TWEEN_STEP then
		return
	end
	numberTweenAccumulator -= NUMBER_TWEEN_STEP

	local now = os.clock()
	for label, tween in pairs(activeNumberTweens) do
		local alpha = math.clamp((now - tween.startTime) / NUMBER_TWEEN_DURATION, 0, 1)
		local blended = blendNumericValue(tween.startValue, tween.targetValue, alpha)
		labelCurrentValues[label] = cloneNumericValue(blended) or blended
		applyFormattedValue(tween.formatFn, blended)

		if alpha >= 1 then
			labelCurrentValues[label] = cloneNumericValue(tween.targetValue) or tween.targetValue
			activeNumberTweens[label] = nil
		end
	end

	if not next(activeNumberTweens) and numberTweenConnection then
		numberTweenConnection:Disconnect()
		numberTweenConnection = nil
	end
end

local function ensureNumberTweenConnection()
	if numberTweenConnection then
		return
	end
	numberTweenAccumulator = 0
	numberTweenConnection = RunService.Heartbeat:Connect(stepNumberTweens)
end

local function tweenNumber(label, targetValue, formatFn)
	if not label or typeof(formatFn) ~= "function" then
		return
	end

	if typeof(targetValue) ~= "number" and typeof(targetValue) ~= "table" then
		formatFn(targetValue)
		return
	end

	local normalizedTarget = cloneNumericValue(targetValue) or targetValue
	local lastTarget = labelTargetValues[label]
	if lastTarget and valuesEqual(lastTarget, normalizedTarget) then
		return
	end

	local currentValue = labelCurrentValues[label]
	if not currentValue then
		labelCurrentValues[label] = cloneNumericValue(normalizedTarget) or normalizedTarget
		labelTargetValues[label] = cloneNumericValue(normalizedTarget) or normalizedTarget
		applyFormattedValue(formatFn, targetValue)
		return
	end

	activeNumberTweens[label] = {
		startValue = cloneNumericValue(currentValue) or currentValue,
		targetValue = cloneNumericValue(normalizedTarget) or normalizedTarget,
		startTime = os.clock(),
		formatFn = formatFn,
	}
	labelTargetValues[label] = cloneNumericValue(normalizedTarget) or normalizedTarget
	ensureNumberTweenConnection()
end

	local playerState = {
		data = 0,
		upgrades = {},
		prestige = 0,
		corePower = 0,
	}
	local autoBuyContext = {
		autoBuyPresetButtons = {},
		presetButtonCooldowns = {},
		playerState = playerState,
		automationAttributesById = automationAttributesById,
		autoPresetCount = AUTO_PRESET_COUNT,
		storageLagDelta = STORAGE_LAG_DELTA,
		recommendationBucketSize = RECOMMENDATION_BUCKET_SIZE,
		showToast = showToast,
		autoBuyPresetApplyEvent = autoBuyPresetApplyEvent,
		autoBuyPresetSaveEvent = autoBuyPresetSaveEvent,
		requestAutoBuyPresets = requestAutoBuyPresets,
		autoBuyAutoSwitchSettingsEvent = autoBuyAutoSwitchSettingsEvent,
		safeFind = safeFind,
		waitForChildWithTimeout = waitForChildWithTimeout,
		rightPanel = rightPanel,
		autoBuyPresetsFrame = rightPanel and safeFind(rightPanel, "AutoBuyPresets"),
		MarketplaceService = MarketplaceService,
		player = player,
		AutomationConstants = AutomationConstants,
		triggerHaptic = triggerHaptic,
		autoSwitchEnabled = false,
		autoSwitchPresetIndex = 1,
		autoSwitchMaxPresetIndex = AUTO_PRESET_COUNT,
		autoSwitchToggleButton = nil,
		autoSwitchPresetButton = nil,
		autoBuyPresetSaveButton = nil,
		currentPresetSettings = nil,
		activePresetIndex = nil,
		lastPresetIndex = 1,
		recommendedPresetIndex = nil,
		lastRecommendationContext = nil,
		pendingPresetSaveToast = false,
		preset4GamepassId = AutomationConstants.GamepassIdPreset4,
	}
	autoBuyContext.handlePresetApply = function(index)
		handlePresetApply(autoBuyContext, index)
	end
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
			setPrestigeOverlayBlocking(prestigeOverlay, not canPrestige)
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
	if autoBuyStateEvent then
		autoBuyStateEvent.OnClientEvent:Connect(function(state)
			if autoBuyController then
				autoBuyController.ApplyState(state)
			else
				pendingAutoBuyState = state
			end
		end)
	end
	if autoBuyController and pendingAutoBuyState then
		autoBuyController.ApplyState(pendingAutoBuyState)
		pendingAutoBuyState = nil
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

	local AUTO_PRESET_COUNT = AutomationConfig.GetPresetSlotCount()
	local automationAttributesById = {}
	for _, automationDefinition in ipairs(AutomationConfig.GetAll()) do
		if
			typeof(automationDefinition) == "table"
			and typeof(automationDefinition.id) == "string"
			and typeof(automationDefinition.attribute) == "string"
		then
			automationAttributesById[automationDefinition.id] = automationDefinition.attribute
		end
	end
	local STORAGE_LAG_DELTA = 5
	local RECOMMENDATION_BUCKET_SIZE = 5




	initAutoBuyPresetUI(autoBuyContext)
	if autoBuyPresetStateEvent then
		autoBuyPresetStateEvent.OnClientEvent:Connect(function(payload)
			handleAutoBuyPresetState(autoBuyContext, payload)
		end)
	end
	if autoBuyPresetUnlockPromptEvent then
		autoBuyPresetUnlockPromptEvent.OnClientEvent:Connect(function()
			promptPresetUnlock(autoBuyContext)
		end)
	end
	requestAutoBuyPresetState(autoBuyContext)
	updateAutoBuyRecommendation(autoBuyContext, true)

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
		updateAutoBuyRecommendation(autoBuyContext)
	end

	local function syncState()
		if not requestSync then
			requestSync = resolveRequestSync()
		end
		if not requestSync then
			return false
		end

		local payload
		local ok, err = pcall(function()
			payload = requestSync:InvokeServer()
		end)

		if not ok then
			warn("[TerminalClient] RequestSync failed", err)
			return false
		end

		if typeof(payload) ~= "table" then
			warn("[TerminalClient] Invalid sync payload")
			return false
		end

		applyState(payload)
		return true
	end

	if PurchaseHandlerBinder then
		PurchaseHandlerBinder.Init({
			purchaseUpgradeEvent = purchaseUpgradeEvent,
			triggerHaptic = triggerHaptic,
			PURCHASE_SETTINGS = PURCHASE_SETTINGS,
			syncState = syncState,
		})
		PurchaseHandlerBinder.Attach(nil, remotesFolder)
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
				if PurchaseHandlerBinder and typeof(PurchaseHandlerBinder.Bind) == "function" then
					PurchaseHandlerBinder.Bind(button, definition.id)
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

	if SyncLoopBinder then
		SyncLoopBinder.Init({
			syncState = syncState,
			resolveRequestSync = resolveRequestSync,
			warn = function(...) warn(...) end,
		})
	end

	buildUpgradeCards()
	setLoadingStep("Initializing Terminal UI", 0.9)
	ensureUiUpdateLoop()
	syncState()
	if SyncLoopBinder and typeof(SyncLoopBinder.Start) == "function" then
		SyncLoopBinder.Start()
	end

	if prestigeButton then
		prestigeButton.MouseButton1Click:Connect(function()
			if not prestigeEvent then
				return
			end
			prestigeEvent:FireServer()
			task.defer(function()
				syncState()
			end)
		end)
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
