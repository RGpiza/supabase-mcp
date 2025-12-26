-- SystemIncrementalUI - Safe Bootstrap
-- ModuleScript for client-side UI that can be safely required

local Players = game:GetService("Players")

local SystemIncrementalUI = {}

local state = {
	screenGui = nil,
	rootFrame = nil,
	notificationLabels = {},
	isInitialized = false
}

local CONFIG = {
	screenGuiName = "TerminalUI",
	rootFrameName = "Root",
	rootSize = UDim2.new(1, 0, 1, 0),
	rootPosition = UDim2.new(0, 0, 0, 0),
	rootBackgroundColor = Color3.fromRGB(15, 17, 21),
	rootBorderColor = Color3.fromRGB(42, 48, 64),
	rootBorderSize = 1,
	labelTextColor = Color3.fromRGB(230, 230, 230),
	labelTextSize = 20,
	notificationLifetime = 3
}

local function createFrame(name, parent, size, position, backgroundColor, borderSize, borderColor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = backgroundColor
	frame.BorderSizePixel = borderSize
	frame.BorderColor3 = borderColor
	frame.Parent = parent
	return frame
end

local function createTextLabel(name, parent, text, size, position, textColor, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = textSize
	label.TextColor3 = textColor
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

function SystemIncrementalUI.buildUI(player)
	if state.isInitialized then
		return true
	end

	local success, result = pcall(function()
		if not player or not player:IsA("Player") then
			warn("[SystemIncrementalUI] buildUI: Invalid player")
			return false
		end

		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			warn("[SystemIncrementalUI] buildUI: PlayerGui not found")
			return false
		end

		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = CONFIG.screenGuiName
		screenGui.ResetOnSpawn = false
		screenGui.Parent = playerGui
		state.screenGui = screenGui

		local rootFrame = createFrame(
			CONFIG.rootFrameName,
			screenGui,
			CONFIG.rootSize,
			CONFIG.rootPosition,
			CONFIG.rootBackgroundColor,
			CONFIG.rootBorderSize,
			CONFIG.rootBorderColor
		)
		state.rootFrame = rootFrame

		local titleLabel = createTextLabel(
			"TitleLabel",
			rootFrame,
			"System Incremental UI Loaded",
			UDim2.new(1, 0, 0, 40),
			UDim2.new(0, 0, 0, 0),
			CONFIG.labelTextColor,
			CONFIG.labelTextSize
		)
		titleLabel.TextYAlignment = Enum.TextYAlignment.Center
		titleLabel.TextXAlignment = Enum.TextXAlignment.Center

		state.isInitialized = true
		return true
	end)

	if not success then
		warn("[SystemIncrementalUI] buildUI failed:", result)
		return false
	end

	return result
end

function SystemIncrementalUI.notify(message, kind)
	local msg = tostring(message or "Notification")
	local k = kind or "info"

	local success, result = pcall(function()
		print("[SystemIncrementalUI] notify:", msg)
		if not state.rootFrame then
			return
		end

		local label = createTextLabel(
			"Notification_" .. tick(),
			state.rootFrame,
			msg,
			UDim2.new(1, 0, 0, 24),
			UDim2.new(0, 0, 0, 50 + (#state.notificationLabels * 28)),
			CONFIG.labelTextColor,
			14
		)
		label.TextXAlignment = Enum.TextXAlignment.Left

		table.insert(state.notificationLabels, label)

		task.delay(CONFIG.notificationLifetime, function()
			if label and label.Parent then
				label:Destroy()
			end
			for i, v in ipairs(state.notificationLabels) do
				if v == label then
					table.remove(state.notificationLabels, i)
					break
				end
			end
		end)
	end)

	if not success then
		warn("[SystemIncrementalUI] notify failed:", result)
	end
end

function SystemIncrementalUI.destroy()
	local success, result = pcall(function()
		if state.screenGui then
			state.screenGui:Destroy()
			state.screenGui = nil
		end
		if state.rootFrame then
			state.rootFrame = nil
		end
		state.notificationLabels = {}
		state.isInitialized = false
	end)

	if not success then
		warn("[SystemIncrementalUI] destroy failed:", result)
	end
end

return SystemIncrementalUI
