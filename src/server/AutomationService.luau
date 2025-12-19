local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeService = require(script.Parent.UpgradeService)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local AutomationConfig = require(ReplicatedStorage.Shared.AutomationConfig)
local AutomationConstants = require(ReplicatedStorage.Shared.AutomationConstants)
local SessionRewardService = require(script.Parent.SessionRewardService)

local AutomationService = {}

local BLOCK_TIMEOUT = 5
local BASE_INTERVAL = 0.5
local SUMMARY_INTERVAL = 120
local automationById = {}
local automationByAttribute = {}
local isAutomationUnlocked

requestSync.OnServerInvoke = function(player)
    local success, result = pcall(function()
        -- Existing code
    end)

    if not success then
        warn("RequestSync error:", result)
        return DEFAULT_PAYLOAD
    end

    return result or DEFAULT_PAYLOAD
end

local DEFAULT_PRIORITY = AutomationConfig.GetDefaultPriority()
local maxSpeedTier = AutomationConfig.GetMaxSpeedTier()
local presetSlotCount = AutomationConfig.GetPresetSlotCount()
local presetStateListeners = {}
local playerSettingsCache = {}
local lastProcessTimes = {}
local blockState = {}
local analyticsByPlayer = {}
local sessionStartTimes = {}
local statePublisher = nil
local autoSwitchNotices = {}
local presetUnlockConnections = {}
local PRESET4_ATTRIBUTE = AutomationConstants.Preset4Attribute or "HasPreset4"
local SIMPLE_AUTO_BRANCHES = {
	CPU = "auto_cpu",
	RAM = "auto_ram",
	STORAGE = "auto_storage",
}
local BRANCH_LOOKUP = {}
for branch, automationId in pairs(SIMPLE_AUTO_BRANCHES) do
	BRANCH_LOOKUP[branch] = automationId
	BRANCH_LOOKUP[string.lower(branch)] = automationId
end
local autoBuyStateCache = {}

local function observePresetUnlockAttribute(player)
	if not player then
		return
	end

	if presetUnlockConnections[player] then
		presetUnlockConnections[player]:Disconnect()
		presetUnlockConnections[player] = nil
	end

	presetUnlockConnections[player] = player:GetAttributeChangedSignal(PRESET4_ATTRIBUTE):Connect(function()
		notifyPresetStateChanged(player)
	end)
end

local function notifyPresetStateChanged(player)
	for _, callback in ipairs(presetStateListeners) do
		local ok, err = pcall(callback, player)
		if not ok then
			warn("[AutomationService] Preset listener failed:", err)
		end
	end
end

function AutomationService.OnPresetStateChanged(callback)
	if typeof(callback) ~= "function" then
		return function() end
	end

	table.insert(presetStateListeners, callback)

	return function()
		for index, stored in ipairs(presetStateListeners) do
			if stored == callback then
				table.remove(presetStateListeners, index)
				break
			end
		end
	end
end

local BRANCH_SHORT_NAMES = {
	CPU = "CPU",
	RAM = "RAM",
	STORAGE = "STO",
}

for _, definition in ipairs(AutomationConfig.GetAll()) do
	automationById[definition.id] = definition
	if typeof(definition.attribute) == "string" and definition.attribute ~= "" then
		automationByAttribute[definition.attribute] = definition.id
		automationByAttribute[string.lower(definition.attribute)] = definition.id
	end
end

local function resolveAutomationId(identifier)
	if typeof(identifier) ~= "string" then
		return nil
	end

	if automationById[identifier] then
		return identifier
	end

	local mapped = automationByAttribute[identifier]
	if mapped then
		return mapped
	end

	return nil
end

local function extractEnabledMap(payload)
	if typeof(payload) ~= "table" then
		return nil
	end

	if typeof(payload.enabled) == "table" then
		return payload.enabled
	end

	local collected
	for attribute, automationId in pairs(automationByAttribute) do
		local value = payload[attribute]
		if value ~= nil then
			collected = collected or {}
			collected[automationId] = value == true
		end
	end

	return collected
end

local function extractPriorityListPayload(payload)
	if typeof(payload) ~= "table" then
		return nil
	end

	if typeof(payload.priority) == "table" then
		return payload.priority
	end

	if typeof(payload.PriorityOrder) == "table" then
		return payload.PriorityOrder
	end

	return nil
end

local function sanitizePresetEntry(payload, fallback, allowRename)
	local sanitized = {
		name = fallback and fallback.name or string.format("Preset %d", math.random(1, 999)),
		enabled = {},
		priority = {},
		speedTier = fallback and fallback.speedTier or 0,
	}

	if typeof(payload) == "table" then
		if allowRename and typeof(payload.name) == "string" and payload.name ~= "" then
			sanitized.name = string.sub(payload.name, 1, 24)
		end

		if typeof(payload.speedTier) == "number" then
			sanitized.speedTier = math.clamp(math.floor(payload.speedTier + 0.5), 0, maxSpeedTier)
		end
	end

	local enabledSource = extractEnabledMap(payload)
	if enabledSource then
		for _, definition in ipairs(AutomationConfig.GetAll()) do
			sanitized.enabled[definition.id] = enabledSource[definition.id] == true
		end
	elseif fallback and typeof(fallback.enabled) == "table" then
		sanitized.enabled = table.clone(fallback.enabled)
	else
		for _, definition in ipairs(AutomationConfig.GetAll()) do
			sanitized.enabled[definition.id] = false
		end
	end

	local priorityList = {}
	local prioritySource = extractPriorityListPayload(payload)
	if prioritySource then
		for _, automationId in ipairs(prioritySource) do
			local resolved = resolveAutomationId(automationId)
			if resolved and not table.find(priorityList, resolved) then
				table.insert(priorityList, resolved)
			end
		end
	
		
	elseif fallback and typeof(fallback.priority) == "table" then
		for _, automationId in ipairs(fallback.priority) do
			if automationById[automationId] and not table.find(priorityList, automationId) then
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
	return sanitized
end

local function isStudio()
        return RunService:IsStudio()
end

local function logCustomEvent(player: Player, eventName: string, value, payload)
        if isStudio() then
                return
        end

        local sanitized = typeof(eventName) == "string" and eventName or ""
        if sanitized == "" then
                return
        end

        task.spawn(function()
                local ok, err = pcall(function()
                        AnalyticsService:LogCustomEvent(player, sanitized, value or 1, payload)
                end)

                if not ok then
                        warn("[AutomationService] Failed to log custom event", sanitized, err)
                end
        end)
end

local function sanitizePresets(presets)
	local stored = {}
	local defaults = AutomationConfig.GetDefaultPresets()

	for index = 1, presetSlotCount do
		local incoming = typeof(presets) == "table" and presets[index] or nil
		stored[index] = sanitizePresetEntry(incoming, defaults[index], true)
	end

	return stored
end

local function clampAutoSwitchPresetIndex(index)
	local numeric = typeof(index) == "number" and math.floor(index + 0.5) or nil
	if not numeric then
		return 1
	end
	return math.clamp(numeric, 1, presetSlotCount)
end

local function sanitizeSettings(settings)
	local sanitized = {
		enabled = {},
		priority = {},
		speedTier = 0,
		presets = AutomationConfig.GetDefaultPresets(),
		autoSwitchOnPrestige = false,
		autoSwitchPresetIndex = 1,
	}

	if typeof(settings) == "table" then
		if typeof(settings.enabled) == "table" then
			for automationId, value in settings.enabled do
				if automationById[automationId] then
					sanitized.enabled[automationId] = value == true
				end
			end
		end

		if typeof(settings.priority) == "table" then
			for _, automationId in ipairs(settings.priority) do
				if automationById[automationId] and not table.find(sanitized.priority, automationId) then
					table.insert(sanitized.priority, automationId)
				end
			end
		end

		if typeof(settings.speedTier) == "number" then
			sanitized.speedTier = math.clamp(math.floor(settings.speedTier + 0.5), 0, maxSpeedTier)
		end

		if typeof(settings.presets) == "table" then
			sanitized.presets = sanitizePresets(settings.presets)
		end

		if typeof(settings.autoSwitchOnPrestige) == "boolean" then
			sanitized.autoSwitchOnPrestige = settings.autoSwitchOnPrestige
		end

		local storedIndex = clampAutoSwitchPresetIndex(settings.autoSwitchPresetIndex)
		if storedIndex then
			sanitized.autoSwitchPresetIndex = storedIndex
		end
	end

	for _, automationId in ipairs(DEFAULT_PRIORITY) do
		if not table.find(sanitized.priority, automationId) then
			table.insert(sanitized.priority, automationId)
		end
	end

	sanitized.autoSwitchPresetIndex = clampAutoSwitchPresetIndex(sanitized.autoSwitchPresetIndex)

	return sanitized
end

local function cloneSettings(settings)
	local copy = {
		speedTier = settings.speedTier or 0,
		enabled = {},
		priority = {},
		presets = {},
		autoSwitchOnPrestige = settings.autoSwitchOnPrestige == true,
		autoSwitchPresetIndex = clampAutoSwitchPresetIndex(settings.autoSwitchPresetIndex),
	}

	for automationId, value in pairs(settings.enabled or {}) do
		copy.enabled[automationId] = value == true
	end

	if typeof(settings.priority) == "table" then
		for _, automationId in ipairs(settings.priority) do
			table.insert(copy.priority, automationId)
		end
	end

	if typeof(settings.presets) == "table" then
		for index, preset in ipairs(settings.presets) do
			copy.presets[index] = {
				name = typeof(preset.name) == "string" and preset.name or string.format("Preset %d", index),
				speedTier = typeof(preset.speedTier) == "number" and preset.speedTier or 0,
				enabled = table.clone(preset.enabled or {}),
				priority = table.clone(preset.priority or {}),
			}
		end
	end

	return copy
end

local function clampPresetIndex(index)
	local numeric = typeof(index) == "number" and math.floor(index + 0.5) or nil
	if not numeric then
		return nil
	end
	if numeric < 1 or numeric > presetSlotCount then
		return nil
	end
	return numeric
end

local function isPresetUnlocked(player, presetIndex)
	if presetIndex <= 3 then
		return true
	end

	if presetIndex == 4 then
		return player ~= nil and player:GetAttribute(PRESET4_ATTRIBUTE) == true
	end

	return true
end

local function getMaxUnlockedPresetIndex(player)
	if isPresetUnlocked(player, presetSlotCount) then
		return presetSlotCount
	end

	return 3
end

local function clonePresetForClient(preset)
	if typeof(preset) ~= "table" then
		return nil
	end

	return {
		name = preset.name,
		enabled = table.clone(preset.enabled or {}),
		priority = table.clone(preset.priority or {}),
		speedTier = preset.speedTier or 0,
	}
end

local function normalizePriorityList(priorityList)
	local normalized = {}
	if typeof(priorityList) == "table" then
		for _, automationId in ipairs(priorityList) do
			if automationById[automationId] and not table.find(normalized, automationId) then
				table.insert(normalized, automationId)
			end
		end
	end

	for _, automationId in ipairs(DEFAULT_PRIORITY) do
		if not table.find(normalized, automationId) then
			table.insert(normalized, automationId)
		end
	end

	return normalized
end

local function normalizeEnabledForPlayer(source, playerData)
	local normalized = {}
	local data = typeof(playerData) == "table" and playerData or {}

	for _, definition in ipairs(AutomationConfig.GetAll()) do
		if isAutomationUnlocked(data, definition) then
			normalized[definition.id] = source and source[definition.id] == true
		else
			normalized[definition.id] = false
		end
	end

	return normalized
end

local function projectPresetForPlayer(playerData, preset)
	if typeof(preset) ~= "table" then
		return nil
	end

	return {
		enabled = normalizeEnabledForPlayer(preset.enabled, playerData),
		priority = normalizePriorityList(preset.priority),
		name = preset.name,
	}
end

local function determineActivePresetIndex(settings, playerData)
	if typeof(settings) ~= "table" or typeof(settings.presets) ~= "table" then
		return nil
	end

	local currentEnabled = normalizeEnabledForPlayer(settings.enabled, playerData)
	local currentPriority = normalizePriorityList(settings.priority)

	for index, preset in ipairs(settings.presets) do
		local projection = projectPresetForPlayer(playerData, preset)
		local matches = projection ~= nil

		if matches then
			for automationId, value in pairs(projection.enabled) do
				if currentEnabled[automationId] ~= value then
					matches = false
					break
				end
			end
		end

		if matches then
			for orderIndex, automationId in ipairs(projection.priority) do
				if currentPriority[orderIndex] ~= automationId then
					matches = false
					break
				end
			end
		end

		if matches then
			return index
		end
	end

	return nil
end

local function buildPresetState(player, settings, playerData, consumeAutoSwitchNotice)
	if typeof(settings) ~= "table" then
		return nil
	end

	local state = {
		presets = {},
		settings = {
			enabled = normalizeEnabledForPlayer(settings.enabled, playerData),
			priority = normalizePriorityList(settings.priority),
		},
		activePreset = determineActivePresetIndex(settings, playerData),
	}

	local autoSwitchIndex = clampAutoSwitchPresetIndex(settings.autoSwitchPresetIndex)
	local maxUnlocked = getMaxUnlockedPresetIndex(player)
	if autoSwitchIndex > maxUnlocked then
		autoSwitchIndex = maxUnlocked
	end
	state.autoSwitch = {
		enabled = settings.autoSwitchOnPrestige == true,
		presetIndex = autoSwitchIndex,
		maxPresetIndex = maxUnlocked,
	}

	for index = 1, presetSlotCount do
		local preset = settings.presets and settings.presets[index]
		if preset then
			state.presets[index] = clonePresetForClient(preset)
		end
	end

	state.presetUnlocks = {}
	for index = 1, presetSlotCount do
		state.presetUnlocks[index] = isPresetUnlocked(player, index)
	end

	state.maxUnlockedPresetIndex = maxUnlocked
	state.presetGamepass = {
		index = 4,
		gamepassId = AutomationConstants.GamepassIdPreset4,
	}

	if consumeAutoSwitchNotice and autoSwitchNotices[player] then
		state.autoSwitchApplied = true
		autoSwitchNotices[player] = nil
	end

	return state
end

local function getAnalyticsState(player)
        local state = analyticsByPlayer[player]
        if state then
                return state
        end

        state = {
                purchases = 0,
                spent = 0,
                upgrades = 0,
                stallCount = 0,
                timeEnabled = 0,
                enabledStart = nil,
                lastSummary = time(),
                toggleSignature = "",
        }
        analyticsByPlayer[player] = state
        return state
end

local function getPrestigeLevel(player): number
        local data = PlayerDataService.Get(player)
        if typeof(data) ~= "table" then
                return 0
        end

        local prestige = data.prestige
        if typeof(prestige) ~= "number" then
                return 0
        end

        return math.max(0, prestige)
end

local function getSessionTime(player)
        local startTime = sessionStartTimes[player]
        if not startTime then
                return 0
        end

        return math.max(0, time() - startTime)
end

local anyAutomationEnabled

local function recordEnabledTime(player, settings, now)
        local analytics = getAnalyticsState(player)
        local active = false
        if anyAutomationEnabled then
                active = anyAutomationEnabled(settings)
        end

        if active then
                if not analytics.enabledStart then
                        analytics.enabledStart = now
                end
        elseif analytics.enabledStart then
                analytics.timeEnabled += math.max(0, now - analytics.enabledStart)
                analytics.enabledStart = nil
        end

        return analytics, active
end

local function getToggleSignature(settings)
        if typeof(settings) ~= "table" or typeof(settings.enabled) ~= "table" then
                return ""
        end

        local flags = {
                settings.enabled.auto_cpu == true,
                settings.enabled.auto_ram == true,
                settings.enabled.auto_storage == true,
        }

        return table.concat(flags, "|")
end

local function logAutoBuyToggle(player, settings)
        if isStudio() then
                return
        end

        local analytics = getAnalyticsState(player)
        local order = getPriorityOrder(player, settings)
        local prioritySignature = getPrioritySignature(order)
        local toggleSignature = string.format("%s|%s", getToggleSignature(settings), prioritySignature)

        if toggleSignature == analytics.toggleSignature then
                return
        end

        analytics.toggleSignature = toggleSignature

        local payload = {
                CPU = settings.enabled.auto_cpu == true,
                RAM = settings.enabled.auto_ram == true,
                STORAGE = settings.enabled.auto_storage == true,
                Priority = prioritySignature,
                PrestigeLevel = getPrestigeLevel(player),
        }

        logCustomEvent(player, "AutoBuyToggle", 1, payload)
end

local function logAutoBuySummary(player, settings, force)
        if isStudio() then
                return
        end

        local now = time()
        local analytics = getAnalyticsState(player)

        if not force and (now - analytics.lastSummary) < SUMMARY_INTERVAL then
                return
        end

        recordEnabledTime(player, settings, now)

        local enabledTime = analytics.timeEnabled
        if analytics.enabledStart then
                enabledTime += math.max(0, now - analytics.enabledStart)
        end

        local totalSpent = math.max(0, analytics.spent)
        local purchaseCount = math.max(0, analytics.purchases)
        local stallCount = math.max(0, analytics.stallCount)
        local upgradesGained = math.max(0, analytics.upgrades)

        if not force and enabledTime <= 0 and purchaseCount <= 0 and stallCount <= 0 and upgradesGained <= 0 and totalSpent <= 0 then
                return
        end

        local payload = {
                Purchases = purchaseCount,
                LevelsGained = upgradesGained,
                TotalSpent = totalSpent,
                ActiveTimeSec = enabledTime,
                StallCount = stallCount,
                PrestigeLevel = getPrestigeLevel(player),
                SessionTimeSec = getSessionTime(player),
        }

        logCustomEvent(player, "AutoBuySummary", 1, payload)

        analytics.purchases = 0
        analytics.spent = 0
        analytics.upgrades = 0
        analytics.stallCount = 0
        analytics.timeEnabled = 0
        analytics.lastSummary = now

        if analytics.enabledStart then
                analytics.enabledStart = now
        end
end

local function getPlayerSettings(player)
	local cached = playerSettingsCache[player]
	if cached then
		return cached
	end

	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end

	local sanitized = sanitizeSettings(data.automation)
	playerSettingsCache[player] = sanitized
	return sanitized
end

local function buildAutoBuySnapshot(settings)
	local snapshot = {}
	if settings and typeof(settings.enabled) == "table" then
		for branch, automationId in pairs(SIMPLE_AUTO_BRANCHES) do
			snapshot[branch] = settings.enabled[automationId] == true
		end
	else
		for branch in pairs(SIMPLE_AUTO_BRANCHES) do
			snapshot[branch] = false
		end
	end
	return snapshot
end

isAutomationUnlocked = function(playerData, automation)
	if not automation then
		return false
	end

	local requirements = automation.unlockRequirement
	if not requirements then
		return true
	end

	if requirements.prestigeLevel then
		local prestige = typeof(playerData.prestige) == "number" and playerData.prestige or 0
		if prestige < requirements.prestigeLevel then
			return false
		end
	end

	if requirements.storageTier then
		local tier = UpgradeConfig.GetStorageTier(playerData.upgrades or {})
		if tier < requirements.storageTier then
			return false
		end
	end

	return true
end

local function getPriorityOrder(player, settings)
	local order = {}
	local source = settings and settings.priority
	if typeof(source) == "table" then
		for _, automationId in ipairs(source) do
			if automationById[automationId] and not table.find(order, automationId) then
				table.insert(order, automationId)
			end
		end
	end

	for _, automationId in ipairs(DEFAULT_PRIORITY) do
		if not table.find(order, automationId) then
			table.insert(order, automationId)
		end
	end

	return order
end

local function getPrioritySignature(order)
	local segments = {}
	for _, automationId in ipairs(order) do
		local definition = automationById[automationId]
		local short = definition and BRANCH_SHORT_NAMES[definition.branch] or automationId
		table.insert(segments, short)
	end
	return table.concat(segments, ">")
end

local function selectCheapestUpgrade(branch, playerData)
	local definitions = UpgradeConfig.GetUpgradesByBranch(branch)
	local owned = playerData.upgrades or {}
	local currency = typeof(playerData.data) == "number" and playerData.data or 0

        local choiceId
        local choiceCost
        local stalled = true

	for _, upgrade in ipairs(definitions) do
		if not UpgradeConfig.IsMaxed(owned, upgrade.id) and UpgradeConfig.MeetsRequirements(owned, upgrade.id) then
			local level = UpgradeConfig.GetLevel(owned, upgrade.id)
			local cost = UpgradeConfig.GetCost(upgrade.id, level)
			if typeof(cost) == "number" then
				if currency >= cost then
					if not choiceCost or cost < choiceCost then
						choiceCost = cost
						choiceId = upgrade.id
						stalled = false
					end
				end
			end
		end
	end

	return choiceId, stalled and currency > 0
end

local function isBlocked(player)
	local states = blockState[player]
	if not states then
		return false
	end

	local now = time()
	for key, record in pairs(states) do
		if record.active then
			if now - (record.timestamp or 0) > BLOCK_TIMEOUT then
				record.active = false
			else
				return true
			end
		end
	end

	return false
end

local function isAutomationEnabled(player, automationId)
	local settings = getPlayerSettings(player)
	if not settings then
		return false
	end

	local flag = settings.enabled[automationId]
	if flag == nil then
		local definition = automationById[automationId]
		return definition and definition.enabledByDefault or false
	end

	return flag == true
end

anyAutomationEnabled = function(settings)
	if typeof(settings) ~= "table" or typeof(settings.enabled) ~= "table" then
		return false
	end

	for automationId, value in pairs(settings.enabled) do
		if value == true and automationById[automationId] then
			return true
		end
	end

	return false
end

local function tryAutomationPurchase(player, automationId, playerData)
	local automation = automationById[automationId]
	if not automation then
		return playerData
	end

	if not isAutomationEnabled(player, automationId) then
		return playerData
	end

	if not isAutomationUnlocked(playerData, automation) then
		return playerData
	end

	local branch = automation.branch
	if not branch then
		return playerData
	end

	local upgradeId, stalled = selectCheapestUpgrade(branch, playerData)
	if not upgradeId then
		if stalled then
			local analytics = getAnalyticsState(player)
			analytics.stallCount += 1
		end
		return playerData
	end

	local success, purchased, spent = UpgradeService.BuyMax(player, upgradeId)
	if not success then
		if stalled then
			local analytics = getAnalyticsState(player)
			analytics.stallCount += 1
		end
		return playerData
	end

	local updated = PlayerDataService.Get(player)
	if purchased and purchased > 0 then
		local analytics = getAnalyticsState(player)
		analytics.purchases += 1
		analytics.spent += math.max(spent or 0, 0)
		analytics.upgrades += purchased
	end

	return updated
end

local function processPlayerAutomation(player, now)
        if isBlocked(player) then
                return
        end

	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return
	end

	local settings = getPlayerSettings(player)
	if not settings then
		return
	end

	for _, automationId in ipairs(getPriorityOrder(player, settings)) do
		playerData = tryAutomationPurchase(player, automationId, playerData)
		if typeof(playerData) ~= "table" then
			break
                end
        end

        recordEnabledTime(player, settings, now or time())
end

local function getBaseInterval(player, settings)
	local interval = BASE_INTERVAL
	local tier = settings and settings.speedTier or 0
	if typeof(tier) == "number" and tier > 0 then
		local tierInfo = AutomationConfig.GetSpeedTierInfo(tier)
		if tierInfo and typeof(tierInfo.interval) == "number" and tierInfo.interval > 0 then
			interval = math.max(tierInfo.interval, interval)
		end
	end

	local multiplier = SessionRewardService.GetAutomationMultiplier(player)
	if typeof(multiplier) ~= "number" or multiplier <= 0 then
		multiplier = 1
	end

	return math.max(0.1, interval / multiplier)
end

local function automationLoop()
        RunService.Heartbeat:Connect(function()
                local now = time()
                for _, player in ipairs(Players:GetPlayers()) do
                        local settings = getPlayerSettings(player)
                        if settings then
                                local interval = getBaseInterval(player, settings)
                                local last = lastProcessTimes[player]
                                if not last or (now - last) >= interval then
                                        lastProcessTimes[player] = now
                                        processPlayerAutomation(player, now)
                                end

                                logAutoBuySummary(player, settings, false)
                        end
                end
        end)
end

local function persistSettings(player, settings)
	PlayerDataService.Set(player, {
		automation = cloneSettings(settings),
	})
	notifyPresetStateChanged(player)
end

function AutomationService.SetEnabled(player, automationId, enabled)
        if not automationById[automationId] then
                return false
        end

	local settings = getPlayerSettings(player)
        if not settings then
                return false
        end

        settings.enabled[automationId] = enabled == true
        persistSettings(player, settings)

        local now = time()
        recordEnabledTime(player, settings, now)
        logAutoBuyToggle(player, settings)

        return true
end

local function resolveAutoBranch(branch)
	if typeof(branch) ~= "string" then
		return nil, nil
	end
	local automationId = BRANCH_LOOKUP[string.upper(branch)] or BRANCH_LOOKUP[string.lower(branch)]
	if not automationId then
		return nil, nil
	end
	local resolvedBranch = nil
	for name, id in pairs(SIMPLE_AUTO_BRANCHES) do
		if id == automationId then
			resolvedBranch = name
			break
		end
	end
	return automationId, resolvedBranch
end

function AutomationService.SetAutoBuyBranch(player, branch, enabled)
	local automationId, resolvedBranch = resolveAutoBranch(branch)
	if not automationId then
		return false
	end

	local success = AutomationService.SetEnabled(player, automationId, enabled)
	if success then
		local settings = getPlayerSettings(player)
		autoBuyStateCache[player] = buildAutoBuySnapshot(settings)
	end
	return success, resolvedBranch
end

function AutomationService.GetAutoBuyState(player)
	local settings = getPlayerSettings(player)
	local snapshot = buildAutoBuySnapshot(settings)
	autoBuyStateCache[player] = snapshot
	return table.clone(snapshot)
end

function AutomationService.DisableAllAutoBuy(player)
	local settings = getPlayerSettings(player)
	local hadSettings = settings and typeof(settings.enabled) == "table"

	local changed = not hadSettings
	if hadSettings then
		for _, automationId in pairs(SIMPLE_AUTO_BRANCHES) do
			if settings.enabled[automationId] then
				settings.enabled[automationId] = false
				changed = true
			end
		end
	end

	if changed then
		if hadSettings then
			persistSettings(player, settings)
			logAutoBuyToggle(player, settings)
		end
	end

	autoBuyStateCache[player] = buildAutoBuySnapshot(settings)
end

function AutomationService.ClearAutoBuyState(player)
	autoBuyStateCache[player] = nil
end

function AutomationService.SetPriority(player, ordered)
	if typeof(ordered) ~= "table" then
		return false
	end

	local settings = getPlayerSettings(player)
	if not settings then
		return false
	end

	local newOrder = {}
	for _, automationId in ipairs(ordered) do
		if automationById[automationId] and not table.find(newOrder, automationId) then
			table.insert(newOrder, automationId)
		end
	end

	for _, automationId in ipairs(DEFAULT_PRIORITY) do
		if not table.find(newOrder, automationId) then
			table.insert(newOrder, automationId)
		end
        end

        settings.priority = newOrder
        persistSettings(player, settings)
        logAutoBuyToggle(player, settings)
        return true
end

function AutomationService.SetAutoSwitchSettings(player, enabled, presetIndex)
	local settings = getPlayerSettings(player)
	if not settings then
		return false
	end

	local newIndex = clampAutoSwitchPresetIndex(presetIndex)
	if not isPresetUnlocked(player, newIndex) then
		newIndex = getMaxUnlockedPresetIndex(player)
	end

	settings.autoSwitchOnPrestige = enabled == true
	settings.autoSwitchPresetIndex = newIndex
	persistSettings(player, settings)

	return true
end

function AutomationService.ApplyAutoSwitchPreset(player)
	local settings = getPlayerSettings(player)
	if not settings or settings.autoSwitchOnPrestige ~= true then
		return false
	end

	local targetIndex = clampPresetIndex(settings.autoSwitchPresetIndex)
	if not targetIndex then
		return false
	end

	if not isPresetUnlocked(player, targetIndex) then
		return false
	end

	autoSwitchNotices[player] = true
	local success = AutomationService.ApplyPreset(player, targetIndex)
	if not success then
		autoSwitchNotices[player] = nil
	end
	return success
end

function AutomationService.PurchaseSpeedTier(player)
	local settings = getPlayerSettings(player)
	if not settings then
		return false, "locked"
	end

	local currentTier = settings.speedTier or 0
	if currentTier >= maxSpeedTier then
		return false, "max"
	end

	local nextTier = currentTier + 1
	local nextInfo = AutomationConfig.GetSpeedTierInfo(nextTier)
	local cost = nextInfo and nextInfo.cost or 0

	local data = PlayerDataService.Get(player)
	if typeof(data) ~= "table" then
		return false, "locked"
	end

	local currency = typeof(data.data) == "number" and data.data or 0
	if currency < cost then
		return false, "poor"
	end

	data.data = currency - cost
	settings.speedTier = nextTier
	PlayerDataService.Set(player, {
		data = data.data,
		automation = cloneSettings(settings),
	})

	return true, nextTier
end

function AutomationService.SetBlockingFlag(player, key, value)
	if key ~= "prestige" and key ~= "store" then
		return
	end

	blockState[player] = blockState[player] or {}
	blockState[player][key] = {
		active = value == true,
		timestamp = time(),
	}
end

function AutomationService.GetPresetState(player, consumeAutoSwitchNotice)
	local settings = getPlayerSettings(player)
	if not settings then
		return nil
	end

	local playerData = PlayerDataService.Get(player)
	return buildPresetState(player, settings, playerData, consumeAutoSwitchNotice == true)
end

function AutomationService.ApplyPreset(player, presetIndex)
	local settings = getPlayerSettings(player)
	if not settings then
		return false, "uninitialized"
	end

	local clamped = clampPresetIndex(presetIndex)
	if not clamped then
		return false, "invalid"
	end

	if not isPresetUnlocked(player, clamped) then
		return false, "locked_preset"
	end

	local preset = settings.presets and settings.presets[clamped]
	if not preset then
		return false, "missing"
	end

	local playerData = PlayerDataService.Get(player)
	local projection = projectPresetForPlayer(playerData, preset)
	if not projection then
		return false, "missing"
	end

	settings.enabled = table.clone(projection.enabled)
	settings.priority = table.clone(projection.priority)

	persistSettings(player, settings)
	recordEnabledTime(player, settings, time())
	logAutoBuyToggle(player, settings)

	return true, buildPresetState(player, settings, playerData, false)
end

function AutomationService.SavePreset(player, presetIndex, payload)
	local settings = getPlayerSettings(player)
	if not settings then
		return false, "uninitialized"
	end

	local clamped = clampPresetIndex(presetIndex)
	if not clamped then
		return false, "invalid"
	end

	if not isPresetUnlocked(player, clamped) then
		return false, "locked_preset"
	end

	settings.presets = settings.presets or {}

	local existing = settings.presets[clamped]
	local sanitized = sanitizePresetEntry(payload, existing, false)
	local playerData = PlayerDataService.Get(player)

	sanitized.enabled = normalizeEnabledForPlayer(sanitized.enabled, playerData)
	sanitized.priority = normalizePriorityList(sanitized.priority)

	settings.presets[clamped] = sanitized
	persistSettings(player, settings)

	return true, buildPresetState(player, settings, playerData, false)
end

local function buildAutomationEntries(player, settings)
	local playerData = PlayerDataService.Get(player)
	local entries = {}
	for _, definition in ipairs(AutomationConfig.GetAll()) do
		local unlocked = typeof(playerData) == "table" and isAutomationUnlocked(playerData, definition) or false
		table.insert(entries, {
			id = definition.id,
			name = definition.name,
			description = definition.description,
			branch = definition.branch,
			enabled = settings.enabled[definition.id] == true,
			unlocked = unlocked,
			unlockRequirement = definition.unlockRequirement,
		})
	end
	return entries
end

function AutomationService.GetClientState(player)
	local settings = getPlayerSettings(player)
	if not settings then
		return nil
	end

	local entries = buildAutomationEntries(player, settings)
	local order = getPriorityOrder(player, settings)
	local tier = settings.speedTier or 0
	local tierInfo = AutomationConfig.GetSpeedTierInfo(tier)
	local nextTier = math.min(tier + 1, maxSpeedTier)
	local canUpgrade = nextTier > tier
	local nextInfo = AutomationConfig.GetSpeedTierInfo(nextTier)
	local data = PlayerDataService.Get(player)
	local currency = typeof(data) == "table" and typeof(data.data) == "number" and data.data or 0

	return {
		automations = entries,
		priority = order,
		speed = {
			tier = tier,
			interval = tierInfo and tierInfo.interval or 0.5,
			nextTier = canUpgrade and nextTier or tier,
			nextInterval = canUpgrade and nextInfo and nextInfo.interval or nil,
			cost = canUpgrade and nextInfo and nextInfo.cost or 0,
			canUpgrade = canUpgrade,
			canAfford = canUpgrade and currency >= (nextInfo and nextInfo.cost or 0) or false,
			maxTier = maxSpeedTier,
		},
	}
end

function AutomationService.Init()
	if AutomationService._initialized then
		return
	end
	AutomationService._initialized = true

        Players.PlayerAdded:Connect(function(player)
                playerSettingsCache[player] = nil
                getPlayerSettings(player)
                sessionStartTimes[player] = time()
                getAnalyticsState(player)
                observePresetUnlockAttribute(player)
                autoSwitchNotices[player] = nil
        end)

        Players.PlayerRemoving:Connect(function(player)
                logAutoBuySummary(player, getPlayerSettings(player), true)
                playerSettingsCache[player] = nil
                lastProcessTimes[player] = nil
                blockState[player] = nil
                analyticsByPlayer[player] = nil
                sessionStartTimes[player] = nil
                if presetUnlockConnections[player] then
                        presetUnlockConnections[player]:Disconnect()
                        presetUnlockConnections[player] = nil
                end
                autoSwitchNotices[player] = nil
		autoBuyStateCache[player] = nil
        end)

        for _, player in ipairs(Players:GetPlayers()) do
                playerSettingsCache[player] = nil
                getPlayerSettings(player)
                sessionStartTimes[player] = time()
                getAnalyticsState(player)
                observePresetUnlockAttribute(player)
                autoSwitchNotices[player] = nil
		autoBuyStateCache[player] = nil
        end

	automationLoop()
end

return AutomationService
