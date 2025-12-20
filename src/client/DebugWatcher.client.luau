local DEBUG_ENABLED = false

if not DEBUG_ENABLED then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
if not player then
	warn("[DEBUG][WARN] LocalPlayer not available")
	return
end

local function log(prefix, message)
	print(string.format("[DEBUG][%s] %s", prefix, message))
end

local function warnLog(message)
	warn(string.format("[DEBUG][WARN] %s", message))
end

local function getRemotes()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		return nil
	end
	return remotesFolder
end

local playerGui = player:WaitForChild("PlayerGui", 5)
if not playerGui then
	warnLog("PlayerGui missing")
	return
end

local serverDataStagnantCount = 0
local lastServerDataValue = nil
local uiDataText = nil
local uiStagnantCount = 0
local missingTerminalWarned = false
local missingRequestSyncWarned = false
local missingUIWarned = false

local function sampleServerState()
	local remotes = getRemotes()
	if not remotes then
		if not missingRequestSyncWarned then
			warnLog("Remotes folder missing; cannot RequestSync")
			missingRequestSyncWarned = true
		end
		return
	end

	local requestSync = remotes:FindFirstChild("RequestSync")
	if not requestSync or not requestSync:IsA("RemoteFunction") then
		if not missingRequestSyncWarned then
			warnLog("RequestSync remote missing or invalid")
			missingRequestSyncWarned = true
		end
		return
	end

	local ok, state = pcall(function()
		return requestSync:InvokeServer()
	end)

	if not ok then
		warnLog("RequestSync failed: " .. tostring(state))
		return
	end

	if typeof(state) ~= "table" then
		warnLog("RequestSync returned non-table state")
		return
	end

	local dataValue = typeof(state.data) == "number" and state.data or 0
	local dpsValue = typeof(state.dps) == "number" and state.dps or 0
	local prestigeValue = typeof(state.prestige) == "number" and state.prestige or 0
	local corePowerValue = typeof(state.corePower) == "number" and state.corePower or 0

	log("SERVER", string.format("Data=%.3f DPS=%.3f Prestige=%d Core=%d", dataValue, dpsValue, prestigeValue, corePowerValue))

	if dpsValue <= 0 then
		warnLog("DPS is zero or negative")
	end

	if lastServerDataValue ~= nil and dataValue <= lastServerDataValue then
		serverDataStagnantCount += 1
		if serverDataStagnantCount >= 5 then
			warnLog("Server data not increasing")
			serverDataStagnantCount = 0
		end
	else
		serverDataStagnantCount = 0
	end

	lastServerDataValue = dataValue
end

local function resolveUI()
	local terminal = playerGui:FindFirstChild("TerminalUI")
	if not terminal then
		if not missingTerminalWarned then
			warnLog("TerminalUI missing from PlayerGui")
			missingTerminalWarned = true
		end
		return nil
	end

	local root = terminal:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local topBar = safeArea and safeArea:FindFirstChild("TopBar")
	local main = safeArea and safeArea:FindFirstChild("Main")
	local rightPanel = main and main:FindFirstChild("RightPanel")
	local statsBox = rightPanel and rightPanel:FindFirstChild("StatsBox")

	if not (topBar and statsBox) then
		if not missingUIWarned then
			warnLog("TopBar or StatsBox missing")
			missingUIWarned = true
		end
		return nil
	end

	local dataValueLabel = topBar:FindFirstChild("DataValue")
	local stat1 = statsBox:FindFirstChild("Stat1")
	local stat2 = statsBox:FindFirstChild("Stat2")
	local stat3 = statsBox:FindFirstChild("Stat3")

	if not (dataValueLabel and stat1 and stat2 and stat3) then
		if not missingUIWarned then
			warnLog("Stat labels missing")
			missingUIWarned = true
		end
		return nil
	end

	return {
		dataValue = dataValueLabel,
		stat1 = stat1,
		stat2 = stat2,
		stat3 = stat3,
	}
end

local observedUI = resolveUI()

task.spawn(function()
	while task.wait(1) do
		local ok, err = pcall(sampleServerState)
		if not ok then
			warnLog("Server sampler error: " .. tostring(err))
		end
	end
end)

task.spawn(function()
	while task.wait(0.5) do
		if not observedUI then
			observedUI = resolveUI()
		end

		if observedUI and observedUI.dataValue then
			local text = observedUI.dataValue.Text
			log("UI", string.format("DataValue=%s", tostring(text)))
			if uiDataText and uiDataText == text then
				uiStagnantCount += 1
				if uiStagnantCount >= 6 then
					warnLog("DataValue text not updating")
					uiStagnantCount = 0
				end
			else
				uiStagnantCount = 0
			end
			uiDataText = text
		end

		if observedUI and not observedUI.dataValue then
			observedUI = nil
		end
	end
end)
