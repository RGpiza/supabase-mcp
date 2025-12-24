local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local AnalyticsService = game:GetService("AnalyticsService")
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

local DeveloperDashboardService = {}

-- Configuration
local CONFIG = {
	-- Only available in Studio
	ENABLED = RunService:IsStudio(),
	
	-- Analytics query settings
	ANALYTICS_WINDOW_HOURS = 24,
	ANALYTICS_LIMIT = 100,
	
	-- Cache settings
	ERROR_CACHE_TTL = 300, -- 5 minutes
}

-- Internal state
local cachedErrors = {}
local lastCacheTime = 0
local isFetching = false

-- Utility functions
local function log(level, message, ...)
	if DebugConfig then
		if level == "error" then
			DebugConfig.Error(message, ...)
		elseif level == "warn" then
			DebugConfig.Warn(message, ...)
		else
			DebugConfig.Log(message, ...)
		end
	end
end

local function isCacheValid()
	return cachedErrors and (tick() - lastCacheTime) < CONFIG.ERROR_CACHE_TTL
end

-- Analytics query functions
local function queryAnalyticsErrors()
	if not CONFIG.ENABLED then
		return {}
	end
	
	local now = os.time()
	local startTime = now - (CONFIG.ANALYTICS_WINDOW_HOURS * 3600)
	
	local query = {
		eventName = "production_error",
		startTime = startTime,
		endTime = now,
		limit = CONFIG.ANALYTICS_LIMIT,
	}
	
	local success, result = pcall(function()
		return AnalyticsService:QueryCustomEvents(query)
	end)
	
	if success and result and result.events then
		return result.events
	else
		log("warn", "Failed to query AnalyticsService:", result)
		return {}
	end
end

-- Error aggregation and formatting
local function aggregateErrors(events)
	local aggregated = {}
	local serviceCounts = {}
	local errorTypeCounts = {}
	
	for _, event in ipairs(events) do
		local eventData = event.eventData or {}
		local key = string.format("%s:%s:%s", 
			eventData.errorType or "unknown",
			eventData.serviceName or "unknown", 
			eventData.shortMessage or "unknown"
		)
		
		if not aggregated[key] then
			aggregated[key] = {
				errorType = eventData.errorType,
				serviceName = eventData.serviceName,
				shortMessage = eventData.shortMessage,
				severity = eventData.severity or 1,
				totalCount = 0,
				uniquePlayers = {},
				lastOccurrence = 0,
				places = {},
			}
		end
		
		local entry = aggregated[key]
		entry.totalCount = entry.totalCount + (eventData.occurrenceCount or 1)
		entry.lastOccurrence = math.max(entry.lastOccurrence, event.timestamp or 0)
		
		-- Track unique players
		if eventData.playerUserId and eventData.playerUserId > 0 then
			entry.uniquePlayers[eventData.playerUserId] = true
		end
		
		-- Track places
		if eventData.gamePlaceId then
			entry.places[eventData.gamePlaceId] = true
		end
		
		-- Update service counts
		if eventData.serviceName then
			serviceCounts[eventData.serviceName] = (serviceCounts[eventData.serviceName] or 0) + 1
		end
		
		-- Update error type counts
		if eventData.errorType then
			errorTypeCounts[eventData.errorType] = (errorTypeCounts[eventData.errorType] or 0) + 1
		end
	end
	
	-- Convert to array and sort by count
	local result = {}
	for _, entry in pairs(aggregated) do
		entry.uniquePlayerCount = #table.keys(entry.uniquePlayers)
		entry.placeCount = #table.keys(entry.places)
		table.insert(result, entry)
	end
	
	table.sort(result, function(a, b)
		return a.totalCount > b.totalCount
	end)
	
	return result, serviceCounts, errorTypeCounts
end

-- Fetch and cache errors
local function fetchErrors()
	if isFetching or not CONFIG.ENABLED then
		return cachedErrors
	end
	
	isFetching = true
	
	task.spawn(function()
		local events = queryAnalyticsErrors()
		cachedErrors, cachedServiceCounts, cachedErrorTypeCounts = aggregateErrors(events)
		lastCacheTime = tick()
		isFetching = false
		
		log("info", "Fetched", #cachedErrors, "production errors from Analytics")
	end)
	
	return cachedErrors
end

-- Public API functions
function DeveloperDashboardService.GetRecentErrors()
	if not CONFIG.ENABLED then
		return {}
	end
	
	if not isCacheValid() then
		return fetchErrors()
	end
	
	return cachedErrors
end

function DeveloperDashboardService.GetServiceCounts()
	if not CONFIG.ENABLED then
		return {}
	end
	
	if not isCacheValid() then
		fetchErrors()
	end
	
	return cachedServiceCounts or {}
end

function DeveloperDashboardService.GetErrorTypeCounts()
	if not CONFIG.ENABLED then
		return {}
	end
	
	if not isCacheValid() then
		fetchErrors()
	end
	
	return cachedErrorTypeCounts or {}
end

function DeveloperDashboardService.GetErrorSummary()
	if not CONFIG.ENABLED then
		return {
			totalErrors = 0,
			uniqueServices = 0,
			mostProblematicService = nil,
			recentErrors = {},
		}
	end
	
	local errors = DeveloperDashboardService.GetRecentErrors()
	local serviceCounts = DeveloperDashboardService.GetServiceCounts()
	
	local summary = {
		totalErrors = #errors,
		uniqueServices = #table.keys(serviceCounts),
		mostProblematicService = nil,
		recentErrors = {},
	}
	
	-- Find most problematic service
	local maxCount = 0
	for service, count in pairs(serviceCounts) do
		if count > maxCount then
			maxCount = count
			summary.mostProblematicService = service
		end
	end
	
	-- Get recent errors (last 10)
	for i = 1, math.min(10, #errors) do
		table.insert(summary.recentErrors, errors[i])
	end
	
	return summary
end

function DeveloperDashboardService.PrintErrorReport()
	if not CONFIG.ENABLED then
		print("Developer Dashboard: Not available in published game")
		return
	end
	
	local summary = DeveloperDashboardService.GetErrorSummary()
	
	print("=== System Incremental Production Error Report ===")
	print(string.format("Total Errors: %d", summary.totalErrors))
	print(string.format("Unique Services: %d", summary.uniqueServices))
	print(string.format("Most Problematic Service: %s", summary.mostProblematicService or "None"))
	print("")
	
	if summary.totalErrors > 0 then
		print("Recent Errors:")
		for i, error in ipairs(summary.recentErrors) do
			local severityText = ""
			if error.severity == 4 then severityText = "🔴 CRITICAL"
			elseif error.severity == 3 then severityText = "🟠 HIGH"
			elseif error.severity == 2 then severityText = "🟡 MEDIUM"
			else severityText = "🔵 LOW" end
			
			print(string.format("  %d. %s - %s", i, severityText, error.errorType))
			print(string.format("     Service: %s", error.serviceName))
			print(string.format("     Message: %s", error.shortMessage))
			print(string.format("     Count: %d, Players: %d", error.totalCount, error.uniquePlayerCount))
			print("")
		end
	else
		print("No production errors found in the last 24 hours.")
	end
end

-- Developer mode helpers
function DeveloperDashboardService.EnableDevMode()
	if RunService:IsStudio() then
		CONFIG.ENABLED = true
		log("info", "Developer Dashboard enabled")
	end
end

function DeveloperDashboardService.DisableDevMode()
	CONFIG.ENABLED = false
	log("info", "Developer Dashboard disabled")
end

function DeveloperDashboardService.RefreshCache()
	if CONFIG.ENABLED then
		lastCacheTime = 0
		cachedErrors = {}
		log("info", "Error cache cleared, will refresh on next access")
	end
end

-- Remote function for Studio clients
function DeveloperDashboardService.GetDashboardData()
	if not CONFIG.ENABLED then
		return {
			enabled = false,
			message = "Developer Dashboard only available in Studio"
		}
	end
	
	local summary = DeveloperDashboardService.GetErrorSummary()
	
	return {
		enabled = true,
		summary = summary,
		timestamp = os.time(),
		cacheAge = tick() - lastCacheTime,
	}
end

-- Initialize service
function DeveloperDashboardService.OnStart()
	if CONFIG.ENABLED then
		log("info", "DeveloperDashboardService initialized (Studio mode)")
		-- Auto-fetch on startup
		task.delay(2, function()
			DeveloperDashboardService.GetRecentErrors()
		end)
	else
		log("info", "DeveloperDashboardService disabled (published game)")
	end
end

return DeveloperDashboardService
