local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsConfig = require(ReplicatedStorage.Shared.AnalyticsConfig)

local AnalyticsTrackerService = {}

local enableAnalytics = (not RunService:IsStudio()) or AnalyticsConfig.FORCE_ENABLE

local sessionStart = {}
local onboardingFlags = {}
local tabDebounce = {}
local dataAccum = {}
local funnelSessions = {}

local function shouldLog()
	return enableAnalytics == true
end

local function toInt(value)
	local n = tonumber(value) or 0
	if n ~= n then
		return 0
	end
	return math.floor(n)
end

local function safeLogEconomy(player, flowType, currencyName, amount, balanceAfter, transactionTypeName, itemSKU, customFields)
	if not shouldLog() or not player then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			currencyName,
			toInt(amount),
			toInt(balanceAfter),
			transactionTypeName,
			itemSKU,
			customFields
		)
	end)
end

local function safeLogOnboarding(player, stepNumber, stepName, customFields)
	if not shouldLog() or not player then
		return
	end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, stepNumber, stepName, customFields)
	end)
end

local function safeLogFunnel(player, funnelName, sessionId, stepNumber, stepName, customFields)
	if not shouldLog() or not player then
		return
	end
	pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, sessionId, stepNumber, stepName, customFields)
	end)
end

local function safeLogCustom(player, eventName, customFields)
	if not shouldLog() or not player then
		return
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName, customFields)
	end)
end

local function getPlayerKey(player)
	return player and tostring(player.UserId) or nil
end

function AnalyticsTrackerService.StartFunnelSession(player, funnelName)
	if not player then
		return nil
	end
	local key = getPlayerKey(player)
	if not key then
		return nil
	end
	funnelSessions[key] = funnelSessions[key] or {}
	local sessionId = HttpService:GenerateGUID(false)
	funnelSessions[key][funnelName] = sessionId
	return sessionId
end

function AnalyticsTrackerService.LogFunnelStep(player, funnelName, sessionId, stepNumber, stepName, customFields)
	safeLogFunnel(player, funnelName, sessionId, stepNumber, stepName, customFields)
end

function AnalyticsTrackerService.LogEconomySource(player, currencyName, amount, balanceAfter, transactionTypeName, itemSKU, customFields)
	safeLogEconomy(player, Enum.AnalyticsEconomyFlowType.Source.Name, currencyName, amount, balanceAfter, transactionTypeName, itemSKU, customFields)
end

function AnalyticsTrackerService.LogEconomySink(player, currencyName, amount, balanceAfter, transactionTypeName, itemSKU, customFields)
	safeLogEconomy(player, Enum.AnalyticsEconomyFlowType.Sink.Name, currencyName, amount, balanceAfter, transactionTypeName, itemSKU, customFields)
end

function AnalyticsTrackerService.LogOnboardingStep(player, stepNumber, stepName, customFields)
	safeLogOnboarding(player, stepNumber, stepName, customFields)
end

function AnalyticsTrackerService.LogCustomCounter(player, eventName, customFields)
	local fields = customFields or {}
	fields.value = toInt(fields.value or 1)
	safeLogCustom(player, eventName, fields)
end

function AnalyticsTrackerService.LogCustomValue(player, eventName, valueNumber, customFields)
	local fields = customFields or {}
	fields.value = toInt(valueNumber)
	safeLogCustom(player, eventName, fields)
end

function AnalyticsTrackerService.OnPlayerAdded(player)
	if not player then
		return
	end
	sessionStart[player] = os.time()
	onboardingFlags[player] = {
		joined = true,
		firstData = false,
		firstUpgrade = false,
		firstPrestigeTab = false,
		firstPrestige = false,
	}
	AnalyticsTrackerService.LogOnboardingStep(player, 1, "Player Joined")
end

function AnalyticsTrackerService.OnPlayerRemoving(player)
	local startTime = sessionStart[player]
	if startTime then
		local duration = os.time() - startTime
		AnalyticsTrackerService.LogCustomValue(player, "SessionSeconds", duration)
	end
	AnalyticsTrackerService.FlushData(player)
	sessionStart[player] = nil
	onboardingFlags[player] = nil
	tabDebounce[player] = nil
	dataAccum[player] = nil
	funnelSessions[player and getPlayerKey(player) or ""] = nil
end

function AnalyticsTrackerService.TrackFirstData(player)
	local flags = onboardingFlags[player]
	if flags and not flags.firstData then
		flags.firstData = true
		AnalyticsTrackerService.LogOnboardingStep(player, 2, "First Data Earned")
	end
end

function AnalyticsTrackerService.TrackFirstUpgrade(player)
	local flags = onboardingFlags[player]
	if flags and not flags.firstUpgrade then
		flags.firstUpgrade = true
		AnalyticsTrackerService.LogOnboardingStep(player, 3, "First Upgrade Purchased")
	end
end

function AnalyticsTrackerService.TrackPrestigeTabOpened(player)
	local flags = onboardingFlags[player]
	if flags and not flags.firstPrestigeTab then
		flags.firstPrestigeTab = true
		AnalyticsTrackerService.LogOnboardingStep(player, 4, "Opened Prestige Tab")
	end
end

function AnalyticsTrackerService.TrackFirstPrestige(player)
	local flags = onboardingFlags[player]
	if flags and not flags.firstPrestige then
		flags.firstPrestige = true
		AnalyticsTrackerService.LogOnboardingStep(player, 5, "First Prestige")
	end
end

function AnalyticsTrackerService.AccumulateData(player, delta, balanceAfter, customFields)
	if not player then
		return
	end
	local amount = toInt(delta)
	if amount <= 0 then
		return
	end
	local now = os.time()
	dataAccum[player] = dataAccum[player] or {
		amount = 0,
		lastFlush = now,
		balanceAfter = 0,
		custom = nil,
	}
	local entry = dataAccum[player]
	entry.amount += amount
	entry.balanceAfter = toInt(balanceAfter)
	entry.custom = customFields
	if entry.amount >= AnalyticsConfig.DATA_FLUSH_THRESHOLD or (now - entry.lastFlush) >= AnalyticsConfig.DATA_FLUSH_INTERVAL_SEC then
		AnalyticsTrackerService.FlushData(player)
	end
end

function AnalyticsTrackerService.FlushData(player)
	local entry = dataAccum[player]
	if not entry or entry.amount <= 0 then
		return
	end
	AnalyticsTrackerService.LogEconomySource(
		player,
		"Data",
		entry.amount,
		entry.balanceAfter,
		Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		"DataProduction",
		entry.custom
	)
	entry.amount = 0
	entry.lastFlush = os.time()
end

function AnalyticsTrackerService.DebouncedTabEvent(player, tabName)
	if not player or typeof(tabName) ~= "string" then
		return false
	end
	local now = os.clock()
	tabDebounce[player] = tabDebounce[player] or {}
	local last = tabDebounce[player][tabName] or 0
	if (now - last) < AnalyticsConfig.UI_EVENT_DEBOUNCE_SEC then
		return false
	end
	tabDebounce[player][tabName] = now
	return true
end

function AnalyticsTrackerService.GetOrStartFunnel(player, funnelName)
	local key = getPlayerKey(player)
	if not key then
		return nil
	end
	funnelSessions[key] = funnelSessions[key] or {}
	if funnelSessions[key][funnelName] then
		return funnelSessions[key][funnelName]
	end
	return AnalyticsTrackerService.StartFunnelSession(player, funnelName)
end

return AnalyticsTrackerService
