local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
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

-- Import ProductionFeedbackService for integration
local ProductionFeedbackService = nil
do
	local ok, mod = pcall(function()
		return require(script.Parent.ProductionFeedbackService)
	end)
	if ok and type(mod) == "table" then
		ProductionFeedbackService = mod
	end
end

local GitHubIssueCreator = {}

-- Configuration
local CONFIG = {
	-- Only run in published games
	ENABLED = game.PlaceId ~= 0 and not RunService:IsStudio(),
	
	-- GitHub integration
	MIDDLEWARE_ENDPOINT = "", -- Set this to enable GitHub issue creation
	RETRY_ATTEMPTS = 3,
	RETRY_DELAY = 2, -- seconds
	
	-- Trigger conditions
	MIN_SEVERITY_FOR_ISSUE = 3, -- HIGH (3) or CRITICAL (4)
	MIN_OCCURRENCE_COUNT = 5, -- Same error must occur this many times
	SHORT_WINDOW_MINUTES = 10, -- Within this time window
	
	-- Throttling
	ISSUE_COOLDOWN_MINUTES = 60, -- Don't create duplicate issues within this time
	MAX_ISSUES_PER_HOUR = 10, -- Rate limit
	
	-- Error categories
	ERROR_CATEGORIES = {
		SERVER_ERROR = "server",
		REMOTE_MISUSE = "network",
		DATASTORE_FAILURE = "datastore",
		ANTICHEAT_ESCALATION = "security",
		ECONOMY_ROLLBACK = "economy",
		SERVICE_CRASH = "server",
	},
	
	-- System names mapping
	SYSTEM_NAMES = {
		["UpgradeService"] = "upgrades",
		["PrestigeService"] = "prestige",
		["ProductionService"] = "production",
		["PlayerDataService"] = "datastore",
		["AntiCheatService"] = "security",
		["RemoteRouter"] = "network",
		["MonetizationService"] = "economy",
		["LeaderboardService"] = "leaderboards",
		["SocialGoalsService"] = "social",
	},
}

-- Internal state
local issueCache = {}
local issueCounters = {}
local lastIssueTime = 0
local issuesThisHour = 0
local pendingIssues = {}

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

local function getSystemName(serviceName)
	return CONFIG.SYSTEM_NAMES[serviceName] or serviceName:lower()
end

local function getErrorCategory(errorType)
	return CONFIG.ERROR_CATEGORIES[errorType] or "general"
end

local function generateErrorSignature(errorType, serviceName, shortMessage)
	return string.format("%s:%s:%s", errorType, serviceName, shortMessage)
end

local function shouldCreateIssue(errorType, serviceName, shortMessage, severity, occurrenceCount)
	if not CONFIG.ENABLED then
		return false, "Disabled in Studio or not configured"
	end
	
	if not CONFIG.MIDDLEWARE_ENDPOINT then
		return false, "GitHub middleware endpoint not configured"
	end
	
	-- Check severity threshold
	if severity < CONFIG.MIN_SEVERITY_FOR_ISSUE then
		return false, string.format("Severity %d below threshold %d", severity, CONFIG.MIN_SEVERITY_FOR_ISSUE)
	end
	
	-- Check occurrence count for non-critical errors
	if severity < 4 and occurrenceCount < CONFIG.MIN_OCCURRENCE_COUNT then
		return false, string.format("Occurrence count %d below threshold %d", occurrenceCount, CONFIG.MIN_OCCURRENCE_COUNT)
	end
	
	-- Check cooldown
	local now = tick()
	if now - lastIssueTime < (CONFIG.ISSUE_COOLDOWN_MINUTES * 60) then
		return false, "Issue cooldown active"
	end
	
	-- Check rate limit
	local hourAgo = now - 3600
	if hourAgo > 0 then
		-- Clean up old counters (this would need to be tracked separately)
	end
	
	if issuesThisHour >= CONFIG.MAX_ISSUES_PER_HOUR then
		return false, "Hourly issue limit reached"
	end
	
	-- Check for existing issue
	local signature = generateErrorSignature(errorType, serviceName, shortMessage)
	if issueCache[signature] and (now - issueCache[signature].lastReported) < (CONFIG.ISSUE_COOLDOWN_MINUTES * 60) then
		return false, "Recent issue exists for this error"
	end
	
	return true, "Issue creation allowed"
end

local function createIssuePayload(errorType, serviceName, shortMessage, severity, playerUserId, occurrenceCount)
	local gameInfo = getGameInfo()
	local systemName = getSystemName(serviceName)
	local category = getErrorCategory(errorType)
	
	-- Generate title
	local title = string.format("[LIVE BUG] %s — %s", systemName:upper(), shortMessage)
	if #title > 100 then
		title = title:sub(1, 97) .. "..."
	end
	
	-- Generate body
	local body = string.format([[
## Bug Report: %s

**Environment:**
- Place ID: %d
- Job ID: %s
- Game ID: %d
- Timestamp: %s UTC
- Player ID: %s

**Error Details:**
- System: %s
- Error Type: %s
- Category: %s
- Severity: %s
- Occurrence Count: %d

**Description:**
%s

**Reproduction Context:**
- Error occurred in live production environment
- This issue was automatically detected and reported
- No manual reproduction steps available

**Additional Notes:**
- This issue was created automatically by the Production Feedback Bridge
- Please investigate the root cause in the specified system
- Check for similar issues before working on a fix
]], 
		shortMessage,
		gameInfo.placeId,
		gameInfo.jobId,
		gameInfo.gameId,
		os.date("!%Y-%m-%d %H:%M:%S", os.time()),
		playerUserId and tostring(playerUserId) or "N/A",
		systemName,
		errorType,
		category,
		severity == 4 and "CRITICAL" or severity == 3 and "HIGH" or severity == 2 and "MEDIUM" or "LOW",
		occurrenceCount,
		shortMessage
	)
	
	-- Generate labels
	local labels = {
		"live",
		"bug",
		string.format("severity:%s", severity == 4 and "critical" or severity == 3 and "high" or "medium"),
		string.format("system:%s", systemName),
		string.format("category:%s", category),
	}
	
	return {
		title = title,
		body = body,
		labels = labels,
		assignees = {}, -- Optional: could be configured
		milestone = nil, -- Optional: could be configured
		errorSignature = generateErrorSignature(errorType, serviceName, shortMessage),
		gameInfo = gameInfo,
		timestamp = os.time(),
		severity = severity,
		occurrenceCount = occurrenceCount,
	}
end

local function sendToMiddleware(payload)
	if not CONFIG.ENABLED or not CONFIG.MIDDLEWARE_ENDPOINT then
		return false, "Middleware not configured"
	end
	
	local jsonPayload = HttpService:JSONEncode(payload)
	
	-- Send with retry logic
	local attempts = 0
	while attempts < CONFIG.RETRY_ATTEMPTS do
		attempts += 1
		local success, response = pcall(function()
			return HttpService:PostAsync(CONFIG.MIDDLEWARE_ENDPOINT, jsonPayload, Enum.HttpContentType.ApplicationJson)
		end)
		
		if success then
			log("info", "GitHub issue created successfully", payload.title)
			return true, response
		else
			log("warn", "Middleware attempt", attempts, "failed:", response)
			if attempts < CONFIG.RETRY_ATTEMPTS then
				task.wait(CONFIG.RETRY_DELAY ^ attempts) -- Exponential backoff
			end
		end
	end
	
	log("error", "Failed to create GitHub issue after", CONFIG.RETRY_ATTEMPTS, "attempts")
	return false, "All retry attempts failed"
end

local function updateIssueCache(signature, payload)
	issueCache[signature] = {
		lastReported = tick(),
		issueId = payload.issueId or "pending",
		occurrenceCount = payload.occurrenceCount,
	}
	
	-- Update counters
	issueCounters[signature] = (issueCounters[signature] or 0) + 1
	lastIssueTime = tick()
	issuesThisHour += 1
end

-- Main issue creation function
function GitHubIssueCreator.CreateIssue(errorType, serviceName, shortMessage, severity, playerUserId, occurrenceCount)
	if not CONFIG.ENABLED then
		return false, "GitHub issue creation disabled"
	end
	
	-- Validate inputs
	if not errorType or not serviceName or not shortMessage or not severity then
		log("warn", "Invalid issue creation parameters")
		return false, "Invalid parameters"
	end
	
	-- Check if issue should be created
	local shouldCreate, reason = shouldCreateIssue(errorType, serviceName, shortMessage, severity, occurrenceCount)
	if not shouldCreate then
		log("debug", "Issue creation skipped:", reason)
		return false, reason
	end
	
	-- Create payload
	local payload = createIssuePayload(errorType, serviceName, shortMessage, severity, playerUserId, occurrenceCount)
	
	-- Send to middleware
	local success, response = sendToMiddleware(payload)
	
	if success then
		-- Update cache and counters
		updateIssueCache(payload.errorSignature, payload)
		return true, "Issue created successfully"
	else
		log("error", "Failed to create GitHub issue:", response)
		return false, response
	end
end

-- Integration with ProductionFeedbackService
function GitHubIssueCreator.HandleProductionError(errorType, serviceName, shortMessage, severity, playerUserId, occurrenceCount)
	-- Only create issues for critical/high severity or repeated errors
	local shouldCreate, reason = shouldCreateIssue(errorType, serviceName, shortMessage, severity, occurrenceCount)
	
	if shouldCreate then
		local success, result = GitHubIssueCreator.CreateIssue(errorType, serviceName, shortMessage, severity, playerUserId, occurrenceCount)
		if success then
			log("info", "GitHub issue created for production error:", errorType, serviceName)
		else
			log("warn", "Failed to create GitHub issue:", result)
		end
		return success
	else
		log("debug", "GitHub issue skipped for:", errorType, reason)
		return false
	end
end

-- Manual issue creation for testing
function GitHubIssueCreator.CreateTestIssue()
	if not CONFIG.ENABLED then
		return false, "Test mode only available in published game"
	end
	
	return GitHubIssueCreator.CreateIssue(
		"SERVER_ERROR",
		"TestService",
		"This is a test issue for GitHub integration",
		4, -- CRITICAL
		123456789,
		1
	)
end

-- Configuration management
function GitHubIssueCreator.SetMiddlewareEndpoint(url)
	CONFIG.MIDDLEWARE_ENDPOINT = url
	log("info", "GitHub middleware endpoint configured")
end

function GitHubIssueCreator.Enable()
	CONFIG.ENABLED = true
	log("info", "GitHub issue creation enabled")
end

function GitHubIssueCreator.Disable()
	CONFIG.ENABLED = false
	log("info", "GitHub issue creation disabled")
end

function GitHubIssueCreator.GetStatus()
	return {
		enabled = CONFIG.ENABLED,
		middlewareConfigured = CONFIG.MIDDLEWARE_ENDPOINT ~= "",
		cooldownMinutes = CONFIG.ISSUE_COOLDOWN_MINUTES,
		maxPerHour = CONFIG.MAX_ISSUES_PER_HOUR,
		minSeverity = CONFIG.MIN_SEVERITY_FOR_ISSUE,
		minOccurrences = CONFIG.MIN_OCCURRENCE_COUNT,
		issueCount = #table.keys(issueCache),
		issueCounters = issueCounters,
	}
end

-- Initialize service
function GitHubIssueCreator.OnStart()
	log("info", "GitHubIssueCreator initialized")
	log("info", "Enabled:", CONFIG.ENABLED)
	log("info", "Middleware configured:", CONFIG.MIDDLEWARE_ENDPOINT ~= "")
	
	-- Start cleanup loop
	task.spawn(function()
		while true do
			task.wait(3600) -- 1 hour
			-- Reset hourly counter
			issuesThisHour = 0
			log("info", "GitHub issue hourly counter reset")
		end
	end)
	
	-- Cleanup old cache entries
	task.spawn(function()
		while true do
			task.wait(1800) -- 30 minutes
			local now = tick()
			local cutoff = now - (CONFIG.ISSUE_COOLDOWN_MINUTES * 120) -- 2x cooldown
			
			for signature, data in pairs(issueCache) do
				if now - data.lastReported > cutoff then
					issueCache[signature] = nil
					issueCounters[signature] = nil
				end
			end
		end
	end)
end

return GitHubIssueCreator
