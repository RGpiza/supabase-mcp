local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local READY_TIMEOUT = 15
local MAX_WAIT = 30

local function findChild(parent, name)
	if not parent then
		return nil
	end
	return parent:FindFirstChild(name)
end

local function findPath(root, path)
	local node = root
	for _, name in ipairs(path) do
		node = findChild(node, name)
		if not node then
			return nil
		end
	end
	return node
end

local function hasAnyGuiButton(container)
	if not container then
		return false
	end
	for _, child in ipairs(container:GetDescendants()) do
		if child:IsA("GuiButton") then
			return true
		end
	end
	return false
end

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

local function getBinderActiveFlag(name)
	local parentFolder = script.Parent
	local modulesFolder = parentFolder and parentFolder:FindFirstChild("Modules")
	local moduleScript = modulesFolder and modulesFolder:FindFirstChild(name)
	local binder = safeRequire(moduleScript)
	if type(binder) == "table" and binder.Active == true then
		return true
	end
	return nil
end

local function checkRequestSync()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return false, "RequestSync: MISSING"
	end
	local requestSync = remotes:FindFirstChild("RequestSync")
	if not (requestSync and requestSync:IsA("RemoteFunction")) then
		return false, "RequestSync: INVALID"
	end

	local ok, payload = pcall(function()
		return requestSync:InvokeServer()
	end)
	if not ok then
		return false, "RequestSync: INVOKE FAILED"
	end
	if type(payload) ~= "table" then
		return false, "Payload: NOT TABLE"
	end

	local required = { "data", "stats", "boosts", "autobuy", "store", "leaderboards", "meta" }
	for _, key in ipairs(required) do
		if payload[key] == nil then
			return false, "Payload: MISSING " .. key
		end
	end

	if type(payload.store) ~= "table" or type(payload.store.items) ~= "table" then
		return false, "Payload: STORE INVALID"
	end
	if type(payload.store.ready) ~= "boolean" then
		return false, "Payload: STORE READY INVALID"
	end

	if type(payload.leaderboards) ~= "table" then
		return false, "Payload: LEADERBOARDS INVALID"
	end
	if type(payload.leaderboards.lifetime) ~= "table"
		or type(payload.leaderboards.weekly) ~= "table"
		or type(payload.leaderboards.friends) ~= "table" then
		return false, "Payload: LEADERBOARDS INVALID"
	end

	if type(payload.meta) ~= "table"
		or type(payload.meta.serverTime) ~= "number"
		or type(payload.meta.version) ~= "string" then
		return false, "Payload: META INVALID"
	end

	return true, "Payload: OK"
end

local function waitForReady(player)
	local deadline = os.clock() + MAX_WAIT
	while os.clock() < deadline do
		if player:GetAttribute("ClientReady") == true then
			return true, os.clock()
		end
		task.wait(0.5)
	end
	return false, os.clock()
end

task.spawn(function()
	local startTime = os.clock()
	local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

	local ready, readyAt = waitForReady(player)
	local elapsed = readyAt - startTime
	local loadingCompletion = "UNKNOWN"
	if ready then
		loadingCompletion = elapsed >= READY_TIMEOUT and "FORCED" or "NORMAL"
	end

	local playerGui = player:FindFirstChild("PlayerGui")
	local terminalUi = playerGui and playerGui:FindFirstChild("TerminalUI")
	local root = terminalUi and terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local rightPanel = main and main:FindFirstChild("RightPanel")
	local pages = rightPanel and rightPanel:FindFirstChild("Pages")
	local statsBox = pages and pages:FindFirstChild("StatsBox")
	local leaderboardPage = pages and pages:FindFirstChild("LeaderboardPage")

	local columns = main and main:FindFirstChild("Columns")
	local cpuColumn = columns and columns:FindFirstChild("CPUColumn")
	local ramColumn = columns and columns:FindFirstChild("RAMColumn")
	local stoColumn = columns and columns:FindFirstChild("STOColumn")
	local cpuCards = cpuColumn and cpuColumn:FindFirstChild("Cards_CPU")
	local ramCards = ramColumn and ramColumn:FindFirstChild("Cards_RAM")
	local stoCards = stoColumn and stoColumn:FindFirstChild("Cards_STORAGE")

	local dataValue = safeArea
		and safeArea:FindFirstChild("TopBar")
		and safeArea.TopBar:FindFirstChild("DataValue")

	local globalStatsPanel = rightPanel and rightPanel:FindFirstChild("GlobalStatsPanel")
	local autoBuyButtonsPresent = (cpuColumn and cpuColumn:FindFirstChild("AutoBuyButton"))
		or (ramColumn and ramColumn:FindFirstChild("AutoBuyButton"))
		or (stoColumn and stoColumn:FindFirstChild("AutoBuyButton"))

	local binderUpgradesActive = getBinderActiveFlag("UpgradeBinder")
	local upgradesActive = binderUpgradesActive == true
		or hasAnyGuiButton(cpuCards)
		or hasAnyGuiButton(ramCards)
		or hasAnyGuiButton(stoCards)
	local autobuyActive = autoBuyButtonsPresent ~= nil
	local binderGlobalStatsActive = getBinderActiveFlag("GlobalStatsBinder")
	local globalStatsActive = binderGlobalStatsActive == true or globalStatsPanel ~= nil
	local leaderboardActive = leaderboardPage ~= nil
	local uiBindingsActive = terminalUi ~= nil and statsBox ~= nil and dataValue ~= nil

	local okSync, syncLine = checkRequestSync()

	local missingActivations = {}
	if not upgradesActive then
		table.insert(missingActivations, "UpgradeBinder.Init")
	end
	if not globalStatsActive then
		table.insert(missingActivations, "GlobalStatsBinder.Start")
	end
	if not autobuyActive then
		table.insert(missingActivations, "AutoBuy.Init")
	end
	if not leaderboardActive then
		table.insert(missingActivations, "Leaderboard.Init")
	end
	if not uiBindingsActive then
		table.insert(missingActivations, "TerminalUIBinder.Init")
	end

	print("[DEBUG SYSTEM CHECK]")
	if okSync then
		print("RequestSync: OK")
		print(syncLine)
	else
		warn(syncLine)
	end

	if upgradesActive then
		print("Upgrades: ACTIVE")
	else
		warn("Upgrades: MISSING HANDLERS")
	end
	if globalStatsActive then
		print("GlobalStats: ACTIVE")
	else
		warn("GlobalStats: NOT ACTIVE")
	end
	if autobuyActive then
		print("Autobuy: ACTIVE")
	else
		warn("Autobuy: NOT ACTIVE")
	end
	if leaderboardActive then
		print("Leaderboards: ACTIVE")
	else
		warn("Leaderboards: NOT ACTIVE")
	end
	if uiBindingsActive then
		print("UI Bindings: OK")
	else
		warn("UI Bindings: PARTIAL")
	end

	print("Loading Completion: " .. loadingCompletion)

	if #missingActivations > 0 then
		warn("Missing Activations:")
		for _, item in ipairs(missingActivations) do
			warn("- " .. item)
		end
	end
end)
