local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local ran = false
local uiEnsured = false

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
	warn("[EmergencyBootstrap] Failed to require " .. moduleScript.Name)
	return nil
end

local function resolveBinder(name)
	local modulesFolder = script.Parent and script.Parent:FindFirstChild("Modules")
	local moduleScript = modulesFolder and modulesFolder:FindFirstChild(name)
	local binder = safeRequire(moduleScript)
	if type(binder) ~= "table" then
		binder = {}
	end
	return binder
end

local function ensureFunction(binder, key)
	if type(binder[key]) ~= "function" then
		binder[key] = function()
			return true
		end
	end
end

local function validatePayload(payload)
	return typeof(payload) == "table"
end

local function tryInvokeRequestSync()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return nil
	end
	local requestSync = remotes:FindFirstChild("RequestSync")
	if not (requestSync and requestSync:IsA("RemoteFunction")) then
		return nil
	end
	local ok, payload = pcall(function()
		return requestSync:InvokeServer()
	end)
	if not ok then
		return nil
	end
	if not validatePayload(payload) then
		return nil
	end
	return payload
end

local diagnosticRan = false
local upgradesUiEnsured = false
local upgradeDiagnosticsRan = false

local function runUpgradeDiagnosticsOnce()
	if upgradeDiagnosticsRan then
		return
	end
	upgradeDiagnosticsRan = true

	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if not playerGui then
		print("[UpgradeDiagnostics] PlayerGui missing")
		return
	end

	local terminalUi = playerGui:FindFirstChild("TerminalUI")
		or playerGui:FindFirstChild("TerminalUI", true)
	print("[UpgradeDiagnostics] TerminalUI exists:", terminalUi ~= nil)

	local function safeGetChild(root, name)
		return root and root:FindFirstChild(name)
	end

	local root = safeGetChild(terminalUi, "Root")
	local safeArea = safeGetChild(root, "SafeArea")
	local main = safeGetChild(safeArea, "Main")
	local columns = safeGetChild(main, "Columns")
	local cpuColumn = safeGetChild(columns, "CPUColumn")
	local ramColumn = safeGetChild(columns, "RAMColumn")
	local stoColumn = safeGetChild(columns, "STOColumn")
	local cpuCards = safeGetChild(cpuColumn, "Cards_CPU") or (columns and columns:FindFirstChild("Cards_CPU", true))
	local ramCards = safeGetChild(ramColumn, "Cards_RAM") or (columns and columns:FindFirstChild("Cards_RAM", true))
	local stoCards = safeGetChild(stoColumn, "Cards_STORAGE") or (columns and columns:FindFirstChild("Cards_STORAGE", true))

	local function countFrames(container)
		if not container then
			return 0
		end
		local count = 0
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Frame") then
				count += 1
			end
		end
		return count
	end

	print("[UpgradeDiagnostics] Cards_CPU:", cpuCards and cpuCards:GetFullName() or "nil", "Frames:", countFrames(cpuCards))
	print("[UpgradeDiagnostics] Cards_RAM:", ramCards and ramCards:GetFullName() or "nil", "Frames:", countFrames(ramCards))
	print("[UpgradeDiagnostics] Cards_STORAGE:", stoCards and stoCards:GetFullName() or "nil", "Frames:", countFrames(stoCards))

	local upgradeTemplate = playerGui:FindFirstChild("UpgradeCardTemplate")
		or playerGui:FindFirstChild("UpgradeCardTemplate", true)
	local templateLocation = upgradeTemplate and upgradeTemplate:GetFullName() or "nil"
	if not upgradeTemplate then
		local starterTemplate = StarterGui:FindFirstChild("UpgradeCardTemplate")
			or StarterGui:FindFirstChild("UpgradeCardTemplate", true)
		local replicatedTemplate = ReplicatedStorage:FindFirstChild("UpgradeCardTemplate")
			or ReplicatedStorage:FindFirstChild("UpgradeCardTemplate", true)
		upgradeTemplate = starterTemplate or replicatedTemplate
		templateLocation = upgradeTemplate and upgradeTemplate:GetFullName() or "nil"
	end
	print("[UpgradeDiagnostics] UpgradeCardTemplate:", templateLocation)

	local upgradeFrames = {}
	for _, node in ipairs(playerGui:GetDescendants()) do
		if node:IsA("Frame") then
			local lowerName = string.lower(node.Name)
			local matchesName = string.find(lowerName, "upgrade", 1, true) ~= nil
			local hasBuyButton = node:FindFirstChild("CardBuyButton", true)
				or node:FindFirstChild("BuyButton", true)
			if matchesName or hasBuyButton then
				table.insert(upgradeFrames, node)
			end
		end
	end
	print("[UpgradeDiagnostics] Upgrade-like Frames in PlayerGui:", #upgradeFrames)
	for i = 1, math.min(#upgradeFrames, 5) do
		print("[UpgradeDiagnostics] Frame:", upgradeFrames[i]:GetFullName())
	end
end

local function tryFindPath(root, path)
	local current = root
	for _, name in ipairs(path) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function ensureUpgradesPage(terminalUi)
	if upgradesUiEnsured then
		return
	end
	upgradesUiEnsured = true

	local root = terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local rightPanel = main and main:FindFirstChild("RightPanel")
	if not rightPanel then
		warn("[UpgradeUI] RightPanel missing in TerminalUI")
		return
	end

	local columns = main and main:FindFirstChild("Columns")
	local cpuCards = columns and columns:FindFirstChild("Cards_CPU", true)
	local ramCards = columns and columns:FindFirstChild("Cards_RAM", true)
	local stoCards = columns and columns:FindFirstChild("Cards_STORAGE", true)

	local function countButtons(container)
		if not container then
			return 0
		end
		local count = 0
		for _, card in ipairs(container:GetChildren()) do
			if card:IsA("Frame") then
				local button = card:FindFirstChild("BuyButton", true) or card:FindFirstChild("CardBuyButton", true)
				if button and button:IsA("GuiButton") then
					count += 1
				end
			end
		end
		return count
	end

	local totalButtons = countButtons(cpuCards) + countButtons(ramCards) + countButtons(stoCards)
	warn("[UpgradeUI] Final state: RightPanel=true Buttons=" .. tostring(totalButtons))
end

local function ensureUpgradeUi()
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	if not diagnosticRan then
		diagnosticRan = true
		local names = {}
		for _, child in ipairs(playerGui:GetChildren()) do
			if child:IsA("LayerCollector") then
				table.insert(names, child.Name)
				local lowerName = string.lower(child.Name)
				if string.find(lowerName, "upgrade", 1, true)
					or string.find(lowerName, "upgrades", 1, true)
					or string.find(lowerName, "shop", 1, true)
					or string.find(lowerName, "store", 1, true)
				then
					child.Enabled = true
					local root = child:FindFirstChildWhichIsA("GuiObject")
					if root then
						root.Visible = true
					end
				end
			end
		end
		print("[UpgradeUI] ScreenGuis in PlayerGui: " .. table.concat(names, ", "))
	end

	local terminalUi = playerGui:FindFirstChild("TerminalUI")
	if not terminalUi then
		local template = StarterGui:FindFirstChild("TerminalUI") or StarterGui:FindFirstChild("TerminalUI", true)
		if not template then
			template = ReplicatedStorage:FindFirstChild("TerminalUI") or ReplicatedStorage:FindFirstChild("TerminalUI", true)
		end
		if template then
			terminalUi = template:Clone()
			if terminalUi:IsA("LayerCollector") then
				terminalUi.ResetOnSpawn = false
			end
			terminalUi.Parent = playerGui
		end
	end

	if terminalUi then
		if terminalUi.Parent ~= playerGui then
			terminalUi.Parent = playerGui
		end
		if terminalUi:IsA("LayerCollector") then
			terminalUi.Enabled = true
			terminalUi.ResetOnSpawn = false
		end
		local root = terminalUi:FindFirstChild("Root")
		if root and root:IsA("GuiObject") then
			root.Visible = true
		end
	end
	if terminalUi then
		ensureUpgradesPage(terminalUi)
	end

	local upgradeTemplate = playerGui:FindFirstChild("UpgradeCardTemplate")
		or playerGui:FindFirstChild("UpgradeCardTemplate", true)
	if not upgradeTemplate then
		local starterTemplate = StarterGui:FindFirstChild("UpgradeCardTemplate")
			or StarterGui:FindFirstChild("UpgradeCardTemplate", true)
		if not starterTemplate then
			starterTemplate = ReplicatedStorage:FindFirstChild("UpgradeCardTemplate")
				or ReplicatedStorage:FindFirstChild("UpgradeCardTemplate", true)
		end
		if starterTemplate then
			upgradeTemplate = starterTemplate:Clone()
			upgradeTemplate.Parent = playerGui
		end
	end
	if upgradeTemplate and upgradeTemplate.Parent ~= playerGui then
		upgradeTemplate.Parent = playerGui
	end

	if not upgradeTemplate then
		local fallbackGui = playerGui:FindFirstChild("UpgradesGui")
		if not (fallbackGui and fallbackGui:IsA("LayerCollector")) then
			fallbackGui = Instance.new("ScreenGui")
			fallbackGui.Name = "UpgradesGui"
			fallbackGui.ResetOnSpawn = false
			fallbackGui.Parent = playerGui
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
	print("[UpgradeUI] Final state: PRESENT")
end
end

local function runOnceWithPayload(payload)
	if ran then
		return
	end
	ran = true

	local upgradeBinder = resolveBinder("UpgradeBinder")
	local globalStatsBinder = resolveBinder("GlobalStatsBinder")

	ensureFunction(upgradeBinder, "Init")
	ensureFunction(globalStatsBinder, "Start")

	ensureUpgradeUi()

	pcall(function()
		upgradeBinder.Init(payload)
	end)
	pcall(function()
		globalStatsBinder.Start(payload)
	end)
end

task.spawn(function()
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChild("PlayerGui")
	if playerGui and not uiEnsured then
		uiEnsured = true
		task.defer(runUpgradeDiagnosticsOnce)
		task.defer(ensureUpgradeUi)
		playerGui.DescendantAdded:Connect(function(child)
			if child and (child.Name == "TerminalUI" or child.Name == "UpgradeCardTemplate") then
				task.defer(ensureUpgradeUi)
			end
		end)
	end
	while not ran do
		local payload = tryInvokeRequestSync()
		if payload then
			runOnceWithPayload(payload)
			break
		end
		task.wait(1)
	end
end)
