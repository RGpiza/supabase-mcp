local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = {}

local DATASTORE_NAME = "PlayerProgress"
local MAX_RETRIES = 3
local RETRY_DELAY = 2

local defaultData = {
	data = 0,
	upgrades = {},
	prestige = 0,
	corePower = 0,
	currency = 0,
	boosts = {},
	ownedPasses = {},
	lastSeen = 0,
	globalMilestones = {},
}

local playerCache = {}
local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local listenersInitialized = false
local afterSetListeners = {}

local function deepCopy(source)
	local target = {}
	for key, value in source do
		if typeof(value) == "table" then
			target[key] = deepCopy(value)
		else
			target[key] = value
		end
	end
	return target
end

local function deepMerge(base, overrides)
	local merged = deepCopy(base)
	if typeof(overrides) ~= "table" then
		return merged
	end

	for key, value in overrides do
		if value ~= nil then
			if typeof(value) == "table" and typeof(merged[key]) == "table" then
				merged[key] = deepMerge(merged[key], value)
			elseif typeof(value) == "table" then
				merged[key] = deepCopy(value)
			else
				merged[key] = value
			end
		end
	end

	return merged
end

local function sanitizeUpgrades(upgrades)
	if typeof(upgrades) ~= "table" then
		return {}
	end

	local cleaned = {}
	for upgradeId, level in upgrades do
		if typeof(upgradeId) == "string" and typeof(level) == "number" then
			cleaned[upgradeId] = level
		end
	end

	return cleaned
end

local function sanitizeBoosts(boosts)
	if typeof(boosts) ~= "table" then
		return {}
	end

	local cleaned = {}
	local now = os.time()

	for boostName, expiration in boosts do
		if typeof(boostName) == "string" and typeof(expiration) == "number" and expiration > now then
			cleaned[boostName] = expiration
		end
	end

	return cleaned
end

local function sanitizeOwnedPasses(passes)
	if typeof(passes) ~= "table" then
		return {}
	end

	local cleaned = {}
	for passId, owned in passes do
		if typeof(passId) == "string" and typeof(owned) == "boolean" then
			cleaned[passId] = owned
		elseif typeof(passId) == "number" and typeof(owned) == "boolean" then
			cleaned[tostring(passId)] = owned
		end
	end

	return cleaned
end

local function sanitizeBooleanTable(source)
	if typeof(source) ~= "table" then
		return {}
	end

	local cleaned = {}
	for key, value in source do
		if typeof(key) == "string" and value ~= nil then
			cleaned[key] = value == true
		end
	end
	return cleaned
end

local function sanitizeGlobalMilestones(payload)
	local sanitized = {}
	if typeof(payload) ~= "table" then
		sanitized.data = {}
		sanitized.prestige = {}
		sanitized.prestigeMultiples = {}
		return sanitized
	end

	sanitized.data = sanitizeBooleanTable(payload.data)
	sanitized.prestige = sanitizeBooleanTable(payload.prestige)
	sanitized.prestigeMultiples = sanitizeBooleanTable(payload.prestigeMultiples)

	return sanitized
end

local function sanitizeData(payload)
	local sanitized = deepCopy(defaultData)

	if typeof(payload) ~= "table" then
		return sanitized
	end

	if typeof(payload.data) == "number" then
		sanitized.data = payload.data
	end

	sanitized.upgrades = sanitizeUpgrades(payload.upgrades)

	if typeof(payload.prestige) == "number" then
		sanitized.prestige = payload.prestige
	end

	if typeof(payload.corePower) == "number" then
		sanitized.corePower = payload.corePower
	end

	if typeof(payload.currency) == "number" then
		sanitized.currency = math.max(0, payload.currency)
	end

	sanitized.boosts = sanitizeBoosts(payload.boosts)
	sanitized.ownedPasses = sanitizeOwnedPasses(payload.ownedPasses)
	sanitized.globalMilestones = sanitizeGlobalMilestones(payload.globalMilestones)
	if typeof(payload.lastSeen) == "number" then
		sanitized.lastSeen = payload.lastSeen
	else
		sanitized.lastSeen = os.time()
	end

	return sanitized
end

local function loadDataWithRetries(userId)
	local attempts = 0
	local lastError

	repeat
		attempts += 1
		local success, stored = pcall(function()
			return dataStore:GetAsync(userId)
		end)

		if success then
			return sanitizeData(stored)
		end

		lastError = stored
		warn("[PlayerDataService] GetAsync failed for", userId, lastError)
		if attempts < MAX_RETRIES then
			task.wait(RETRY_DELAY)
		end
	until attempts >= MAX_RETRIES

	return sanitizeData(nil)
end

local function saveDataWithRetries(userId, data)
	local attempts = 0
	local lastError

	repeat
		attempts += 1
		local success, err = pcall(function()
			dataStore:SetAsync(userId, data)
		end)

		if success then
			return true
		end

		lastError = err
		warn("[PlayerDataService] SetAsync failed for", userId, lastError)
		if attempts < MAX_RETRIES then
			task.wait(RETRY_DELAY)
		end
	until attempts >= MAX_RETRIES

	return false, lastError
end

local function dispatchAfterSet(player, previousState, newState)
	for _, callback in ipairs(afterSetListeners) do
		local ok, err = pcall(callback, player, previousState, newState)
		if not ok then
			warn("[PlayerDataService] AfterSet listener failed:", err)
		end
	end
end

function PlayerDataService.InitPlayer(player)
	local userId = tostring(player.UserId)
	if playerCache[userId] then
		return playerCache[userId]
	end

	local data = loadDataWithRetries(userId)
	playerCache[userId] = data

	return data
end

function PlayerDataService.Get(player)
	local userId = tostring(player.UserId)
	if playerCache[userId] then
		return playerCache[userId]
	end

	return PlayerDataService.InitPlayer(player)
end

function PlayerDataService.Set(player, newData)
	if typeof(newData) ~= "table" then
		warn("[PlayerDataService] Attempt to set invalid data for", player)
		return
	end

	local userId = tostring(player.UserId)
	local previousState = playerCache[userId]
	local merged = deepMerge(playerCache[userId] or defaultData, newData)
	playerCache[userId] = sanitizeData(merged)
	dispatchAfterSet(player, previousState, playerCache[userId])
end

function PlayerDataService.Save(player)
	local userId = tostring(player.UserId)
	local cached = playerCache[userId]

	if not cached then
		return false
	end

	cached.lastSeen = os.time()

	local success = saveDataWithRetries(userId, cached)
	return success
end

function PlayerDataService.Release(player)
	local userId = tostring(player.UserId)
	playerCache[userId] = nil
end

function PlayerDataService.OnAfterSet(callback)
	if typeof(callback) ~= "function" then
		return function() end
	end

	table.insert(afterSetListeners, callback)

	return function()
		for index, stored in ipairs(afterSetListeners) do
			if stored == callback then
				table.remove(afterSetListeners, index)
				break
			end
		end
	end
end

local function setupListeners()
	if listenersInitialized then
		return
	end
	listenersInitialized = true

	Players.PlayerAdded:Connect(function(player)
		PlayerDataService.InitPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.Save(player)
		PlayerDataService.Release(player)
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerDataService.Save(player)
		end
	end)
end

setupListeners()

return PlayerDataService
