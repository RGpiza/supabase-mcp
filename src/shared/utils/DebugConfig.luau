local DebugConfig = {}

DebugConfig.Enabled = false

function DebugConfig.Log(...)
	if DebugConfig.Enabled then
		print(...)
	end
end

function DebugConfig.Warn(...)
	if DebugConfig.Enabled then
		warn(...)
	end
end

return DebugConfig
