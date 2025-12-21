local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = {}

local DATASTORE_NAME = "PlayerProgress"
local MAX_RETRIES = 3
local RETRY_DELAY = 2

local defaultData = {
	data = 0,
	peakData = 0,
	dataEarnedThisRun = 0,
	upgrades = {},
	prestige = 0,
	prestigePoints = 0,
	ppSpent = 0,
	unlocks = {},
	automation = {
		cpuAuto = false,
		ramAuto = false,
		stoAuto = false,
		tickMs = 1000,
		enabled = true,
	},
	globalLikeClaims = {},
	hasClaimedFavoriteReward = false,
	productionBonus = 0,
	automationMultiplier = 0,
	claimedLikes = {},
	claimedFavorites = {},
	highestLikeMilestoneClaimed = 0,
	prestigeUpgrades = {
		globalProduction = 0,
		autoSpeed = 0,
		offlineEfficiency = 0,
		costReduction = 0,
		pp_global_mult_1 = 0,
		pp_cpu_mult_1 = 0,
		pp_ram_mult_1 = 0,
		pp_storage_mult_1 = 0,
		pp_auto_speed_1 = 0,
		pp_auto_eff_1 = 0,
		pp_offline_core_1 = 0,
		pp_prestige_gain_1 = 0,
		pp_prestige_req_1 = 0,
		pp_auto_bypass_1 = 0,
		pp_batch_buy_1 = 0,
		pp_milestone_amp_1 = 0,
		pp_endgame_boost_1 = 0,
	},
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
	if typeof(payload.peakData) == "number" then
		sanitized.peakData = payload.peakData
	end
	if typeof(payload.dataEarnedThisRun) == "number" then
		sanitized.dataEarnedThisRun = payload.dataEarnedThisRun
	end

	sanitized.upgrades = sanitizeUpgrades(payload.upgrades)

	if typeof(payload.prestige) == "number" then
		sanitized.prestige = payload.prestige
	end
	if typeof(payload.prestigePoints) == "number" then
		sanitized.prestigePoints = payload.prestigePoints
	end
	if typeof(payload.ppSpent) == "number" then
		sanitized.ppSpent = payload.ppSpent
	end
	if typeof(payload.unlocks) == "table" then
		local cleanedUnlocks = {}
		for nodeId, enabled in pairs(payload.unlocks) do
			if typeof(nodeId) == "string" and enabled == true then
				cleanedUnlocks[nodeId] = true
			end
		end
		sanitized.unlocks = cleanedUnlocks
	end
	if typeof(payload.automation) == "table" then
		local auto = payload.automation
		if typeof(auto.cpuAuto) == "boolean" then
			sanitized.automation.cpuAuto = auto.cpuAuto
		end
		if typeof(auto.ramAuto) == "boolean" then
			sanitized.automation.ramAuto = auto.ramAuto
		end
		if typeof(auto.stoAuto) == "boolean" then
			sanitized.automation.stoAuto = auto.stoAuto
		end
		if typeof(auto.tickMs) == "number" then
			sanitized.automation.tickMs = auto.tickMs
		end
		if typeof(auto.enabled) == "boolean" then
			sanitized.automation.enabled = auto.enabled
		end
	end
	if typeof(payload.globalLikeClaims) == "table" then
		local claims = {}
		for milestoneId, claimed in pairs(payload.globalLikeClaims) do
			if typeof(milestoneId) == "string" and claimed == true then
				claims[milestoneId] = true
			end
		end
		sanitized.globalLikeClaims = claims
	end
	if typeof(payload.claimedLikes) == "table" then
		local claims = {}
		for milestoneId, claimed in pairs(payload.claimedLikes) do
			if typeof(milestoneId) == "string" and claimed == true then
				claims[milestoneId] = true
			end
		end
		sanitized.claimedLikes = claims
	end
	if typeof(payload.claimedFavorites) == "table" then
		local claims = {}
		for milestoneId, claimed in pairs(payload.claimedFavorites) do
			if typeof(milestoneId) == "string" and claimed == true then
				claims[milestoneId] = true
			end
		end
		sanitized.claimedFavorites = claims
	end
	if typeof(payload.highestLikeMilestoneClaimed) == "number" then
		sanitized.highestLikeMilestoneClaimed = payload.highestLikeMilestoneClaimed
	end
	if typeof(payload.hasClaimedFavoriteReward) == "boolean" then
		sanitized.hasClaimedFavoriteReward = payload.hasClaimedFavoriteReward
	end
	if typeof(payload.productionBonus) == "number" then
		sanitized.productionBonus = payload.productionBonus
	end
	if typeof(payload.automationMultiplier) == "number" then
		sanitized.automationMultiplier = payload.automationMultiplier
	end
	if typeof(payload.prestigeUpgrades) == "table" then
		local pu = payload.prestigeUpgrades
		if typeof(pu.globalProduction) == "number" then
			sanitized.prestigeUpgrades.globalProduction = pu.globalProduction
		end
		if typeof(pu.autoSpeed) == "number" then
			sanitized.prestigeUpgrades.autoSpeed = pu.autoSpeed
		end
		if typeof(pu.offlineEfficiency) == "number" then
			sanitized.prestigeUpgrades.offlineEfficiency = pu.offlineEfficiency
		end
		if typeof(pu.costReduction) == "number" then
			sanitized.prestigeUpgrades.costReduction = pu.costReduction
		end
		for _, key in ipairs({
			"pp_global_mult_1",
			"pp_cpu_mult_1",
			"pp_ram_mult_1",
			"pp_storage_mult_1",
			"pp_auto_speed_1",
			"pp_auto_eff_1",
			"pp_offline_core_1",
			"pp_prestige_gain_1",
			"pp_prestige_req_1",
			"pp_auto_bypass_1",
			"pp_batch_buy_1",
			"pp_milestone_amp_1",
			"pp_endgame_boost_1",
		}) do
			if typeof(pu[key]) == "number" then
				sanitized.prestigeUpgrades[key] = pu[key]
			end
		end
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
