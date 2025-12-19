-- ServerScriptService/Server/RemotesBootstrap.server.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure Remotes folder exists
if not ReplicatedStorage:FindFirstChild("Remotes") then
    local remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
else
    warn("Remotes folder already exists.")
end

-- Create RequestSync RemoteFunction if it doesn't exist
if not ReplicatedStorage.Remotes:FindFirstChild("RequestSync") then
    local requestSync = Instance.new("RemoteFunction")
    requestSync.Name = "RequestSync"
    requestSync.Parent = ReplicatedStorage.Remotes
else
    warn("RequestSync remote already exists.")
end