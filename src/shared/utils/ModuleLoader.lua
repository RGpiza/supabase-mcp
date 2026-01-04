local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()
local DebugTrace = nil
do
	local ok, mod = pcall(function()
		return require(script.Parent:FindFirstChild("DebugTrace"))
	end)
	if ok and type(mod) == "table" then
		DebugTrace = mod
	end
end

-- Import InitManager for optimized loading
local InitManager = nil
do
	local ok, mod = pcall(function()
		return require(script.Parent:FindFirstChild("InitManager"))
	end)
	if ok and type(mod) == "table" then
		InitManager = mod
	end
end

local RootDirectory
local ModuleDirectory

if IsServer then
	RootDirectory = ServerScriptService
	ModuleDirectory = RootDirectory:WaitForChild("services")
else
	local player = Players.LocalPlayer
	RootDirectory = player:WaitForChild("PlayerScripts")
	ModuleDirectory = RootDirectory:WaitForChild("controllers")
end

-- Track loaded modules to prevent duplicates
local loadedModules = {}
local moduleInitStates = {}

local function RequireModule(module: Instance)
	if not module:IsA("ModuleScript") then
		return
	end

	-- Skip if already loaded
	if loadedModules[module] then
		return
	end

	local ok, imported = pcall(require, module)
	if not ok then
		warn("[Framework] Failed to require:", module:GetFullName(), imported)
		if DebugTrace then
			DebugTrace.LogError("Require failed", module:GetFullName())
		end
		return
	end

	loadedModules[module] = true

	if DebugTrace then
		DebugTrace.LogLoad(module:GetFullName())
	end

	-- If using InitManager, register the module instead of auto-starting
	if InitManager then
		if type(imported) == "table" and type(imported.OnStart) == "function" then
			-- Register with InitManager for controlled initialization
			local moduleName = module.Name
			local moduleType = IsServer and "service" or "controller"
			
			if moduleType == "service" then
				InitManager.registerService(moduleName, imported.OnStart, "core")
			else
				InitManager.registerController(moduleName, imported.OnStart, "core")
			end
			
			if DebugTrace then
				DebugTrace.LogStart(module:GetFullName() .. " (registered with InitManager)")
			end
		end
	else
		-- Fallback to old behavior if InitManager not available
		if type(imported) == "table" and type(imported.OnStart) == "function" then
			imported.OnStart()
			if DebugTrace then
				DebugTrace.LogStart(module:GetFullName())
			end
		end
	end
end

return function()
	-- If InitManager is available, let it handle initialization
	if InitManager then
		-- Register all modules with InitManager
		for _, descendant in ipairs(ModuleDirectory:GetDescendants()) do
			RequireModule(descendant)
		end
		
		-- Start initialization through InitManager
		InitManager.initialize()
		
		if not IsServer then
			ModuleDirectory.DescendantAdded:Connect(RequireModule)
		end
		
		return InitManager
	else
		-- Fallback to old behavior
		for _, descendant in ipairs(ModuleDirectory:GetDescendants()) do
			RequireModule(descendant)
		end

		if not IsServer then
			ModuleDirectory.DescendantAdded:Connect(RequireModule)
		end
		
		return nil
	end
end
