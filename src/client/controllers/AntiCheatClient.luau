local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
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

local AntiCheatClient = {}

-- Configuration
local CONFIG = {
	DEBUG = false,
	TOAST_DURATION = 3,
	ENABLE_TOASTS = true,
}

-- Internal state
local localPlayer = Players.LocalPlayer
local sessionNonce = nil
local lastErrorTime = 0
local errorCount = 0

-- Reason codes (must match server)
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

local function showToast(message, duration)
	if not CONFIG.ENABLE_TOASTS then
		return
	end
	
	-- Find toast label in UI
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	
	local terminalUI = playerGui:FindFirstChild("TerminalUI")
	if not terminalUI then
		return
	end
	
	local toastLabel = terminalUI:FindFirstChild("ToastLabel")
	if not toastLabel then
		return
	end
	
	-- Throttle error messages
	local now = tick()
	if now - lastErrorTime < 1 then
		errorCount += 1
		if errorCount > 5 then
			-- Suppress spam
			return
		end
	else
		errorCount = 0
		lastErrorTime = now
	end
	
	-- Show toast
	toastLabel.Text = message
	toastLabel.TextTransparency = 1
	toastLabel.Visible = true
	
	local tweenInfo = TweenInfo.new(duration or CONFIG.TOAST_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	-- Fade in
	game:GetService("TweenService"):Create(toastLabel, tweenInfo, { TextTransparency = 0 }):Play()
	
	-- Fade out after delay
	task.delay(duration or CONFIG.TOAST_DURATION, function()
		game:GetService("TweenService"):Create(toastLabel, tweenInfo, { TextTransparency = 1 }):Play()
		task.delay(tweenInfo.Time, function()
			toastLabel.Visible = false
		end)
	end)
end

local function getReasonText(code)
	local texts = {
		[REASON_CODES.VALID] = "Valid",
		[REASON_CODES.TOO_MANY_REQUESTS] = "Too many requests - please slow down",
		[REASON_CODES.INVALID_PAYLOAD] = "Invalid request - please try again",
		[REASON_CODES.EXPLOIT_DETECTED] = "Security violation detected",
		[REASON_CODES.SESSION_EXPIRED] = "Session expired - please reconnect",
		[REASON_CODES.PERMISSION_DENIED] = "Access denied",
		[REASON_CODES.INTERNAL_ERROR] = "Server error - please try again",
	}
	return texts[code] or "Unknown error"
end

-- Remote event handlers for error responses
local function setupErrorHandlers()
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		return
	end
	
	-- Handle error responses from server
	local function handleRemoteError(remoteName, player, errorData)
		if player ~= localPlayer then
			return
		end
		
		local reason = errorData.error
		local newSessionNonce = errorData.sessionNonce
		
		log("warn", "Remote error", remoteName, reason)
		
		-- Update session nonce if provided
		if newSessionNonce then
			sessionNonce = newSessionNonce
		end
		
		-- Show user-friendly error message
		local message = getReasonText(reason)
		showToast(message)
		
		-- Handle specific error types
		if reason == REASON_CODES.SESSION_EXPIRED then
			-- Session expired - might need to refresh
			log("warn", "Session expired, generating new nonce")
			sessionNonce = HttpService:GenerateGUID(false)
		elseif reason == REASON_CODES.EXPLOIT_DETECTED then
			-- Serious security issue
			log("error", "Exploit detected - this should not happen in normal gameplay")
		end
	end
	
	-- Connect error handlers for all remotes
	local remoteNames = {
		"BuyUpgrade",
		"AutoBuyBest", 
		"Prestige",
		"FetchLeaderboard",
		"ToggleAuto",
		"PurchaseStore",
		"LikeGoal",
	}
	
	for _, remoteName in ipairs(remoteNames) do
		local remote = remotesFolder:FindFirstChild(remoteName)
		if remote and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(function(errorData)
				handleRemoteError(remoteName, localPlayer, errorData)
			end)
		end
	end
end

-- Enhanced remote call wrapper with anti-cheat support
function AntiCheatClient.CallRemote(remoteName, payload)
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		showToast("Network error - please reconnect")
		return false, "No remotes folder"
	end
	
	local remote = remotesFolder:FindFirstChild(remoteName)
	if not remote then
		showToast("Network error - remote not found")
		return false, "Remote not found"
	end
	
	-- Generate session nonce if not exists
	if not sessionNonce then
		sessionNonce = HttpService:GenerateGUID(false)
	end
	
	-- Add session nonce to payload
	local enhancedPayload = table.clone(payload or {})
	enhancedPayload.__sessionNonce = sessionNonce
	
	-- Call remote
	if remote:IsA("RemoteEvent") then
		remote:FireServer(enhancedPayload)
		return true, "Event sent"
	elseif remote:IsA("RemoteFunction") then
		local success, result = pcall(function()
			return remote:InvokeServer(enhancedPayload)
		end)
		
		if success then
			-- Check for error response
			if result and result.error then
				local message = getReasonText(result.error)
				showToast(message)
				-- Update session nonce if provided
				if result.sessionNonce then
					sessionNonce = result.sessionNonce
				end
				return false, message
			else
				-- Update session nonce if provided
				if result and result.sessionNonce then
					sessionNonce = result.sessionNonce
				end
				return true, result
			end
		else
			log("error", "Remote function call failed", remoteName, result)
			showToast("Server error - please try again")
			return false, "Server error"
		end
	else
		showToast("Invalid remote type")
		return false, "Invalid remote"
	end
end

-- Specific remote call helpers
function AntiCheatClient.BuyUpgrade(upgradeId, count)
	return AntiCheatClient.CallRemote("BuyUpgrade", {
		upgradeId = upgradeId,
		count = count or 1,
	})
end

function AntiCheatClient.AutoBuyBest(branch)
	return AntiCheatClient.CallRemote("AutoBuyBest", {
		branch = branch,
	})
end

function AntiCheatClient.Prestige()
	return AntiCheatClient.CallRemote("Prestige", {})
end

function AntiCheatClient.FetchLeaderboard(page, type)
	return AntiCheatClient.CallRemote("FetchLeaderboard", {
		page = page or 1,
		type = type or "global",
	})
end

function AntiCheatClient.ToggleAuto(branch, enabled)
	return AntiCheatClient.CallRemote("ToggleAuto", {
		branch = branch,
		enabled = enabled,
	})
end

function AntiCheatClient.PurchaseStore(itemId, quantity)
	return AntiCheatClient.CallRemote("PurchaseStore", {
		itemId = itemId,
		quantity = quantity or 1,
	})
end

function AntiCheatClient.LikeGoal(goalId)
	return AntiCheatClient.CallRemote("LikeGoal", {
		goalId = goalId,
	})
end

function AntiCheatClient.RequestSync()
	return AntiCheatClient.CallRemote("RequestSync", {})
end

function AntiCheatClient.RequestPrestigeState()
	return AntiCheatClient.CallRemote("RequestPrestigeState", {})
end

function AntiCheatClient.RequestPrestigePurchase(upgradeId)
	return AntiCheatClient.CallRemote("RequestPrestigePurchase", {
		upgradeId = upgradeId,
	})
end

-- Admin/debug functions
function AntiCheatClient.EnableDebug(enable)
	CONFIG.DEBUG = enable
	log("info", "Debug " .. (enable and "enabled" or "disabled"))
end

function AntiCheatClient.EnableToasts(enable)
	CONFIG.ENABLE_TOASTS = enable
end

function AntiCheatClient.GetSessionNonce()
	return sessionNonce
end

function AntiCheatClient.RefreshSession()
	sessionNonce = HttpService:GenerateGUID(false)
	log("info", "Session refreshed")
end

-- Initialize client
function AntiCheatClient.OnStart()
	log("info", "AntiCheatClient initialized")
	setupErrorHandlers()
	
	-- Generate initial session nonce
	sessionNonce = HttpService:GenerateGUID(false)
	
	-- Handle player leaving
	localPlayer.AncestryChanged:Connect(function()
		if not localPlayer or not localPlayer.Parent then
			sessionNonce = nil
			log("info", "Player left, cleared session")
		end
	end)
end

return AntiCheatClient
