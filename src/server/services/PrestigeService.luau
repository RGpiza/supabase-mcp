local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)
local LeaderboardService = require(script.Parent.LeaderboardService)

local PrestigeService = {}

local REQUIRED_TIER = 3
local PRESTIGE_UNIT = 0.1
local PRESTIGE_MULTIPLIER = 1.15

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
	local currentMultiplier = 1 + (currentBonusUnits * PRESTIGE_UNIT)
	local newMultiplier = currentMultiplier * PRESTIGE_MULTIPLIER
	local newBonusUnits = math.max(((newMultiplier - 1) / PRESTIGE_UNIT), 0)

	state.data = 0
	state.upgrades = {}
	state.prestige = (state.prestige or 0) + 1
	state.corePower = newBonusUnits

	PlayerDataService.Set(player, state)
	PlayerDataService.Save(player)
	LeaderboardService.UpdatePlayerStat(player, state.data or 0)

	return true
end

return PrestigeService
