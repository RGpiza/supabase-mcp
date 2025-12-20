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
	local UserInputService = game:GetService("UserInputService")
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- Module requires moved to top-level to reduce locals inside Init
local PurchaseHandlerBinder = nil
local SyncLoopBinder = nil
local SyncState = nil
local SyncPoller = nil
do
	local modulesFolder = script.Parent and script.Parent:FindFirstChild("Modules")
	if modulesFolder then
		pcall(function()
			PurchaseHandlerBinder = require(modulesFolder:FindFirstChild("PurchaseHandlerBinder"))
		end)
		pcall(function()
			SyncLoopBinder = require(modulesFolder:FindFirstChild("SyncLoopBinder"))
		end)
		pcall(function()
			SyncState = require(modulesFolder:FindFirstChild("SyncState"))
		end)
		pcall(function()
			SyncPoller = require(modulesFolder:FindFirstChild("SyncPoller"))
		end)
	end
end

local function CreateWeeklyRewardsUI(parent)
	if not parent then
		return nil
	end

	local existing = parent:FindFirstChild("WeeklyRewardsPanel")
	if existing then
		existing.Visible = true
		return existing
	end

	local panel = Instance.new("Frame")
	panel.Name = "WeeklyRewardsPanel"
	panel.Parent = parent
	panel.Size = UDim2.new(1, -12, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = true
	panel.LayoutOrder = 4

	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

	local stroke = Instance.new("UIStroke", panel)
	stroke.Color = Color3.fromRGB(70, 90, 110)
	stroke.Transparency = 0.4

	local padding = Instance.new("UIPadding", panel)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)

	local layout = Instance.new("UIListLayout", panel)
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Parent = panel
	header.BackgroundTransparency = 1
	header.Text = "WEEKLY REWARDS"
	header.Font = Enum.Font.GothamBold
	header.TextSize = 16
	header.TextColor3 = Color3.fromRGB(225, 235, 255)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Size = UDim2.new(1, 0, 0, 22)
	header.LayoutOrder = 1

	local tiers = {
		{ label = "Top 1%", reward = "+25% Boost" },
		{ label = "Top 5%", reward = "+15% Boost" },
		{ label = "Top 10%", reward = "+10% Boost" },
	}

	for i, tier in ipairs(tiers) do
		local row = Instance.new("Frame")
		row.Parent = panel
		row.Size = UDim2.new(1, 0, 0, 52)
		row.BackgroundColor3 = Color3.fromRGB(20, 25, 36)
		row.BackgroundTransparency = 0.1
		row.BorderSizePixel = 0
		row.LayoutOrder = i + 1

		local tierDef = WEEKLY_REWARD_DEFINITIONS[i]
		if tierDef and tierDef.tier then
			row.Name = tierDef.tier .. "Row"
		end

		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

		local rowPadding = Instance.new("UIPadding", row)
		rowPadding.PaddingLeft = UDim.new(0, 10)
		rowPadding.PaddingRight = UDim.new(0, 10)
		rowPadding.PaddingTop = UDim.new(0, 6)
		rowPadding.PaddingBottom = UDim.new(0, 6)

		local title = Instance.new("TextLabel")
		title.Parent = row
		title.BackgroundTransparency = 1
		title.Text = tier.label
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextColor3 = Color3.fromRGB(220, 230, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Size = UDim2.new(1, -120, 0, 20)

		local reward = Instance.new("TextLabel")
		reward.Parent = row
		reward.BackgroundTransparency = 1
		reward.Text = tier.reward
		reward.Font = Enum.Font.Gotham
		reward.TextSize = 13
		reward.TextColor3 = Color3.fromRGB(200, 215, 235)
		reward.TextXAlignment = Enum.TextXAlignment.Left
		reward.Position = UDim2.new(0, 0, 0, 22)
		reward.Size = UDim2.new(1, -120, 0, 18)

		local status = Instance.new("TextLabel")
		status.Name = "Status"
		status.Parent = row
		status.BackgroundTransparency = 1
		status.Text = "Currently Qualified"
		status.Font = Enum.Font.GothamBold
		status.TextSize = 12
		status.TextColor3 = Color3.fromRGB(235, 240, 255)
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.Size = UDim2.new(0, 110, 0, 18)
		status.Position = UDim2.new(1, -110, 0, 8)
		status.Visible = false
	end

	local footer = Instance.new("TextLabel")
	footer.Name = "Countdown"
	footer.Parent = panel
	footer.BackgroundTransparency = 1
	footer.Text = "Resets in: --"
	footer.Font = Enum.Font.Gotham
	footer.TextSize = 13
	footer.TextColor3 = Color3.fromRGB(200, 210, 230)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.Size = UDim2.new(1, 0, 0, 18)
	footer.LayoutOrder = 99

	return panel
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
				statsPageFrame = pages
				return statsPageFrame
			end
		end
		return statsPageFrame
	end

	local function getWeeklyRewardsParent()
		local pages = rightPanel and (safeFind and safeFind(rightPanel, "Pages") or rightPanel:FindFirstChild("Pages"))
		return pages or resolveStatsPage() or (statsBox and statsBox.Parent) or rightPanel
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
			weeklyRewardsPanel = CreateWeeklyRewardsUI(parent)
		end

		if not weeklyRewardsPanel or not weeklyRewardsPanel.Parent then
			return nil
		end

		weeklyRewardsPanel.Visible = true

		weeklyRewardRows = {}
		weeklyRewardsCountdownLabel = nil

		for _, definition in ipairs(WEEKLY_REWARD_DEFINITIONS) do
			local row = weeklyRewardsPanel:FindFirstChild(string.format("%sRow", definition.tier))
			if row and row:IsA("Frame") then
				local stroke = row:FindFirstChildOfClass("UIStroke")
				local statusLabel = row:FindFirstChild("Status")
				weeklyRewardRows[definition.tier] = {
					frame = row,
					stroke = stroke,
					statusLabel = statusLabel,
					baseColor = row.BackgroundColor3,
					highlightColor = WEEKLY_REWARD_HIGHLIGHT[definition.tier] or row.BackgroundColor3,
					accentColor = WEEKLY_REWARD_ACCENT[definition.tier] or Color3.fromRGB(235, 240, 255),
				}
			end
		end

		local countdown = weeklyRewardsPanel:FindFirstChild("Countdown")
		if countdown and countdown:IsA("TextLabel") then
			weeklyRewardsCountdownLabel = countdown
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
	if typeof(context.autoBuyPresetButtons) ~= "table" then
		return
	end
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
	if typeof(context.autoBuyPresetButtons) ~= "table" then
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

local function buildUpgradeCards(context)
	local template = context.template
	local upgradeCards = context.upgradeCards
	local cpuCards = context.cpuCards
	local ramCards = context.ramCards
	local stoCards = context.stoCards
	local upgradeConfig = context.upgradeConfig
	local purchaseHandlerBinder = context.purchaseHandlerBinder
	local yieldEvery = typeof(context.yieldEvery) == "number" and context.yieldEvery or 0
	local onBuilt = context.onBuilt

	local builtCount = 0
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
			if purchaseHandlerBinder and typeof(purchaseHandlerBinder.Bind) == "function" then
				purchaseHandlerBinder.Bind(button, definition.id)
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

	local function buildBranch(branchName, parentFolder)
		for _, definition in ipairs(upgradeConfig.GetUpgradesByBranch(branchName)) do
			createCard(definition, parentFolder)
			builtCount += 1
			if yieldEvery > 0 and builtCount % yieldEvery == 0 then
				task.wait()
			end
		end
	end

	buildBranch("CPU", cpuCards)
	buildBranch("RAM", ramCards)
	buildBranch("STORAGE", stoCards)

	if typeof(onBuilt) == "function" then
		onBuilt()
	end
end

local function startUiUpdateLoop(options)
	if not options then
		return
	end

	local getCachedState = options.getCachedState
	local applyStateToUI = options.applyStateToUI
	local isAlive = options.isAlive
	local uiUpdateStartedRef = options.uiUpdateStartedRef
	if not (getCachedState and applyStateToUI and uiUpdateStartedRef) then
		return
	end

	if uiUpdateStartedRef.value then
		return
	end
	uiUpdateStartedRef.value = true

	task.spawn(function()
		while task.wait(0.1) do
			if isAlive and not isAlive() then
				break
			end
			local state = getCachedState()
			if state then
				applyStateToUI(state)
			end
		end
		uiUpdateStartedRef.value = false
	end)
end

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

local function setupRuntimeSystems(args)
	if not args then
		return
	end

	local context = args.context
	local ui = args.ui
	local safeFind = args.safeFind
	local waitForChildWithTimeout = args.waitForChildWithTimeout
	local Players = args.Players
	local NumberFormatter = args.NumberFormatter
	local UserInputService = args.UserInputService
	local HapticService = args.HapticService
	local RunService = args.RunService
	local MarketplaceService = args.MarketplaceService
	local UpgradeConfig = args.UpgradeConfig
	local AutomationConfig = args.AutomationConfig
	local AutomationConstants = args.AutomationConstants
	local PurchaseHandlerBinder = args.PurchaseHandlerBinder
	local SyncLoopBinder = args.SyncLoopBinder
	local ToastController = args.ToastController
	local StoreUIController = args.StoreUIController
	local BoostUIController = args.BoostUIController
	local LeaderboardClient = args.LeaderboardClient
	local remotesFolder = args.remotesFolder
	local purchaseUpgradeEvent = args.purchaseUpgradeEvent
	local prestigeEvent = args.prestigeEvent
	local prestigePreviewEvent = args.prestigePreviewEvent
	local requestPrestigePreview = args.requestPrestigePreview
	local sessionBonusEvent = args.sessionBonusEvent
	local globalAnnouncementEvent = args.globalAnnouncementEvent
	local globalStatsEvent = args.globalStatsEvent
	local serverPowerEvent = args.serverPowerEvent
	local systemNotificationEvent = args.systemNotificationEvent
	local autoBuyPresetStateEvent = args.autoBuyPresetStateEvent
	local autoBuyPresetUnlockPromptEvent = args.autoBuyPresetUnlockPromptEvent
	local requestAutoBuyPresets = args.requestAutoBuyPresets
	local autoBuyStateEvent = args.autoBuyStateEvent
	local setAutoBuyEvent = args.setAutoBuyEvent
	local weeklyResetFunction = args.weeklyResetFunction
	local leaderboardFunction = args.leaderboardFunction
	local lifetimeLeaderboardFunction = args.lifetimeLeaderboardFunction
	local activationState = args.activationState
	local activationHook = args.activationHook
	local setLoadingStep = args.setLoadingStep
	local markLocalReady = args.markLocalReady

	local playerState = (context and context.playerState) or {}
	if context then
		context.playerState = playerState
	end
	if typeof(playerState.upgrades) ~= "table" then
		playerState.upgrades = {}
	end
	if typeof(playerState.data) ~= "number" then
		playerState.data = 0
	end
	if typeof(playerState.dps) ~= "number" then
		playerState.dps = 0
	end
	if typeof(playerState.prestige) ~= "number" then
		playerState.prestige = 0
	end
	if typeof(playerState.corePower) ~= "number" then
		playerState.corePower = 0
	end

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

	local cardsResolvedWarned = false
	local function resolveCardContainers()
		local screenGui = ui.screenGui
		if not columns and main then
			columns = safeFind(main, "Columns") or main:FindFirstChild("Columns", true)
		end
		if not columns and screenGui then
			columns = screenGui:FindFirstChild("Columns", true)
		end
		if not rightPanel and main then
			rightPanel = safeFind(main, "RightPanel") or main:FindFirstChild("RightPanel", true)
		end
		if not rightPanel and screenGui then
			rightPanel = screenGui:FindFirstChild("RightPanel", true)
		end
		if columns then
			cpuCards = cpuCards or columns:FindFirstChild("Cards_CPU", true)
			ramCards = ramCards or columns:FindFirstChild("Cards_RAM", true)
			stoCards = stoCards or columns:FindFirstChild("Cards_STORAGE", true)
		end
		if not cardsResolvedWarned and (not cpuCards or not ramCards or not stoCards) then
			cardsResolvedWarned = true
			warn("[TerminalClient] Upgrade card containers missing; upgrades may not appear")
		end
	end

	resolveCardContainers()

	local dataValueLabel = safeFind(topBar, "DataValue")
	if not dataValueLabel then
		warn("[TerminalClient] DataValue missing")
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

		if not (tabs and pages and statsTab and leaderboardTab and leaderboardPage) then
			warn("[TerminalClient] Leaderboard tabs missing, skipping toggles")
			return
		end
		local statsFrames = {}
		if statsPage and statsPage:IsA("GuiObject") then
			statsFrames = { statsPage }
		else
			for _, child in ipairs(pages:GetChildren()) do
				if child:IsA("GuiObject") and child ~= leaderboardPage then
					table.insert(statsFrames, child)
				end
			end
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
			for _, frame in ipairs(statsFrames) do
				frame.Visible = showStats
			end
			leaderboardPage.Visible = not showStats
			local weeklyPanel = pages:FindFirstChild("WeeklyRewardsPanel", true)
				or rightPanel:FindFirstChild("WeeklyRewardsPanel", true)
			if weeklyPanel and weeklyPanel:IsA("GuiObject") then
				weeklyPanel.Visible = showStats
			end
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

		local listObject = page:FindFirstChild("List", true) or page:FindFirstChildWhichIsA("ScrollingFrame", true)
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
	local rawShowToast = toastController and toastController.ShowToast or function() end
	local function showToast(payload)
		if typeof(payload) == "table" then
			local title = tostring(payload.title or "")
			local body = tostring(payload.body or "")
			local message
			if title ~= "" and body ~= "" then
				message = string.format("%s: %s", title, body)
			else
				message = title ~= "" and title or body
			end
			if message ~= "" then
				rawShowToast(message)
			end
			return
		end
		local message = tostring(payload or "")
		if message ~= "" then
			rawShowToast(message)
		end
	end
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
		sessionBonusProgressLabel.Text = string.format("%s / %s", formatSessionTime(elapsedSeconds), formatSessionTime(targetSeconds))
	end

	local function handleSessionBonusUpdate(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local elapsed = tonumber(payload.elapsedSeconds) or 0
		local target = tonumber(payload.targetSeconds) or sessionBonusTargetSeconds
		sessionBonusTargetSeconds = target
		updateSessionBonusUI(elapsed, target)

		local activatedRewards = payload.activatedRewards
		if activatedRewards and typeof(activatedRewards) == "table" and showToast then
			for _, rewardId in ipairs(activatedRewards) do
				showToast({
					title = "Session Bonus",
					body = string.format("Reward %s activated!", tostring(rewardId)),
					duration = 3,
				})
			end
		end
	end

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
		panel.Size = UDim2.new(1, -10, 0, 80)
		panel.Position = UDim2.new(0, 5, 0, 0)
		panel.AnchorPoint = Vector2.new(0, 0)
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
		title.Size = UDim2.new(1, 0, 0, 18)

		local dataLabel = panel:FindFirstChild("GlobalStatsDataLabel")
		if not (dataLabel and dataLabel:IsA("TextLabel")) then
			dataLabel = Instance.new("TextLabel")
			dataLabel.Name = "GlobalStatsDataLabel"
			dataLabel.Parent = panel
		end
		dataLabel.BackgroundTransparency = 1
		dataLabel.Font = Enum.Font.GothamSemibold
		dataLabel.TextSize = 12
		dataLabel.TextXAlignment = Enum.TextXAlignment.Left
		dataLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
		dataLabel.Position = UDim2.new(0, 0, 0, 22)
		dataLabel.Size = UDim2.new(1, 0, 0, 16)
		dataLabel.Text = "Data Generated"

		local dataValue = panel:FindFirstChild("GlobalStatsDataValue")
		if not (dataValue and dataValue:IsA("TextLabel")) then
			dataValue = Instance.new("TextLabel")
			dataValue.Name = "GlobalStatsDataValue"
			dataValue.Parent = panel
		end
		dataValue.BackgroundTransparency = 1
		dataValue.Font = Enum.Font.GothamBold
		dataValue.TextSize = 16
		dataValue.TextXAlignment = Enum.TextXAlignment.Left
		dataValue.TextColor3 = Color3.fromRGB(255, 255, 255)
		dataValue.Position = UDim2.new(0, 0, 0, 36)
		dataValue.Size = UDim2.new(1, 0, 0, 20)

		local prestigeLabel = panel:FindFirstChild("GlobalStatsPrestigeLabel")
		if not (prestigeLabel and prestigeLabel:IsA("TextLabel")) then
			prestigeLabel = Instance.new("TextLabel")
			prestigeLabel.Name = "GlobalStatsPrestigeLabel"
			prestigeLabel.Parent = panel
		end
		prestigeLabel.BackgroundTransparency = 1
		prestigeLabel.Font = Enum.Font.GothamSemibold
		prestigeLabel.TextSize = 12
		prestigeLabel.TextXAlignment = Enum.TextXAlignment.Right
		prestigeLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
		prestigeLabel.Position = UDim2.new(1, -140, 0, 22)
		prestigeLabel.Size = UDim2.new(0, 140, 0, 16)
		prestigeLabel.Text = "Prestiges"

		local prestigeValue = panel:FindFirstChild("GlobalStatsPrestigeValue")
		if not (prestigeValue and prestigeValue:IsA("TextLabel")) then
			prestigeValue = Instance.new("TextLabel")
			prestigeValue.Name = "GlobalStatsPrestigeValue"
			prestigeValue.Parent = panel
		end
		prestigeValue.BackgroundTransparency = 1
		prestigeValue.Font = Enum.Font.GothamBold
		prestigeValue.TextSize = 16
		prestigeValue.TextXAlignment = Enum.TextXAlignment.Right
		prestigeValue.TextColor3 = Color3.fromRGB(255, 255, 255)
		prestigeValue.Position = UDim2.new(1, -140, 0, 36)
		prestigeValue.Size = UDim2.new(0, 140, 0, 20)

		globalStatsPanel = panel
		globalStatsDataValue = dataValue
		globalStatsPrestigeValue = prestigeValue
	end

	local function updateGlobalStatsUI(totalData, totalPrestiges)
		ensureGlobalStatsUI()
		if not (globalStatsDataValue and globalStatsPrestigeValue) then
			return
		end
		local formatter = NumberFormatter
		if formatter and typeof(formatter.format) == "function" then
			globalStatsDataValue.Text = formatter.format(totalData or 0)
			globalStatsPrestigeValue.Text = formatter.format(totalPrestiges or 0)
		else
			globalStatsDataValue.Text = tostring(totalData or 0)
			globalStatsPrestigeValue.Text = tostring(totalPrestiges or 0)
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
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.BorderSizePixel = 0
		panel.LayoutOrder = 0
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

		local label = panel:FindFirstChild("ServerPowerValue")
		if not (label and label:IsA("TextLabel")) then
			label = Instance.new("TextLabel")
			label.Name = "ServerPowerValue"
			label.Parent = panel
		end
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamSemibold
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Position = UDim2.new(0, 0, 0, 24)
		label.Size = UDim2.new(1, 0, 0, 22)

		serverPowerPanel = panel
		serverPowerLabel = label
	end

	local function updateServerPowerUI(multiplier, playerCount)
		ensureServerPowerUI()
		if not serverPowerLabel then
			return
		end
		local percent = math.floor(((multiplier or 1) - 1) * 100 + 0.5)
		serverPowerLabel.Text = string.format("+%d%% (%d players)", percent, playerCount or 0)
	end

	local function handleServerPowerUpdate(payload)
		if typeof(payload) ~= "table" then
			return
		end
		updateServerPowerUI(payload.multiplier, payload.playerCount)
	end

	local function handleGlobalAnnouncement(payload)
		if typeof(payload) ~= "table" then
			return
		end
		showToast({
			title = tostring(payload.title or "Announcement"),
			body = tostring(payload.body or ""),
			duration = tonumber(payload.duration) or 4,
		})
	end

	local function handleSystemNotification(payload)
		if typeof(payload) == "string" then
			showToast({
				title = "SYSTEM",
				body = payload,
				duration = 3,
			})
			return
		end
		if typeof(payload) ~= "table" then
			return
		end
		showToast({
			title = tostring(payload.title or "SYSTEM"),
			body = tostring(payload.body or ""),
			duration = tonumber(payload.duration) or 3,
		})
	end

	local function setPreviewPending()
		if not prestigeBox then
			return
		end
		local header = safeFind(prestigeBox, "PrestigeHeader")
		if header then
			header.Text = "PRESTIGE"
		end
		local overlay = safeFind(prestigeBox, "PrestigeLockedOverlay")
		local subtext = overlay and safeFind(overlay, "Subtext")
		local body = overlay and safeFind(overlay, "Body")
		if subtext then
			subtext.Text = "Checking unlock..."
		end
		if body then
			body.Text = "Fetching preview details"
		end
	end

	local function updatePreviewText(payload)
		if not prestigeBox then
			return
		end
		local overlay = safeFind(prestigeBox, "PrestigeLockedOverlay")
		if not overlay then
			return
		end

		local canPrestige = payload.canPrestige == true
		local nextMultiplier = typeof(payload.nextMultiplier) == "number" and payload.nextMultiplier or 0
		local multiplierGain = typeof(payload.multiplierGain) == "number" and payload.multiplierGain or 0

		local header = safeFind(prestigeBox, "PrestigeHeader")
		local subtext = safeFind(overlay, "Subtext")
		local body = safeFind(overlay, "Body")
		if header then
			header.Text = "PRESTIGE"
		end
		if subtext then
			if canPrestige then
				subtext.Text = "If you prestiged now:"
			else
				local requirement = NumberFormatter.format(payload.unlockRequirement or 0)
				subtext.Text = string.format("Unlocks at %s Data", requirement)
			end
		end
		if body then
			if canPrestige then
				local gainText = multiplierGain
				if gainText <= 0 then
					gainText = nextMultiplier - 1
				end
				body.Text = string.format("+%0.2fx Permanent Power", gainText)
			else
				local current = NumberFormatter.format(payload.currentData or 0)
				body.Text = string.format("Currently: %s Data", current)
			end
		end
	end

	local autoBuyContext = {
		context = context,
		safeFind = safeFind,
		waitForChildWithTimeout = waitForChildWithTimeout,
		autoBuyPresetApplyEvent = args.autoBuyPresetApplyEvent,
		autoBuyPresetSaveEvent = args.autoBuyPresetSaveEvent,
		autoBuyPresetStateEvent = autoBuyPresetStateEvent,
		requestAutoBuyPresets = requestAutoBuyPresets,
		autoBuyPresetUnlockPromptEvent = autoBuyPresetUnlockPromptEvent,
		autoBuyAutoSwitchSettingsEvent = args.autoBuyAutoSwitchSettingsEvent,
		setAutoBuyEvent = setAutoBuyEvent,
		autoBuyStateEvent = autoBuyStateEvent,
		rightPanel = rightPanel,
		autoBuyPresetsFrame = rightPanel and safeFind(rightPanel, "AutoBuyPresets"),
		tabs = rightPanel and safeFind(rightPanel, "Tabs"),
		pages = rightPanel and safeFind(rightPanel, "Pages"),
		statsBox = statsBox,
		prestigeBox = prestigeBox,
		columns = columns,
		cpuCards = cpuCards,
		ramCards = ramCards,
		stoCards = stoCards,
		PURCHASE_SETTINGS = PURCHASE_SETTINGS,
		UpgradeConfig = UpgradeConfig,
		AutomationConfig = AutomationConfig,
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
	local cachedStateRef = { value = nil }
	local uiUpdateStartedRef = { value = false }
	local displayedDataRef = { value = nil }

	local upgradeCards = {}
	local upgradeCardsBuildStarted = false
	local upgradeCardsTemplateWarned = false
	local upgradeCardsRetryCount = 0
	local coreSystemsStarted = false
	local syncLoopStarted = false
	local syncLoopWarningIssued = false

	local function resolveUpgradeTemplate()
		if args.template and args.template.Parent then
			return args.template
		end
		local playerGui = context and context.playerGui
		if playerGui then
			return playerGui:FindFirstChild("UpgradeCardTemplate")
				or playerGui:FindFirstChild("UpgradeCardTemplate", true)
		end
		return nil
	end

	local function buildUpgradeCardsAsync()
		if upgradeCardsBuildStarted then
			return
		end
		task.spawn(function()
			local template = resolveUpgradeTemplate()
			local attempts = 0
			while not template and attempts < 5 do
				attempts += 1
				task.wait(0.2)
				template = resolveUpgradeTemplate()
			end
			if not template then
				if not upgradeCardsTemplateWarned then
					upgradeCardsTemplateWarned = true
					warn("[TerminalClient] UpgradeCardTemplate missing; upgrade cards not built")
				end
				upgradeCardsBuildStarted = false
				if upgradeCardsRetryCount < 3 then
					upgradeCardsRetryCount += 1
					task.delay(1, buildUpgradeCardsAsync)
				end
				return
			end
			upgradeCardsBuildStarted = true
			resolveCardContainers()
			buildUpgradeCards({
				template = template,
				upgradeCards = upgradeCards,
				cpuCards = cpuCards,
				ramCards = ramCards,
				stoCards = stoCards,
				upgradeConfig = UpgradeConfig,
				purchaseHandlerBinder = PurchaseHandlerBinder,
				yieldEvery = 6,
				onBuilt = refreshAllCards,
			})
		end)
	end

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

	local function setPrestigeOverlayBlocking(overlay, blocked)
		if not (overlay and overlay:IsA("GuiObject")) then
			return
		end
		overlay.Active = blocked == true
		local blocker = overlay:FindFirstChild("Blocker")
		if blocker and blocker:IsA("GuiButton") then
			blocker.Active = blocked == true
			blocker.Visible = blocked == true
		end
	end

	local function setPrestigeState(canPrestige)
		if prestigeBox then
			local prestigeButton = safeFind(prestigeBox, "PrestigeButton")
			if prestigeButton then
				prestigeButton.Active = canPrestige
				prestigeButton.Text = canPrestige and "PRESTIGE" or "LOCKED"
			end
			local prestigeOverlay = safeFind(prestigeBox, "PrestigeLockedOverlay")
			if prestigeOverlay then
				prestigeOverlay.Visible = not canPrestige
				setPrestigeOverlayBlocking(prestigeOverlay, not canPrestige)
			end
		end
	end

	local lastPreviewPayload = nil
	local pendingPrestigePreviewPayloads = {}
	local prestigePreviewHandler

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

	setPreviewPending()

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
	end
	updateGlobalStatsUI(0, 0)
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

	updateGlobalStatsUI(0, 0)

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

		if not (UpgradeConfig and typeof(UpgradeConfig.GetUpgradeCost) == "function") then
			return
		end
		if not (UpgradeConfig and typeof(UpgradeConfig.MeetsUpgradeRequirements) == "function") then
			return
		end

		local level = getUpgradeLevel(upgradeId)
		local nextCost, atMax = UpgradeConfig.GetUpgradeCost(upgradeId, level + 1)
		local canAfford = playerState.data >= (nextCost or math.huge)
		local meetsRequirements = UpgradeConfig.MeetsUpgradeRequirements(playerState.upgrades, upgradeId)
		local hasCost = typeof(nextCost) == "number"

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

	local syncState = SyncPoller and SyncPoller.RunOnce or nil
	local UpgradeBinder
	local GlobalStatsBinder

	do
		local modulesFolder = script.Parent and script.Parent:FindFirstChild("Modules")
		if modulesFolder then
			local upgradeModule = modulesFolder:FindFirstChild("UpgradeBinder")
			if upgradeModule then
				local ok, mod = pcall(function()
					return require(upgradeModule)
				end)
				if ok then
					UpgradeBinder = mod
				end
			end
			local globalStatsModule = modulesFolder:FindFirstChild("GlobalStatsBinder")
			if globalStatsModule then
				local ok, mod = pcall(function()
					return require(globalStatsModule)
				end)
				if ok then
					GlobalStatsBinder = mod
				end
			end
		end
	end
	if type(UpgradeBinder) ~= "table" then
		UpgradeBinder = {
			Init = function(_payload)
				buildUpgradeCardsAsync()
			end,
		}
	end
	if type(GlobalStatsBinder) ~= "table" then
		GlobalStatsBinder = {
			Start = function(_payload)
				updateGlobalStatsUI(0, 0)
			end,
		}
	end
	if type(UpgradeBinder.SetContext) == "function" then
		UpgradeBinder.SetContext({
			buildUpgradeCardsAsync = buildUpgradeCardsAsync,
			refreshAllCards = refreshAllCards,
			purchaseHandlerBinder = PurchaseHandlerBinder,
		})
	end
	if type(GlobalStatsBinder.SetContext) == "function" then
		GlobalStatsBinder.SetContext({
			updateGlobalStatsUI = updateGlobalStatsUI,
			globalStatsEvent = globalStatsEvent,
		})
	end

	if SyncState then
		local applyContext = SyncState.applyContext or {}
		applyContext.playerState = playerState
		applyContext.cachedStateRef = cachedStateRef
		applyContext.displayedDataRef = displayedDataRef
		applyContext.refreshAllCards = refreshAllCards
		applyContext.updateAutoBuyRecommendation = updateAutoBuyRecommendation
		applyContext.autoBuyContext = autoBuyContext
		applyContext.rebindUpgrades = function(payload)
			if UpgradeBinder and type(UpgradeBinder.Init) == "function" then
				UpgradeBinder.Init(payload)
			end
		end
		applyContext.activateCoreSystems = function(payload)
			if coreSystemsStarted then
				return
			end
			local upgradeOk = false
			local globalStatsOk = false
			if UpgradeBinder and type(UpgradeBinder.Init) == "function" then
				upgradeOk = UpgradeBinder.Init(payload) ~= false
			else
				warn("[TerminalClient] UpgradeBinder.Init missing")
			end
			if GlobalStatsBinder and type(GlobalStatsBinder.Start) == "function" then
				globalStatsOk = GlobalStatsBinder.Start(payload) ~= false
			else
				warn("[TerminalClient] GlobalStatsBinder.Start missing")
			end
			if not (upgradeOk and globalStatsOk) then
				return
			end
			coreSystemsStarted = true
			activationState.coreSystemsStarted = true
		end
		SyncState.applyContext = applyContext
	end

	local function hasValidSyncState()
		return typeof(cachedStateRef.value) == "table"
	end

	local function startCoreSystems()
		if coreSystemsStarted then
			return true
		end
		if syncState then
			syncState()
		end
		if not hasValidSyncState() then
			return false
		end
		local payload = cachedStateRef.value
		local upgradeOk = false
		local globalStatsOk = false
		if UpgradeBinder and type(UpgradeBinder.Init) == "function" then
			upgradeOk = UpgradeBinder.Init(payload) ~= false
		else
			warn("[TerminalClient] UpgradeBinder.Init missing")
		end
		if GlobalStatsBinder and type(GlobalStatsBinder.Start) == "function" then
			globalStatsOk = GlobalStatsBinder.Start(payload) ~= false
		else
			warn("[TerminalClient] GlobalStatsBinder.Start missing")
		end
		if not (upgradeOk and globalStatsOk) then
			return false
		end
		coreSystemsStarted = true
		activationState.coreSystemsStarted = true
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

	if SyncLoopBinder then
		SyncLoopBinder.Init({
			syncState = syncState,
			resolveRequestSync = SyncState and SyncState.resolveRequestSync or nil,
			warn = function(...) warn(...) end,
		})
	end

	if SyncState then
		SyncState.onFirstPayload = function(payload)
			if coreSystemsStarted then
				return
			end
			local upgradeOk = false
			local globalStatsOk = false
			if UpgradeBinder and type(UpgradeBinder.Init) == "function" then
				upgradeOk = UpgradeBinder.Init(payload) ~= false
			else
				warn("[TerminalClient] UpgradeBinder.Init missing")
			end
			if GlobalStatsBinder and type(GlobalStatsBinder.Start) == "function" then
				globalStatsOk = GlobalStatsBinder.Start(payload) ~= false
			else
				warn("[TerminalClient] GlobalStatsBinder.Start missing")
			end
			if not (upgradeOk and globalStatsOk) then
				return
			end
			coreSystemsStarted = true
			activationState.coreSystemsStarted = true
		end
	end

	startCoreSystems()
	activationHook.ensureCoreSystems = startCoreSystems

	local function finalizeActivation()
		if activationState.completed then
			return
		end
		activationState.completed = true
		if setLoadingStep then
			setLoadingStep("Initializing Terminal UI", 0.9)
		end
		startUiUpdateLoop({
			getCachedState = function()
				return cachedStateRef.value
			end,
			applyStateToUI = applyStateToUI,
			isAlive = function()
				return script.Parent ~= nil
			end,
			uiUpdateStartedRef = uiUpdateStartedRef,
		})
		syncState()
		if SyncLoopBinder and typeof(SyncLoopBinder.Start) == "function" then
			SyncLoopBinder.Start()
		end
	end

	activationHook.activate = function()
		if activationState.completed then
			return
		end
		if startCoreSystems() then
			finalizeActivation()
			return
		end
		if activationState.activationRetry then
			return
		end
		activationState.activationRetry = true
		task.spawn(function()
			while not activationState.completed do
				if startCoreSystems() then
					finalizeActivation()
					break
				end
				task.wait(0.5)
			end
		end)
	end

	if activationState.requested and activationHook.activate then
		activationHook.activate()
	end

	if prestigeBox then
		local prestigeButton = safeFind(prestigeBox, "PrestigeButton")
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
	end

	RunService.RenderStepped:Connect(function(dt)
		if not dataValueLabel then
			return
		end

		local frameDt = typeof(dt) == "number" and dt or 0

		local targetData = 0
		if cachedStateRef.value and typeof(cachedStateRef.value.data) == "number" then
			targetData = cachedStateRef.value.data
		elseif typeof(playerState.data) == "number" then
			targetData = playerState.data
		end

		if displayedDataRef.value == nil then
			displayedDataRef.value = targetData
		end

		local snapThreshold = math.max(math.abs(targetData) * 0.05, 100)
		if math.abs(targetData - displayedDataRef.value) > snapThreshold then
			displayedDataRef.value = targetData
		else
			local alpha = 1 - math.exp(-frameDt * 10)
			displayedDataRef.value = displayedDataRef.value + (targetData - displayedDataRef.value) * alpha
		end

		local predictedDps = 0
		if cachedStateRef.value and typeof(cachedStateRef.value.dps) == "number" then
			predictedDps = cachedStateRef.value.dps
		end

		if predictedDps ~= 0 and frameDt > 0 then
			displayedDataRef.value += predictedDps * frameDt
		end

		local maxOvershoot = math.max(25, math.abs(targetData) * 0.01, math.abs(predictedDps) * 0.5)
		if displayedDataRef.value > targetData + maxOvershoot then
			displayedDataRef.value = targetData + maxOvershoot
		end
		if displayedDataRef.value < 0 then
			displayedDataRef.value = 0
		end

		dataValueLabel.Text = formatDataValueText(displayedDataRef.value)
	end)

	if markLocalReady then
		if activationState.coreSystemsStarted then
			markLocalReady()
		else
			task.spawn(function()
				local deadline = os.clock() + 10
				while os.clock() < deadline do
					if activationState.coreSystemsStarted then
						break
					end
					task.wait(0.2)
				end
				markLocalReady()
			end)
		end
	end
end


function LoadingInitializer.Init()
	local success, errorMessage = pcall(function()
	-- Services
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local MarketplaceService = game:GetService("MarketplaceService")
	local UserInputService = game:GetService("UserInputService")
	local HapticService = game:GetService("HapticService")
	local StarterGui = game:GetService("StarterGui")

	-- Modules
	local TerminalUIBinder = require(script.Parent:WaitForChild("TerminalUIBinder"))
	local ToastController = require(script.Parent:WaitForChild("ToastController"))
	local StoreUIController = require(script.Parent:WaitForChild("StoreUIController"))
	local BoostUIController = require(script.Parent:WaitForChild("BoostUIController"))
	local LeaderboardClient = require(script.Parent:WaitForChild("LeaderboardClient"))

	-- Player + ready state
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

	-- Helpers
	local function safeFind(parent, name)
		if not parent then
			return nil
		end
		return parent:FindFirstChild(name)
	end
	local terminalUiWarned = false
	local templateWarned = false

	local function ensureTerminalUi(playerGuiRef)
		if not playerGuiRef then
			return nil
		end

		local screenGui = playerGuiRef:FindFirstChild("TerminalUI")
		if not screenGui and StarterGui then
			local template = StarterGui:FindFirstChild("TerminalUI") or StarterGui:FindFirstChild("TerminalUI", true)
			if not template then
				template = ReplicatedStorage and (ReplicatedStorage:FindFirstChild("TerminalUI") or ReplicatedStorage:FindFirstChild("TerminalUI", true))
			end
			if template and template:IsA("LayerCollector") then
				screenGui = template:Clone()
				screenGui.ResetOnSpawn = false
				screenGui.Parent = playerGuiRef
			elseif template and template:IsA("Instance") then
				screenGui = template:Clone()
				screenGui.Parent = playerGuiRef
			end
		end

		if not screenGui then
			local descendant = playerGuiRef:FindFirstChild("TerminalUI", true)
			if descendant then
				screenGui = descendant
				screenGui.Parent = playerGuiRef
			end
		end

		if screenGui then
			if screenGui.Parent ~= playerGuiRef then
				screenGui.Parent = playerGuiRef
			end
			if screenGui:IsA("LayerCollector") then
				screenGui.Enabled = true
				screenGui.ResetOnSpawn = false
			end
			local root = screenGui:FindFirstChild("Root")
			if root and root:IsA("GuiObject") then
				root.Visible = true
			end
			return screenGui
		end

		if not terminalUiWarned then
			terminalUiWarned = true
			warn("[TerminalClient] TerminalUI template missing; UI may not render")
		end
		return nil
	end

	local function ensureUpgradeTemplate(playerGuiRef)
		if not playerGuiRef then
			return nil
		end

		local template = playerGuiRef:FindFirstChild("UpgradeCardTemplate")
		if not template then
			template = playerGuiRef:FindFirstChild("UpgradeCardTemplate", true)
		end
		if not template and StarterGui then
			local starterTemplate = StarterGui:FindFirstChild("UpgradeCardTemplate") or StarterGui:FindFirstChild("UpgradeCardTemplate", true)
			if not starterTemplate then
				starterTemplate = ReplicatedStorage and (ReplicatedStorage:FindFirstChild("UpgradeCardTemplate") or ReplicatedStorage:FindFirstChild("UpgradeCardTemplate", true))
			end
			if starterTemplate then
				template = starterTemplate:Clone()
				template.Parent = playerGuiRef
			end
		end
		if not template then
			local fallbackGui = playerGuiRef:FindFirstChild("UpgradesGui")
			if not (fallbackGui and fallbackGui:IsA("LayerCollector")) then
				fallbackGui = Instance.new("ScreenGui")
				fallbackGui.Name = "UpgradesGui"
				fallbackGui.ResetOnSpawn = false
				fallbackGui.Parent = playerGuiRef
			end

			fallbackGui.Enabled = true

			local fallbackRoot = fallbackGui:FindFirstChild("UpgradesRoot")
			if not (fallbackRoot and fallbackRoot:IsA("Frame")) then
				fallbackRoot = Instance.new("Frame")
				fallbackRoot.Name = "UpgradesRoot"
				fallbackRoot.Size = UDim2.new(1, 0, 1, 0)
				fallbackRoot.BackgroundTransparency = 1
				fallbackRoot.Parent = fallbackGui
			end
			fallbackRoot.Visible = true
		end

		if not template and not templateWarned then
			templateWarned = true
			warn("[TerminalClient] UpgradeCardTemplate missing; created fallback UpgradesGui")
		end
		return template
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

	-- Loading UI setup
	local playerGui = player:WaitForChild("PlayerGui", 5)
	if not playerGui then
		warn("[TerminalClient] PlayerGui missing")
		return
	end
	ensureTerminalUi(playerGui)
	ensureUpgradeTemplate(playerGui)

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

	-- Remotes
	local remotesFolder = waitForChildWithTimeout(ReplicatedStorage, "Remotes") or safeFind(ReplicatedStorage, "Remotes")
	local loadingProgressEvent = remotesFolder and safeFind(remotesFolder, "LoadingProgress")
	local storeAnalyticsEvent = remotesFolder and safeFind(remotesFolder, "StoreAnalyticsEvent")
	local boostsUpdatedEvent = remotesFolder and safeFind(remotesFolder, "BoostsUpdated")
	local offlinePreviewEvent = remotesFolder and safeFind(remotesFolder, "OfflineEarningsPreview")

	if not remotesFolder then
		warn("[TerminalClient] Remotes folder missing")
		return
	end

	local function getRemote(name)
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

	if SyncState then
		SyncState.Init({
			resolveRequestSync = resolveRequestSync,
			backoffMax = 5,
			warnCooldown = 0,
			warn = function(...) warn(...) end,
			requestSync = resolveRequestSync(),
		})
	end
	local purchaseUpgradeEvent = getRemote("PurchaseUpgrade")
	local prestigeEvent = getRemote("RequestPrestige")
	local prestigePreviewEvent = getRemote("PrestigePreviewUpdate")
	local requestPrestigePreview = getRemote("RequestPrestigePreview")
	local sessionBonusEvent = getRemote("SessionBonusUpdate")
	local globalAnnouncementEvent = getRemote("GlobalAnnouncement")
	local globalStatsEvent = getRemote("GlobalStatsUpdate")
	local serverPowerEvent = getRemote("ServerPowerUpdate")
	local systemNotificationEvent = getRemote("SystemNotification")
	local leaderboardFunction = getRemote("GetLeaderboard")
	local lifetimeLeaderboardFunction = getRemote("GetLifetimeLeaderboard")
	weeklyResetFunction = getRemote("GetWeeklyResetTime")
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
			purchaseUpgradeEvent
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
	local activationState = { requested = false, completed = false }
	local activationHook = { activate = nil }

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
		if force then
			ensureTerminalUi(playerGui)
			ensureUpgradeTemplate(playerGui)
		end

		if activationHook.ensureCoreSystems then
			local coreReady = activationHook.ensureCoreSystems()
			if not coreReady and not force then
				if not activationState.activationRetrySetReady then
					activationState.activationRetrySetReady = true
					task.delay(0.25, function()
						activationState.activationRetrySetReady = false
						trySetReady(false)
					end)
				end
				return
			end
		end

		if not force then
			if not serverReady and activationState.coreSystemsStarted then
				serverReady = true
			end
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

		activationState.requested = true
		if activationHook.activate and not activationState.completed then
			activationHook.activate()
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
	local template = ensureUpgradeTemplate(playerGui) or waitForChildWithTimeout(playerGui, "UpgradeCardTemplate")
	if not template then
		warn("[TerminalClient] UpgradeCardTemplate missing")
	end

	if template and template:IsA("GuiObject") then
		template.Visible = false
	end

	local UpgradeConfig = require(sharedFolder:WaitForChild("UpgradeConfig"))
	local AutomationConfig = require(sharedFolder:WaitForChild("AutomationConfig"))
	local AutomationConstants = require(sharedFolder:WaitForChild("AutomationConstants"))

	setupRuntimeSystems({
		context = context,
		ui = ui,
		safeFind = safeFind,
		waitForChildWithTimeout = waitForChildWithTimeout,
		Players = Players,
		NumberFormatter = NumberFormatter,
		UserInputService = UserInputService,
		HapticService = HapticService,
		RunService = RunService,
		MarketplaceService = MarketplaceService,
		UpgradeConfig = UpgradeConfig,
		AutomationConfig = AutomationConfig,
		AutomationConstants = AutomationConstants,
		PurchaseHandlerBinder = PurchaseHandlerBinder,
		SyncLoopBinder = SyncLoopBinder,
		ToastController = ToastController,
		StoreUIController = StoreUIController,
		BoostUIController = BoostUIController,
		LeaderboardClient = LeaderboardClient,
		remotesFolder = remotesFolder,
		purchaseUpgradeEvent = purchaseUpgradeEvent,
		prestigeEvent = prestigeEvent,
		prestigePreviewEvent = prestigePreviewEvent,
		requestPrestigePreview = requestPrestigePreview,
		sessionBonusEvent = sessionBonusEvent,
		globalAnnouncementEvent = globalAnnouncementEvent,
		globalStatsEvent = globalStatsEvent,
		serverPowerEvent = serverPowerEvent,
		systemNotificationEvent = systemNotificationEvent,
		autoBuyPresetApplyEvent = autoBuyPresetApplyEvent,
		autoBuyPresetSaveEvent = autoBuyPresetSaveEvent,
		autoBuyPresetStateEvent = autoBuyPresetStateEvent,
		autoBuyPresetUnlockPromptEvent = autoBuyPresetUnlockPromptEvent,
		requestAutoBuyPresets = requestAutoBuyPresets,
		autoBuyAutoSwitchSettingsEvent = autoBuyAutoSwitchSettingsEvent,
		autoBuyStateEvent = autoBuyStateEvent,
		setAutoBuyEvent = setAutoBuyEvent,
		weeklyResetFunction = weeklyResetFunction,
		leaderboardFunction = leaderboardFunction,
		lifetimeLeaderboardFunction = lifetimeLeaderboardFunction,
		activationState = activationState,
		activationHook = activationHook,
		setLoadingStep = setLoadingStep,
		markLocalReady = function()
			localReady = true
			trySetReady(false)
		end,
		template = template,
	})
end)

	if not success then
		warn("[TerminalClient] Initialization failed:", errorMessage)
	end
end

return LoadingInitializer
