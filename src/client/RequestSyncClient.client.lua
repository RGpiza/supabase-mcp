-- src/client/RequestSyncClient.client.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function safeAccess(payload, key)
	if type(payload) == "table" and payload[key] ~= nil then
		return payload[key]
	end
	return nil
end

local WARN_COOLDOWN = 5
local lastWarnAt = 0

local function warnThrottled(message)
	local now = os.clock()
	if now - lastWarnAt < WARN_COOLDOWN then
		return
	end
	lastWarnAt = now
	warn(message)
end

local function pollLoop()
    while true do
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local requestSync = remotes and remotes:FindFirstChild("RequestSync")
		if not (requestSync and requestSync:IsA("RemoteFunction")) then
			warnThrottled("[RequestSyncClient] RequestSync is missing. Retrying in 1 second...")
			wait(1)
			continue
		end

		local ok, payload = pcall(function()
			return requestSync:InvokeServer()
		end)
		if ok and type(payload) == "table" then
			print("[RequestSyncClient] Valid payload received")
		else
			warnThrottled("[RequestSyncClient] Invalid payload received. Retrying in 1 second...")
		end

		wait(1)
	end
end

-- Start the poll loop on a separate thread to avoid blocking the main game loop
spawn(pollLoop)
