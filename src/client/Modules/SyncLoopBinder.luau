local SyncLoopBinder = {}

local ctx = nil
local loopActive = false
local missingAttempts = 0
local syncLoopWarningIssued = false

function SyncLoopBinder.Init(context)
	ctx = context or {}
	loopActive = false
	missingAttempts = 0
	syncLoopWarningIssued = false
end

function SyncLoopBinder.Start()
	if loopActive then return end
	loopActive = true
	task.spawn(function()
		while true do
			task.wait(0.5)
			if not ctx then break end
			local ok = true
			-- attempt to run a sync cycle via provided syncState function
			if not ctx.syncState or type(ctx.syncState) ~= "function" then
				ok = false
			else
				local success, result = pcall(ctx.syncState)
				ok = success and result ~= false
			end

			if not ok then
				-- try to resolve once via optional resolveRequestSync
				if ctx.resolveRequestSync and type(ctx.resolveRequestSync) == "function" then
					pcall(ctx.resolveRequestSync)
				end
				missingAttempts = missingAttempts + 1
				if missingAttempts > 1 then
					if not syncLoopWarningIssued then
						syncLoopWarningIssued = true
						if ctx.warn then
							ctx.warn("[TerminalClient] RequestSync missing, stopping poll loop")
						else
							warn("[TerminalClient] RequestSync missing, stopping poll loop")
						end
					end
					break
				end
			else
				missingAttempts = 0
			end
		end
		loopActive = false
	end)
end

function SyncLoopBinder.Stop()
	loopActive = false
end

return SyncLoopBinder
