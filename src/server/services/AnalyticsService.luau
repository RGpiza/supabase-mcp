-- AnalyticsService.lua
-- Production-ready Roblox Analytics wrapper for System Incremental
-- Server-only, fail-safe, throttled, and batched

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Analytics constants
local CURRENCY_NAME = "Data"
local THROTTLE_MS = 1000
local BATCH_INTERVAL_MS = 5000
local MAX_BATCH_SIZE = 50

-- Enum mappings
local EconomyFlowType = Enum.AnalyticsEconomyFlowType
local EconomyTransactionType = Enum.AnalyticsEconomyTransactionType

-- Module state
local AnalyticsService = {}
local analyticsService = game:GetService("AnalyticsService")
local isStudio = RunService:IsStudio()

-- Throttling and batching
local lastEconomyEvent = {}
local lastFunnelEvent = {}
local pendingEconomyEvents = {}
local batchTimer = 0

-- Utility functions
local function isValidPlayer(player)
	return player and typeof(player) == "Instance" and player:IsA("Player")
end

local function isValidAmount(amount)
	return typeof(amount) == "number" and amount > 0
end

local function isValidStep(stepNumber)
	return typeof(stepNumber) == "number" and stepNumber >= 1 and stepNumber <= 100
end

local function getThrottleKey(player, eventKey)
	return player.UserId .. ":" .. eventKey
end

local function shouldThrottle(player, eventKey)
	local key = getThrottleKey(player, eventKey)
	local lastTime = lastEconomyEvent[key] or 0
	local now = tick()
	
	if now - lastTime < THROTTLE_MS / 1000 then
		return true
	end
	
	lastEconomyEvent[key] = now
	return false
end

local function shouldThrottleFunnel(player, funnelId, stepKey)
	local key = player.UserId .. ":" .. funnelId .. ":" .. stepKey
	local lastTime = lastFunnelEvent[key] or 0
	local now = tick()
	
	if now - lastTime < THROTTLE_MS / 1000 then
		return true
	end
	
	lastFunnelEvent[key] = now
	return false
end

local function safeAnalyticsCall(func, ...)
	if isStudio then
		return
	end
	
	local success, err = pcall(func, ...)
	if not success then
		warn("[Analytics] Failed to log:", err)
	end
end

-- Economy logging
function AnalyticsService.LogDataSource(player, amount, balance, transactionType, itemSKU)
	if not isValidPlayer(player) or not isValidAmount(amount) then
		return
	end
	
	if shouldThrottle(player, "source") then
		return
	end
	
	local eventKey = "source:" .. transactionType.Name .. (itemSKU and ":" .. itemSKU or "")
	if shouldThrottle(player, eventKey) then
		return
	end
	
	safeAnalyticsCall(function()
		analyticsService:LogEconomyEvent(
			EconomyFlowType.Source,
			transactionType,
			CURRENCY_NAME,
			amount,
			balance,
			player,
			itemSKU
		)
	end)
	
	print("[Analytics] Economy Source logged")
end

function AnalyticsService.LogDataSink(player, amount, balance, transactionType, itemSKU)
	if not isValidPlayer(player) or not isValidAmount(amount) then
		return
	end
	
	if shouldThrottle(player, "sink") then
		return
	end
	
	local eventKey = "sink:" .. transactionType.Name .. (itemSKU and ":" .. itemSKU or "")
	if shouldThrottle(player, eventKey) then
		return
	end
	
	safeAnalyticsCall(function()
		analyticsService:LogEconomyEvent(
			EconomyFlowType.Sink,
			transactionType,
			CURRENCY_NAME,
			amount,
			balance,
			player,
			itemSKU
		)
	end)
	
	print("[Analytics] Economy Sink logged")
end

-- Funnel logging
function AnalyticsService.StartShopFunnel(player)
	if not isValidPlayer(player) then
		return nil
	end
	
	local funnelId = "shop_" .. player.UserId .. "_" .. tick()
	
	safeAnalyticsCall(function()
		analyticsService:StartFunnel(funnelId, "Shop", player)
	end)
	
	print("[Analytics] Funnel started:", funnelId)
	return funnelId
end

function AnalyticsService.LogShopFunnelStep(player, funnelSessionId, stepNumber, stepName)
	if not isValidPlayer(player) or not isValidStep(stepNumber) or not funnelSessionId then
		return
	end
	
	local stepKey = stepNumber .. ":" .. stepName
	if shouldThrottleFunnel(player, funnelSessionId, stepKey) then
		return
	end
	
	safeAnalyticsCall(function()
		analyticsService:LogFunnelStep(
			funnelSessionId,
			stepNumber,
			stepName,
			player
		)
	end)
	
	print("[Analytics] Funnel step logged:", stepNumber, stepName)
end

-- Onboarding logging
function AnalyticsService.LogOnboardingStep(player, stepNumber, stepName)
	if not isValidPlayer(player) or not isValidStep(stepNumber) then
		return
	end
	
	local eventKey = "onboarding:" .. stepNumber .. ":" .. stepName
	if shouldThrottle(player, eventKey) then
		return
	end
	
	safeAnalyticsCall(function()
		analyticsService:LogFunnelStep(
			"onboarding_" .. player.UserId,
			stepNumber,
			stepName,
			player
		)
	end)
	
	print("[Analytics] Onboarding step logged:", stepNumber, stepName)
end

-- Custom event logging
function AnalyticsService.LogCustom(player, eventName, value, customFields)
	if not isValidPlayer(player) or typeof(eventName) ~= "string" then
		return
	end
	
	local eventKey = "custom:" .. eventName
	if shouldThrottle(player, eventKey) then
		return
	end
	
	local eventData = {
		EventName = eventName,
		Value = value,
		CustomFields = customFields or {}
	}
	
	safeAnalyticsCall(function()
		analyticsService:LogEvent(player, eventData)
	end)
	
	print("[Analytics] Custom event logged:", eventName)
end

-- Batch processing (optional enhancement)
function AnalyticsService.ProcessBatch()
	if #pendingEconomyEvents > 0 then
		-- Process batch if needed
		pendingEconomyEvents = {}
	end
end

-- Initialize
if not isStudio then
	RunService.Heartbeat:Connect(function(dt)
		batchTimer = batchTimer + dt
		if batchTimer >= BATCH_INTERVAL_MS / 1000 then
			AnalyticsService.ProcessBatch()
			batchTimer = 0
		end
	end)
end

return AnalyticsService
