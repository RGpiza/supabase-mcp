local DebugConfigLoader = {}

-- Standardized DebugConfig loading utility
-- This ensures consistent loading across all services

function DebugConfigLoader.load()
	local DebugConfig = nil
	
	-- Try multiple paths to find DebugConfig
	local paths = {
		-- Primary path: ReplicatedStorage.Shared.utils.DebugConfig
		function()
			local utilsFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Shared") and game:GetService("ReplicatedStorage").Shared:FindFirstChild("utils")
			if utilsFolder then
				local debugModule = utilsFolder:FindFirstChild("DebugConfig")
				if debugModule then
					return require(debugModule)
				end
			end
			return nil
		end,
		
		-- Fallback path: ReplicatedStorage.utils.DebugConfig
		function()
			local utilsFolder = game:GetService("ReplicatedStorage"):FindFirstChild("utils")
			if utilsFolder then
				local debugModule = utilsFolder:FindFirstChild("DebugConfig")
				if debugModule then
					return require(debugModule)
				end
			end
			return nil
		end,
		
		-- Fallback path: ReplicatedStorage.DebugConfig
		function()
			local debugModule = game:GetService("ReplicatedStorage"):FindFirstChild("DebugConfig")
			if debugModule then
				return require(debugModule)
			end
			return nil
		end,
	}
	
	for _, pathFunc in ipairs(paths) do
		local ok, result = pcall(pathFunc)
		if ok and result then
			DebugConfig = result
			break
		end
	end
	
	return DebugConfig
end

-- Convenience function for services to use
function DebugConfigLoader.createLogger(serviceName)
	local DebugConfig = DebugConfigLoader.load()
	
	if not DebugConfig then
		-- Fallback logging if DebugConfig is not available
		return {
			Log = function(message, ...)
				print(string.format("[%s] %s", serviceName, message), ...)
			end,
			Warn = function(message, ...)
				warn(string.format("[%s] %s", serviceName, message), ...)
			end,
			Error = function(message, ...)
				warn(string.format("[%s] ERROR: %s", serviceName, message), ...)
			end,
			Debug = function(message, ...)
				print(string.format("[%s] DEBUG: %s", serviceName, message), ...)
			end,
		}
	end
	
	return {
		Log = function(message, ...)
			DebugConfig.Log(string.format("[%s] %s", serviceName, message), ...)
		end,
		Warn = function(message, ...)
			DebugConfig.Warn(string.format("[%s] %s", serviceName, message), ...)
		end,
		Error = function(message, ...)
			DebugConfig.Error(string.format("[%s] %s", serviceName, message), ...)
		end,
		Debug = function(message, ...)
			DebugConfig.Debug(string.format("[%s] %s", serviceName, message), ...)
		end,
	}
end

return DebugConfigLoader
