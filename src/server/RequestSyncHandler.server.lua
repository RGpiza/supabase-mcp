-- src/server/RequestSyncHandler.server.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getDefaultPayload()
    return {
        data = {},
        stats = {},
        boosts = {},
        autobuy = {},
        store = {
            ready = false,
            items = {}
        },
        leaderboards = {
            lifetime = {},
            weekly = {},
            friends = {}
        },
        meta = {
            serverTime = os.time(),
            version = "1.0"
        }
    }
end

local function buildPayload(player)
    local data = {}
    local stats = {}
    local boosts = {}
    local autobuy = {}
    
    if PlayerDataService then
        data = PlayerDataService.Get(player) or {}
    end
    
    if StatsService then
        stats = StatsService.GetStats(player) or {}
    end
    
    if BoostsService then
        boosts = BoostsService.GetBoosts(player) or {}
    end
    
    local store = {
        ready = false,
        items = {}
    }
    
    if StoreService then
        local storeSuccess, storeResult = pcall(function()
            return StoreService.GetStoreStatus(player)
        end)
        if storeSuccess and type(storeResult) == "table" then
            store.ready = storeResult.ready or false
            store.items = storeResult.items or {}
        end
    end
    
    local leaderboards = {
        lifetime = {},
        weekly = {},
        friends = {}
    }
    
    if LeaderboardService then
        local lbSuccess, lbResult = pcall(function()
            return LeaderboardService.GetLeaderboards(player)
        end)
        if lbSuccess and type(lbResult) == "table" then
            leaderboards.lifetime = lbResult.lifetime or {}
            leaderboards.weekly = lbResult.weekly or {}
            leaderboards.friends = lbResult.friends or {}
        end
    end
    
    local meta = {
        serverTime = os.time(),
        version = "1.0"
    }
    
    return {
        data = data,
        stats = stats,
        boosts = boosts,
        autobuy = autobuy,
        store = store,
        leaderboards = leaderboards,
        meta = meta
    }
end

local function waitForRequestSync()
    local maxRetries = 10
    local retryCount = 0
    
    while retryCount < maxRetries do
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local requestSync = remotes:FindFirstChild("RequestSync")
            if requestSync then
                return requestSync
            end
        end
        
        retryCount = retryCount + 1
        wait(0.5)
    end
    
    warn("[RequestSyncHandler] RequestSync remote not found after retries.")
    return nil
end

local requestSync = waitForRequestSync()

if requestSync then
    requestSync.OnServerInvoke = function(player)
        local success, payload = pcall(function()
            return buildPayload(player)
        end)
        
        if not success then
            warn("[RequestSyncHandler] Error building payload:", payload)
            return getDefaultPayload()
        end
        
        if type(payload) ~= "table" then
            warn("[RequestSyncHandler] Payload is not a table.")
            return getDefaultPayload()
        end
        
        return payload
    end
else
    warn("[RequestSyncHandler] Could not assign OnServerInvoke - RequestSync not found.")
end

local RequestSync = ReplicatedStorage.Remotes.RequestSync
pcall(function()
    RequestSync.OnServerInvoke = function(player, data)
        return {
            data = {},
            stats = {},
            boosts = {},
            autobuy = {},
            store = {
                ready = true,
                items = {}
            },
            leaderboards = {
                lifetime = {},
                weekly = {},
                friends = {}
            },
            meta = {
                serverTime = os.time(),
                version = "1.0"
            }
        }
    end
end)