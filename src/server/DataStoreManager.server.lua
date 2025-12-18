-- Throttled per-player DataStore saving:
-- - 60s cooldown
-- - coalesce changes via pending flag
-- - autosave every 90s
-- - save on PlayerRemoving
-- - do not write leaderboards every tick

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local playerStore = DataStoreService:GetDataStore("PlayerData")

local SAVE_COOLDOWN = 60 -- seconds
local AUTOSAVE_INTERVAL = 90 -- seconds

local playerStates = {} -- [userId] = { lastSave = number, pending = bool, data = table }

local function getState(userId)
    local state = playerStates[userId]
    if not state then
        state = { lastSave = 0, pending = false, data = {} }
        playerStates[userId] = state
    end
    return state
end

-- Expose a BindableEvent to mark players as dirty from other scripts.
local SaveEventsFolder = Instance.new("Folder")
SaveEventsFolder.Name = "SaveEvents"
SaveEventsFolder.Parent = script

local MarkDirtyEvent = Instance.new("BindableEvent")
MarkDirtyEvent.Name = "MarkDirty"
MarkDirtyEvent.Parent = SaveEventsFolder

-- Usage: script.SaveEvents.MarkDirty:Fire(userId, sectionName, sectionData)
MarkDirtyEvent.Event:Connect(function(userId, sectionName, sectionData)
    local state = getState(userId)
    state.pending = true
    state.data[sectionName] = sectionData
end)

local function saveUserId(userId, force)
    local state = getState(userId)
    local now = os.clock()
    local since = now - (state.lastSave or 0)

    if not force and since < SAVE_COOLDOWN and not state.pending then
        -- Respect cooldown when nothing pending
        return false, "cooldown"
    end

    local payloadToSave = state.data or {}

    -- Do not write leaderboards every tick; strip out volatile leaderboard snapshot
    if payloadToSave.leaderboards ~= nil then
        payloadToSave.leaderboards = nil
    end

    local ok, err = pcall(function()
        playerStore:UpdateAsync(tostring(userId), function(existing)
            existing = existing or {}
            for k, v in pairs(payloadToSave) do
                existing[k] = v
            end
            return existing
        end)
    end)

    if not ok then
        warn(("[DataStore] Save failed for %d: %s"):format(userId, tostring(err)))
        -- Keep pending so autosave retries
        return false, err
    end

    state.lastSave = now
    state.pending = false
    return true
end

Players.PlayerAdded:Connect(function(player)
    getState(player.UserId)
    -- Optional: load player data here (omitted)
end)

Players.PlayerRemoving:Connect(function(player)
    local userId = player.UserId
    local ok = saveUserId(userId, true)
    if not ok then
        -- Best-effort second attempt
        saveUserId(userId, true)
    end
end)

task.spawn(function()
    while true do
        task.wait(AUTOSAVE_INTERVAL)
        for _, player in ipairs(Players:GetPlayers()) do
            local userId = player.UserId
            local state = getState(userId)
            local elapsed = os.clock() - (state.lastSave or 0)

            if state.pending or elapsed >= AUTOSAVE_INTERVAL then
                local ok, reason = saveUserId(userId, false)
                if not ok and reason == "cooldown" then
                    -- Ensure we don't starve saves beyond 90s max
                    if elapsed >= AUTOSAVE_INTERVAL then
                        saveUserId(userId, true)
                    end
                end
            end
        end
    end
end)
