local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeBinder = {
	_context = nil,
	_initialized = false,
	Active = false,
	LastInitTime = nil,
	_bindWatcherAttached = false,
	_watchedContainers = {},
	_scannedContainers = {},
}

local function safeRequire(moduleScript)
	if not moduleScript then
		return nil
	end
	local ok, result = pcall(function()
		return require(moduleScript)
	end)
	if ok then
		return result
	end
	return nil
end

local function warnOnce(message)
	if UpgradeBinder._warned then
		return
	end
	UpgradeBinder._warned = true
	warn(message)
end

local function isPayload(value)
	return type(value) == "table" and (value.data ~= nil or value.stats ~= nil or value.meta ~= nil)
end

function UpgradeBinder.SetContext(context)
	if type(context) ~= "table" then
		return
	end
	UpgradeBinder._context = context
end

local function resolveRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return nil
	end
	local purchaseEvent = remotes:FindFirstChild("PurchaseUpgrade")
	if purchaseEvent and purchaseEvent:IsA("RemoteEvent") then
		return purchaseEvent
	end
	local purchaseFunction = remotes:FindFirstChild("PurchaseUpgrade")
	if purchaseFunction and purchaseFunction:IsA("RemoteFunction") then
		return purchaseFunction
	end
	return nil
end

local function getTerminalUI()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	return playerGui:FindFirstChild("TerminalUI") or playerGui:FindFirstChild("TerminalUI", true)
end

local function findCardContainers(terminalUi)
	if not terminalUi then
		return {}
	end
	local root = terminalUi:FindFirstChild("Root") or terminalUi:FindFirstChild("Root", true)
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local columns = main and main:FindFirstChild("Columns")
	if not columns then
		columns = terminalUi:FindFirstChild("Columns", true)
	end
	if not columns then
		return {}
	end
	local containers = {}
	local cpu = columns:FindFirstChild("Cards_CPU", true)
	local ram = columns:FindFirstChild("Cards_RAM", true)
	local sto = columns:FindFirstChild("Cards_STORAGE", true)
	if cpu then table.insert(containers, cpu) end
	if ram then table.insert(containers, ram) end
	if sto then table.insert(containers, sto) end
	return containers
end

local function bindUpgradeButtons(purchaseRemote)
	local modulesFolder = script.Parent and script.Parent:FindFirstChild("Modules")
	local purchaseBinder = modulesFolder and modulesFolder:FindFirstChild("PurchaseHandlerBinder")
	local PurchaseHandlerBinder = nil
	if purchaseBinder then
		PurchaseHandlerBinder = safeRequire(purchaseBinder)
	end

	if type(PurchaseHandlerBinder) == "table" and type(PurchaseHandlerBinder.Init) == "function" then
		PurchaseHandlerBinder.Init({
			purchaseUpgradeEvent = purchaseRemote,
			PURCHASE_SETTINGS = {
				debounce = 0.2,
				longPressDuration = 0.5,
				activationSuppress = 0.1,
			},
		})
	end

	local UserInputService = game:GetService("UserInputService")
	local function bindButton(button, upgradeId)
		if button:GetAttribute("UpgradeBound") == true then
			return
		end
		button:SetAttribute("UpgradeBound", true)

		if type(PurchaseHandlerBinder) == "table" and type(PurchaseHandlerBinder.Bind) == "function" then
			PurchaseHandlerBinder.Bind(button, upgradeId)
			return
		end

		local lastHandled = 0
		local activeTouch = nil
		local touchLongPressTriggered = false

		local function firePurchase(mode)
			local now = os.clock()
			if now - lastHandled < 0.2 then
				return
			end
			lastHandled = now
			if purchaseRemote and purchaseRemote:IsA("RemoteEvent") then
				purchaseRemote:FireServer({ upgradeId = upgradeId, mode = mode or "single" })
			elseif purchaseRemote and purchaseRemote:IsA("RemoteFunction") then
				pcall(function()
					purchaseRemote:InvokeServer({ upgradeId = upgradeId, mode = mode or "single" })
				end)
			end
		end

		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				firePurchase("max")
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				local isShift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
					or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				local isCtrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
					or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				local isAlt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
					or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
				if isShift or isCtrl or isAlt then
					firePurchase("max")
				end
			elseif input.UserInputType == Enum.UserInputType.Touch then
				activeTouch = input
				touchLongPressTriggered = false
				local captured = input
				task.delay(0.5, function()
					if activeTouch == captured and not touchLongPressTriggered then
						touchLongPressTriggered = true
						firePurchase("max")
					end
				end)
			end
		end)

		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and activeTouch == input then
				activeTouch = nil
				if not touchLongPressTriggered then
					firePurchase("single")
				end
			end
		end)

		button.Activated:Connect(function()
			firePurchase("single")
		end)
	end

	local function bindCard(card)
		if not (card and card:IsA("GuiObject")) then
			return
		end
		local button = card:FindFirstChild("BuyButton", true) or card:FindFirstChild("CardBuyButton", true)
		print("[UpgradeBinder] Card frame:", card.Name, "BuyButton:", tostring(button ~= nil))
		if not button then
			return
		end
		local upgradeId = card.Name
		if upgradeId and upgradeId ~= "" then
			bindButton(button, upgradeId)
		end
	end

	local function scanAndBind(container)
		if not container then
			return
		end
		print("[UpgradeBinder] Scanning container:", container.Name, "Children:", #container:GetChildren())
		for _, descendant in ipairs(container:GetDescendants()) do
			if descendant:IsA("UIListLayout")
				or descendant:IsA("UIPadding")
				or descendant:IsA("UIGridLayout")
			then
				continue
			end
			local button = descendant:FindFirstChild("BuyButton", true)
				or descendant:FindFirstChild("CardBuyButton", true)
			if button and button:IsA("GuiButton") then
				bindCard(descendant)
			end
		end
	end

	local function connectContainer(container)
		if not container then
			return
		end
		if not UpgradeBinder._watchedContainers[container] then
			UpgradeBinder._watchedContainers[container] = true
			container.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("GuiButton") and (descendant.Name == "BuyButton" or descendant.Name == "CardBuyButton") then
					local card = descendant.Parent
					if card and card:IsA("GuiObject") then
						bindCard(card)
					end
				end
			end)
		end
		if not UpgradeBinder._scannedContainers[container] then
			UpgradeBinder._scannedContainers[container] = true
			scanAndBind(container)
		end
	end

	local function ensureWatcher()
		if UpgradeBinder._bindWatcherAttached then
			return
		end
		local player = Players.LocalPlayer
		local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return
		end
		UpgradeBinder._bindWatcherAttached = true
		task.defer(function()
			local containers = findCardContainers(getTerminalUI())
			for _, container in ipairs(containers) do
				connectContainer(container)
			end
			print("[UpgradeBinder] Containers found:", #containers)
		end)
	end

	ensureWatcher()
	local containers = findCardContainers(getTerminalUI())
	for _, container in ipairs(containers) do
		connectContainer(container)
	end
	print("[UpgradeBinder] Containers found:", #containers)
	return true
end

function UpgradeBinder.EnsureBindings()
	bindUpgradeButtons(resolveRemotes())
end

function UpgradeBinder.Init(arg1, arg2)
	if UpgradeBinder._initialized then
		UpgradeBinder.EnsureBindings()
		return true
	end

	local context = UpgradeBinder._context
	local payload = nil
	if type(arg1) == "table" and not isPayload(arg1) and type(context) ~= "table" then
		context = arg1
		UpgradeBinder._context = context
	end
	if isPayload(arg1) then
		payload = arg1
	elseif isPayload(arg2) then
		payload = arg2
	end

	local purchaseRemote = resolveRemotes()

	if type(context) == "table" then
		local buildUpgradeCardsAsync = context.buildUpgradeCardsAsync
		if type(buildUpgradeCardsAsync) == "function" then
			buildUpgradeCardsAsync()
		end

		local refreshAllCards = context.refreshAllCards
		if type(refreshAllCards) == "function" then
			refreshAllCards()
		end

		if type(context.applyUpgradePayload) == "function" then
			context.applyUpgradePayload(payload)
		end
	end

	local bound = bindUpgradeButtons(purchaseRemote)
	if not bound then
		warnOnce("[UpgradeBinder] No upgrade buttons found; upgrades may not respond")
	end

	local function logFinalCheck()
		local totalButtons = 0
		local boundButtons = 0
		for _, container in ipairs(findCardContainers(getTerminalUI())) do
			for _, card in ipairs(container:GetChildren()) do
				if card:IsA("Frame") then
					local button = card:FindFirstChild("BuyButton", true) or card:FindFirstChild("CardBuyButton", true)
					if button and button:IsA("GuiButton") then
						totalButtons += 1
						if button:GetAttribute("UpgradeBound") == true then
							boundButtons += 1
						end
					end
				end
			end
		end
		print("[UpgradeBinder] Final check: Buttons=" .. tostring(totalButtons) .. " Bound=" .. tostring(boundButtons))
	end

	logFinalCheck()

	UpgradeBinder._initialized = true
	UpgradeBinder.Active = true
	UpgradeBinder.LastInitTime = os.time()
	return true
end

return UpgradeBinder
