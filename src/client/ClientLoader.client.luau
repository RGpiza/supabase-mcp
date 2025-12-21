local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
if not Shared then
	error('[ClientLoader] Missing ReplicatedStorage.Shared (case-sensitive). Create it manually in Studio.')
end

local Utils = Shared:FindFirstChild("utils")
if not Utils then
	error('[ClientLoader] Missing ReplicatedStorage.Shared.utils (case-sensitive). Create it manually in Studio.')
end

local ModuleLoader = Utils:FindFirstChild("ModuleLoader")
if not ModuleLoader or not ModuleLoader:IsA("ModuleScript") then
	error('[ClientLoader] Missing ReplicatedStorage.Shared.utils.ModuleLoader (ModuleScript). Create it manually in Studio.')
end

local Load = require(ModuleLoader)
Load()
