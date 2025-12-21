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

local function RequireModule(module: Instance)
	if not module:IsA("ModuleScript") then
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

	if DebugTrace then
		DebugTrace.LogLoad(module:GetFullName())
	end

	if type(imported) == "table" and type(imported.OnStart) == "function" then
		imported.OnStart()
		if DebugTrace then
			DebugTrace.LogStart(module:GetFullName())
		end
	end
end

return function()
	for _, descendant in ipairs(ModuleDirectory:GetDescendants()) do
		RequireModule(descendant)
	end

	if not IsServer then
		ModuleDirectory.DescendantAdded:Connect(RequireModule)
	end
end
