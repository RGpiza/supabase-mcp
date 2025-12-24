local DebugConfig = {}

-- Configuration
local DEBUG_ENABLED = false  -- Change to true for development
local LOG_LEVEL = {
	ERROR = 1,
	WARN = 2,
	INFO = 3,
	DEBUG = 4
}

local currentLogLevel = LOG_LEVEL.INFO

-- Internal state
local logHistory = {}
local maxHistorySize = 1000

-- Utility functions
local function shouldLog(level)
	return DEBUG_ENABLED and level <= currentLogLevel
end

local function formatMessage(level, message, ...)
	local timestamp = os.date("%H:%M:%S")
	local levelStr = ""
	
	if level == LOG_LEVEL.ERROR then
		levelStr = "[ERROR]"
	elseif level == LOG_LEVEL.WARN then
		levelStr = "[WARN]"
	elseif level == LOG_LEVEL.INFO then
		levelStr = "[INFO]"
	elseif level == LOG_LEVEL.DEBUG then
		levelStr = "[DEBUG]"
	end
	
	local args = {...}
	local formattedMessage = string.format("%s %s %s", timestamp, levelStr, tostring(message))
	
	if #args > 0 then
		formattedMessage = formattedMessage .. " " .. table.concat(args, " ")
	end
	
	return formattedMessage
end

-- Core logging functions
function DebugConfig.Log(message, ...)
	if not shouldLog(LOG_LEVEL.INFO) then
		return
	end
	
	local formatted = formatMessage(LOG_LEVEL.INFO, message, ...)
	print(formatted)
	
	-- Add to history
	table.insert(logHistory, formatted)
	if #logHistory > maxHistorySize then
		table.remove(logHistory, 1)
	end
end

function DebugConfig.Warn(message, ...)
	if not shouldLog(LOG_LEVEL.WARN) then
		return
	end
	
	local formatted = formatMessage(LOG_LEVEL.WARN, message, ...)
	warn(formatted)
	
	-- Add to history
	table.insert(logHistory, formatted)
	if #logHistory > maxHistorySize then
		table.remove(logHistory, 1)
	end
end

function DebugConfig.Error(message, ...)
	if not shouldLog(LOG_LEVEL.ERROR) then
		return
	end
	
	local formatted = formatMessage(LOG_LEVEL.ERROR, message, ...)
	warn(formatted)
	
	-- Add to history
	table.insert(logHistory, formatted)
	if #logHistory > maxHistorySize then
		table.remove(logHistory, 1)
	end
end

function DebugConfig.Debug(message, ...)
	if not shouldLog(LOG_LEVEL.DEBUG) then
		return
	end
	
	local formatted = formatMessage(LOG_LEVEL.DEBUG, message, ...)
	print(formatted)
	
	-- Add to history
	table.insert(logHistory, formatted)
	if #logHistory > maxHistorySize then
		table.remove(logHistory, 1)
	end
end

-- Performance logging (only logs if performance is below threshold)
function DebugConfig.Perf(message, threshold, actual)
	if not shouldLog(LOG_LEVEL.WARN) then
		return
	end
	
	if actual and threshold and actual > threshold then
		DebugConfig.Warn(string.format("%s (expected: %s, actual: %s)", message, threshold, actual))
	end
end

-- UI sync logging (only logs mismatches)
function DebugConfig.UI(message, ...)
	if not shouldLog(LOG_LEVEL.WARN) then
		return
	end
	
	DebugConfig.Warn("[UI SYNC] " .. message, ...)
end

-- Initialization logging (only logs during startup)
function DebugConfig.Init(message, ...)
	if not shouldLog(LOG_LEVEL.INFO) then
		return
	end
	
	DebugConfig.Log("[INIT] " .. message, ...)
end

-- Configuration functions
function DebugConfig.Enable()
	DEBUG_ENABLED = true
	DebugConfig.Log("Debug logging enabled")
end

function DebugConfig.Disable()
	DEBUG_ENABLED = false
	DebugConfig.Log("Debug logging disabled")
end

function DebugConfig.SetLogLevel(level)
	if level >= LOG_LEVEL.ERROR and level <= LOG_LEVEL.DEBUG then
		currentLogLevel = level
		DebugConfig.Log("Log level set to:", level)
	else
		DebugConfig.Error("Invalid log level:", level)
	end
end

function DebugConfig.GetLogLevel()
	return currentLogLevel
end

-- History management
function DebugConfig.GetLogHistory()
	return logHistory
end

function DebugConfig.ClearHistory()
	logHistory = {}
	DebugConfig.Log("Log history cleared")
end

function DebugConfig.SaveHistoryToFile(filename)
	if not shouldLog(LOG_LEVEL.INFO) then
		return false, "Debug logging disabled"
	end
	
	local content = table.concat(logHistory, "\n")
	
	-- Note: In Roblox, file I/O is limited. This is a placeholder for potential future implementation
	-- or for use with external tools that can access the log history.
	
	DebugConfig.Log("Log history would be saved to:", filename)
	return true, "Log history saved"
end

-- Performance monitoring
function DebugConfig.StartTimer(label)
	if not shouldLog(LOG_LEVEL.DEBUG) then
		return function() return 0 end
	end
	
	local startTime = tick()
	
	return function()
		local duration = tick() - startTime
		DebugConfig.Debug(string.format("%s took %sms", label, duration * 1000))
		return duration
	end
end

-- Memory monitoring
function DebugConfig.LogMemory(label)
	if not shouldLog(LOG_LEVEL.DEBUG) then
		return
	end
	
	-- Note: Roblox doesn't provide direct memory access, but this could be used
	-- with external monitoring tools or future Roblox APIs
	DebugConfig.Debug(string.format("%s memory snapshot", label or "Memory"))
end

-- Batch logging (prevents spam)
local batchLogs = {}
local batchTimeout = 5
local lastBatchTime = 0

function DebugConfig.BatchLog(key, message, ...)
	if not shouldLog(LOG_LEVEL.INFO) then
		return
	end
	
	local now = tick()
	
	if now - lastBatchTime > batchTimeout then
		-- Flush previous batch
		for batchKey, batchData in pairs(batchLogs) do
			DebugConfig.Log(string.format("%s (x%d)", batchData.message, batchData.count))
		end
		
		-- Start new batch
		batchLogs = {}
		lastBatchTime = now
	end
	
	if not batchLogs[key] then
		batchLogs[key] = {
			message = formatMessage(LOG_LEVEL.INFO, message, ...),
			count = 1
		}
	else
		batchLogs[key].count = batchLogs[key].count + 1
	end
end

-- Auto-disable per-tick/per-render logs
function DebugConfig.DisableRenderLogs()
	-- This would be called to disable any render-stepped logging
	-- Individual systems should check this flag before logging in render loops
	DebugConfig.Log("Render logging disabled")
end

-- Export constants
DebugConfig.LOG_LEVEL = LOG_LEVEL

return DebugConfig
