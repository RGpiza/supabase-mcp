local SyncState = require(script.Parent:WaitForChild("SyncState"))
local SyncValidator = require(script.Parent:WaitForChild("SyncValidator"))
local SyncApplier = require(script.Parent:WaitForChild("SyncApplier"))

local SyncPoller = {}

local function warnOnce(message)
	local warnFn = SyncState.warn or warn
	if SyncState.ShouldWarn() then
		warnFn(message)
	end
end

function SyncPoller.RunOnce()
	local resolveRequestSync = SyncState.resolveRequestSync
	if type(resolveRequestSync) == "function" and not SyncState.requestSync then
		SyncState.requestSync = resolveRequestSync()
	end

	if not SyncState.requestSync then
		task.wait(SyncState.backoff)
		SyncState.StepBackoff()
		return true
	end

	SyncState.ResetBackoff()

	local ok, payload = pcall(function()
		return SyncState.requestSync:InvokeServer()
	end)
	if not ok then
		warnOnce("[TerminalClient] RequestSync failed")
		return true
	end

	if not SyncValidator.IsValid(payload) then
		warnOnce("[TerminalClient] Invalid sync payload")
		return true
	end

	if not SyncState.hasFirstPayload and type(SyncState.onFirstPayload) == "function" then
		SyncState.hasFirstPayload = true
		pcall(function()
			SyncState.onFirstPayload(payload)
		end)
	end

	SyncApplier.Apply(payload, SyncState.applyContext)
	return true
end

return SyncPoller
