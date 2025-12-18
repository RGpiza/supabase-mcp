local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local SaveScheduler = require(script.Parent.SaveScheduler)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local EconomyAnalytics = require(script.Parent.EconomyAnalytics)
local LeaderboardService = require(script.Parent.LeaderboardService)
local GlobalStatsService = require(script.Parent.GlobalStatsService)

local PrestigeService = {}

local REQUIRED_TIER = 3
local PRESTIGE_UNIT = 0.1
local PRESTIGE_MULTIPLIER = 1.15
local PRESTIGE_UNLOCK_UPGRADE_ID = "sto_3"

local prestigeRequirementCache

local function getPlayerState(player)
	local state = PlayerDataService.Get(player)
	if typeof(state) ~= "table" then
		warn("[PrestigeService] Invalid player data for", player)
		return nil
	end

	if typeof(state.upgrades) ~= "table" then
		state.upgrades = {}
	end

	return state
end

local function getPrestigeRequirementCost()
	if prestigeRequirementCache then
		return prestigeRequirementCache
	end

	local cost = UpgradeConfig.GetCost(PRESTIGE_UNLOCK_UPGRADE_ID, 0)
	if typeof(cost) ~= "number" then
		cost = 0
	end

	prestigeRequirementCache = math.max(cost, 0)
	return prestigeRequirementCache
end

local function computeCurrentMultiplier(state)
	local bonusUnits = typeof(state.corePower) == "number" and math.max(state.corePower, 0) or 0
	return 1 + (bonusUnits * PRESTIGE_UNIT)
end

local function computePrestigePreview(state)
	local currentMultiplier = computeCurrentMultiplier(state)
	local newMultiplier = currentMultiplier * PRESTIGE_MULTIPLIER

	return currentMultiplier, newMultiplier, math.max(newMultiplier - currentMultiplier, 0)
end

function PrestigeService.CanPrestige(player)
	local state = getPlayerState(player)
	if not state then
		return false
	end

	local tier = UpgradeConfig.GetStorageTier(state.upgrades)
	return tier >= REQUIRED_TIER
end

function PrestigeService.Prestige(player)
	if not PrestigeService.CanPrestige(player) then
		return false
	end

	local state = getPlayerState(player)
	if not state then
		return false
	end

	local currentBonusUnits = typeof(state.corePower) == "number" and state.corePower or 0
	local currentMultiplier, newMultiplier = computePrestigePreview(state)
	local newBonusUnits = math.max(((newMultiplier - 1) / PRESTIGE_UNIT), 0)

	local prestigeLevel = (state.prestige or 0) + 1
	local spentData = math.max(state.data or 0, 0)

	state.data = 0
	state.upgrades = {}
	state.prestige = prestigeLevel
	state.corePower = newBonusUnits

	PlayerDataService.Set(player, state)
	SaveScheduler.FlushPlayer(player, true)
	LeaderboardService.ForceSync(player)
	GlobalStatsService.AddPrestige(1)

	if spentData > 0 then
		EconomyAnalytics.LogSink(
			player,
			spentData,
			state.data,
			Enum.AnalyticsEconomyTransactionType.Gameplay,
			"Prestige_Reset",
			{
				PrestigeLevel = prestigeLevel,
			}
		)
	end

	local gainedCore = math.max(newBonusUnits - currentBonusUnits, 0)
	if gainedCore > 0 then
		EconomyAnalytics.LogSource(
			player,
			gainedCore,
			state.corePower,
			Enum.AnalyticsEconomyTransactionType.Gameplay,
			"Prestige_CoreGain",
			{
				PrestigeLevel = prestigeLevel,
			}
		)
	end

	return true
end

function PrestigeService.GetPrestigeRequirement()
	return getPrestigeRequirementCost()
end

function PrestigeService.GetPreview(player)
	local state = getPlayerState(player)
	if not state then
		return nil
	end

	local currentData = typeof(state.data) == "number" and math.max(state.data, 0) or 0
	local storageTier = UpgradeConfig.GetStorageTier(state.upgrades or {})
	local canPrestige = storageTier >= REQUIRED_TIER
	local currentMultiplier, newMultiplier, gain = computePrestigePreview(state)

	return {
		canPrestige = canPrestige,
		currentData = currentData,
		unlockRequirement = getPrestigeRequirementCost(),
		currentMultiplier = currentMultiplier,
		nextMultiplier = newMultiplier,
		multiplierGain = gain,
		storageTier = storageTier,
	}
end

return PrestigeService
