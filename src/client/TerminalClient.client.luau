local success, errorMessage = pcall(function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")

	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
	if not player then
		warn("[TerminalClient] LocalPlayer missing")
		return
	end

	local function safeFind(parent, name)
		if not parent then
			return nil
		end
		return parent:FindFirstChild(name)
	end

	local playerGui = player:WaitForChild("PlayerGui", 5)
	if not playerGui then
		warn("[TerminalClient] PlayerGui missing")
		return
	end

	local screenGui = playerGui:WaitForChild("TerminalUI", 5)
	if not screenGui then
		warn("[TerminalClient] TerminalUI failed to load")
		return
	end

	local root = safeFind(screenGui, "Root")
	local safeArea = root and safeFind(root, "SafeArea")
	local topBar = safeArea and safeFind(safeArea, "TopBar")
	local main = safeArea and safeFind(safeArea, "Main")
	local columns = main and safeFind(main, "Columns")
	local cpuColumn = columns and safeFind(columns, "CPUColumn")
	local ramColumn = columns and safeFind(columns, "RAMColumn")
	local stoColumn = columns and safeFind(columns, "STOColumn")
	local cpuCards = cpuColumn and safeFind(cpuColumn, "Cards_CPU")
	local ramCards = ramColumn and safeFind(ramColumn, "Cards_RAM")
	local stoCards = stoColumn and safeFind(stoColumn, "Cards_STORAGE")
	local rightPanel = main and safeFind(main, "RightPanel")
	local statsBox = rightPanel and safeFind(rightPanel, "StatsBox")
	local prestigeBox = rightPanel and safeFind(rightPanel, "PrestigeBox")
	local toastArea = safeArea and safeFind(safeArea, "ToastArea")

	if not (root and safeArea and topBar and main and columns and cpuCards and ramCards and stoCards and statsBox and prestigeBox and toastArea) then
		warn("[TerminalClient] UI hierarchy incomplete")
		return
	end

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

	local remotesFolder = safeFind(ReplicatedStorage, "Remotes")
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

	local UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeConfig"))
	local NumberFormatter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NumberFormatter"))

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
	local toastCooldown = false
	local syncLoopStarted = false
	local syncLoopWarningIssued = false

	local function showToast(message)
		if not toastArea then
			return
		end

		if toastCooldown then
			return
		end

		local toast = Instance.new("TextLabel")
		toast.Name = "Toast"
		toast.BackgroundTransparency = 1
		toast.TextColor3 = Color3.new(1, 1, 1)
		toast.TextStrokeTransparency = 0.5
		toast.Font = Enum.Font.GothamBold
		toast.TextSize = 20
		toast.Text = message
		toast.AnchorPoint = Vector2.new(0.5, 0)
		toast.Position = UDim2.new(0.5, 0, 0, 0)
		toast.Parent = toastArea

		toast.TextTransparency = 1
		toast.Visible = true
		toastCooldown = true

		local fadeIn = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })
		local fadeOut = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })

		fadeIn.Completed:Connect(function()
			task.delay(1.2, function()
				fadeOut:Play()
			end)
		end)

		fadeOut.Completed:Connect(function()
			toastCooldown = false
			toast:Destroy()
		end)

		fadeIn:Play()
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
end)

if not success then
	warn("[TerminalClient] Initialization failed:", errorMessage)
	return
end

print("[TerminalClient] Initialized successfully")
