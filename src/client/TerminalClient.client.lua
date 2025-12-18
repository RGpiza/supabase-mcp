-- Client poll loop: retry on missing RequestSync or invalid payload; never perma-stop
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local running = true
localPlayer.AncestryChanged:Connect(function(_, parent)
    if parent == nil then
        running = false
    end
end)

local function validatePayload(payload)
    if type(payload) ~= "table" then return false, "payload not table" end
    local function has(k) return payload[k] ~= nil end
    if not (has("data") and has("stats") and has("boosts") and has("autobuy") and has("meta")) then
        return false, "missing required keys"
    end
    if payload.leaderboards ~= nil and type(payload.leaderboards) ~= "table" then
        return false, "leaderboards must be table or nil"
    end
    if type(payload.meta) ~= "table" then return false, "meta not table" end
    if type(payload.meta.serverTime) ~= "number" then return false, "meta.serverTime not number" end
    if type(payload.meta.version) ~= "string" then return false, "meta.version not string" end
    return true
end

task.spawn(function()
    local pollIntervalSuccess = 5
    while running do
        local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not Remotes then
            warn("[TerminalClient] Remotes missing; retrying in 2s")
            task.wait(2)
            continue
        end

        local rf = Remotes:FindFirstChild("RequestSync")
        if not rf then
            warn("[TerminalClient] RequestSync missing; retrying in 2s")
            task.wait(2)
            continue
        end

        if not rf:IsA("RemoteFunction") then
            warn("[TerminalClient] RequestSync exists but is not a RemoteFunction (" .. rf.ClassName .. "); retrying in 2s")
            task.wait(2)
            continue
        end

        local ok, payload = pcall(function()
            return rf:InvokeServer()
        end)

        if not ok then
            warn("[TerminalClient] InvokeServer failed: " .. tostring(payload) .. " ; retrying in 1s")
            task.wait(1)
            continue
        end

        local valid, reason = validatePayload(payload)
        if not valid then
            warn("[TerminalClient] Invalid sync payload: " .. tostring(reason) .. " ; retrying in 1s")
            task.wait(1)
            continue
        end

        -- TODO: consume payload (update UI/state using payload.data, payload.stats, etc.)
        -- print("Sync OK. ServerTime:", payload.meta.serverTime, "Version:", payload.meta.version)

        task.wait(pollIntervalSuccess)
    end
end)
