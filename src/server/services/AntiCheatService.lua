local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local DebugConfig = nil
do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.utils:FindFirstChild("DebugConfig"))
	end)
	if ok and type(mod) == "table" then
		DebugConfig = mod
	end
end

-- Import ProductionFeedbackService for error reporting
local ProductionFeedbackService = nil
do
	local ok, mod = pcall(function()
		return require(script.Parent.ProductionFeedbackService)
	end)
	if ok and type(mod) == "table" then
		ProductionFeedbackService = mod
	end
end

local AntiCheatService = {}

-- Configuration
local CONFIG = {
	DEBUG = false,
	
	-- Rate limiting configuration (requests per time window)
	RATE_LIMITS = {
		BuyUpgrade = { burst = 10, refillRate = 5, window = 10 }, -- 10 burst, refill 5/sec, 10s window
		AutoBuyBest = { burst = 8, refillRate = 4, window = 10 },
		Prestige = { burst = 3, refillRate = 1, window = 30 },
		FetchLeaderboard = { burst = 5, refillRate = 2, window = 15 },
		ToggleAuto = { burst = 20, refillRate = 10, window = 10 },
		PurchaseStore = { burst = 5, refillRate = 2, window = 15 },
		LikeGoal = { burst = 10, refillRate = 5, window = 10 },
	},
	
	-- Escalation thresholds
	ESCALATION = {
		SOFT_BLOCK_THRESHOLD = 5, -- violations before soft block
		IGNORE_THRESHOLD = 15, -- violations before ignoring
		KICK_THRESHOLD = 50, -- violations before kick
		RESET_WINDOW = 300, -- seconds to reset violation count
	},
	
	-- Economy integrity bounds
	ECONOMY = {
		MAX_CURRENCY_GROWTH_PER_MINUTE = 1000000, -- generous bound for currency growth
		MAX_PRESTIGE_GROWTH_PER_HOUR = 10, -- max prestige per hour
		AUDIT_INTERVAL = 20, -- seconds between audits
	},
	
	-- Payload validation
	PAYLOAD = {
		MAX_STRING_LENGTH = 100,
		MAX_ARRAY_SIZE = 100,
		MAX_NUMBER_MAGNITUDE = 1e15,
	}
}

-- Internal state
local playerStates = {}
local lastKnownGood = {}
local auditTimer = 0

-- Reason codes for client feedback
local REASON_CODES = {
	VALID = 0,
	TOO_MANY_REQUESTS = 1,
	INVALID_PAYLOAD = 2,
	EXPLOIT_DETECTED = 3,
	SESSION_EXPIRED = 4,
	PERMISSION_DENIED = 5,
	INTERNAL_ERROR = 6,
}

-- Utility functions
local function log(level, message, ...)
	if CONFIG.DEBUG and DebugConfig then
		if level == "error" then
			DebugConfig.Error(message, ...)
		elseif level == "warn" then
			DebugConfig.Warn(message, ...)
		else
			DebugConfig.Log(message, ...)
		end
	end
end

local function getReasonText(code)
	local texts = {
		[REASON_CODES.VALID] = "Valid",
		[REASON_CODES.TOO_MANY_REQUESTS] = "Too many requests",
		[REASON_CODES.INVALID_PAYLOAD] = "Invalid payload",
		[REASON_CODES.EXPLOIT_DETECTED] = "Exploit detected",
		[REASON_CODES.SESSION_EXPIRED] = "Session expired",
		[REASON_CODES.PERMISSION_DENIED] = "Permission denied",
		[REASON_CODES.INTERNAL_ERROR] = "Internal error",
	}
	return texts[code] or "Unknown error"
end

-- Token bucket implementation
local function createTokenBucket(config)
	return {
		tokens = config.burst,
		maxTokens = config.burst,
		refillRate = config.refillRate,
		lastRefill = tick(),
		window = config.window,
		requests = {}, -- sliding window for burst detection
	}
end

local function refillTokens(bucket)
	local now = tick()
	local elapsed = now - bucket.lastRefill
	if elapsed >= 1 then -- refill every second
		local refillAmount = math.floor(elapsed * bucket.refillRate)
		bucket.tokens = math.min(bucket.maxTokens, bucket.tokens + refillAmount)
		bucket.lastRefill = now
	end
end

local function checkRateLimit(playerId, remoteName)
	local config = CONFIG.RATE_LIMITS[remoteName]
	if not config then
		return true, REASON_CODES.VALID
	end
	
	local state = playerStates[playerId]
	if not state then
		state = {
			buckets = {},
			violations = 0,
			lastViolation = 0,
			sessionNonce = HttpService:GenerateGUID(false),
			ignoreUntil = 0,
		}
		playerStates[playerId] = state
	end
	
	-- Check if player is being ignored
	if state.ignoreUntil > tick() then
		return false, REASON_CODES.TOO_MANY_REQUESTS
	end
	
	local bucket = state.buckets[remoteName]
	if not bucket then
		bucket = createTokenBucket(config)
		state.buckets[remoteName] = bucket
	end
	
	refillTokens(bucket)
	
	-- Check sliding window for burst protection
	local now = tick()
	local windowStart = now - config.window
	bucket.requests = { unpack(bucket.requests) }
	
	-- Remove old requests
	for i = #bucket.requests, 1, -1 do
		if bucket.requests[i] < windowStart then
			table.remove(bucket.requests, i)
		else
			break
		end
	end
	
	-- Check burst limit
	if #bucket.requests >= config.burst then
		state.violations += 1
		state.lastViolation = now
		log("warn", "Rate limit exceeded", playerId, remoteName, state.violations)
		return false, REASON_CODES.TOO_MANY_REQUESTS
	end
	
	-- Check token availability
	if bucket.tokens <= 0 then
		state.violations += 1
		state.lastViolation = now
		log("warn", "Token limit exceeded", playerId, remoteName, state.violations)
		return false, REASON_CODES.TOO_MANY_REQUESTS
	end
	
	-- Consume token and add to window
	bucket.tokens -= 1
	table.insert(bucket.requests, now)
	
	-- Reset violations if enough time has passed
	if now - state.lastViolation > CONFIG.ESCALATION.RESET_WINDOW then
		state.violations = 0
	end
	
	return true, REASON_CODES.VALID
end

-- Payload validation
local function validatePayload(payload, remoteName)
	if typeof(payload) ~= "table" then
		return false, REASON_CODES.INVALID_PAYLOAD
	end
	
	-- Whitelist validation based on remote
	local allowedKeys = {}
	if remoteName == "BuyUpgrade" then
		allowedKeys = { "upgradeId", "count" }
	elseif remoteName == "AutoBuyBest" then
		allowedKeys = { "branch" }
	elseif remoteName == "Prestige" then
		allowedKeys = {}
	elseif remoteName == "FetchLeaderboard" then
		allowedKeys = { "page", "type" }
	elseif remoteName == "ToggleAuto" then
		allowedKeys = { "branch", "enabled" }
	elseif remoteName == "PurchaseStore" then
		allowedKeys = { "itemId", "quantity" }
	elseif remoteName == "LikeGoal" then
		allowedKeys = { "goalId" }
	else
		allowedKeys = {}
	end
	
	-- Check for unexpected fields
	for key in pairs(payload) do
		if not table.find(allowedKeys, key) then
			log("warn", "Unexpected payload field", remoteName, key)
			return false, REASON_CODES.INVALID_PAYLOAD
		end
	end
	
	-- Validate specific fields
	if remoteName == "BuyUpgrade" then
		local upgradeId = payload.upgradeId
		if typeof(upgradeId) ~= "string" or #upgradeId == 0 or #upgradeId > CONFIG.PAYLOAD.MAX_STRING_LENGTH then
			return false, REASON_CODES.INVALID_PAYLOAD
		end
		
		local count = payload.count
		if typeof(count) ~= "number" or count <= 0 or count > 100 or math.floor(count) ~= count then
			return false, REASON_CODES.INVALID_PAYLOAD
		end
	elseif remoteName == "AutoBuyBest" then
		local branch = payload.branch
		if typeof(branch) ~= "string" or not table.find({ "CPU", "RAM", "STORAGE" }, branch) then
			return false, REASON_CODES.INVALID_PAYLOAD
		end
	elseif remoteName == "ToggleAuto" then
		local branch = payload.branch
		local enabled = payload.enabled
		if typeof(branch) ~= "string" or typeof(enabled) ~= "boolean" then
			return false, REASON_CODES.INVALID_PAYLOAD
		end
	elseif remoteName == "PurchaseStore" then
		local itemId = payload.itemId
		local quantity = payload.quantity
		if typeof(itemId) ~= "string" or typeof(quantity) ~= "number" or quantity <= 0 or quantity > 10 then
			return false, REASON_CODES.INVALID_PAYLOAD
		end
	elseif remoteName == "LikeGoal" then
		local goalId = payload.goalId
		if typeof(goalId) ~= "string" or #goalId == 0 then
			return false, REASON_CODES.INVALID_PAYLOAD
		end
	end
	
	return true, REASON_CODES.VALID
end

-- Session validation
local function validateSession(playerId, sessionNonce)
	local state = playerStates[playerId]
	if not state then
		return false, REASON_CODES.SESSION_EXPIRED
	end
	
	if state.sessionNonce ~= sessionNonce then
		return false, REASON_CODES.SESSION_EXPIRED
	end
	
	return true, REASON_CODES.VALID
end

-- Escalation handling
local function handleEscalation(playerId, remoteName, reason)
	local state = playerStates[playerId]
	if not state then
		return
	end
	
	local now = tick()
	
	-- Soft block
	if state.violations >= CONFIG.ESCALATION.SOFT_BLOCK_THRESHOLD then
		log("warn", "Soft blocking player", playerId, remoteName, state.violations)
		-- Continue processing but log
	end
	
	-- Ignore player
	if state.violations >= CONFIG.ESCALATION.IGNORE_THRESHOLD then
		state.ignoreUntil = now + 60 -- ignore for 60 seconds
		log("warn", "Ignoring player", playerId, remoteName, state.violations)
	end
	
	-- Kick player
	if state.violations >= CONFIG.ESCALATION.KICK_THRESHOLD then
		local player = Players:GetPlayerByUserId(playerId)
		if player then
			player:Kick("Anti-cheat violation: Excessive rate limiting")
			log("error", "Kicked player for anti-cheat violations", playerId, state.violations)
		end
	end
	
	-- Send analytics event
	if DebugConfig then
		DebugConfig.Log("Anti-cheat violation", playerId, remoteName, reason, state.violations)
	end
end

-- Economy integrity checks
local function updateLastKnownGood(playerId, playerData)
	if not playerData then
		return
	end
	
	lastKnownGood[playerId] = {
		data = playerData.data or 0,
		prestige = playerData.prestige or 0,
		prestigePoints = playerData.prestigePoints or 0,
		timestamp = tick(),
	}
end

local function checkEconomyIntegrity(playerId, playerData)
	local good = lastKnownGood[playerId]
	if not good then
		updateLastKnownGood(playerId, playerData)
		return true, REASON_CODES.VALID
	end
	
	local now = tick()
	local timeElapsed = now - good.timestamp
	
	-- Check currency growth
	local expectedMaxCurrency = good.data + (CONFIG.ECONOMY.MAX_CURRENCY_GROWTH_PER_MINUTE * timeElapsed / 60)
	if playerData.data > expectedMaxCurrency then
		log("error", "Currency integrity violation", playerId, playerData.data, expectedMaxCurrency)
		-- Rollback to last known good
		playerData.data = good.data
		return false, REASON_CODES.EXPLOIT_DETECTED
	end
	
	-- Check prestige growth
	local expectedMaxPrestige = good.prestige + (CONFIG.ECONOMY.MAX_PRESTIGE_GROWTH_PER_HOUR * timeElapsed / 3600)
	if playerData.prestige > expectedMaxPrestige then
		log("error", "Prestige integrity violation", playerId, playerData.prestige, expectedMaxPrestige)
		-- Rollback to last known good
		playerData.prestige = good.prestige
		return false, REASON_CODES.EXPLOIT_DETECTED
	end
	
	return true, REASON_CODES.VALID
end

-- Main check function
function AntiCheatService.Check(player, remoteName, payload, sessionNonce)
	local playerId = player.UserId
	
	-- Session validation
	local sessionValid, sessionReason = validateSession(playerId, sessionNonce)
	if not sessionValid then
		return false, sessionReason
	end
	
	-- Rate limiting
	local rateValid, rateReason = checkRateLimit(playerId, remoteName)
	if not rateValid then
		handleEscalation(playerId, remoteName, "rate_limit")
		return false, rateReason
	end
	
	-- Payload validation
	local payloadValid, payloadReason = validatePayload(payload, remoteName)
	if not payloadValid then
		handleEscalation(playerId, remoteName, "invalid_payload")
		return false, payloadReason
	end
	
	-- Additional remote-specific checks would go here
	-- For now, we'll assume the payload is valid
	
	return true, REASON_CODES.VALID
end

-- Economy audit function
function AntiCheatService.AuditPlayer(playerId, playerData)
	local integrityValid, integrityReason = checkEconomyIntegrity(playerId, playerData)
	if not integrityValid then
		log("error", "Economy audit failed", playerId, integrityReason)
		return false, integrityReason
	end
	
	updateLastKnownGood(playerId, playerData)
	return true, REASON_CODES.VALID
end

-- Get reason text for client
function AntiCheatService.GetReasonText(code)
	return getReasonText(code)
end

-- Get player state for debugging
function AntiCheatService.GetPlayerState(playerId)
	return playerStates[playerId]
end

-- Reset player violations (admin function)
function AntiCheatService.ResetViolations(playerId)
	local state = playerStates[playerId]
	if state then
		state.violations = 0
		state.ignoreUntil = 0
		log("info", "Reset violations for player", playerId)
	end
end

-- Cleanup expired player states
function AntiCheatService.Cleanup()
	local now = tick()
	local expired = {}
	
	for playerId, state in pairs(playerStates) do
		-- Clean up old violations
		if now - state.lastViolation > CONFIG.ESCALATION.RESET_WINDOW then
			state.violations = 0
		end
		
		-- Clean up old player states (after 1 hour of inactivity)
		if now - (state.lastActivity or 0) > 3600 then
			expired[#expired + 1] = playerId
		end
	end
	
	for _, playerId in ipairs(expired) do
		playerStates[playerId] = nil
		lastKnownGood[playerId] = nil
	end
end

-- Initialize service
function AntiCheatService.OnStart()
	log("info", "AntiCheatService initialized")
	
	-- Start cleanup loop
	task.spawn(function()
		while true do
			task.wait(300) -- cleanup every 5 minutes
			AntiCheatService.Cleanup()
		end
	end)
	
	-- Start economy audit loop
	task.spawn(function()
		while true do
			task.wait(CONFIG.ECONOMY.AUDIT_INTERVAL)
			-- Audit all active players (this would be called from PlayerDataService)
		end
	end)
end

return AntiCheatService
