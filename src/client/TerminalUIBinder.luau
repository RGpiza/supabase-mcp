local UIPaths = require(script.Parent:FindFirstChild("Modules"):FindFirstChild("UIPaths"))
local TerminalUIBinder = {}
local initialized = false
local statsFallbackWarned = false
local prestigeFallbackWarned = false

local function applyCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = instance
	end
	corner.CornerRadius = radius
end

local function createStatLabel(parent, name, order)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(235, 238, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "..."
	label.Size = UDim2.new(1, 0, 0, 20)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

local function ensureStatsBox(container)
	if not container then
		return nil
	end

	local statsBox = container:FindFirstChild("StatsBox")
	local created = false
	if not (statsBox and statsBox:IsA("Frame")) then
		statsBox = Instance.new("Frame")
		statsBox.Name = "StatsBox"
		statsBox.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		statsBox.BackgroundTransparency = 0.15
		statsBox.Size = UDim2.new(1, -10, 0, 72)
		statsBox.AutomaticSize = Enum.AutomaticSize.Y
		statsBox.Position = UDim2.new(0, 5, 0, 0)
		statsBox.LayoutOrder = -5
		statsBox.Parent = container
		created = true
	end

	applyCorner(statsBox, UDim.new(0, 8))

	if not statsBox:FindFirstChildOfClass("UIPadding") then
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.Parent = statsBox
	end

	if not statsBox:FindFirstChildOfClass("UIListLayout") then
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = statsBox
	end

	local missingLabel = false
	for index = 1, 3 do
		local labelName = "Stat" .. index
		local label = statsBox:FindFirstChild(labelName)
		if not (label and label:IsA("TextLabel")) then
			createStatLabel(statsBox, labelName, index)
			missingLabel = true
		else
			label.LayoutOrder = index
		end
	end

	if (created or missingLabel) and not statsFallbackWarned then
		statsFallbackWarned = true
		warn("[TerminalClient] StatsBox missing or incomplete in TerminalUI, injected fallback elements")
	end

	return statsBox
end

local function ensurePrestigeOverlay(parent)
	local overlay = parent:FindFirstChild("PrestigeLockedOverlay")
	local created = false
	if not (overlay and overlay:IsA("Frame")) then
		overlay = Instance.new("Frame")
		overlay.Name = "PrestigeLockedOverlay"
		overlay.BackgroundColor3 = Color3.fromRGB(12, 14, 26)
		overlay.BackgroundTransparency = 0.15
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.Visible = false
		overlay.ZIndex = 5
		overlay.Active = false
		overlay.Parent = parent
		created = true

		applyCorner(overlay, UDim.new(0, 8))

		local label = Instance.new("TextLabel")
		label.Name = "LockText"
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.TextColor3 = Color3.fromRGB(255, 238, 200)
		label.Text = "LOCKED"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Parent = overlay
	end

	overlay.Active = false

	local blocker = overlay:FindFirstChild("Blocker")
	if not (blocker and blocker:IsA("TextButton")) then
		blocker = Instance.new("TextButton")
		blocker.Name = "Blocker"
		blocker.Parent = overlay
	end
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.Position = UDim2.fromScale(0, 0)
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.Active = overlay.Active
	blocker.Selectable = false
	blocker.ZIndex = (overlay.ZIndex or 0) + 1

	return overlay, created
end

local function ensurePrestigeButton(prestigeBox)
	local button = prestigeBox:FindFirstChild("PrestigeButton")
	local created = false
	if not (button and button:IsA("TextButton")) then
		button = Instance.new("TextButton")
		button.Name = "PrestigeButton"
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamBold
		button.TextSize = 20
		button.TextColor3 = Color3.fromRGB(240, 245, 255)
		button.Text = "PRESTIGE"
		button.BackgroundColor3 = Color3.fromRGB(45, 55, 80)
		button.Size = UDim2.new(1, -10, 0, 44)
		button.Position = UDim2.new(0, 5, 0, 45)
		button.Parent = prestigeBox
		created = true

		applyCorner(button, UDim.new(0, 8))

		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(255, 236, 160)
		stroke.Transparency = 0.7
		stroke.Parent = button
	end

	return button, created
end

local function ensurePrestigeBox(container)
	if not container then
		return nil
	end

	local prestigeBox = container:FindFirstChild("PrestigeBox")
	local created = false
	if not (prestigeBox and prestigeBox:IsA("Frame")) then
		prestigeBox = Instance.new("Frame")
		prestigeBox.Name = "PrestigeBox"
		prestigeBox.BackgroundColor3 = Color3.fromRGB(17, 24, 35)
		prestigeBox.BackgroundTransparency = 0.1
		prestigeBox.Size = UDim2.new(1, -10, 0, 120)
		prestigeBox.AutomaticSize = Enum.AutomaticSize.Y
		prestigeBox.LayoutOrder = 5
		prestigeBox.Parent = container
		created = true

		applyCorner(prestigeBox, UDim.new(0, 10))

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 10)
		padding.PaddingBottom = UDim.new(0, 10)
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.Parent = prestigeBox
	end

	local button, buttonCreated = ensurePrestigeButton(prestigeBox)
	local overlay, overlayCreated = ensurePrestigeOverlay(prestigeBox)
	overlay.Size = button.Size
	overlay.Position = button.Position

	if not prestigeBox:FindFirstChild("PrestigeTitle") then
		local title = Instance.new("TextLabel")
		title.Name = "PrestigeTitle"
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextColor3 = Color3.fromRGB(200, 240, 255)
		title.Text = "PRESTIGE"
		title.Size = UDim2.new(1, -10, 0, 20)
		title.Position = UDim2.new(0, 5, 0, 0)
		title.Parent = prestigeBox
	end

	if (created or buttonCreated or overlayCreated) and not prestigeFallbackWarned then
		prestigeFallbackWarned = true
		warn("[TerminalClient] PrestigeBox missing or incomplete in TerminalUI, injected fallback elements")
	end

	return prestigeBox
end

function TerminalUIBinder.Init(context)
	if initialized then
		return context.ui ~= nil
	end

	local playerGui = context.playerGui
	if not playerGui then
		warn("[TerminalClient] PlayerGui missing")
		return false
	end

	local screenGui = UIPaths.GetTerminalUI(playerGui)
	if not screenGui then
		warn("[TerminalClient] TerminalUI missing; aborting UI bind")
		return false
	end

	local safeFind = context.safeFind
	local waitForChild = context.waitForChildWithTimeout

	local function getChild(parent, childName)
		if not parent or not childName then
			return nil
		end

		local child = safeFind and safeFind(parent, childName) or nil
		if child then
			return child
		end

		if waitForChild then
			return waitForChild(parent, childName)
		end

		return nil
	end

	local root = getChild(screenGui, "Root")
	local safeArea = getChild(root, "SafeArea")
	local topBar = getChild(safeArea, "TopBar")
	local main = getChild(safeArea, "Main")
	local columns = getChild(main, "Columns")
	local cpuColumn = getChild(columns, "CPUColumn")
	local ramColumn = getChild(columns, "RAMColumn")
	local stoColumn = getChild(columns, "STOColumn")
	local cpuCards = UIPaths.GetCardsCPU(screenGui) or getChild(cpuColumn, "Cards_CPU")
	local ramCards = UIPaths.GetCardsRAM(screenGui) or getChild(ramColumn, "Cards_RAM")
	local stoCards = UIPaths.GetCardsSTO(screenGui) or getChild(stoColumn, "Cards_STORAGE")
	local rightPanel = getChild(main, "RightPanel")

	local statsPage = nil
	if rightPanel then
		local pages = getChild(rightPanel, "Pages")
		if pages then
			statsPage = getChild(pages, "StatsPage")
		end
	end

	local function findInStatsContainer(name)
		if statsPage then
			local found = statsPage:FindFirstChild(name, true)
			if found then
				return found
			end
		end
		if rightPanel then
			return rightPanel:FindFirstChild(name, true)
		end
		return nil
	end

	local statsBox = findInStatsContainer("StatsBox")
	if not statsBox then
		statsBox = ensureStatsBox(statsPage or rightPanel)
	end

	local prestigeBox = findInStatsContainer("PrestigeBox") or ensurePrestigeBox(statsPage or rightPanel)
	local toastArea = getChild(safeArea, "ToastArea")

	if not (root and safeArea and topBar and main and columns and cpuCards and ramCards and stoCards and statsBox and prestigeBox and toastArea) then
		local missing = {}
		if not root then
			table.insert(missing, "Root")
		end
		if not safeArea then
			table.insert(missing, "SafeArea")
		end
		if not topBar then
			table.insert(missing, "TopBar")
		end
		if not main then
			table.insert(missing, "Main")
		end
		if not columns then
			table.insert(missing, "Columns")
		end
		if not cpuCards then
			table.insert(missing, "Cards_CPU")
		end
		if not ramCards then
			table.insert(missing, "Cards_RAM")
		end
		if not stoCards then
			table.insert(missing, "Cards_STORAGE")
		end
		if not statsBox then
			table.insert(missing, "StatsBox")
		end
		if not prestigeBox then
			table.insert(missing, "PrestigeBox")
		end
		if not toastArea then
			table.insert(missing, "ToastArea")
		end

		if #missing > 0 then
			warn(string.format("[TerminalClient] UI hierarchy incomplete: missing %s", table.concat(missing, ", ")))
		else
			warn("[TerminalClient] UI hierarchy incomplete")
		end
		return false
	end

	context.ui = {
		screenGui = screenGui,
		root = root,
		safeArea = safeArea,
		topBar = topBar,
		main = main,
		columns = columns,
		cpuColumn = cpuColumn,
		ramColumn = ramColumn,
		stoColumn = stoColumn,
		cpuCards = cpuCards,
		ramCards = ramCards,
		stoCards = stoCards,
		rightPanel = rightPanel,
		statsBox = statsBox,
		prestigeBox = prestigeBox,
		toastArea = toastArea,
	}

	initialized = true
	return true
end

return TerminalUIBinder
