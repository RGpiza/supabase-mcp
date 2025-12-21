local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local PrestigeConfig = require(ReplicatedStorage.Shared.PrestigeConfig)
local LeaderboardService = require(script.Parent.LeaderboardService)
local AnalyticsTrackerService = require(script.Parent.AnalyticsTrackerService)
local PrestigePointsService = require(script.Parent.PrestigePointsService)

local PrestigeService = {}

local REQUIRED_TIER = 3
local PRESTIGE_UNIT = 0.25
local BASE_REQUIREMENT = PrestigeConfig.PP_BASE_REQUIREMENT
local PP_CAP = PrestigeConfig.PP_CAP
local PP_GAIN_POWER = PrestigeConfig.PP_GAIN_POWER
local PP_GAIN_MULT = PrestigeConfig.PP_GAIN_MULT
local prestigeInProgress = {}

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

function PrestigeService.CanPrestige(player)
	local state = getPlayerState(player)
	if not state then
		return false
	end

	local earned = typeof(state.dataEarnedThisRun) == "number" and state.dataEarnedThisRun or 0
	local reqLevel = PrestigePointsService.GetUpgradeLevel(state, "pp_prestige_req_1")
	local reqReduction = math.clamp(reqLevel * 0.05, 0, 0.25)
	local effectiveRequirement = BASE_REQUIREMENT * (1 - reqReduction)
	if earned < effectiveRequirement then
		return false
	end

	local tier = UpgradeConfig.GetStorageTier(state.upgrades)
	return tier >= REQUIRED_TIER
end

function PrestigeService.CalculatePrestigePointsGain(state)
	if typeof(state) ~= "table" then
		return 0
	end
	local earned = typeof(state.dataEarnedThisRun) == "number" and state.dataEarnedThisRun or 0
	local reqLevel = PrestigePointsService.GetUpgradeLevel(state, "pp_prestige_req_1")
	local reqReduction = math.clamp(reqLevel * 0.05, 0, 0.25)
	local effectiveRequirement = BASE_REQUIREMENT * (1 - reqReduction)
	if earned < effectiveRequirement then
		return 0
	end
	local ratio = earned / effectiveRequirement
	local gain = math.floor((ratio ^ PP_GAIN_POWER) * PP_GAIN_MULT)
	local gainLevel = PrestigePointsService.GetUpgradeLevel(state, "pp_prestige_gain_1")
	local gainMult = 1 + (gainLevel * 0.07)
	gain = math.floor(gain * gainMult)
	if gain < 1 then
		gain = 1
	end
	if gain > PP_CAP then
		gain = PP_CAP
	end
	return gain
end

function PrestigeService.CalculateNextPrestigeThreshold(state)
	if typeof(state) ~= "table" then
		return BASE_REQUIREMENT
	end
	local earned = typeof(state.dataEarnedThisRun) == "number" and state.dataEarnedThisRun or 0
	local reqLevel = PrestigePointsService.GetUpgradeLevel(state, "pp_prestige_req_1")
	local reqReduction = math.clamp(reqLevel * 0.05, 0, 0.25)
	local effectiveRequirement = BASE_REQUIREMENT * (1 - reqReduction)
	if earned < effectiveRequirement then
		return math.floor(effectiveRequirement)
	end
	local currentGain = PrestigeService.CalculatePrestigePointsGain(state)
	local nextGain = currentGain + 1
	local nextEarned = effectiveRequirement * ((nextGain / PP_GAIN_MULT) ^ (1 / PP_GAIN_POWER))
	return math.floor(nextEarned)
end

function PrestigeService.Prestige(player)
	if not PrestigeService.CanPrestige(player) then
		return false
	end
	if prestigeInProgress[player] then
		return false
	end

	local state = getPlayerState(player)
	if not state then
		return false
	end

	prestigeInProgress[player] = true

	local pointsGain = PrestigeService.CalculatePrestigePointsGain(state)
	if pointsGain <= 0 then
		prestigeInProgress[player] = nil
		return false
	end
	local prestigeBefore = state.prestige or 0
	local dataAtPrestige = state.data or 0
	state.prestigePoints = (state.prestigePoints or 0) + pointsGain
	state.data = 0
	state.upgrades = {}
	state.peakData = 0
	state.dataEarnedThisRun = 0
	state.prestige = (state.prestige or 0) + 1
	state.corePower = 0
	state.boostExpiresAt = 0
	state.boostEnd = 0

	PlayerDataService.Set(player, state)
	PlayerDataService.Save(player)
	LeaderboardService.UpdatePlayerStat(player, state.data or 0)
	AnalyticsTrackerService.LogEconomySource(
		player,
		"PrestigePoints",
		pointsGain,
		state.prestigePoints,
		Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		"PrestigeReward",
		{
			prestigeBefore = prestigeBefore,
			prestigeAfter = state.prestige or 0,
			dataAtPrestige = math.floor(dataAtPrestige),
		}
	)
	AnalyticsTrackerService.LogCustomValue(player, "PrestigeTriggered", pointsGain, {
		prestigeAfter = state.prestige or 0,
	})
	AnalyticsTrackerService.TrackFirstPrestige(player)
	prestigeInProgress[player] = nil

	return true
end

function PrestigeService.IsPrestiging(player)
	return prestigeInProgress[player] == true
end

return PrestigeService
