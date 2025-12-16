local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)

local UpgradeService = {}

local function getUpgradeDefinition(upgradeId)
	if typeof(upgradeId) ~= "string" then
		return nil
	end

	return UpgradeConfig.GetUpgradeById(upgradeId)
end

local function ensurePlayerState(player)
	local state = PlayerDataService.Get(player)
	if typeof(state) ~= "table" then
		return nil
	end

	if typeof(state.upgrades) ~= "table" then
		state.upgrades = {}
	end

	if typeof(state.data) ~= "number" then
		state.data = 0
	end

	return state
end

local function evaluatePurchase(state, upgradeId)
	local definition = getUpgradeDefinition(upgradeId)
	if not definition then
		return false, nil, 0, "locked"
	end

	local upgrades = state.upgrades
	local currentLevel = UpgradeConfig.GetLevel(upgrades, upgradeId)

	if UpgradeConfig.IsMaxed(upgrades, upgradeId) then
		return false, nil, currentLevel, "max"
	end

	if not UpgradeConfig.MeetsRequirements(upgrades, upgradeId) then
		return false, nil, currentLevel, "locked"
	end

	local cost = UpgradeConfig.GetCost(upgradeId, currentLevel)
	if typeof(cost) ~= "number" then
		return false, nil, currentLevel, "locked"
	end

	if (state.data or 0) < cost then
		return false, cost, currentLevel, "poor"
	end

	return true, cost, currentLevel, nil
end

function UpgradeService.CanBuy(player, upgradeId)
	local state = ensurePlayerState(player)
	if not state then
		return false, "locked"
	end

	local success, _, _, reason = evaluatePurchase(state, upgradeId)
	return success, reason
end

function UpgradeService.Buy(player, upgradeId)
	local state = ensurePlayerState(player)
	if not state then
		return false, "locked"
	end

	local success, cost, currentLevel, reason = evaluatePurchase(state, upgradeId)
	if not success then
		return false, reason
	end

	state.data = (state.data or 0) - cost
	state.upgrades[upgradeId] = currentLevel + 1

	PlayerDataService.Set(player, state)

	return true
end

return UpgradeService
