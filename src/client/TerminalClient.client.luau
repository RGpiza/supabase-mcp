local INVALID_SYNC_WARN_TOKEN = "Invalid sync payload"
local INVALID_SYNC_WARN_COOLDOWN = 5
local lastInvalidSyncWarnAt = -math.huge
local originalWarn = warn

warn = function(...)
	local first = select(1, ...)
	if type(first) == "string" and string.find(first, INVALID_SYNC_WARN_TOKEN, 1, true) then
		local now = os.clock()
		if now - lastInvalidSyncWarnAt < INVALID_SYNC_WARN_COOLDOWN then
			return
		end
		lastInvalidSyncWarnAt = now
	end

	return originalWarn(...)
end

local LoadingInitializer = require(script.Parent:WaitForChild("LoadingInitializer"))
LoadingInitializer.Init()
