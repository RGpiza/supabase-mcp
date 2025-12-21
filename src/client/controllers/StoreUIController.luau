local StoreUIController = {}

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local DebugConfig = nil
do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.utils:FindFirstChild("DebugConfig"))
	end)
	if ok and type(mod) == "table" then
		DebugConfig = mod
	end
end

local StoreProducts = {
	Gamepasses = {
		x2Data = 1635206515,
		fasterAuto = 1635120464,
	},
	DevProducts = {
		boost5m = 3481392368,
		boost1h = 3481392653,
	},
}

local initialized = false
local storeButtons = {}
local boostTimerConnection
local boostEndTimestamp = 0
local terminalUiRef
local boundMarketplaceEvents = false

local function formatTime(seconds)
	seconds = math.max(seconds or 0, 0)
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", minutes, secs)
end

local function setButtonText(button, text)
	if not button then
		return
	end
	if button:IsA("TextButton") then
		button.Text = text
		return
	end
	local status = button:FindFirstChild("StatusLabel") or button:FindFirstChild("Label")
	if status and status:IsA("TextLabel") then
		status.Text = text
	end
end

local function findStoreRoot(terminalUi)
	if not terminalUi then
		return nil
	end
	local root = terminalUi:FindFirstChild("Root")
	if root then
		local safeArea = root:FindFirstChild("SafeArea")
		if safeArea then
			local storeUi = safeArea:FindFirstChild("StoreUI")
			if storeUi and storeUi:IsA("GuiObject") then
				return storeUi
			end
			local overlay = safeArea:FindFirstChild("StoreOverlay")
			if overlay and overlay:IsA("GuiObject") then
				return overlay
			end
		end
	end
	local storeUi = terminalUi:FindFirstChild("StoreUI", true)
	if storeUi and storeUi:IsA("GuiObject") then
		return storeUi
	end
	local direct = terminalUi:FindFirstChild("StoreOverlay", true)
	if direct and direct:IsA("GuiObject") then
		return direct
	end
	return terminalUi
end

local function findButtonByAttributes(container, productId, storeKey)
	for _, instance in ipairs(container:GetDescendants()) do
		if instance:IsA("GuiButton") then
			local key = instance:GetAttribute("StoreKey")
			if typeof(key) == "string" and key == storeKey then
				return instance
			end
			local attrId = instance:GetAttribute("ProductId") or instance:GetAttribute("GamepassId") or instance:GetAttribute("DevProductId")
			if typeof(attrId) == "number" and attrId == productId then
				return instance
			end
		end
	end
	return nil
end

local function findButtonByName(container, names)
	for _, name in ipairs(names) do
		local found = container:FindFirstChild(name, true)
		if found and found:IsA("GuiButton") then
			return found
		end
	end
	return nil
end

local function resolveStoreButton(container, config)
	local button = findButtonByAttributes(container, config.id, config.key)
	if button then
		return button
	end
	if config.names then
		button = findButtonByName(container, config.names)
		if button then
			return button
		end
	end
	return nil
end

local function stopBoostTimer()
	if boostTimerConnection then
		boostTimerConnection:Disconnect()
		boostTimerConnection = nil
	end
end

local function startBoostTimer(updateFn)
	stopBoostTimer()
	local nextTick = 0
	boostTimerConnection = RunService.Heartbeat:Connect(function()
		local now = os.time()
		if now >= boostEndTimestamp then
			stopBoostTimer()
			updateFn()
			return
		end
		if now >= nextTick then
			nextTick = now + 1
			updateFn()
		end
	end)
end

function StoreUIController.Init(ctx)
	if initialized then
		return true
	end
	initialized = true

	local terminalUi = ctx.terminalGui or ctx.terminalUi
	local onRequestSync = ctx.onRequestSync
	local player = ctx.player or Players.LocalPlayer

	if not terminalUi then
		warn("[StoreUI] TerminalUI missing")
		return false
	end
	local playerGui = player and player:FindFirstChild("PlayerGui")
	local liveTerminal = playerGui and playerGui:FindFirstChild("TerminalUI")
	if not liveTerminal or terminalUi ~= liveTerminal then
		warn("[StoreUI] terminalGui is not PlayerGui.TerminalUI")
		return false
	end

	terminalUiRef = terminalUi
	local storeRoot = ctx.storeRoot or findStoreRoot(terminalUi)
	if not storeRoot then
		warn("[StoreUI] Store root not found")
		return false
	end

	local root = terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local storeUi = safeArea and safeArea:FindFirstChild("StoreUI")
	local storeOverlay = safeArea and safeArea:FindFirstChild("StoreOverlay")
	local topBar = safeArea and safeArea:FindFirstChild("TopBar")
	local storeButton = topBar and topBar:FindFirstChild("StoreButton")
	local storeClose = storeUi and storeUi:FindFirstChild("Header") and storeUi.Header:FindFirstChild("Close")

	if storeUi and storeUi:IsA("GuiObject") then
		storeUi.Visible = false
	end
	if storeOverlay and storeOverlay:IsA("GuiObject") then
		storeOverlay.Visible = false
		storeOverlay.Active = false
	end

	if storeButton and storeButton:IsA("GuiButton") then
		storeButton.Active = true
		storeButton.AutoButtonColor = true
		storeButton.Selectable = true
		storeButton.MouseButton1Click:Connect(function()
			local open = storeUi and storeUi.Visible == false
			if storeUi and storeUi:IsA("GuiObject") then
				storeUi.ZIndex = 20
				storeUi.Visible = open
			end
			if storeOverlay and storeOverlay:IsA("GuiObject") then
				storeOverlay.ZIndex = 10
				storeOverlay.Visible = open
				storeOverlay.Active = open
			end
			if DebugConfig then
				DebugConfig.Log(open and "[StoreUI] Store opened" or "[StoreUI] Store closed")
			end
		end)
	else
		warn("[StoreUI] StoreButton missing")
	end

	local function closeStore()
		if storeUi and storeUi:IsA("GuiObject") then
			storeUi.Visible = false
		end
		if storeOverlay and storeOverlay:IsA("GuiObject") then
			storeOverlay.Visible = false
			storeOverlay.Active = false
		end
		if DebugConfig then
			DebugConfig.Log("[StoreUI] Store closed")
		end
	end

	if storeClose and storeClose:IsA("GuiButton") then
		storeClose.Active = true
		storeClose.AutoButtonColor = true
		storeClose.Selectable = true
		storeClose.MouseButton1Click:Connect(closeStore)
	end

	if storeOverlay and storeOverlay:IsA("GuiButton") then
		storeOverlay.Active = false
		storeOverlay.AutoButtonColor = true
		storeOverlay.MouseButton1Click:Connect(closeStore)
	end

	local entries = {
		{
			key = "x2Data",
			id = StoreProducts.Gamepasses.x2Data,
			type = "Gamepass",
			names = { "X2DataButton", "TwoXDataButton", "2xDataButton", "Pass2xData", "Gamepass2xData", "X2Data", "x2DataCard" },
		},
		{
			key = "fasterAuto",
			id = StoreProducts.Gamepasses.fasterAuto,
			type = "Gamepass",
			names = { "FasterAutoButton", "AutoBuyPassButton", "PassFasterAuto", "GamepassFasterAuto", "FasterAuto", "FasterAutoCard" },
		},
		{
			key = "boost5m",
			id = StoreProducts.DevProducts.boost5m,
			type = "DevProduct",
			names = { "Boost5mButton", "Boost5MinButton", "Boost5m", "Boost5", "+5MinBoostCard" },
		},
		{
			key = "boost1h",
			id = StoreProducts.DevProducts.boost1h,
			type = "DevProduct",
			names = { "Boost1hButton", "Boost1HourButton", "Boost1h", "Boost60m", "+1HourBoostCard" },
		},
	}

	for _, entry in ipairs(entries) do
		local button = resolveStoreButton(storeRoot, entry)
		if button and not button:IsA("GuiButton") then
			button = button:FindFirstChildWhichIsA("GuiButton", true)
		end
		storeButtons[entry.key] = button
		if not button then
			warn(("[StoreUI] Button missing for %s"):format(entry.key))
		else
			button:SetAttribute("StoreKey", entry.key)
			button:SetAttribute("ProductId", entry.id)
			button.Active = true
			button.AutoButtonColor = true
			button.Selectable = true
			if DebugConfig then
				DebugConfig.Log(("[StoreUI] Button bound for %s"):format(entry.key))
			end
			button.Activated:Connect(function()
				if entry.type == "Gamepass" then
					MarketplaceService:PromptGamePassPurchase(player, entry.id)
				else
					MarketplaceService:PromptProductPurchase(player, entry.id)
				end
			end)
		end
	end

	if not boundMarketplaceEvents then
		boundMarketplaceEvents = true
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(finishedPlayer)
			if finishedPlayer == player and typeof(onRequestSync) == "function" then
				onRequestSync()
			end
		end)
		if MarketplaceService.PromptProductPurchaseFinished then
			MarketplaceService.PromptProductPurchaseFinished:Connect(function(finishedPlayer)
				if finishedPlayer == player and typeof(onRequestSync) == "function" then
					onRequestSync()
				end
			end)
		end
	end

print("[INIT] StoreUIController initialized")
	return true
end

function StoreUIController.Update(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local passes = payload.passes
	if typeof(passes) ~= "table" then
		passes = {
			x2Data = payload.owns2xData,
			fasterAuto = payload.ownsFasterAuto,
		}
	end

	local owns2x = typeof(passes.x2Data) == "boolean" and passes.x2Data or false
	local ownsFast = typeof(passes.fasterAuto) == "boolean" and passes.fasterAuto or false
	local boostEnd = typeof(payload.boostEnd) == "number" and payload.boostEnd or payload.boostExpiresAt or 0

	boostEndTimestamp = boostEnd

	local x2Button = storeButtons.x2Data
	if x2Button then
		setButtonText(x2Button, owns2x and "OWNED" or "BUY 2X DATA")
	end

	local fastButton = storeButtons.fasterAuto
	if fastButton then
		setButtonText(fastButton, ownsFast and "OWNED" or "BUY FASTER AUTO")
	end

	local boost5Button = storeButtons.boost5m
	local boost1Button = storeButtons.boost1h

	local function updateBoostLabels()
		local remaining = boostEndTimestamp - os.time()
		local active = remaining > 0
		local timer = formatTime(remaining)
		if boost5Button then
			local label = active and ("ACTIVE 5M " .. timer) or "BUY 5M BOOST"
			setButtonText(boost5Button, label)
		end
		if boost1Button then
			local label = active and ("ACTIVE 1H " .. timer) or "BUY 1H BOOST"
			setButtonText(boost1Button, label)
		end
		if not active then
			stopBoostTimer()
		end
	end

	updateBoostLabels()
	if boostEndTimestamp > os.time() then
		startBoostTimer(updateBoostLabels)
	end

	if terminalUiRef and terminalUiRef:IsA("ScreenGui") then
		terminalUiRef:SetAttribute("AutoBuyIntervalMultiplier", ownsFast and 0.5 or 1)
	end
end

StoreUIController.StoreProducts = StoreProducts

return StoreUIController
