local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local SaveScheduler = require(script.Parent.SaveScheduler)
local UpgradeConfig = require(ReplicatedStorage.Shared.UpgradeConfig)

local UpgradeService = {}

local function getUpgradeDefinition(upgradeId)
	if typeof(upgradeId) ~= "string" then
		return nil
	end

	return UpgradeConfig.ById[upgradeId]
end

local function resolveUpgradeLevel(upgrades, upgradeId)
	if typeof(upgrades) ~= "table" then
		return 0
	end

	local level = upgrades[upgradeId]
	if typeof(level) ~= "number" then
		return 0
	end

	return math.max(level, 0)
end

local function validateUpgradeCost(upgrade, upgradeId, currentLevel)
	if upgrade.maxLevel and currentLevel >= upgrade.maxLevel then
		return false
	end

	local cost = UpgradeConfig.getUpgradeCost(upgradeId, currentLevel)
	if typeof(cost) ~= "number" then
		return false
	end

	return true, cost
end

local function cloneState(playerData)
	if typeof(playerData) ~= "table" then
		return nil
	end

	return table.clone(playerData)
end

local function getCurrency(playerData)
	if typeof(playerData.data) ~= "number" then
		return 0
	end

	return playerData.data
end

local function ensureUpgradeTable(playerData)
	if typeof(playerData.upgrades) ~= "table" then
		playerData.upgrades = {}
	end

	return playerData.upgrades
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
	SaveScheduler.FlushPlayer(player)

	local spent = math.max(0, startingData - remainingData)
	return true, quantity, spent
end

function UpgradeService.CanBuy(player, upgradeId)
	local upgrade = getUpgradeDefinition(upgradeId)
	if not upgrade then
		return false, nil
	end

	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return false, nil
	end

	local upgrades = ensureUpgradeTable(playerData)
	local currentLevel = resolveUpgradeLevel(upgrades, upgradeId)

	local storageTier = UpgradeConfig.GetStorageTier(upgrades)
	if upgrade.id == "sto_2" and resolveUpgradeLevel(upgrades, "sto_1") <= 0 then
		return false, cloneState(playerData)
	elseif upgrade.id == "sto_3" and resolveUpgradeLevel(upgrades, "sto_2") <= 0 then
		return false, cloneState(playerData)
	elseif upgrade.id == "cpu_2" and storageTier < 2 then
		return false, cloneState(playerData)
	elseif upgrade.id == "cpu_3" and storageTier < 3 then
		return false, cloneState(playerData)
	elseif upgrade.id == "ram_2" and storageTier < 2 then
		return false, cloneState(playerData)
	end

	local canLevel, cost = validateUpgradeCost(upgrade, upgradeId, currentLevel)
	if not canLevel then
		return false, cloneState(playerData)
	end

	local currency = getCurrency(playerData)
	if currency < cost then
		return false, cloneState(playerData)
	end

	return true, cloneState(playerData)
end

function UpgradeService.Buy(player, upgradeId)
<<<<<<< HEAD
	local success, reasonOrQuantity, spent = executePurchase(player, upgradeId, 1)
	if not success then
		return false, reasonOrQuantity
	end

	return true, reasonOrQuantity, spent
end

function UpgradeService.BuyMax(player, upgradeId)
	local success, purchased, spent = executePurchase(player, upgradeId, nil)
	return success, purchased, spent
=======
	local upgrade = getUpgradeDefinition(upgradeId)
	if not upgrade then
		return false, nil
	end

	local playerData = PlayerDataService.Get(player)
	if typeof(playerData) ~= "table" then
		return false, nil
	end

	local upgrades = ensureUpgradeTable(playerData)
	local currentLevel = resolveUpgradeLevel(upgrades, upgradeId)
	local nextLevel = currentLevel + 1

	local canLevel, cost = validateUpgradeCost(upgrade, upgradeId, currentLevel)
	if not canLevel then
		return false, cloneState(playerData)
	end

	local storageTier = UpgradeConfig.GetStorageTier(upgrades)
	if upgrade.id == "sto_2" and resolveUpgradeLevel(upgrades, "sto_1") <= 0 then
		return false, cloneState(playerData)
	elseif upgrade.id == "sto_3" and resolveUpgradeLevel(upgrades, "sto_2") <= 0 then
		return false, cloneState(playerData)
	elseif upgrade.id == "cpu_2" and storageTier < 2 then
		return false, cloneState(playerData)
	elseif upgrade.id == "cpu_3" and storageTier < 3 then
		return false, cloneState(playerData)
	elseif upgrade.id == "ram_2" and storageTier < 2 then
		return false, cloneState(playerData)
	end

	local currency = getCurrency(playerData)
	if currency < cost then
		return false, cloneState(playerData)
	end

	playerData.data = currency - cost
	upgrades[upgradeId] = nextLevel

	PlayerDataService.Set(player, playerData)

	return true, cloneState(playerData)
>>>>>>> parent of 0324c3d (Add automation, group bonus, and milestone services)
end

return UpgradeService
