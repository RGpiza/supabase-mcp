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

local function planPurchase(state, upgradeId, desiredQuantity)
	local success, _, currentLevel, reason = evaluatePurchase(state, upgradeId)
	if not success then
		return 0, state.data or 0, currentLevel, reason
	end

	local definition = getUpgradeDefinition(upgradeId)
	if not definition then
		return 0, state.data or 0, currentLevel, "locked"
	end

	local remainingData = state.data or 0
	local purchases = 0
	local maxLevel = definition.maxLevel

	while currentLevel < maxLevel do
		if desiredQuantity and purchases >= desiredQuantity then
			break
		end

		local cost = UpgradeConfig.GetCost(upgradeId, currentLevel)
		if typeof(cost) ~= "number" or remainingData < cost then
			break
		end

		remainingData -= cost
		currentLevel += 1
		purchases += 1
	end

	if purchases <= 0 then
		return 0, state.data or 0, currentLevel, "poor"
	end

	return purchases, remainingData, currentLevel, nil
end

local function executePurchase(player, upgradeId, desiredQuantity)
	local state = ensurePlayerState(player)
	if not state then
		return false, "locked", 0, 0
	end

	local startingData = state.data or 0
	local quantity, remainingData, resultingLevel, reason = planPurchase(state, upgradeId, desiredQuantity)
	if quantity <= 0 then
		return false, reason or "locked", 0, 0
	end

	state.data = remainingData
	state.upgrades[upgradeId] = resultingLevel

	PlayerDataService.Set(player, state)

	local spent = math.max(0, startingData - remainingData)
	return true, quantity, spent
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
	local success, reasonOrQuantity, spent = executePurchase(player, upgradeId, 1)
	if not success then
		return false, reasonOrQuantity
	end

	return true, reasonOrQuantity, spent
end

function UpgradeService.BuyMax(player, upgradeId)
	local success, purchased, spent = executePurchase(player, upgradeId, nil)
	return success, purchased, spent
end

return UpgradeService
