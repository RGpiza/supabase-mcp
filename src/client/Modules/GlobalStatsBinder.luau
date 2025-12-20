local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIPaths = require(script.Parent:FindFirstChild("UIPaths"))

local GlobalStatsBinder = {
	_context = nil,
	_started = false,
	Active = false,
	LastUpdateTime = nil,
}

local function warnOnce(message)
	if GlobalStatsBinder._warned then
		return
	end
	GlobalStatsBinder._warned = true
	warn(message)
end

function GlobalStatsBinder.SetContext(context)
	if type(context) ~= "table" then
		return
	end
	GlobalStatsBinder._context = context
end

local function isPayload(value)
	return type(value) == "table" and (value.data ~= nil or value.stats ~= nil or value.meta ~= nil)
end

local function resolveGlobalStatsEvent()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return nil
	end
	local event = remotes:FindFirstChild("GlobalStatsUpdate")
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

local function resolveUi()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local terminalUi = UIPaths.GetTerminalUI(playerGui)
	if not terminalUi then
		return nil
	end
	local root = terminalUi:FindFirstChild("Root")
	local safeArea = root and root:FindFirstChild("SafeArea")
	local topBar = safeArea and safeArea:FindFirstChild("TopBar")
	local dataValue = topBar and topBar:FindFirstChild("DataValue")
	local rightPanel = safeArea and safeArea:FindFirstChild("Main") and safeArea.Main:FindFirstChild("RightPanel")
	local globalPanel = rightPanel and rightPanel:FindFirstChild("GlobalStatsPanel")
	local globalDataValue = globalPanel and globalPanel:FindFirstChild("GlobalStatsDataValue")
	local globalPrestigeValue = globalPanel and globalPanel:FindFirstChild("GlobalStatsPrestigeValue")
	return {
		dataValue = dataValue,
		globalDataValue = globalDataValue,
		globalPrestigeValue = globalPrestigeValue,
	}
end

local function extractGlobalStats(payload)
	if type(payload) ~= "table" then
		return nil, nil
	end
	local stats = payload.stats
	if type(stats) == "table" then
		local global = stats.globalStats
		if type(global) == "table" then
			local totalData = tonumber(global.totalData)
			local totalPrestiges = tonumber(global.totalPrestiges)
			return totalData, totalPrestiges
		end
	end
	return nil, nil
end

local function updateUi(ui, totalData, totalPrestiges)
	if not ui then
		return
	end
	local dataText = tostring(totalData or 0)
	local prestigeText = tostring(totalPrestiges or 0)
	if ui.globalDataValue and ui.globalDataValue:IsA("TextLabel") then
		ui.globalDataValue.Text = dataText
	end
	if ui.globalPrestigeValue and ui.globalPrestigeValue:IsA("TextLabel") then
		ui.globalPrestigeValue.Text = prestigeText
	end
	if ui.dataValue and ui.dataValue:IsA("TextLabel") then
		ui.dataValue.Text = dataText
	end
	GlobalStatsBinder.LastUpdateTime = os.time()
end

function GlobalStatsBinder.Start(arg1, arg2)
	if GlobalStatsBinder._started then
		return true
	end

	local context = GlobalStatsBinder._context
	local payload = nil
	if type(arg1) == "table" and not isPayload(arg1) and type(context) ~= "table" then
		context = arg1
		GlobalStatsBinder._context = context
	end
	if isPayload(arg1) then
		payload = arg1
	elseif isPayload(arg2) then
		payload = arg2
	end

	local updateGlobalStatsUI = type(context) == "table" and context.updateGlobalStatsUI or nil
	local globalStatsEvent = type(context) == "table" and context.globalStatsEvent or nil

	local ui = resolveUi()

	local totalData, totalPrestiges = extractGlobalStats(payload)
	if type(updateGlobalStatsUI) == "function" then
		updateGlobalStatsUI(totalData or 0, totalPrestiges or 0)
	else
		updateUi(ui, totalData or 0, totalPrestiges or 0)
	end

	if not globalStatsEvent then
		globalStatsEvent = resolveGlobalStatsEvent()
	end

	if globalStatsEvent and typeof(globalStatsEvent.OnClientEvent) == "RBXScriptSignal" then
		globalStatsEvent.OnClientEvent:Connect(function(statsPayload)
			if type(statsPayload) ~= "table" then
				return
			end
			local dataValue = tonumber(statsPayload.totalData) or 0
			local prestigeValue = tonumber(statsPayload.totalPrestiges) or 0
			if type(updateGlobalStatsUI) == "function" then
				updateGlobalStatsUI(dataValue, prestigeValue)
			else
				updateUi(ui, dataValue, prestigeValue)
			end
		end)
	end

	GlobalStatsBinder._started = true
	GlobalStatsBinder.Active = true
	GlobalStatsBinder.LastUpdateTime = os.time()
	return true
end

return GlobalStatsBinder
