local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local AnalyticsLogger = {}

local function isStudio()
	return RunService:IsStudio()
end

local function clampNumber(value, default)
	if typeof(value) ~= "number" then
		return default
	end
	return value
end

local function logCustomEvent(player: Player?, eventName: string, value, customFields)
	if isStudio() then
		return
	end

	local sanitizedEvent = typeof(eventName) == "string" and eventName or ""
	if sanitizedEvent == "" then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:LogCustomEvent(player, sanitizedEvent, value or 1, customFields)
		end)

		if not ok then
			warn("[AnalyticsLogger] Failed to log custom event", sanitizedEvent, err)
		end
	end)
end

function AnalyticsLogger.LogOfflineSession(player: Player?, amount: number, hadBoosts: boolean, prestigeLevel: number, timeAwaySeconds: number, sessionDuration: number?)
	if isStudio() then
		return
	end

	if typeof(amount) ~= "number" or amount <= 0 then
		return
	end

	local payload = {
		OfflineAmount = clampNumber(amount, 0),
		HadBoosts = hadBoosts == true,
		PrestigeLevel = clampNumber(prestigeLevel, 0),
		TimeAwaySeconds = math.max(0, clampNumber(timeAwaySeconds, 0)),
		SessionDuration = math.max(0, clampNumber(sessionDuration or 0, 0)),
	}

	logCustomEvent(player, "OfflineEarningsSession", 1, payload)
end

return AnalyticsLogger
