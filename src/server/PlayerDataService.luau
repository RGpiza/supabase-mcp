local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = {}

local DATASTORE_NAME = "PlayerProgress"
local MAX_RETRIES = 3
local RETRY_DELAY = 2

local AutomationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AutomationConfig"))

local defaultData = {
	data = 0,
	upgrades = {},
	prestige = 0,
	corePower = 0,
	weeklyData = 0,
	lastWeeklyReset = "",
	weeklyReward = {
		tier = "",
		expiresAt = 0,
	},
	lifetimeData = 0,
	currency = 0,
	boosts = {},
	ownedPasses = {},
	lastSeen = 0,
	globalMilestones = {},
	automation = {
		enabled = {},
		priority = AutomationConfig.GetDefaultPriority(),
		speedTier = 0,
		presets = AutomationConfig.GetDefaultPresets(),
		autoSwitchOnPrestige = false,
		autoSwitchPresetIndex = 1,
	},
}

local playerCache = {}
local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local listenersInitialized = false
local afterSetListeners = {}

local function getCurrentWeekKey()
	local utc = os.date("!*t")
	local dayOfYear = utc.yday or 1
	local weekIndex = math.floor(math.max(dayOfYear - 1, 0) / 7)
	return string.format("%04d-W%02d", utc.year, weekIndex + 1)
end

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

local function sanitizeAutomation(payload)
	local sanitized = {
		enabled = {},
		priority = AutomationConfig.GetDefaultPriority(),
		speedTier = 0,
		presets = AutomationConfig.GetDefaultPresets(),
		autoSwitchOnPrestige = false,
		autoSwitchPresetIndex = 1,
	}

	if typeof(payload) ~= "table" then
		return sanitized
	end

	if typeof(payload.enabled) == "table" then
		for _, definition in ipairs(AutomationConfig.GetAll()) do
			local value = payload.enabled[definition.id]
			if value ~= nil then
				sanitized.enabled[definition.id] = value == true
			end
		end
	end

	local priorityList = {}
	if typeof(payload.priority) == "table" then
		for _, automationId in ipairs(payload.priority) do
			if typeof(automationId) == "string" and not table.find(priorityList, automationId) then
				table.insert(priorityList, automationId)
			end
		end
	end

	for _, definition in ipairs(AutomationConfig.GetAll()) do
		if not table.find(priorityList, definition.id) then
			table.insert(priorityList, definition.id)
		end
	end
	sanitized.priority = priorityList

	local tier = payload.speedTier
	if typeof(tier) ~= "number" then
		tier = 0
	end
	sanitized.speedTier = math.clamp(math.floor(tier + 0.5), 0, AutomationConfig.GetMaxSpeedTier())

	if typeof(payload.presets) == "table" then
		local defaults = AutomationConfig.GetDefaultPresets()
		for index = 1, AutomationConfig.GetPresetSlotCount() do
			local incoming = payload.presets[index]
			local base = defaults[index]
			if typeof(incoming) == "table" and typeof(base) == "table" then
				local preset = {
					name = typeof(incoming.name) == "string" and string.sub(incoming.name, 1, 24) or base.name,
					enabled = {},
					priority = {},
					speedTier = typeof(incoming.speedTier) == "number" and math.clamp(math.floor(incoming.speedTier + 0.5), 0, AutomationConfig.GetMaxSpeedTier()) or base.speedTier,
				}

				if typeof(incoming.enabled) == "table" then
					for _, definition in ipairs(AutomationConfig.GetAll()) do
						preset.enabled[definition.id] = incoming.enabled[definition.id] == true
					end
				else
					preset.enabled = table.clone(base.enabled)
				end

				if typeof(incoming.priority) == "table" then
					for _, automationId in ipairs(incoming.priority) do
						if typeof(automationId) == "string" and not table.find(preset.priority, automationId) then
							table.insert(preset.priority, automationId)
						end
					end
				end
				for _, definition in ipairs(AutomationConfig.GetAll()) do
					if not table.find(preset.priority, definition.id) then
						table.insert(preset.priority, definition.id)
					end
				end

				sanitized.presets[index] = preset
			end
		end
	end

	if typeof(payload.autoSwitchOnPrestige) == "boolean" then
		sanitized.autoSwitchOnPrestige = payload.autoSwitchOnPrestige
	end

	local presetIndex = payload.autoSwitchPresetIndex
	if typeof(presetIndex) ~= "number" then
		presetIndex = 1
	end
	presetIndex = math.clamp(math.floor(presetIndex + 0.5), 1, AutomationConfig.GetPresetSlotCount())
	sanitized.autoSwitchPresetIndex = presetIndex

	return sanitized
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

	if typeof(payload.weeklyData) == "number" then
		sanitized.weeklyData = math.max(payload.weeklyData, 0)
	end

	if typeof(payload.lastWeeklyReset) == "string" then
		sanitized.lastWeeklyReset = payload.lastWeeklyReset
	end

	if typeof(payload.weeklyReward) == "table" then
		local reward = payload.weeklyReward
		sanitized.weeklyReward = {
			tier = typeof(reward.tier) == "string" and reward.tier or "",
			expiresAt = typeof(reward.expiresAt) == "number" and reward.expiresAt or 0,
		}
	end

	local currentWeekKey = getCurrentWeekKey()
	if sanitized.lastWeeklyReset == "" then
		sanitized.lastWeeklyReset = currentWeekKey
	end

	if sanitized.lastWeeklyReset ~= currentWeekKey then
		sanitized.weeklyData = 0
		sanitized.lastWeeklyReset = currentWeekKey
	end

	if typeof(payload.lifetimeData) == "number" then
		sanitized.lifetimeData = math.max(payload.lifetimeData, 0)
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
	sanitized.automation = sanitizeAutomation(payload.automation)
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
	local sanitized = sanitizeData(merged)

	local currentWeekKey = getCurrentWeekKey()
	if sanitized.lastWeeklyReset ~= currentWeekKey then
		sanitized.weeklyData = 0
		sanitized.lastWeeklyReset = currentWeekKey
	end

	local previousDataValue = 0
	if typeof(previousState) == "table" and typeof(previousState.data) == "number" then
		previousDataValue = previousState.data
	end
	local previousLifetime = 0
	if typeof(previousState) == "table" and typeof(previousState.lifetimeData) == "number" then
		previousLifetime = math.max(previousState.lifetimeData, 0)
	end

	local newDataValue = typeof(sanitized.data) == "number" and sanitized.data or 0
	local lifetimeValue = typeof(sanitized.lifetimeData) == "number" and math.max(sanitized.lifetimeData, 0) or previousLifetime

	local delta = newDataValue - previousDataValue
	if delta > 0 then
		lifetimeValue += delta
	else
		lifetimeValue = math.max(lifetimeValue, previousLifetime)
	end

	local previousWeekly = 0
	if typeof(previousState) == "table" and typeof(previousState.weeklyData) == "number" then
		previousWeekly = previousState.weeklyData
	end

	local weeklyValue = typeof(sanitized.weeklyData) == "number" and math.max(sanitized.weeklyData, 0) or previousWeekly
	if delta > 0 then
		weeklyValue += delta
	else
		weeklyValue = math.max(weeklyValue, previousWeekly)
	end

	sanitized.lifetimeData = lifetimeValue
	sanitized.weeklyData = weeklyValue
	playerCache[userId] = sanitized
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
		PlayerDataService.Release(player)
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerDataService.Release(player)
		end
	end)
end

setupListeners()

return PlayerDataService
