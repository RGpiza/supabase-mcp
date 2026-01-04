-- AnalyticsService.lua
-- Production-ready Roblox Analytics wrapper
-- Server-only, fail-safe, throttled, and batched

local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")

local AnalyticsServiceModule = {}

-- Configuration
local CURRENCY_NAME = "Data"
local STUDIO_MODE = game:GetService("RunService"):IsStudio()
local THROTTLE_WINDOW = 1  -- seconds
local BATCH_WINDOW = 0.5    -- seconds

-- State
local playerLastEvents = {}  -- player -> {eventName -> lastTime}
local pendingEconomyEvents = {}  -- {player, type, amount, balance, transactionType, itemSKU}
local lastBatchTime = 0

-- Helper: Validate player
local function isValidPlayer(player)
	return player and player:IsA("Player") and player.Parent == Players
end

-- Helper: Throttle repeated events
local function shouldThrottle(player, eventName)
	local now = tick()
	local playerEvents = playerLastEvents[player]
	if not playerEvents then
		playerLastEvents[player] = {}
		playerEvents = playerLastEvents[player]
	end
	local last = playerEvents[eventName]
	if last and (now - last) < THROTTLE_WINDOW then
		return true
	end
	playerEvents[eventName] = now
	return false
end

-- Helper: Log safely
local function safeLog(msg)
	if not STUDIO_MODE then
		print("[Analytics] " .. msg)
	end
end

-- Helper: Get transaction type enum
local function getTransactionType(name)
	local t = Enum.AnalyticsEconomyTransactionType
	if name == "Purchase" then return t.Purchase end
	if name == "Sale" then return t.Sale end
	if name == "Reward" then return t.Reward end
	if name == "Consumed" then return t.Consumed end
	if name == "Granted" then return t.Granted end
	return t.Purchase  -- default
end

-- Economy: Source
function AnalyticsServiceModule.LogDataSource(player, amount, balance, transactionType, itemSKU)
	if STUDIO_MODE then return end
	if not isValidPlayer(player) then return end
	if amount <= 0 then return end
	
	if shouldThrottle(player, "DataSource") then return end
	
	local tType = getTransactionType(transactionType or "Reward")
	
	-- Batch economy events
	table.insert(pendingEconomyEvents, {
		player = player,
		type = "Source",
		amount = amount,
		balance = balance,
		transactionType = tType,
		itemSKU = itemSKU
	})
	
	safeLog("Economy Source logged")
end

-- Economy: Sink
function AnalyticsServiceModule.LogDataSink(player, amount, balance, transactionType, itemSKU)
	if STUDIO_MODE then return end
	if not isValidPlayer(player) then return end
	if amount <= 0 then return end
	
	if shouldThrottle(player, "DataSink") then return end
	
	local tType = getTransactionType(transactionType or "Purchase")
	
	table.insert(pendingEconomyEvents, {
		player = player,
		type = "Sink",
		amount = amount,
		balance = balance,
		transactionType = tType,
		itemSKU = itemSKU
	})
	
	safeLog("Economy Sink logged")
end

-- Funnel: Start
function AnalyticsServiceModule.StartShopFunnel(player)
	if STUDIO_MODE then return "" end
	if not isValidPlayer(player) then return "" end
	
	local funnelId = "funnel_" .. player.UserId .. "_" .. tick()
	
	-- Immediate funnel start
	pcall(function()
		AnalyticsService:ReportFunnelStep(player, funnelId, 1, "Shop Opened")
	end)
	
	safeLog("Funnel started")
	return funnelId
end

-- Funnel: Step
function AnalyticsServiceModule.LogShopFunnelStep(player, funnelSessionId, stepNumber, stepName)
	if STUDIO_MODE then return end
	if not isValidPlayer(player) then return end
	if not funnelSessionId or stepNumber < 1 or stepNumber > 10 then return end
	
	if shouldThrottle(player, "FunnelStep") then return end
	
	pcall(function()
		AnalyticsService:ReportFunnelStep(player, funnelSessionId, stepNumber, stepName)
	end)
	
	safeLog("Funnel step logged")
end

-- Custom Event
function AnalyticsServiceModule.LogCustom(player, eventName, value, customFields)
	if STUDIO_MODE then return end
	if not isValidPlayer(player) then return end
	if not eventName or eventName == "" then return end
	
	if shouldThrottle(player, "Custom_" .. eventName) then return end
	
	local fields = customFields or {}
	fields["event"] = eventName
	fields["value"] = value or 0
	
	pcall(function()
		AnalyticsService:ReportCustomEvent(player, eventName, fields)
	end)
	
	safeLog("Custom event logged: " .. eventName)
end

-- Batch flush logic (called by InitManager or heartbeat)
function AnalyticsServiceModule.FlushPendingEvents()
	if STUDIO_MODE then return end
	local now = tick()
	if now - lastBatchTime < BATCH_WINDOW then return end
	lastBatchTime = now
	
	for i = #pendingEconomyEvents, 1, -1 do
		local ev = pendingEconomyEvents[i]
		local flowType = Enum.AnalyticsEconomyFlowType.Source
		if ev.type == "Sink" then flowType = Enum.AnalyticsEconomyFlowType.Sink end
		
		pcall(function()
			AnalyticsService:ReportEconomyEvent(ev.player, CURRENCY_NAME, ev.amount, ev.balance, flowType, ev.transactionType, ev.itemSKU)
		end)
		
		table.remove(pendingEconomyEvents, i)
	end
end

-- InitManager integration: register heartbeat for batch flushing
function AnalyticsServiceModule.OnStart()
	-- Set up periodic batch flush
	game:GetService("RunService"):BindToRenderStep("AnalyticsFlush", Enum.RenderPriority.Last.Value, function()
		AnalyticsServiceModule.FlushPendingEvents()
	end)
	
	safeLog("AnalyticsService started")
end

function AnalyticsServiceModule.OnStop()
	-- Cleanup
	game:GetService("RunService"):UnbindFromRenderStep("AnalyticsFlush")
	safeLog("AnalyticsService stopped")
end

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	playerLastEvents[player] = nil
	-- Note: pending events for this player will be dropped (safe)
end)

return AnalyticsServiceModule
