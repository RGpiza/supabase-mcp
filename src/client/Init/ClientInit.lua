local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

print("[ClientInit] Started")

local clientRoot = script.Parent and script.Parent.Parent
if not clientRoot then
	error("[ClientInit] Client root missing")
end

local function waitForChildTimeout(parent, childName, seconds)
	if not parent then
		error(("[ClientInit] WaitForChildTimeout missing parent for %s"):format(childName))
	end
	local child = parent:WaitForChild(childName, seconds)
	if not child then
		error(("[ClientInit] WaitForChildTimeout timed out: %s"):format(childName))
	end
	return child
end

local bootstrapFolder = waitForChildTimeout(clientRoot, "Bootstrap", 3)
local modulesFolder = waitForChildTimeout(clientRoot, "Modules", 3)
local controllersFolder = clientRoot:FindFirstChild("Controllers")

local function safeRequire(moduleScript, name)
	if not moduleScript then
		warn(("[ClientInit] Missing module: %s"):format(name))
		return nil
	end
	local ok, res = pcall(require, moduleScript)
	if not ok then
		warn(("[ClientInit] require failed: %s :: %s"):format(name, tostring(res)))
		return nil
	end
	return res
end

local function safeCall(fn, name)
	local ok, err = pcall(fn)
	if not ok then
		warn(("[ClientInit] init failed: %s :: %s"):format(name, tostring(err)))
	end
end

local player = Players.LocalPlayer
if not player then
	error("[ClientInit] LocalPlayer missing")
end

local readyEvent = ReplicatedStorage:FindFirstChild("TerminalUIReady")
if readyEvent and not readyEvent:IsA("BindableEvent") then
	error("[ClientInit] ReplicatedStorage.TerminalUIReady is not a BindableEvent")
end
if not readyEvent then
	readyEvent = Instance.new("BindableEvent")
	readyEvent.Name = "TerminalUIReady"
	readyEvent.Parent = ReplicatedStorage
end

local terminalUi = nil
print("[ClientInit] Waiting for TerminalUIReady")
task.delay(3, function()
	if not terminalUi then
		error("TerminalUIReady never fired — pipeline stalled")
	end
end)

local TerminalUIBootstrap = safeRequire(waitForChildTimeout(bootstrapFolder, "TerminalUIBootstrap", 3), "TerminalUIBootstrap")
safeCall(function()
	terminalUi = TerminalUIBootstrap.Ensure(player)
	if not terminalUi then
		error("[ClientInit] TerminalUIBootstrap.Ensure returned nil")
	end
end, "TerminalUIBootstrap.Ensure")

if not terminalUi then
	terminalUi = readyEvent.Event:Wait()
end
print("[ClientInit] TerminalUIReady received")

if not (terminalUi and terminalUi:IsA("ScreenGui")) then
	error("[ClientInit] TerminalUIReady fired without a ScreenGui")
end

local function findTemplate(ui)
	return StarterGui:FindFirstChild("UpgradeCardTemplate")
end

local function logClip(node, label)
	if node and node:IsA("GuiObject") then
		print(("[ClientInit] %s ClipsDescendants before=%s"):format(label, tostring(node.ClipsDescendants)))
		node.ClipsDescendants = false
		print(("[ClientInit] %s ClipsDescendants after=%s"):format(label, tostring(node.ClipsDescendants)))
	end
end

local function applyDisplayOrder(ui)
	for _, child in ipairs(ui.Parent:GetChildren()) do
		if child:IsA("ScreenGui") then
			print(("[ClientInit] ScreenGui %s DisplayOrder=%d Enabled=%s"):format(
				child.Name,
				child.DisplayOrder,
				tostring(child.Enabled)
			))
			child.DisplayOrder = child == ui and 100 or 0
		end
	end
end

local function forceUIVisible(ui)
	ui.Enabled = true
	ui.DisplayOrder = 100

	local root = ui:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local columns = main and main:FindFirstChild("Columns")
	local rightPanel = main and main:FindFirstChild("RightPanel")

	local function forcePanel(frame)
		if frame and frame:IsA("Frame") then
			frame.Visible = true
			frame.BackgroundTransparency = 0
		elseif frame and frame:IsA("GuiObject") then
			frame.Visible = true
		end
	end

	forcePanel(root)
	forcePanel(safeArea)
	forcePanel(main)
	forcePanel(columns)
	forcePanel(rightPanel)

	local function forceCards(container)
		if not container then
			return
		end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Frame") then
				child.Visible = true
				child.BackgroundTransparency = 0
				local title = child:FindFirstChild("CardTitle") or child:FindFirstChild("Title")
				local desc = child:FindFirstChild("CardDesc") or child:FindFirstChild("Description")
				local cost = child:FindFirstChild("CardCostLabel") or child:FindFirstChild("Cost")
				if title and title:IsA("TextLabel") then
					title.TextTransparency = 0
				end
				if desc and desc:IsA("TextLabel") then
					desc.TextTransparency = 0
				end
				if cost and cost:IsA("TextLabel") then
					cost.TextTransparency = 0
				end
				local buyButton = child:FindFirstChild("CardBuyButton") or child:FindFirstChild("BuyButton")
				if buyButton and buyButton:IsA("GuiButton") then
					buyButton.Active = true
					buyButton.AutoButtonColor = true
					buyButton.Selectable = true
				end
			end
		end
	end

	local cpuCards = columns and columns:FindFirstChild("CPUColumn") and columns.CPUColumn:FindFirstChild("Cards_CPU")
	local ramCards = columns and columns:FindFirstChild("RAMColumn") and columns.RAMColumn:FindFirstChild("Cards_RAM")
	local stoCards = columns and columns:FindFirstChild("STOColumn") and columns.STOColumn:FindFirstChild("Cards_STORAGE")
	forceCards(cpuCards)
	forceCards(ramCards)
	forceCards(stoCards)

	local storeOverlay = safeArea and safeArea:FindFirstChild("StoreOverlay")
	if storeOverlay and storeOverlay:IsA("GuiObject") then
		storeOverlay.Visible = false
	end

	local bgOne = 0
	local textOne = 0
	for _, desc in ipairs(ui:GetDescendants()) do
		if desc:IsA("GuiObject") and desc.BackgroundTransparency >= 1 then
			bgOne += 1
		end
		if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.TextTransparency >= 1 then
			textOne += 1
		end
	end
	print(("[ClientInit] Transparency dump: Background=1 count=%d Text=1 count=%d"):format(bgOne, textOne))
	if bgOne > 0 or textOne > 0 then
		for _, desc in ipairs(ui:GetDescendants()) do
			if desc:IsA("GuiObject") and desc.BackgroundTransparency >= 1 then
				print(("[ClientInit] BackgroundTransparency=1: %s"):format(desc:GetFullName()))
			end
			if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.TextTransparency >= 1 then
				print(("[ClientInit] TextTransparency=1: %s"):format(desc:GetFullName()))
			end
		end
	end
end

local function injectDebugCard(playerGui, ui)
	local template = findTemplate(ui)
	local root = ui:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local columns = main and main:FindFirstChild("Columns")
	local cpuColumn = columns and columns:FindFirstChild("CPUColumn")
	local cpuCards = cpuColumn and cpuColumn:FindFirstChild("Cards_CPU")

	local templatePath = template and template:GetFullName() or "nil"
	local terminalPath = ui and ui:GetFullName() or "nil"
	local cardsPath = cpuCards and cpuCards:GetFullName() or "nil"
	print("[ClientInit] StarterGui.UpgradeCardTemplate:", templatePath)
	print("[ClientInit] PlayerGui.TerminalUI:", terminalPath)
	print("[ClientInit] Cards_CPU:", cardsPath)

	if not (template and cpuCards) then
		warn("[ClientInit] Missing UpgradeCardTemplate or Cards_CPU for debug card")
		return
	end

	local card = template:Clone()
	card.Name = "__DEBUG_CARD__"
	card.Parent = cpuCards
	card.Visible = true
	card.Size = UDim2.new(1, -12, 0, 110)
	card.AutomaticSize = Enum.AutomaticSize.None
	card.LayoutOrder = -999
	card.ZIndex = 9999
	cpuCards.Visible = true
	cpuCards.CanvasSize = UDim2.new(0, 0, 0, 0)
	cpuCards.AutomaticCanvasSize = Enum.AutomaticSize.Y

	for _, desc in ipairs(card:GetDescendants()) do
		if desc:IsA("GuiObject") then
			desc.ZIndex = 10000
			if desc:IsA("TextLabel") or desc:IsA("TextButton") then
				desc.TextTransparency = 0
			elseif desc:IsA("Frame") or desc:IsA("ImageLabel") then
				desc.BackgroundTransparency = math.min(desc.BackgroundTransparency, 0.2)
			end
		end
	end
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
terminalUi = playerGui:WaitForChild("TerminalUI", 5)
if not terminalUi then
	warn("[ClientInit] PlayerGui.TerminalUI missing; skipping debug injection")
else
	injectDebugCard(playerGui, terminalUi)
	logClip(terminalUi:FindFirstChild("Root"), "Root")
	local safeArea = terminalUi:FindFirstChild("Root") and terminalUi.Root:FindFirstChild("SafeArea")
	logClip(safeArea, "SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	logClip(main, "Main")
	local columns = main and main:FindFirstChild("Columns")
	logClip(columns, "Columns")
	local rightPanel = main and main:FindFirstChild("RightPanel")
	logClip(rightPanel, "RightPanel")
	local cpuCards = columns and columns:FindFirstChild("CPUColumn") and columns.CPUColumn:FindFirstChild("Cards_CPU")
	logClip(cpuCards, "Cards_CPU")
	applyDisplayOrder(terminalUi)
	forceUIVisible(terminalUi)

	if cpuCards and #cpuCards:GetChildren() > 0 then
		local anyVisible = false
		for _, child in ipairs(cpuCards:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				local size = child.AbsoluteSize
				if size.X > 1 and size.Y > 1 then
					anyVisible = true
					break
				end
			end
		end
		if not anyVisible then
			error("UI EXISTS BUT IS VISUALLY BLOCKED — CHECK CLIPPING / DISPLAYORDER / ZINDEX")
		end
	end
end

print("[ClientInit] Init:UIPaths")
local UIPaths = safeRequire(waitForChildTimeout(modulesFolder, "UIPaths", 3), "UIPaths")
safeCall(function()
	UIPaths.Init(terminalUi)
end, "UIPaths.Init")

print("[ClientInit] Init:RequestSyncClient")
local RequestSyncController = safeRequire(waitForChildTimeout(modulesFolder, "RequestSyncController", 3), "RequestSyncController")
safeCall(function()
	RequestSyncController.Init(terminalUi)
end, "RequestSyncController.Init")

print("[ClientInit] Init:UpgradeRenderer")
local UpgradeRenderer = safeRequire(waitForChildTimeout(modulesFolder, "UpgradeRenderer", 3), "UpgradeRenderer")
safeCall(function()
	if type(UpgradeRenderer.Init) == "function" then
		UpgradeRenderer.Init(terminalUi)
	end
end, "UpgradeRenderer.Init")

print("[ClientInit] Init:UpgradeBinder")
local UpgradeBinder = safeRequire(waitForChildTimeout(modulesFolder, "UpgradeBinder", 3), "UpgradeBinder")
safeCall(function()
	if type(UpgradeBinder.Init) == "function" then
		UpgradeBinder.Init(terminalUi)
	end
end, "UpgradeBinder.Init")

print("[ClientInit] Init:GlobalStats")
local GlobalStatsBinder = safeRequire(waitForChildTimeout(modulesFolder, "GlobalStatsBinder", 3), "GlobalStatsBinder")
safeCall(function()
	if type(GlobalStatsBinder.Start) == "function" then
		GlobalStatsBinder.Start()
	end
end, "GlobalStatsBinder.Start")

print("[ClientInit] Init:StoreRuntime")
local StoreRuntime = safeRequire(waitForChildTimeout(modulesFolder, "StoreRuntime", 3), "StoreRuntime")
safeCall(function()
	if type(StoreRuntime.Init) == "function" then
		StoreRuntime.Init(terminalUi)
	end
end, "StoreRuntime.Init")

print("[ClientInit] Init:Leaderboards")
local WeeklyController = controllersFolder and safeRequire(waitForChildTimeout(controllersFolder, "WeeklyLeaderboardController", 3), "WeeklyLeaderboardController") or nil
safeCall(function()
	if WeeklyController and type(WeeklyController.Init) == "function" then
		WeeklyController.Init(terminalUi)
	end
end, "WeeklyLeaderboardController.Init")

print("[ClientInit] Init:Autobuy")
local AutoBuyController = controllersFolder and safeRequire(waitForChildTimeout(controllersFolder, "AutoBuyController", 3), "AutoBuyController") or nil
safeCall(function()
	if AutoBuyController and type(AutoBuyController.Init) == "function" then
		AutoBuyController.Init()
	end
end, "AutoBuyController.Init")

print("[ClientInit] Init:Done")

return true
