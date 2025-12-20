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
	owns2xData = false,
	ownsFasterAuto = false,
	boostExpiresAt = 0,
	boostEnd = 0,
	passes = {
		x2Data = false,
		fasterAuto = false,
	},
	receiptIds = {},
}

local playerCache = {}
local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

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

local function sanitizeReceipts(receipts)
	if typeof(receipts) ~= "table" then
		return {}
	end
	local cleaned = {}
	for _, id in ipairs(receipts) do
		if typeof(id) == "string" then
			table.insert(cleaned, id)
		end
	end
	if #cleaned > 50 then
		local overflow = #cleaned - 50
		for _ = 1, overflow do
			table.remove(cleaned, 1)
		end
	end
	return cleaned
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

	if typeof(payload.owns2xData) == "boolean" then
		sanitized.owns2xData = payload.owns2xData
	end

	if typeof(payload.ownsFasterAuto) == "boolean" then
		sanitized.ownsFasterAuto = payload.ownsFasterAuto
	end

	if typeof(payload.passes) == "table" then
		local passData = payload.passes
		if typeof(passData.x2Data) == "boolean" then
			sanitized.passes.x2Data = passData.x2Data
		end
		if typeof(passData.fasterAuto) == "boolean" then
			sanitized.passes.fasterAuto = passData.fasterAuto
		end
	end

	if typeof(payload.boostExpiresAt) == "number" then
		sanitized.boostExpiresAt = payload.boostExpiresAt
	end

	if typeof(payload.boostEnd) == "number" then
		sanitized.boostEnd = payload.boostEnd
	end

	if sanitized.owns2xData then
		sanitized.passes.x2Data = true
	end

	if sanitized.ownsFasterAuto then
		sanitized.passes.fasterAuto = true
	end

	local bestBoost = math.max(sanitized.boostExpiresAt or 0, sanitized.boostEnd or 0)
	sanitized.boostExpiresAt = bestBoost
	sanitized.boostEnd = bestBoost

	sanitized.receiptIds = sanitizeReceipts(payload.receiptIds)

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
	playerCache[userId] = sanitizeData(newData)
end

function PlayerDataService.Save(player)
	local userId = tostring(player.UserId)
	local cached = playerCache[userId]

	if not cached then
		return false
	end

	local success = saveDataWithRetries(userId, cached)
	return success
end

function PlayerDataService.Release(player)
	local userId = tostring(player.UserId)
	playerCache[userId] = nil
end

return PlayerDataService
