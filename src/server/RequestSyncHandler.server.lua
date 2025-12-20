-- src/server/RequestSyncHandler.server.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DEFAULT_VERSION = "1.0"

local function safeRequire(moduleName, suppressWarn)
	local module = nil
	for _, child in ipairs(script.Parent:GetChildren()) do
		if child.Name == moduleName and child:IsA("ModuleScript") then
			module = child
			break
		end
	end
	if not module then
		return nil
	end

	local ok, result = pcall(require, module)
	if ok then
		return result
	end

	if not suppressWarn then
		warn(string.format("[RequestSyncHandler] Failed to require %s.", moduleName))
	end
	return nil
end

local PlayerDataService = safeRequire("PlayerDataService")
local StatsService = safeRequire("StatsService")
local BoostsService = safeRequire("BoostsService")
local StoreService = safeRequire("StoreService", true)
local LeaderboardService = safeRequire("LeaderboardService")

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
            version = DEFAULT_VERSION
        }
    }
end

local function buildPayload(player)
	local payload = getDefaultPayload()

	if PlayerDataService then
		local ok, result = pcall(function()
			return PlayerDataService.Get(player)
		end)
		if ok and type(result) == "table" then
			payload.data = result
		end
	end

	if StatsService then
		local ok, result = pcall(function()
			return StatsService.GetStats(player)
		end)
		if ok and type(result) == "table" then
			payload.stats = result
		end
	end

	if BoostsService then
		local ok, result = pcall(function()
			return BoostsService.GetBoosts(player)
		end)
		if ok and type(result) == "table" then
			payload.boosts = result
		end
	end

	if StoreService then
		local ok, result = pcall(function()
			return StoreService.GetStoreStatus(player)
		end)
		if ok and type(result) == "table" then
			payload.store.ready = result.ready == true
			payload.store.items = type(result.items) == "table" and result.items or {}
		end
	end

	if LeaderboardService then
		local ok, result = pcall(function()
			return LeaderboardService.GetLeaderboards(player)
		end)
		if ok and type(result) == "table" then
			payload.leaderboards.lifetime = type(result.lifetime) == "table" and result.lifetime or {}
			payload.leaderboards.weekly = type(result.weekly) == "table" and result.weekly or {}
			payload.leaderboards.friends = type(result.friends) == "table" and result.friends or {}
		end
	end

	payload.meta.serverTime = os.time()
	payload.meta.version = DEFAULT_VERSION

	return payload
end

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not (remotesFolder and remotesFolder:IsA("Folder")) then
	warn("[RequestSyncHandler] Remotes folder missing; OnServerInvoke not assigned.")
	return
end

local requestSync = remotesFolder:FindFirstChild("RequestSync")

if requestSync and requestSync:IsA("RemoteFunction") then
	requestSync.OnServerInvoke = function(player)
		local ok, payload = pcall(function()
			return buildPayload(player)
		end)

		if not ok then
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
