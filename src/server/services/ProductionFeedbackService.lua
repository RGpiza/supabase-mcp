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

-- Import GitHubIssueCreator for automatic issue creation
local GitHubIssueCreator = nil
do
	local ok, mod = pcall(function()
		return require(script.Parent.GitHubIssueCreator)
	end)
	if ok and type(mod) == "table" then
		GitHubIssueCreator = mod
	end
end

local ProductionFeedbackService = {}

-- Configuration
local CONFIG = {
	-- Only run in published games
	ENABLED = game.PlaceId ~= 0 and not RunService:IsStudio(),
	
	-- Throttling and deduplication
	THROTTLE_WINDOW = 60, -- seconds
	BATCH_INTERVAL = 30, -- seconds
	MAX_BATCH_SIZE = 50,
	
	-- Severity levels
	SEVERITY = {
		LOW = 1,
		MEDIUM = 2,
		HIGH = 3,
		CRITICAL = 4,
	},
	
	-- Error types
	ERROR_TYPES = {
		SERVER_ERROR = "server_error",
		REMOTE_MISUSE = "remote_misuse",
		DATASTORE_FAILURE = "datastore_failure",
		ANTICHEAT_ESCALATION = "anticheat_escalation",
		ECONOMY_ROLLBACK = "economy_rollback",
		SERVICE_CRASH = "service_crash",
	},
	
	-- Webhook configuration (optional)
	WEBHOOK_URL = "", -- Set this to enable Discord/webhook delivery
	WEBHOOK_BATCH_SIZE = 10,
	WEBHOOK_RETRY_ATTEMPTS = 3,
}

-- Internal state
local errorCache = {}
local errorCounts = {}
local batchQueue = {}
local lastBatchTime = 0
local isBatching = false

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

local function getGameInfo()
	return {
		placeId = game.PlaceId,
		jobId = game.JobId,
		gameId = game.GameId,
		isStudio = RunService:IsStudio(),
	}
end

local function generateErrorKey(errorType, serviceName, shortMessage)
	return string.format("%s:%s:%s", errorType, serviceName, shortMessage)
end

local function shouldThrottle(errorKey, severity)
	local now = tick()
	local lastSeen = errorCache[errorKey]
	
	if not lastSeen then
		return false
	end
	
	-- Critical errors bypass throttling
	if severity >= CONFIG.SEVERITY.CRITICAL then
		return false
	end
	
	-- Check throttle window
	if now - lastSeen < CONFIG.THROTTLE_WINDOW then
		return true
	end
	
	return false
end

local function incrementErrorCount(errorKey)
	errorCounts[errorKey] = (errorCounts[errorKey] or 0) + 1
end

local function createErrorReport(errorType, serviceName, shortMessage, severity, playerUserId)
	local gameInfo = getGameInfo()
	local errorKey = generateErrorKey(errorType, serviceName, shortMessage)
	
	local report = {
		gamePlaceId = gameInfo.placeId,
		serverJobId = gameInfo.jobId,
		gameId = gameInfo.gameId,
		playerUserId = playerUserId or 0,
		serviceName = serviceName,
		errorType = errorType,
		shortMessage = shortMessage,
		severity = severity,
		timestamp = os.time(),
		occurrenceCount = errorCounts[errorKey] or 1,
		isStudio = gameInfo.isStudio,
	}
	
	return report
end

-- Analytics delivery
local function sendToAnalytics(report)
	if not CONFIG.ENABLED then
		return
	end
	
	local success, err = pcall(function()
		AnalyticsService:ReportCustomEvent("production_error", {
			errorType = report.errorType,
			serviceName = report.serviceName,
			severity = report.severity,
			occurrenceCount = report.occurrenceCount,
			gamePlaceId = report.gamePlaceId,
			serverJobId = report.serverJobId,
			playerUserId = report.playerUserId,
			shortMessage = report.shortMessage,
		})
	end)
	
	if not success then
		log("warn", "Failed to send to AnalyticsService", err)
	end
end

-- Webhook delivery
local function sendToWebhook(reports)
	if not CONFIG.ENABLED or not CONFIG.WEBHOOK_URL or #reports == 0 then
		return
	end
	
	local payload = {
		content = nil,
		embeds = {
			{
				title = "System Incremental Production Errors",
				color = 16711680, -- Red
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
				fields = {},
				footer = {
					text = string.format("Place: %d | Job: %s", reports[1].gamePlaceId, reports[1].serverJobId)
				}
			}
		}
	}
	
	-- Add error details
	for i, report in ipairs(reports) do
		if i > CONFIG.WEBHOOK_BATCH_SIZE then
			break
		end
		
		local severityText = ""
		if report.severity == CONFIG.SEVERITY.CRITICAL then
			severityText = "🔴 CRITICAL"
		elseif report.severity == CONFIG.SEVERITY.HIGH then
			severityText = "🟠 HIGH"
		elseif report.severity == CONFIG.SEVERITY.MEDIUM then
			severityText = "🟡 MEDIUM"
		else
			severityText = "🔵 LOW"
		end
		
		table.insert(payload.embeds[1].fields, {
			name = string.format("%s - %s", severityText, report.errorType),
			value = string.format("**Service:** %s\n**Message:** %s\n**Count:** %d\n**Player:** %s", 
				report.serviceName, report.shortMessage, report.occurrenceCount, 
				report.playerUserId > 0 and tostring(report.playerUserId) or "N/A"),
			inline = false
		})
	end
	
	local jsonPayload = HttpService:JSONEncode(payload)
	
	-- Send with retry logic
	local attempts = 0
	while attempts < CONFIG.WEBHOOK_RETRY_ATTEMPTS do
		attempts += 1
		local success, response = pcall(function()
			return HttpService:PostAsync(CONFIG.WEBHOOK_URL, jsonPayload, Enum.HttpContentType.ApplicationJson)
		end)
		
		if success then
			log("info", "Webhook sent successfully", #reports, "errors")
			break
		else
			log("warn", "Webhook attempt", attempts, "failed:", response)
			if attempts < CONFIG.WEBHOOK_RETRY_ATTEMPTS then
				task.wait(2 ^ attempts) -- Exponential backoff
			end
		end
	end
end

-- Batch processing
local function processBatch()
	if isBatching or #batchQueue == 0 then
		return
	end
	
	isBatching = true
	local batch = table.move(batchQueue, 1, math.min(#batchQueue, CONFIG.MAX_BATCH_SIZE), 1, {})
	table.clear(batchQueue)
	
	-- Send to webhook
	sendToWebhook(batch)
	
	-- Send individual reports to analytics
	for _, report in ipairs(batch) do
		sendToAnalytics(report)
	end
	
	isBatching = false
	lastBatchTime = tick()
end

-- Main error reporting function
function ProductionFeedbackService.ReportError(errorType, serviceName, shortMessage, severity, playerUserId)
	if not CONFIG.ENABLED then
		return
	end
	
	-- Validate inputs
	if not errorType or not serviceName or not shortMessage or not severity then
		log("warn", "Invalid error report parameters")
		return
	end
	
	if not table.find(CONFIG.ERROR_TYPES, errorType) then
		log("warn", "Unknown error type:", errorType)
		return
	end
	
	if severity < CONFIG.SEVERITY.LOW or severity > CONFIG.SEVERITY.CRITICAL then
		log("warn", "Invalid severity level:", severity)
		return
	end
	
	local errorKey = generateErrorKey(errorType, serviceName, shortMessage)
	
	-- Check throttling
	if shouldThrottle(errorKey, severity) then
		incrementErrorCount(errorKey)
		return
	end
	
	-- Update cache and counts
	errorCache[errorKey] = tick()
	incrementErrorCount(errorKey)
	
	-- Create and queue report
	local report = createErrorReport(errorType, serviceName, shortMessage, severity, playerUserId)
	table.insert(batchQueue, report)
	
	-- Process batch if enough errors or critical error
	if #batchQueue >= CONFIG.MAX_BATCH_SIZE or severity >= CONFIG.SEVERITY.CRITICAL then
		processBatch()
	elseif tick() - lastBatchTime > CONFIG.BATCH_INTERVAL then
		processBatch()
	end
end

-- Service-specific convenience functions
function ProductionFeedbackService.ReportServerError(serviceName, shortMessage, playerUserId)
	ProductionFeedbackService.ReportError(CONFIG.ERROR_TYPES.SERVER_ERROR, serviceName, shortMessage, CONFIG.SEVERITY.HIGH, playerUserId)
end

function ProductionFeedbackService.ReportRemoteMisuse(serviceName, shortMessage, playerUserId)
	ProductionFeedbackService.ReportError(CONFIG.ERROR_TYPES.REMOTE_MISUSE, serviceName, shortMessage, CONFIG.SEVERITY.MEDIUM, playerUserId)
end

function ProductionFeedbackService.ReportDataStoreFailure(serviceName, shortMessage, playerUserId)
	ProductionFeedbackService.ReportError(CONFIG.ERROR_TYPES.DATASTORE_FAILURE, serviceName, shortMessage, CONFIG.SEVERITY.HIGH, playerUserId)
end

function ProductionFeedbackService.ReportAntiCheatEscalation(serviceName, shortMessage, playerUserId)
	ProductionFeedbackService.ReportError(CONFIG.ERROR_TYPES.ANTICHEAT_ESCALATION, serviceName, shortMessage, CONFIG.SEVERITY.MEDIUM, playerUserId)
end

function ProductionFeedbackService.ReportEconomyRollback(serviceName, shortMessage, playerUserId)
	ProductionFeedbackService.ReportError(CONFIG.ERROR_TYPES.ECONOMY_ROLLBACK, serviceName, shortMessage, CONFIG.SEVERITY.CRITICAL, playerUserId)
end

function ProductionFeedbackService.ReportServiceCrash(serviceName, shortMessage, playerUserId)
	ProductionFeedbackService.ReportError(CONFIG.ERROR_TYPES.SERVICE_CRASH, serviceName, shortMessage, CONFIG.SEVERITY.CRITICAL, playerUserId)
end

-- Developer mode helpers
function ProductionFeedbackService.GetRecentErrors()
	if RunService:IsStudio() then
		return batchQueue
	else
		return {}
	end
end

function ProductionFeedbackService.EnableDevMode()
	if RunService:IsStudio() then
		CONFIG.ENABLED = true
		log("info", "Production feedback dev mode enabled")
	end
end

function ProductionFeedbackService.DisableDevMode()
	CONFIG.ENABLED = false
	log("info", "Production feedback disabled")
end

-- Integration with existing services
function ProductionFeedbackService.WrapServiceCall(serviceName, func)
	return function(...)
		local success, result = pcall(func, ...)
		if not success then
			ProductionFeedbackService.ReportServerError(serviceName, tostring(result))
			-- Automatically create GitHub issue for critical server errors
			if GitHubIssueCreator then
				task.spawn(function()
					GitHubIssueCreator.HandleProductionError(
						"SERVER_ERROR",
						serviceName,
						tostring(result),
						CONFIG.SEVERITY.CRITICAL,
						0, -- No player for server errors
						1
					)
				end)
			end
			return false, result
		end
		return success, result
	end
end

-- Automatic GitHub issue creation for critical errors
function ProductionFeedbackService.CreateGitHubIssue(errorType, serviceName, shortMessage, severity, playerUserId, occurrenceCount)
	if not GitHubIssueCreator then
		log("warn", "GitHubIssueCreator not available")
		return false, "GitHub integration not configured"
	end
	
	-- Only create issues for critical/high severity errors
	if severity < CONFIG.SEVERITY.HIGH then
		return false, "Severity too low for GitHub issue"
	end
	
	-- Create GitHub issue
	local success, result = GitHubIssueCreator.CreateIssue(
		errorType,
		serviceName,
		shortMessage,
		severity,
		playerUserId,
		occurrenceCount
	)
	
	if success then
		log("info", "GitHub issue created for production error:", errorType, serviceName)
	else
		log("warn", "Failed to create GitHub issue:", result)
	end
	
	return success, result
end

-- Initialize service
function ProductionFeedbackService.OnStart()
	log("info", "ProductionFeedbackService initialized")
	log("info", "Enabled:", CONFIG.ENABLED)
	log("info", "PlaceId:", game.PlaceId)
	log("info", "JobId:", game.JobId)
	
	-- Start batch processing loop
	task.spawn(function()
		while true do
			task.wait(CONFIG.BATCH_INTERVAL)
			processBatch()
		end
	end)
	
	-- Cleanup old cache entries periodically
	task.spawn(function()
		while true do
			task.wait(300) -- 5 minutes
			local now = tick()
			for key, lastSeen in pairs(errorCache) do
				if now - lastSeen > CONFIG.THROTTLE_WINDOW * 2 then
					errorCache[key] = nil
					errorCounts[key] = nil
				end
			end
		end
	end)
end

return ProductionFeedbackService
