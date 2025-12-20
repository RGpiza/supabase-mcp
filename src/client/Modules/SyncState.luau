local SyncState = {
	requestSync = nil,
	resolveRequestSync = nil,
	applyContext = nil,
	warn = nil,
	onFirstPayload = nil,
	hasFirstPayload = false,
	backoff = 0.5,
	backoffMax = 5,
	warnCooldown = 5,
	lastWarnAt = -math.huge,
}

function SyncState.Init(config)
	if type(config) ~= "table" then
		return
	end

	if type(config.resolveRequestSync) == "function" then
		SyncState.resolveRequestSync = config.resolveRequestSync
	end
	if type(config.warn) == "function" then
		SyncState.warn = config.warn
	end
	if type(config.backoffMax) == "number" then
		SyncState.backoffMax = config.backoffMax
	end
	if type(config.warnCooldown) == "number" then
		SyncState.warnCooldown = config.warnCooldown
	end
	if config.requestSync then
		SyncState.requestSync = config.requestSync
	end
end

function SyncState.ResetBackoff()
	SyncState.backoff = 0.5
end

function SyncState.StepBackoff()
	SyncState.backoff = math.min(SyncState.backoff * 2, SyncState.backoffMax)
end

function SyncState.ShouldWarn()
	local now = os.clock()
	if now - SyncState.lastWarnAt < SyncState.warnCooldown then
		return false
	end
	SyncState.lastWarnAt = now
	return true
end

return SyncState
