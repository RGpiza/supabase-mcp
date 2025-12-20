-- src/client/RequestSyncClient.client.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function safeAccess(payload, key)
    if type(payload) == "table" and payload[key] ~= nil then
        return payload[key]
    else
        warn("[RequestSyncClient] Missing or invalid key:", key)
        return nil
    end
end

local function pollLoop()
    while true do
        local success, requestSync = pcall(function()
            return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestSync")
        end)

        if not success then
            warn("[RequestSyncClient] RequestSync is missing. Retrying in 1 second...")
            wait(1)
            continue
        end

        local payload = requestSync:InvokeServer()
        if type(payload) == "table" and safeAccess(payload, "data") ~= nil and safeAccess(payload, "stats") ~= nil and safeAccess(payload, "boosts") ~= nil and safeAccess(payload, "autobuy") ~= nil and safeAccess(payload, "store") ~= nil and safeAccess(payload, "leaderboards") ~= nil and safeAccess(payload, "meta") ~= nil then
            -- Process valid payload
            local data = safeAccess(payload, "data")
            local stats = safeAccess(payload, "stats")
            local boosts = safeAccess(payload, "boosts")
            local autobuy = safeAccess(payload, "autobuy")
            local store = safeAccess(payload, "store")
            local leaderboards = safeAccess(payload, "leaderboards")
            local meta = safeAccess(payload, "meta")

            -- Example processing of the payload
            print("[RequestSyncClient] Valid payload received")
        else
            warn("[RequestSyncClient] Invalid payload received. Retrying in 1 second...")
        end

        wait(1)
    end
end

-- Start the poll loop on a separate thread to avoid blocking the main game loop
spawn(pollLoop)